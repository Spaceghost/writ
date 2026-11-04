# Task 2 report: lanes panel and live updates

Status: DONE_WITH_CONCERNS

Commits on lane/dev-board (not pushed):
- 0d05df2 Add live lanes panel and file-watch updates to the dev board
- dc7b15a Keep dev board ledgers readable and make the SSE smoke check deterministic
- 2edb5cb Reorder the dev board README live-update notes

Changed: contrib/board/{server.ts,template.ts,board.css,smoke.ts,README.md,AGENTS.md}
and one "Read further" line in the repository README.md. Nothing else.

## Delivered
- Lanes panel (`#lanes`): each `--lanes` subdirectory with `.git` (others listed as
  skipped) shows name, branch, last commit (hash, subject, relative time), for each
  `.superpowers/sdd/<plan>/` the last 10 lines of progress.md and every
  task-N-report.md (numeric order, `<details>`, `Status:` line in the summary), changes
  whose task counts differ from the root (or are absent there), and verification/ files
  the root lacks or that are newer AND differ in content (mtime alone flags every file
  of a fresh worktree checkout). Ledgers and reports use the same escaped markdown
  pipeline as change pages (ledger with `breaks: true` since it is line-oriented).
  Missing/empty/mid-write/unreadable pieces degrade to a "could not be read" line.
  With `--lanes` the panel comes first on the index. `/api/lanes` returns the scan.
- Git: exactly two fixed argv vectors (`rev-parse --abbrev-ref HEAD`,
  `log -1 --format=%h%x09%s%x09%cr`) via `git -C <dir>`, async with a 3 s kill timer,
  `GIT_OPTIONAL_LOCKS=0`, no pager/prompt. SDD read from the filesystem only.
- Live updates: fragments `#nav`, `#index-tables`, `#lanes` on `/`; `#nav`, `#main`
  elsewhere. Debounced ~200 ms (one flush 200 ms after the first event of a burst);
  each flush rescans once, renders each open page once, and sends each connection only
  fragments whose HTML changed (`datastar-patch-elements`). Reconnect still gets a full
  render. Morph-safe: `data-preserve-attr="open"` on report/nav `<details>`,
  `style`/`aria-selected` on the explainer tab elements, stable ids on lanes, reports,
  explainer sections and iframes (verified via Datastar 1.0.4 bundle source).
- Watch strategy: one non-recursive fs.watch per directory, re-synced after every
  flush. Measured on Bun 1.1.8/Linux: `recursive: true` missed modifications of existing
  files in subdirectories and everything in directories created after the watch.
  Watched: root openspec/verification/docs, the lanes dir, each lane's
  openspec/verification/docs/.superpowers/sdd, anchors filtered by name, and each
  lane gitdir's `logs/` filtered to `HEAD` so commits refresh the commit line (the one
  watch inside git metadata; notifications only, never read). Ignored: node_modules,
  .git, build, dist, out, target, result, zig-out, .zig-cache, .cache. ~700-810
  watches with the six real lanes.
- Hardening: links keep only http/https/mailto, fragments, and same-origin relative
  paths; other schemes, protocol-relative `//host`, `/\host`, and schemes hidden by
  character references (`&#106;`, `&colon;`) or control chars become `#` (marked keeps
  references raw in hrefs and does not re-escape them, so they are decoded before the
  check); applied to images too. Explainer iframes:
  `sandbox="allow-scripts allow-popups"`, no allow-same-origin (grep showed no
  explainer uses storage, cookies, forms, or parent/top); README explains. Explainer
  scan uses Dirent.isFile (symlinks excluded); serve opens with O_NOFOLLOW + fstat
  isFile and returns 404 on any failure (symlink test: 404). Lane files also read with
  O_NOFOLLOW. smoke.ts uses `total > 0` and a baseline from `/api/baselines`.
  "Task 1/2" wording removed from README, AGENTS.md, and code.

## Verification
smoke.ts (passed 10/10 consecutive runs after the socket fix):
```
PASS server binds to loopback (http://127.0.0.1:55491)
PASS GET / is 200
PASS index lists the runtime-profile change
PASS index pins Datastar v1.0.4
PASS /api/changes contains add-bend-runtime-host-profile (28 changes)
PASS archive/ is skipped
PASS runtime-profile tasks counted (0/8)
PASS runtime-profile lists explainer.html
PASS change page renders proposal, design, tasks, specs in order (4662,8237,13084,15308)
PASS change page shows the proposal title
PASS change page embeds the explainer in an iframe
PASS explainer iframe is sandboxed without same-origin
PASS explainer served as-is with text/html
PASS traversal is not served
PASS POST is refused
PASS /api/baselines lists a baseline with traceability (14 baselines)
PASS baseline page links traceability (authority-boundary)
PASS lanes panel lists the synthetic lane
PASS lanes panel skips a directory without .git
PASS unreadable branch degrades to a note
PASS ledger shows only the last ten lines
PASS report rendered in a collapsible section with its status
PASS report raw HTML is escaped
PASS unsafe link schemes become #
PASS /events sends a datastar-patch-elements full render
PASS index stream starts with a full render
PASS touching a lane verification/ file pushes #lanes within 2 s (358 ms)
PASS lane push does not resend unchanged fragments
PASS editing a report pushes the new text within 2 s (332 ms)
PASS a new report file is pushed within 2 s (338 ms)
smoke: all checks passed
```
Browser (Playwright Chromium, server `--root <scratch copy of openspec+verification>
--lanes /mnt/.../writ-lanes`):
```
PASS panel lists six lanes (6)
PASS dev-board: branch, commit, ledger, report
PASS genode-binding: branch, commit, ledger, report
PASS runtime-profile: branch, commit, ledger, report
PASS report edit appears without reload (492 ms)
PASS opened report stays open after the push
PASS no horizontal scroll at 1280
PASS tasks.md edit pushes the change page
PASS explainer tab stays selected and visible after push (vis=True docsHidden=True sel=true)
PASS iframe sandbox attribute
PASS explainer frame has an opaque origin and renders (null)
PASS no horizontal scroll at 390 dark (390)
PASS no console errors
```
The report edit was an append to this report file (dev-board is itself a lane). The
tasks.md edit was made in the scratch copy, never the repository. Commit refresh:
in a scratch `git init` + `git worktree add` lanes dir, an empty commit in the worktree
arrived on an open `/events?page=/` stream within 2 s.
Link filter checked case-by-case (javascript:, mixed case, leading space, tab,
`&#106;`, `&#x6A;`, `&colon;`, data:, vbscript:, file:, `//evil`, `/\evil`, `\\evil`
all -> `#`; https, http, mailto, `#frag`, `/change/x`, relative paths kept).

## Concerns
- Bun 1.1.8 server sends a chunk's closing CRLF only with its next write; Bun's own
  fetch reader then holds the chunk until the next write (up to the 5 s keepalive).
  Browsers and curl are unaffected (pushes land in ~300-500 ms). smoke.ts therefore
  reads SSE over a raw socket with its own chunked decoder; this was the cause of the
  flaky SSE assertions seen mid-task. Documented in README and smoke.ts.
- The gitdir `logs/` watch sits outside --root/--lanes (in the main repo's
  .git/worktrees/<lane>/); it is a notification-only watch, documented in README,
  AGENTS-level contract in server.ts header. Drop it if that is unwanted; commits
  would then show on the next other change.
- Each flush runs 2 git processes per lane and re-renders all report markdown;
  ~0.5-0.8 s for six lanes. Fine at current scale.
- A first path segment containing `&` in a relative markdown link becomes `#`
  (conservative choice against hidden schemes).
- Not run: bend Tests.bend / PROOF.bend / openspec validate; no Bend, spec, or proof
  files changed.

## Review fix pass (ae79769)
- Important: README watch list and server.ts header now state that the lane git
  metadata `logs/` directory is the one path watched outside --root and --lanes,
  notify-only and never read, located from the lane `.git` file's `gitdir:` line
  (standard layout `<main repo>/.git/worktrees/<lane>/logs`; the board follows
  whatever gitdir says).
- Standalone explainer response sends `Content-Security-Policy: sandbox allow-scripts
  allow-popups`; README no longer recommends the standalone route for same-origin
  needs. Playwright: standalone page origin `null`, renders, no console errors.
  New smoke check asserts the header.
- /events start: initial render wrapped in try/catch; on failure the stream stays open
  with a comment and an empty sent-map, so the next flush sends every fragment.
- README: O_NOFOLLOW wording (final component only, parents not checked); blank line
  before "## Layout"; one-line known gap for the initial-render/registration window.
- smoke.ts: 31 checks, "smoke: all checks passed" on 4 consecutive runs.
- Deferred per coordinator: lane file size caps, closing the initial-window race,
  splitting server.ts, extra smoke cases.
