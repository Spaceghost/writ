# Writ dev board

A small read-only web board for reading Writ's OpenSpec suite: baseline
capabilities, pending changes, their task progress, and each change's
standalone explainer pages, in one place. It is tooling under `contrib/` (see
`AGENTS.md`); it is not part of Writ and makes no claim about Writ's behavior or
verification. Task counts are checkbox counts as written in `tasks.md`.

## Run

Requires [Bun](https://bun.sh) (tested with 1.1.8).

```sh
cd contrib/board && bun install --frozen-lockfile && cd ../..
bun contrib/board/server.ts --root .
# board: listening on http://127.0.0.1:4242/
```

| Flag | Default | Meaning |
| --- | --- | --- |
| `--root <repo>` | `.` | Repository whose `openspec/` is read |
| `--lanes <dir>` | none | Directory whose subdirectories are git worktrees of the same repository; without it the lanes panel is empty |
| `--port <n>` | `4242` | Port; `0` picks a free one |
| `--host <addr>` | `127.0.0.1` | The only address the server binds to |

Smoke test (starts the server on a free port against this checkout, checks the
index, `/api/changes`, a change page, an explainer, a baseline page, and the
first SSE event; exits nonzero on failure):

```sh
bun contrib/board/smoke.ts
```

## What it reads

- `openspec/specs/*/spec.md`: baseline capabilities (first heading, count of
  `### Requirement:` headings) and `openspec/traceability/<name>.md` if present.
- `openspec/changes/*/` except `archive/`: `.openspec.yaml` (`x-status`,
  `x-depends-on` only), `proposal.md` (first heading is the title), `design.md`,
  `tasks.md` (counts `- [ ]` and `- [x]`), `specs/*/spec.md`, and `*.html`.
- With `--lanes`, the names of subdirectories that contain `.git` (Task 1 lists
  names only; Task 2 adds branch, ledger, reports, and live updates).

It never writes to the repository, never runs a mutating `git` command, and
never executes what it reads. Raw HTML inside markdown is shown escaped.
Relative links between OpenSpec documents are rewritten to board routes; other
relative links (for example to `.bend` sources) are left as written and do not
resolve on the board.

## Routes

| Route | Content |
| --- | --- |
| `/` | Index: pending changes (status, `done/total` tasks, dependency count, explainers), baselines, lanes panel |
| `/change/<name>` | `proposal.md`, `design.md`, `tasks.md`, then each `specs/*/spec.md`, in that order, plus one tab per explainer |
| `/change/<name>/html/<file>` | The change's `*.html` file, byte-for-byte, as `text/html` |
| `/spec/<name>` | A baseline spec, linking its traceability file |
| `/spec/<name>/traceability` | The baseline's traceability table |
| `/api/changes` | JSON array of scanned changes (also `/api/baselines`) |
| `/events?page=<path>` | Datastar SSE stream for that page |
| `/board.css` | Stylesheet |

Explainers are embedded in an `iframe` on the change page, one tab each, and
also linked to open standalone. The iframe keeps each explainer's own styles
and scripts intact because it is a separate document; the board does not wrap
or rewrite the file.

## Frontend pins

- Datastar **v1.0.4**, loaded from
  `https://cdn.jsdelivr.net/gh/starfederation/datastar@v1.0.4/bundles/datastar.js`.
  Determined on 2026-11-03 from the GitHub releases list,
  <https://github.com/starfederation/datastar/releases> (v1.0.4, published
  2026-09-21, marked latest and not a prerelease), and confirmed against the
  CDN URL shown on <https://data-star.dev/guide/getting_started>.
  Datastar 1.0 names the fragment-merge event `datastar-patch-elements`; the
  board sends outer morphs of the `#nav` and `#main` elements.
- `marked` **18.1.3** for markdown, pinned exactly in `package.json` with the
  committed `bun.lockb` (Bun 1.1.8 writes the binary lockfile; `bun bun.lockb`
  prints it as text).

## Live updates

Each page opens one SSE connection to `/events` (`data-init="@get(...)"`). On
connect, and so on every reconnect, the server sends a full render of the
page's `#nav` and `#main` fragments, then holds the connection with comment
keepalives. File watching and pushes on change arrive in Task 2. The browser
never polls.

## Layout

Light and dark follow `prefers-color-scheme`, with the same palette and type as
the explainer pages. Below 760px the change list moves under the content and
tables scroll inside their own box rather than the page.
