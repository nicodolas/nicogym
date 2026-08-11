CREATE TABLE "planner_states" (
	"profile_id" uuid PRIMARY KEY NOT NULL,
	"weekly_schedule" jsonb NOT NULL,
	"recovery_hours" integer DEFAULT 48 NOT NULL,
	"today_workout" text DEFAULT 'Chân + Mông' NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "planner_states" ADD CONSTRAINT "planner_states_profile_id_profiles_id_fk" FOREIGN KEY ("profile_id") REFERENCES "public"."profiles"("id") ON DELETE cascade ON UPDATE no action;