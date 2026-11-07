// Writ dev board: a read-only viewer for the OpenSpec suite.
//
// Public entry point: `bun utils/board/server.ts --root <repo> [--lanes <dir>]
// [--port 4242] [--host 127.0.0.1]`. Everything else in this file is an
// implementation helper.
//
// Read-only contract: the server only reads files below --root and --lanes. It
// never writes, never executes a file it reads, and runs exactly two read-only
// git commands per lane (`rev-parse --abbrev-ref HEAD` and `log -1
// --no-show-signature`), which read the worktree's gitdir. One path outside
// --root and --lanes is watched: the lane's git metadata `logs/` directory, located from the `gitdir:` line of the
// lane's `.git` file (standard layout: <main repo>/.git/worktrees/<lane>/logs;
// the board follows whatever gitdir says). That watch is notify-only, filtered
// to HEAD's reflog name, and nothing there is ever opened or read; it exists so
// a commit refreshes the panel. Markdown is rendered with raw HTML escaped and unsafe link schemes
// replaced by `#`; explainer pages are served byte-for-byte as text/html only
// when their name appears in the scanned change directory as a regular file
// (not a symlink). Request paths are matched against scanned names, never
// joined into a filesystem path unchecked, so a request cannot reach outside
// the scan. Requests whose Host header is not the board's own address are
// refused (403), so a DNS-rebinding page cannot read the board's routes.
//
// The board makes no claim about Writ's behavior, proofs, or verification. It
// shows what the documents say, including checkbox counts as written.

import { readdirSync, readFileSync, existsSync, lstatSync, openSync, closeSync, fstatSync, watch, constants, appendFileSync, mkdirSync, type FSWatcher } from "node:fs";
import { join, resolve, posix } from "node:path";
import { Marked, type Tokens } from "marked";
import * as T from "./template.ts";

// ---------------------------------------------------------------- flags

type Flags = { root: string; lanes: string | null; port: number; host: string; questions: string | null };

function parseFlags(argv: string[]): Flags {
  const flags: Flags = { root: ".", lanes: null, port: 4242, host: "127.0.0.1", questions: null };
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
    else if (arg === "--questions") flags.questions = need();
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
  /** Directory under openspec/changes: the name, or `archive/<name>` once archived. */
  dir: string;
  /** Archived changes (openspec/changes/archive/<date>-<name>) are listed apart; their specs are folded into the baseline. */
  archived: boolean;
  /** The date prefix of an archived change's directory, or null. */
  archivedOn: string | null;
  title: string;
  status: string;
  dependsOn: string[];
  tasks: { done: number; total: number };
  /** Task ids ("1.3", "2.2") as written before each box, when the line starts with one. */
  taskIds: { done: string[]; open: string[] };
  /** Every task box in tasks.md, in file order, with its section heading. */
  taskList: TaskItem[];
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

/**
 * Reads a regular file without following a symlink at the last component
 * (O_NOFOLLOW), and refuses anything that is not a regular file. Used for lane
 * files and explainers, where the scan promised a regular file.
 */
function readRegular(path: string): Buffer | null {
  let fd: number | undefined;
  try {
    fd = openSync(path, constants.O_RDONLY | constants.O_NOFOLLOW);
    if (!fstatSync(fd).isFile()) return null;
    return readFileSync(fd);
  } catch {
    return null;
  } finally {
    if (fd !== undefined) closeSync(fd);
  }
}

function readRegularText(path: string): string | null {
  return readRegular(path)?.toString("utf8") ?? null;
}

/**
 * True only for a real directory (lstat, so a symlink is false). Lane anchor
 * directories (`.superpowers`, `.superpowers/sdd`, `verification`, `openspec`,
 * `openspec/changes`) are checked with this before they are read or watched,
 * so a lane cannot point the board at a tree outside the lane through them.
 */
function realDir(path: string): boolean {
  try {
    return lstatSync(path).isDirectory();
  } catch {
    return false;
  }
}

/** Regular files (Dirent.isFile, so symlinks excluded) in `dir` matching `pattern`. */
function regularFiles(dir: string, pattern: RegExp): string[] {
  try {
    return readdirSync(dir, { withFileTypes: true })
      .filter((d) => d.isFile() && pattern.test(d.name))
      .map((d) => d.name)
      .sort();
  } catch {
    return [];
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
export type TaskItem = { done: boolean; id: string | null; text: string; section: string | null };

/** Every `- [ ]`/`- [x]` line of tasks.md with the nearest heading above it; text is cut at 200 chars. */
export function taskList(markdown: string | null): TaskItem[] {
  if (markdown === null) return [];
  const out: TaskItem[] = [];
  let section: string | null = null;
  for (const line of markdown.split(/\r?\n/)) {
    const h = line.match(/^#{1,6}\s+(.+?)\s*$/);
    if (h) { section = h[1]; continue; }
    const m = line.match(/^\s*[-*]\s+\[([ xX])\]\s+(.*)$/);
    if (!m) continue;
    const id = m[2].match(/^(\d+(?:\.\d+)*)\b\s*/);
    // Backticks are markdown emphasis here; the list shows plain text.
    const body = (id ? m[2].slice(id[0].length) : m[2]).replace(/`/g, "");
    const text = body.length > 200 ? `${body.slice(0, 197)}...` : body;
    out.push({ done: m[1] !== " ", id: id ? id[1] : null, text, section });
  }
  return out;
}

/** Task ids before checked and unchecked boxes: `- [x] 1.3 …` gives "1.3". */
export function taskIds(markdown: string | null): { done: string[]; open: string[] } {
  const out = { done: [] as string[], open: [] as string[] };
  if (markdown === null) return out;
  for (const m of markdown.matchAll(/^\s*[-*]\s+\[([ xX])\]\s+(\d+(?:\.\d+)*)\b/gm)) {
    (m[1] === " " ? out.open : out.done).push(m[2]);
  }
  return out;
}

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
  const live = subdirs(changes).filter((name) => name !== "archive").map((name) => ({ name, rel: name, archived: false }));
  const archived = realDir(join(changes, "archive"))
    ? subdirs(join(changes, "archive")).map((name) => ({ name, rel: `archive/${name}`, archived: true }))
    : [];
  return [...live, ...archived].map(({ name, rel, archived }) => {
      const dir = join(changes, rel);
      const meta = parseMeta(readText(join(dir, ".openspec.yaml")));
      // Dirent.isFile is false for a symlink, so a linked explainer is never listed.
      const html = regularFiles(dir, SAFE_HTML);
      return {
        name,
        dir: rel,
        archived,
        archivedOn: archived ? (name.match(/^(\d{4}-\d{2}-\d{2})-/)?.[1] ?? null) : null,
        title: firstHeading(readText(join(dir, "proposal.md")), name),
        status: archived ? "archived" : meta.status,
        dependsOn: meta.dependsOn,
        tasks: countTasks(readText(join(dir, "tasks.md"))),
        taskIds: taskIds(readText(join(dir, "tasks.md"))),
        taskList: taskList(readText(join(dir, "tasks.md"))),
        html,
        hasDesign: existsSync(join(dir, "design.md")),
        specs: subdirs(join(dir, "specs")).filter((c) => existsSync(join(dir, "specs", c, "spec.md"))),
      };
    });
}

// ---------------------------------------------------------------- questions

/**
 * Questions the controller asks the reader: one authored HTML page per
 * question under `docs/superpowers/records/questions/<id>.html` (served
 * as-is in a sandboxed iframe, any form or image the author wants), plus
 * `<id>.answers.jsonl`, one JSON object per line, appended by the board's
 * single write route when the page's form posts to
 * `/questions/<id>/answer`, and by the controller for its own replies.
 * `<id>` is `q` followed by digits. The page's `<title>` is the summary;
 * `<meta name="writ-topic">` and `<meta name="writ-status" content="open|closed">`
 * are optional.
 */
export const QUESTIONS_DIR = "docs/superpowers/records/questions";
const QUESTION_ID = /^q\d{1,6}$/;
const QUESTION_HTML = /^(q\d{1,6})\.html$/;
/** Largest accepted answer body, in bytes. */
const ANSWER_LIMIT = 16 * 1024;

/** `kind` is set by the controller: `note` (default) replies without reopening, `ask` reopens, `close` closes. */
export type Answer = { at: string; who: string; kind: "note" | "ask" | "close" | null; fields: Record<string, string> };
export type Question = {
  id: string;
  title: string;
  topic: string | null;
  /** `closed` from the page's meta or a controller `close` entry; `open` when the reader has not answered since the question or the controller's last `ask`; else `answered`. */
  status: "open" | "answered" | "closed";
  answers: Answer[];
  lastAt: string | null;
};

function questionsDir(flags: Flags): string {
  return flags.questions ?? join(flags.root, QUESTIONS_DIR);
}

/** Answers file text to entries; a malformed line is kept as a text answer so nothing is lost silently. */
export function parseAnswers(text: string): Answer[] {
  const out: Answer[] = [];
  for (const line of text.split(/\r?\n/)) {
    if (line.trim() === "") continue;
    try {
      const o = JSON.parse(line) as Partial<Answer>;
      const fields: Record<string, string> = {};
      for (const [k, v] of Object.entries(o.fields ?? {})) fields[String(k)] = String(v);
      const k = o.kind === "ask" || o.kind === "close" || o.kind === "note" ? o.kind : null;
      out.push({ at: String(o.at ?? ""), who: String(o.who ?? ""), kind: k, fields });
    } catch {
      out.push({ at: "", who: "", kind: null, fields: { text: line } });
    }
  }
  return out;
}

function scanQuestions(flags: Flags): Question[] {
  const dir = questionsDir(flags);
  if (!existsSync(dir) || !realDir(dir)) return [];
  return regularFiles(dir, QUESTION_HTML).map((file) => {
    const id = file.match(QUESTION_HTML)![1];
    const head = (readRegularText(join(dir, file)) ?? "").slice(0, 8192);
    const title = head.match(/<title>([^<]*)<\/title>/i)?.[1]?.trim() || id;
    const topic = head.match(/<meta\s+name="writ-topic"\s+content="([^"]*)"/i)?.[1] ?? null;
    const closed = /<meta\s+name="writ-status"\s+content="closed"/i.test(head);
    const answers = parseAnswers(readRegularText(join(dir, `${id}.answers.jsonl`)) ?? "");
    const last = answers[answers.length - 1];
    // Open until the reader answers; a controller "ask" after the reader's last entry reopens; a note does not.
    let status: Question["status"] = "open";
    for (const a of answers) {
      if (a.who === "controller") { if (a.kind === "ask") status = "open"; }
      else status = "answered";
    }
    if (closed || answers.some((a) => a.who === "controller" && a.kind === "close")) status = "closed";
    return { id, title, topic, status, answers, lastAt: last?.at ?? null };
  }).sort((a, b) => Number(b.id.slice(1)) - Number(a.id.slice(1)));
}

/** Control characters other than tab and newline are dropped; values are capped. */
function cleanField(v: string): string {
  return v.replace(/[\u0000-\u0008\u000b-\u001f\u007f]/g, "").slice(0, 4000);
}

/**
 * The board's one write: append the reader's answer to `<id>.answers.jsonl`.
 * Accepts a form post (urlencoded or multipart) or JSON; every field becomes a
 * string. The Host check in `handle` already refuses other sites; the Origin
 * must be the board's own or `null` (a sandboxed question iframe has an opaque
 * origin). Never creates the question page; a missing page is 404.
 */
async function recordAnswer(flags: Flags, hosts: Set<string>, id: string, req: Request): Promise<Response> {
  if (!QUESTION_ID.test(id)) return new Response("not found\n", { status: 404 });
  const dir = questionsDir(flags);
  if (!existsSync(join(dir, `${id}.html`))) return new Response("not found\n", { status: 404 });
  const origin = req.headers.get("origin");
  if (origin !== null && origin !== "null" && !hosts.has(origin.replace(/^https?:\/\//, "").toLowerCase())) {
    return new Response("forbidden origin\n", { status: 403 });
  }
  const length = Number(req.headers.get("content-length") ?? "0");
  if (length > ANSWER_LIMIT) return new Response("answer too large\n", { status: 413 });
  const type = req.headers.get("content-type") ?? "";
  const fields: Record<string, string> = {};
  if (type.includes("application/json")) {
    const body = (await req.json().catch(() => null)) as Record<string, unknown> | null;
    if (body === null) return new Response("bad json\n", { status: 400 });
    for (const [k, v] of Object.entries(body)) fields[cleanField(k).slice(0, 64)] = cleanField(typeof v === "string" ? v : JSON.stringify(v));
  } else {
    const form = await req.formData().catch(() => null);
    if (form === null) return new Response("bad form\n", { status: 400 });
    for (const [k, v] of form.entries()) {
      if (typeof v !== "string") continue; // files are not accepted
      const key = cleanField(k).slice(0, 64);
      fields[key] = fields[key] === undefined ? cleanField(v) : `${fields[key]}, ${cleanField(v)}`;
    }
  }
  if (Object.keys(fields).length === 0) return new Response("empty answer\n", { status: 400 });
  const entry: Answer = { at: new Date().toISOString(), who: "josh", kind: null, fields };
  mkdirSync(dir, { recursive: true });
  appendFileSync(join(dir, `${id}.answers.jsonl`), JSON.stringify(entry) + "\n");
  // The form lands on a small confirmation inside its own frame; the board page's
  // thread around it is re-rendered by the watcher for every open stream.
  return new Response("", { status: 303, headers: { location: `/questions/${id}/answered?at=${encodeURIComponent(entry.at)}` } });
}

// ---------------------------------------------------------------- lanes

/** Directory names never walked or watched: dependencies, git internals, build output. */
const IGNORED_DIRS = new Set(["node_modules", ".git", "build", "dist", "out", "target", "result", "zig-out", ".zig-cache", ".cache"]);

/** Lines of `progress.md` shown in the panel. */
const LEDGER_TAIL = 10;
const REPORT_FILE = /^task-(\d+)-report\.md$/;
const GIT_TIMEOUT_MS = 3000;

/** One line of a lane's `.lane/activity.log`: `<ISO time>\t<who>\t<text>`; a line without tabs is all text. */
export type ActivityLine = { at: string; who: string; text: string };

/**
 * Where a plan stands, read from the last ledger line that names a task (or
 * the final-review and merge lines after the tasks). `label` is a closed set
 * so the template can colour it; `text` is the line itself, shortened.
 */
export type Phase = {
  label: "dispatched" | "implemented" | "review" | "fix" | "complete" | "landed" | "unknown";
  task: string | null;
  text: string;
};

export type LaneSdd = {
  /** The record directory name (the plan's), under docs/superpowers/records or .superpowers/sdd. */
  plan: string;
  /** Where the files live, relative to the lane. */
  dir: string;
  /** Rendered tail of progress.md, or null with `ledgerNote` saying why. */
  ledger: string | null;
  ledgerNote: string | null;
  /** The plan file the ledger's first line names, relative to the lane, or null. */
  planFile: string | null;
  phase: Phase | null;
  reports: { file: string; status: string | null; html: string | null }[];
  /** Reviewer reports (`task-<n>-review.md`, then `final-review.md`), rendered. */
  reviews: { file: string; html: string | null }[];
};

/** How a lane is shown: by its newest phase, then by how recently anything in it was written. */
export type LaneStatus = "active" | "review" | "idle" | "landed";

export type Lane = {
  name: string;
  branch: string | null;
  commit: { hash: string; subject: string; when: string; at: number | null } | null;
  /** Changes this lane works on: named by its plan files or differing in task boxes. */
  changes: string[];
  /** Epoch ms of the newest signal (commit, ledger, activity log, report), or null. */
  signalAt: number | null;
  status: LaneStatus;
  /** Last lines across `<lane>/.lane/*.log`, oldest first by timestamp; empty when absent. */
  activity: ActivityLine[];
  activityNote: string | null;
  /** Each entry says what could not be read for this lane. */
  notes: string[];
  sdd: LaneSdd[];
  /** Changes whose checkbox counts differ from the root's (root null: not in root). */
  taskDiffs: { name: string; lane: { done: number; total: number }; root: { done: number; total: number } | null }[];
  /** Files under verification/ that are new or newer-and-different than the root's copy; null if absent. */
  verification: { path: string; kind: "new" | "changed" }[] | null;
};

export type LaneScan = { dir: string; readable: boolean; lanes: Lane[]; skipped: string[] };

/**
 * The only two git commands the board runs. Both are read-only; the argument
 * vectors are fixed so no request or file content can reach git's argv.
 */
const GIT_BRANCH = ["rev-parse", "--abbrev-ref", "HEAD"] as const;
const GIT_LAST = ["log", "-1", "--no-show-signature", "--format=%h%x09%s%x09%cr%x09%ct"] as const;

/**
 * Environment for git. Variables that would redirect git to another
 * repository, work tree, or index are removed so `-C <lane>` decides; system
 * config is skipped; signature checks are off in the argv, so lane or user
 * config cannot make these commands run gpg, a pager, or a credential helper.
 */
function gitEnv(): Record<string, string | undefined> {
  const env: Record<string, string | undefined> = { ...process.env };
  for (const k of ["GIT_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE", "GIT_COMMON_DIR"]) delete env[k];
  return { ...env, GIT_CONFIG_NOSYSTEM: "1", GIT_OPTIONAL_LOCKS: "0", GIT_TERMINAL_PROMPT: "0", GIT_PAGER: "cat", PAGER: "cat" };
}

async function git(dir: string, args: typeof GIT_BRANCH | typeof GIT_LAST): Promise<string | null> {
  try {
    const proc = Bun.spawn(["git", "-C", dir, ...args], {
      stdin: "ignore",
      stdout: "pipe",
      stderr: "ignore",
      // No optional index locks, no pager, no credential prompt, no system config.
      env: gitEnv(),
    });
    const timer = setTimeout(() => proc.kill(), GIT_TIMEOUT_MS);
    const out = await new Response(proc.stdout).text();
    const code = await proc.exited;
    clearTimeout(timer);
    return code === 0 ? out.trim() : null;
  } catch {
    return null;
  }
}

/** Lane candidates: subdirectories of --lanes that hold a `.git` file or directory. */
function laneNames(lanes: string): { lanes: string[]; skipped: string[] } {
  const all = subdirs(lanes);
  const isLane = (d: string) => existsSync(join(lanes, d, ".git"));
  return { lanes: all.filter(isLane), skipped: all.filter((d) => !isLane(d)) };
}

/**
 * The gitdir of a worktree: `<dir>/.git` itself when it is a directory, or the
 * path named by its `gitdir:` line when it is a file (a linked worktree).
 */
function gitDirOf(dir: string): string | null {
  const dotGit = join(dir, ".git");
  try {
    if (lstatSync(dotGit).isDirectory()) return dotGit;
  } catch {
    return null;
  }
  const m = readRegularText(dotGit)?.match(/^gitdir:\s*(.+?)\s*$/m);
  return m ? resolve(dir, m[1]) : null;
}

function ledgerTail(text: string): string {
  const lines = text.split(/\r?\n/);
  while (lines.length > 0 && lines[lines.length - 1].trim() === "") lines.pop();
  return lines.slice(-LEDGER_TAIL).join("\n");
}

/** Lines of activity.log shown per lane. */
const ACTIVITY_TAIL = 12;
/**
 * Committed execution records, one directory per plan (and so per proposal):
 * `docs/superpowers/records/<plan>/` with `progress.md` (the ledger, whose
 * first line names the plan file and whose `Branch:` line names the lane
 * branch that ran it), `activity.log`, `task-<n>-brief.md`,
 * `task-<n>-report.md`, `task-<n>-review.md`, and `final-review.md`. They
 * are committed with the lane's work, so a worktree also carries the records
 * of plans that already landed; a lane card shows the records whose
 * `Branch:` line is its branch, or failing that whose name ends with the
 * worktree's name.
 */
export const RECORDS_DIR = "docs/superpowers/records";
const LEDGER_BRANCH = /^Branch:\s*(\S+)/m;
const REVIEW_FILE = /^task-(\d+)-review\.md$/;
const FINAL_REVIEW = "final-review.md";
/** A signal younger than this makes a lane "active". */
export const ACTIVE_MS = 30 * 60 * 1000;
/** A ledger saying "review" counts as live only this long; reviews are quiet on disk but not for hours. */
export const REVIEW_MS = 3 * 60 * 60 * 1000;
const LEDGER_PLAN = /^#\s*SDD ledger\s*[—-]+\s*plan:\s*(\S+)/;
const CHANGE_REF = /openspec\/changes\/([A-Za-z0-9._-]+)/g;

/** Parses activity-log text into lines (all of them; callers take the tail). */
export function parseActivity(text: string): ActivityLine[] {
  const lines = text.split(/\r?\n/).filter((l) => l.trim() !== "");
  return lines.map((line) => {
    const parts = line.split("\t");
    if (parts.length >= 3) return { at: parts[0], who: parts[1], text: parts.slice(2).join("\t") };
    if (parts.length === 2) return { at: parts[0], who: "", text: parts[1] };
    return { at: "", who: "", text: line };
  });
}

/**
 * The phase of a plan from its ledger: the last line that names a task, a
 * final review, or a merge wins. Wording follows the SDD ledger convention
 * (`Task N: dispatched`, `implementer DONE`, `Review dispatched`,
 * `fix round R`, `complete`, `Merged to master`).
 */
export function parsePhase(ledger: string): Phase | null {
  const lines = ledger.split(/\r?\n/).map((l) => l.trim()).filter((l) => l !== "");
  for (let i = lines.length - 1; i >= 0; i--) {
    const line = lines[i];
    const task = line.match(/^Tasks?\s+(\d+(?:\s*(?:,|and|-)\s*\d+)*)\s*:/i)?.[1] ?? null;
    const isFinal = /^(final|whole-branch|merged|pushed|fix round|review)/i.test(line) || /merged to master|pushed master/i.test(line);
    if (task === null && !isFinal) continue;
    const text = line.length > 160 ? `${line.slice(0, 157)}...` : line;
    let label: Phase["label"] = "unknown";
    if (/merged to master|pushed master|\blanded\b|\bmerging\b|\bmerged\b/i.test(line)) label = "landed";
    else if (/\bcomplete\b/i.test(line)) label = "complete";
    else if (/fix round|fix pass|micro-round/i.test(line)) label = "fix";
    else if (/re-review|review/i.test(line)) label = "review";
    else if (/\b(DONE|DONE_WITH_CONCERNS|BLOCKED|NEEDS_CONTEXT)\b/.test(line)) label = "implemented";
    else if (/dispatched/i.test(line)) label = "dispatched";
    return { label, task, text };
  }
  return null;
}

/**
 * Change names a plan file refers to, in order of first mention. The first is
 * the plan's primary change (its `Spec:` line); later mentions are context.
 */
export function planChanges(planText: string): string[] {
  const out: string[] = [];
  for (const m of planText.matchAll(CHANGE_REF)) if (!out.includes(m[1])) out.push(m[1]);
  return out;
}

/**
 * The plan file a ledger names, as a lane-relative path, only if it is a
 * markdown file under docs/superpowers/plans with no path traversal.
 */
function ledgerPlanFile(ledger: string): string | null {
  const rel = ledger.split(/\r?\n/, 1)[0].match(LEDGER_PLAN)?.[1] ?? null;
  if (rel === null) return null;
  if (!/^docs\/superpowers\/plans\/[A-Za-z0-9._-]+\.md$/.test(rel)) return null;
  return rel;
}

function mtimeMs(path: string): number | null {
  try {
    const st = lstatSync(path);
    return st.isFile() ? st.mtimeMs : null;
  } catch {
    return null;
  }
}

/**
 * A lane's records: the committed `docs/superpowers/records/<plan>/`
 * directories whose ledger names this lane's branch (or whose name ends with
 * the worktree's name when the ledger has no `Branch:` line), else the
 * git-ignored `.superpowers/sdd/<plan>/` workspaces (older lanes), so nothing
 * already shown disappears.
 */
function scanSdd(dir: string, name: string, branch: string | null): { sdd: LaneSdd[]; note: string | null } {
  const recordsDir = join(dir, RECORDS_DIR);
  const parts = RECORDS_DIR.split("/");
  if (parts.every((_, k) => existsSync(join(dir, ...parts.slice(0, k + 1))))) {
    if (!parts.every((_, k) => realDir(join(dir, ...parts.slice(0, k + 1))))) return { sdd: [], note: `${RECORDS_DIR} is not a real directory (symlink?); skipped` };
    const mine = subdirs(recordsDir).filter((plan) => {
      const ledger = readRegularText(join(recordsDir, plan, "progress.md"));
      const b = ledger?.match(LEDGER_BRANCH)?.[1] ?? null;
      return b !== null ? b === branch : plan.endsWith(`-${name}`) || plan === name;
    });
    if (mine.length > 0) return { note: null, sdd: mine.map((plan) => scanRecord(join(recordsDir, plan), plan, `${RECORDS_DIR}/${plan}`)) };
  }
  const base = join(dir, ".superpowers", "sdd");
  if (!existsSync(base)) return { sdd: [], note: null };
  if (!realDir(join(dir, ".superpowers")) || !realDir(base)) return { sdd: [], note: ".superpowers/sdd is not a real directory (symlink?); skipped" };
  const plans = subdirs(base);
  if (plans.length === 0) return { sdd: [], note: "no plan directories under .superpowers/sdd/" };
  return { note: null, sdd: plans.map((plan) => scanRecord(join(base, plan), plan, `.superpowers/sdd/${plan}`)) };
}

/** One record directory: ledger, phase, plan file, task reports, reviewer reports. */
function scanRecord(planDir: string, plan: string, rel: string): LaneSdd {
  {
    {
      const ledgerPath = join(planDir, "progress.md");
      let ledger: string | null = null;
      let ledgerNote: string | null = null;
      let planFile: string | null = null;
      let phase: Phase | null = null;
      if (!existsSync(ledgerPath)) ledgerNote = "no progress.md yet";
      else {
        const text = readRegularText(ledgerPath);
        if (text === null) ledgerNote = "progress.md could not be read (not a regular file, or removed mid-scan)";
        else if (text.trim() === "") ledgerNote = "progress.md is empty (possibly mid-write)";
        else {
          ledger = renderMarkdown(ledgerTail(text), `${rel}/progress.md`, { lineBreaks: true });
          planFile = ledgerPlanFile(text);
          phase = parsePhase(text);
        }
      }

      const reports = regularFiles(planDir, REPORT_FILE)
        .sort((x, y) => Number(x.match(REPORT_FILE)![1]) - Number(y.match(REPORT_FILE)![1]))
        .map((file) => {
          const text = readRegularText(join(planDir, file));
          const status = text?.match(/^Status:\s*(.+?)\s*$/m)?.[1] ?? null;
          return { file, status, html: text === null ? null : renderMarkdown(text, `${rel}/${file}`) };
        });
      const reviews = [
        ...regularFiles(planDir, REVIEW_FILE).sort((x, y) => Number(x.match(REVIEW_FILE)![1]) - Number(y.match(REVIEW_FILE)![1])),
        ...(regularFiles(planDir, /^final-review\.md$/).length > 0 ? [FINAL_REVIEW] : []),
      ].map((file) => {
        const text = readRegularText(join(planDir, file));
        return { file, html: text === null ? null : renderMarkdown(text, `${rel}/${file}`) };
      });
      return { plan, dir: rel, ledger, ledgerNote, planFile, phase, reports, reviews };
    }
  }
}

/** Files below `dir` (relative paths), regular files only, ignored directories skipped. */
function walkFiles(dir: string, prefix = "", depth = 0): string[] {
  if (depth > 6) return [];
  let entries;
  try {
    entries = readdirSync(dir, { withFileTypes: true });
  } catch {
    return [];
  }
  return entries.flatMap((d) => {
    const rel = prefix ? `${prefix}/${d.name}` : d.name;
    if (d.isFile()) return [rel];
    if (d.isDirectory() && !IGNORED_DIRS.has(d.name)) return walkFiles(join(dir, d.name), rel, depth + 1);
    return [];
  }).sort();
}

/**
 * Verification files a lane has that the root lacks, or that are newer than the
 * root's copy and differ in content. The content check matters because a fresh
 * worktree checkout gives every file a newer mtime than the root's copy.
 */
function newerVerification(root: string, dir: string): Lane["verification"] {
  const laneVer = join(dir, "verification");
  if (!realDir(laneVer)) return null;
  const rootVer = join(root, "verification");
  return walkFiles(laneVer).flatMap((rel) => {
    let laneMtime: number;
    let rootMtime: number;
    try {
      laneMtime = lstatSync(join(laneVer, rel)).mtimeMs;
    } catch {
      return []; // removed since the walk
    }
    try {
      rootMtime = lstatSync(join(rootVer, rel)).mtimeMs;
    } catch {
      return [{ path: rel, kind: "new" as const }];
    }
    if (laneMtime <= rootMtime) return [];
    const a = readRegular(join(laneVer, rel));
    const b = readRegular(join(rootVer, rel));
    return a !== null && b !== null && a.equals(b) ? [] : [{ path: rel, kind: "changed" as const }];
  });
}

async function scanLane(root: string, rootChanges: Change[], lanes: string, name: string): Promise<Lane> {
  const dir = join(lanes, name);
  const notes: string[] = [];
  const [branch, last] = await Promise.all([git(dir, GIT_BRANCH), git(dir, GIT_LAST)]);
  if (branch === null) notes.push("branch could not be read (git rev-parse failed)");
  let commit: Lane["commit"] = null;
  if (last === null) notes.push("last commit could not be read (git log failed)");
  else {
    const [hash, subject = "", when = "", ct = ""] = last.split("\t");
    const at = /^\d+$/.test(ct) ? Number(ct) * 1000 : null;
    commit = { hash, subject, when, at };
  }
  const { sdd, note } = scanSdd(dir, name, branch);
  if (note) notes.push(note);
  const byName = new Map(rootChanges.map((c) => [c.name, c.tasks]));
  const taskDiffs = realDir(join(dir, "openspec")) && realDir(join(dir, "openspec", "changes"))
    ? scanChanges(dir).flatMap((c) => {
        const r = byName.get(c.name) ?? null;
        return r !== null && r.done === c.tasks.done && r.total === c.tasks.total ? [] : [{ name: c.name, lane: c.tasks, root: r }];
      })
    : [];
  if (!existsSync(dir)) notes.push("directory could not be read (removed?)");
  // Changes the lane works on: the primary change each plan file names. Task-box
  // drift is shown separately; an old lane drifts from the root without working on it.
  const known = new Set(rootChanges.map((c) => c.name));
  const changes: string[] = [];
  for (const p of sdd) {
    if (p.planFile === null) continue;
    const text = readRegularText(join(dir, p.planFile));
    if (text === null) continue;
    const primary = planChanges(text).find((c) => known.has(c));
    if (primary !== undefined && !changes.includes(primary)) changes.push(primary);
  }
  // The activity logs of this lane's records, merged by timestamp (ISO times sort as text).
  let activity: ActivityLine[] = [];
  let activityNote: string | null = null;
  const times: number[] = [];
  {
    const all: ActivityLine[] = [];
    for (const p of sdd) {
      const f = join(dir, p.dir, "activity.log");
      if (!existsSync(f)) continue;
      const text = readRegularText(f);
      if (text === null) activityNote = `${p.dir}/activity.log could not be read (not a regular file, or removed mid-scan)`;
      else all.push(...parseActivity(text));
      const t = mtimeMs(f);
      if (t !== null) times.push(t);
    }
    activity = all.sort((a, b) => (a.at < b.at ? -1 : a.at > b.at ? 1 : 0)).slice(-ACTIVITY_TAIL);
  }
  // The newest write anywhere the lane records progress, or its last commit.
  if (commit?.at != null) times.push(commit.at);
  for (const p of sdd) {
    const planDir = join(dir, p.dir);
    for (const f of ["progress.md", ...p.reports.map((r) => r.file), ...p.reviews.map((r) => r.file)]) {
      const t = mtimeMs(join(planDir, f));
      if (t !== null) times.push(t);
    }
  }
  const signalAt = times.length === 0 ? null : Math.max(...times);
  return { name, branch, commit, changes, signalAt, status: laneStatus(sdd, signalAt), activity, activityNote, notes, sdd, taskDiffs, verification: newerVerification(root, dir) };
}

/**
 * Landed once every plan's phase is landed; in review while the newest plan is
 * in review; active while any signal is younger than ACTIVE_MS; otherwise idle.
 * A review is read-only work, so it is shown even when the files are quiet.
 */
export function laneStatus(sdd: Pick<LaneSdd, "phase">[], signalAt: number | null, now = Date.now()): LaneStatus {
  const phases = sdd.map((p) => p.phase).filter((p): p is Phase => p !== null);
  if (phases.length > 0 && phases.every((p) => p.label === "landed")) return "landed";
  const age = signalAt === null ? Infinity : now - signalAt;
  const newest = phases[phases.length - 1];
  if (newest?.label === "review" && age < REVIEW_MS) return "review";
  return age < ACTIVE_MS ? "active" : "idle";
}

async function scanLanes(root: string, rootChanges: Change[], lanes: string | null): Promise<LaneScan | null> {
  if (lanes === null) return null;
  const readable = existsSync(lanes);
  const { lanes: names, skipped } = laneNames(lanes);
  return { dir: lanes, readable, skipped, lanes: await Promise.all(names.map((n) => scanLane(root, rootChanges, lanes, n))) };
}

// ---------------------------------------------------------------- markdown

/**
 * Renders repository markdown. Raw HTML in the source is escaped, not passed
 * through, so a document cannot inject script into the board. Relative links
 * that point at OpenSpec documents are rewritten to the matching board route;
 * other relative links are left as written. `lineBreaks` keeps single
 * newlines as breaks, for line-oriented files such as an SDD ledger.
 */
function renderMarkdown(source: string, repoPath: string, opts: { lineBreaks?: boolean } = {}): string {
  const md = new Marked({ gfm: true, breaks: opts.lineBreaks === true });
  md.use({
    renderer: {
      html({ text }: Tokens.HTML | Tokens.Tag) {
        return T.esc(text);
      },
    },
    walkTokens(token) {
      if (token.type === "link" || token.type === "image") {
        const t = token as Tokens.Link | Tokens.Image;
        t.href = boardHref(t.href, repoPath);
      }
    },
  });
  return md.parse(source, { async: false }) as string;
}

/** Schemes a rendered link may keep; any other scheme becomes `#`. */
const SAFE_SCHEME = /^(https?|mailto):/i;

/**
 * Decodes the character references a browser would decode inside an href
 * attribute, so the scheme check sees what the browser will see. marked keeps
 * `&#106;` and similar references in the href and does not re-escape them.
 */
function decodeRefs(s: string): string {
  return s
    .replace(/&#x([0-9a-f]+);?/gi, (_, h) => String.fromCodePoint(Math.min(parseInt(h, 16), 0x10ffff)))
    .replace(/&#(\d+);?/g, (_, d) => String.fromCodePoint(Math.min(Number(d), 0x10ffff)))
    .replace(/&(colon|tab|newline|amp|sol|num|quest|period);/gi, (_, n) =>
      ({ colon: ":", tab: "\t", newline: "\n", amp: "&", sol: "/", num: "#", quest: "?", period: "." })[n.toLowerCase() as "colon"]);
}

/**
 * Filters and rewrites one markdown link target. Kept: http:, https:, mailto:,
 * fragment links, and same-origin relative paths. Rewritten: relative links to
 * OpenSpec documents become the matching board route. Everything else
 * (javascript:, data:, file:, protocol-relative `//host`, or a scheme hidden
 * behind character references or control characters) becomes `#`.
 */
export function boardHref(href: string, repoPath: string): string {
  // Browsers drop ASCII tab/newline anywhere and C0/space at the ends; strip all
  // of them so the probe is never more permissive than the browser.
  const probe = decodeRefs(href).replace(/[\u0000-\u0020\u007f]/g, "");
  const head = probe.split(/[/?#]/, 1)[0];
  if (head.includes(":")) return SAFE_SCHEME.test(probe) ? href : "#";
  if (head.includes("&")) return "#"; // an undecoded reference where a scheme could sit
  if (/^[/\\]{2}/.test(probe)) return "#"; // protocol-relative: another host, not a board route
  if (probe.startsWith("#") || probe.startsWith("/")) return href;
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

/**
 * One scan of the filesystem shared by every page rendered in the same flush.
 * The lanes scan (which runs git) happens only if an index page asks for it.
 */
type Snapshot = { changes: Change[]; baselines: Baseline[]; questions: Question[]; lanes: () => Promise<LaneScan | null> };

function snapshot(flags: Flags): Snapshot {
  const changes = scanChanges(flags.root);
  let lanes: Promise<LaneScan | null> | undefined;
  return {
    changes,
    baselines: scanBaselines(flags.root),
    questions: scanQuestions(flags),
    lanes: () => (lanes ??= scanLanes(flags.root, changes, flags.lanes)),
  };
}

/**
 * One rendered page. `main` is the full content element for the first render;
 * `parts` are the id-carrying fragments that updates may replace individually
 * (always including `nav`). For the index, `main` is built from its parts.
 */
type View = { status: number; title: string; nav: string; main: string; parts: Record<string, string> };

async function view(flags: Flags, page: string, snap: Snapshot): Promise<View> {
  const { changes, baselines, questions } = snap;
  const nav = T.nav(changes, page, questions);
  const page1 = (status: number, title: string, main: string): View => ({ status, title, nav, main, parts: { nav, main } });
  const notFound = page1(404, "Not found", T.notFound(page));

  if (page === "/") {
    const scan = await snap.lanes();
    const tables = T.indexTables(baselines, changes, scan, questions);
    const lanes = T.lanesPanel(scan);
    return { status: 200, title: "Writ board", nav, main: T.index(tables, lanes, flags.lanes !== null), parts: { nav, "index-tables": tables, lanes } };
  }
  let m: RegExpMatchArray | null;
  if (page === "/questions") return page1(200, "Questions", T.questionsPage(questions));
  if ((m = page.match(/^\/questions\/(q\d{1,6})$/))) {
    const q = questions.find((x) => x.id === m![1]);
    if (!q) return notFound;
    return page1(200, q.title, T.questionPage(q));
  }
  if ((m = page.match(/^\/change\/([^/]+)$/))) {
    const change = changes.find((c) => c.name === m![1]);
    if (!change) return notFound;
    const base = `openspec/changes/${change.dir}`;
    const docs = {
      proposal: mdFile(flags.root, `${base}/proposal.md`),
      design: mdFile(flags.root, `${base}/design.md`),
      tasks: mdFile(flags.root, `${base}/tasks.md`),
      specs: change.specs.map((c) => ({ capability: c, html: mdFile(flags.root, `${base}/specs/${c}/spec.md`) ?? "" })),
    };
    return page1(200, change.title, T.changePage(change, docs, changes));
  }
  if ((m = page.match(/^\/spec\/([^/]+)(\/traceability)?$/))) {
    const baseline = baselines.find((b) => b.name === m![1]);
    if (!baseline) return notFound;
    const trace = m[2] !== undefined;
    if (trace && !baseline.traceability) return notFound;
    const repoPath = trace ? `openspec/traceability/${baseline.name}.md` : `openspec/specs/${baseline.name}/spec.md`;
    const html = mdFile(flags.root, repoPath);
    if (html === null) return notFound;
    return page1(200, baseline.title, T.specPage(baseline, html, trace, repoPath));
  }
  return notFound;
}

// ---------------------------------------------------------------- SSE

const encoder = new TextEncoder();

/** Formats one Datastar `datastar-patch-elements` event (outer morph by id). */
export function patchElements(html: string): string {
  // SSE ends a line at CRLF, CR, or LF; split on all three so no fragment text
  // can end a data line early and start a field of its own.
  const lines = html.split(/\r\n|\r|\n/).map((l) => `data: elements ${l}`).join("\n");
  return `event: datastar-patch-elements\n${lines}\n\n`;
}

/** An open /events connection and the fragments it was last sent, by id. */
type Client = { page: string; last: Map<string, string>; send: (text: string) => boolean };

const clients = new Set<Client>();

/**
 * One SSE connection per client. On connect it sends the full render of the
 * client's page (so a reconnect always resynchronizes); afterwards `flush`
 * pushes only fragments whose HTML changed. Comment keepalives hold the stream.
 */
export function events(flags: Flags, page: string, reconcile: () => void, afterInitialRender?: () => Promise<void>): Response {
  let client: Client | undefined;
  const stream = new ReadableStream({
    async start(controller) {
      // A failed first render (for example a lane scan throwing) keeps the
      // stream open with nothing recorded as sent, so the next flush sends
      // every fragment.
      let v: View | null = null;
      try {
        v = await view(flags, page, snapshot(flags));
        // The optional pause is used only by the smoke test to reproduce a
        // filesystem update after this snapshot but before registration.
        await afterInitialRender?.();
      } catch (err) {
        console.error(`board: initial render of ${page} failed: ${err}`);
      }
      const c: Client = {
        page,
        last: new Map(v === null ? [] : Object.entries(v.parts)),
        send(text) {
          try {
            controller.enqueue(encoder.encode(text));
            return true;
          } catch {
            clients.delete(c);
            return false;
          }
        },
      };
      client = c;
      const first = v === null ? ": initial render failed; waiting for the next change\n\n" : patchElements(v.nav) + patchElements(v.main);
      if (c.send(first)) {
        clients.add(c);
        // A watcher flush may have completed while the first view was being
        // built and this client was absent. Queue a fresh scan only after the
        // initial patch, through the same serialized path as watcher events.
        reconcile();
      }
    },
    cancel() {
      if (client) clients.delete(client);
    },
  });
  return new Response(stream, {
    headers: { "content-type": "text/event-stream", "cache-control": "no-cache", connection: "keep-alive" },
  });
}

// Comments keep proxies and Bun's 10 s idle timeout from closing a quiet stream.
setInterval(() => {
  for (const c of clients) c.send(": keepalive\n\n");
}, 5000).unref?.();

/**
 * Re-renders the pages open on /events and sends each client only the
 * fragments that differ from what it last received. Pages are rendered once per
 * flush however many clients show them. Returns the number of events sent.
 */
async function pushChanges(flags: Flags): Promise<number> {
  if (clients.size === 0) return 0;
  const snap = snapshot(flags);
  const views = new Map<string, Promise<View>>();
  let sent = 0;
  for (const c of [...clients]) {
    if (!views.has(c.page)) views.set(c.page, view(flags, c.page, snap));
    const v = await views.get(c.page)!;
    let out = "";
    for (const [id, html] of Object.entries(v.parts)) {
      if (c.last.get(id) === html) continue;
      out += patchElements(html);
      c.last.set(id, html);
      sent++;
    }
    if (out) c.send(out);
  }
  return sent;
}

// ---------------------------------------------------------------- watching

const DEBOUNCE_MS = 200;
const WALK_DEPTH = 12;
/** Subtrees watched in the root and in every lane. */
const ROOT_TREES = ["openspec", "verification", "docs"];
const LANE_TREES = [...ROOT_TREES, ".superpowers/sdd"];

/**
 * Watches the board's inputs with one non-recursive fs.watch per directory.
 * Bun 1.1.8's `recursive: true` on Linux misses modifications to existing
 * files in subdirectories and anything in directories created after the watch
 * starts, so the directory set is walked and re-synced after every flush.
 *
 * Each watched directory may carry a name filter: anchor directories (the
 * root, each lane, `.superpowers`, a gitdir's `logs/`) only report entries that
 * lead to a watched subtree, so unrelated edits in a worktree do not re-render.
 */
export class Watcher {
  private watchers = new Map<string, FSWatcher>();
  private filters = new Map<string, Set<string> | null>();
  private timer: ReturnType<typeof setTimeout> | undefined;
  private running = false;
  private again = false;
  private stopped = false;

  constructor(private flags: Flags, private onFlush: (events: number) => void = () => {}) {}

  start(): void {
    this.stopped = false;
    this.sync();
  }

  /** Reconcile a newly registered connection with the current filesystem. */
  reconcile(): void {
    this.schedule();
  }

  /** Close watchers and any pending debounce timer. */
  stop(): void {
    this.stopped = true;
    this.again = false;
    if (this.timer !== undefined) clearTimeout(this.timer);
    this.timer = undefined;
    for (const watcher of this.watchers.values()) watcher.close();
    this.watchers.clear();
  }

  /** Directories to watch, each with its name filter (null: any entry). */
  private desired(): Map<string, Set<string> | null> {
    const want = new Map<string, Set<string> | null>();
    const add = (dir: string, filter: string[] | null) => {
      if (!existsSync(dir)) return;
      const prev = want.get(dir);
      if (prev === null || filter === null) want.set(dir, null);
      else want.set(dir, new Set([...(prev ?? []), ...filter]));
    };
    const walk = (dir: string, depth = 0) => {
      add(dir, null);
      if (depth >= WALK_DEPTH) return;
      try {
        for (const d of readdirSync(dir, { withFileTypes: true })) {
          if (d.isDirectory() && !IGNORED_DIRS.has(d.name)) walk(join(dir, d.name), depth + 1);
        }
      } catch {}
    };
    const { root, lanes } = this.flags;
    add(root, ROOT_TREES);
    for (const t of ROOT_TREES) if (existsSync(join(root, t))) walk(join(root, t));
    if (this.flags.questions !== null) add(this.flags.questions, null);
    if (lanes !== null) {
      add(lanes, null);
      for (const name of laneNames(lanes).lanes) {
        const dir = join(lanes, name);
        add(dir, [...ROOT_TREES, ".superpowers", ".git"]);
        // Anchors that are symlinks are neither walked nor watched (see realDir).
        if (realDir(join(dir, ".superpowers"))) add(join(dir, ".superpowers"), ["sdd"]);
        for (const t of LANE_TREES) {
          const parts = t.split("/");
          if (parts.every((_, k) => realDir(join(dir, ...parts.slice(0, k + 1))))) walk(join(dir, t));
        }
        // A commit appends to the gitdir's logs/HEAD; watch that name only.
        const gitDir = gitDirOf(dir);
        if (gitDir) add(join(gitDir, "logs"), ["HEAD"]);
      }
    }
    return want;
  }

  /** Adds watchers for new directories and closes those for vanished ones. */
  sync(): void {
    const want = this.desired();
    for (const [dir, w] of this.watchers) {
      if (!want.has(dir)) {
        w.close();
        this.watchers.delete(dir);
        this.filters.delete(dir);
      }
    }
    for (const [dir, filter] of want) {
      this.filters.set(dir, filter);
      if (this.watchers.has(dir)) continue;
      try {
        const w = watch(dir, (_event, name) => this.onEvent(dir, name === null ? null : String(name)));
        w.on("error", () => {
          w.close();
          this.watchers.delete(dir);
          this.schedule();
        });
        this.watchers.set(dir, w);
      } catch {
        // Vanished between the walk and the watch; the next sync retries.
      }
    }
  }

  get size(): number {
    return this.watchers.size;
  }

  private onEvent(dir: string, name: string | null): void {
    const filter = this.filters.get(dir);
    if (name !== null) {
      // Anchors report only entries leading to a watched subtree; inside a
      // subtree everything counts except ignored directory names.
      const top = name.split("/")[0];
      if (filter ? !filter.has(top) : IGNORED_DIRS.has(top)) return;
    }
    this.schedule();
  }

  /** Coalesces a burst of events into one flush about DEBOUNCE_MS after the first. */
  private schedule(): void {
    if (this.stopped) return;
    if (this.running) {
      this.again = true;
      return;
    }
    this.timer ??= setTimeout(() => this.flush(), DEBOUNCE_MS);
  }

  private async flush(): Promise<void> {
    this.timer = undefined;
    this.running = true;
    try {
      this.sync();
      this.onFlush(await pushChanges(this.flags));
    } catch (err) {
      console.error(`board: update failed: ${err}`);
    } finally {
      this.running = false;
      if (this.again) {
        this.again = false;
        this.schedule();
      }
    }
  }
}

// ---------------------------------------------------------------- routes

const CSS_PATH = join(import.meta.dir, "board.css");

/** Loopback names a browser may send as Host for a loopback-bound board. */
const LOOPBACK_HOSTS = ["127.0.0.1", "localhost", "::1", "[::1]"];

/**
 * Host header values the board answers. Bound to a loopback address it accepts
 * exactly `127.0.0.1:<port>`, `localhost:<port>`, and `[::1]:<port>`;
 * otherwise exactly `<--host>:<port>`. Any other Host (a rebinding page's own
 * name) gets 403, so another site in the reader's browser cannot read routes.
 */
export function allowedHosts(host: string, port: number): Set<string> {
  const h = host.toLowerCase();
  if (LOOPBACK_HOSTS.includes(h)) return new Set([`127.0.0.1:${port}`, `localhost:${port}`, `[::1]:${port}`]);
  return new Set([`${h.includes(":") && !h.startsWith("[") ? `[${h}]` : h}:${port}`]);
}

async function handle(flags: Flags, hosts: Set<string>, req: Request, reconcile: () => void): Promise<Response> {
  if (!hosts.has((req.headers.get("host") ?? "").toLowerCase())) return new Response("forbidden host\n", { status: 403 });
  const url = new URL(req.url);
  let path: string;
  try {
    path = decodeURIComponent(url.pathname);
  } catch {
    return new Response("bad path\n", { status: 400 });
  }
  if (path.length > 1) path = path.replace(/\/+$/, "");
  // The one route that writes: a reader's answer to a question page's form.
  const answer = path.match(/^\/questions\/(q\d{1,6})\/answer$/);
  if (answer) {
    if (req.method !== "POST") return new Response("post only\n", { status: 405 });
    return recordAnswer(flags, hosts, answer[1], req);
  }
  if (req.method !== "GET" && req.method !== "HEAD") return new Response("read-only\n", { status: 405 });
  const answered = path.match(/^\/questions\/(q\d{1,6})\/answered$/);
  if (answered) {
    const at = (url.searchParams.get("at") ?? "").replace(/[^0-9TZ:.-]/g, "").slice(0, 32);
    return new Response(T.answeredPage(answered[1], at), {
      headers: { "content-type": "text/html; charset=utf-8", "content-security-policy": "sandbox allow-scripts allow-forms allow-popups" },
    });
  }
  const qhtml = path.match(/^\/questions\/(q\d{1,6})\/html$/);
  if (qhtml) {
    // The question page, served as-is like an explainer, in the same CSP sandbox plus forms.
    const bytes = readRegular(join(questionsDir(flags), `${qhtml[1]}.html`));
    if (bytes === null) return new Response("not found\n", { status: 404 });
    return new Response(bytes, {
      headers: { "content-type": "text/html; charset=utf-8", "content-security-policy": "sandbox allow-scripts allow-forms allow-popups" },
    });
  }
  if (path === "/api/questions") {
    return Response.json(scanQuestions(flags));
  }

  if (path === "/board.css") {
    return new Response(readFileSync(CSS_PATH), { headers: { "content-type": "text/css; charset=utf-8" } });
  }
  if (path === "/api/changes") {
    return Response.json(scanChanges(flags.root));
  }
  if (path === "/api/baselines") {
    return Response.json(scanBaselines(flags.root));
  }
  if (path === "/api/lanes") {
    return Response.json(await scanLanes(flags.root, scanChanges(flags.root), flags.lanes));
  }
  if (path === "/events") {
    return events(flags, url.searchParams.get("page") ?? "/", reconcile);
  }
  const explainer = path.match(/^\/change\/([^/]+)\/html\/([^/]+)$/);
  if (explainer) {
    // Served as-is: the explainers are standalone pages with their own styles.
    // The name must be a regular file in the scan; the read refuses a symlink
    // and returns 404 if the file was replaced or removed after the scan.
    const notFound = new Response("not found\n", { status: 404 });
    const change = scanChanges(flags.root).find((c) => c.name === explainer[1]);
    if (!change || !change.html.includes(explainer[2])) return notFound;
    const bytes = readRegular(join(flags.root, "openspec", "changes", ...change.dir.split("/"), explainer[2]));
    if (bytes === null) return notFound;
    // The CSP sandbox gives the standalone view the same opaque-origin
    // isolation as the board's sandboxed iframe.
    return new Response(bytes, {
      headers: { "content-type": "text/html; charset=utf-8", "content-security-policy": "sandbox allow-scripts allow-popups" },
    });
  }
  const v = await view(flags, path, snapshot(flags));
  // `?embed=1` renders without the header and nav, for the index's quick-view panel.
  return new Response(T.shell(v.title, v.nav, v.main, path, url.searchParams.get("embed") === "1"), {
    status: v.status,
    headers: { "content-type": "text/html; charset=utf-8" },
  });
}

if (import.meta.main) {
  const flags = parseFlags(process.argv.slice(2));
  const verbose = process.env.BOARD_VERBOSE === "1";
  const watcher = new Watcher(flags, (n) => {
    if (verbose && n > 0) console.log(`board: pushed ${n} fragment(s)`);
  });
  watcher.start();
  // The allowed Host set needs the bound port, which `--port 0` only fixes
  // after the listen; until then every request is refused.
  let hosts = new Set<string>();
  const server = Bun.serve({
    hostname: flags.host,
    port: flags.port,
    // Never serve Bun's development error page (stack and source).
    development: false,
    error(err) {
      console.error(`board: request failed: ${err}`);
      return new Response("internal error\n", { status: 500, headers: { "content-type": "text/plain; charset=utf-8" } });
    },
    fetch: (req) => handle(flags, hosts, req, () => watcher.reconcile()),
  });
  hosts = allowedHosts(flags.host, server.port);
  console.log(`board: reading ${flags.root}${flags.lanes ? ` and lanes in ${flags.lanes}` : ""}; answers are appended under ${questionsDir(flags)}`);
  console.log(`board: watching ${watcher.size} directories`);
  console.log(`board: listening on http://${server.hostname}:${server.port}/`);
}
