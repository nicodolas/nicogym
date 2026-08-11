import { sql } from "drizzle-orm";

import { createApp } from "./app.js";
import { auth } from "./auth.js";
import { createDatabase } from "./db/client.js";
import { readEnvironment } from "./env.js";
import { createFixedWindowRateLimiter } from "./rate-limit.js";

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
      return session ? { id: session.user.id } : null;
    },
    workoutWriteAllowed: (userId) => workoutWriteLimiter.consume(userId),
    plannerWriteAllowed: async (userId) => {
      const result = await database.execute(sql`
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
        const result = await database.execute(sql`
          with ensured_profile as (
            insert into profiles (auth_user_id)
            values (${userId})
            on conflict (auth_user_id) do update
              set updated_at = profiles.updated_at
            returning id
          )
          insert into planner_states (
            profile_id, weekly_schedule, recovery_hours, today_workout,
            suggestion_accepted, updated_at
          )
          select id, ${JSON.stringify(state.weeklySchedule)}::jsonb,
            ${state.recoveryHours}, ${state.todayWorkout},
            ${state.suggestionAccepted}, now()
          from ensured_profile
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
    workoutSets: {
      insert: async ({ userId, workoutExerciseId, loadKg, repetitions }) => {
        await database.execute(sql`
          insert into profiles (auth_user_id)
          values (${userId})
          on conflict (auth_user_id) do nothing
        `);

        const result = await database.execute(sql`
          insert into workout_sets (
            profile_id,
            workout_exercise_id,
            set_number,
            load_kg,
            repetitions
          )
          select
            profiles.id,
            ${workoutExerciseId}::uuid,
            coalesce(max(workout_sets.set_number), 0) + 1,
            ${loadKg},
            ${repetitions}
          from profiles
          inner join workout_sessions
            on workout_sessions.profile_id = profiles.id
          inner join workout_exercises
            on workout_exercises.workout_session_id = workout_sessions.id
            and workout_exercises.id = ${workoutExerciseId}::uuid
          left join workout_sets
            on workout_sets.workout_exercise_id = ${workoutExerciseId}::uuid
          where profiles.auth_user_id = ${userId}
          group by profiles.id
        `);
        return (result.rowCount ?? 0) > 0;
      },
    },
  });
}
