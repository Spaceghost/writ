# Task 6 review: selection rule document; samples never bypass final commit (task 1.5)

Reviewed dc03bda against 045973f.

Verdict 1, spec compliance: APPROVED
Verdict 2, document quality and honesty: APPROVED

## Findings (ordered by severity; none blocking)

1. Low, `openspec/changes/add-executor-rendezvous/tasks.md` box 1.5. The citation lists five of the nine integration checks. It omits the epoch-advance check ("integration the issuer's live stamp advanced to epoch 5 ...") and the budget-shortfall check ("integration with the selection current and dispatched, the reader's budget funds quote 41 ..."), both of which the brief names. Fix: add those two names (and the withdrawn-approval check) to the parenthetical.
2. Low, `RendezvousTests.bend` check "integration a sample is not a commit ...". Its third conjunct (a Sampled session cannot commit) is rejected by Backplane's stage requirement, not by anything about the sample. The doc table words it honestly ("a Sampled session cannot commit"), and the second check (N.approve/N.start on the withdrawn projection) carries the real weight. No change needed; keep the doc wording as is.
3. Cosmetic, tasks.md preface: "Tasks 1.1 to 1.5 are implemented in `Rendezvous.bend`" - 1.5 is a doc plus tests, not Rendezvous.bend code. Fix: "Tasks 1.1 to 1.4 are implemented in Rendezvous.bend; 1.5 in docs/EXECUTOR-RENDEZVOUS.md and RendezvousTests.bend".

## Verified (spec compliance)

- Read all seven denial/positive integration checks plus the two sample checks. Each denial uses `kept(...)`, which asserts rejection, Running session at revision 6, ledger revision and reader balance unchanged, and `N.hold_live` for receipt 11: the reservation is not spent. Checks 3, 6 and 7 also assert `rendezvous_passed()` (selection current, evidence, dispatch recorded). The commits drive the real `B.commit` and `OS.commit_from_capability` on `negotiation_context` of the dispatched state; positive controls commit.
- Reran mutants on a scratch copy with an integration-only driver (baseline prints done, no FAIL): B2 (`N.budget_live` Require to True) killed by the budget check; B3 (`output_fits`) killed by the wide-output check; X1 (`Transfer` write-grant require) killed by the write-revoked check; B4 (`T.accepted(T.admit)` Require to True) survives, equivalent as reported (`output_policy` rejects first; controller ruling).
- `bend Tests.bend`: exit 0, "ALL LIBRARY TESTS PASSED", 1625 PASS lines; Negotiation 26, Backplane 40, Facade 12, Issuance 230, Rendezvous 197. `bend PROOF.bend`: ALL PROOFS CHECK.
- `git diff 045973f --stat` over LAWS.bend, PROOF.bend, Tests.bend, Backplane.bend, DataOS.bend: empty. Changed files are only RendezvousTests.bend, docs/EXECUTOR-RENDEZVOUS.md, tasks.md and the records directory. No count pin in the doc or code beyond the existing summary print.
- Box 1.5 is checked and cites files and check names.

## Verified (document)

- Order: worked example, then current gap (model implemented; no host adapter, transport, durable state, metering or facade entry; path disabled), then contracts.
- The 12-gate table matches `eligibility_gates_found` (Rendezvous.bend:1307-1326) gate for gate, including the reasons and the `found_fault` Expired/StaleEpoch/Revoked split. The dispatch order matches `dispatch_gates` (2316) and `run_gates` (2289): revision, host revision, Running session, request match, currency, caller token, evidence, WrongTrial, Replay, with the target gates reported first (documented as an accepted order).
- Rulings present: provider-scoped offer ids, one rendezvous per request, approvals re-checked against the directory and bound to the live stamp, unneeded origins refused (ScopeMismatch), strict ranking (quote, provider, serial), one evidence per selection with abandon-and-reselect and its liveness cost, `session_follows_selection`/WrongTrial, host revision gate, caller token compared with the grant's, zero quote OverBudget, second withdrawal Revoked.
- Trusted inputs each state what goes wrong if wrong (`from`, issuer state, transfer context, `now`, request/constraint, session/n_context, host/profiles, rebuild-per-use, atomic install). Gaps listed: unmetered trial compute, quote ceiling pending Spaceghost (q18), grants installed by the monitor. Ten host preconditions. The closing section disclaims host runs, wiring, metering, billing semantics and a Lean verdict.
- Spot-checked four claims against tests: second withdrawal Revoked ("ER-006 a second withdrawal of approval 1 denied Revoked"); second evidence Replay ("ER-005 a second evidence for selection 3 denied Replay"); WrongTrial for a session sampled under a retired selection (line 1985); the quoted check names in the doc (ER-002, ER-001, ER-007, integration) all exist in RendezvousTests.bend. Laws named in the doc exist in LAWS/PROOF/Rendezvous.bend.

Not run: `--verdict`, native/GPU runs, OpenSpec validation (Task 8).
