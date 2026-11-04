// Smoke test for the dev board. Starts server.ts on a free port against this
// repository, checks the index, the change JSON, one change page with its
// explainer, the explainer bytes, a baseline page, and the first SSE event.
// Exits nonzero on any failed expectation. It reads only; it writes nothing.

import { join, resolve } from "node:path";
import { readFileSync } from "node:fs";

const root = resolve(join(import.meta.dir, "..", ".."));
const expected = "add-bend-runtime-host-profile";
let failures = 0;

function check(label: string, ok: boolean, detail = ""): void {
  console.log(`${ok ? "PASS" : "FAIL"} ${label}${detail ? ` (${detail})` : ""}`);
  if (!ok) failures++;
}

const proc = Bun.spawn([process.execPath, join(import.meta.dir, "server.ts"), "--root", root, "--port", "0"], {
  stdout: "pipe",
  stderr: "inherit",
});

async function baseUrl(): Promise<string> {
  const reader = proc.stdout.getReader();
  const decoder = new TextDecoder();
  let text = "";
  const deadline = Date.now() + 5000;
  while (Date.now() < deadline) {
    const { value, done } = await reader.read();
    if (done) break;
    text += decoder.decode(value);
    const m = text.match(/listening on (http:\/\/\S+?)\/?\s/);
    if (m) return m[1];
  }
  throw new Error(`server did not report a URL: ${text}`);
}

try {
  const base = await baseUrl();
  check("server binds to loopback", base.startsWith("http://127.0.0.1:"), base);

  const index = await fetch(`${base}/`);
  const indexHtml = await index.text();
  check("GET / is 200", index.status === 200);
  check("index lists the runtime-profile change", indexHtml.includes(`/change/${expected}`));
  check("index pins Datastar v1.0.4", indexHtml.includes("datastar@v1.0.4/bundles/datastar.js"));

  const api = await fetch(`${base}/api/changes`);
  const changes = (await api.json()) as { name: string; tasks: { done: number; total: number }; html: string[] }[];
  const profile = changes.find((c) => c.name === expected);
  check("/api/changes contains " + expected, profile !== undefined, `${changes.length} changes`);
  check("archive/ is skipped", !changes.some((c) => c.name === "archive"));
  check("runtime-profile tasks counted", profile?.tasks.total === 8, `${profile?.tasks.done}/${profile?.tasks.total}`);
  check("runtime-profile lists explainer.html", profile?.html.includes("explainer.html") === true);

  const page = await (await fetch(`${base}/change/${expected}`)).text();
  const order = ["id=\"proposal\"", "id=\"design\"", "id=\"tasks\"", "id=\"spec-"].map((s) => page.indexOf(s));
  check("change page renders proposal, design, tasks, specs in order", order.every((i, k) => i >= 0 && (k === 0 || i > order[k - 1])), order.join(","));
  check("change page shows the proposal title", page.includes("Bend runtime host profile"));
  check("change page embeds the explainer in an iframe", page.includes(`<iframe src="/change/${expected}/html/explainer.html"`));

  const explainer = await fetch(`${base}/change/${expected}/html/explainer.html`);
  const onDisk = readFileSync(join(root, "openspec", "changes", expected, "explainer.html"), "utf8");
  check("explainer served as-is with text/html", explainer.headers.get("content-type")?.startsWith("text/html") === true && (await explainer.text()) === onDisk);

  check("traversal is not served", (await fetch(`${base}/change/${expected}/html/..%2Fproposal.md`)).status === 404);
  check("POST is refused", (await fetch(`${base}/`, { method: "POST" })).status === 405);

  const spec = await fetch(`${base}/spec/data-model`);
  const specHtml = await spec.text();
  check("baseline page links traceability", spec.status === 200 && specHtml.includes("/spec/data-model/traceability"));

  const ac = new AbortController();
  const events = await fetch(`${base}/events?page=${encodeURIComponent(`/change/${expected}`)}`, { signal: ac.signal });
  const reader = events.body!.getReader();
  const first = new TextDecoder().decode((await reader.read()).value);
  check("/events sends a datastar-patch-elements full render", first.startsWith("event: datastar-patch-elements\n") && first.includes('id="main"'));
  ac.abort();
} catch (err) {
  check("smoke run completed", false, String(err));
} finally {
  proc.kill();
}

console.log(failures === 0 ? "smoke: all checks passed" : `smoke: ${failures} check(s) failed`);
process.exit(failures === 0 ? 0 : 1);
