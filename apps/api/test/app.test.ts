import { describe, expect, it } from "vitest";

import { createApp } from "../src/app.js";

const authenticatedUser = { id: "user-1", role: "user" as const };
const adminUser = { id: "admin-1", role: "admin" as const };
const workoutExerciseId = "d4d68f8b-4aa3-4cb0-a077-3dfd51e6d95f";

describe("API", () => {
  const plannerState = {
    weeklySchedule: [
      { day: 1, title: "Ngực + Tay sau" },
      { day: 5, title: "Chân + Mông" },
    ],
    recoveryHours: 48,
    todayWorkout: "Chân + Mông",
    suggestionAccepted: false,
  };

  it("identifies the API from its public root", async () => {
    const response = await createApp().request("/");

    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({
      service: "nicogym-api",
      status: "ok",
      health: "/health",
    });
  });

  it("reports service health without touching the database", async () => {
    const response = await createApp().request("/health");

    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ service: "nicogym-api", status: "ok" });
  });

  it("reports service health through the Vercel function path", async () => {
    const response = await createApp().request("/api/health");

    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ service: "nicogym-api", status: "ok" });
  });

  it("rejects malformed set logs", async () => {
    const response = await createApp({ currentUser: async () => authenticatedUser }).request("/api/workout-sets", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ loadKg: -1, repetitions: 0 }),
    });

    expect(response.status).toBe(400);
  });

  it("rejects invalid JSON as a client error", async () => {
    const response = await createApp({ currentUser: async () => authenticatedUser }).request("/api/workout-sets", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: "{not-json",
    });

    expect(response.status).toBe(400);
    expect(await response.json()).toEqual({ error: "invalid_workout_set" });
  });

  it("requires authentication to log a set", async () => {
    const response = await createApp().request("/api/workout-sets", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ workoutExerciseId, loadKg: 40, repetitions: 10 }),
    });

    expect(response.status).toBe(401);
  });

  it("starts an owned workout exercise from a catalog slug", async () => {
    const started: unknown[] = [];
    const response = await createApp({
      currentUser: async () => authenticatedUser,
      workoutSessions: {
        start: async (value) => (started.push(value), workoutExerciseId),
      },
    }).request("/api/workout-sessions", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ exerciseSlug: "leg-press" }),
    });

    expect(response.status).toBe(201);
    expect(started).toEqual([{ userId: "user-1", exerciseSlug: "leg-press" }]);
    expect(await response.json()).toEqual({ data: { workoutExerciseId } });
  });

  it("does not start a workout for an unknown exercise", async () => {
    const response = await createApp({
      currentUser: async () => authenticatedUser,
      workoutSessions: { start: async () => null },
    }).request("/api/workout-sessions", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ exerciseSlug: "missing-exercise" }),
    });

    expect(response.status).toBe(404);
    expect(await response.json()).toEqual({ error: "exercise_not_found" });
  });

  it("requires authentication to read the planner", async () => {
    const response = await createApp().request("/api/planner");
    expect(response.status).toBe(401);
  });

  it("returns the exercise catalog to an authenticated member", async () => {
    const exercises = [{ slug: "leg-press", name: "Leg press" }];
    const response = await createApp({
      currentUser: async () => authenticatedUser,
      exerciseCatalog: {
        list: async () => exercises,
        previewImport: async () => ({ token: "unused", summary: { creates: 0, updates: 0 } }),
        applyImport: async () => ({ created: 0, updated: 0 }),
      },
    }).request("/api/exercises");

    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ data: exercises });
  });

  it("returns only the persisted application role for the current member", async () => {
    const response = await createApp({ currentUser: async () => adminUser }).request("/api/me");
    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ data: { id: "admin-1", role: "admin" } });
  });

  it("does not trust a normal member with exercise imports", async () => {
    const response = await createApp({ currentUser: async () => authenticatedUser }).request(
      "/api/admin/exercises/import/preview",
      {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ mode: "create", exercises: [] }),
      },
    );
    expect(response.status).toBe(403);
    expect(await response.json()).toEqual({ error: "admin_required" });
  });

  it("previews and applies a bounded admin JSON import", async () => {
    const calls: unknown[] = [];
    const exerciseCatalog = {
      list: async () => [],
      previewImport: async (value: unknown) => {
        calls.push(value);
        return { token: "signed-preview-token", summary: { creates: 1, updates: 0 } };
      },
      applyImport: async (token: string) => {
        calls.push(token);
        return { created: 1, updated: 0 };
      },
    };
    const exercise = {
      slug: "goblet-squat",
      name: "Goblet squat",
      category: "Chân & Mông",
      equipment: "Tạ đơn",
      prescription: "3 × 8–12",
      primaryMuscles: ["Đùi trước", "Mông"],
      summary: "Squat với một tạ trước ngực.",
      setup: ["Giữ tạ sát ngực."],
      steps: ["Hạ hông có kiểm soát."],
      cues: ["Giữ cả bàn chân trên sàn."],
      mistakes: ["Đầu gối đổ vào trong."],
      safety: "Dừng nếu đau nhói.",
      sourceLabel: "NicoGym",
      sourceUrl: "https://example.com/source",
      videoUrl: "https://www.youtube.com/watch?v=test1234567",
      imageUrl: "https://example.com/goblet-squat.jpg",
    };
    const app = createApp({ currentUser: async () => adminUser, exerciseCatalog });
    const preview = await app.request("/api/admin/exercises/import/preview", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ mode: "create", exercises: [exercise] }),
    });
    expect(preview.status).toBe(200);
    expect(await preview.json()).toEqual({
      data: { token: "signed-preview-token", summary: { creates: 1, updates: 0 } },
    });

    const apply = await app.request("/api/admin/exercises/import/apply", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ previewToken: "signed-preview-token" }),
    });
    expect(apply.status).toBe(200);
    expect(await apply.json()).toEqual({ data: { created: 1, updated: 0 } });
    expect(calls).toHaveLength(2);
  });

  it("rejects duplicate slugs and imports over 100 exercises", async () => {
    const exercise = {
      slug: "leg-press",
      name: "Leg press",
      category: "Chân & Mông",
      equipment: "Máy",
      prescription: "3 × 10",
      primaryMuscles: ["Đùi trước"],
      summary: "Tóm tắt đủ dài.",
      setup: ["Chuẩn bị."],
      steps: ["Thực hiện."],
      cues: ["Gợi ý."],
      mistakes: ["Lỗi."],
      safety: "An toàn.",
      sourceLabel: "NicoGym",
      sourceUrl: "https://example.com",
      videoUrl: "https://youtube.com/watch?v=abcdefghijk",
    };
    const app = createApp({ currentUser: async () => adminUser });
    for (const exercises of [[exercise, exercise], Array.from({ length: 101 }, (_, index) => ({ ...exercise, slug: `exercise-${index}` }))]) {
      const response = await app.request("/api/admin/exercises/import/preview", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ mode: "create", exercises }),
      });
      expect(response.status).toBe(400);
      expect(await response.json()).toMatchObject({ error: "invalid_exercise_import" });
    }
  });

  it("rejects exercise preview documents over 512 KB", async () => {
    const response = await createApp({ currentUser: async () => adminUser }).request(
      "/api/admin/exercises/import/preview",
      {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ padding: "x".repeat(513 * 1024) }),
      },
    );
    expect(response.status).toBe(413);
    expect(await response.json()).toEqual({ error: "payload_too_large" });
  });

  it("returns the authenticated member planner", async () => {
    const response = await createApp({
      currentUser: async () => authenticatedUser,
      plannerStates: { get: async () => plannerState, upsert: async (_, state) => state },
    }).request("/api/planner");

    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ data: plannerState });
  });

  it("validates and stores planner changes for the authenticated member", async () => {
    const stored: unknown[] = [];
    const response = await createApp({
      currentUser: async () => authenticatedUser,
      plannerStates: {
        get: async () => null,
        upsert: async (userId, state) => (stored.push({ userId, state }), state),
      },
    }).request("/api/planner", {
      method: "PUT",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(plannerState),
    });

    expect(response.status).toBe(200);
    expect(stored).toEqual([{ userId: "user-1", state: plannerState }]);
  });

  it("allows browser preflight for planner PUT requests", async () => {
    const response = await createApp({ allowedOrigins: ["https://app.nicogym.test"] }).request(
      "/api/planner",
      { method: "OPTIONS", headers: { origin: "https://app.nicogym.test" } },
    );
    expect(response.headers.get("access-control-allow-methods")).toContain("PUT");
  });

  it("rejects unsafe planner bounds", async () => {
    const response = await createApp({ currentUser: async () => authenticatedUser }).request(
      "/api/planner",
      {
        method: "PUT",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ ...plannerState, recoveryHours: 200 }),
      },
    );
    expect(response.status).toBe(400);
    expect(await response.json()).toEqual({ error: "invalid_planner_state" });
  });

  it("rejects duplicate planner days", async () => {
    const response = await createApp({ currentUser: async () => authenticatedUser }).request(
      "/api/planner",
      {
        method: "PUT",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          ...plannerState,
          weeklySchedule: [
            { day: 1, title: "Ngực" },
            { day: 1, title: "Lưng" },
          ],
        }),
      },
    );
    expect(response.status).toBe(400);
  });

  it("rate limits planner writes per authenticated user", async () => {
    const response = await createApp({
      currentUser: async () => authenticatedUser,
      plannerWriteAllowed: () => false,
    }).request("/api/planner", {
      method: "PUT",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(plannerState),
    });
    expect(response.status).toBe(429);
    expect(response.headers.get("retry-after")).toBe("60");
  });

  it("stores a valid set for the authenticated user", async () => {
    const stored: unknown[] = [];
    const response = await createApp({
      currentUser: async () => authenticatedUser,
      workoutSets: { insert: async (value) => (stored.push(value), true) },
    }).request("/api/workout-sets", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ workoutExerciseId, loadKg: 40, repetitions: 10 }),
    });

    expect(response.status).toBe(201);
    expect(stored).toEqual([
      { userId: "user-1", workoutExerciseId, loadKg: 40, repetitions: 10 },
    ]);
  });

  it("does not report success when the exercise is not owned by the user", async () => {
    const response = await createApp({
      currentUser: async () => authenticatedUser,
      workoutSets: { insert: async () => false },
    }).request("/api/workout-sets", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ workoutExerciseId, loadKg: 40, repetitions: 10 }),
    });

    expect(response.status).toBe(404);
    expect(await response.json()).toEqual({ error: "workout_exercise_not_found" });
  });

  it("does not grant an allowed CORS origin to an untrusted site", async () => {
    const response = await createApp({ allowedOrigins: ["https://app.nicogym.test"] }).request("/api/workout-sets", {
      method: "OPTIONS",
      headers: { origin: "https://evil.example" },
    });

    expect(response.headers.get("access-control-allow-origin")).toBeNull();
  });

  it("rejects state-changing browser requests from an untrusted origin", async () => {
    let inserted = false;
    const response = await createApp({
      allowedOrigins: ["https://nicodolasgym.netlify.app"],
      currentUser: async () => authenticatedUser,
      workoutSets: { insert: async () => (inserted = true) },
    }).request("/api/workout-sets", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        origin: "https://evil.example",
      },
      body: JSON.stringify({ workoutExerciseId, loadKg: 40, repetitions: 10 }),
    });

    expect(response.status).toBe(403);
    expect(inserted).toBe(false);
  });

  it("rejects oversized request bodies before JSON parsing", async () => {
    const response = await createApp({ currentUser: async () => authenticatedUser }).request(
      "/api/workout-sets",
      {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ padding: "x".repeat(33 * 1024) }),
      },
    );

    expect(response.status).toBe(413);
    expect(await response.json()).toEqual({ error: "payload_too_large" });
  });

  it("requires JSON content for workout writes", async () => {
    const response = await createApp({ currentUser: async () => authenticatedUser }).request(
      "/api/workout-sets",
      {
        method: "POST",
        headers: { "content-type": "text/plain" },
        body: "not-json",
      },
    );

    expect(response.status).toBe(415);
  });

  it("requires a UUID workout exercise identifier", async () => {
    const response = await createApp({ currentUser: async () => authenticatedUser }).request(
      "/api/workout-sets",
      {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ workoutExerciseId: "not-a-uuid", loadKg: 40, repetitions: 10 }),
      },
    );

    expect(response.status).toBe(400);
  });

  it("rate limits workout writes per authenticated user", async () => {
    const response = await createApp({
      currentUser: async () => authenticatedUser,
      workoutWriteAllowed: () => false,
    }).request("/api/workout-sets", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ workoutExerciseId, loadKg: 40, repetitions: 10 }),
    });

    expect(response.status).toBe(429);
    expect(response.headers.get("retry-after")).toBe("60");
    expect(await response.json()).toEqual({ error: "rate_limit_exceeded" });
  });

  it("adds defensive HTTP response headers", async () => {
    const response = await createApp().request("/health");

    expect(response.headers.get("x-content-type-options")).toBe("nosniff");
    expect(response.headers.get("x-frame-options")).toBe("SAMEORIGIN");
    expect(response.headers.get("referrer-policy")).toBe("no-referrer");
  });
});
