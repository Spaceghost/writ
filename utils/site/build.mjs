import { createHash } from "node:crypto";
import { mkdir, readFile, realpath, writeFile } from "node:fs/promises";
import { dirname, isAbsolute, relative, resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";

// The small text asset set is bundled into a Worker module. No build plugins,
// network dependencies, environment variables or secrets enter the package.
const source = dirname(fileURLToPath(import.meta.url));
const root = await realpath(resolve(source, "../.."));
if (process.argv.length !== 3)
  throw new Error(
    "Usage: node utils/site/build.mjs OUTPUT_DIRECTORY_OUTSIDE_CHECKOUT",
  );
const output = resolve(process.argv[2]);
await mkdir(output, { recursive: true });
const actualOutput = await realpath(output);
const relation = relative(root, actualOutput);
if (
  relation === "" ||
  (!relation.startsWith(`..${sep}`) && !isAbsolute(relation))
) {
  throw new Error("Generated website output must be outside the checkout");
}
const files = {
  "index.html": "text/html; charset=utf-8",
  "style.css": "text/css; charset=utf-8",
  "site.js": "text/javascript; charset=utf-8",
  "mark.svg": "image/svg+xml",
};
const assets = {};
const manifest = {};
for (const [name, type] of Object.entries(files)) {
  const body = await readFile(resolve(source, "public", name), "utf8");
  const sha256 = createHash("sha256").update(body).digest("hex");
  assets[name] = { type, body, etag: `"${sha256}"` };
  manifest[name] = { sha256, bytes: Buffer.byteLength(body), type };
}
const worker = await readFile(resolve(source, "worker.mjs"), "utf8");
const bundle = `${worker}\nconst assets = ${JSON.stringify(assets)};\nexport default createWorker(assets);\n`;
if (Buffer.byteLength(bundle) > 256 * 1024)
  throw new Error("Review packaging before exceeding the 256 KiB site budget");
await writeFile(resolve(output, "site-worker.mjs"), bundle);
await writeFile(
  resolve(output, "asset-manifest.json"),
  JSON.stringify(manifest, null, 2) + "\n",
);
console.log(
  `Built ${Object.keys(files).length} assets, ${Buffer.byteLength(bundle)} bytes: ${output}/site-worker.mjs`,
);
