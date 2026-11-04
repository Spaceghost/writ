// Smoke test for the dev board. Starts server.ts on a free port against this
// repository with a synthetic --lanes directory, checks the index, the change
// and baseline JSON, one change page with its sandboxed explainer, the
// explainer bytes, a baseline page, the first SSE event, the lanes panel, and
// that file changes under the lanes directory arrive as SSE pushes within two
// seconds. It also checks that a forged Host header is refused and that a
// carriage return in a lane file name never reaches the SSE stream raw. Exits
// nonzero on any failed expectation.
//
// It never writes to the repository. The only files it writes are the
// synthetic lane under a fresh temporary directory, removed on exit. That lane
// is test data, not a real worktree: its `.git` file names a gitdir that does
// not exist, so the panel must degrade to "could not be read" lines.

import { join, resolve } from "node:path";
import { readFileSync, mkdtempSync, mkdirSync, writeFileSync, appendFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { connect } from "node:net";

const root = resolve(join(import.meta.dir, "..", ".."));
// Created inside the try below so that a failure while building the fixture or
// spawning the server still reaches the cleanup in `finally`.
let lanesDir: string | undefined;
let proc: ReturnType<typeof spawnServer> | undefined;
/**
 * Synthetic verification file name with a carriage return followed by text
 * shaped like an SSE field. If the CR reached the stream raw it would end the
 * data line and start a `data: elements` line of its own.
 */
const CR_NAME = 'cr-probe\rdata: elements <b id="nav">x.txt';
const expected = "add-bend-runtime-host-profile";
let failures = 0;

function check(label: string, ok: boolean, detail = ""): void {
  console.log(`${ok ? "PASS" : "FAIL"} ${label}${detail ? ` (${detail})` : ""}`);
  if (!ok) failures++;
}

function spawnServer(lanes: string) {
  return Bun.spawn([process.execPath, join(import.meta.dir, "server.ts"), "--root", root, "--lanes", lanes, "--port", "0"], {
    stdout: "pipe",
    stderr: "inherit",
  });
}

async function baseUrl(): Promise<string> {
  const reader = proc!.stdout.getReader();
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
  sock.write(`GET ${path} HTTP/1.1\r\nHost: ${hostname}:${port}\r\nAccept: text/event-stream\r\n\r\n`);
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

/** Status code of a GET sent over a raw socket with exactly the given Host header. */
function statusWithHost(base: string, path: string, host: string): Promise<number> {
  const { hostname, port } = new URL(base);
  return new Promise((done) => {
    const sock = connect(Number(port), hostname);
    let text = "";
    const finish = () => {
      sock.destroy();
      done(Number(text.match(/^HTTP\/1\.1 (\d{3})/)?.[1] ?? 0));
    };
    sock.write(`GET ${path} HTTP/1.1\r\nHost: ${host}\r\nConnection: close\r\n\r\n`);
    sock.on("data", (d: Buffer) => {
      text += d.toString("latin1");
      if (text.includes("\r\n")) finish();
    });
    sock.on("error", finish);
    setTimeout(finish, 2000);
  });
}

try {
  lanesDir = mkdtempSync(join(tmpdir(), "writ-board-smoke-"));
  const lane = join(lanesDir, "smoke-lane");
  const plan = join(lane, ".superpowers", "sdd", "smoke-plan");
  mkdirSync(plan, { recursive: true });
  mkdirSync(join(lane, "verification"));
  writeFileSync(join(lane, ".git"), `gitdir: ${join(lanesDir, "no-such-gitdir")}\n`);
  writeFileSync(join(lane, "verification", CR_NAME), "synthetic test data\n");
  writeFileSync(join(plan, "progress.md"),
    "# SDD ledger — plan: docs/superpowers/plans/smoke.md\nTask 1: review Needs fixes. Fix round 1 dispatched (base 0000000).\n"
    + Array.from({ length: 14 }, (_, i) => `- entry-${String(i + 1).padStart(2, "0")}`).join("\n") + "\n");
  mkdirSync(join(lane, "docs", "superpowers", "plans"), { recursive: true });
  writeFileSync(join(lane, "docs", "superpowers", "plans", "smoke.md"), `# Plan: smoke\n\nSpec: \`openspec/changes/${expected}/\` (synthetic).\n`);
  // The committed record: keyed by the plan; its ledger's Branch line cannot
  // match (the synthetic lane has no readable branch), so the name suffix does.
  const rec = join(lane, "docs", "superpowers", "records", "2026-11-04-smoke-lane");
  mkdirSync(rec, { recursive: true });
  writeFileSync(join(rec, "activity.log"), "2026-11-04T10:00:00Z\timplementer\tread the brief\n2026-11-04T10:05:00Z\timplementer\tstarted the probe build\n");
  writeFileSync(join(rec, "progress.md"),
    "# SDD ledger — plan: docs/superpowers/plans/smoke.md\nTask 1: review Needs fixes. Fix round 1 dispatched (base 0000000).\n"
    + Array.from({ length: 14 }, (_, i) => `- entry-${String(i + 1).padStart(2, "0")}`).join("\n") + "\n");
  writeFileSync(join(rec, "task-1-report.md"),
    "# Smoke report\n\nStatus: SMOKE\n\n<script>alert(1)</script>\n\n[bad](javascript:alert(1)) [ref](&#106;avascript:alert(1)) [ok](https://example.org/)\n");
  writeFileSync(join(rec, "task-1-review.md"), "# Review\n\nAssessment: Approved (smoke)\n");
  writeFileSync(join(plan, "task-1-report.md"),
    "# Smoke report\n\nStatus: SMOKE\n\n<script>alert(1)</script>\n\n[bad](javascript:alert(1)) [ref](&#106;avascript:alert(1)) [ok](https://example.org/)\n");
  mkdirSync(join(lanesDir, "not-a-worktree"));
  proc = spawnServer(lanesDir);

  const base = await baseUrl();
  check("server binds to loopback", base.startsWith("http://127.0.0.1:"), base);

  const index = await fetch(`${base}/`);
  const indexHtml = await index.text();
  check("GET / is 200", index.status === 200);
  check("index lists the runtime-profile change", indexHtml.includes(`/change/${expected}`));
  check("index pins Datastar v1.0.4", indexHtml.includes("datastar@v1.0.4/bundles/datastar.js"));
  check("index delegates link clicks to the quick-view panel", indexHtml.includes(`data-signals:panel__ifmissing="''"`) && indexHtml.includes("$panel = a.pathname") && indexHtml.includes('<aside id="panel" class="panel"') && indexHtml.includes('<div id="panel-backdrop" class="panel-backdrop"') && indexHtml.includes(`data-on:click="$panel = ''"`) && indexHtml.includes('data-attr:src="$panel'));
  const embedded = await fetch(`${base}/change/${expected}?embed=1`);
  const embeddedHtml = await embedded.text();
  check("?embed=1 renders a page without the header and nav, with its own live stream", embedded.status === 200 && embeddedHtml.includes('<body class="embed"') && !embeddedHtml.includes('<nav id="nav"') && !embeddedHtml.includes('class="top"') && embeddedHtml.includes("/events?page="));
  check("a plain page keeps the header and nav", (await (await fetch(`${base}/change/${expected}`)).text()).includes('<nav id="nav"'));

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
  check("standalone explainer carries the CSP sandbox", explainer.headers.get("content-security-policy") === "sandbox allow-scripts allow-popups");

  check("traversal is not served", (await fetch(`${base}/change/${expected}/html/..%2Fproposal.md`)).status === 404);
  check("POST is refused", (await fetch(`${base}/`, { method: "POST" })).status === 405);
  const { port } = new URL(base);
  const forged = await statusWithHost(base, "/api/lanes", "evil.example");
  const forgedPort = await statusWithHost(base, "/", `evil.example:${port}`);
  const real = await statusWithHost(base, "/", `127.0.0.1:${port}`);
  const localhost = await statusWithHost(base, "/", `localhost:${port}`);
  check("forged Host header is refused with 403", forged === 403 && forgedPort === 403, `${forged}, ${forgedPort}`);
  check("loopback Host header is served with 200", real === 200 && localhost === 200, `${real}, ${localhost}`);

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

  // With --lanes the lanes panel precedes the tables, so slice to the section's end.
  const tablesStart = indexHtml.indexOf('id="index-tables"');
  const tables = indexHtml.slice(tablesStart, indexHtml.indexOf("</section>", tablesStart));
  check("index shows summary tiles", tables.includes('class="tiles"') && tables.includes("Being worked on"));
  // The row starts with the chevron cell, before the change link.
  const linkAt = tables.indexOf(`/change/${expected}"`);
  const rowStart = tables.lastIndexOf("<tr", linkAt);
  const row = tables.slice(rowStart, tables.indexOf("</tr>", rowStart));
  check("the change the lane's plan names carries the lane's chip", row.includes('class="chip chip-active"') && row.includes("#lane-smoke-lane"));
  check("the chip shows the ledger phase and an age", row.includes("Task 1 · fix round") && /chip-age">\d+ (s|min)</.test(row));
  const sig = `t_${expected.replace(/-/g, "_")}`;
  check("the change row starts with a chevron that flips its task signal", row.includes(`<button type="button" class="chev" aria-label="Show the task list" aria-controls="tasks-${expected}" data-on:click="$${sig} = !$${sig}"`) && row.includes(`data-class:open="$${sig}"`));
  const taskRowStart = tables.indexOf(`<tr id="tasks-${expected}" class="taskrow"`);
  const taskRowHtml = tables.slice(taskRowStart, tables.indexOf("</tr>", taskRowStart));
  check("the task row follows the change row, spans the table, and is shown by the signal", taskRowStart > rowStart && taskRowHtml.includes(`data-show="$${sig}"`) && taskRowHtml.includes('data-preserve-attr="style"') && taskRowHtml.includes('<td colspan="6">'));
  check("open tasks come first, done ones behind a nested toggle", taskRowHtml.indexOf('class="task task-open"') < taskRowHtml.indexOf('class="task task-done"') && taskRowHtml.includes(`<details id="done-${expected}" class="donelist" data-preserve-attr="open"><summary>`));
  check("the table declares one signal per change with a task list", tables.includes(`data-signals__ifmissing=`) && tables.includes(`&quot;${sig}&quot;:false`));
  const asig = `a_${expected.replace(/-/g, "_")}`;
  check("the change row carries an activity icon with the last lines as its tooltip", row.includes(`class="act" aria-label="Show recent activity" aria-controls="activity-${expected}"`) && row.includes("started the probe build") && row.includes(`data-on:click="$${asig} = !$${asig}"`));
  const tickStart = tables.indexOf(`<tr class="tickerrow">`, rowStart);
  const tick = tables.slice(tickStart, tables.indexOf("</tr>", tickStart));
  check("a ticker row under the change shows its newest activity line with a content-keyed id", tickStart > rowStart && /<p id="tick-add-bend-runtime-host-profile-[a-z0-9]+" class="ticker">/.test(tick) && tick.includes("started the probe build") && !tick.includes("read the brief"));
  const actStart = tables.indexOf(`<tr id="activity-${expected}" class="taskrow activityrow"`);
  const actRow = tables.slice(actStart, tables.indexOf("</tr>", actStart));
  check("the activity row follows the change row and lists the lane's lines newest-first in a reversed list", actStart > rowStart && actRow.includes(`data-show="$${asig}"`) && actRow.includes('<ol class="log" reversed>') && actRow.indexOf("started the probe build") < actRow.indexOf("read the brief") && actRow.includes("smoke-lane · implementer"));
  check("changes with no task and no lane are collapsed", tables.includes('id="rest-changes"') && /\d+ more changes with no task done and no lane/.test(tables));
  check("lane card shows its status line and the change it is on", lanesHtml.includes('class="lane-phase">Task 1 · fix round') && lanesHtml.includes(`lane-changes">on <a href="/change/${expected}"`));
  check("lane card's activity feed is newest-first in the DOM inside a reversed list (rendered oldest to newest, scrolled to the end)", lanesHtml.includes('<ol class="log" reversed>') && lanesHtml.indexOf("started the probe build") < lanesHtml.indexOf("read the brief") && lanesHtml.includes('log-who">implementer'));
  check("the committed records/<plan>/ record is read instead of the sdd workspace", lanesHtml.includes("docs/superpowers/records/2026-11-04-smoke-lane/progress.md") && !lanesHtml.includes(".superpowers/sdd/smoke-plan/progress.md"));
  check("reviewer reports are listed after task reports", /<details id="lane-smoke-lane-[^"]*task-1-review-md" class="report review"/.test(lanesHtml) && lanesHtml.includes("Approved (smoke)"));
  check("/api/lanes carries the parsed activity and phase", (await (await fetch(`${base}/api/lanes`)).text()).includes('"label":"fix"'));

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
  check("a CR in a lane file name never reaches the stream raw",
    initial.text.includes("cr-probe") && !initial.text.includes("\r") && !initial.text.includes('\ndata: elements <b id="nav">'));

  writeFileSync(join(lane, "verification", "smoke-touch.txt"), "touched\n");
  const touched = await waitFor("smoke-touch.txt", 2000);
  check("touching a lane verification/ file pushes #lanes within 2 s", touched.ok && touched.text.includes('data: elements <section id="lanes"'), `${touched.after} ms`);
  check("lane push does not resend unchanged fragments", !touched.text.includes('id="index-tables"') && !touched.text.includes('id="nav"'));

  writeFileSync(join(rec, "task-1-report.md"), "# Smoke report\n\nStatus: EDITED\n\nedited body\n");
  const edited = await waitFor("edited body", 2000);
  check("editing a report pushes the new text within 2 s", edited.ok && edited.text.includes("EDITED"), `${edited.after} ms`);

  appendFileSync(join(rec, "activity.log"), "2026-11-04T10:09:00Z\timplementer\tprobe printed hi, writing the evidence\n");
  // The chip tooltip on the index tables and the lane's feed both carry the
  // line; the tables fragment is sent first, then the lanes panel.
  const appendedTables = await waitFor("writing the evidence", 2000);
  const appendedLanes = await waitFor("writing the evidence", 2000);
  check("appending to the record's activity.log pushes the index tables within 2 s", appendedTables.ok && appendedTables.text.includes('data: elements <section id="index-tables"'), `${appendedTables.after} ms`);
  check("the pushed tables carry the new line as a new ticker element", /<p id="tick-add-bend-runtime-host-profile-[a-z0-9]+" class="ticker"><span class="log-at">10:09:00<\/span>/.test(appendedTables.text) && appendedTables.text.includes("writing the evidence"));
  check("appending to the record's activity.log pushes the lane feed within 2 s", appendedLanes.ok && appendedLanes.text.includes('data: elements <section id="lanes"'), `${appendedLanes.after} ms`);

  writeFileSync(join(rec, "task-2-report.md"), "# Second\n\nStatus: NEW\n");
  const added = await waitFor("task-2-report.md", 2000);
  check("a new report file is pushed within 2 s", added.ok, `${added.after} ms`);
  live.close();
} catch (err) {
  check("smoke run completed", false, String(err));
} finally {
  proc?.kill();
  if (lanesDir !== undefined) rmSync(lanesDir, { recursive: true, force: true });
}

console.log(failures === 0 ? "smoke: all checks passed" : `smoke: ${failures} check(s) failed`);
process.exit(failures === 0 ? 0 : 1);
