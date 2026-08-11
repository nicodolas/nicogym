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
      reasons: [
        "quadriceps còn khoảng 24 giờ phục hồi",
        "chest đã nghỉ 72 giờ",
      ],
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

  it("discloses default recovery data when no training history exists", () => {
    const result = recommendWorkout({
      scheduled: { id: "legs", muscleGroups: ["quadriceps"] },
      alternatives: [{ id: "push", muscleGroups: ["chest"] }],
      recovery: {},
    });

    expect(result).toMatchObject({ kind: "keep", usedRecoveryDefaults: true });
    expect(result.reasons).toContain("Chưa có lịch sử tập, tạm dùng mặc định");
  });

  it("ranks fully recovered alternatives by longest rest and stable id", () => {
    const result = recommendWorkout({
      scheduled: { id: "legs", muscleGroups: ["quadriceps"] },
      alternatives: [
        { id: "pull", muscleGroups: ["back"] },
        { id: "arms", muscleGroups: ["biceps"] },
        { id: "push", muscleGroups: ["chest"] },
      ],
      recovery: {
        quadriceps: { hoursSinceTraining: 12, minimumHours: 48 },
        back: { hoursSinceTraining: 72, minimumHours: 48 },
        biceps: { hoursSinceTraining: 96, minimumHours: 48 },
        chest: { hoursSinceTraining: 96, minimumHours: 48 },
      },
    });

    expect(result).toMatchObject({ kind: "suggest", suggestedWorkoutId: "arms" });
    expect(result.reasons).toContain("quadriceps còn khoảng 36 giờ phục hồi");
    expect(result.reasons).toContain("biceps đã nghỉ 96 giờ");
  });
});
