import { Hono } from "hono";
import { bodyLimit } from "hono/body-limit";
import { cors } from "hono/cors";
import { secureHeaders } from "hono/secure-headers";
import { z } from "zod";

const workoutSetSchema = z.object({
  workoutExerciseId: z.string().uuid(),
  loadKg: z.number().min(0),
  repetitions: z.number().int().min(1).max(1000),
});

const plannerStateSchema = z.object({
  weeklySchedule: z
    .array(z.object({ day: z.number().int().min(1).max(7), title: z.string().trim().min(1).max(80) }))
    .min(1)
    .max(7),
  recoveryHours: z.number().int().min(24).max(96),
  todayWorkout: z.string().trim().min(1).max(80),
}).refine(
  (state) => new Set(state.weeklySchedule.map((session) => session.day)).size === state.weeklySchedule.length,
  { message: "duplicate_schedule_day", path: ["weeklySchedule"] },
);

type PlannerState = z.infer<typeof plannerStateSchema>;

interface CurrentUser {
  id: string;
}

interface WorkoutSetInsert {
  userId: string;
  workoutExerciseId: string;
  loadKg: number;
  repetitions: number;
}

export interface AppDependencies {
  currentUser?: (headers: Headers) => Promise<CurrentUser | null>;
  workoutSets?: { insert: (value: WorkoutSetInsert) => Promise<boolean> };
  allowedOrigins?: string[];
  authHandler?: (request: Request) => Promise<Response>;
  workoutWriteAllowed?: (userId: string) => boolean | Promise<boolean>;
  plannerStates?: {
    get: (userId: string) => Promise<PlannerState | null>;
    upsert: (userId: string, state: PlannerState) => Promise<PlannerState>;
  };
  plannerWriteAllowed?: (userId: string) => boolean | Promise<boolean>;
}

export function createApp(dependencies: AppDependencies = {}) {
  const app = new Hono();
  const allowedOrigins = dependencies.allowedOrigins ?? ["http://localhost:8080"];

  app.use("*", secureHeaders());

  app.use("/api/*", async (context, next) => {
    const origin = context.req.header("origin");
    if (origin && !allowedOrigins.includes(origin)) {
      return context.json({ error: "origin_not_allowed" }, 403);
    }
    await next();
  });

  app.use(
    "/api/*",
    cors({
      origin: (origin) => (allowedOrigins.includes(origin) ? origin : null),
      allowHeaders: ["Content-Type", "Authorization"],
      allowMethods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
      exposeHeaders: ["set-auth-token"],
      maxAge: 600,
      credentials: true,
    }),
  );

  app.use(
    "/api/*",
    bodyLimit({
      maxSize: 32 * 1024,
      onError: (context) => context.json({ error: "payload_too_large" }, 413),
    }),
  );

  app.get("/health", (context) =>
    context.json({ service: "nicogym-api", status: "ok" }),
  );
  app.get("/", (context) =>
    context.json({
      service: "nicogym-api",
      status: "ok",
      health: "/health",
    }),
  );
  app.get("/api/health", (context) =>
    context.json({ service: "nicogym-api", status: "ok" }),
  );

  if (dependencies.authHandler) {
    app.on(["GET", "POST"], "/api/auth/*", (context) =>
      dependencies.authHandler!(context.req.raw),
    );
  }

  app.get("/api/planner", async (context) => {
    const user = await (dependencies.currentUser?.(context.req.raw.headers) ?? Promise.resolve(null));
    if (!user) return context.json({ error: "unauthorized" }, 401);
    if (!dependencies.plannerStates) return context.json({ error: "service_unavailable" }, 503);

    const state = await dependencies.plannerStates.get(user.id);
    return context.json({ data: state });
  });

  app.put("/api/planner", async (context) => {
    if (!context.req.header("content-type")?.toLowerCase().startsWith("application/json")) {
      return context.json({ error: "unsupported_media_type" }, 415);
    }
    const user = await (dependencies.currentUser?.(context.req.raw.headers) ?? Promise.resolve(null));
    if (!user) return context.json({ error: "unauthorized" }, 401);
    if (dependencies.plannerWriteAllowed && !(await dependencies.plannerWriteAllowed(user.id))) {
      context.header("Retry-After", "60");
      return context.json({ error: "rate_limit_exceeded" }, 429);
    }

    let body: unknown;
    try {
      body = await context.req.json();
    } catch {
      return context.json({ error: "invalid_planner_state" }, 400);
    }
    const parsed = plannerStateSchema.safeParse(body);
    if (!parsed.success) return context.json({ error: "invalid_planner_state" }, 400);
    if (!dependencies.plannerStates) return context.json({ error: "service_unavailable" }, 503);

    const state = await dependencies.plannerStates.upsert(user.id, parsed.data);
    return context.json({ data: state });
  });

  app.post("/api/workout-sets", async (context) => {
    if (!context.req.header("content-type")?.toLowerCase().startsWith("application/json")) {
      return context.json({ error: "unsupported_media_type" }, 415);
    }

    const user = await (dependencies.currentUser?.(context.req.raw.headers) ?? Promise.resolve(null));
    if (!user) return context.json({ error: "unauthorized" }, 401);

    if (dependencies.workoutWriteAllowed && !(await dependencies.workoutWriteAllowed(user.id))) {
      context.header("Retry-After", "60");
      return context.json({ error: "rate_limit_exceeded" }, 429);
    }

    let body: unknown;
    try {
      body = await context.req.json();
    } catch {
      return context.json({ error: "invalid_workout_set" }, 400);
    }

    const parsed = workoutSetSchema.safeParse(body);
    if (!parsed.success) {
      return context.json({ error: "invalid_workout_set" }, 400);
    }

    if (!dependencies.workoutSets) {
      return context.json({ error: "service_unavailable" }, 503);
    }

    const inserted = await dependencies.workoutSets.insert({ userId: user.id, ...parsed.data });
    if (!inserted) {
      return context.json({ error: "workout_exercise_not_found" }, 404);
    }
    return context.json({ data: parsed.data }, 201);
  });

  app.onError((error, context) => {
    console.error("Unhandled API error", error);
    return context.json({ error: "internal_server_error" }, 500);
  });

  return app;
}

type VercelHandler = (request: Request) => Response | Promise<Response>;

let productionHandler: VercelHandler | undefined;

export default {
  async fetch(request: Request) {
    if (!productionHandler) {
      const { createProductionApp } = await import("./production-app.js");
      const app = createProductionApp();
      productionHandler = (incomingRequest) => app.fetch(incomingRequest);
    }
    return productionHandler(request);
  },
};
