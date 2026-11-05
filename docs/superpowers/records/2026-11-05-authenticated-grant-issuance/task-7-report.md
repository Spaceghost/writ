# Task 7 report: full verification, records and host preconditions (box 2.2)

Status: DONE_WITH_CONCERNS (concerns below; none blocks the acceptance criteria)

Environment: `export PATH="$HOME/.local/share/writ-toolchains/bend-2.0.39/bend/bin:$PATH"; export BEND_NO_TELEMETRY=1`, Bend 2.0.39, run from the worktree root. Build outputs go to `../writ-build/authenticated-grant-issuance/` (a lane subdirectory, so the parallel lanes' `../writ-build` files are not overwritten).

## Carried notes from Task 6

- M-1: dropped "Task 6 of this change creates it." from `docs/GRANT-ISSUANCE.md`.
- M-2: added two GI-003 checks to `IssuanceTests.bend` section `registration` (two fixtures `plan_source_version`, `plan_output_type`, four lines of checks; count string 224 -> 226):
  - "GI-003 approvals differing only in the source object's version denied ScopeMismatch"
  - "GI-003 approvals differing only in output type denied ScopeMismatch"
  The GI-003 traceability row now names them, and its gap sentence is gone.
  Mutation exercise (scratch copies under the session scratchpad; `Transfer.bend` was mutated there only and is unchanged in the tree): (a) `T.Plan.equal` comparing manifest object ids but not versions: KILLED, first FAIL is the new source-version check (521 PASS before it); (b) `T.Plan.equal` with `U32.is_eq(at, bt)` dropped: KILLED, first FAIL is the new output-type check. The baseline copy passed 1010.

As a result the lane total is **1010 = 782 plus 228 new checks (226 Issuance + 2 Facade)**, not the 1008 in the dispatch. The two extra checks are the ones the dispatch allowed.

## The five check results (verbatim)

1. JS: `bend Tests.bend -o ../writ-build/authenticated-grant-issuance/tests.js && node ../writ-build/authenticated-grant-issuance/tests.js > verification/tests-js.txt`: build exit 0, run exit 0; last lines
   `Property: 324 checks passed; 320 graph cases, each checked against CPU and Bend parallel producers` / `ALL LIBRARY TESTS PASSED`; `grep -cE '^PASS[: ]'` = 1010 (957 `PASS: ` + 53 `PASS `), 0 FAIL; `Issuance: 226 checks passed`, `Facade: 12 checks passed`.
2. Native CPU: `bend Tests.bend -o ../writ-build/authenticated-grant-issuance/tests-native` (exit 0, real 2m54.596s) then `../writ-build/authenticated-grant-issuance/tests-native +RTS --threads 4 --gpu off > verification/tests-native.txt` (exit 0, real 0m0.099s); same last lines, 1010 PASS, 0 FAIL. `cmp` with tests-js.txt: byte-identical, SHA-256 `61743d04903fd4536c345b5b4b20878f940ff759e03a1e752f951e56ab86295a` for both. The 41 VECTOR lines equal master's. This is a CPU run with `--gpu off`, not a GPU test.
3. `bend PROOF.bend > verification/proofs.txt`: exit 0; `ALL PROOFS CHECK` / `Use --verdict for mathematical validity.` (12 laws; file unchanged from master).
4. `bend PROOF.bend --verdict`: exit 1;
   `Error: BendTT infrastructure: the kernel did not build (lean: Executable not found in $PATH: "lean"); --verdict needs Lean v4.34.0 (elan toolchain leanprover/lean4:v4.34.0), or $BENDTT set to a built kernel`
   NOT VERIFIED; appended verbatim to `verification/kernel-verdict.txt` (`which lean elan` finds neither).
5. `~/.bun/bin/bunx @fission-ai/openspec@1.16.0 validate --all --strict --no-interactive > verification/openspec-validation.txt`: exit 0; `Totals: 44 passed, 0 failed (44 items)`. Re-run after the last document edits: identical output.

## Diff list

`git diff --stat master...HEAD -- '*.bend'` (and the same plus the working tree) lists exactly FacadeTests.bend, Issuance.bend, IssuanceTests.bend, LAWS.bend, PROOF.bend, Tests.bend. No use-time module (`Transfer`, `Frontend`, `DataOS`, `Backplane`, `Negotiation`, `Ledger`, `Guard`, `HostBinding`) and no `writfs/`, `contrib/rclone/` or `hosts/` source changed. `git diff master...HEAD -- LAWS.bend PROOF.bend` has 0 removed lines. Note: a plain `git diff master` (two-dot) also shows `docs/superpowers/records/questions/q18.*`, because master moved on after the lane branched; the lane did not touch them.

Non-record files the lane changes against the merge base: the six .bend files, `VERIFICATION.md` (proof-scope addition only, 26 lines added), `docs/GRANT-ISSUANCE.md`, `openspec/changes/add-authenticated-grant-issuance/tasks.md` (boxes), `openspec/traceability/grant-issuance.md`, `openspec/traceability/transfer-admission.md` (the deferred sentence), `verification/grant-issuance.txt`, `verification/kernel-verdict.txt` (appended), `verification/openspec-validation.txt`, `verification/tests-js.txt`, `verification/tests-native.txt`. No count pin changed: README.md, utils/nix/writ.nix, the workflow, build-and-run.sh and the VERIFICATION.md count sentences are untouched (INSTALL.md does not exist in this tree).

## Records updated in Task 7

- `docs/GRANT-ISSUANCE.md`: new section "Remaining host preconditions" before "What this document does not claim".
- `VERIFICATION.md` "Explicit proof scope": a paragraph after the six-item list naming the six issuance laws with one-line rationale and limits, and this tree's proof and `--verdict` outcome. The "six declared laws" sentence is left for the re-pin (see below).
- `verification/grant-issuance.txt`: counts 224/1008 -> 226/1010, the two new checks and their mutation result, the full-run commands and results, the `--verdict` outcome.
- `openspec/traceability/grant-issuance.md`: header sentence with the full runs (1010, CPU) and a link to the preconditions; GI-003 row.
- `tasks.md`: 2.2 checked with its evidence; 2.1's parenthetical now reads "1008 ... at box 2.1; 1010 after box 2.2's two GI-003 checks". All seven boxes are checked. The change is not archived.

## Preconditions section summary

Seven numbered preconditions, each a host obligation not met today, quoting the requirement where one applies:
1. Transport identity verification for every `from` and every projection principal, equal to `F.Caller.subject` (GI-001 "an authenticated authority for that source's read domain", GI-004 "the authenticated subject").
2. Signature verification for approvals carried off-host, signer bound to `from`.
3. Durable and serialized state: atomic install at `expected_revision`, serialization, crash preservation, no rollback (GI-005 "atomically register a grant only while the snapshot and approvals used for its validation remain current"; AB-006 "serialize accepted model transitions against current authoritative revisions and preserve their replay state across crashes").
4. Monitor-supplied directory, placements, live stamp, trusted clock (the same values as `T.Context.live`/`now` and `F.Live`) and CSPRNG tokens.
5. Per-use projection rebuilding (GI-008 "whenever it is used"), no caching, reuse, merging or caller-supplied projections.
6. Enablement and capability negotiation in a host adapter (design: "explicit capability negotiation", "Keep the new path disabled until its acceptance tests and host preconditions hold", rollback "never restores old authority epochs or forgets consumed receipts"); `DataOS.commit_from_capability` stays the only host-facing commit.
7. Host-corpus rebaseline: `hosts/unikraft/scripts/check-corpus.sh` (`WRIT_CORPUS_PASS` default 782, with `verification/unikernel-corpus-linux-reference.txt`) and `scripts/genode/writ_bend_tests/writ_bend_tests.run` (`expected_pass 782`) still expect 782 and need rebuilt images and new captures by a later lane; current-tree gates are re-pinned by the controller.

## Pins to update at re-pin time

The values are this lane's alone (1010). If the parallel lane adds N checks, the total is 1010 + N.

| File | Line | Old | New (this lane alone) |
| --- | --- | --- | --- |
| README.md | 114 | `The recorded suite passes **782 checks on each of the JavaScript and native CPU` | `**1010 checks ...` |
| utils/nix/writ.nix | 10 | comment `# 782, and the final line is "ALL LIBRARY TESTS PASSED".` | `# 1010, ...` |
| utils/nix/writ.nix | 55 | `# exactly 782 lines beginning with PASS ...` | `exactly 1010 lines` |
| utils/nix/writ.nix | 64-65 | `if [ "$passes" != 782 ]` / `expected 782 PASS lines` | `1010` / `expected 1010 PASS lines` |
| .github/workflows/writfs-genode-native.yml | 25 | `WRIT_CORE_EXPECTED: '782'` | `WRIT_CORE_EXPECTED: '1010'` |
| contrib/native-hosts/genode/build-and-run.sh | 18 | `(currently 782)` | `(currently 1010)` |
| VERIFICATION.md | 34 | `\| Facade \| 10 \| ...` | `\| Facade \| 12 \| ...` (the two GI-008 facade checks) |
| VERIFICATION.md | after 35 (HostBinding row) | none | new row `\| Issuance \| 226 \| Authenticated approval submission, exact paired-scope registration, revision-checked revocation and replay, attenuation-only derivation, exclusive expiry, subject-scoped per-use projections into T.admit and F.checked_plan (model only; not wired to a host) \|` |
| VERIFICATION.md | 37 | `\| **Total per backend** \| **782** \| ...` | `**1010**` |
| VERIFICATION.md | 49 | `counting both forms yields 782 per file.` | `yields 1010 per file.` |
| VERIFICATION.md | 154 | `` `bend PROOF.bend` prints `ALL PROOFS CHECK` for six declared laws: `` | `twelve declared laws` (the six issuance laws are listed in the paragraph after item 6) |
| VERIFICATION.md | 213 | `No Lean-kernel verdict exists for any of the six laws.` | `... any of the twelve laws.` |
| VERIFICATION.md | 385-386 (Model boundaries) | `The integrated core passes 782 checks and 41 vectors on both CPU backends;` / next line `all six ordinary laws pass.` | `1010 checks` / `all twelve ordinary laws pass.` |

Leave historical sentences at 782 (VERIFICATION.md lines 20, 22, 83, ~302, ~308, ~388; the host-corpus gates above in preconditions item 7): they describe recorded runs of the earlier tree.

## Concerns

1. The total is 1010, not the 1008 in the dispatch, because the two allowed GI-003 checks were added. All records say 1010 = 782 + 226 + 2, and the box 2.1 text was edited to say that 1008 was the box 2.1 figure.
2. `openspec/changes/add-authenticated-grant-issuance/tasks.md` still opens with "All implementation and integration work below is pending." with every box checked. The plan allows only box edits there, so I left it. The controller may want to change it at landing.
3. `verification/openspec-validation.txt` was stale at the merge base (37 items) and now records the 44 this tree produces. If master has since rewritten it, expect a merge conflict that can be resolved by regenerating the file.
4. The build paths are `../writ-build/authenticated-grant-issuance/`, not the `../writ-build/` named in the brief and in VERIFICATION.md, to avoid collisions with the parallel lanes. The commands are recorded as run.
5. There is no Lean kernel verdict and no GPU run. The native run is CPU only.
