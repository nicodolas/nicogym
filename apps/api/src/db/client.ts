import { drizzle } from "drizzle-orm/neon-http";

import * as authSchema from "./auth-schema.js";
import * as businessSchema from "./schema.js";

const schema = { ...authSchema, ...businessSchema };

export function createDatabase(connectionString: string) {
  return drizzle(connectionString, { schema });
}

export type Database = ReturnType<typeof createDatabase>;
