type VercelHandler = (request: Request) => Response | Promise<Response>;

let productionHandler: VercelHandler | undefined;

export default {
  async fetch(request: Request) {
    if (!productionHandler) {
      const { createProductionApp } = await import(
        "../apps/api/src/production-app.js"
      );
      const app = createProductionApp();
      productionHandler = (incomingRequest) => app.fetch(incomingRequest);
    }
    return productionHandler(request);
  },
};
