import { handle } from "hono/vercel";

import { createProductionApp } from "../src/production-app.js";

export default handle(createProductionApp());
