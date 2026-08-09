import { betterAuth } from "better-auth";
import { drizzleAdapter } from "better-auth/adapters/drizzle";
import { bearer } from "better-auth/plugins";

import { createDatabase } from "./db/client.js";
import { readEnvironment } from "./env.js";

const environment = readEnvironment();
const database = createDatabase(environment.DATABASE_URL);

export const auth = betterAuth({
  appName: "NicoGym",
  baseURL: environment.BETTER_AUTH_URL,
  secret: environment.BETTER_AUTH_SECRET,
  trustedOrigins: environment.ALLOWED_ORIGINS.split(",").map((origin) => origin.trim()),
  database: drizzleAdapter(database, { provider: "pg" }),
  emailAndPassword: {
    enabled: true,
    minPasswordLength: 10,
  },
  plugins: [bearer({ requireSignature: true })],
});
