// Page template and HTML fragments for the dev board. Every fragment that the
// SSE stream may replace carries a stable id (`nav`, `main`, and on the index
// `index-tables` and `lanes`) so a Datastar outer morph lands on the same
// element the first render produced.
//
// Morphs copy the server's attributes onto the live element, so state the
// reader changes in the browser is listed in `data-preserve-attr`: `open` on
// <details>, and the `style`/`aria-selected` that the explainer tabs set.
// Nested elements a morph should match keep stable ids for the same reason.

import type { ActivityLine, Baseline, Change, Lane, LaneScan, LaneStatus, Phase, Question, TaskItem } from "./server.ts";

/** Pinned Datastar release; see README.md for where the version was found. */
export const DATASTAR_URL = "https://cdn.jsdelivr.net/gh/starfederation/datastar@v1.0.4/bundles/datastar.js";
/** Subresource Integrity hash of DATASTAR_URL; README.md records how it was computed. */
export const DATASTAR_SRI = "sha384-twbOvafhSBQ0rJDNPzJdUw6DRvthVgAVfSIG1BQVmCiNO7Qh2zeVn7T5qstgjJ9q";

/**
 * HTML-escapes text, and replaces C0 control characters other than tab and
 * newline (and DEL) with U+FFFD. A carriage return from lane content (a commit
 * subject, a file name) would otherwise end an SSE data line; the visible
 * replacement shows that something was there.
 */
export function esc(s: string): string {
  return s
    .replace(/[\u0000-\u0008\u000b-\u001f\u007f]/g, "\ufffd")
    .replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]!);
}

const href = (name: string) => encodeURIComponent(name);

/** An id-safe slug: Datastar and CSS selectors need no escaping for it. */
const slug = (s: string) => s.toLowerCase().replace(/[^a-z0-9-]+/g, "-");

/**
 * On the index, a click on any same-origin page link opens that page in the
 * quick-view panel instead of leaving the index: the handler is delegated
 * from the shell, so links in pushed fragments need nothing extra. Links with
 * a hash (lane anchors), a target, or to the index itself keep their default.
 */
const PEEK_HANDLER = "const a = evt.target.closest('a[href]'); if (a && a.origin == location.origin && !a.hash && !a.target && a.pathname != '/') { evt.preventDefault(); $panel = a.pathname; }";

/** The quick-view panel: a drawer showing a board page embedded (no header or nav), still live over its own /events stream. */
function panel(): string {
  return `<div id="panel-backdrop" class="panel-backdrop" data-show="$panel != ''" data-preserve-attr="style" style="display:none" data-on:click="$panel = ''"></div>
<aside id="panel" class="panel" data-show="$panel != ''" data-preserve-attr="style" style="display:none" aria-label="Quick view">
<div class="panel-bar"><span class="panel-path" data-text="$panel"></span><a class="panel-open" data-attr:href="$panel" target="_top">open in full</a><button type="button" class="panel-close" aria-label="Close the quick view" data-on:click="$panel = ''">×</button></div>
<iframe id="panel-frame" class="panel-frame" title="Quick view" data-attr:src="$panel ? $panel + ($panel.indexOf('/html/') > 0 ? '' : '?embed=1') : 'about:blank'" sandbox="allow-scripts allow-same-origin allow-forms allow-popups allow-top-navigation-by-user-activation"></iframe>
</aside>`;
}

/**
 * Full document. `page` is the board path whose fragments /events re-renders.
 * `embed` renders the page without the header and nav, for the quick-view
 * panel (`?embed=1`); it keeps its own live stream.
 */
export function shell(title: string, nav: string, main: string, page: string, embed = false): string {
  const init = esc(`@get('/events?page=' + ${JSON.stringify(encodeURIComponent(page))})`);
  if (embed) {
    return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>${esc(title)} · Writ board</title>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Fraunces:opsz,wght@9..144,500;9..144,700&family=Source+Sans+3:ital,wght@0,400;0,600;1,400&family=JetBrains+Mono:wght@400;600&display=swap">
<link rel="stylesheet" href="/board.css">
<script type="module" src="${DATASTAR_URL}" integrity="${DATASTAR_SRI}" crossorigin="anonymous"></script>
</head>
<body class="embed" data-init="${init}">
${main}
</body>
</html>
`;
  }
  const onIndex = page === "/";
  const shellAttrs = onIndex ? ` data-signals:panel__ifmissing="''" data-on:click="${esc(PEEK_HANDLER)}" data-on:keydown__window="evt.key == 'Escape' &amp;&amp; ($panel = '')"` : "";
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>${esc(title)} · Writ board</title>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Fraunces:opsz,wght@9..144,500;9..144,700&family=Source+Sans+3:ital,wght@0,400;0,600;1,400&family=JetBrains+Mono:wght@400;600&display=swap">
<link rel="stylesheet" href="/board.css">
<script type="module" src="${DATASTAR_URL}" integrity="${DATASTAR_SRI}" crossorigin="anonymous"></script>
</head>
<body data-init="${init}">
<header class="top"><a class="brand" href="/">Writ board</a><span class="note">read-only view of openspec/; makes no verification claim</span></header>
<div class="shell"${shellAttrs}>
${nav}
${main}
</div>
${onIndex ? panel() : ""}
</body>
</html>
`;
}

function progress(t: { done: number; total: number }): string {
  const pct = t.total === 0 ? 0 : Math.round((100 * t.done) / t.total);
  return `<span class="progress" title="${t.done} of ${t.total} task boxes checked"><span class="bar"><span style="width:${pct}%"></span></span><span class="num">${t.done}/${t.total}</span></span>`;
}

const statusTag = (s: string) => `<span class="status status-${esc(s.replace(/[^a-z0-9-]/gi, ""))}">${esc(s)}</span>`;

/** "12 s", "4 min", "3 h", "2 d": how long ago an epoch-ms signal was. */
export function ago(at: number | null, now = Date.now()): string {
  if (at === null) return "no signal";
  const s = Math.max(0, Math.round((now - at) / 1000));
  if (s < 60) return `${s} s`;
  const m = Math.round(s / 60);
  if (m < 60) return `${m} min`;
  const h = Math.round(m / 60);
  if (h < 48) return `${h} h`;
  return `${Math.round(h / 24)} d`;
}

const PHASE_WORDS: Record<Phase["label"], string> = {
  dispatched: "dispatched", implemented: "implemented, awaiting review", review: "in review", fix: "fix round",
  complete: "complete", landed: "landed", unknown: "",
};

/** The newest plan phase of a lane, as a short phrase ("Task 3 · fix round"). */
export function phaseText(l: Lane): string {
  const p = [...l.sdd].reverse().find((x) => x.phase !== null)?.phase ?? null;
  if (p === null) return "no ledger phase";
  const word = PHASE_WORDS[p.label] || "see ledger";
  return p.task === null ? word : `Task ${p.task} · ${word}`;
}

/** The newest activity line of a lane, or null. */
function latestActivity(l: Lane): string | null {
  const a = l.activity[l.activity.length - 1];
  return a ? a.text : null;
}

const dot = (status: LaneStatus) => `<span class="dot dot-${status}" aria-hidden="true"></span>`;

/**
 * A lane chip for a change row: dot, lane name, phase, age, on one line. The
 * phase is the part that gives way (ellipsis) on a narrow row, so it carries
 * its full text as a tooltip; the age never truncates.
 */
function laneChip(l: Lane): string {
  const latest = latestActivity(l);
  const title = latest === null ? "" : ` title="${esc(latest)}"`;
  const phase = esc(phaseText(l));
  return `<span class="chip chip-${l.status}"${title}>${dot(l.status)}<a href="#lane-${slug(l.name)}">${esc(l.name)}</a><span class="chip-phase" title="${phase}">${phase}</span><span class="chip-age">${esc(ago(l.signalAt))}</span></span>`;
}

/** Datastar signal name for a change's task row: slugs are not identifiers, so hyphens become underscores. */
const taskSignal = (c: Change) => `t_${slug(c.name).replace(/-/g, "_")}`;

/**
 * The task row under a change: open tasks first as cards grouped by section,
 * done tasks behind a nested toggle. Shown by a Datastar signal the chevron
 * at the start of the change row flips; the row spans the table so opening
 * it never resizes the columns. `style` is preserved across morphs so the
 * reader's open rows stay open.
 */
function taskRow(c: Change, columns: number): string {
  if (c.taskList.length === 0) return "";
  const group = (items: TaskItem[]) => {
    let section: string | null = null;
    const out: string[] = [];
    for (const t of items) {
      if (t.section !== section) {
        section = t.section;
        if (section !== null) out.push(`<li class="task-section">${esc(section)}</li>`);
      }
      out.push(`<li class="task ${t.done ? "task-done" : "task-open"}"><span class="task-id">${t.id === null ? "·" : esc(t.id)}</span><span class="task-text">${esc(t.text)}</span></li>`);
    }
    return out.join("");
  };
  const open = c.taskList.filter((t) => !t.done);
  const done = c.taskList.filter((t) => t.done);
  const openList = open.length === 0
    ? `<p class="muted small">Every box is checked.</p>`
    : `<ul class="tasks">${group(open)}</ul>`;
  const doneList = done.length === 0
    ? ""
    : `<details id="done-${slug(c.name)}" class="donelist" data-preserve-attr="open"><summary>${done.length} done</summary><ul class="tasks">${group(done)}</ul></details>`;
  return `<tr id="tasks-${slug(c.name)}" class="taskrow" data-show="$${taskSignal(c)}" data-preserve-attr="style" style="display:none"><td colspan="${columns}"><div class="taskrow-inner"><div class="doc-label">openspec/changes/${esc(c.name)}/tasks.md · ${open.length} to do · ${done.length} done</div>${openList}${doneList}</div></td></tr>`;
}

/** Datastar signal for a change's activity row. */
const activitySignal = (c: Change) => `a_${slug(c.name).replace(/-/g, "_")}`;

/** The newest activity lines across the lanes on a change, oldest first. */
function changeActivity(lanes: Lane[]): (ActivityLine & { lane: string })[] {
  const all = lanes.flatMap((l) => l.activity.map((a) => ({ ...a, lane: l.name })));
  return all.sort((a, b) => (a.at < b.at ? -1 : a.at > b.at ? 1 : 0)).slice(-ACTIVITY_ROW_LINES);
}
const ACTIVITY_ROW_LINES = 10;

/** The time part of an ISO timestamp, as the feeds show it. */
const clock = (at: string) => at.replace(/^\d{4}-\d{2}-\d{2}T/, "").replace(/Z$/, "");

/**
 * The activity icon on a change row: hover shows the last three lines as a
 * tooltip, click opens a full-width row with the last ten lines across the
 * lanes on the change (same reversed list as the lane feeds, newest at the
 * end and in view).
 */
function activityIcon(c: Change, lines: (ActivityLine & { lane: string })[]): string {
  if (lines.length === 0) return "";
  const sig = activitySignal(c);
  const tip = lines.slice(-3).map((a) => `${clock(a.at)} ${a.lane}: ${a.text}`).join("\n");
  return `<button type="button" class="act" aria-label="Show recent activity" aria-controls="activity-${slug(c.name)}" title="${esc(tip)}" data-on:click="$${sig} = !$${sig}" data-attr:aria-expanded="$${sig} ? 'true' : 'false'" data-class:open="$${sig}" data-preserve-attr="aria-expanded class"><svg viewBox="0 0 16 16" width="14" height="14" aria-hidden="true"><path d="M1 8h3l2-5 3 10 2-5h4" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linejoin="round" stroke-linecap="round"/></svg></button>`;
}

/**
 * The ticker under a change row: its newest activity line. The line's id
 * carries a hash of its content, so a new line is a new element to the morph
 * and the CSS enter animation plays; an unchanged line is left alone.
 */
function tickerRow(c: Change, lines: (ActivityLine & { lane: string })[], columns: number): string {
  const a = lines[lines.length - 1];
  if (!a) return "";
  let h = 0;
  for (const ch of `${a.at}${a.lane}${a.who}${a.text}`) h = (h * 31 + ch.charCodeAt(0)) >>> 0;
  // One line; the text gives way with an ellipsis and keeps its full wording as a tooltip.
  return `<tr class="tickerrow"><td colspan="${columns}"><p id="tick-${slug(c.name)}-${h.toString(36)}" class="ticker"><span class="log-at">${esc(clock(a.at))}</span><span class="log-who">${esc(a.lane)}${a.who ? `<span class="log-role"> · ${esc(a.who)}</span>` : ""}</span><span class="log-text" title="${esc(a.text)}">${esc(a.text)}</span></p></td></tr>`;
}

function activityRow(c: Change, lines: (ActivityLine & { lane: string })[], columns: number): string {
  if (lines.length === 0) return "";
  const items = [...lines].reverse().map((a) =>
    `<li><span class="log-at">${esc(clock(a.at))}</span><span class="log-who">${esc(a.lane)}${a.who ? ` · ${esc(a.who)}` : ""}</span><span class="log-text">${esc(a.text)}</span></li>`).join("");
  return `<tr id="activity-${slug(c.name)}" class="taskrow activityrow" data-show="$${activitySignal(c)}" data-preserve-attr="style" style="display:none"><td colspan="${columns}"><div class="taskrow-inner"><div class="doc-label">recent activity on ${esc(c.name)}, last ${lines.length} lines across ${new Set(lines.map((a) => a.lane)).size} lane(s)</div><ol class="log" reversed>${items}</ol></div></td></tr>`;
}

/** The chevron that opens a change's task row; a real button so it is keyboard-reachable. */
function chevron(c: Change): string {
  if (c.taskList.length === 0) return `<td class="chev-cell"></td>`;
  const sig = taskSignal(c);
  return `<td class="chev-cell"><button type="button" class="chev" aria-label="Show the task list" aria-controls="tasks-${slug(c.name)}" data-on:click="$${sig} = !$${sig}" data-attr:aria-expanded="$${sig} ? 'true' : 'false'" data-class:open="$${sig}" data-preserve-attr="aria-expanded class"></button></td>`;
}


/** Left list of changes grouped by status, then a link per baseline section. */
export function nav(changes: Change[], page: string, questions: Question[] = []): string {
  const open = questions.filter((q) => q.status === "open").length;
  const qlink = `<a class="home qlink"${page === "/questions" ? ` aria-current="page"` : ""} href="/questions">Questions${open > 0 ? ` <span class="count">${open}</span>` : ""}</a>`;
  const groups = new Map<string, Change[]>();
  for (const c of changes) groups.set(c.status, [...(groups.get(c.status) ?? []), c]);
  const body = [...groups.keys()].sort().map((status) => {
    const items = groups.get(status)!.map((c) => {
      const path = `/change/${c.name}`;
      const current = page === path ? ` aria-current="page"` : "";
      return `<li><a href="/change/${href(c.name)}"${current}>${esc(c.archived ? c.title : c.name)}</a></li>`;
    }).join("");
    // Archived changes start collapsed; the rest open.
    return `<details${status === "archived" ? "" : " open"} data-preserve-attr="open"><summary>${esc(status)} <span class="count">${groups.get(status)!.length}</span></summary><ul>${items}</ul></details>`;
  }).join("");
  return `<nav id="nav" class="side" aria-label="Changes"><a class="home"${page === "/" ? ` aria-current="page"` : ""} href="/">Index</a>${qlink}${body}</nav>`;
}

/**
 * Index tables (summary tiles, changes with their lanes, then baselines);
 * patched as `#index-tables`. Changes with a task done or a lane on them come
 * first; the rest collapse under one line so the live ones are visible.
 */
export function indexTables(baselines: Baseline[], allChanges: Change[], scan: LaneScan | null, questions: Question[] = []): string {
  const questionsSection = questionsSummary(questions);
  const changes = allChanges.filter((c) => !c.archived);
  const archived = allChanges.filter((c) => c.archived).sort((a, b) => (a.archivedOn ?? "") < (b.archivedOn ?? "") ? 1 : -1);
  const archivedRows = archived.map((c) => `<tr>
<td class="n">${esc(c.archivedOn ?? "")}</td>
<td><a href="/change/${href(c.name)}">${esc(c.title)}</a><div class="sub">${esc(c.name.replace(/^\d{4}-\d{2}-\d{2}-/, ""))}</div></td>
<td>${c.specs.map((x) => `<a href="/spec/${href(x)}">${esc(x)}</a>`).join(", ") || `<span class="muted">none</span>`}</td>
<td>${c.html.map((f) => `<a href="/change/${href(c.name)}/html/${href(f)}">${esc(f)}</a>`).join("<br>") || `<span class="muted">none</span>`}</td>
</tr>`).join("");
  const archivedTable = archived.length === 0 ? "" : `<h2>Archived changes</h2>
<p class="muted small">${archived.length} change${archived.length === 1 ? "" : "s"} landed and archived; each one's spec delta is folded into the baseline capability it names.</p>
<div class="tablewrap"><table>
<thead><tr><th>Archived</th><th>Change</th><th>Baseline capability</th><th>Explainers</th></tr></thead>
<tbody>${archivedRows}</tbody>
</table></div>`;
  const lanesOf = new Map<string, Lane[]>();
  for (const l of scan?.lanes ?? []) for (const c of l.changes) lanesOf.set(c, [...(lanesOf.get(c) ?? []), l]);
  const live = (l: Lane) => l.status === "active" || l.status === "review";
  const workedOn = changes.filter((c) => (lanesOf.get(c.name) ?? []).some(live));
  const done = changes.reduce((n, c) => n + c.tasks.done, 0);
  const total = changes.reduce((n, c) => n + c.tasks.total, 0);
  const lanes = scan?.lanes ?? [];
  const liveLanes = lanes.filter(live);
  const landed = lanes.filter((l) => l.status === "landed");
  const tiles = scan === null ? "" : `<div class="tiles">
<div class="tile"><span class="tile-label">Being worked on</span><span class="tile-value">${workedOn.length} change${workedOn.length === 1 ? "" : "s"}</span><span class="tile-sub">${workedOn.map((c) => esc(c.name)).join(" · ") || "no lane with a signal in the last 30 min"}</span></div>
<div class="tile"><span class="tile-label">Tasks done</span><span class="tile-value">${done} of ${total}</span><span class="tile-sub">checkbox counts across every tasks.md</span></div>
<div class="tile"><span class="tile-label">Questions for you</span><span class="tile-value">${questions.filter((q) => q.status === "open").length} open</span><span class="tile-sub">${questions.filter((q) => q.status === "answered").length} answered · ${questions.filter((q) => q.status === "closed").length} closed</span></div>
<div class="tile"><span class="tile-label">Lanes</span><span class="tile-value">${liveLanes.length} live · ${landed.length} landed</span><span class="tile-sub">${lanes.length} worktrees; a lane is live when its ledger says review or anything in it was written in the last 30 min</span></div>
</div>`;
  const baseRows = baselines.map((b) => `<tr>
<td><a href="/spec/${href(b.name)}">${esc(b.name)}</a><div class="sub">${esc(b.title)}</div></td>
<td class="n">${b.requirements}</td>
<td>${b.traceability ? `<a href="/spec/${href(b.name)}/traceability">traceability</a>` : `<span class="muted">none</span>`}</td>
</tr>`).join("");
  const row = (c: Change) => {
    const on = lanesOf.get(c.name) ?? [];
    const landedOn = on.filter((l) => l.status === "landed");
    const lines = changeActivity(on);
    // Icon in its own column, then one chip per line and the landed lanes as a single muted line.
    const icon = activityIcon(c, lines);
    const list = on.filter((l) => l.status !== "landed").map(laneChip).join("")
      + (landedOn.length === 0 ? "" : `<span class="muted landed-list" title="landed: ${esc(landedOn.map((l) => l.name).join(", "))}">landed: ${landedOn.map((l) => `<a href="#lane-${slug(l.name)}">${esc(l.name)}</a>`).join(", ")}</span>`);
    const chips = icon === "" && list === "" ? "" : `<div class="workers">${icon}<div class="worker-list">${list}</div></div>`;
    const deps = c.dependsOn.length === 0 ? "" : ` · depends on ${c.dependsOn.length}`;
    return `<tr class="change-row${(lanesOf.get(c.name) ?? []).some(live) ? " row-live" : ""}">
${chevron(c)}<td><a href="/change/${href(c.name)}">${esc(c.name)}</a><div class="sub" title="${esc(c.dependsOn.join(", ") || "no dependencies")}">${esc(c.title)}${deps}</div></td>
<td class="status-cell">${statusTag(c.status)}</td>
<td class="tasks-cell">${progress(c.tasks)}</td>
<td class="chips">${chips || `<span class="muted">none</span>`}</td>
<td class="expl-cell">${c.html.map((f) => `<a href="/change/${href(c.name)}/html/${href(f)}">${esc(f)}</a>`).join("<br>") || `<span class="muted">none</span>`}</td>
</tr>${tickerRow(c, lines, 6)}${taskRow(c, 6)}${activityRow(c, lines, 6)}`;
  };
  // One signal per change for its task row and one for its activity row, false unless the reader already flipped it.
  const signals = JSON.stringify(Object.fromEntries([
    ...changes.filter((c) => c.taskList.length > 0).map((c) => [taskSignal(c), false]),
    ...changes.filter((c) => (lanesOf.get(c.name) ?? []).some((l) => l.activity.length > 0)).map((c) => [activitySignal(c), false]),
  ]));
  const shown = changes.filter((c) => c.tasks.done > 0 || (lanesOf.get(c.name) ?? []).length > 0);
  const rest = changes.filter((c) => !shown.includes(c));
  const restBoxes = rest.reduce((n, c) => n + c.tasks.total, 0);
  const restRows = rest.length === 0 ? "" : `<tr class="rest"><td colspan="6"><details id="rest-changes" data-preserve-attr="open"><summary>${rest.length} more change${rest.length === 1 ? "" : "s"} with no task done and no lane (0 of ${restBoxes} boxes)</summary>
<div class="tablewrap"><table class="changes"><tbody>${rest.map(row).join("")}</tbody></table></div></details></td></tr>`;
  return `<section id="index-tables" data-signals__ifmissing="${esc(signals)}">
${tiles}
${questionsSection}
<p class="lede">${baselines.length} baseline capabilities and ${changes.length} pending changes. Task counts are checkbox counts as written in each <code>tasks.md</code>, not evidence; a lane chip is what that lane's ledger and activity log say.</p>
<h2>Pending changes</h2>
<div class="tablewrap"><table class="changes">
<thead><tr><th class="chev-cell"></th><th>Change</th><th class="status-cell">Status</th><th class="tasks-cell">Tasks</th><th class="chips">Worked on by</th><th class="expl-cell">Explainers</th></tr></thead>
<tbody>${shown.map(row).join("")}${restRows}</tbody>
</table></div>
${archivedTable}
<h2>Baseline capabilities</h2>
<div class="tablewrap"><table>
<thead><tr><th>Capability</th><th>Reqs</th><th>Traceability</th></tr></thead>
<tbody>${baseRows}</tbody>
</table></div>
</section>`;
}

/**
 * Index content: tiles and the change table first (the lane chips there are
 * the coordination view), the lane cards after. The index uses the full width.
 */
export function index(tables: string, lanes: string, _lanesFirst: boolean): string {
  return `<main id="main" class="content wide">
<h1>Writ OpenSpec board</h1>
${tables}
${lanes}
</main>`;
}

const count = (t: { done: number; total: number } | null) => (t === null ? "absent" : `${t.done}/${t.total}`);

/** One lane worktree: identity line, then ledger, reports, task drift, verification. */
function laneCard(l: Lane): string {
  const id = `lane-${slug(l.name)}`;
  const branch = l.branch === null ? "" : `<span class="branch">${esc(l.branch)}</span>`;
  const commit = l.commit === null
    ? ""
    : `<p class="commit"><code>${esc(l.commit.hash)}</code> ${esc(l.commit.subject)} <span class="muted">${esc(l.commit.when)}</span></p>`;
  const notes = l.notes.map((n) => `<p class="note-line">${esc(n)}</p>`).join("");
  const changes = l.changes.length === 0
    ? ""
    : `<span class="lane-changes">on ${l.changes.map((c) => `<a href="/change/${href(c)}">${esc(c)}</a>`).join(", ")}</span>`;
  const activity = l.activityNote !== null
    ? `<p class="note-line">${esc(l.activityNote)}</p>`
    : l.activity.length === 0
      ? `<p class="muted small">No activity.log in this lane's record yet; agents append one line per step.</p>`
      // Newest first in the DOM; the list is a column-reverse flex box, so it
      // reads oldest to newest and opens scrolled to the newest line.
      : `<ol class="log" reversed>${[...l.activity].reverse().map((a) =>
          `<li><span class="log-at">${esc(a.at.replace(/^\d{4}-\d{2}-\d{2}T/, "").replace(/Z$/, ""))}</span><span class="log-who">${esc(a.who)}</span><span class="log-text">${esc(a.text)}</span></li>`).join("")}</ol>`;
  const logName = l.sdd.length === 1 ? `${l.sdd[0].dir}/activity.log` : `activity.log of ${l.sdd.length} records`;
  const feed = `<div class="activity"><div class="doc-label">${esc(logName)}, last ${l.activity.length} lines</div>${activity}</div>`;
  const status = `<p class="lane-status">${dot(l.status)}<span class="lane-phase">${esc(phaseText(l))}</span><span class="muted">${esc(ago(l.signalAt))}${l.signalAt === null ? "" : " ago"}</span>${changes}</p>`;
  const sdd = l.sdd.map((p) => {
    const rel = p.dir;
    const ledger = p.ledger === null
      ? `<p class="note-line">${esc(p.ledgerNote ?? "no ledger")}</p>`
      : `<div class="md ledger">${p.ledger}</div>`;

    const reports = p.reports.length === 0
      ? `<p class="muted small">No task reports yet.</p>`
      : p.reports.map((r) => {
          const rid = `${id}-${slug(p.plan)}-${slug(r.file)}`;
          const status = r.status === null ? "" : ` <span class="report-status">${esc(r.status)}</span>`;
          const body = r.html === null ? `<p class="note-line">${esc(r.file)} could not be read</p>` : `<div class="md">${r.html}</div>`;
          return `<details id="${rid}" class="report" data-preserve-attr="open"><summary><code>${esc(r.file)}</code>${status}</summary>${body}</details>`;
        }).join("");
    const reviews = p.reviews.map((r) => {
      const rid = `${id}-${slug(p.plan)}-${slug(r.file)}`;
      const body = r.html === null ? `<p class="note-line">${esc(r.file)} could not be read</p>` : `<div class="md">${r.html}</div>`;
      return `<details id="${rid}" class="report review" data-preserve-attr="open"><summary><code>${esc(r.file)}</code> <span class="report-status">reviewer</span></summary>${body}</details>`;
    }).join("");
    const more = `<details id="${id}-${slug(p.plan)}-ledger" class="more" data-preserve-attr="open"><summary>${esc(rel)}/progress.md, last 10 lines · ${p.reports.length} report${p.reports.length === 1 ? "" : "s"} · ${p.reviews.length} review${p.reviews.length === 1 ? "" : "s"}</summary>${ledger}${reports}${reviews}</details>`;
    return `<div class="plan">${more}</div>`;
  }).join("");
  const diffs = l.taskDiffs.length === 0
    ? ""
    : `<details id="${id}-drift" class="more drift" data-preserve-attr="open"><summary>Task boxes differing from the root · ${l.taskDiffs.length}</summary><ul>${l.taskDiffs.map((d) =>
        `<li>${d.root === null ? `<code>${esc(d.name)}</code>` : `<a href="/change/${href(d.name)}">${esc(d.name)}</a>`} <span class="num">${count(d.lane)}</span> <span class="muted">here, root ${count(d.root)}</span></li>`).join("")}</ul></details>`;
  const ver = l.verification === null || l.verification.length === 0
    ? ""
    : `<details id="${id}-verification" class="more drift" data-preserve-attr="open"><summary>verification/ files new or changed relative to the root · ${l.verification.length}</summary><ul>${l.verification.map((v) =>
        `<li><code>${esc(v.path)}</code> <span class="muted">${v.kind}</span></li>`).join("")}</ul></details>`;
  return `<article id="${id}" class="lane lane-${l.status}">
<header><h3>${esc(l.name)}</h3>${branch}</header>
${status}${commit}${notes}${feed}${sdd}${diffs}${ver}
</article>`;
}

const QSTATUS: Record<Question["status"], string> = { open: "needs an answer", answered: "answered", closed: "closed" };

/** Index section: only the questions still waiting on the reader, newest first; answered and closed ones live on /questions. Empty when nothing is open. */
function questionsSummary(questions: Question[]): string {
  const live = questions.filter((q) => q.status === "open");
  if (live.length === 0) return "";
  const rows = live.map((q) => {
    const last = q.answers[q.answers.length - 1];
    const lastText = last ? `${esc(last.who)} · ${esc(clock(last.at))}: ${esc(Object.values(last.fields).join(" · ").slice(0, 90))}` : "no answer yet";
    return `<tr class="qrow q-${q.status}">
<td><span class="dot dot-${q.status === "open" ? "review" : q.status === "answered" ? "active" : "landed"}" aria-hidden="true"></span></td>
<td><a href="/questions/${esc(q.id)}">${esc(q.title)}</a>${q.topic ? `<div class="sub">${esc(q.topic)}</div>` : ""}</td>
<td><span class="status status-${q.status}">${QSTATUS[q.status]}</span></td>
<td class="qlast">${lastText}</td>
</tr>`;
  }).join("");
  return `<h2>Questions for you</h2>
<p class="muted small">Waiting on you: ${live.length}. Answer in the drawer; answered questions move to the <a href="/questions">questions page</a>.</p>
<div class="tablewrap"><table class="questions">
<thead><tr><th class="chev-cell"></th><th>Question</th><th>Status</th><th>Latest</th></tr></thead>
<tbody>${rows}</tbody>
</table></div>`;
}

/** One answer entry: who, when, and each field as a label/value pair; `text` fields read as prose. */
function answerBlock(a: { at: string; who: string; fields: Record<string, string> }): string {
  const who = a.who === "controller" ? "me" : a.who || "reply";
  const pairs = Object.entries(a.fields).map(([k, v]) =>
    k === "text" || k === "answer" || k === "note"
      ? `<p class="answer-text">${esc(v).replace(/\n/g, "<br>")}</p>`
      : `<div class="answer-field"><dt>${esc(k)}</dt><dd>${esc(v).replace(/\n/g, "<br>")}</dd></div>`).join("");
  const stamp = a.at.replace("T", " ").replace(/\.\d{1,3}Z$/, "Z");
  return `<li class="answer answer-${a.who === "controller" ? "controller" : "reader"}"><div class="answer-head"><span class="log-who">${esc(who)}</span><span class="log-at">${esc(stamp)}</span></div><dl>${pairs}</dl></li>`;
}

/** The thread under a question page: every entry so far, oldest first. */
function answersList(q: Question): string {
  if (q.answers.length === 0) return `<p class="muted small">No answer yet.</p>`;
  return `<ol class="answers">${q.answers.map(answerBlock).join("")}</ol>`;
}

/** A question page: its authored HTML in a sandboxed iframe (forms allowed), then the thread. */
export function questionPage(q: Question): string {
  return `<main id="main" class="content">
<p class="eyebrow">question · ${esc(q.id)}${q.topic ? ` · ${esc(q.topic)}` : ""} · <span class="status status-${q.status}">${QSTATUS[q.status]}</span></p>
<h1>${esc(q.title)}</h1>
<section class="qframe-wrap">
<iframe id="qframe-${esc(q.id)}" class="qframe" src="/questions/${esc(q.id)}/html" title="${esc(q.title)}" sandbox="allow-scripts allow-forms allow-popups"></iframe>
</section>
<section class="doc"><div class="doc-label">${esc(q.id)}.answers.jsonl, ${q.answers.length} entr${q.answers.length === 1 ? "y" : "ies"}</div>${answersList(q)}</section>
</main>`;
}

/** The small page a question's form lands on after its answer is recorded; it renders inside the form's own frame. */
export function answeredPage(id: string, at: string): string {
  return `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Recorded</title>
<style>body{margin:0;padding:1.2rem;font:15px/1.5 "Source Sans 3","Segoe UI",system-ui,sans-serif;color:#1d2230;background:#f7f6f2}@media (prefers-color-scheme:dark){body{color:#e6e4dc;background:#15181f}}a{color:#15655c}@media (prefers-color-scheme:dark){a{color:#5fc2b2}}</style>
</head><body>
<p><strong>Recorded</strong> at ${esc(at)}. Your answer is in the thread under this form and the controller sees it on its next read.</p>
<p><a href="/questions/${esc(id)}/html">Back to the form</a> to add more.</p>
</body></html>
`;
}

/** All questions, newest first, each linking to its page. */
export function questionsPage(questions: Question[]): string {
  const items = questions.map((q) => `<li><a href="/questions/${esc(q.id)}">${esc(q.title)}</a> <span class="status status-${q.status}">${QSTATUS[q.status]}</span>${q.lastAt ? ` <span class="muted small">last ${esc(clock(q.lastAt))}</span>` : ""}</li>`).join("");
  return `<main id="main" class="content">
<h1>Questions</h1>
<p class="lede">${questions.length} question${questions.length === 1 ? "" : "s"} from the controller. Each one is its own page with its own form; your answers are appended to that question's file and shown under it.</p>
${questions.length === 0 ? `<p class="muted">None yet.</p>` : `<ul class="qlist">${items}</ul>`}
</main>`;
}

/** The lanes panel, patched as `#lanes`. `scan` is null when --lanes is absent. */
export function lanesPanel(scan: LaneScan | null): string {
  let body: string;
  if (scan === null) body = `<p class="muted">No <code>--lanes</code> directory given.</p>`;
  else if (!scan.readable) body = `<p class="note-line">Lanes directory <code>${esc(scan.dir)}</code> could not be read.</p>`;
  else if (scan.lanes.length === 0) body = `<p class="muted">No git worktrees found in <code>${esc(scan.dir)}</code>.</p>`;
  else {
    // Live lanes first, then landed last; stable otherwise.
    const rank: Record<LaneStatus, number> = { active: 0, review: 0, idle: 1, landed: 2 };
    body = `<div class="lanes-grid">${[...scan.lanes].sort((a, b) => rank[a.status] - rank[b.status]).map(laneCard).join("\n")}</div>`;
  }
  const skipped = scan && scan.skipped.length > 0
    ? `<p class="muted small">Not git worktrees, skipped: ${scan.skipped.map((s) => `<code>${esc(s)}</code>`).join(", ")}</p>`
    : "";
  const lede = scan && scan.lanes.length > 0
    ? `<p class="muted small">${scan.lanes.length} worktrees in <code>${esc(scan.dir)}</code>. Ledgers and reports are what each lane wrote; they are not verification.</p>`
    : "";
  return `<section id="lanes" class="lanes-panel"><h2>Lanes</h2>${lede}${body}${skipped}</section>`;
}

type ChangeDocs = {
  proposal: string | null;
  design: string | null;
  tasks: string | null;
  specs: { capability: string; html: string }[];
};

/**
 * Change page. Tabs (Datastar signal `tab`) switch between the rendered
 * documents and one iframe per explainer. The documents tab keeps the order
 * proposal, design, tasks, spec deltas. The iframe keeps each explainer's own
 * styles intact because it is a separate document.
 */
export function changePage(c: Change, docs: ChangeDocs, all: Change[]): string {
  const known = new Set(all.map((x) => x.name));
  const deps = c.dependsOn.length === 0
    ? `<span class="muted">none</span>`
    : c.dependsOn.map((d) => known.has(d) ? `<a href="/change/${href(d)}">${esc(d)}</a>` : `<code>${esc(d)}</code>`).join(", ");
  const section = (id: string, label: string, html: string | null) =>
    html === null ? "" : `<section id="${id}" class="doc"><div class="doc-label">${esc(label)}</div><div class="md">${html}</div></section>`;
  const docsHtml = [
    section("proposal", "proposal.md", docs.proposal),
    section("design", "design.md", docs.design),
    section("tasks", "tasks.md", docs.tasks),
    ...docs.specs.map((s) => section(`spec-${s.capability}`, `specs/${s.capability}/spec.md`, s.html)),
  ].join("");
  const toc = [
    docs.proposal !== null ? `<a href="#proposal">Proposal</a>` : "",
    docs.design !== null ? `<a href="#design">Design</a>` : "",
    docs.tasks !== null ? `<a href="#tasks">Tasks</a>` : "",
    ...docs.specs.map((s) => `<a href="#spec-${esc(s.capability)}">Spec: ${esc(s.capability)}</a>`),
  ].join("");
  // Explainer names match /^[A-Za-z0-9._-]+\.html$/, so they are safe inside a quoted JS string.
  const tab = (key: string, label: string) =>
    `<button type="button" role="tab" data-preserve-attr="aria-selected" data-on:click="$tab = '${key}'" data-attr:aria-selected="$tab == '${key}' ? 'true' : 'false'">${esc(label)}</button>`;
  const tabs = c.html.length === 0 ? "" : `<div class="tabs" role="tablist">${tab("docs", "Documents")}${c.html.map((f) => tab(f, f)).join("")}</div>`;
  const frames = c.html.map((f) => {
    const src = `/change/${href(c.name)}/html/${href(f)}`;
    // Sandboxed without allow-same-origin: explainers run their own scripts but
    // cannot read the board's origin, storage, or cookies.
    return `<section id="explainer-${slug(f)}" class="explainer" data-show="$tab == '${f}'" data-preserve-attr="style" style="display:none">
<p class="frame-bar"><span>${esc(f)}, served as-is</span><a href="${src}" target="_blank" rel="noopener">open standalone</a></p>
<iframe id="frame-${slug(f)}" src="${src}" title="${esc(f)} for ${esc(c.name)}" loading="lazy" sandbox="allow-scripts allow-popups"></iframe>
</section>`;
  }).join("");
  return `<main id="main" class="content" data-signals:tab__ifmissing="'docs'">
<p class="eyebrow">${c.archived ? `archived ${esc(c.archivedOn ?? "")} · ${esc(c.name.replace(/^\d{4}-\d{2}-\d{2}-/, ""))}` : `change · ${esc(c.name)}`}</p>
<h1>${esc(c.title)}</h1>
<dl class="facts">
<div><dt>Status</dt><dd>${statusTag(c.status)}</dd></div>
<div><dt>Tasks</dt><dd>${progress(c.tasks)}</dd></div>
<div><dt>Depends on</dt><dd>${deps}</dd></div>
</dl>
${tabs}
<div class="docs" data-show="$tab == 'docs'" data-preserve-attr="style">
<nav class="toc" aria-label="Sections">${toc}</nav>
${docsHtml}
</div>
${frames}
</main>`;
}

export function specPage(b: Baseline, html: string, trace: boolean, repoPath: string): string {
  const other = trace
    ? `<a href="/spec/${href(b.name)}">specification</a>`
    : b.traceability ? `<a href="/spec/${href(b.name)}/traceability">traceability</a>` : `<span class="muted">no traceability file</span>`;
  return `<main id="main" class="content">
<p class="eyebrow">baseline · ${esc(b.name)}${trace ? " · traceability" : ""}</p>
<dl class="facts">
<div><dt>Requirements</dt><dd>${b.requirements}</dd></div>
<div><dt>See also</dt><dd>${other}</dd></div>
</dl>
<section class="doc"><div class="doc-label">${esc(repoPath)}</div><div class="md">${html}</div></section>
</main>`;
}

export function notFound(page: string): string {
  return `<main id="main" class="content"><h1>Not found</h1><p>No change, baseline, or page at <code>${esc(page)}</code>.</p><p><a href="/">Back to the index</a></p></main>`;
}
