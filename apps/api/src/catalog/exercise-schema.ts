import { z } from "zod";

const boundedList = z.array(z.string().trim().min(2).max(240)).min(1).max(12);
const httpsUrl = z.string().url().max(2_048).refine(
  (value) => new URL(value).protocol === "https:",
  "https_required",
);

export const exerciseInputSchema = z.object({
  slug: z.string().trim().regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/).min(2).max(80),
  name: z.string().trim().min(2).max(120),
  category: z.string().trim().min(2).max(80),
  equipment: z.string().trim().min(2).max(120),
  prescription: z.string().trim().min(2).max(80),
  primaryMuscles: boundedList,
  summary: z.string().trim().min(5).max(600),
  setup: boundedList,
  steps: boundedList,
  cues: boundedList,
  mistakes: boundedList,
  safety: z.string().trim().min(3).max(600),
  sourceLabel: z.string().trim().min(2).max(120),
  sourceUrl: httpsUrl,
  videoUrl: httpsUrl.optional(),
  imageUrl: httpsUrl.optional(),
  videoId: z.string().trim().regex(/^[A-Za-z0-9_-]{11}$/).optional(),
  expectedUpdatedAt: z.string().datetime({ offset: true }).optional(),
}).strict();

export const exerciseImportSchema = z.object({
  mode: z.enum(["create", "update", "upsert"]),
  exercises: z.array(exerciseInputSchema).min(1).max(100),
}).strict().superRefine((value, context) => {
  const seen = new Set<string>();
  value.exercises.forEach((exercise, index) => {
    if (seen.has(exercise.slug)) {
      context.addIssue({
        code: "custom",
        message: "duplicate_slug",
        path: ["exercises", index, "slug"],
      });
    }
    seen.add(exercise.slug);
  });
});

export const importApplySchema = z.object({
  previewToken: z.string().min(16).max(512 * 1024),
}).strict();

export type ExerciseImport = z.infer<typeof exerciseImportSchema>;

