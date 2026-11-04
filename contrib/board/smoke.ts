// Smoke test for the dev board. Starts server.ts on a free port against this
// repository with a synthetic --lanes directory, checks the index, the change
// and baseline JSON, one change page with its sandboxed explainer, the
// explainer bytes, a baseline page, the first SSE event, the lanes panel, and
// that file changes under the lanes directory arrive as SSE pushes within two
// seconds. Exits nonzero on any failed expectation.
//
// It never writes to the repository. The only files it writes are the
// synthetic lane under a fresh temporary directory, removed on exit. That lane
// is test data, not a real worktree: its `.git` file names a gitdir that does
// not exist, so the panel must degrade to "could not be read" lines.

import { join, resolve } from "node:path";
import { readFileSync, mkdtempSync, mkdirSync, writeFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { connect } from "node:net";

const root = resolve(join(import.meta.dir, "..", ".."));
const lanesDir = mkdtempSync(join(tmpdir(), "writ-board-smoke-"));
const lane = join(lanesDir, "smoke-lane");
const plan = join(lane, ".superpowers", "sdd", "smoke-plan");
mkdirSync(plan, { recursive: true });
mkdirSync(join(lane, "verification"));
writeFileSync(join(lane, ".git"), `gitdir: ${join(lanesDir, "no-such-gitdir")}\n`);
writeFileSync(join(plan, "progress.md"), Array.from({ length: 14 }, (_, i) => `- entry-${String(i + 1).padStart(2, "0")}`).join("\n") + "\n");
writeFileSync(join(plan, "task-1-report.md"),
  "# Smoke report\n\nStatus: SMOKE\n\n<script>alert(1)</script>\n\n[bad](javascript:alert(1)) [ref](&#106;avascript:alert(1)) [ok](https://example.org/)\n");
mkdirSync(join(lanesDir, "not-a-worktree"));
const expected = "add-bend-runtime-host-profile";
let failures = 0;

function check(label: string, ok: boolean, detail = ""): void {
  console.log(`${ok ? "PASS" : "FAIL"} ${label}${detail ? ` (${detail})` : ""}`);
  if (!ok) failures++;
}

const proc = Bun.spawn([process.execPath, join(import.meta.dir, "server.ts"), "--root", root, "--lanes", lanesDir, "--port", "0"], {
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

/**
 * Opens an SSE stream over a plain TCP socket, decodes HTTP/1.1 chunked
 * transfer encoding, and returns `waitFor(needle, ms)`, which resolves with the
 * first complete `datastar-patch-elements` event containing `needle`, skipping
 * others, or `ok: false` after `ms`.
 */
function openStream(base: string, path: string) {
  const { hostname, port } = new URL(base);
  const sock = connect(Number(port), hostname);
  sock.write(`GET ${path} HTTP/1.1\r\nHost: ${hostname}\r\nAccept: text/event-stream\r\n\r\n`);
  let raw = Buffer.alloc(0);
  let headersDone = false;
  let body = "";
  let wake: (() => void) | null = null;
  const decoder = new TextDecoder();
  sock.on("data", (d: Buffer) => {
    raw = Buffer.concat([raw, d]);
    if (!headersDone) {
      const end = raw.indexOf("\r\n\r\n");
      if (end < 0) return;
      raw = raw.subarray(end + 4);
      headersDone = true;
    }
    // Chunked framing: "<hex size>\r\n<bytes>\r\n", repeated. Bun 1.1.8 sends
    // a chunk's closing CRLF only with the next write, so a chunk's bytes are
    // consumed as soon as they arrive and its CRLF is dropped when it does.
    while (true) {
      if (raw.length >= 2 && raw[0] === 13 && raw[1] === 10) raw = raw.subarray(2);
      const eol = raw.indexOf("\r\n");
      if (eol < 0) break;
      const size = parseInt(raw.subarray(0, eol).toString("latin1"), 16);
      if (Number.isNaN(size) || raw.length < eol + 2 + size) break;
      body += decoder.decode(raw.subarray(eol + 2, eol + 2 + size), { stream: true });
      raw = raw.subarray(eol + 2 + size);
    }
    wake?.();
  });
  sock.on("error", () => wake?.());
  async function waitFor(needle: string, ms: number): Promise<{ ok: boolean; after: number; text: string }> {
    const t0 = Date.now();
    while (Date.now() - t0 < ms) {
      const i = body.indexOf("\n\n");
      if (i >= 0) {
        const ev = body.slice(0, i);
        body = body.slice(i + 2);
        if (ev.startsWith("event: datastar-patch-elements") && ev.includes(needle)) return { ok: true, after: Date.now() - t0, text: ev };
        continue;
      }
      await new Promise<void>((r) => {
        wake = r;
        setTimeout(r, Math.max(1, ms - (Date.now() - t0)));
      });
      wake = null;
    }
    return { ok: false, after: Date.now() - t0, text: "" };
  }
  return { waitFor, close: () => sock.destroy() };
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
  check("runtime-profile tasks counted", (profile?.tasks.total ?? 0) > 0, `${profile?.tasks.done}/${profile?.tasks.total}`);
  check("runtime-profile lists explainer.html", profile?.html.includes("explainer.html") === true);

  const page = await (await fetch(`${base}/change/${expected}`)).text();
  const order = ["id=\"proposal\"", "id=\"design\"", "id=\"tasks\"", "id=\"spec-"].map((s) => page.indexOf(s));
  check("change page renders proposal, design, tasks, specs in order", order.every((i, k) => i >= 0 && (k === 0 || i > order[k - 1])), order.join(","));
  check("change page shows the proposal title", page.includes("Bend runtime host profile"));
  const frame = page.match(/<iframe [^>]*src="\/change\/[^"]+\/html\/explainer\.html"[^>]*>/)?.[0] ?? "";
  check("change page embeds the explainer in an iframe", frame !== "");
  check("explainer iframe is sandboxed without same-origin", frame.includes('sandbox="allow-scripts allow-popups"') && !frame.includes("allow-same-origin"));

  const explainer = await fetch(`${base}/change/${expected}/html/explainer.html`);
  const onDisk = readFileSync(join(root, "openspec", "changes", expected, "explainer.html"), "utf8");
  check("explainer served as-is with text/html", explainer.headers.get("content-type")?.startsWith("text/html") === true && (await explainer.text()) === onDisk);

  check("traversal is not served", (await fetch(`${base}/change/${expected}/html/..%2Fproposal.md`)).status === 404);
  check("POST is refused", (await fetch(`${base}/`, { method: "POST" })).status === 405);

  const baselines = (await (await fetch(`${base}/api/baselines`)).json()) as { name: string; traceability: boolean }[];
  const traced = baselines.find((b) => b.traceability);
  check("/api/baselines lists a baseline with traceability", traced !== undefined, `${baselines.length} baselines`);
  if (traced) {
    const spec = await fetch(`${base}/spec/${traced.name}`);
    const specHtml = await spec.text();
    check(`baseline page links traceability (${traced.name})`, spec.status === 200 && specHtml.includes(`/spec/${traced.name}/traceability`));
  }

  const lanesHtml = indexHtml.slice(indexHtml.indexOf('id="lanes"'));
  check("lanes panel lists the synthetic lane", lanesHtml.includes('id="lane-smoke-lane"'));
  check("lanes panel skips a directory without .git", lanesHtml.includes("<code>not-a-worktree</code>") && !lanesHtml.includes('id="lane-not-a-worktree"'));
  check("unreadable branch degrades to a note", lanesHtml.includes("branch could not be read"));
  check("ledger shows only the last ten lines", lanesHtml.includes("entry-14") && lanesHtml.includes("entry-05") && !lanesHtml.includes("entry-04"));
  check("report rendered in a collapsible section with its status", /<details id="lane-smoke-lane-[^"]*task-1-report-md"[^>]*>/.test(lanesHtml) && lanesHtml.includes("SMOKE"));
  check("report raw HTML is escaped", lanesHtml.includes("&lt;script&gt;") && !lanesHtml.includes("<script>alert"));
  check("unsafe link schemes become #", !/href="[^"]*(javascript|&#106;)/i.test(lanesHtml) && lanesHtml.includes('href="https://example.org/"'));

  const changeStream = openStream(base, `/events?page=${encodeURIComponent(`/change/${expected}`)}`);
  const first = await changeStream.waitFor('id="main"', 2000);
  check("/events sends a datastar-patch-elements full render", first.ok && first.text.includes(`change · ${expected}`));
  changeStream.close();

  // Live updates: an index stream must receive a lanes push after a change on
  // disk. The stream is read over a raw socket: Bun 1.1.8's server sends a
  // chunk's closing CRLF only with its next write, and Bun's own fetch reader
  // then holds the chunk back until that write (up to the 5 s keepalive),
  // which would time a correct push out. Browsers and curl deliver it at once.
  const live = openStream(base, "/events?page=%2F");
  const waitFor = live.waitFor;
  const initial = await waitFor('id="main"', 2000);
  check("index stream starts with a full render", initial.ok);

  writeFileSync(join(lane, "verification", "smoke-touch.txt"), "touched\n");
  const touched = await waitFor("smoke-touch.txt", 2000);
  check("touching a lane verification/ file pushes #lanes within 2 s", touched.ok && touched.text.includes('data: elements <section id="lanes"'), `${touched.after} ms`);
  check("lane push does not resend unchanged fragments", !touched.text.includes('id="index-tables"') && !touched.text.includes('id="nav"'));

  writeFileSync(join(plan, "task-1-report.md"), "# Smoke report\n\nStatus: EDITED\n\nedited body\n");
  const edited = await waitFor("edited body", 2000);
  check("editing a report pushes the new text within 2 s", edited.ok && edited.text.includes("EDITED"), `${edited.after} ms`);

  writeFileSync(join(plan, "task-2-report.md"), "# Second\n\nStatus: NEW\n");
  const added = await waitFor("task-2-report.md", 2000);
  check("a new report file is pushed within 2 s", added.ok, `${added.after} ms`);
  live.close();
} catch (err) {
  check("smoke run completed", false, String(err));
} finally {
  proc.kill();
  rmSync(lanesDir, { recursive: true, force: true });
}

console.log(failures === 0 ? "smoke: all checks passed" : `smoke: ${failures} check(s) failed`);
process.exit(failures === 0 ? 0 : 1);
