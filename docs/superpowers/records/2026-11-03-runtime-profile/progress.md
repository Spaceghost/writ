# SDD ledger — plan: docs/superpowers/plans/2026-11-03-runtime-profile.md
Branch: lane/runtime-profile
Base: 3f6bf86
Preflight: lanes share no files; Hello.bend owned by runtime-profile (others create own fallback); profile uses scripts/ not tools/ (gitignored). Ruling: Nix and board lanes are tooling under the contrib/rclone precedent — flagged for Spaceghost; costs a revert if he objects.
Task 1: implementer DONE_WITH_CONCERNS (commit 35a9b22). Ruling: Task 2 allowlist keeps fopen/fscanf/fclose (used at startup for the cgroup CPU quota); only open and the cu*/nvrtc*/MTL* groups are GPU-only — costs nothing if wrong beyond an allowlist edit. Noted: implementer reports verification/source-sha256.txt stale before this lane; left untouched, to be checked at integration (manifest may intentionally cover only Bend/Go sources).
Task 1: complete (commits 3f6bf86..35a9b22, review clean). Minor (deferred): add _exit|raise to HOST_CALLS pattern; missing-bend PATH hint; quote $EMIT. Carried into Task 2 dispatch: pattern fix and the fopen ruling.
Task 2: implementer DONE_WITH_CONCERNS (commits a49e0ac, 68aebc5). Ruling: effect rows detected via <prefix>_run symbols because -O2 strips the _use constructors — accepted, version-dependent, must be stated in the script header. Ruling: spec RH-003 requires the check on static binaries ("linked effect table for a static one"); refusing static with exit 2 does not satisfy it — effect-row check must run on non-stripped static binaries with the symbol-allowlist half reported as not applicable. Enters fix loop if the reviewer confirms.
Task 2: review ❌ — Important: static binaries refused (spec RH-003). Fix round 1 dispatched (static effect-row check, version-dependence sentence, inline glibc tags). Minor (deferred): readelf dependency; pthread_detach admitted though unused.
Task 2: fix round 1/5 dispatched for re-review (commits 68aebc5..1afb90a).
Task 2: fix round 1/5 (3 addressed, 0 open; commits 68aebc5..1afb90a). Minor (deferred): a binary with imports but no (NEEDED) is treated as static and its imports skipped; glibc _run collision claim only partially evidenced.
Task 2: complete (commits 35a9b22..1afb90a, review clean)
Task 3: implementer DONE_WITH_CONCERNS (commits 28a10fe, 9e2e028, b307583). Noted: a 10 GiB core file was created and deleted; ulimit -c 0 for reruns. Review dispatched.
Task 3: review ❌ (Important: PASS-count command not recorded). Fix round 1 dispatched (count commands, ulimit -c 0 note, gdb quote). Minor (deferred): threshold bracketed not bisected.
Task 3: fix round 1/5 dispatched for re-review (commits b307583..0e1629e).
Task 3: fix round 1/5 (all addressed; commits b307583..0e1629e)
Task 3: complete (commits 1afb90a..0e1629e, review clean). All plan tasks complete; final whole-branch review dispatched.
Final review: ready after fixes. I1 LTO-internalized _run symbols give a false PASS and the guard checks io_runs (work queue) not io_eff_rows (effect table); I2 no static FAIL evidence; I3 Tests/PROOF runs not recorded in tree. Ruling: one fix wave: I1 via option (b) (accept [tT] _run names, deny-list known non-effect locals such as dlerror_run, guard on io_eff_rows, exit 2 when no effect row found, static LTO Widened FAIL evidence), I2, I3 as a verification note, plus minors 1,2,4,5,7,8; skip minor 3 (version pin enforcement: reviewed-only gap noted), 6 (wording only if cheap), 9, 10. Traceability table deferred to integration (task 3.1).
Final fix wave: commit ab0b381; LTO Widened now FAILs; LTO Hello refused exit 2 (effect table stripped). Scoped re-review dispatched.
Final fix wave re-review: all addressed. Finishing: merging lane/runtime-profile into unikernel-runtime-proposals.
