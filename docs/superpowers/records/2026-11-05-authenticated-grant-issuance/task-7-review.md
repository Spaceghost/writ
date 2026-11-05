# Task 7 review (box 2.2)

Verdicts: Spec compliance APPROVED. Record quality NEEDS_FIXES (one minor finding).

## Findings

1. Minor (record quality): `verification/openspec-validation.txt` records 44 but nothing in
   any record says why it moved from 37 (stale at merge base; seven items added by other
   lanes' changes/specs plus this tree). Report concern 3 holds the only explanation, and the
   report is not a durable record. Fix: add one sentence to `verification/grant-issuance.txt`
   near line 55 (`Totals: 44 ...`): "the committed file at the merge base was stale (37 items);
   44 is the full count of this tree" listing the seven added items (freestanding-bend-runtime,
   unikernel-appliance-host, unikernel-library-runtime, bend-runtime-host-profile,
   genode-bend-component, genode-capability-adoption, native-host-canary-mounts). The
   command-output file itself may stay pure output.

No other findings.

## Spec compliance, verified

- Ran `bend Tests.bend`: 1010 `PASS` lines, 0 FAIL, ends `ALL LIBRARY TESTS PASSED`.
- Ran `bend PROOF.bend`: `ALL PROOFS CHECK` / `Use --verdict for mathematical validity.`
- `git diff master --name-only -- '*.bend'`: exactly FacadeTests, Issuance, IssuanceTests,
  LAWS, PROOF, Tests. LAWS/PROOF: 0 removed lines.
- No count pin changed: README.md:114, utils/nix/writ.nix:10,55,64-65, the workflow
  (WRIT_CORE_EXPECTED '782'), build-and-run.sh:18 all still 782; no diff in those paths.
  INSTALL.md absent.
- Pins table: line numbers checked against VERIFICATION.md (34, 37, 49, 154, 213, 385-386) and
  the other files; all name file, line, old, new. The HostBinding row 35 insertion point is right.
- Stale phrase "Task 6 of this change" gone from docs/GRANT-ISSUANCE.md.
- Preconditions section: seven items, requirement words quoted (GI-001, GI-004, GI-005, AB-006,
  GI-003, GI-007, GI-008, design text); includes the 782 rebaseline.
- Mutants rerun in scratch copies (tree untouched): dropping version compare in Objects.equal
  fails only "GI-003 approvals differing only in the source object's version ..." first (521 PASS
  before); dropping `U32.is_eq(at, bt)` in Plan.equal fails "... only in output type ..." (522).
- Records agree with the runs (tasks.md 2.2, verification/grant-issuance.txt, traceability).

## Record quality, verified

- No sentence claims a Lean verdict or GPU evidence: every mention says NOT VERIFIED / CPU run /
  not a GPU test.
- `verification/kernel-verdict.txt` appended refusal matches the quoted error verbatim.
- VERIFICATION.md diff is 26 added lines, all in the proof-scope list; count sentences untouched.
- Not run: native CPU build (about 3 min) and OpenSpec; relied on the recorded outputs (the
  JS and native files are claimed byte-identical; tests-js.txt matches my 1010 count).
