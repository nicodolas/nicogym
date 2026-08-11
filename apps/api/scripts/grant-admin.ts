import { sql } from "drizzle-orm";
import { neon } from "@neondatabase/serverless";
import { z } from "zod";

import { createDatabase } from "../src/db/client.js";

const input = z.object({
  DIRECT_URL: z.string().startsWith("postgresql://"),
  ADMIN_EMAIL: z.string().email(),
}).parse(process.env);

if (input.DIRECT_URL.includes("-pooler.")) {
  throw new Error("DIRECT_URL must use the non-pooled Neon endpoint");
}

const database = createDatabase(input.DIRECT_URL);
const matched = await database.execute(sql`
  select id from "user" where lower(email) = lower(${input.ADMIN_EMAIL})
`);
if (matched.rows.length !== 1) {
  throw new Error(`Expected exactly one existing auth user; found ${matched.rows.length}`);
}
const authUserId = String(matched.rows[0]!.id);
const httpSql = neon(input.DIRECT_URL);
await httpSql.transaction((transaction) => [
  transaction`
    insert into profiles (auth_user_id, role)
    values (${authUserId}, 'admin')
    on conflict (auth_user_id) do update set role = 'admin', updated_at = now()
  `,
  transaction`
    insert into admin_audit_events (actor_auth_user_id, action, target, details)
    values (${authUserId}, 'grant_admin', ${authUserId}, ${JSON.stringify({ source: "local_grant_script" })}::jsonb)
  `,
], { isolationLevel: "Serializable" });

process.stdout.write("Admin role granted to exactly one existing account.\n");
