import { describe, expect, it } from "vitest";

import { createApp } from "../src/app.js";

const authenticatedUser = { id: "user-1" };
const workoutExerciseId = "d4d68f8b-4aa3-4cb0-a077-3dfd51e6d95f";

describe("API", () => {
  const plannerState = {
    weeklySchedule: [
      { day: 1, title: "Ngực + Tay sau" },
      { day: 5, title: "Chân + Mông" },
    ],
    recoveryHours: 48,
    todayWorkout: "Chân + Mông",
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

  it("requires authentication to read the planner", async () => {
    const response = await createApp().request("/api/planner");
    expect(response.status).toBe(401);
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
