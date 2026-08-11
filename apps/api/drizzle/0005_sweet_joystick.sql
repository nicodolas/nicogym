CREATE TYPE "public"."profile_role" AS ENUM('user', 'admin');--> statement-breakpoint
CREATE TABLE "admin_audit_events" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"actor_auth_user_id" text NOT NULL,
	"action" text NOT NULL,
	"target" text NOT NULL,
	"details" jsonb DEFAULT '{}'::jsonb NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "exercises" ADD COLUMN "content" jsonb DEFAULT '{}'::jsonb NOT NULL;--> statement-breakpoint
ALTER TABLE "exercises" ADD COLUMN "archived" boolean DEFAULT false NOT NULL;--> statement-breakpoint
ALTER TABLE "exercises" ADD COLUMN "schema_version" integer DEFAULT 1 NOT NULL;--> statement-breakpoint
ALTER TABLE "exercises" ADD COLUMN "created_at" timestamp with time zone DEFAULT now() NOT NULL;--> statement-breakpoint
ALTER TABLE "exercises" ADD COLUMN "updated_at" timestamp with time zone DEFAULT now() NOT NULL;--> statement-breakpoint
ALTER TABLE "profiles" ADD COLUMN "role" "profile_role" DEFAULT 'user' NOT NULL;--> statement-breakpoint
ALTER TABLE "admin_audit_events" ADD CONSTRAINT "admin_audit_events_actor_auth_user_id_user_id_fk" FOREIGN KEY ("actor_auth_user_id") REFERENCES "public"."user"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "admin_audit_actor_created_idx" ON "admin_audit_events" USING btree ("actor_auth_user_id","created_at");