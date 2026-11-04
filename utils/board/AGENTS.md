# Working on the dev board

This directory is development tooling, not part of Writ. It follows the
`contrib/rclone/` precedent for non-Bend code that the core never depends on:
Writ's authored implementation, tests, examples, and proofs stay in Bend 2, and
nothing outside `utils/board/` may import, build, or require this board.

The board is read-only. It reads the repository given by `--root` and the
sibling git worktrees under `--lanes`. It never writes to either and never
executes a file it reads. Its only git invocations are the fixed, read-only
`git -C <lane> rev-parse --abbrev-ref HEAD` and
`git -C <lane> log -1 --no-show-signature --format=%h%x09%s%x09%cr%x09%ct`, run with
`GIT_DIR`, `GIT_WORK_TREE`, `GIT_INDEX_FILE`, and `GIT_COMMON_DIR` removed and
`GIT_CONFIG_NOSYSTEM=1`; do not add others. The SDD workspace
(`.superpowers/sdd/`) is git-ignored and is read from the filesystem. Lane
files and explainers are opened with `O_NOFOLLOW`, which refuses a symlink only
as the final path component, and must be regular files; a lane's anchor
directories (`.superpowers`, `.superpowers/sdd`, `docs/superpowers/records`, `verification`, `openspec`,
`openspec/changes`) are skipped unless `lstat` shows a real directory, and
entries below them are listed without following symlinks. Requests whose Host
header is not the board's own address get 403.
Markdown (documents, ledgers, reports) is rendered with raw HTML escaped and
link schemes other than http, https, and mailto replaced by `#`; explainer pages are served as-is
only when their name appears in a scanned change directory. Keep request paths
matched against scanned names rather than joined into filesystem paths.

The board makes no authority, behavior, or verification claim about Writ. It
shows what the documents say. A checked task box is a count of text, not
evidence, and a lane's ledger or report is what that lane wrote; do not present
a board view as a test, proof, or host qualification result. Keep its wording consistent with that.

Keep it small: `server.ts` (scanning, routes, SSE), `template.ts` (page and
fragments), `board.css`, and `smoke.ts`. Datastar is the only frontend library
and is loaded from the pinned CDN URL in `template.ts`; `marked` is the only npm
dependency and is pinned with the committed `bun.lockb`. Update README.md when
either pin, a flag, or a route changes, and run `bun utils/board/smoke.ts`.
