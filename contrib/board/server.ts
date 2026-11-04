// Writ dev board: a read-only viewer for the OpenSpec suite.
//
// Public entry point: `bun contrib/board/server.ts --root <repo> [--lanes <dir>]
// [--port 4242] [--host 127.0.0.1]`. Everything else in this file is an
// implementation helper.
//
// Read-only contract: the server only reads files below --root and --lanes. It
// never writes, never runs a mutating git command, and never executes a file it
// reads. Markdown is rendered with raw HTML escaped; explainer pages are served
// byte-for-byte as text/html only when their name appears in the scanned change
// directory. Request paths are matched against scanned names, never joined into
// a filesystem path unchecked, so a request cannot reach outside the scan.
//
// The board makes no claim about Writ's behavior, proofs, or verification. It
// shows what the documents say, including checkbox counts as written.

import { readdirSync, readFileSync, existsSync, statSync } from "node:fs";
import { join, resolve, posix } from "node:path";
import { Marked, type Tokens } from "marked";
import * as T from "./template.ts";

// ---------------------------------------------------------------- flags

type Flags = { root: string; lanes: string | null; port: number; host: string };

function parseFlags(argv: string[]): Flags {
  const flags: Flags = { root: ".", lanes: null, port: 4242, host: "127.0.0.1" };
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    const value = argv[i + 1];
    const need = () => {
      if (value === undefined) fail(`${arg} needs a value`);
      i++;
      return value!;
    };
    if (arg === "--root") flags.root = need();
    else if (arg === "--lanes") flags.lanes = need();
    else if (arg === "--port") flags.port = Number(need());
    else if (arg === "--host") flags.host = need();
    else fail(`unknown argument: ${arg}`);
  }
  if (!Number.isInteger(flags.port) || flags.port < 0 || flags.port > 65535) fail("--port must be 0..65535");
  flags.root = resolve(flags.root);
  if (flags.lanes !== null) flags.lanes = resolve(flags.lanes);
  if (!existsSync(join(flags.root, "openspec"))) fail(`no openspec/ directory under ${flags.root}`);
  return flags;
}

function fail(message: string): never {
  console.error(`board: ${message}`);
  process.exit(2);
}

// ---------------------------------------------------------------- scanning

/** Names that may appear in a URL; anything else is treated as not found. */
const SAFE_NAME = /^[A-Za-z0-9][A-Za-z0-9._-]*$/;
const SAFE_HTML = /^[A-Za-z0-9][A-Za-z0-9._-]*\.html$/;

export type Baseline = {
  name: string;
  title: string;
  requirements: number;
  traceability: boolean;
};

export type Change = {
  name: string;
  title: string;
  status: string;
  dependsOn: string[];
  tasks: { done: number; total: number };
  html: string[];
  hasDesign: boolean;
  specs: string[];
};

function readText(path: string): string | null {
  try {
    return readFileSync(path, "utf8");
  } catch {
    return null;
  }
}

function subdirs(dir: string): string[] {
  try {
    return readdirSync(dir, { withFileTypes: true })
      .filter((d) => d.isDirectory() && SAFE_NAME.test(d.name))
      .map((d) => d.name)
      .sort();
  } catch {
    return [];
  }
}

function firstHeading(markdown: string | null, fallback: string): string {
  const m = markdown?.match(/^#\s+(.+)$/m);
  return m ? m[1].trim() : fallback;
}

/** Counts GitHub-style task boxes as written; a checked box is not evidence. */
export function countTasks(markdown: string | null): { done: number; total: number } {
  let done = 0;
  let total = 0;
  for (const m of (markdown ?? "").matchAll(/^\s*[-*] \[([ xX])\]/gm)) {
    total++;
    if (m[1] !== " ") done++;
  }
  return { done, total };
}

/**
 * Reads only `x-status` and `x-depends-on` from `.openspec.yaml`. The files use
 * a scalar status and either `[]`, an inline list, or a block list of names.
 * Anything else is ignored rather than guessed.
 */
export function parseMeta(yaml: string | null): { status: string; dependsOn: string[] } {
  let status = "unknown";
  const dependsOn: string[] = [];
  const lines = (yaml ?? "").split(/\r?\n/);
  for (let i = 0; i < lines.length; i++) {
    const s = lines[i].match(/^x-status:\s*(\S+)\s*$/);
    if (s) status = s[1].replace(/^["']|["']$/g, "");
    const d = lines[i].match(/^x-depends-on:\s*(.*)$/);
    if (!d) continue;
    const inline = d[1].trim();
    if (inline.startsWith("[")) {
      for (const item of inline.replace(/^\[|\]$/g, "").split(",")) {
        const name = item.trim().replace(/^["']|["']$/g, "");
        if (name) dependsOn.push(name);
      }
      continue;
    }
    for (let j = i + 1; j < lines.length; j++) {
      const item = lines[j].match(/^\s+-\s+(.+?)\s*$/);
      if (!item) break;
      dependsOn.push(item[1].replace(/^["']|["']$/g, ""));
    }
  }
  return { status, dependsOn };
}

function scanBaselines(root: string): Baseline[] {
  const specs = join(root, "openspec", "specs");
  return subdirs(specs).flatMap((name) => {
    const text = readText(join(specs, name, "spec.md"));
    if (text === null) return [];
    return [{
      name,
      title: firstHeading(text, name).replace(/\s+Specification$/, ""),
      requirements: (text.match(/^###\s+Requirement:/gm) ?? []).length,
      traceability: existsSync(join(root, "openspec", "traceability", `${name}.md`)),
    }];
  });
}

function scanChanges(root: string): Change[] {
  const changes = join(root, "openspec", "changes");
  return subdirs(changes)
    .filter((name) => name !== "archive")
    .map((name) => {
      const dir = join(changes, name);
      const meta = parseMeta(readText(join(dir, ".openspec.yaml")));
      let html: string[] = [];
      try {
        html = readdirSync(dir).filter((f) => SAFE_HTML.test(f) && statSync(join(dir, f)).isFile()).sort();
      } catch {}
      return {
        name,
        title: firstHeading(readText(join(dir, "proposal.md")), name),
        status: meta.status,
        dependsOn: meta.dependsOn,
        tasks: countTasks(readText(join(dir, "tasks.md"))),
        html,
        hasDesign: existsSync(join(dir, "design.md")),
        specs: subdirs(join(dir, "specs")).filter((c) => existsSync(join(dir, "specs", c, "spec.md"))),
      };
    });
}

/** Task 1 lists lane worktree names only; Task 2 fills in branch and reports. */
function scanLanes(lanes: string | null): string[] {
  if (lanes === null) return [];
  return subdirs(lanes).filter((d) => existsSync(join(lanes, d, ".git")));
}

// ---------------------------------------------------------------- markdown

/**
 * Renders repository markdown. Raw HTML in the source is escaped, not passed
 * through, so a document cannot inject script into the board. Relative links
 * that point at OpenSpec documents are rewritten to the matching board route;
 * other relative links are left as written.
 */
function renderMarkdown(source: string, repoPath: string): string {
  const md = new Marked({ gfm: true });
  md.use({
    renderer: {
      html({ text }: Tokens.HTML | Tokens.Tag) {
        return T.esc(text);
      },
    },
    walkTokens(token) {
      if (token.type === "link") (token as Tokens.Link).href = boardHref((token as Tokens.Link).href, repoPath);
    },
  });
  return md.parse(source, { async: false }) as string;
}

export function boardHref(href: string, repoPath: string): string {
  if (/^([a-z][a-z0-9+.-]*:|#|\/)/i.test(href)) return href;
  const [pathPart, hash = ""] = href.split("#", 2);
  const target = posix.normalize(posix.join(posix.dirname(repoPath), pathPart));
  const frag = hash ? `#${hash}` : "";
  let m: RegExpMatchArray | null;
  if ((m = target.match(/^openspec\/changes\/([^/]+)\/specs\/([^/]+)\/spec\.md$/))) return `/change/${m[1]}#spec-${m[2]}`;
  if ((m = target.match(/^openspec\/changes\/([^/]+)\/([^/]+\.html)$/))) return `/change/${m[1]}/html/${m[2]}`;
  if ((m = target.match(/^openspec\/changes\/([^/]+)(\/(proposal|design|tasks)\.md)?\/?$/))) return `/change/${m[1]}${frag}`;
  if ((m = target.match(/^openspec\/specs\/([^/]+)(\/spec\.md)?\/?$/))) return `/spec/${m[1]}${frag}`;
  if ((m = target.match(/^openspec\/traceability\/([^/]+)\.md$/))) return `/spec/${m[1]}/traceability${frag}`;
  return href;
}

function mdFile(root: string, repoPath: string): string | null {
  const text = readText(join(root, repoPath));
  return text === null ? null : renderMarkdown(text, repoPath);
}

// ---------------------------------------------------------------- views

/** One rendered page: its title and the two fragments the SSE stream patches. */
type View = { status: number; title: string; nav: string; main: string };

function view(flags: Flags, page: string): View {
  const changes = scanChanges(flags.root);
  const baselines = scanBaselines(flags.root);
  const nav = T.nav(changes, page);
  const notFound: View = { status: 404, title: "Not found", nav, main: T.notFound(page) };

  if (page === "/") {
    return { status: 200, title: "Writ board", nav, main: T.index(baselines, changes, flags.lanes, scanLanes(flags.lanes)) };
  }
  let m: RegExpMatchArray | null;
  if ((m = page.match(/^\/change\/([^/]+)$/))) {
    const change = changes.find((c) => c.name === m![1]);
    if (!change) return notFound;
    const base = `openspec/changes/${change.name}`;
    const docs = {
      proposal: mdFile(flags.root, `${base}/proposal.md`),
      design: mdFile(flags.root, `${base}/design.md`),
      tasks: mdFile(flags.root, `${base}/tasks.md`),
      specs: change.specs.map((c) => ({ capability: c, html: mdFile(flags.root, `${base}/specs/${c}/spec.md`) ?? "" })),
    };
    return { status: 200, title: change.title, nav, main: T.changePage(change, docs, changes) };
  }
  if ((m = page.match(/^\/spec\/([^/]+)(\/traceability)?$/))) {
    const baseline = baselines.find((b) => b.name === m![1]);
    if (!baseline) return notFound;
    const trace = m[2] !== undefined;
    if (trace && !baseline.traceability) return notFound;
    const repoPath = trace ? `openspec/traceability/${baseline.name}.md` : `openspec/specs/${baseline.name}/spec.md`;
    const html = mdFile(flags.root, repoPath);
    if (html === null) return notFound;
    return { status: 200, title: baseline.title, nav, main: T.specPage(baseline, html, trace, repoPath) };
  }
  return notFound;
}

// ---------------------------------------------------------------- SSE

const encoder = new TextEncoder();

/** Formats one Datastar `datastar-patch-elements` event (outer morph by id). */
export function patchElements(html: string): string {
  const lines = html.split("\n").map((l) => `data: elements ${l}`).join("\n");
  return `event: datastar-patch-elements\n${lines}\n\n`;
}

/**
 * One SSE connection per client. On connect it sends the full render of the
 * client's page (so a reconnect always resynchronizes) and then holds the
 * connection with comment heartbeats. Task 2 adds file watching and pushes.
 */
function events(flags: Flags, page: string): Response {
  let timer: ReturnType<typeof setInterval> | undefined;
  const stream = new ReadableStream({
    start(controller) {
      const v = view(flags, page);
      controller.enqueue(encoder.encode(patchElements(v.nav) + patchElements(v.main)));
      // Comments keep proxies and Bun's idle timeout from closing a quiet stream.
      timer = setInterval(() => {
        try {
          controller.enqueue(encoder.encode(": keepalive\n\n"));
        } catch {
          clearInterval(timer);
        }
      }, 5000);
    },
    cancel() {
      clearInterval(timer);
    },
  });
  return new Response(stream, {
    headers: { "content-type": "text/event-stream", "cache-control": "no-cache", connection: "keep-alive" },
  });
}

// ---------------------------------------------------------------- routes

const CSS_PATH = join(import.meta.dir, "board.css");

function handle(flags: Flags, req: Request): Response {
  if (req.method !== "GET" && req.method !== "HEAD") return new Response("read-only\n", { status: 405 });
  const url = new URL(req.url);
  let path: string;
  try {
    path = decodeURIComponent(url.pathname);
  } catch {
    return new Response("bad path\n", { status: 400 });
  }
  if (path.length > 1) path = path.replace(/\/+$/, "");

  if (path === "/board.css") {
    return new Response(readFileSync(CSS_PATH), { headers: { "content-type": "text/css; charset=utf-8" } });
  }
  if (path === "/api/changes") {
    return Response.json(scanChanges(flags.root));
  }
  if (path === "/api/baselines") {
    return Response.json(scanBaselines(flags.root));
  }
  if (path === "/events") {
    return events(flags, url.searchParams.get("page") ?? "/");
  }
  const explainer = path.match(/^\/change\/([^/]+)\/html\/([^/]+)$/);
  if (explainer) {
    // Served as-is: the explainers are standalone pages with their own styles.
    const change = scanChanges(flags.root).find((c) => c.name === explainer[1]);
    if (!change || !change.html.includes(explainer[2])) return new Response("not found\n", { status: 404 });
    const file = join(flags.root, "openspec", "changes", change.name, explainer[2]);
    return new Response(readFileSync(file), { headers: { "content-type": "text/html; charset=utf-8" } });
  }
  const v = view(flags, path);
  return new Response(T.shell(v.title, v.nav, v.main, path), {
    status: v.status,
    headers: { "content-type": "text/html; charset=utf-8" },
  });
}

if (import.meta.main) {
  const flags = parseFlags(process.argv.slice(2));
  const server = Bun.serve({
    hostname: flags.host,
    port: flags.port,
    fetch: (req) => handle(flags, req),
  });
  console.log(`board: reading ${flags.root}${flags.lanes ? ` and lanes in ${flags.lanes}` : ""}`);
  console.log(`board: listening on http://${server.hostname}:${server.port}/`);
}
