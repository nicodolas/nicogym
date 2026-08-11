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
