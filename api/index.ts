type VercelHandler = (request: Request) => Response | Promise<Response>;

let productionHandler: VercelHandler | undefined;

export default async function vercelHandler(request: Request) {
  if (!productionHandler) {
    const [{ handle }, { createProductionApp }] = await Promise.all([
      import("hono/vercel"),
      import("../apps/api/src/production-app.js"),
    ]);
    productionHandler = handle(createProductionApp());
  }
  return productionHandler(request);
}
