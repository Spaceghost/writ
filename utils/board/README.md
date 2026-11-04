# Writ dev board

A small read-only web board for reading Writ's OpenSpec suite: baseline
capabilities, pending changes, their task progress, and each change's
standalone explainer pages, in one place. Given `--lanes`, it is also the live
coordination view of the parallel work lanes: each worktree's branch, last
commit, SDD ledger, implementer reports, task drift, and new verification
files, updated in open pages as files change. It is tooling under `contrib/` (see
`AGENTS.md`); it is not part of Writ and makes no claim about Writ's behavior or
verification. Task counts are checkbox counts as written in `tasks.md`.

## Run

Requires [Bun](https://bun.sh) (tested with 1.1.8).

```sh
cd utils/board && bun install --frozen-lockfile && cd ../..
bun utils/board/server.ts --root .
# board: listening on http://127.0.0.1:4242/

# with the lane worktrees (sibling directory of this checkout)
bun utils/board/server.ts --root . --lanes ../writ-lanes
```

| Flag | Default | Meaning |
| --- | --- | --- |
| `--root <repo>` | `.` | Repository whose `openspec/` is read |
| `--lanes <dir>` | none | Directory whose subdirectories are git worktrees of the same repository; without it the lanes panel says so and nothing under it is watched |
| `--port <n>` | `4242` | Port; `0` picks a free one |
| `--host <addr>` | `127.0.0.1` | The only address the server binds to |

Set `BOARD_VERBOSE=1` to log how many fragments each update pushed.

Smoke test (starts the server on a free port against this checkout with a
synthetic `--lanes` directory in a fresh temporary directory; checks the index,
`/api/changes`, `/api/baselines`, a change page and its sandboxed explainer, a
baseline page, the lanes panel including escaping and link filtering, that a
forged Host header gets 403 and the loopback one 200, that a carriage return
in a lane file name never reaches the SSE stream raw, and that
touching a lane's `verification/` file, editing a report, and adding a report
each arrive as an SSE push within two seconds; removes the temporary directory;
exits nonzero on failure):

```sh
bun utils/board/smoke.ts
```

## What it reads

- `openspec/specs/*/spec.md`: baseline capabilities (first heading, count of
  `### Requirement:` headings) and `openspec/traceability/<name>.md` if present.
- `openspec/changes/*/` except `archive/`: `.openspec.yaml` (`x-status`,
  `x-depends-on` only), `proposal.md` (first heading is the title), `design.md`,
  `tasks.md` (counts `- [ ]` and `- [x]`), `specs/*/spec.md`, and `*.html`.
- With `--lanes`, each subdirectory that contains a `.git` file or directory
  (others are listed as skipped):
  - branch and last commit, from the only two git commands the board runs,
    both read-only: `git -C <dir> rev-parse --abbrev-ref HEAD` and
    `git -C <dir> log -1 --no-show-signature --format=%h%x09%s%x09%cr%x09%ct`. They
    run with `GIT_DIR`, `GIT_WORK_TREE`, `GIT_INDEX_FILE`, and `GIT_COMMON_DIR`
    removed from the environment, `GIT_CONFIG_NOSYSTEM=1`, and no pager or
    terminal prompt. Git config in a lane cannot make these commands run a
    program through the board: signature verification (`log.showSignature`,
    `gpg.program`) is off in the argv, the pager is `cat`, and neither command
    runs hooks, diff drivers, textconv filters, or credential helpers;
  - for each `<dir>/.superpowers/sdd/<plan>/`, the last ten lines of
    `progress.md` and every `task-<n>-report.md` (in task order, each in a
    collapsible section, its `Status:` line in the summary). This workspace is
    git-ignored, so it is read from the filesystem, never from git. From the
    ledger the board also reads the plan's **phase** (the last line naming a
    task, a final review, or a merge, classified by its wording: dispatched,
    implemented, in review, fix round, complete, landed) and the plan file the
    first line names (`# SDD ledger — plan: docs/superpowers/plans/<x>.md`,
    only that directory, no traversal), whose first `openspec/changes/<name>`
    reference is the change the lane works on (task-box drift is listed
    separately and does not make a lane "on" a change);
  - the last twelve lines across `<dir>/.lane/*.log` (see below): one file
    per lane, named after it, committed with the lane;
  - every change under `<dir>/openspec/changes/` whose checkbox counts differ
    from the root's, or that the root does not have;
  - files under `<dir>/verification/` that the root lacks, or that are newer
    than the root's copy and differ in content (a fresh worktree checkout makes
    every file newer, so time alone would list them all).

  A lane that is missing, empty, or mid-write degrades to a line saying what
  could not be read (branch, commit, ledger, a report) instead of failing the
  panel. `/api/lanes` returns the same scan as JSON.

It never writes to the repository or a lane, never runs any other `git`
command, and never executes what it reads. Lane files and explainers are opened
with `O_NOFOLLOW`, so a symlink as the final path component is refused, and
must be regular files. A lane's anchor directories (`.superpowers`,
`.superpowers/sdd`, `verification`, `openspec`, `openspec/changes`) are read
and watched only if `lstat` shows a real directory, and directory listings
below them skip symlinks; other symlinked parent directories are not checked.
Text shown from lanes and documents has C0 control characters other than tab
and newline replaced by U+FFFD, and SSE data lines are split on CR, LF, and
CRLF, so a carriage return in a commit subject or file name cannot start an
SSE field of its own. Markdown (documents, ledgers, reports) goes through
one pipeline: raw HTML is shown escaped, and a link keeps its target only if it
is `http:`, `https:`, `mailto:`, a fragment, or a same-origin relative path;
any other scheme (including one hidden behind character references or control
characters) and protocol-relative `//host` links become `#`. Relative links
between OpenSpec documents are rewritten to board routes; other relative links
(for example to `.bend` sources) are left as written and do not resolve on the
board.

### Activity log

Agents working in a lane append one line per step to
`<lane>/.lane/<lane name>.log` (create `.lane/` if absent), tab-separated:

```
<UTC time, RFC 3339>	<who>	<what happened>
```

for example:

```sh
mkdir -p .lane && printf '%s\t%s\t%s\n' "$(date -u +%FT%TZ)" implementer "Task 3: liveness run passed, writing the evidence" >> .lane/genode-channel.log
```

`who` is the role (`implementer`, `reviewer`, `controller`). A line without
tabs is shown as text alone. The file is committed with the lane's work, so
after a merge the log sits on master as the record of how that lane went; a
worktree therefore holds the logs of landed lanes too, and the board merges
every `.lane/*.log` by timestamp. It is a few kilobytes per lane. The board
shows the last twelve lines per lane,
oldest first, newest emphasised, and the newest line is the tooltip on the
lane's chip in the change table. The file is the main "being worked on"
signal: a lane is **active** when its newest signal (last commit time,
`progress.md`, `activity.log`, or a report file) is under 30 minutes old,
**in review** when its ledger phase says review and that signal is under three
hours old, **landed** when every plan's phase is a merge, and **idle**
otherwise. None of this is verification: it is what the lane wrote.

The index leads with three tiles (changes being worked on, tasks done across
every `tasks.md`, lanes live and landed), then the changes table. A change with
a task done or a lane on it is listed; the rest collapse under one line. Each
listed change shows a progress bar, the task ids done and open, a collapsed
"N to do" list (the open boxes of its `tasks.md` grouped by section, the done
ones behind a nested "N done" toggle; both open states kept across pushes),
and a chip per
live or idle lane on it (dot, name, phase, age); landed lanes are a muted list.
Lane cards show the status line (dot, phase, age, changes), the activity feed,
then the ledger tail and reports; live lanes sort first.

## Requests

Every request must carry a Host header naming the board itself, or it gets
`403`. Bound to a loopback address (the default), the accepted values are
exactly `127.0.0.1:<port>`, `localhost:<port>`, and `[::1]:<port>`; with a
non-loopback `--host`, only `<host>:<port>`. This stops a DNS-rebinding page in
the reader's browser from reading the board's routes, `/api/lanes` included.
Only `GET` and `HEAD` are answered (`405` otherwise). The server runs with
Bun's `development: false` and a plain-text `500` error handler, so a failure
never serves a stack trace or source.

## Routes

| Route | Content |
| --- | --- |
| `/` | Index: pending changes (status, `done/total` tasks, dependency count, explainers), baselines, lanes panel |
| `/change/<name>` | `proposal.md`, `design.md`, `tasks.md`, then each `specs/*/spec.md`, in that order, plus one tab per explainer |
| `/change/<name>/html/<file>` | The change's `*.html` file, byte-for-byte, as `text/html`; 404 if it is not a regular file in the scan or vanished after it |
| `/spec/<name>` | A baseline spec, linking its traceability file |
| `/spec/<name>/traceability` | The baseline's traceability table |
| `/api/changes` | JSON array of scanned changes |
| `/api/baselines` | JSON array of scanned baselines |
| `/api/lanes` | JSON lanes scan (`null` without `--lanes`) |
| `/events?page=<path>` | Datastar SSE stream for that page |
| `/board.css` | Stylesheet |

Explainers are embedded in an `iframe` on the change page, one tab each, and
also linked to open standalone. The iframe keeps each explainer's own styles
and scripts intact because it is a separate document; the board does not wrap
or rewrite the file.

The iframe carries `sandbox="allow-scripts allow-popups"` and deliberately
omits `allow-same-origin`. The explainers' scripts (tabs, diagrams) still run
and their external links can open, but the frame gets an opaque origin, so an
explainer cannot read the board's DOM, cookies, or storage or script the board
page. None of the current explainers uses `localStorage`, cookies, forms, or
`window.parent`/`window.top` (checked with grep over
`openspec/changes/*/*.html`), so none needs same-origin access.

The explainer route itself also sends
`Content-Security-Policy: sandbox allow-scripts allow-popups`, so the "open
standalone" view gets the same opaque-origin isolation as the iframe. An
explainer that needed same-origin access would not get it by either route;
that would be a deliberate change to both the iframe attribute and this header.

## Frontend pins

- Datastar **v1.0.4**, loaded from
  `https://cdn.jsdelivr.net/gh/starfederation/datastar@v1.0.4/bundles/datastar.js`.
  Determined on 2026-11-03 from the GitHub releases list,
  <https://github.com/starfederation/datastar/releases> (v1.0.4, published
  2026-09-21, marked latest and not a prerelease), and confirmed against the
  CDN URL shown on <https://data-star.dev/guide/getting_started>.
  The script tag carries `integrity="sha384-twbOvafhSBQ0rJDNPzJdUw6DRvthVgAVfSIG1BQVmCiNO7Qh2zeVn7T5qstgjJ9q"`
  and `crossorigin="anonymous"` (`DATASTAR_SRI` in `template.ts`), computed on
  2026-11-03 from the pinned file (33553 bytes, first line `// Datastar v1.0.4`),
  fetched twice with the same result:
  `curl -sSfL https://cdn.jsdelivr.net/gh/starfederation/datastar@v1.0.4/bundles/datastar.js | openssl dgst -sha384 -binary | openssl base64 -A`.
  Changing the pin means recomputing it the same way.
  Datastar 1.0 names the fragment-merge event `datastar-patch-elements`; the
  board sends outer morphs of the `#nav` and `#main` elements.
- `marked` **18.1.3** for markdown, pinned exactly in `package.json` with the
  committed `bun.lockb` (Bun 1.1.8 writes the binary lockfile; `bun bun.lockb`
  prints it as text).

## Live updates

Each page opens one SSE connection to `/events` (`data-init="@get(...)"`). On
connect, and so on every reconnect, the server sends a full render of the
page's `#nav` and `#main` fragments, then holds the connection with comment
keepalives every 5 s. The browser never polls.

When a watched file changes, the server waits about 200 ms to coalesce a
burst, rescans once, re-renders each page that has an open connection, and
sends each connection only the fragments whose HTML differs from what it last
received, as Datastar `datastar-patch-elements` outer morphs by id:

| Page | Fragments |
| --- | --- |
| `/` | `#nav`, `#index-tables` (tiles, change and baseline tables), `#lanes` |
| `/change/<name>`, `/spec/<name>[/traceability]` | `#nav`, `#main` |

So a report edit in a lane pushes `#lanes` to index pages (and
`#index-tables` when a chip's phase, age, or tooltip changed), an
`activity.log` append pushes the lane's feed within the debounce window, and a
`tasks.md` edit pushes the tables, the nav, and that change's page. The morph
keeps what the reader changed in the browser: open report sections, nav
groups, the selected explainer tab, and loaded iframes (`data-preserve-attr`
and stable ids).

Browsers and `curl` receive each push at once. Bun 1.1.8's own `fetch` reader
does not: the server sends a chunk's closing CRLF only with its next write, and
that reader holds the chunk until then (up to the 5 s keepalive), so
`smoke.ts` reads the stream over a plain socket instead.

Watched, ignoring `node_modules`, `.git`, and build directories (`build`,
`dist`, `out`, `target`, `result`, `zig-out`, `.zig-cache`, `.cache`):

- `<root>/openspec`, `<root>/verification`, `<root>/docs`;
- the `--lanes` directory itself (new or removed worktrees);
- in each lane, `openspec`, `verification`, `docs`, `.superpowers/sdd`, and `.lane`;
- each lane's git metadata `logs/` directory, filtered to the `HEAD` reflog,
  so a commit refreshes the branch and last-commit line. **This is the one path
  the board watches outside `--root` and `--lanes`.** The path comes from the
  `gitdir:` line of the lane's `.git` file (or `<lane>/.git/logs` when `.git`
  is a directory). In the standard layout that is
  `<main repository>/.git/worktrees/<lane>/logs`, but the board follows
  whatever the gitdir line says. The watch is notify-only: the board never
  opens or reads anything there (the commit line comes from `git log`).

Watch strategy: one non-recursive `fs.watch` per directory, not
`fs.watch(..., { recursive: true })`. On Bun 1.1.8 under Linux the recursive
form was measured to miss modifications of existing files in subdirectories
and every change inside a directory created after the watch started, which is
exactly how reports and ledgers are written. The board therefore walks the
listed subtrees, watches each directory, and re-syncs the set after every
update (adding new directories and dropping removed ones). Anchor directories
(the root, each lane, `.superpowers`) are filtered to the entry names that lead
to a watched subtree, so unrelated edits elsewhere in a worktree do not trigger
rescans. With six lanes this is about 700 watches, well under the default
inotify limit.

Known gap: a file change between a connection's initial render and its
registration for pushes is not sent until the next change.

## Layout

Light and dark follow `prefers-color-scheme`, with the same palette and type as
the explainer pages. Below 760px the change list moves under the content and
tables scroll inside their own box rather than the page.
