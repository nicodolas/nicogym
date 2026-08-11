import { readFile } from "node:fs/promises";
import { resolve } from "node:path";

import { neon } from "@neondatabase/serverless";
import { z } from "zod";

import { exerciseInputSchema } from "../src/catalog/exercise-schema.js";

const { DIRECT_URL } = z.object({
  DIRECT_URL: z.string().startsWith("postgresql://"),
}).parse(process.env);
if (DIRECT_URL.includes("-pooler.")) throw new Error("DIRECT_URL must use the non-pooled Neon endpoint");

const source = JSON.parse(
  await readFile(resolve(process.cwd(), "../client/assets/data/exercises.vi.json"), "utf8"),
) as Array<Record<string, unknown>>;
const exercises = source.map((record) => exerciseInputSchema.parse({
  slug: record.id,
  name: record.name,
  category: record.category,
  equipment: record.equipment,
  prescription: record.prescription,
  primaryMuscles: record.primaryMuscles,
  summary: record.summary,
  setup: record.setup,
  steps: record.steps,
  cues: record.cues,
  mistakes: record.mistakes,
  safety: record.safety,
  sourceLabel: record.sourceLabel,
  sourceUrl: record.sourceUrl,
  videoUrl: record.videoUrl,
  ...(record.videoId ? { videoId: record.videoId } : {}),
}));

const database = neon(DIRECT_URL);
await database.transaction((transaction) =>
  exercises.map((exercise) => transaction`
      insert into exercises (slug, name, equipment, instructions, common_mistakes, video_url, reviewed, content)
      values (${exercise.slug}, ${exercise.name}, ${exercise.equipment}, ${JSON.stringify(exercise.steps)}::jsonb,
        ${JSON.stringify(exercise.mistakes)}::jsonb, ${exercise.videoUrl ?? null}, true,
        ${JSON.stringify(exercise)}::jsonb)
      on conflict (slug) do update set name = excluded.name, equipment = excluded.equipment,
        instructions = excluded.instructions, common_mistakes = excluded.common_mistakes,
        video_url = excluded.video_url, reviewed = true, content = excluded.content,
        archived = false, updated_at = now()
    `),
  { isolationLevel: "Serializable" },
);
process.stdout.write(`Seeded ${exercises.length} curated exercises.\n`);
