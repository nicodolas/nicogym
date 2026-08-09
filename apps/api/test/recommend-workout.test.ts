import { describe, expect, it } from "vitest";

import { recommendWorkout } from "../src/domain/recommend-workout.js";

describe("recommendWorkout", () => {
  it("keeps the scheduled workout when its muscles are recovered", () => {
    const result = recommendWorkout({
      scheduled: { id: "legs", muscleGroups: ["quadriceps"] },
      alternatives: [{ id: "push", muscleGroups: ["chest"] }],
      recovery: { quadriceps: { hoursSinceTraining: 72, minimumHours: 48 } },
    });

    expect(result).toEqual({ kind: "keep", workoutId: "legs", reasons: [] });
  });

  it("suggests but never applies an alternative when recovery is insufficient", () => {
    const result = recommendWorkout({
      scheduled: { id: "legs", muscleGroups: ["quadriceps"] },
      alternatives: [{ id: "push", muscleGroups: ["chest"] }],
      recovery: {
        quadriceps: { hoursSinceTraining: 24, minimumHours: 48 },
        chest: { hoursSinceTraining: 72, minimumHours: 48 },
      },
    });

    expect(result).toEqual({
      kind: "suggest",
      scheduledWorkoutId: "legs",
      suggestedWorkoutId: "push",
      requiresConfirmation: true,
      reasons: ["quadriceps needs about 24 more hours of recovery"],
    });
  });

  it("keeps the schedule when no recovered alternative exists", () => {
    const result = recommendWorkout({
      scheduled: { id: "legs", muscleGroups: ["quadriceps"] },
      alternatives: [{ id: "push", muscleGroups: ["chest"] }],
      recovery: {
        quadriceps: { hoursSinceTraining: 24, minimumHours: 48 },
        chest: { hoursSinceTraining: 12, minimumHours: 48 },
      },
    });

    expect(result.kind).toBe("keep");
  });
});
