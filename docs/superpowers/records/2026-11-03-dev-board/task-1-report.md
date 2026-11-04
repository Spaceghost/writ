# Task 1 report: board server, index, change pages

Status: DONE

Commit on lane/dev-board (not pushed): d7090be Add read-only dev board for OpenSpec changes and explainers

## Delivered (contrib/board/)
- server.ts: flag parsing (--root, --lanes, --port, --host; binds only to --host), scanning of
  openspec/specs/*/spec.md and openspec/changes/* (archive/ skipped), minimal .openspec.yaml reader
  (x-status, x-depends-on: [] / inline / block list), task box counting, *.html listing; routes /,
  /change/<name>, /change/<name>/html/<file> (as-is, text/html), /spec/<name>, /spec/<name>/traceability,
  /api/changes, /api/baselines, /events (Datastar SSE), /board.css. Non-GET/HEAD returns 405.
- template.ts: page shell, nav grouped by status, index tables, change page (tabs: Documents + one
  iframe per explainer; Documents shows proposal, design, tasks, spec deltas in order), spec page.
- board.css: explainer palette/type (slate neutrals, green accent), light/dark via prefers-color-scheme,
  single column under 760px with content first.
- smoke.ts, README.md, AGENTS.md, package.json (marked 18.1.3 exact), bun.lockb committed.
- .gitignore: /contrib/board/node_modules/ (only change outside contrib/board/).

## Decisions
- Datastar v1.0.4: GitHub releases API for starfederation/datastar (latest non-prerelease, 2026-09-21),
  confirmed by the CDN URL on https://data-star.dev/guide/getting_started. Recorded in README.
- Datastar 1.0's fragment-merge event is `datastar-patch-elements` (the plan's "fragment-merge" wording
  predates the rename). /events sends outer morphs of #nav and #main on connect, then 5 s comment
  keepalives (Bun 1.1.8's default 10 s idle timeout would otherwise close a quiet stream).
- Explainers: iframe on the change page (one tab each) plus an "open standalone" link; files served
  byte-for-byte. The tab signal uses __ifmissing so the on-connect morph does not reset the chosen tab.
- Markdown raw HTML is escaped (no document can inject script). Relative links between OpenSpec docs
  are rewritten to board routes; other relative links (e.g. Core.bend from traceability) are left
  as written and do not resolve on the board.
- With --lanes the panel lists worktree names only; Task 2 fills it in.

## Verification
smoke.ts output:
```
PASS server binds to loopback (http://127.0.0.1:53071)
PASS GET / is 200
PASS index lists the runtime-profile change
PASS index pins Datastar v1.0.4
PASS /api/changes contains add-bend-runtime-host-profile (28 changes)
PASS archive/ is skipped
PASS runtime-profile tasks counted (0/8)
PASS runtime-profile lists explainer.html
PASS change page renders proposal, design, tasks, specs in order (4539,8114,12961,15185)
PASS change page shows the proposal title
PASS change page embeds the explainer in an iframe
PASS explainer served as-is with text/html
PASS traversal is not served
PASS POST is refused
PASS baseline page links traceability
PASS /events sends a datastar-patch-elements full render
smoke: all checks passed
```
Browser check (Playwright Chromium, headless): index and change pages at 1280px light and 390px dark;
documentElement.scrollWidth equals viewport width on /, a change page, /spec/data-model and its
traceability page (no horizontal page scroll); explainer tab click hides documents and shows the
iframe; aria-selected toggles true/false; no console errors; page still on the explainer after 7 s
(SSE held open). Index shows 28 changes and 14 baselines, matching the directories.

## Concerns
- bun.lockb is binary (Bun 1.1.8 has no text lockfile); reviewable via `bun bun.lockb`.
- Fonts load from Google Fonts like the explainers; offline, system fallbacks apply.
- template.ts is a separate "page template" file per the plan's file budget; no client script needed.
- Not run: bend Tests.bend / PROOF.bend / openspec validate. No Bend, spec, or proof files changed.
