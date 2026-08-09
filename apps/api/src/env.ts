import { resolve } from "node:path";

import { config } from "dotenv";
import { z } from "zod";

config({ path: resolve(process.cwd(), "../../.env") });

const environmentSchema = z.object({
  DATABASE_URL: z.string().url().startsWith("postgresql://"),
  BETTER_AUTH_SECRET: z.string().min(32),
  BETTER_AUTH_URL: z.string().url().default("http://localhost:3000"),
  ALLOWED_ORIGINS: z.string().default("http://localhost:8080"),
});

export type Environment = z.infer<typeof environmentSchema>;

export function readEnvironment(): Environment {
  return environmentSchema.parse(process.env);
}
