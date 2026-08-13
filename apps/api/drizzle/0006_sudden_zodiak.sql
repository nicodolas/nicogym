ALTER TABLE "workout_sessions" ADD COLUMN "operation_id" text;--> statement-breakpoint
ALTER TABLE "workout_sets" ADD COLUMN "operation_id" text;--> statement-breakpoint
CREATE UNIQUE INDEX "workout_exercises_session_position_uidx" ON "workout_exercises" USING btree ("workout_session_id","position");--> statement-breakpoint
CREATE UNIQUE INDEX "workout_sessions_profile_operation_uidx" ON "workout_sessions" USING btree ("profile_id","operation_id");--> statement-breakpoint
CREATE UNIQUE INDEX "workout_sets_profile_operation_uidx" ON "workout_sets" USING btree ("profile_id","operation_id");