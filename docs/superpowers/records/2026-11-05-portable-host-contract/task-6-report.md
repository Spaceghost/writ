# Task 6 report: records (portable host contract)

Status: DONE_WITH_CONCERNS (concerns below; none blocks the acceptance criteria)

Environment: `export PATH="$HOME/.local/share/writ-toolchains/bend-2.0.39/bend/bin:$PATH"; export BEND_NO_TELEMETRY=1`. Bend 2.0.39, clang 23.1.1, Node v26.10.0, Linux x86_64, run from the worktree root. Build outputs are in `../writ-build/portable-host-contract/` (`t6-*`).

Plan rulings applied: the cross-lane ruling overrides the brief. No count pin was changed: `README.md`, `docs/INSTALL.md`, `utils/nix/writ.nix`, `.github/workflows/*.yml` (`WRIT_CORE_EXPECTED`), `contrib/native-hosts/genode/build-and-run.sh`, `contrib/native-hosts/genode/README.md`, and the total-row, per-file and law-count sentences in `VERIFICATION.md` are untouched. They are listed in "Pins to update at re-pin time" below. No manifest was regenerated (the controller regenerates it at merge). The change is not archived, because section 2 is open. The Genode native CI run at the new count has not been executed by this lane.

Count: **1182 = 782 plus 400 new checks** (HostWire 63, HostIdentity 92, HostPrimitives 206, HostConformance 39). That is unchanged from Task 5, because Task 6 adds no check.

## The five check results (verbatim)

1. JS: `bend Tests.bend` (embedded runtime) exit 0, then `bend Tests.bend -o ../writ-build/portable-host-contract/tests.js && node ../writ-build/portable-host-contract/tests.js > verification/tests-js.txt`: build exit 0, run exit 0. The last lines are `Property: 324 checks passed; 320 graph cases, each checked against CPU and Bend parallel producers` / `ALL LIBRARY TESTS PASSED`. `grep -cE '^PASS[: ]'` = 1182 (1129 `PASS: ` + 53 `PASS `), 0 FAIL. Summaries: `HostWire: 63 checks passed`, `HostIdentity: 92 checks passed`, `HostPrimitives: 206 checks passed`, `HostConformance: 39 checks passed, 33 vectors emitted`. The embedded-runtime run and the Node run are byte-identical.
2. Native CPU: `bend Tests.bend -o ../writ-build/portable-host-contract/tests-native` (exit 0, real 2m56.275s), then `../writ-build/portable-host-contract/tests-native +RTS --threads 4 --gpu off > verification/tests-native.txt` (exit 0, real 0m0.087s). The last lines are the same, with 1182 PASS and 0 FAIL. `cmp` with tests-js.txt finds the files byte-identical, SHA-256 `120108e0662e781284095d947d2f4ae0b4e47a32fafe72a783ab4f0514763425` for both. The `VECTOR PH-` lines are `cmp`-identical to `verification/portable-host-vectors.txt` (33 lines, SHA-256 `fb85d405c08e9ad46727ffe0d69bf9f7d5cc241281226d8c1740a4a9f094d30d`), and the `VECTOR GA-` lines are identical to `verification/host-binding-vectors.txt`. This is a CPU run with `--gpu off`, not a GPU test.
3. `bend PROOF.bend`: exit 0; `ALL PROOFS CHECK` / `Use --verdict for mathematical validity.` There are 11 laws (`grep -c '^law ' LAWS.bend` = 11: six from the base plus five from this lane). The output is identical to `verification/proofs.txt`.
4. `bend PROOF.bend --verdict`: exit 1;
   `Error: BendTT infrastructure: the kernel did not build (lean: Executable not found in $PATH: "lean"); --verdict needs Lean v4.34.0 (elan toolchain leanprover/lean4:v4.34.0), or $BENDTT set to a built kernel`
   NOT VERIFIED (`which lean elan` finds neither).
5. `~/.bun/bin/bunx @fission-ai/openspec@1.16.0 validate --all --strict --no-interactive`: exit 0; `Totals: 44 passed, 0 failed (44 items)`.

## Diff list

`git diff --name-only $(git merge-base master HEAD) -- '*.bend'` lists exactly: HostConformanceTests.bend, HostConformanceVectors.bend, HostIdentity.bend, HostIdentityTests.bend, HostPrimitives.bend, HostPrimitivesTests.bend, HostPublication.bend, HostWire.bend, HostWireTests.bend, LAWS.bend, PROOF.bend, Tests.bend. `git diff <merge-base> -- LAWS.bend PROOF.bend` has 0 removed lines. No .bend file changed in Task 6. A two-dot `git diff master -- '*.bend'` also shows FacadeTests.bend, Issuance.bend and IssuanceTests.bend, because master gained the grant-issuance lane after this lane branched. This lane did not touch them.

Files changed in Task 6 (non-record):
- `VERIFICATION.md`: four suite rows after HostBinding (HostWire 63, HostIdentity 92, HostPrimitives 206, HostConformance 39); a new subsection "Portable host vectors" (the file, its SHA-256, the cmp commands, and the limit that no native host replays the vectors); and a paragraph after the six-item law list naming the five new laws, what they do not assert, and this tree's PROOF and `--verdict` results. The total row, the "782 per file" sentence, "six declared laws", "any of the six laws", and the Model-boundaries counts are untouched (pins table).
- `verification/tests-js.txt`, `verification/tests-native.txt`: fresh captures (above).
- `verification/environment.txt`: `bend_source_files` 36 -> 45, `bend_source_lines` 8160 -> 17197, `javascript_checks` and `native_checks` 782 -> 1182. These are counted as in the historical record, from the root and `examples/` `.bend` files: at a4cbe1d that definition gives exactly 36 files and 8160 lines.
- `openspec/traceability/portable-host-contract.md`: the carried notes, plus a new section "Requirement summary (task 6)" (below).
- `openspec/changes/add-portable-host-contract/tasks.md`: the preface now says section 1 (1.1 to 1.4) landed as a library model and section 2 is open, with the change unarchived. Boxes 1.1 to 1.4 were already checked with file citations by Tasks 1 to 5, and I verified each citation names existing files. Section 2 boxes stay unchecked.
- `openspec/changes/add-portable-host-contract/design.md`: "All implementation tasks remain pending." is replaced by the section 1 implemented / section 2 pending split.
- `docs/PLATFORMS.md`: one sentence at the end of "The shared host contract" names the four modules (HostWire, HostIdentity, HostPrimitives with HostPublication, HostConformanceVectors) as the library model, tested on two synthetic adapters, with native qualification pending in section 2.

## Traceability summary

Carried notes applied:
- Line 74 (the HostIdentity PH-005 delegation row, which the Task 4 review called line 73) cites `PH-005 delegate at a stale revision denied StaleRevision` (HostIdentityTests) again. `PH-005 the primitive delegate at a stale revision denied StaleRevision` now appears only in the family 1 wrapper row.
- PH-010 "A device completes after teardown" row: a reviewed-only note says that `complete` ignores the wire `sequence` and `status` and records no outstanding operation, so replayed or re-sequenced completions are accepted alike while the worker is Running. It also says that an accepted completion grants nothing (the binding must not deliver data on the strength of `Admitted`), and that per-sequence matching is a host obligation (2.3) or later work.
- PH-009 "Crash recovery" row: a reviewed-only note says that the recovery record and `Reconcile` hold only the invocation and digest, with no destination, policy, label or backend. A reconciled publication's destination therefore comes from the binding's durable log, a host obligation.
- The four laws became 11 in total with Task 4's two companions. VERIFICATION.md names all five lane laws.

New section "Requirement summary (task 6)": one row per PH-001 to PH-014. Each row gives the model status, the section rows it rests on with representative exact check names and vector ids, and the gap in the requirement's or section 2 task's own words. All 42 check names cited in the section were verified to exist verbatim in `*Tests.bend`.
- Model-tested: PH-002, PH-003, PH-005, PH-011. PH-004 is model-tested, but its `Ambiguous` branches are source-reviewed.
- Model-tested decision part with the native part a gap: PH-001 (native fast path, 2.2), PH-006 (2.1 "required feature/profile negotiation ... when any required native control is absent"), PH-007 (native limits and channels, 2.2), PH-008 (2.3 "mutable-alias elimination"), PH-009 (2.3 "durable publication under revocation, crash"), PH-010 (2.3 "stale asynchronous completion races", DMA/IO quiescence).
- Not marked done: PH-012 (decision half only, vector PH-012-1; "native adversarial probes", 2.2), PH-013 (no model check; 2.4 "exact runtime/kernel/driver/configuration evidence per target"), and PH-014 (model part tested; real device isolation and GPU evidence, 2.1 and 2.4; no GPU used).
- A closing paragraph quotes the five section 2 items as the remaining gaps.

## Pins to update at re-pin time

Lane-alone count: **1182** (782 + 400). Expected merged count on master: **1014 + 400 = 1414**. Laws: 11 on this lane alone, and 12 on master + 5 = **17** merged. Bend source files (root + examples): 45 on this lane alone, and 38 on master + 9 = **47** merged. Lines: master 11918 + 9037 added by this lane = about **20955** merged (recount after the LAWS/PROOF conflict is resolved). Line numbers are master's (b5052bb).

| File | Line (master) | Old value on master | New value (merged) |
| --- | --- | --- | --- |
| README.md | 114 | `The recorded suite passes **1014 checks on each of the JavaScript and native CPU` | `**1414 checks ...` (lane alone: 1182) |
| docs/INSTALL.md | 76 | `requiring 1014 lines` | `requiring 1414 lines` |
| docs/INSTALL.md | 161 | `Each complete test run should report **1014 passing checks** and` | `**1414 passing checks**` |
| docs/INSTALL.md | 162-163 | `` `PROOF.bend` checks twelve declared laws about guards, `` / `preservation of denied state, and grant issuance;` | `seventeen declared laws`; consider adding "and host-contract denials" |
| utils/nix/writ.nix | 10 | `# 1014, and the final line is "ALL LIBRARY TESTS PASSED".` | `# 1414, ...` |
| utils/nix/writ.nix | 55 | `# exactly 1014 lines beginning with PASS ...` | `exactly 1414 lines` |
| utils/nix/writ.nix | 64-65 | `if [ "$passes" != 1014 ]` / `expected 1014 PASS lines` | `1414` / `expected 1414 PASS lines` |
| .github/workflows/writfs-genode-native.yml | 25 | `WRIT_CORE_EXPECTED: '1014'` | `WRIT_CORE_EXPECTED: '1414'` (Genode CI at 1414 not run by this lane) |
| contrib/native-hosts/genode/build-and-run.sh | 18 | `(currently 1014)` | `(currently 1414)` |
| contrib/native-hosts/genode/README.md | 135 | `WRIT_CORE_EXPECTED=1014 bash ...` | `WRIT_CORE_EXPECTED=1414` |
| contrib/native-hosts/genode/README.md | 149 | `workflow pins it to 1014 for the integrated source.` | `1414` |
| contrib/native-hosts/genode/README.md | 162 | `(1014 in the current workflow)` | `(1414 ...)` |
| VERIFICATION.md | 7-8 | `The core and examples contain 36 authored .bend files (34 originally verified, plus HostBinding.bend and HostBindingTests.bend)` (already stale on master: 38) | `47 ...`, naming Issuance and the nine host-contract files (optional; it is a file count, not a check count) |
| VERIFICATION.md | 38 | `\| **Total per backend** \| **1014** \| ...` | `**1414**` (this lane's four rows sum to 400) |
| VERIFICATION.md | 50 | `counting both forms yields 1014 per file.` | `yields 1414 per file.` |
| VERIFICATION.md | 155 | `` `bend PROOF.bend` prints `ALL PROOFS CHECK` for twelve declared laws: `` | `seventeen declared laws` (the five host-contract laws are in this lane's paragraph after the list) |
| VERIFICATION.md | 214 | `No Lean-kernel verdict exists for any of the twelve laws.` | `... any of the seventeen laws.` |
| VERIFICATION.md | 386-387 | `The integrated core passes 1014 checks and 41 vectors on both CPU backends;` / `all twelve ordinary laws pass.` | `1414 checks, 41 HostBinding vectors and 33 portable-host vector lines` / `all seventeen ordinary laws pass.` |
| verification/environment.txt | 12-16 | `bend_source_files` 36, `bend_source_lines` 8160, `javascript_checks` 782, `native_checks` 782 (master never updated them; this lane sets 45 / 17197 / 1182 / 1182) | 47 / recount (about 20955) / 1414 / 1414 |
| verification/tests-js.txt, tests-native.txt | whole file | master's 1014 captures (SHA `e07942b3...`); this lane's 1182 captures (SHA `120108e0...`) | recapture on the merged tree (1414) |

Leave historical sentences unchanged (VERIFICATION.md lines 20, 22, 84, 295, 303, 309, 389; the Genode, Unikraft and native-host runs at 782). `hosts/unikraft/scripts/check-corpus.sh` (`WRIT_CORPUS_PASS` default) and `scripts/genode/writ_bend_tests/writ_bend_tests.run` (`expected_pass`) still expect 782 and belong to a later host-corpus lane.

Merge note: `git merge-tree --write-tree master HEAD` reports content conflicts in LAWS.bend and PROOF.bend, because both lanes append imports and laws at the end. Tests.bend auto-merges. Resolve by keeping both sides (no law is shared). The VERIFICATION.md suite table will likely also conflict around the HostBinding/Issuance rows.

## Concerns

1. Until the re-pin, VERIFICATION.md is internally inconsistent: the four new rows plus the old rows sum to 1182, while the total row still says 782 (the ruling forbids changing it in this lane), and the captures hold 1182.
2. `verification/openspec-validation.txt` on this lane's base is stale (37 items), while the live run gives 44. It is not in this lane's path list, so I left it. Master already records 44, so the merge should take master's file.
3. `verification/kernel-verdict.txt` was not appended. It is not in the plan's Task 6 path list. The exact `--verdict` refusal is recorded in this report and in the VERIFICATION.md lane-laws paragraph.
4. The `complete` sequence/status gap and the recovery record's missing destination are documented in traceability (and here), not in the `HostPublication.bend` header. Task 6 may not touch .bend files. If the controller wants the header to say it too, that is a comment-only follow-up.
5. The brief's "three new laws" is outdated: the lane has five, for 11 laws in all. The brief's "four suite rows" was followed; the HostPrimitives row covers both HostPrimitives.bend and HostPublication.bend, because one test module (HostPrimitivesTests) covers both.
6. No Lean kernel verdict and no GPU run. The native run is CPU only. The Genode native CI at the new count has not been executed by this lane.
