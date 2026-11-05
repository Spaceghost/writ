# Task 5 report: dispatch, invalidation and the provider registry (task 1.4; ER-007, ER-006 dispatch, ER-001 dispatch)

Status: DONE_WITH_CONCERNS (concerns at the end; none blocks the task).

Branch `lane/executor-rendezvous`, base 131a835 (Task 4 records), lane branched from master 78449c9. Touched: `Rendezvous.bend`, `RendezvousTests.bend`, `LAWS.bend` and `PROOF.bend` (additions only), `openspec/changes/add-executor-rendezvous/tasks.md` (box 1.4 and the preface line), and this records directory. `HostPrimitives.bend`, `HostIdentity.bend`, `Frontend.bend`, `Transfer.bend`, `Negotiation.bend`, `Issuance.bend` and `Tests.bend` are unchanged (`git diff --stat 78449c9 -- HostPrimitives.bend HostIdentity.bend Frontend.bend Transfer.bend Negotiation.bend Issuance.bend Tests.bend` shows only the Task 1 two-line Tests.bend edit). Rendezvous now imports `Frontend` (F), `HostIdentity` (HI) and `HostPrimitives` (HP) for read-only use of their exported helpers (`HI.session_at`, `HI.sessions`, `HI.session_caller`, `HI.caller_subject`, `HP.identity`, `HP.bindings`, `HP.binding_at`, `HP.non_delegable_session`, `F.token`).

## What was added

- Public entry point `dispatch(state, expected_revision, offer, host, worker_session, session, expected_session, n_context, snapshot)`, with the outer helper `dispatch_by`, the checked step `dispatch_checked` and `commit_dispatch`.
- Exported helpers: `dispatch_target_selected` over the gate list `target_gates`, with `worker_lookup`, `worker_caller_is` and `binding_names`; the inner gate lists `dispatch_gates` and `run_gates`; `evidence_for` and `dispatch_recorded`.
- Public projection `provider_registry(state, snapshot) -> F.Registry`, with `registry_for_token`, `keep_capability`, `granted_registry`, `selected_registry`, `selection_dispatched` and `registry_open`.
- Law `rendezvous_unselected_dispatch_rejects` (LAWS.bend) and its proof (PROOF.bend).
- Header: the trusted host input, the outer-match paragraph, a Dispatch paragraph, a Provider registry paragraph, the public entry point list, the Laws paragraph (five laws), and the projection paragraph now says `dispatch` requires `session_follows_selection`. The `Dispatch` type comment no longer says "(a later task)".
- Tests: the section `dispatch` (29 checks in `dispatch_happy`, `dispatch_inner`, `dispatch_invalidation`, `dispatch_substitution`). The 103-column fixture comment at the old `RendezvousTests.bend:1191` is rewrapped; no comment line in either file is over 100 columns.

## `dispatch`, in order

Outermost: `dispatch_target_selected(state, offer, host, worker_session)`, which is `Guard.all` over `target_gates(selection(state), ...)`:

1. a selection exists and its stored offer's identity is `offer` (NotSelected);
2. `HI.session_at(HI.sessions(HP.identity(host)), worker_session)` is exactly one session whose `F.Caller.subject` is the selected offer's provider id (NotSelected; no session or two under the id is NotSelected);
3. that session is non-delegable (`HP.non_delegable_session`; NotSelected);
4. `HP.binding_at(HP.bindings(host), worker_session)` is exactly one binding naming the selected offer's profile (WrongProfile; no binding, as for a client session, or two bindings, is WrongProfile).

False gives `Rejected{state, first failing target gate's reason}` before the revision, session or evidence is read. Then `Guard.all` over `dispatch_gates`, the reason being the first failing gate of the same list:

5. `revision_current` (StaleRevision);
6. `N.ready(session, expected_session, N.Running{}, n_context)` (WrongStage);
7. the session's request is exactly the rendezvous request (ScopeMismatch);
8. `current_gates` spliced in: the selected record still stored and unambiguous, its request, the live stamp (StaleEpoch), then every eligibility gate with its own reason (NoGrant, ScopeMismatch, Expired, StaleEpoch, Revoked, RightsNotHeld, OverBudget, Constraint, MissingApproval);
9. `run_gates`: evidence for this selection id naming the selected offer's identity and provider claim is stored (MissingEvidence); `session_follows_selection(state, session)` (WrongTrial); no dispatch is recorded for this selection id (Replay).

On acceptance it records `Dispatch{selection id, worker_session}` ahead of the earlier records and advances the revision once; the change id is the selection id.

Rulings applied:
- **Profile gate placement.** The brief puts the profile binding both in the outer predicate and in the inner gate list. A gate after an outer conjunct that already holds is unreachable (an equivalent mutant), so it is kept once, as the last target gate, and the outer False arm reports its reason (WrongProfile), as the brief's "reported by the inner gates" asks. Consequence: WrongProfile is reported before StaleRevision, not after MissingEvidence. The header and the `dispatch` doc state this order.
- **Carried item (Task 4 re-review).** The fixed error set already has `WrongTrial`, so the trial gate uses it, placed directly after the MissingEvidence gate: a selection with no evidence still reports MissingEvidence, and evidence for another trial reports WrongTrial.
- **Evidence binding.** "Stored evidence for this selection" is checked as evidence under the current selection id that also names the selected offer's identity and provider claim (`evidence_for`), as the Task 4 S2 fix does for the projection, so a monitor-installed foreign record under the current id is not this selection's evidence. Stricter than the brief.
- **Replay is per selection.** A record for a retired selection does not block a later selection's dispatch, since ids are never reused.

## `provider_registry`

`provider_registry(state, snapshot)` is `I.registry(issuer, selected offer's provider, now)` filtered to the token of the backing grant under the selected offer's grant id, read from the snapshot issuer. It is produced only while `selection_current(state, snapshot)` holds and a dispatch is recorded for the current selection id; otherwise `F.EmptyRegistry{}`. It is recomputed at every call; nothing is cached. With no selection, before dispatch, after a revocation, an expiry, an epoch advance, an origin's withdrawal, or after `abandon` and a reselection that is not yet dispatched, it is empty. The header and its doc say the monitor must open the worker's input handle (`HostPrimitives.issue`) from this projection, rebuilt per use, and never from the raw issuer registry (which also holds the provider's other grants; the test with A's second grant 12 shows the difference) or from a cached projection.

## Denial cases and check names

Fixtures (section `dispatch`):
- Host: SYNTHETIC MONITOR STATE built through `HP.open_session` on host 61, incarnation 57, profiles 1 and 2. Session ids, as HostIdentity allocates them: 1 A's delegable client, 2 A's non-delegable client (no binding), 3 C's worker at profile 1, 4 A's worker at profile 2, 5 B's worker at profile 2, 6 A's worker at profile 1, 7 B's worker at profile 1. Worker ids 6 and 7 avoid profile ids 1 and 2, approval ids 1, 2 and 4 and selection ids 2 to 5. Two synthetic variants: a second session under id 6, and a second binding for 6.
- Trial world (Task 4): A's session is advanced through approve, reserve (receipt 11, a fresh ledger) and start on the projected context to Running at revision 6; dispatch of selection 3 to session 6 gives revision 7.
- Short-grant world: A also holds grant 12 (token word 17, valid while now < 130); approval serial 14 until 145; offer {201, 6} quote 39 until 130; selected at 110 as selection 2.
- Substitution world, from the dispatched state: 101 withdraws B's approval, B offers {202, 8} at quote 20, abandon, 101 approves B afresh (serial 25 until 135, id 4), B selected at 116 as selection 5, B's trial (challenge 26, sample 36) stored.

| Case | Expected | Check name |
|---|---|---|
| selected provider after N.start | accepted, Dispatch{3, 6}, revision 7 | ER-007 after N.start on the projected context, A's Running session dispatches selection 3 to A's worker session 6 (profile 1): Dispatch{3, 6} at revision 7, id 3 issued, nothing else changed |
| registry after dispatch, Frontend use | one capability, TF.plan() | ER-001 provider_registry after dispatch holds exactly grant 3's capability for A, and F.mount, F.open and F.checked_plan resolve it to TF.plan() for caller A |
| before dispatch | empty registry | ER-007 before dispatch provider_registry is empty, though Issuance projects grant 3 for A, so F.mount finds no capability |
| raw registry holds two grants | filtered to one | ER-001 with A also holding grant 12 (token word 17), the raw registry for A has two capabilities but provider_registry keeps only the selected grant 3's token |
| B's worker / B's offer / unknown offer | NotSelected | ER-001 dispatch to an unselected provider: A's offer with B's worker session 7, B's offer {202, 5} with B's or A's worker session, or A's unknown offer {201, 9}, denied NotSelected |
| C's worker, unbound id, twin session, delegable client | NotSelected | ER-001 a worker session of C (3), an unbound session id 9, a session id 6 the identity table holds twice, or A's delegable client session 1, denied NotSelected |
| worker_caller_is arms (masked) | False | ER-001 worker_caller_is: no session under id 9, or two sessions under id 6 both with caller A, is not A's worker; the one session 6 is |
| other profile, no binding, twin binding | WrongProfile | ER-001 A's worker session 4 bound under profile 2, A's non-delegable client session 2 with no worker binding, or a session 6 bound twice, denied WrongProfile |
| no selection | NotSelected first | ER-001 dispatch_target_selected is false with no selection and true for A's offer on A's worker session 6; with no selection a dispatch at a stale revision is denied NotSelected first |
| stale revision | StaleRevision | ER-007 dispatch at revision 5 against 6 denied StaleRevision |
| not Running | WrongStage | ER-007 a session at Reserved, or a Running session at revision 6 named as 5, denied WrongStage |
| second dispatch | Replay | ER-007 a second dispatch of selection 3 denied Replay |
| no evidence, foreign evidence | MissingEvidence | ER-005 dispatch with no evidence for selection 3, or with evidence under id 3 naming B's offer or B's claim, denied MissingEvidence |
| same offer reselected | MissingEvidence | ER-005 A's same offer {201, 4} reselected as selection 4: retired selection 3's evidence for that offer and provider does not count, so dispatch is denied MissingEvidence |
| list order | whole list read | ER-007 the evidence and dispatch lookups read the whole list: A's evidence for selection 3 behind a record for selection 2 still dispatches, and Dispatch{3, 6} behind a record for selection 2 still denies Replay |
| wrong-trial session (carried) | WrongTrial | ER-005 A's session sampled under retired selection 3 and advanced to Running on B's projection is denied WrongTrial for B's selection 4; B's own Running session dispatches |
| B selected: B's p2 worker, A's target | WrongProfile; NotSelected | ER-001 while B is selected, B's worker session 5 bound under profile 2 is denied WrongProfile, and A's offer on A's worker session is denied NotSelected |
| revocation race | Revoked; projection and registry empty; N.start rejected | ER-007 selection racing revocation: once 101 revokes the source approval behind A's grant 3, dispatch is denied Revoked, the projection carries no approvals so N.start is rejected on it (it advances on the earlier one), and the dispatched selection's provider_registry is empty |
| epoch advance | StaleEpoch; registry empty | ER-007 epoch change between selection and dispatch: once the issuer's live stamp advances to epoch 5, dispatch is denied StaleEpoch and the dispatched selection's provider_registry is empty |
| origin withdraws, offer expires after dispatch | registry empty | ER-006 after dispatch, provider_registry is empty once object 10's approval of A is withdrawn, or at 113 when A's offer has expired, though grant 3 is still current and projected for A |
| grant expires before dispatch | Expired | ER-007 a grant that expires before dispatch: A's grant 12 and its offer {201, 6} both end at 130 (an offer cannot outlive its grant); selected at 110 and current at 120, dispatch at 130 is denied Expired, the grant's currency gate reporting first |
| projected approval bound | N.start at 130 rejected | ER-007 the projected approval ends at 130 (the grant's and offer's end, before approval 145), so N.start at 130 is rejected even on a projection built at 120 (at 129 it advances), and the projection at 130 is empty |
| invocation, manifest, destination, quote | ScopeMismatch | ER-007 a Running session whose request differs in invocation (98), manifest (source 10v5), destination (20v9) or quote (41) denied ScopeMismatch; the same session with the rendezvous request dispatches |
| new request | empty rendezvous; NotSelected | ER-007 a rendezvous opened for the request with invocation 98 has no offers, approvals or evidence, and dispatching A there is denied NotSelected |
| selected offer withdrawn | NotSelected | ER-007 once A withdraws the selected offer {201, 4} before dispatch, dispatch is denied NotSelected, also at the revision before the withdrawal |
| cheaper B after selection | NotSelected; AlreadySelected | ER-007 after A's selection is dispatched, B offers quote 20: dispatching B's offer to B's worker is denied NotSelected and select is denied AlreadySelected |
| A's approvals for B | MissingApproval; NoEligibleOffer | ER-007 after abandon, A's approval does not count for B: B's offer is ineligible MissingApproval and select finds no eligible offer at 114 (A's expired at 113) until 101 approves B |
| A's evidence for B | MissingEvidence; registry empty | ER-007 B reselected as selection 5: A's evidence does not follow (dispatch with A's Running session denied MissingEvidence), and A's dispatch record of selection 3 opens no provider_registry for B |
| A's dispatch record for B | B dispatches | ER-007 with B's own approval and trial, selection 5 dispatches to B's worker session 7 beside A's earlier Dispatch{3, 6}, which does not count as a replay, and provider_registry holds only B's grant 6 |

The ScopeMismatch sessions are SYNTHETIC (a Running session at revision 6 with the other request); its positive control, the same record with the rendezvous request, dispatches. The short-grant dispatch at 130 uses A's trial-world Running session: a Negotiation session carries no rendezvous identity and its request is the rendezvous request, so it reaches the currency gate.

All new checks, in run order:

- ER-007 after N.start on the projected context, A's Running session dispatches selection 3 to A's worker session 6 (profile 1): Dispatch{3, 6} at revision 7, id 3 issued, nothing else changed
- ER-001 provider_registry after dispatch holds exactly grant 3's capability for A, and F.mount, F.open and F.checked_plan resolve it to TF.plan() for caller A
- ER-007 before dispatch provider_registry is empty, though Issuance projects grant 3 for A, so F.mount finds no capability
- ER-001 with A also holding grant 12 (token word 17), the raw registry for A has two capabilities but provider_registry keeps only the selected grant 3's token
- ER-001 dispatch to an unselected provider: A's offer with B's worker session 7, B's offer {202, 5} with B's or A's worker session, or A's unknown offer {201, 9}, denied NotSelected
- ER-001 a worker session of C (3), an unbound session id 9, a session id 6 the identity table holds twice, or A's delegable client session 1, denied NotSelected
- ER-001 A's worker session 4 bound under profile 2, A's non-delegable client session 2 with no worker binding, or a session 6 bound twice, denied WrongProfile
- ER-001 worker_caller_is: no session under id 9, or two sessions under id 6 both with caller A, is not A's worker; the one session 6 is
- ER-001 dispatch_target_selected is false with no selection and true for A's offer on A's worker session 6; with no selection a dispatch at a stale revision is denied NotSelected first
- ER-007 dispatch at revision 5 against 6 denied StaleRevision
- ER-007 a session at Reserved, or a Running session at revision 6 named as 5, denied WrongStage
- ER-007 a second dispatch of selection 3 denied Replay
- ER-005 dispatch with no evidence for selection 3, or with evidence under id 3 naming B's offer or B's claim, denied MissingEvidence
- ER-005 A's same offer {201, 4} reselected as selection 4: retired selection 3's evidence for that offer and provider does not count, so dispatch is denied MissingEvidence
- ER-007 the evidence and dispatch lookups read the whole list: A's evidence for selection 3 behind a record for selection 2 still dispatches, and Dispatch{3, 6} behind a record for selection 2 still denies Replay
- ER-005 A's session sampled under retired selection 3 and advanced to Running on B's projection is denied WrongTrial for B's selection 4; B's own Running session dispatches
- ER-001 while B is selected, B's worker session 5 bound under profile 2 is denied WrongProfile, and A's offer on A's worker session is denied NotSelected
- ER-007 selection racing revocation: once 101 revokes the source approval behind A's grant 3, dispatch is denied Revoked, the projection carries no approvals so N.start is rejected on it (it advances on the earlier one), and the dispatched selection's provider_registry is empty
- ER-007 epoch change between selection and dispatch: once the issuer's live stamp advances to epoch 5, dispatch is denied StaleEpoch and the dispatched selection's provider_registry is empty
- ER-006 after dispatch, provider_registry is empty once object 10's approval of A is withdrawn, or at 113 when A's offer has expired, though grant 3 is still current and projected for A
- ER-007 a grant that expires before dispatch: A's grant 12 and its offer {201, 6} both end at 130 (an offer cannot outlive its grant); selected at 110 and current at 120, dispatch at 130 is denied Expired, the grant's currency gate reporting first
- ER-007 the projected approval ends at 130 (the grant's and offer's end, before approval 145), so N.start at 130 is rejected even on a projection built at 120 (at 129 it advances), and the projection at 130 is empty
- ER-007 a Running session whose request differs in invocation (98), manifest (source 10v5), destination (20v9) or quote (41) denied ScopeMismatch; the same session with the rendezvous request dispatches
- ER-007 a rendezvous opened for the request with invocation 98 has no offers, approvals or evidence, and dispatching A there is denied NotSelected
- ER-007 once A withdraws the selected offer {201, 4} before dispatch, dispatch is denied NotSelected, also at the revision before the withdrawal
- ER-007 after A's selection is dispatched, B offers quote 20: dispatching B's offer to B's worker is denied NotSelected and select is denied AlreadySelected
- ER-007 after abandon, A's approval does not count for B: B's offer is ineligible MissingApproval and select finds no eligible offer at 114 (A's expired at 113) until 101 approves B
- ER-007 B reselected as selection 5: A's evidence does not follow (dispatch with A's Running session denied MissingEvidence), and A's dispatch record of selection 3 opens no provider_registry for B
- ER-007 with B's own approval and trial, selection 5 dispatches to B's worker session 7 beside A's earlier Dispatch{3, 6}, which does not count as a replay, and provider_registry holds only B's grant 6

## Removal map (mutation pass)

The full table is in `task-5-mutants.md`. Scratch: the session scratchpad's `executor-rendezvous-t5/` (`mutants.py`, `run.py`, `mutants.txt`; the mutated copy in `mutant/`); the worktree was never mutated. Final sweep: 43 mutants, 41 killed, 2 equivalent with written arguments:
- G5: the NoSelection arm of `run_gates` is unreachable after `current_gates`.
- P5: `selection_dispatched`'s NoSelection arm is never read, because `selection_current` is False first.

Coverage: each of the four target gates with True substituted; each arm of `worker_caller_is` and `binding_names`; the NoSelection arm of `target_gates`; the outer match (bypassed, wrong state, fixed reason); each inner gate; the currency splice; the reasons of the binding and trial gates and the order of the evidence and trial gates; each conjunct and the recursion of `evidence_for` and `dispatch_recorded`; every field of the commit (worker, selection id, revision, issued id, earlier records); and the registry's currency and dispatch conjuncts, its False arm, the token filter, its recursion and its keep arm.

The first sweep left T6, T8 and E1 alive. T6 and T8 are masked at the entry point by the non-delegable gate; they are killed by the direct `worker_caller_is` check. E1 is killed by the reselected-same-offer check.

## The law

`rendezvous_unselected_dispatch_rejects` (LAWS.bend, rationale comment above it; listed in the module header's Laws paragraph). Statement: for every state, expected revision, offer identity, `HostPrimitives.State` host, worker session, Negotiation session, expected session revision, Negotiation context and snapshot, given `{Rendezvous.dispatch_target_selected(state, offer, host, worker_session) == False{}}`, the pair (`Change.accepted`, `Change.state`) of `dispatch(...)` equals `(False{}, state)`.

Rationale (ER-001, ER-007): no dispatch can be recorded for a provider, offer or worker session that is not the current selection's, whatever its approvals, evidence or price. That covers a cheaper candidate substituted after selection and an unselected provider, and the attempt records nothing and advances no revision.

What the proof covers: `dispatch` unfolds to `dispatch_by(dispatch_target_selected(...), ...)`. The proof rewrites that scrutinee to False with the hypothesis, reversed, which selects `Rejected{state, reason}`; so it pins the outer match and that its Rejected branch carries the caller's state, whatever the reason. Mutants O1 (the match bypassed) and O2 (the False arm returns another state) make PROOF.bend fail.

What it does not cover: that an accepted dispatch is correct (currency, evidence, trial binding and replay are inner gates, covered by the tests), the denial reason, that the target gates are the right ones (T1 to T4 weaken the hypothesis, so the proof still checks and the tests kill them), and that the host executes only recorded dispatches. It is not a trivial law: it names a transition and becomes false if the outer match is removed or its False branch commits.

## Verification

- `bend Rendezvous.bend --check-only`: `ALL PROOFS CHECK` / `Use --verdict for mathematical validity.`
- `bend RendezvousTests.bend`: last line `Rendezvous: 183 checks passed` (154 plus 29 new), 183 PASS lines.
- `bend Tests.bend`: last line `ALL LIBRARY TESTS PASSED`; 1611 PASS lines (`PASS:` and `PASS ` together), 0 FAIL. That is 1582 plus 29 new, and 1428 at master 78449c9 plus 183 Rendezvous checks. The count is the one this tree prints; no count pin or shared capture was touched.
- `bend PROOF.bend`: last lines `ALL PROOFS CHECK` / `Use --verdict for mathematical validity.` LAWS.bend has 24 laws: the 23 before this task plus `rendezvous_unselected_dispatch_rejects`. `--verdict` was not run.
- `git diff HEAD -- LAWS.bend PROOF.bend`: 32 and 9 added lines, 0 removed.
- `Tests.bend` is unchanged in this task.

## Concerns

1. **Profile gate placement (ruling above).** WrongProfile is reported by the outer target match, so it precedes StaleRevision instead of following MissingEvidence as the brief's inner list orders it. The reviewer should confirm the single placement.
2. **Host state trust.** `dispatch` reads the supplied `HP.State` as the monitor's current one. It does not check `HP.valid` or a host revision, matching the brief's signature (no expected host revision). A stale host state (a session id rebound after a restart, or a binding changed) is a host obligation, stated in the header; the twin-session and twin-binding states are denied anyway.
3. **The registry is per selection, not per worker.** `provider_registry` does not name the dispatched worker session. Binding the opened handle to the recorded worker session (through `HostPrimitives.issue` on that session) is the monitor's step; Bend does not tie them. The header states that the handle must be opened from this projection; the recorded `Dispatch{selection, worker_session}` names the session.
4. **Issued entries are not retired here.** An identity entry the monitor already issued from the registry is not retired when the registry empties; HostPublication's revocation family does that, and Frontend uses against the rebuilt registry are denied. Stated in the header.
5. **Synthetic sessions.** The ScopeMismatch cases use SYNTHETIC Running sessions (the other request cannot be negotiated through this rendezvous's projection), each with a positive control; the expiry case reuses A's trial-world Running session. Both are named in the fixture comments.
6. **Mutation scratch location.** As in Tasks 3 and 4, the session scratchpad (`executor-rendezvous-t5/`) instead of the plan's `../writ-build/executor-rendezvous/mutant/`, per the dispatch.

## Fix round 1 (review task-5-review.md: S1 to S5)

Spec compliance was approved, and the profile-gate placement ruling was accepted. All five findings are addressed. `HostPrimitives.bend`, `HostIdentity.bend`, `Frontend.bend`, `Issuance.bend`, `Negotiation.bend`, `Transfer.bend` and `Tests.bend` are still unchanged.

- **S1, host currency (ruled).** `dispatch` now takes `expected_host_revision` directly after `host`, and threads it through `dispatch_by`, `dispatch_checked`, `dispatch_checks` and `dispatch_gates`. `dispatch_gates` gains `Gate{HP.current(host, expected_host_revision), StaleRevision{}}` as its second gate, after the rendezvous revision. `HP.current` is revision equality plus `HP.valid` (which includes `HostIdentity.valid`). The target match stays outermost.
  - The law and proof gain `for expected_host_revision: Nat` and pass it through; the statement and proof term are otherwise unchanged. The law comment now says the hypothesis is read on the supplied host state, whose currency is an inner gate. The law was added in this task; `git diff 78449c9 -- LAWS.bend PROOF.bend` is still additions only.
  - The header's trusted-input entry, the Dispatch paragraph, the `dispatch` doc and its denial order (NotSelected, WrongProfile, StaleRevision for the rendezvous then the host, ...) say this. They also say that a valid, current table whose native-session mapping the adapter kept across a restart is still HostIdentity's restart obligation.
  - New checks: "ER-007 the host state at revision 7 named as 6 or 8 denied StaleRevision" and "ER-007 a host state that is not HP.valid at its own revision (sessions of incarnation 57 under incarnation 58, or bindings to unconfigured profiles) denied StaleRevision; the twin-session and twin-binding hosts are not valid either". These are the reviewer's PROBE1 and PROBE2 (SYNTHETIC `restarted_host`, `unconfigured_host`) and PROBE3. The happy dispatch now passes `HP.revision(host())`. Mutants H1 (gate True), H2 (expected host revision ignored) and H3 (revision only, no `HP.valid`) are killed.
- **S2, profile source.** New check: "ER-001 the binding is compared with the selected offer's profile: with A's profile-2 offer {201, 2} selected, A's worker session 4 (profile 2) is its target and session 6 (profile 1) is not, WrongProfile". It uses Task 3's `p2_state()` (constraint {1, 2}, `offer_a2_p2_35`). The reviewer's X3 (binding compared with a fixed profile 1) is killed.
- **S3, incarnation.** `Dispatch` is now `Dispatch{selection, incarnation, worker_session}`. `commit_dispatch` records `HI.incarnation(HP.identity(host))`, which the host gate has just validated. The type comment and header say that the session id names a session only within that incarnation, and a record from another incarnation names no current session. The happy check now expects `Dispatch{3, 57, 6}`; the substitution check expects `Dispatch{5, 57, 7}` beside `Dispatch{3, 57, 6}`. Mutant I1 (incarnation recorded as 0) is killed.
- **S4, caller token.** `run_gates` now starts with `worker_token_is(worker_lookup(host, worker_session), grant_for(issuer, offer's grant))`, reason NotSelected, through `grant_token_is`. It is placed after the currency gates, so the outer match stays snapshot-free.
  - New check: "ER-001 A's worker session 8 authenticated under another token (word 3) is A's subject at profile 1 but not grant 3's holder: denied NotSelected; A's session 6 on the same host dispatches" (the reviewer's PROBE5, on a valid host built through `open_session`). Mutants K1 (gate True) and K2 (comparison True) are killed.
  - This gate masked the target caller gate (T2, T7), because B's sessions carry B's token. New check: "ER-001 a worker session 8 presenting grant 3's token under B's subject 202 is not A's worker: dispatch_target_selected is false and dispatch is denied NotSelected". It kills both again.
  - K3 (`grant_token_is` None arm True) and K4 (`worker_token_is` other arms True) are equivalent. The target gates already require exactly one session (`worker_caller_is`), and `current_gates` requires an unambiguous grant under the offer's grant id (eligibility's BelongsTo), so neither arm is reached.
- **S5, check name.** Renamed to "ER-007 a grant that expires before dispatch: A's grant 12 and its offer {201, 6} both end at 130 (an offer cannot outlive its grant); selected at 110 and current at 120, dispatch at 130 is denied Expired, the grant's currency gate reporting first", here and in the table above.

Concern 2 (host state trust) is resolved for revision and validity. The remaining residual is the restart mapping obligation above.

Mutation pass, rerun in full in `executor-rendezvous-t5/`: 53 mutants, 49 killed, 4 equivalent (G5, P5, K3, K4). The full sweep first left T2 and T7 alive (masked by the new token gate), and the subject-swap check kills both. Patterns for G1, G3, G4, G5 and C1 to C5 were re-anchored to the new code. The table is extended in `task-5-mutants.md`.

Verification:
- `bend Rendezvous.bend --check-only`: `ALL PROOFS CHECK`.
- `bend RendezvousTests.bend`: `Rendezvous: 188 checks passed` (183 plus 5 new).
- `bend Tests.bend`: last line `ALL LIBRARY TESTS PASSED`; 1616 PASS (`PASS:` and `PASS ` together), 0 FAIL. That is 1428 at 78449c9 plus 188.
- `bend PROOF.bend`: `ALL PROOFS CHECK` / `Use --verdict for mathematical validity.` 24 laws. `--verdict` was not run.
