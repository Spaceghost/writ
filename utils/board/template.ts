// Page template and HTML fragments for the dev board. Every fragment that the
// SSE stream may replace carries a stable id (`nav`, `main`, and on the index
// `index-tables` and `lanes`) so a Datastar outer morph lands on the same
// element the first render produced.
//
// Morphs copy the server's attributes onto the live element, so state the
// reader changes in the browser is listed in `data-preserve-attr`: `open` on
// <details>, and the `style`/`aria-selected` that the explainer tabs set.
// Nested elements a morph should match keep stable ids for the same reason.

import type { Baseline, Change, Lane, LaneScan, LaneStatus, Phase } from "./server.ts";

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

/** Full document. `page` is the board path whose fragments /events re-renders. */
export function shell(title: string, nav: string, main: string, page: string): string {
  const init = esc(`@get('/events?page=' + ${JSON.stringify(encodeURIComponent(page))})`);
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
<div class="shell">
${nav}
${main}
</div>
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
  for (const p of [...l.sdd].reverse()) {
    const a = p.activity[p.activity.length - 1];
    if (a) return a.text;
  }
  return null;
}

const dot = (status: LaneStatus) => `<span class="dot dot-${status}" aria-hidden="true"></span>`;

/** A lane chip for a change row: dot, lane name, phase, age. */
function laneChip(l: Lane): string {
  const latest = latestActivity(l);
  const title = latest === null ? "" : ` title="${esc(latest)}"`;
  return `<span class="chip chip-${l.status}"${title}>${dot(l.status)}<a href="#lane-${slug(l.name)}">${esc(l.name)}</a><span class="chip-phase">${esc(phaseText(l))}</span><span class="chip-age">${esc(ago(l.signalAt))}</span></span>`;
}

/** Task numbers a tasks.md marks done and open, for the line under a progress bar. */
function taskNumbers(c: Change): string {
  if (c.taskIds.done.length === 0 && c.taskIds.open.length === 0) return "";
  const list = (ids: string[]) => ids.map(esc).join(" ");
  const done = c.taskIds.done.length === 0 ? "" : `${list(c.taskIds.done)} done`;
  const open = c.taskIds.open.length === 0 ? "" : `${list(c.taskIds.open)} open`;
  return `<div class="sub tasknums">${[done, open].filter(Boolean).join(" · ")}</div>`;
}

/** Left list of changes grouped by status, then a link per baseline section. */
export function nav(changes: Change[], page: string): string {
  const groups = new Map<string, Change[]>();
  for (const c of changes) groups.set(c.status, [...(groups.get(c.status) ?? []), c]);
  const body = [...groups.keys()].sort().map((status) => {
    const items = groups.get(status)!.map((c) => {
      const path = `/change/${c.name}`;
      const current = page === path ? ` aria-current="page"` : "";
      return `<li><a href="/change/${href(c.name)}"${current}>${esc(c.name)}</a></li>`;
    }).join("");
    return `<details open data-preserve-attr="open"><summary>${esc(status)} <span class="count">${groups.get(status)!.length}</span></summary><ul>${items}</ul></details>`;
  }).join("");
  return `<nav id="nav" class="side" aria-label="Changes"><a class="home"${page === "/" ? ` aria-current="page"` : ""} href="/">Index</a>${body}</nav>`;
}

/**
 * Index tables (summary tiles, changes with their lanes, then baselines);
 * patched as `#index-tables`. Changes with a task done or a lane on them come
 * first; the rest collapse under one line so the live ones are visible.
 */
export function indexTables(baselines: Baseline[], changes: Change[], scan: LaneScan | null): string {
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
    const chips = on.filter((l) => l.status !== "landed").map(laneChip).join("")
      + (landedOn.length === 0 ? "" : `<span class="muted small landed-list">landed: ${landedOn.map((l) => `<a href="#lane-${slug(l.name)}">${esc(l.name)}</a>`).join(", ")}</span>`);
    const deps = c.dependsOn.length === 0 ? "" : ` · depends on ${c.dependsOn.length}`;
    return `<tr class="${(lanesOf.get(c.name) ?? []).some(live) ? "row-live" : ""}">
<td><a href="/change/${href(c.name)}">${esc(c.name)}</a><div class="sub" title="${esc(c.dependsOn.join(", ") || "no dependencies")}">${esc(c.title)}${deps}</div></td>
<td>${statusTag(c.status)}</td>
<td>${progress(c.tasks)}${taskNumbers(c)}</td>
<td class="chips">${chips || `<span class="muted">none</span>`}</td>
<td>${c.html.map((f) => `<a href="/change/${href(c.name)}/html/${href(f)}">${esc(f)}</a>`).join("<br>") || `<span class="muted">none</span>`}</td>
</tr>`;
  };
  const shown = changes.filter((c) => c.tasks.done > 0 || (lanesOf.get(c.name) ?? []).length > 0);
  const rest = changes.filter((c) => !shown.includes(c));
  const restBoxes = rest.reduce((n, c) => n + c.tasks.total, 0);
  const restRows = rest.length === 0 ? "" : `<tr class="rest"><td colspan="5"><details id="rest-changes" data-preserve-attr="open"><summary>${rest.length} more change${rest.length === 1 ? "" : "s"} with no task done and no lane (0 of ${restBoxes} boxes)</summary>
<div class="tablewrap"><table><tbody>${rest.map(row).join("")}</tbody></table></div></details></td></tr>`;
  return `<section id="index-tables">
${tiles}
<p class="lede">${baselines.length} baseline capabilities and ${changes.length} pending changes. Task counts are checkbox counts as written in each <code>tasks.md</code>, not evidence; a lane chip is what that lane's ledger and activity log say.</p>
<h2>Pending changes</h2>
<div class="tablewrap"><table class="changes">
<thead><tr><th>Change</th><th>Status</th><th>Tasks</th><th>Worked on by</th><th>Explainers</th></tr></thead>
<tbody>${shown.map(row).join("")}${restRows}</tbody>
</table></div>
<h2>Baseline capabilities</h2>
<div class="tablewrap"><table>
<thead><tr><th>Capability</th><th>Reqs</th><th>Traceability</th></tr></thead>
<tbody>${baseRows}</tbody>
</table></div>
</section>`;
}

/**
 * Index content. With --lanes the lanes panel comes first, because the board
 * is then a coordination view; without it the panel is a one-line note last.
 */
export function index(tables: string, lanes: string, lanesFirst: boolean): string {
  return `<main id="main" class="content">
<h1>Writ OpenSpec board</h1>
${lanesFirst ? `${lanes}\n${tables}` : `${tables}\n${lanes}`}
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
  const status = `<p class="lane-status">${dot(l.status)}<span class="lane-phase">${esc(phaseText(l))}</span><span class="muted">signal ${esc(ago(l.signalAt))} ago</span>${changes}</p>`;
  const sdd = l.sdd.map((p) => {
    const rel = `.superpowers/sdd/${p.plan}`;
    const ledger = p.ledger === null
      ? `<p class="note-line">${esc(p.ledgerNote ?? "no ledger")}</p>`
      : `<div class="md ledger">${p.ledger}</div>`;
    const activity = p.activityNote !== null
      ? `<p class="note-line">${esc(p.activityNote)}</p>`
      : p.activity.length === 0
        ? `<p class="muted small">No activity.log yet; agents append one line per step.</p>`
        : `<ol class="log">${p.activity.map((a) =>
            `<li><span class="log-at">${esc(a.at.replace(/^\d{4}-\d{2}-\d{2}T/, "").replace(/Z$/, ""))}</span><span class="log-who">${esc(a.who)}</span><span class="log-text">${esc(a.text)}</span></li>`).join("")}</ol>`;
    const feed = `<div class="activity"><div class="doc-label">${esc(rel)}/activity.log, last ${p.activity.length} lines</div>${activity}</div>`;
    const reports = p.reports.length === 0
      ? `<p class="muted small">No task reports yet.</p>`
      : p.reports.map((r) => {
          const rid = `${id}-${slug(p.plan)}-${slug(r.file)}`;
          const status = r.status === null ? "" : ` <span class="report-status">${esc(r.status)}</span>`;
          const body = r.html === null ? `<p class="note-line">${esc(r.file)} could not be read</p>` : `<div class="md">${r.html}</div>`;
          return `<details id="${rid}" class="report" data-preserve-attr="open"><summary><code>${esc(r.file)}</code>${status}</summary>${body}</details>`;
        }).join("");
    return `<div class="plan">${feed}<div class="doc-label">${esc(rel)}/progress.md, last 10 lines</div>${ledger}${reports}</div>`;
  }).join("");
  const diffs = l.taskDiffs.length === 0
    ? ""
    : `<div class="drift"><div class="doc-label">Task boxes differing from the root</div><ul>${l.taskDiffs.map((d) =>
        `<li>${d.root === null ? `<code>${esc(d.name)}</code>` : `<a href="/change/${href(d.name)}">${esc(d.name)}</a>`} <span class="num">${count(d.lane)}</span> <span class="muted">here, root ${count(d.root)}</span></li>`).join("")}</ul></div>`;
  const ver = l.verification === null || l.verification.length === 0
    ? ""
    : `<div class="drift"><div class="doc-label">verification/ files new or changed relative to the root</div><ul>${l.verification.map((v) =>
        `<li><code>${esc(v.path)}</code> <span class="muted">${v.kind}</span></li>`).join("")}</ul></div>`;
  return `<article id="${id}" class="lane lane-${l.status}">
<header><h3>${esc(l.name)}</h3>${branch}</header>
${status}${commit}${notes}${sdd}${diffs}${ver}
</article>`;
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
    body = [...scan.lanes].sort((a, b) => rank[a.status] - rank[b.status]).map(laneCard).join("\n");
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
<p class="eyebrow">change · ${esc(c.name)}</p>
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
