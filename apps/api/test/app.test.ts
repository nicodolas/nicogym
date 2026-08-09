import { describe, expect, it } from "vitest";

import { createApp } from "../src/app.js";

const authenticatedUser = { id: "user-1" };

describe("API", () => {
  it("reports service health without touching the database", async () => {
    const response = await createApp().request("/health");

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
      body: JSON.stringify({ workoutExerciseId: "exercise-1", loadKg: 40, repetitions: 10 }),
    });

    expect(response.status).toBe(401);
  });

  it("stores a valid set for the authenticated user", async () => {
    const stored: unknown[] = [];
    const response = await createApp({
      currentUser: async () => authenticatedUser,
      workoutSets: { insert: async (value) => (stored.push(value), true) },
    }).request("/api/workout-sets", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ workoutExerciseId: "exercise-1", loadKg: 40, repetitions: 10 }),
    });

    expect(response.status).toBe(201);
    expect(stored).toEqual([
      { userId: "user-1", workoutExerciseId: "exercise-1", loadKg: 40, repetitions: 10 },
    ]);
  });

  it("does not report success when the exercise is not owned by the user", async () => {
    const response = await createApp({
      currentUser: async () => authenticatedUser,
      workoutSets: { insert: async () => false },
    }).request("/api/workout-sets", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ workoutExerciseId: "someone-elses-exercise", loadKg: 40, repetitions: 10 }),
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
});
