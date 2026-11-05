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

The values are this lane's alone (1014). If the parallel lane adds N checks, the total is 1014 + N.

| File | Line | Old | New (this lane alone) |
| --- | --- | --- | --- |
| README.md | 114 | `The recorded suite passes **782 checks on each of the JavaScript and native CPU` | `**1014 checks ...` |
| utils/nix/writ.nix | 10 | comment `# 782, and the final line is "ALL LIBRARY TESTS PASSED".` | `# 1014, ...` |
| utils/nix/writ.nix | 55 | `# exactly 782 lines beginning with PASS ...` | `exactly 1014 lines` |
| utils/nix/writ.nix | 64-65 | `if [ "$passes" != 782 ]` / `expected 782 PASS lines` | `1014` / `expected 1014 PASS lines` |
| .github/workflows/writfs-genode-native.yml | 25 | `WRIT_CORE_EXPECTED: '782'` | `WRIT_CORE_EXPECTED: '1014'` |
| contrib/native-hosts/genode/build-and-run.sh | 18 | `(currently 782)` | `(currently 1014)` |
| VERIFICATION.md | 34 | `\| Facade \| 10 \| ...` | `\| Facade \| 12 \| ...` (the two GI-008 facade checks) |
| VERIFICATION.md | after 35 (HostBinding row) | none | new row `\| Issuance \| 226 \| Authenticated approval submission, exact paired-scope registration, revision-checked revocation and replay, attenuation-only derivation, exclusive expiry, subject-scoped per-use projections into T.admit and F.checked_plan (model only; not wired to a host) \|` |
| VERIFICATION.md | 37 | `\| **Total per backend** \| **782** \| ...` | `**1014**` |
| VERIFICATION.md | 49 | `counting both forms yields 782 per file.` | `yields 1014 per file.` |
| VERIFICATION.md | 154 | `` `bend PROOF.bend` prints `ALL PROOFS CHECK` for six declared laws: `` | `twelve declared laws` (the six issuance laws are listed in the paragraph after item 6) |
| VERIFICATION.md | 213 | `No Lean-kernel verdict exists for any of the six laws.` | `... any of the twelve laws.` |
| VERIFICATION.md | 385-386 (Model boundaries) | `The integrated core passes 782 checks and 41 vectors on both CPU backends;` / next line `all six ordinary laws pass.` | `1014 checks` / `all twelve ordinary laws pass.` |

Leave historical sentences at 782 (VERIFICATION.md lines 20, 22, 83, ~302, ~308, ~388; the host-corpus gates above in preconditions item 7): they describe recorded runs of the earlier tree.

## Concerns

1. The total is 1010, not the 1008 in the dispatch, because the two allowed GI-003 checks were added. All records say 1010 = 782 + 226 + 2, and the box 2.1 text was edited to say that 1008 was the box 2.1 figure.
2. `openspec/changes/add-authenticated-grant-issuance/tasks.md` still opens with "All implementation and integration work below is pending." with every box checked. The plan allows only box edits there, so I left it. The controller may want to change it at landing.
3. `verification/openspec-validation.txt` was stale at the merge base (37 items) and now records the 44 this tree produces. If master has since rewritten it, expect a merge conflict that can be resolved by regenerating the file.
4. The build paths are `../writ-build/authenticated-grant-issuance/`, not the `../writ-build/` named in the brief and in VERIFICATION.md, to avoid collisions with the parallel lanes. The commands are recorded as run.
5. There is no Lean kernel verdict and no GPU run. The native run is CPU only.

## Final fix round

Read `final-review.md` and `task-7-review.md` (not edited). Controller ruling on I-1: Option A.

### I-1: register takes the authenticated `from`

- `Issuance.register(state, expected_revision, from, request, now, token)`. `register_current`, `register_checked`, `register_checks` and `register_gates` take `from` too. The new gate is `Gate{speaks_for_subject(from, scope), SubjectMismatch{}, ...`, third in `register_gates` (after StaleRevision and UnknownVersion), before any approval is read. SubjectMismatch is the reason from the fixed set, and the module header says so. `Principal.id` and `speaks_for_subject` moved above `register_gates`, because Bend needs a definition before its first use. Their text is unchanged except for one comment sentence. `derive` and the projections use the same helper.
- The single-use ruling is unchanged. The subject check grants no authority.
- Updated comments: the module header ("Registration takes the authenticated `from` ..."), the `register` doc, the `register_gates` denial-order comment, and the `Request` type comment. M-4: the stale "projection (task 1.5)" comment now reads "the projections `reads`, `writes` and `registry` admit only the authenticated principal's current grants".
- Laws: `issuance_stale_revision_rejects` and `issuance_stale_registration_keeps_state` gain `for from: Issuance.Principal`, and their rationale says "every calling principal ... (the subject included, so the subject check is not what denies it)". These are still real statements over every `from`. The PROOF.bend terms only thread `from` through, because the outer revision match still comes first. `git diff <merge-base> -- LAWS.bend PROOF.bend` still has 0 removed lines. There are still 12 laws.
- Tests: all 94 `I.register`/`I.register_checks` calls in `IssuanceTests.bend` pass the request scope's subject. That is `subject_principal()`, or `principal8()` for the subject-8 requests, so every earlier check still reaches the gate it was written for. Both fixtures moved to the top of the file (synthetic, commented). The four new checks:
  - "GI-004 principal 8, neither an authority nor subject 7, registering subject 7's pair with rights 0 until 101 denied SubjectMismatch, both approvals unconsumed"
  - "GI-004 the source authority or the write authority registering subject 7's request denied SubjectMismatch"
  - "GI-004 after principal 8's registration is denied, subject 7 registers the same pair as grant 3"
  - "scenario third-party registration: principal 8 registering subject 7's approved pair with rights 0 until 101 is denied SubjectMismatch and nothing is projected; subject 7 then registers the pair as grant 3 and T.admit admits TF.plan()"
- Mutation (scratch copies under the session scratchpad, `t7fix/`): with the gate condition replaced by `True{}`, the run is KILLED, and the first FAIL is the principal-8 check (525 PASS before it). With the gate weakened to accept any caller except principal 8, the run is KILLED, and the first FAIL is the authority-caller check (526 PASS). `bend PROOF.bend` still prints ALL PROOFS CHECK under both, as expected: the laws rely only on the revision match.

### Minor findings

- M-1: `docs/GRANT-ISSUANCE.md` "Rebuilding the projections" gains a "Rights reach Frontend only" bullet. It says Transfer grants carry no rights, so a bare `T.admit` path admits a current grant's whole plan whatever its rights, including 0. It states the hazard, and the host must route rights-limited use through Frontend.
- M-2: "trusted, monotone clock: `now` never decreases across the transitions and uses of one issuer state" is now in the live-stamp section (which also states the revival examples) and in precondition 4. The GI-007 traceability gap says the same.
- M-3: "no grant-level revocation" is listed as open in GRANT-ISSUANCE.md "What this document does not claim" and at the end of the traceability file.
- M-4: done (above).
- M-5: `verification/grant-issuance.txt` now says why openspec-validation.txt went from 37 to 44 items: the stale file at the merge base, and the seven added items by name.
- Documents: the GRANT-ISSUANCE.md entry-point table and "The authenticated principal" section (the old "`register` takes no `from`" sentence is replaced with the I-1 rationale and a named check). Traceability: GI-002 and GI-004 rows (implementing defs, named checks, the gap now includes the `from` of `register`) and the header count. Evidence file: counts, a new "Registration-caller checks" section with its mutation result, and the scenario list (24, matching the run). tasks.md: the 2.1 and 2.2 box notes now give 1014.

### Results (verbatim)

1. `bend Tests.bend -o ../writ-build/authenticated-grant-issuance/tests.js && node ... > verification/tests-js.txt`: exit 0. The last lines are `Property: 324 checks passed; 320 graph cases, each checked against CPU and Bend parallel producers` / `ALL LIBRARY TESTS PASSED`. There are 1014 PASS lines (961 `PASS: ` + 53 `PASS `) and 0 FAIL. `Issuance: 230 checks passed`, `Facade: 12 checks passed`.
2. Native CPU: the build exited 0 (real 2m42.137s), and `+RTS --threads 4 --gpu off` exited 0 with 1014 PASS. The output is byte-identical to tests-js.txt: SHA-256 `e07942b33808774a01ebf82f6a1a2396513088b893b43eeb3641831a87138928`. The VECTOR lines equal master's. This is a CPU run, not a GPU test.
3. `bend PROOF.bend`: `ALL PROOFS CHECK` / `Use --verdict for mathematical validity.` (12 laws; proofs.txt unchanged).
4. `--verdict`: not re-run in this round. The Task 7 attempt (exit 1, no `lean`) stands in kernel-verdict.txt.
5. OpenSpec 1.16.0 strict: `Totals: 44 passed, 0 failed (44 items)`, identical to the recorded file.

Count: **1014 = 782 plus 232 new checks (230 Issuance + 2 Facade)**. The pins table above now gives 1014.

`git diff --stat <merge-base> -- '*.bend'` still lists exactly FacadeTests, Issuance, IssuanceTests, LAWS, PROOF and Tests. No use-time module changed, and no count pin changed.
