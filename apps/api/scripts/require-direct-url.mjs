import { resolve } from "node:path";

import { config } from "dotenv";

config({ path: resolve(process.cwd(), "../../.env") });

const directUrl = process.env.DIRECT_URL;
if (!directUrl) {
  throw new Error("DIRECT_URL is required for migrations; pooled DATABASE_URL is runtime-only.");
}

const parsed = new URL(directUrl);
if (parsed.protocol !== "postgresql:" || parsed.hostname.includes("-pooler.")) {
  throw new Error("DIRECT_URL must be a non-pooled PostgreSQL connection string.");
}

if (directUrl === process.env.DATABASE_URL) {
  throw new Error("DIRECT_URL must not reuse DATABASE_URL.");
}
