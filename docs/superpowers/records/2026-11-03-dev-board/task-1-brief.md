### Task 1: Server, index, and change pages

Create `contrib/board/server.ts` (Bun) that:

1. Scans `<root>/openspec/specs/*/spec.md` (baseline capabilities) and `<root>/openspec/changes/*/` (pending changes; skip `archive/`). For each change read `.openspec.yaml` for `x-status` and `x-depends-on`, `proposal.md`'s first heading as the title, `tasks.md` to count `- [ ]` and `- [x]` boxes, and list any `*.html` files in the change directory.
2. Serves `/` as an index: two tables (baselines; changes with status, task progress as `done/total`, dependency count, and links), plus a lanes panel (Task 2) that renders empty when `--lanes` is absent.
3. Serves `/change/<name>` rendering `proposal.md`, `design.md`, `tasks.md`, and each `specs/*/spec.md` as HTML sections in that order, with a tab or link per `*.html` explainer that serves the file at `/change/<name>/html/<file>` as-is (the explainer pages are standalone HTML; serve them with `text/html`, no wrapping, in an `iframe` on the change page or as a direct link; choose the one that keeps the explainer's own styles intact and say which in the README).
4. Serves `/spec/<name>` rendering a baseline spec and linking its `openspec/traceability/<name>.md` if present.
5. Serves `/api/changes` as JSON for the smoke test.
6. Serves `/events` as a Datastar SSE stream (Task 2 wires the watching; in this task it may send one full-render fragment on connect and keep the connection open).

Page shell: a small CSS file with light and dark via `prefers-color-scheme`, a left list of changes grouped by status, the content on the right, readable at a phone width. Use the same muted palette as the explainer pages (slate neutrals, a green accent) so the board and the pages feel like one tool.

Write `contrib/board/README.md` (run command, flags, what it reads) and `contrib/board/AGENTS.md`. Write `smoke.ts` and run it.

Acceptance: `bun contrib/board/server.ts --root .` serves the index with every change listed and the runtime-profile change page shows its proposal and its `explainer.html`; `smoke.ts` passes; lockfile committed.

