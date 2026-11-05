# Task 6 review: end-to-end evidence and traceability (box 2.1)

Reviewed commit 22ff828 against b0ffdbd. Verdicts:

1. Spec compliance: APPROVED
2. Record quality: APPROVED

## Findings (by severity)

No Critical or Important findings.

Minor (no fix required):
- M-1 `docs/GRANT-ISSUANCE.md` still says Task 6 creates the traceability file. Controller ruling: Task 7's. Not flagged.
- M-2 `openspec/traceability/grant-issuance.md`, GI-003 row: a source-version-only and an output-type-only mismatch have no named test; the row says so in plain words (covered by `T.Plan.equal`, by review). Honest; optionally add two checks in Task 7 if cheap.
- M-3 Evidence file `verification/grant-issuance.txt` lists scenario names but only the 2 new Facade names; the 201 earlier Issuance names are not repeated. Acceptable: the traceability file quotes those it relies on, and the file says `bend Tests.bend` output is a scratch capture.

## Verified

Spec compliance
- Read `scenarios()` (IssuanceTests.bend 1385-1470) and the fixtures: each scenario starts at `I.empty` (`initial()`/`pair_initial()`) and moves via submit_source/submit_write/register/revoke/derive; use judged by unchanged `T.admit`, `F.mount/open/checked_plan` on rebuilt projections. The one hand-built state (`epoch_advanced`, `with_live`) is marked in source, evidence and traceability, and the check asserts `I.valid` on it. Current authority (4 checks), revocation mid-flow and after derivation (4), replay (5), and the six denial cases (10) each appear whole with named checks and both permitted and denied outcomes.
- Ran `bend Tests.bend`: rc 0, 1008 PASS lines (`grep -cE '^PASS[: ]'`), 0 FAIL. Last lines: `Property: 324 checks passed; 320 graph cases, each checked against CPU and Bend parallel producers` / `ALL LIBRARY TESTS PASSED`.
- Ran `bend PROOF.bend`: last lines `ALL PROOFS CHECK` / `Use --verdict for mathematical validity.` (12 laws, unchanged files).
- `git diff b0ffdbd --stat` over Issuance.bend, Tests.bend, FacadeTests.bend, PROOF.bend, LAWS.bend is empty; no count pin edited (only the new IssuanceTests.bend section, which adds no pre-existing line deletions).
- Traceability has rows GI-001..GI-008, matching all 8 requirement ids in the spec delta. Extracted all 80 quoted names from the traceability file and checked them verbatim against the PASS lines of my run: none missing. Reviewed-only gaps: host transport identity (GI-001, GI-004), host serialization of installs/durable state (GI-005), monitor time (GI-007), per-use projection rebuilding and no facade entry (GI-008); signatures are in the evidence "Not exercised" list.
- transfer-admission.md diff: before "authenticated grant issuance is deferred."; after "Authenticated grant issuance is modeled in Bend and is not wired to a host; see [grant-issuance.md](grant-issuance.md)." Text only.
- tasks.md box 2.1 checked, citing IssuanceTests.bend section, verification file and both traceability files; 2.2 still open.
- Evidence file has the commands, version, CPU-only statement, count arithmetic (782 + 224 + 2 = 1008; 955 + 53), proof last line, `--verdict` not run, all 23 scenario names (match the test file) and the not-exercised list. Date line 2026-11-05 UTC matches the host clock.

Record quality
- Spot-checked rows against the test file: GI-001 (forged issuer scenarios do assert NotAuthority and MissingApproval, then the honest registration), GI-003 (redirect and expanded manifest do assert ScopeMismatch under both scopes and T.admit Write), GI-005 (replay scenarios assert Replay on second registration, consumed source, consumed write, and revoked serial), GI-006 (derivation scenario asserts attenuated child resolves TF.plan() and dies with the revoked root). None overstates. The unreachable `DestinationIsPlans` gate is marked and tied to a named non-scenario check.
- Gaps use the requirement's own quoted words ("an authenticated authority", "the authenticated subject", "atomically register", "whenever it is used"), not softened.
- Mutation reproduction: ran the report's `run.py` in a fresh scratch dir (scenarios-only, baseline 224 passing). 18 of 19 mutants KILLED, each by a scenario check (NotAuthority gate, serial Replay, write/source Unconsumed, source Unrevoked, source Present, SameScope, SameSubject, request unexpired, inclusive expiry, scope_at_live, derive subject, root Unrevoked, parent currency, usable_by subject and currency, revoke marks nothing, scope_wellformed). `DestinationIsPlans` SURVIVED as the report states (equivalent through public lifecycles; killed by the named registration check).

Not run: `--verdict` (no Lean toolchain), OpenSpec validation (Task 7). CPU run only; no GPU claim.
