# SDD ledger — plan: docs/superpowers/plans/2026-11-03-dev-board.md
Branch: lane/dev-board
Base: 3f6bf86
Preflight: lanes share no files; Hello.bend owned by runtime-profile (others create own fallback); profile uses scripts/ not tools/ (gitignored). Ruling: Nix and board lanes are tooling under the contrib/rclone precedent — flagged for Spaceghost; costs a revert if he objects.
Task 1: implementer DONE (commit d7090be). Ruling: Datastar 1.0.4 event name datastar-patch-elements accepted (plan named the pre-1.0 fragment-merge event). Ruling: binary bun.lockb accepted as the committed lockfile.
Task 1: complete (commits 3f6bf86..d7090be, review clean). Minor (deferred, carried into Task 2 as required hardening): markdown link schemes restricted to http/https/mailto; iframe sandbox; symlink and deleted-file handling on explainer route; smoke test brittleness (total==8, data-model); drop "Task 1/2" wording from README/AGENTS/code.
Task 2: implementer DONE_WITH_CONCERNS (commits 0d05df2, dc7b15a, 2edb5cb). Ruling: per-directory watches (Bun recursive watch unreliable) accepted and documented; a notify-only watch on the main repo .git/worktrees/<lane>/logs is accepted because it reads nothing — must be documented in README as the one path outside --root/--lanes. Review dispatched.
Task 2: review ❌ (Important: README wording for the git-metadata watch). Fix round 1 dispatched with cheap minors (CSP on standalone explainer, try/catch on initial render, symlink wording, blank line). Minor (deferred): read size caps; initial-window race; split server.ts; extra smoke cases.
Task 2: fix round 1/5 dispatched for re-review (commits 2edb5cb..ae79769).
Task 2: fix round 1/5 (all addressed; commits 2edb5cb..ae79769)
Task 2: complete (commits d7090be..ae79769, review clean). All plan tasks complete; final whole-branch review dispatched.
Final review: ready after fixes. Important: no Host-header allowlist (DNS rebinding reads lane data); CR in lane content breaks SSE framing. Ruling: one fix wave: both Importants plus minors 3 (AGENTS symlink wording), 4 (git --no-show-signature and scrubbed env), 5 (Evidence→Traceability), 10 (development:false + plain 500), 11 (drift links), smoke temp-dir leak, and SRI for Datastar if the hash is obtainable offline from the pinned file; skip 7 (slug collisions), 8 (backpressure), 9 (verification read cost) as deferred.
Final fix wave: commit 257175c, 34 smoke checks pass; scoped re-review dispatched.
Final fix wave re-review: all addressed. Finishing: merging lane/dev-board into unikernel-runtime-proposals.
Merged to master as ee93f1d and pushed.
