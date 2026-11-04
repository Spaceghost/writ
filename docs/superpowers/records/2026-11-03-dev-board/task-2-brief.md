### Task 2: Lanes panel and live updates

Add the lanes panel. For each subdirectory of `--lanes` that contains a `.git` file or directory, show: directory name, current branch (read `.git` worktree metadata or run read-only `git -C <dir> rev-parse --abbrev-ref HEAD` and `git -C <dir> log -1 --format='%h %s %cr'`), the SDD ledger if present at `<dir>/.superpowers/sdd/*/progress.md` (render its last ten lines), each `<dir>/.superpowers/sdd/*/task-*-report.md` as a collapsible section rendered from markdown, the task checkbox counts for every change directory in that worktree that differs from the root's counts, and the list of files under `<dir>/verification/` newer than the root's copies.

Wire live updates: watch `<root>/openspec`, `<root>/verification`, `<root>/docs`, and every lane directory's `openspec`, `verification`, `docs`, and `.superpowers/sdd` subtrees. On change, re-render the affected fragment (index tables, a change page, or the lanes panel) and push it as a Datastar fragment-merge on every open `/events` connection whose page includes that fragment. Debounce about 200 ms. Ignore `node_modules`, `.git`, and build directories.

Extend `smoke.ts`: after the first fetch, touch a temporary file under a temporary `--lanes` directory's `verification/` and assert that an SSE event arrives within two seconds. Clean up the temporary directory.

Add one line to the repository `README.md` under "Read further" linking `contrib/board/README.md`.

Acceptance: with `--lanes ../writ-lanes` the panel lists each worktree with branch, last commit, ledger tail, and reports; editing a report file updates the open page without reload; `smoke.ts` passes including the SSE assertion.
