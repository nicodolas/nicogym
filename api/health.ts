import { handle } from "hono/vercel";

import { createProductionApp } from "../apps/api/src/production-app.js";

export default handle(createProductionApp());
