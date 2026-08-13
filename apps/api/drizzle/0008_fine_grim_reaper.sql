ALTER TABLE "planner_states" ADD COLUMN "goal" text DEFAULT 'muscle_strength' NOT NULL;--> statement-breakpoint
ALTER TABLE "planner_states" ADD COLUMN "session_minutes" integer DEFAULT 45 NOT NULL;