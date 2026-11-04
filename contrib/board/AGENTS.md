# Working on the dev board

This directory is development tooling, not part of Writ. It follows the
`contrib/rclone/` precedent for non-Bend code that the core never depends on:
Writ's authored implementation, tests, examples, and proofs stay in Bend 2, and
nothing outside `contrib/board/` may import, build, or require this board.

The board is read-only. It reads the repository given by `--root` and, from
Task 2, the sibling git worktrees under `--lanes`. It never writes to either,
never runs a mutating `git` command, and never executes a file it reads.
Markdown is rendered with raw HTML escaped; explainer pages are served as-is
only when their name appears in a scanned change directory. Keep request paths
matched against scanned names rather than joined into filesystem paths.

The board makes no authority, behavior, or verification claim about Writ. It
shows what the documents say. A checked task box is a count of text, not
evidence; do not present a board view as a test, proof, or host qualification
result. Keep its wording consistent with that.

Keep it small: `server.ts` (scanning, routes, SSE), `template.ts` (page and
fragments), `board.css`, and `smoke.ts`. Datastar is the only frontend library
and is loaded from the pinned CDN URL in `template.ts`; `marked` is the only npm
dependency and is pinned with the committed `bun.lockb`. Update README.md when
either pin, a flag, or a route changes, and run `bun contrib/board/smoke.ts`.
