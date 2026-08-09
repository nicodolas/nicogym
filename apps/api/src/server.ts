import { serve } from "@hono/node-server";

import { createProductionApp } from "./production-app.js";

const port = Number(process.env.PORT ?? 3000);
const app = createProductionApp();

serve({ fetch: app.fetch, port }, ({ port: activePort }) => {
  console.log(`NicoGym API listening on http://localhost:${activePort}`);
});
