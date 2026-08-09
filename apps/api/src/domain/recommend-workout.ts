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
  | { kind: "keep"; workoutId: string; reasons: string[] }
  | {
      kind: "suggest";
      scheduledWorkoutId: string;
      suggestedWorkoutId: string;
      requiresConfirmation: true;
      reasons: string[];
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
  const scheduledRemaining = remainingRecoveryHours(input.scheduled, input.recovery);
  if (scheduledRemaining === 0) {
    return { kind: "keep", workoutId: input.scheduled.id, reasons: [] };
  }

  const recoveredAlternative = input.alternatives.find(
    (workout) => remainingRecoveryHours(workout, input.recovery) === 0,
  );
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
    suggestedWorkoutId: recoveredAlternative.id,
    requiresConfirmation: true,
    reasons: blockedMuscle
      ? [`${blockedMuscle} needs about ${scheduledRemaining} more hours of recovery`]
      : [],
  };
}
