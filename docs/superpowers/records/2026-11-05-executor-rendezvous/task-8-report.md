# Task 8 report: full verification and host preconditions (task 2.2)

Status: DONE_WITH_CONCERNS (concerns at the end; none blocks the acceptance criteria).

Branch `lane/executor-rendezvous`, on 70861cb (task 7 records); lane base master 78449c9 (master is now f970496, whose later commits add only a plan and question records). Environment: `export PATH="$HOME/.local/share/writ-toolchains/bend-2.0.39/bend/bin:$PATH"; export BEND_NO_TELEMETRY=1`; Bend 2.0.39, Node v26.10.0, clang 23.1.1, Linux 7.2.9-1-MANJARO x86_64, run from the worktree root. Build outputs are in `../writ-build/executor-rendezvous/` and scratch in the session scratchpad's `executor-rendezvous-t8/`.

Plan rulings applied: the cross-lane ruling overrides the brief. No count pin and no shared capture changed (`README.md`, `docs/INSTALL.md`, `VERIFICATION.md`, `utils/nix/writ.nix`, `.github/workflows/*.yml`, `contrib/native-hosts/genode/build-and-run.sh` and `README.md`, `verification/tests-*.txt`, `proofs.txt`, `kernel-verdict.txt`, `environment.txt`, `openspec-validation.txt`, `gpu-*`). They are listed under "Pins to update at re-pin time". No manifest was regenerated. The change is not archived.

Count: **1651 = 1428 at master 78449c9 plus 223 Rendezvous checks**, unchanged from task 7 (this task adds no check). Laws: **24 = 17 plus 7**.

## What changed

- `Rendezvous.bend`: comments only (R1, below). With comment lines stripped, the file is identical to 56f091b.
- `RendezvousTests.bend`: the native-arity split (below). No check was added, removed or renamed.
- `docs/EXECUTOR-RENDEZVOUS.md`: the R1 sentence in "The final commit still decides"; the "Remaining host preconditions" section rewritten (13 numbered items plus the re-pin note).
- `openspec/traceability/executor-rendezvous.md`: the R1 sentence in the ER-001 boundary and in the cross-cutting item on the committed output's worker; `commit_context` named in the ER-006 boundary and in the per-use rebuilding item (the re-review's minor note).
- `openspec/changes/add-executor-rendezvous/tasks.md`: the preface (landed, held from archive, with the gaps); box 2.1's reviewed-only list gains R1; box 2.2 checked, citing its files.
- `verification/executor-rendezvous.txt`: the header, the R1 item in "Not exercised", `commit_context` in the per-use rebuilding item, and a new section "Task 2.2: full verification".
- Records: this report, `task-8-mutants.md`, `activity.log`.

### Native arity split (finding)

The first native build failed: `bend Tests.bend -o ../writ-build/executor-rendezvous/tests-native` gave `Error: an arity over 247` (exit 1, after 56 s). This lane had not built natively before task 8.
- Bisecting: `Rendezvous.bend` alone builds; 21 of the 35 `RendezvousTests` check groups fail. Emitting C (`-o drv.c`, about 2 s each, which raises the same error before clang runs) for one driver per check located 33 of the 223 checks.
- Cause, as far as measured: one def that holds several references to transition fixtures (for example `a_change()` twice and `with_a()` twice) exceeds the limit. The same condition passes once it is split across defs, or bound once and passed as a parameter. This is the limit the note above `HostBindingTests.main` and `BackplaneTests.bend:148` describe.
- Fix: each of the 33 checks is now a conjunction of named Bool defs, one per original conjunct, unchanged and in order (180 defs `<group>_<K>_<J>`, each block under a comment citing the limit). It was applied by script (`split.py`) and verified by `verify_split.py`: inlining the defs back gives exactly the earlier tokens with comments stripped. The Node output after the split is byte-identical to the run before it.

## The five check results (verbatim)

1. JS: `bend Tests.bend -o ../writ-build/executor-rendezvous/tests.js && node ../writ-build/executor-rendezvous/tests.js`: build exit 0, run exit 0, 0 FAIL lines. Last lines: `Property: 324 checks passed; 320 graph cases, each checked against CPU and Bend parallel producers` / `ALL LIBRARY TESTS PASSED`. `grep -cE '^PASS[: ]'` = 1651 (1598 `PASS: ` + 53 `PASS `), no duplicate label, `Rendezvous: 223 checks passed`. The embedded-runtime `bend Tests.bend` output is byte-identical.
2. Native CPU: `bend Tests.bend -o ../writ-build/executor-rendezvous/tests-native` exit 0 (real 12m11.716s, sharing the machine with the mutation sweep), then `../writ-build/executor-rendezvous/tests-native +RTS --threads 4 --gpu off` exit 0 (real 0m9.157s), 1651 PASS, 0 FAIL, the same last lines. `cmp` with the Node output: byte-identical. SHA-256 of both: `df544bc6b11ceab2343425e6e894e6418f4febb1e7ef549977c02d80a491131f`. This is a CPU run with `--gpu off`, not a GPU test.
3. `bend PROOF.bend`: exit 0; `ALL PROOFS CHECK` / `Use --verdict for mathematical validity.` `grep -c '^law ' LAWS.bend` = 24. `bend Rendezvous.bend --check-only`: `ALL PROOFS CHECK`.
4. `bend PROOF.bend --verdict`: exit 1;
   `Error: BendTT infrastructure: the kernel did not build (lean: Executable not found in $PATH: "lean"); --verdict needs Lean v4.34.0 (elan toolchain leanprover/lean4:v4.34.0), or $BENDTT set to a built kernel`
   NOT VERIFIED (`which lean elan` finds neither).
5. `~/.bun/bin/bunx @fission-ai/openspec@1.16.0 validate --all --strict --no-interactive`: exit 0; `Totals: 44 passed, 0 failed (44 items)`. Rerun after the last document edit, with the same result.

## Diff list

`git diff --name-only master -- '*.bend'` lists exactly `LAWS.bend`, `PROOF.bend`, `Rendezvous.bend`, `RendezvousTests.bend`, `Tests.bend`. Nothing else differs among `.bend` files.
- `git diff 78449c9 -- LAWS.bend PROOF.bend Tests.bend`: no removed line. `Tests.bend` carries task 1's two lines only.
- `git diff --stat 78449c9` (the lane's own change): the five `.bend` files, `docs/EXECUTOR-RENDEZVOUS.md`, `openspec/changes/add-executor-rendezvous/tasks.md`, `openspec/traceability/executor-rendezvous.md`, `verification/executor-rendezvous.txt` and this records directory. That is the plan's touch list.
- A two-dot `git diff --stat master` also shows `docs/superpowers/plans/2026-11-05-linux-host.md` and `docs/superpowers/records/questions/q18.*`. They were added on master after the lane branched; this lane did not touch them.

## Final mutation map

Full table: `task-8-mutants.md`. It was run on the final tree, in scratch copies only, with the full `RendezvousTests` driver; every survivor was also run through `bend PROOF.bend`.

| Part | Mutants | Killed | Equivalent |
|---|---|---|---|
| A: every `Gate{cond, ...}` constructed in `Rendezvous.bend`, cond -> `True{}` | 83 | 81 | 2 (A57 = T10, A75 = G5) |
| B: every task 1 to 7 mutant, re-applied | 365 | 350 | 15 (the accepted A6, A6b, W19, W19b, S8, F2, R2, P14, P18, T10, G5, P5, K3, K4, B4; A6 and W19 do not build) |
| Total | 448 | 431 | 17 |

Part A by def:
- `offer_gates_found` 14, `eligibility_gates_found` 12, `approval_gates` 10, `trial_gates` 10;
- `withdraw_gates`, `select_gates`, `current_gates`, `target_gates` and `run_gates` 5 each;
- `dispatch_gates` 4, `withdraw_offer_gates` 3, `evidence_gates` 3, `abandon_gates` 2.

Part B covers the comparator clauses, projection filters, outer matches, commit fields and `commit_context` conjuncts.

Notes:
- Nine task 1 and task 3 patterns are no longer unique on the final tree. They were re-anchored to the def they were written for (listed in the table's preface).
- Task 2's C5, R1 and R2 use a placeholder that its own runner expands into an `approval_profile_of` helper. The first pass did not build them. They were rerun with the helper and all three are killed by the checks task 2 recorded.
- No mutant is killed by PROOF.bend alone, and there is no new survivor.
- The records' earlier total, 366, counts task 5 as 53. Its harness holds 52 distinct ids (T2 and T7 are rerun rows), so Part B is 365.

## Remaining host preconditions (summary of the document section)

The path stays disabled until each precondition holds on a host and that host's native acceptance tests show it. The section quotes the requirement or the design where one names the obligation:
1. transport identity for providers and approvers ("an authenticated provider", ER-001; "current approval from every contributing origin", ER-006);
2. signature verification for off-host offers and approvals;
3. grants installed by the monitor, with the issuance directory and placements (GRANT-ISSUANCE.md preconditions);
4. the trusted, non-decreasing clock, current transfer contexts and unreused challenge ids ("generated after the candidate and provider scope are fixed", ER-004);
5. the genuine request and profile constraint at `open`, and genuine sessions and receipts;
6. the host state current at dispatch (`HP.valid` at `expected_host_revision`, caller bound only from authenticated evidence, HostIdentity's restart obligation);
7. durable, serialized rendezvous state (the design's rule that rollback "never restores old authority epochs or forgets consumed receipts");
8. per-use rebuilding of all three projections;
9. the same session at the commit (R1);
10. an adapter that admits workers only from `provider_registry` after a recorded dispatch and runs the worker it admitted;
11. enablement and capability negotiation (quoting the design);
12. trial metering (`add-metered-sample-execution`);
13. quote settlement (q18).

A closing note lists the controller's count re-pin, as an open item that is not a host precondition.

## R1 closure

R1 is the task 7 re-review item: the host must pass the same Negotiation session to `commit_context` and to `Backplane.commit` or `DataOS.commit_from_capability`. Bend cannot tie the two, because the commit takes its session separately. The sentence is now in each place the re-review named:
- the `Rendezvous.bend` header's commit projection paragraph and the `commit_context` comment (comments only);
- `docs/EXECUTOR-RENDEZVOUS.md`, "The final commit still decides", and precondition 9;
- the ER-001 row's boundary cell and the cross-cutting item in `openspec/traceability/executor-rendezvous.md`;
- box 2.1's reviewed-only list in `tasks.md`;
- a new "Not exercised" item in `verification/executor-rendezvous.txt`.

No check pins it; it stays reviewed-only. The re-review's minor note is also applied: the ER-006 boundary names `commit_context` for per-use rebuilding.

## Pins to update at re-pin time

Line numbers are master's (f970496). "New value" is for this lane alone: 1651 checks and 24 laws. The controller combines it with the policy-aware-audit lane's additions.

| File | Line (master) | Old value on master | New value (this lane alone) |
| --- | --- | --- | --- |
| README.md | 114 | `The recorded suite passes **1428 checks on each of the JavaScript and native CPU` | `**1651 checks ...` |
| docs/INSTALL.md | 76 | `requiring 1428 lines` | `requiring 1651 lines` |
| docs/INSTALL.md | 161 | `Each complete test run should report **1428 passing checks** and` | `**1651 passing checks**` |
| docs/INSTALL.md | 162 | `` `PROOF.bend` checks seventeen declared laws about guards, `` | `twenty-four declared laws`; consider naming executor rendezvous in the list that follows |
| utils/nix/writ.nix | 10 | `# 1428, and the final line is "ALL LIBRARY TESTS PASSED".` | `# 1651, ...` |
| utils/nix/writ.nix | 55 | `# exactly 1428 lines beginning with PASS ...` | `exactly 1651 lines` |
| utils/nix/writ.nix | 64-65 | `if [ "$passes" != 1428 ]` / `expected 1428 PASS lines` | `1651` / `expected 1651 PASS lines` |
| .github/workflows/writfs-genode-native.yml | 25 | `WRIT_CORE_EXPECTED: '1428'` | `'1651'` (the Genode CI at the new count is not run by this lane) |
| contrib/native-hosts/genode/build-and-run.sh | 18 | `(currently 1428)` | `(currently 1651)` |
| contrib/native-hosts/genode/README.md | 135 | `WRIT_CORE_EXPECTED=1428 bash ...` | `WRIT_CORE_EXPECTED=1651` |
| contrib/native-hosts/genode/README.md | 149 | `workflow pins it to 1428 for the integrated source.` | `1651` |
| contrib/native-hosts/genode/README.md | 162 | `(1428 in the current workflow)` | `(1651 ...)` |
| VERIFICATION.md | 26-42 (suite table) | no Rendezvous row | add `\| Rendezvous \| 223 \| ... \|` after Issuance (offers, origin approvals, eligibility and selection, trial binding, dispatch, commit projection, lifecycle scenarios; model only) |
| VERIFICATION.md | 43 | `\| **Total per backend** \| **1428** \| ...` | `**1651**` |
| VERIFICATION.md | 55 | `counting both forms yields 1428 per file.` | `yields 1651 per file.` |
| VERIFICATION.md | 246 | `` `bend PROOF.bend` prints `ALL PROOFS CHECK` for seventeen declared laws: `` | `twenty-four declared laws` (plus the seven rendezvous laws in the list) |
| VERIFICATION.md | 330 | `No Lean-kernel verdict exists for any of the seventeen laws.` | `... any of the twenty-four laws.` |
| VERIFICATION.md | 502-503 | `The integrated core passes 1428 checks, ...` / `all seventeen ordinary laws pass.` | `1651 checks` / `all twenty-four` |
| verification/environment.txt | 12-16 | `bend_source_files` 47, `bend_source_lines` 21213, `javascript_checks` 1428, `native_checks` 1428 | recount files and lines on the merged tree (this lane adds two .bend files, Rendezvous.bend and RendezvousTests.bend); checks 1651 / 1651 |
| verification/tests-js.txt, tests-native.txt, proofs.txt, kernel-verdict.txt, openspec-validation.txt | whole file | master's 1428 captures | recapture on the merged tree; this lane's outputs have SHA-256 `df544bc6...a491131f` (1651 PASS) |

Leave historical sentences unchanged: VERIFICATION.md 20-24 (782), 208, 212 and 222 (the GPU runs on the 1428 tree); `openspec/changes/validate-physical-gpu-execution/tasks.md:68`; `openspec/traceability/gpu-validation.md:56-66`; `openspec/traceability/portable-host-contract.md:244-251`; `verification/gpu-trust-profile.md:186`. Each of these describes a run on a recorded tree.

Merge note: `LAWS.bend` and `PROOF.bend` append at the end, as the policy-aware-audit lane's do. Resolve by keeping both sides. `Tests.bend` is one import and one call.

## Concerns

1. The native-arity split touches 33 checks' layout in `RendezvousTests.bend` (+180 small defs). It is token-equivalent and output-identical, but it is a test-file change in the verification task, and the reviewer should confirm it. A later lane adding checks with several transition fixtures in one condition will hit the same limit; only `-o <binary>` or `-o x.c` shows it, `bend Tests.bend` does not.
2. The native build took 12 minutes because it shared the machine with the 448-mutant sweep; the earlier lanes' 3-minute figure is not comparable.
3. No Lean verdict and no GPU run; the native run is CPU only. No host runs the rendezvous; the Genode CI at the new count was not run.
4. R1 and the reported-worker obligation stay reviewed-only; Bend cannot check them.
5. The task 5 total (53 rows, 52 distinct ids) makes the earlier 366 total one more than the mutants that exist; recorded above and in `task-8-mutants.md`.

## Final fix round

Findings from `final-review.md` and `task-8-review.md`, each with its closure.

- **F1 (blocking): one rendezvous per request.** Closed in code. `open(index, request, constraint)` returns an `Opening`; a request already in the monitor's index of opened requests is denied `AlreadyOpen` with the index unchanged, and an accepted open extends the index (`fresh` builds the state). Checks: "F1 scenario one rendezvous per request: R.open of the two-source request on the empty index is accepted ..." (the reviewer's scenario (b): the second rendezvous cannot be opened) and "F1 scenario one rendezvous per request: a request differing only in units (31) opens beside it ...". Mutants N1 to N8 and N16, all killed. Precondition 14 (the monitor keeps the index durably and passes the one it returned) and the ER-005 row state the residual trusted input: a host that opens a second state from a fixture without the index is outside the model; the reviewer's b0 to b3 still hold in that case.
- **F2 (blocking): `commit_context` host currency.** Closed in code. `commit_context` takes `expected_host_revision` and gates on `HP.current` as `dispatch` does; a StaleRevision or invalid host yields no commit context. Checks: "integration commit_context requires the current host state: ... (the final review's scenario e5) ..." and "integration commit_context requires HP.valid: ...". Mutants N9 to N12, killed. Precondition 6 now covers dispatch and the commit. The host still names its current revision (trusted input, as at dispatch).
- **F3 (optional): who invokes select and abandon.** Documented: precondition 5 and the trusted-input text name them monitor actions, never a provider's or caller's request.
- **F4 (optional): `challenge_evidenced` offer and provider.** Closed in code: it compares the evidence's offer id and provider with the selection's offer. Check "ER-005 session_follows_selection binds the evidence's selection, offer and provider: ...". Mutants N13 to N15, killed; t4-B2 re-anchored and killed.
- **F5 (observation): an inert approval counts again if authority returns.** Documented in `docs/EXECUTOR-RENDEZVOUS.md` "Origin approvals" and the `Rendezvous.bend` header.
- **Minor 1:** the 366 figure in `verification/executor-rendezvous.txt` now carries the 365-distinct correction.
- **Minor 2:** the arity lesson is in the verification record's Task 2.2 section.
- **Minor 3:** box 2.2's note quotes the `--verdict` line and gives the sweep totals (Task 8: 448, 431 killed, 17 equivalent; final round: 464, 447 killed, 17 equivalent).
- **Minor 4:** a new activity.log line corrects 433/15 to 431/17; the old line is unchanged.
- **Sweep finding in this round:** t7f-C5 (dispatch_is without the incarnation comparison) survived the first full run, because the new `HP.current` gate denies the restarted host before the incarnation compare is reached. Added "integration commit_context requires the dispatch's incarnation: a valid, current host in incarnation 58 with the same bindings ..."; it kills C5. t5-O2 no longer built (`open` returns an `Opening`); re-anchored to `fresh`, killed. Both rerun on the final tree.

Results on the final tree: `bend Tests.bend` 1657 PASS lines (229 Rendezvous), 0 FAIL, `ALL LIBRARY TESTS PASSED`; embedded, Node and native CPU (`--gpu off`, not a GPU test) byte-identical (SHA-256 29f7b272...767e7fa9; native build 8m23s, run 11.4s); C emission has no arity error; `bend PROOF.bend` ALL PROOFS CHECK, 24 laws, LAWS.bend and PROOF.bend unchanged; `--verdict` refused (no lean), NOT VERIFIED; OpenSpec strict 44 passed. No pin changed.

### Pins to update at re-pin time (final count)

Line numbers are master's (f970496). "New value" is for this lane alone: 1657 checks and 24 laws. The controller combines it with the policy-aware-audit lane's additions.

| File | Line (master) | Old value on master | New value (this lane alone) |
| --- | --- | --- | --- |
| README.md | 114 | `The recorded suite passes **1428 checks on each of the JavaScript and native CPU` | `**1657 checks ...` |
| docs/INSTALL.md | 76 | `requiring 1428 lines` | `requiring 1657 lines` |
| docs/INSTALL.md | 161 | `Each complete test run should report **1428 passing checks** and` | `**1657 passing checks**` |
| docs/INSTALL.md | 162 | `` `PROOF.bend` checks seventeen declared laws about guards, `` | `twenty-four declared laws`; consider naming executor rendezvous in the list that follows |
| utils/nix/writ.nix | 10 | `# 1428, and the final line is "ALL LIBRARY TESTS PASSED".` | `# 1657, ...` |
| utils/nix/writ.nix | 55 | `# exactly 1428 lines beginning with PASS ...` | `exactly 1657 lines` |
| utils/nix/writ.nix | 64-65 | `if [ "$passes" != 1428 ]` / `expected 1428 PASS lines` | `1657` / `expected 1657 PASS lines` |
| .github/workflows/writfs-genode-native.yml | 25 | `WRIT_CORE_EXPECTED: '1428'` | `'1657'` (the Genode CI at the new count is not run by this lane) |
| contrib/native-hosts/genode/build-and-run.sh | 18 | `(currently 1428)` | `(currently 1657)` |
| contrib/native-hosts/genode/README.md | 135 | `WRIT_CORE_EXPECTED=1428 bash ...` | `WRIT_CORE_EXPECTED=1657` |
| contrib/native-hosts/genode/README.md | 149 | `workflow pins it to 1428 for the integrated source.` | `1657` |
| contrib/native-hosts/genode/README.md | 162 | `(1428 in the current workflow)` | `(1657 ...)` |
| VERIFICATION.md | 26-42 (suite table) | no Rendezvous row | add `\| Rendezvous \| 229 \| ... \|` after Issuance (offers, origin approvals, eligibility and selection, trial binding, dispatch, commit projection, lifecycle scenarios; model only) |
| VERIFICATION.md | 43 | `\| **Total per backend** \| **1428** \| ...` | `**1657**` |
| VERIFICATION.md | 55 | `counting both forms yields 1428 per file.` | `yields 1657 per file.` |
| VERIFICATION.md | 246 | `` `bend PROOF.bend` prints `ALL PROOFS CHECK` for seventeen declared laws: `` | `twenty-four declared laws` (plus the seven rendezvous laws in the list) |
| VERIFICATION.md | 330 | `No Lean-kernel verdict exists for any of the seventeen laws.` | `... any of the twenty-four laws.` |
| VERIFICATION.md | 502-503 | `The integrated core passes 1428 checks, ...` / `all seventeen ordinary laws pass.` | `1657 checks` / `all twenty-four` |
| verification/environment.txt | 12-16 | `bend_source_files` 47, `bend_source_lines` 21213, `javascript_checks` 1428, `native_checks` 1428 | recount files and lines on the merged tree (this lane adds two .bend files, Rendezvous.bend and RendezvousTests.bend); checks 1657 / 1657 |
| verification/tests-js.txt, tests-native.txt, proofs.txt, kernel-verdict.txt, openspec-validation.txt | whole file | master's 1428 captures | recapture on the merged tree; this lane's outputs have SHA-256 `29f7b272...767e7fa9` (1657 PASS) |

Leave historical sentences unchanged: VERIFICATION.md 20-24 (782), 208, 212 and 222 (the GPU runs on the 1428 tree); `openspec/changes/validate-physical-gpu-execution/tasks.md:68`; `openspec/traceability/gpu-validation.md:56-66`; `openspec/traceability/portable-host-contract.md:244-251`; `verification/gpu-trust-profile.md:186`. Each of these describes a run on a recorded tree.

Merge note: `LAWS.bend` and `PROOF.bend` append at the end, as the policy-aware-audit lane's do. Resolve by keeping both sides. `Tests.bend` is one import and one call.
