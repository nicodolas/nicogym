export interface WorkoutOption {
  id: string;
  muscleGroups: string[];
}

export interface RecoveryState {
  hoursSinceTraining: number;
  minimumHours: number;
}

interface RecommendationInput {
  scheduled: WorkoutOption;
  alternatives: WorkoutOption[];
  recovery: Record<string, RecoveryState>;
}

export type WorkoutRecommendation =
  | { kind: "keep"; workoutId: string; reasons: string[]; usedRecoveryDefaults?: true }
  | {
      kind: "suggest";
      scheduledWorkoutId: string;
      suggestedWorkoutId: string;
      requiresConfirmation: true;
      reasons: string[];
      usedRecoveryDefaults?: true;
    };

function remainingRecoveryHours(
  workout: WorkoutOption,
  recovery: Record<string, RecoveryState>,
): number {
  return Math.max(
    0,
    ...workout.muscleGroups.map((muscle) => {
      const state = recovery[muscle];
      return state ? state.minimumHours - state.hoursSinceTraining : 0;
    }),
  );
}

export function recommendWorkout(input: RecommendationInput): WorkoutRecommendation {
  if (Object.keys(input.recovery).length === 0) {
    return {
      kind: "keep",
      workoutId: input.scheduled.id,
      reasons: ["Chưa có lịch sử tập, tạm dùng mặc định"],
      usedRecoveryDefaults: true,
    };
  }
  const scheduledRemaining = remainingRecoveryHours(input.scheduled, input.recovery);
  if (scheduledRemaining === 0) {
    return { kind: "keep", workoutId: input.scheduled.id, reasons: [] };
  }

  const recoveredAlternative = input.alternatives
    .filter((workout) => remainingRecoveryHours(workout, input.recovery) === 0)
    .map((workout) => ({
      workout,
      restedHours: Math.min(
        ...workout.muscleGroups.map((muscle) => input.recovery[muscle]?.hoursSinceTraining ?? 0),
      ),
    }))
    .sort((left, right) => right.restedHours - left.restedHours || left.workout.id.localeCompare(right.workout.id))[0];
  if (!recoveredAlternative) {
    return { kind: "keep", workoutId: input.scheduled.id, reasons: [] };
  }

  const blockedMuscle = input.scheduled.muscleGroups.find((muscle) => {
    const state = input.recovery[muscle];
    return state && state.hoursSinceTraining < state.minimumHours;
  });

  return {
    kind: "suggest",
    scheduledWorkoutId: input.scheduled.id,
    suggestedWorkoutId: recoveredAlternative.workout.id,
    requiresConfirmation: true,
    reasons: [
      ...(blockedMuscle ? [`${blockedMuscle} còn khoảng ${scheduledRemaining} giờ phục hồi`] : []),
      ...recoveredAlternative.workout.muscleGroups.map((muscle) =>
        `${muscle} đã nghỉ ${input.recovery[muscle]?.hoursSinceTraining ?? 0} giờ`),
    ],
  };
}
