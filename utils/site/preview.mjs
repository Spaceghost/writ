import { createServer } from "node:http";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";

if (!process.argv[2])
  throw new Error("Usage: node utils/site/preview.mjs BUILT_WORKER [PORT]");
const { default: worker } = await import(
  pathToFileURL(resolve(process.argv[2]))
);
const port = Number(process.argv[3] || 4173);
const server = createServer(async (request, response) => {
  try {
    const input = new Request(
      new URL(request.url, `http://127.0.0.1:${port}`),
      {
        method: request.method,
        headers: request.headers,
      },
    );
    const output = await worker.fetch(input);
    response.writeHead(output.status, Object.fromEntries(output.headers));
    response.end(Buffer.from(await output.arrayBuffer()));
  } catch (error) {
    console.error(error);
    response.writeHead(500).end("Preview error");
  }
});
server.listen(port, "127.0.0.1", () =>
  console.log(`Local: http://127.0.0.1:${port}/writ/`),
);
for (const signal of ["SIGINT", "SIGTERM"])
  process.on(signal, () => server.close());
