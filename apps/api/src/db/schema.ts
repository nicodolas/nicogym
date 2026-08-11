import {
  boolean,
  doublePrecision,
  integer,
  jsonb,
  pgTable,
  primaryKey,
  text,
  timestamp,
  uniqueIndex,
  uuid,
} from "drizzle-orm/pg-core";

import { user } from "./auth-schema.js";

export const profiles = pgTable(
  "profiles",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    authUserId: text("auth_user_id")
      .notNull()
      .references(() => user.id, { onDelete: "cascade" }),
    displayName: text("display_name"),
    goal: text("goal").notNull().default("muscle_and_strength"),
    experienceLevel: text("experience_level").notNull().default("beginner"),
    createdAt: timestamp("created_at", { withTimezone: true }).defaultNow().notNull(),
    updatedAt: timestamp("updated_at", { withTimezone: true }).defaultNow().notNull(),
  },
  (table) => [uniqueIndex("profiles_auth_user_id_uidx").on(table.authUserId)],
);

export const muscleGroups = pgTable("muscle_groups", {
  id: text("id").primaryKey(),
  name: text("name").notNull(),
});

export const exercises = pgTable("exercises", {
  id: uuid("id").defaultRandom().primaryKey(),
  slug: text("slug").notNull().unique(),
  name: text("name").notNull(),
  equipment: text("equipment").notNull(),
  instructions: jsonb("instructions").$type<string[]>().notNull(),
  commonMistakes: jsonb("common_mistakes").$type<string[]>().notNull(),
  videoUrl: text("video_url"),
  reviewed: boolean("reviewed").notNull().default(false),
});

export const exerciseMuscles = pgTable(
  "exercise_muscles",
  {
    exerciseId: uuid("exercise_id").notNull().references(() => exercises.id),
    muscleGroupId: text("muscle_group_id").notNull().references(() => muscleGroups.id),
    isPrimary: boolean("is_primary").notNull().default(false),
  },
  (table) => [primaryKey({ columns: [table.exerciseId, table.muscleGroupId] })],
);

export const workoutPlans = pgTable("workout_plans", {
  id: uuid("id").defaultRandom().primaryKey(),
  profileId: uuid("profile_id").notNull().references(() => profiles.id),
  name: text("name").notNull(),
  active: boolean("active").notNull().default(false),
  createdAt: timestamp("created_at", { withTimezone: true }).defaultNow().notNull(),
});

export const scheduledSessions = pgTable("scheduled_sessions", {
  id: uuid("id").defaultRandom().primaryKey(),
  profileId: uuid("profile_id").notNull().references(() => profiles.id),
  planId: uuid("plan_id").references(() => workoutPlans.id),
  scheduledFor: timestamp("scheduled_for", { withTimezone: true }).notNull(),
  title: text("title").notNull(),
  status: text("status").notNull().default("scheduled"),
  confirmedRecommendationId: uuid("confirmed_recommendation_id"),
});

export const workoutSessions = pgTable("workout_sessions", {
  id: uuid("id").defaultRandom().primaryKey(),
  profileId: uuid("profile_id").notNull().references(() => profiles.id),
  scheduledSessionId: uuid("scheduled_session_id").references(() => scheduledSessions.id),
  startedAt: timestamp("started_at", { withTimezone: true }).defaultNow().notNull(),
  completedAt: timestamp("completed_at", { withTimezone: true }),
});

export const workoutExercises = pgTable("workout_exercises", {
  id: uuid("id").defaultRandom().primaryKey(),
  workoutSessionId: uuid("workout_session_id").notNull().references(() => workoutSessions.id),
  exerciseId: uuid("exercise_id").notNull().references(() => exercises.id),
  position: integer("position").notNull(),
});

export const workoutSets = pgTable(
  "workout_sets",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    profileId: uuid("profile_id").notNull().references(() => profiles.id),
    workoutExerciseId: uuid("workout_exercise_id").notNull().references(() => workoutExercises.id),
    setNumber: integer("set_number").notNull(),
    loadKg: doublePrecision("load_kg").notNull(),
    repetitions: integer("repetitions").notNull(),
    effort: text("effort"),
    completedAt: timestamp("completed_at", { withTimezone: true }).defaultNow().notNull(),
  },
  (table) => [
    uniqueIndex("workout_sets_exercise_number_uidx").on(table.workoutExerciseId, table.setNumber),
  ],
);

export const recoveryPreferences = pgTable(
  "recovery_preferences",
  {
    profileId: uuid("profile_id").notNull().references(() => profiles.id),
    muscleGroupId: text("muscle_group_id").notNull().references(() => muscleGroups.id),
    minimumHours: integer("minimum_hours").notNull().default(48),
  },
  (table) => [primaryKey({ columns: [table.profileId, table.muscleGroupId] })],
);

export const plannerStates = pgTable("planner_states", {
  profileId: uuid("profile_id")
    .primaryKey()
    .references(() => profiles.id, { onDelete: "cascade" }),
  weeklySchedule: jsonb("weekly_schedule")
    .$type<Array<{ day: number; title: string }>>()
    .notNull(),
  recoveryHours: integer("recovery_hours").notNull().default(48),
  todayWorkout: text("today_workout").notNull().default("Chân + Mông"),
  updatedAt: timestamp("updated_at", { withTimezone: true }).defaultNow().notNull(),
});

export const recommendationRuns = pgTable("recommendation_runs", {
  id: uuid("id").defaultRandom().primaryKey(),
  profileId: uuid("profile_id").notNull().references(() => profiles.id),
  scheduledSessionId: uuid("scheduled_session_id").notNull().references(() => scheduledSessions.id),
  ruleVersion: text("rule_version").notNull(),
  result: jsonb("result").notNull(),
  accepted: boolean("accepted"),
  createdAt: timestamp("created_at", { withTimezone: true }).defaultNow().notNull(),
});
