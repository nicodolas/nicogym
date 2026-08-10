import { Hono } from "hono";
import { handle } from "hono/vercel";
import { cors } from "hono/cors";
import { z } from "zod";

const workoutSetSchema = z.object({
  workoutExerciseId: z.string().min(1),
  loadKg: z.number().min(0),
  repetitions: z.number().int().min(1).max(1000),
});

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
}

export function createApp(dependencies: AppDependencies = {}) {
  const app = new Hono();
  const allowedOrigins = dependencies.allowedOrigins ?? ["http://localhost:8080"];

  app.use(
    "/api/*",
    cors({
      origin: (origin) => (allowedOrigins.includes(origin) ? origin : null),
      allowHeaders: ["Content-Type", "Authorization"],
      allowMethods: ["GET", "POST", "PATCH", "DELETE", "OPTIONS"],
      exposeHeaders: ["set-auth-token"],
      maxAge: 600,
      credentials: true,
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

  app.post("/api/workout-sets", async (context) => {
    const user = await (dependencies.currentUser?.(context.req.raw.headers) ?? Promise.resolve(null));
    if (!user) return context.json({ error: "unauthorized" }, 401);

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

  return app;
}

type VercelHandler = ReturnType<typeof handle>;

let productionHandler: VercelHandler | undefined;

export default async function vercelHandler(request: Request) {
  if (!productionHandler) {
    const { createProductionApp } = await import("./production-app.js");
    productionHandler = handle(createProductionApp());
  }
  return productionHandler(request);
}
