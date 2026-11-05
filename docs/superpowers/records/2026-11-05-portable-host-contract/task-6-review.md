# Task 6 review: records (portable host contract)

Reviewed commit cd25c29 against merge base d56325ba (not master).

## Verdicts

1. Spec compliance: APPROVED
2. Record quality: APPROVED (two low findings, optional)

## Findings (by severity)

No critical, high, or medium findings.

Low 1. `openspec/changes/add-portable-host-contract/design.md:97`: the replaced sentence names the section 1 / section 2 split correctly and states no overclaim. The body of design.md never states the implemented rulings (holder is the bound session, not the subject; monitor-owned profiles, roles, delegability; single publication route through `DataOS.commit_from_capability`; plan binding at issue and publish). Nothing contradicts them (lines 24-37 are compatible), but a reader of design.md alone does not learn them. Fix (optional, comment-level): add one sentence after line 97 pointing to `openspec/traceability/portable-host-contract.md` "Requirement summary (task 6)" for the implemented rulings, or state the four rulings in a short paragraph.

Low 2. Report "Pins to update at re-pin time" omits two master mentions of 1014: `docs/GRANT-ISSUANCE.md:379` ("1014 checks on this tree") and `contrib/native-hosts/genode/run/writ_common.inc:7` (comment). Both are historical statements, so leaving them is defensible, but the table claims to list every pin. Fix: add them to the "leave historical" list or the table when re-pinning.

Informational (controller rulings, not flagged): VERIFICATION.md total (782) disagrees with its own rows (sum 1182) until the re-pin; openspec-validation.txt and kernel-verdict.txt refresh in the final round; Task 4 header comment edit in that round.

## Spec compliance: what I verified and ran

- `bend Tests.bend`: exit 0; last lines `Property: 324 checks passed; 320 graph cases, each checked against CPU and Bend parallel producers` / `ALL LIBRARY TESTS PASSED`.
- `bend PROOF.bend`: exit 0; `ALL PROOFS CHECK` / `Use --verdict for mathematical validity.` `grep -c '^law ' LAWS.bend` = 11 (6 + 5).
- `bend PROOF.bend --verdict`: exit 1; `Error: BendTT infrastructure: the kernel did not build (lean: Executable not found in $PATH: "lean"); ...` Matches the quote in the report and VERIFICATION.md. No Lean verdict claimed anywhere.
- OpenSpec 1.16.0 strict: `Totals: 44 passed, 0 failed (44 items)`.
- Stored captures: `tests-js.txt` and `tests-native.txt` each 1182 `PASS` lines, `cmp` identical, SHA-256 120108e0...3425 (both); vectors file 33 lines, SHA-256 fb85d405...30d. Matches the report and the traceability summary. CPU only, `--gpu off`; the records say it is not a GPU test.
- Counts: HostWire 63 + HostIdentity 92 + HostPrimitives 206 + HostConformance 39 = 400; 782 + 400 = 1182; the VERIFICATION.md rows and the suite section lines in tests-js.txt agree.
- `git diff --name-only d56325ba -- '*.bend'`: the nine lane modules/tests (HostConformance{Tests,Vectors}, HostIdentity{,Tests}, HostPrimitives{,Tests}, HostPublication, HostWire{,Tests}) plus LAWS, PROOF, Tests. Nothing else.
- Count pins: `git diff d56325ba -- README.md docs/INSTALL.md utils .github contrib` is empty (untouched). The pins table's 17 master line citations checked against `master` (README 114, INSTALL 76/161/162, writ.nix 10/55/64, workflow 25, build-and-run.sh 18, genode README 135/149/162, VERIFICATION 38/50/155/214/386): all match the quoted old values. New values 1414 / seventeen laws are correct (1014+400; 12+5).
- environment.txt: 45 files / 17197 lines / 1182 / 1182; I recounted 45 root+examples `.bend` files and 17197 lines.
- Six spot-checked traceability rows: eight check names (PH-001 FastPathUnavailable, PH-003 ForeignHost, PH-004 Ambiguous, PH-006 UnmediatedRoute, PH-009 Substitution, PH-010 StopEffects no recall, PH-011 tag-5 UnknownTag, PH-014 order) each exist in the named `*Tests.bend` and have exactly one `PASS:` line in tests-js.txt. Vector ids PH-002-1..5, PH-003-1..3, PH-004-1..3, PH-005-1..11, PH-009-1..4, PH-010-1..6, PH-012-1 all appear in portable-host-vectors.txt.
- Every PH-001 to PH-014 has a row in "Requirement summary (task 6)" with checks/vectors or a gap quoted from the requirement or section 2 task.
- Carried Task 4 notes: line 74 cites `PH-005 delegate at a stale revision denied StaleRevision` (exists, one PASS line); PH-010 row notes `complete` ignores sequence and status; PH-009 row notes the recovery record has no destination.
- tasks.md: boxes 1.1-1.4 checked, each citing files; preface says section 1 landed, section 2 open, unarchived. PLATFORMS.md: one sentence (lines 123-127), accurate (four modules named, HostPublication with HostPrimitives, native qualification pending in section 2).

## Record quality

- No row says executed without a check that runs the scenario; PH-012 is explicitly decision half only on Bend fixtures; PH-013 has no model check and is "Not marked done"; PH-014 and PH-006/007/008/009/010 keep native parts as gaps, in the requirement's or task's own words.
- No sentence claims a Lean verdict, GPU evidence, or a Genode CI run at 1182/1414. The report states the Genode run was not executed; VERIFICATION.md states no native host replays the vectors.
- Failed/incomplete outcomes preserved (`--verdict` exit 1, concerns 1-6 in the report).
- Manifest not regenerated, per the cross-lane ruling (controller regenerates at merge).
