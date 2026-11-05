# Task 6 report: selection rule document; samples never bypass final commit (task 1.5)

Status: DONE_WITH_CONCERNS (concerns at the end; none blocks).

Branch `lane/executor-rendezvous`, from 045973f (Task 5 records). Touched: `RendezvousTests.bend` (new `integration` section, header line, `main` count), `docs/EXECUTOR-RENDEZVOUS.md` (new), `openspec/changes/add-executor-rendezvous/tasks.md` (box 1.5 and the preface line), and this records directory. `Backplane.bend`, `DataOS.bend`, `Negotiation.bend`, `Transfer.bend`, `LAWS.bend`, `PROOF.bend` and `Tests.bend` are unchanged by this task (`git diff 045973f -- LAWS.bend PROOF.bend Backplane.bend DataOS.bend Tests.bend` is empty; `Tests.bend` keeps Task 1's two lines against master).

## The final-commit checks

The section drives the unchanged `Backplane.commit` and `DataOS.commit_from_capability` with a `B.Context` (BackplaneTests' binding, graph, candidate and principals) whose `negotiation` is `R.negotiation_context(dispatched_t(), raw, snapshot)`: selection 3 of A's offer, A's passing evidence stored, `Dispatch{3, 57, 6}`. The session is A's Running trial session (revision 6, receipt 11) and the ledger holds its reservation (revision 1). The facade uses FacadeTests' execute descriptor and registry for reader 7. `kept(result)` asserts rejection, the Running session at revision 6, the ledger at the same revision and reader balance, and the hold for receipt 11 still live (no reservation spent). `rendezvous_passed()` asserts the selection is current at 110 with the evidence and dispatch recorded.

`integration_commits`:
1. "integration a dispatched, sampled execution commits through Backplane.commit on the projected context: Committed, the write intent keeps the plan, origins and label, and the ledger advances to revision 2" (positive control).
2. "integration the same execution commits through DataOS.commit_from_capability with reader 7's execute descriptor" (positive control).
3. "integration with the selection current and dispatched, the reader's transfer write grant revoked: T.admit denies, Backplane and the facade reject and spend no reservation" (missing grant: `T.admit` at `Write`).
4. "integration A's grant 3 revoked after dispatch: the projected approvals are empty, N.owners denies, Backplane and the facade reject and spend no reservation" (provider grant revoked: `N.owners`).
5. "integration the issuer's live stamp advanced to epoch 5 after dispatch: the projection is empty, Backplane and the facade reject and spend no reservation" (stale epoch: `N.owners` on the emptied projection).
6. "integration with the selection current and dispatched, an output carrying control label 3 does not fit the destination: Backplane rejects and spends no reservation" (wrong destination: Backplane's `output_fits`).
7. "integration with the selection current and dispatched, the reader's budget funds quote 41 against the request's 42: N.budget_live denies, Backplane and the facade reject and spend no reservation" (budget shortfall: `N.budget_live`).

`integration_samples`:
8. "integration a sample is not a commit: before A's evidence is stored the passing sample 31 is not projected so N.sample rejects, a Challenged session cannot approve, and a Sampled session cannot commit (on A's evidence it samples)".
9. "integration once object 10 withdraws A's approval, A's Sampled session cannot approve and its Reserved session cannot reach Running on the projection (it starts on the approved one)".

## Removal map

Full table in `task-6-mutants.md` (11 runs through an integration-only driver in scratch; 10 killed, 1 equivalent):

- `Backplane.checks` `N.owners` -> True kills check 4, and check 5 once 4 is removed (B1, B1e).
- `negotiation_context` non-current arm passing raw approvals kills check 4, and check 5 once 4 is removed (R1, R1e). This shows that the rendezvous projection is what empties the owners input.
- `Backplane.checks` `N.budget_live` -> True kills check 7 (B2).
- `Backplane.commit_output` `output_fits` -> True kills check 6 (B3).
- `Transfer.header` write-grant require -> True kills check 3 (X1).
- `Backplane.checks` `T.admit` Require -> True survives, equivalent (B4): `output_policy` matches only `T.Admitted`, so `commit_output` rejects on a denied admission before it reads the checks. Check 3 is pinned by X1 instead.
- The sample projection passing raw samples kills check 8 (R2).
- `N.approve` owners -> True and `N.start` owners -> True kill check 9 (N1, N2).

## The document's sections in brief

`docs/EXECUTOR-RENDEZVOUS.md`:
- **Worked example:** the plan's example (B 30 unapproved, A 40 selected; B's dispatch NotSelected; revocation denies dispatch, N.start and the final commit), with the exact check names, and a note that the trial fixtures quote 38 and 41.
- **Current gap:** the model is implemented, while there is no host adapter, transport, durable state, trial metering or facade entry; the path stays disabled. It links the spec, design, tasks, traceability (pending, Task 7), GRANT-ISSUANCE.md and the locality proposal.
- **Selection rule:**
  - one rendezvous per request;
  - offers, with the provider-scoped ids ruling, claims versus grant authority, `provider_rights()`, serials never reused, the zero-quote OverBudget ruling, and submission versus eligibility;
  - origin approvals: checked against the issuance directory, unneeded origins refused at submission (ScopeMismatch), bound to the issuer's live stamp (StaleEpoch at submission, live stamp at use), authority re-read, and withdrawal with second-withdrawal Revoked;
  - the 12 eligibility gates in order, with their reasons;
  - ranking profile 1 as the strict order (quote, provider id, serial), and what a selection stores and how its currency is re-derived;
  - conflicts and withdrawal: ConflictingOffer, provider-only `withdraw_offer`, Revoked for an absent id, no re-ranking, abandon and retired ids.
- **Trial binding and dispatch:**
  - the evidence gates, with one evidence per selection and abandon-and-reselect on expiry (with its liveness cost);
  - the projection's three lists;
  - `session_follows_selection` and the `WrongTrial` gate;
  - the dispatch target match, then the gate order with the host revision gate (`HP.current`), the caller-token gate, evidence, trial and replay;
  - the incarnation in the record, the accepted WrongProfile-before-StaleRevision order, and `provider_registry` with the worker binding left to the monitor.
- **The final commit still decides:** a table of the integration checks and what denies each, with a pointer to the mutation table.
- **Limits:** gameable samples, and identity is not integrity; no declassification; confinement and final validation are still required; origins approve providers, not prices; the quote is a ceiling and is not settled (budget and hold still bound to the request's quote and units; exact versus ceiling with Spaceghost on q18); `add-metered-sample-execution` is unmet.
- **Trusted inputs, each with what goes wrong:**
  - `from`;
  - `Snapshot.issuer`, with the grants installed by the monitor recorded as a gap;
  - `Snapshot.transfer` and the transfer context inside `n_context`;
  - `now` (the challenge window needs non-decreasing time and no challenge-id reuse);
  - the request and constraint at `open`;
  - `session`, `expected_session` and `n_context`;
  - `host` and `expected_host_revision`, with the configured profiles;
  - rebuild per use for `negotiation_context` and `provider_registry`;
  - atomic install at `expected_revision`.

  It also lists the untrusted claims (records, `OfferId`, `approval_id`, `worker_session`).
- **Public entry points:** a table with their signatures. The exported helpers are named as helpers.
- **What the locality proposal may extend:** append eligibility gates (remove, never reorder), complete the quote with movement costs (pending q18), and rely on the existing bindings. It may not replace profile 1 without a new versioned profile and a coordinated ER-003 change.
- **Remaining host preconditions:** 10 items.
- **What this document does not claim:** no host meets the inputs, no wiring, no metering, no settled billing, and no Lean verdict.

## Commands and final lines

Environment: `export PATH="$HOME/.local/share/writ-toolchains/bend-2.0.39/bend/bin:$PATH"; export BEND_NO_TELEMETRY=1`.

- `bend Rendezvous.bend --check-only`: `ALL PROOFS CHECK` / `Use --verdict for mathematical validity.`
- `bend RendezvousTests.bend`: `Rendezvous: 197 checks passed` (188 plus 9 new).
- `bend Tests.bend`: last line `ALL LIBRARY TESTS PASSED`, exit 0. 1625 PASS lines (the `PASS:` and `PASS ` forms counted together), which is 1616 plus 9 new. Summary lines:
  - `Negotiation: 26 checks passed`
  - `Backplane: 40 checks passed`
  - `Facade: 12 checks passed`
  - `Issuance: 230 checks passed`
  - `Rendezvous: 197 checks passed`
- `bend PROOF.bend`: `ALL PROOFS CHECK` / `Use --verdict for mathematical validity.`, exit 0. 24 laws, unchanged.

Not run: `--verdict`, the native, JS and GPU runs, and OpenSpec validation (Task 8).

## Concerns

1. **The write-revoked check is pinned outside Backplane.** It is pinned by a Transfer mutant (X1), because Backplane's own `T.admit` Require is redundant with `output_policy` (B4, equivalent). This is a property of the unchanged Backplane. It is recorded, not changed.
2. **Checks 4 and 5 deny at the same Backplane gate (`N.owners`).** They differ in what empties the projection: a revocation versus an epoch advance. The "stale epoch" here is the issuer epoch the rendezvous reads. A transfer-stamp drift would be denied by `T.admit` and `stamps_agree` together, and that case is already covered in BackplaneTests.
3. **The mutation sweep used an integration-only driver.** It was used so that Negotiation, Transfer and Backplane mutants report the integration check rather than an earlier section's. The B1e and R1e variants delete one check in the scratch copy to reach the epoch check.
4. **The traceability link is pending.** The document names `openspec/traceability/executor-rendezvous.md` as written by task 2.1 and not yet present. Task 7 must create it at that path.
