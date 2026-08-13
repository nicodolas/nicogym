import { sql } from "drizzle-orm";
import { neon } from "@neondatabase/serverless";

import { createApp } from "./app.js";
import { auth } from "./auth.js";
import { createDatabase } from "./db/client.js";
import { readEnvironment } from "./env.js";
import { createFixedWindowRateLimiter } from "./rate-limit.js";
import { signImportPreview, verifyImportPreview } from "./catalog/import-token.js";

const workoutWriteLimiter = createFixedWindowRateLimiter({
  limit: 60,
  windowMs: 60_000,
});

export function createProductionApp() {
  const environment = readEnvironment();
  const database = createDatabase(environment.DATABASE_URL);

  return createApp({
    allowedOrigins: environment.ALLOWED_ORIGINS.split(",").map((origin) => origin.trim()),
    authHandler: (request) => auth.handler(request),
    currentUser: async (headers) => {
      const session = await auth.api.getSession({ headers });
      if (!session) return null;
      const result = await database.execute(sql`
        insert into profiles (auth_user_id)
        values (${session.user.id})
        on conflict (auth_user_id) do update set updated_at = profiles.updated_at
        returning role
      `);
      return { id: session.user.id, role: result.rows[0]?.role === "admin" ? "admin" : "user" };
    },
    exerciseCatalog: {
      list: async () => {
        const result = await database.execute(sql`
          select content || jsonb_build_object(
            'id', slug,
            'slug', slug,
            'name', name,
            'equipment', equipment,
            'videoUrl', video_url,
            'updatedAt', updated_at,
            'schemaVersion', schema_version
          ) as exercise
          from exercises
          where archived = false
          order by content->>'category', name, slug
        `);
        return result.rows.map((row) => row.exercise);
      },
      previewImport: async (value, adminUserId) => {
        const revision = await catalogRevision(database);
        const slugs = value.exercises.map((exercise) => exercise.slug);
        const existing = await database.execute(sql`
          select slug, updated_at as "updatedAt"
          from exercises
          where slug = any(${slugs}::text[])
        `);
        const bySlug = new Map(existing.rows.map((row) => [String(row.slug), row.updatedAt]));
        if (value.mode === "create" && bySlug.size > 0) throw new Error("exercise_already_exists");
        if (value.mode === "update" && bySlug.size !== value.exercises.length) throw new Error("exercise_not_found");
        for (const exercise of value.exercises) {
          const current = bySlug.get(exercise.slug);
          if (exercise.expectedUpdatedAt && current && new Date(String(current)).toISOString() !== exercise.expectedUpdatedAt) {
            throw new Error("stale_exercise_version");
          }
        }
        return {
          token: signImportPreview({
            ...value,
            adminUserId,
            catalogRevision: revision,
            expiresAt: Date.now() + 10 * 60_000,
          }, environment.BETTER_AUTH_SECRET),
          summary: {
            creates: value.exercises.filter((exercise) => !bySlug.has(exercise.slug)).length,
            updates: value.exercises.filter((exercise) => bySlug.has(exercise.slug)).length,
          },
        };
      },
      applyImport: async (token, adminUserId) => {
        const preview = verifyImportPreview(token, environment.BETTER_AUTH_SECRET);
        if (preview.adminUserId !== adminUserId) throw new Error("preview_owner_mismatch");
        if (await catalogRevision(database) !== preview.catalogRevision) throw new Error("stale_catalog_preview");
        const existing = await database.execute(sql`
          select slug from exercises where slug = any(${preview.exercises.map((exercise) => exercise.slug)}::text[])
        `);
        const existingSlugs = new Set(existing.rows.map((row) => String(row.slug)));
        const created = preview.exercises.filter((exercise) => !existingSlugs.has(exercise.slug)).length;
        const updated = preview.exercises.length - created;
        const httpSql = neon(environment.DATABASE_URL);
        try {
          await httpSql.transaction((transaction) => [
            transaction`
              select 1 / case when (
                select count(*)::text || ':' || coalesce(
                  md5(string_agg(slug || ':' || updated_at::text, ',' order by slug)),
                  'none'
                ) from exercises
              ) = ${preview.catalogRevision} then 1 else 0 end
            `,
            ...preview.exercises.map((exercise) => preview.mode === "create"
              ? transaction`
                  insert into exercises (slug, name, equipment, instructions, common_mistakes, video_url, reviewed, content)
                  values (${exercise.slug}, ${exercise.name}, ${exercise.equipment}, ${JSON.stringify(exercise.steps)}::jsonb,
                    ${JSON.stringify(exercise.mistakes)}::jsonb, ${exercise.videoUrl ?? null}, true, ${JSON.stringify(exercise)}::jsonb)
                `
              : preview.mode === "update"
                ? transaction`
                    update exercises set name = ${exercise.name}, equipment = ${exercise.equipment},
                      instructions = ${JSON.stringify(exercise.steps)}::jsonb,
                      common_mistakes = ${JSON.stringify(exercise.mistakes)}::jsonb,
                      video_url = ${exercise.videoUrl ?? null}, reviewed = true,
                      content = ${JSON.stringify(exercise)}::jsonb, archived = false, updated_at = now()
                    where slug = ${exercise.slug}
                  `
                : transaction`
                    insert into exercises (slug, name, equipment, instructions, common_mistakes, video_url, reviewed, content)
                    values (${exercise.slug}, ${exercise.name}, ${exercise.equipment}, ${JSON.stringify(exercise.steps)}::jsonb,
                      ${JSON.stringify(exercise.mistakes)}::jsonb, ${exercise.videoUrl ?? null}, true, ${JSON.stringify(exercise)}::jsonb)
                    on conflict (slug) do update set name = excluded.name, equipment = excluded.equipment,
                      instructions = excluded.instructions, common_mistakes = excluded.common_mistakes,
                      video_url = excluded.video_url, reviewed = true, content = excluded.content,
                      archived = false, updated_at = now()
                  `),
            transaction`
              insert into admin_audit_events (actor_auth_user_id, action, target, details)
              values (${adminUserId}, 'exercise_import', 'exercise_catalog', ${JSON.stringify({ created, updated })}::jsonb)
            `,
          ], { isolationLevel: "Serializable" });
        } catch (error) {
          if (error instanceof Error && error.message.includes("division by zero")) {
            throw new Error("stale_catalog_preview");
          }
          throw error;
        }
        return { created, updated };
      },
    },
    workoutWriteAllowed: (userId) => workoutWriteLimiter.consume(userId),
    plannerWriteAllowed: async (userId) => {
      const result = await database.execute(sql`
        with cleanup as (
          delete from api_rate_limits
          where key <> ${`planner:${userId}`}
            and window_started_at < now() - interval '1 day'
        )
        insert into api_rate_limits (key, window_started_at, request_count)
        values (${`planner:${userId}`}, date_trunc('minute', now()), 1)
        on conflict (key) do update set
          window_started_at = case
            when api_rate_limits.window_started_at < date_trunc('minute', now())
              then date_trunc('minute', now())
            else api_rate_limits.window_started_at
          end,
          request_count = case
            when api_rate_limits.window_started_at < date_trunc('minute', now()) then 1
            else api_rate_limits.request_count + 1
          end
        returning request_count
      `);
      return Number(result.rows[0]?.request_count ?? 61) <= 60;
    },
    plannerStates: {
      get: async (userId) => {
        const result = await database.execute(sql`
          select
            planner_states.weekly_schedule as "weeklySchedule",
            planner_states.recovery_hours as "recoveryHours",
            planner_states.today_workout as "todayWorkout",
            planner_states.suggestion_accepted as "suggestionAccepted"
          from planner_states
          inner join profiles on profiles.id = planner_states.profile_id
          where profiles.auth_user_id = ${userId}
          limit 1
        `);
        return (result.rows[0] as {
          weeklySchedule: Array<{ day: number; title: string }>;
          recoveryHours: number;
          todayWorkout: string;
          suggestionAccepted: boolean;
        } | undefined) ?? null;
      },
      upsert: async (userId, state) => {
        await database.execute(sql`
          insert into profiles (auth_user_id)
          values (${userId})
          on conflict (auth_user_id) do nothing
        `);
        const result = await database.execute(sql`
          insert into planner_states (
            profile_id, weekly_schedule, recovery_hours, today_workout,
            suggestion_accepted, updated_at
          )
          select id, ${JSON.stringify(state.weeklySchedule)}::jsonb,
            ${state.recoveryHours}, ${state.todayWorkout},
            ${state.suggestionAccepted}, now()
          from profiles where auth_user_id = ${userId}
          on conflict (profile_id) do update set
            weekly_schedule = excluded.weekly_schedule,
            recovery_hours = excluded.recovery_hours,
            today_workout = excluded.today_workout,
            suggestion_accepted = excluded.suggestion_accepted,
            updated_at = now()
          returning weekly_schedule as "weeklySchedule",
            recovery_hours as "recoveryHours", today_workout as "todayWorkout",
            suggestion_accepted as "suggestionAccepted"
        `);
        const saved = result.rows[0] as typeof state | undefined;
        if (!saved) throw new Error("planner_upsert_failed");
        return saved;
      },
    },
    progress: {
      summary: async (userId) => {
        const result = await database.execute(sql`
          with member as (
            select id from profiles where auth_user_id = ${userId}
          ), owned_sets as (
            select workout_sets.id, workout_sets.load_kg, workout_sets.repetitions,
              workout_sets.completed_at, workout_sessions.id as session_id,
              exercises.slug as "exerciseSlug", exercises.name as "exerciseName"
            from member
            inner join workout_sets on workout_sets.profile_id = member.id
            inner join workout_exercises on workout_exercises.id = workout_sets.workout_exercise_id
            inner join workout_sessions
              on workout_sessions.id = workout_exercises.workout_session_id
              and workout_sessions.profile_id = member.id
            inner join exercises on exercises.id = workout_exercises.exercise_id
          ), latest as (
            select id, "exerciseSlug", "exerciseName", load_kg as "loadKg",
              repetitions, completed_at as "completedAt"
            from owned_sets
            order by completed_at desc, id desc
            limit 8
          )
          select count(distinct session_id)::int as sessions,
            count(*)::int as sets,
            coalesce(sum(load_kg * repetitions), 0)::float8 as "volumeKg",
            coalesce((select jsonb_agg(latest order by "completedAt" desc, id desc) from latest), '[]'::jsonb) as latest
          from owned_sets
        `);
        const row = result.rows[0];
        const latest = Array.isArray(row?.latest)
          ? row.latest
          : JSON.parse(String(row?.latest ?? "[]"));
        return {
          sessions: Number(row?.sessions ?? 0),
          sets: Number(row?.sets ?? 0),
          volumeKg: Number(row?.volumeKg ?? 0),
          latest: latest.map((item: Record<string, unknown>) => ({
            exerciseSlug: String(item.exerciseSlug),
            exerciseName: String(item.exerciseName),
            loadKg: Number(item.loadKg),
            repetitions: Number(item.repetitions),
            completedAt: new Date(String(item.completedAt)).toISOString(),
          })),
        };
      },
    },
    workoutSessions: {
      start: async ({ userId, exerciseSlug, operationId }) => {
        await database.execute(sql`
          insert into profiles (auth_user_id)
          values (${userId})
          on conflict (auth_user_id) do nothing
        `);
        const result = await database.execute(sql`
          with created_session as (
            insert into workout_sessions (profile_id, operation_id)
            select profiles.id, ${operationId}
            from profiles
            where profiles.auth_user_id = ${userId}
              and exists (
                select 1 from exercises
                where exercises.slug = ${exerciseSlug} and exercises.archived = false
              )
            on conflict (profile_id, operation_id)
            do update set operation_id = excluded.operation_id
            returning id
          )
          insert into workout_exercises (workout_session_id, exercise_id, position)
          select created_session.id, exercises.id, 0
          from created_session
          inner join exercises
            on exercises.slug = ${exerciseSlug} and exercises.archived = false
          on conflict (workout_session_id, position)
          do update set position = excluded.position
          where workout_exercises.exercise_id = excluded.exercise_id
          returning workout_exercises.id
        `);
        return result.rows[0]?.id ? String(result.rows[0].id) : null;
      },
    },
    workoutSets: {
      insert: async ({ userId, workoutExerciseId, operationId, loadKg, repetitions }) => {
        await database.execute(sql`
          insert into profiles (auth_user_id)
          values (${userId})
          on conflict (auth_user_id) do nothing
        `);

        const result = await database.execute(sql`
          with target as (
            select profiles.id as profile_id, workout_exercises.id as workout_exercise_id
            from profiles
            inner join workout_sessions
              on workout_sessions.profile_id = profiles.id
            inner join workout_exercises
              on workout_exercises.workout_session_id = workout_sessions.id
              and workout_exercises.id = ${workoutExerciseId}::uuid
            where profiles.auth_user_id = ${userId}
          ), allocated as (
            update workout_exercises
            set next_set_number = workout_exercises.next_set_number + 1
            from target
            where workout_exercises.id = target.workout_exercise_id
            returning
              target.profile_id,
              workout_exercises.id as workout_exercise_id,
              workout_exercises.next_set_number - 1 as set_number
          )
          insert into workout_sets (
            profile_id,
            workout_exercise_id,
            operation_id,
            set_number,
            load_kg,
            repetitions
          )
          select
            allocated.profile_id,
            allocated.workout_exercise_id,
            ${operationId},
            allocated.set_number,
            ${loadKg},
            ${repetitions}
          from allocated
          on conflict (profile_id, operation_id)
          do update set operation_id = excluded.operation_id
          where workout_sets.workout_exercise_id = excluded.workout_exercise_id
            and workout_sets.load_kg = excluded.load_kg
            and workout_sets.repetitions = excluded.repetitions
          returning workout_sets.id
        `);
        return (result.rowCount ?? 0) > 0;
      },
    },
  });
}

type SqlExecutor = Pick<ReturnType<typeof createDatabase>, "execute">;

async function catalogRevision(database: SqlExecutor): Promise<string> {
  const result = await database.execute(sql`
    select count(*)::text || ':' || coalesce(
      md5(string_agg(slug || ':' || updated_at::text, ',' order by slug)),
      'none'
    ) as revision
    from exercises
  `);
  return String(result.rows[0]?.revision ?? "0:none");
}
