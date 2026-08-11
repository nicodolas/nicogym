import { createProductionApp } from "../src/production-app.js";

const app = createProductionApp();

export default {
  fetch(request: Request) {
    return app.fetch(request);
  },
};
