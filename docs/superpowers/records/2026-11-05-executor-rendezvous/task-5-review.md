# Task 5 review: dispatch, invalidation and the provider registry (87853e0, review package 131a835..87853e0)

Reviewer: task reviewer (security and proofs). Read-only apart from this file. Scratch: session scratchpad `executor-rendezvous-review-t5/`. It holds:
- `tests.out`, `proof.out`: the baseline runs on 87853e0;
- `mine.py`, `run.py`, `mutants.txt`: the reviewer mutant list (six of the implementer's, the two equivalents, and X1 to X4), the runner and its results;
- `probe/`: a copy of the tree with reviewer probes appended to `RendezvousTests.bend` (PROBE0 to PROBE6);
- `x6/`: the eligibility grant-currency mutant, run against the `dispatch` section alone.

## Verdicts

1. Spec compliance: **APPROVED**.
   - `dispatch` matches `dispatch_target_selected` outermost, then runs its gate list in the stated order. The target check is: the stored selection's offer identity; exactly one HostIdentity session under `worker_session` whose caller subject is the selected provider's id; that session non-delegable; exactly one worker binding naming the offer's profile.
   - Each case is denied with its named reason and the state unchanged, through the test-side `denied` (exact `Error.equal` and field-by-field `State.equal`):
     - a substituted cheaper candidate: NotSelected, then AlreadySelected; after abandon, MissingApproval and MissingEvidence;
     - a revoked grant: Revoked;
     - a grant expired before dispatch: Expired;
     - an unselected provider or offer: NotSelected;
     - a wrong-trial session: WrongTrial;
     - a session whose caller is not the selected provider: NotSelected.
   - I reran six mutants on these paths (T1, T2, T7, O1, G4, G7). All six are killed by the named checks. O1 also makes PROOF.bend fail.
   - `provider_registry` is recomputed at every call, with no cache. It is empty with no selection, before dispatch, after a currency failure, and for a reselection that is not yet dispatched. P1, P2 and my X1 and X4 are killed.
   - The law `rendezvous_unselected_dispatch_rejects` is a real statement, and its proof has no hole (see "The law" below).
   - G5 and P5 really are equivalent. I reran both, both survive, and the arguments hold.
   - Results: `bend Tests.bend` gives 1611 PASS, 0 FAIL and `ALL LIBRARY TESTS PASSED`. `bend PROOF.bend` gives `ALL PROOFS CHECK`, with 24 laws. `bend Rendezvous.bend --check-only` gives `ALL PROOFS CHECK`.
   - LAWS.bend (+32) and PROOF.bend (+9) are additions only. Tests.bend is unchanged since Task 1. HostPrimitives, HostIdentity, Frontend, Transfer, Negotiation and Issuance are unchanged since 78449c9.
   - Only touch-list files changed. No count pin moved: the `Rendezvous: 183 checks passed` print is the plan's required exact line. Box 1.4 is checked, citing `RendezvousTests.bend` checks and the law.
   - This verdict measures the brief as written. Its signature passes no host revision, so the missing host gate is reported under verdict 2 (S1).
2. Security and code quality: **NEEDS_FIXES**.
   - The required finding S1 stands, and my probes confirm it: an invalid or unbound host state is accepted.
   - I found no route to a provider other than the one the selection names, provided the host state is current (S1 aside):
     - the registry is keyed on the live selection id (X1 is killed);
     - the caller is read from the host table at call time;
     - the profile is read from the host bindings and the selected offer, never from the request;
     - denials carry no effect;
     - the record names the selection id and a host-validated session id, never a claim.
   - The other findings are smaller: a test gap on the profile source (S2), the restart naming in the record (S3), the session's caller token (S4), and a check name (S5).

Ruling judged, as asked: reporting WrongProfile (and NotSelected) before StaleRevision is **accepted**. Before the revision gate, the target gates read only two things: the stored selection in the caller-supplied rendezvous state, and the caller-supplied host state. The caller is the monitor, which supplied both. None of the following is consulted before the revision gate: the snapshot (issuer, grants, approvals), the evidence, the dispatch records, or the Negotiation session. So the order reveals nothing beyond facts about the caller's own inputs. On a stale rendezvous state the reason may describe that stale state. That is still a denial with the state unchanged, and a retry at the current revision gives the current reason.

## Findings (by severity)

### S1 (Important, security; required by controller ruling): `dispatch` does not gate on the host state's revision or validity

Where:
- `Rendezvous.bend:2343-2346`: `dispatch` takes `host: HP.State` with no expected host revision.
- `Rendezvous.bend:2273-2278`: `dispatch_gates` holds only the rendezvous `revision_current`.
- `Rendezvous.bend:2204-2221`: `target_gates` reads `HP.identity(host)` and `HP.bindings(host)` without checking them.
- `Rendezvous.bend:59-67`: the header says "A stale host state would keep a rebound or restarted session id, which Bend cannot detect." Part of that Bend *can* detect, through `HP.valid`.

Every transition in this repository gates on the state it reads. In HostPrimitives this is `current(state, expected_revision)` = revision equal && `valid`, denied StaleRevision (`HostPrimitives.bend:111-117, 973-974`), and HostPublication reuses that helper. Dispatch is where execution is handed to a provider, and it does not do this.

Probes (`probe/`, run on 87853e0 unchanged; all PASS, so each bad state is accepted):
- PROBE1: the fixture host, with its identity's incarnation set to 58 while every session is still incarnation 57. This is the shape of a session table carried across a restart. `HP.valid` is False, and `dispatch` of selection 3 to session 6 is **accepted**.
- PROBE2: the fixture host with no configured profiles, so the binding names an unconfigured profile. `HP.valid` is False, and `dispatch` is **accepted**.
- PROBE3: the fixture host at revision +99. `dispatch` is **accepted**: nothing ties the decision to the host revision the monitor validated against.
- PROBE4: `twin_session_host()` and `twin_binding_host()` both fail `HP.valid` today. They are denied only because the outer lookups count.

Fix:
1. Add `expected_host_revision: Nat` right after `host` in `dispatch`, `dispatch_by`, `dispatch_checked` and `dispatch_gates`.
2. Add the gate `Gate{HP.current(host, expected_host_revision), StaleRevision{}, ...}` as the second gate of `dispatch_gates`, directly after `revision_current`. The order becomes: target (outer), StaleRevision (rendezvous), StaleRevision (host), WrongStage, and so on. The state is unchanged on denial.
   - `HP.current` is the exported helper HostPublication already reuses. It is revision equality plus `HP.valid`, which includes `HI.valid`.
   - Keep the target match outermost: an invalid host can only make the target gates deny, never accept.
3. Update the law and proof signatures (LAWS.bend, PROOF.bend): add `for expected_host_revision: Nat` and pass it through. The statement and the proof term are otherwise unchanged. The law was added in this task, so this is not a change to an existing law.
4. Tests, each with exact reason and unchanged state:
   - the happy dispatch at `HP.revision(host())`;
   - the host at revision − 1 (or + 1): StaleRevision;
   - the PROBE1 incarnation-mismatched host: StaleRevision;
   - the PROBE2 unconfigured-profile host: StaleRevision.
   - The twin-session and twin-binding entry-point checks keep their NotSelected and WrongProfile reasons, since the outer match runs first. Add one assertion that both are `Bool.not(HP.valid(...))`, so the fixture comment ("as a corrupted host might hold") is checked.
5. Pin the new gate with mutants: the gate → True, and the expected host revision ignored.
6. Header (lines 59-67), the `dispatch` doc and its denial-order sentence: state that the host state must be current at `expected_host_revision` and `HP.valid`, and that an unchanged-but-stale host table (a remapped native session within one valid state) remains the HostIdentity restart obligation.
7. Update report concern 2.

### S2 (Minor, test gap): the profile compared with the binding is not pinned to the selected offer's

Where: `Rendezvous.bend:2212` (`binding_names(..., Offer.profile(selected))`); `RendezvousTests.bend:1877-1879` and the `dispatch_inner` profile check.

My mutant X3 replaces `Offer.profile(selected)` with the fixed profile `1n`, and it **survives** the whole suite. Every dispatched selection in the section (offers `{201, 4}`, `{202, 5}`, `{201, 6}`, `{202, 8}`) is at profile 1, and the trial world's constraint is `{1}`. So the suite cannot tell "the selected offer's profile" from "the only admitted profile" or from a constant. A binding check that read the constraint, or any default, would pass.

Fix: add a direct check, the standard's route for a masked gate. Select A's profile-2 candidate in the two-profile world (`state_a12`/`state_a21` with `approval_a_p2` and `offer_a2_p2`, constraint `{1, 2}`), then:
- `dispatch_target_selected(..., offer {201, 2}, host(), 4n)` is True (A's worker at profile 2);
- with A's worker 6 (profile 1) it is False.

Optionally also check `Gates.reason` of `target_gates` there: WrongProfile.

### S3 (Minor, security naming): the dispatch record's worker session id is not incarnation-qualified

Where: `Rendezvous.bend:329-330` (`Dispatch{selection, worker_session}`) and `commit_dispatch` at `Rendezvous.bend:2287-2293`.

HostIdentity issues session ids from 1 again after `restart` (`HostIdentity.bend:23-29`). So a recorded `Dispatch{3, 6}` can name a different session after a restart, and report concern 3 says the monitor binds the handle to "the recorded worker session". Downstream checks limit the damage:
- `HP.issue` checks the handle owner (subject and token) against the session;
- `provider_registry` does not read the record's session.

Still, the record the monitor acts on is ambiguous across incarnations.

Fix, either:
- record the host incarnation, `Dispatch{selection, incarnation: HI.incarnation(HP.identity(host)), worker_session}`, and have the header say that a record from another incarnation names no session; or
- at minimum, state in the `Dispatch` type comment and the header that the session id is meaningful only within the incarnation current at dispatch.

### S4 (Minor, defense in depth): the worker's caller token is not compared with the selected grant's token

Where: `Rendezvous.bend:2174-2181` (`worker_caller_is` compares `caller_subject` only).

PROBE5: a valid host in which A's non-delegable worker session 8 at profile 1 is authenticated as `F.Caller{201, token_c}`. `dispatch` to session 8 is accepted, and `Dispatch{3, 8}` is recorded.

PROBE6: that caller then gets no plan from `provider_registry`, because Frontend's `find_capability` matches the caller token. So the grant itself is not reachable. But the record names a worker that cannot use the selection's grant, and "exact scope at commit" is enforced only downstream.

Fix:
- add a conjunct `T.CodeId.equal(F.Caller.token, the backing grant's token)`;
- or state in the `worker_caller_is` doc and the header that only the subject is bound here and the token is bound at Frontend use.

The first option needs the snapshot in the target gates. If the outer match is to stay snapshot-free, put the check in `run_gates` with reason NotSelected.

### S5 (Minor, naming): the "grant expires before dispatch" check does not isolate the grant's expiry

Where: `RendezvousTests.bend:1999-2001` and `task-5-report.md` (table and check list).

In the short-grant world the offer `{201, 6}` and grant 12 both end at 130. In `x6/`, eligibility's grant-currency gate (`IsCurrent`) was mutated to True. With the revocation check removed, the `dispatch` section still passes this check, because the offer's own `unexpired` gate also gives Expired at 130.

This cannot be separated: Outlives (`I.lifetime_within`) forces the offer to end no later than its grant, so a grant expiry always coincides with the offer's. The reason is right (the grant gate reports first), and the grant gate itself is pinned by the Task 3 check and by the dispatch revocation check.

Fix: rename the check, for example "... grant 12 and its offer both end at 130 (an offer cannot outlive its grant); dispatch at 130 is denied Expired, the grant's currency gate reporting first". Make the same edit in the report.

### Notes (no change required)

- X2 (the caller compared with the *requested* `OfferId.provider` instead of the selected offer's provider) survives. It is equivalent at the entry point:
  - the offer-identity gate forces the requested id to equal the stored one;
  - `current_gates` re-runs `id_owned_by(id, provider)`, so the two provider ids agree whenever the inner list passes.
  The code reads the stored provider, which is the right source.
- Issued identity entries surviving a registry rebuild (report concern 4) is a stated limitation:
  - HostPrimitives' runtime facts re-resolve the entry through `HI.resolve`, which checks the entry's own expiry but not the Rendezvous selection;
  - retirement is HostPublication's revocation family;
  - publication re-checks through `F.checked_plan` against whatever registry the monitor passes.
  The header states the obligation. A later integration task should test that path with the rebuilt `provider_registry`.
- The registry's per-selection scope, with the worker binding left to the monitor, follows the controller ruling and is stated in the header.
- Fixtures use distinct values: worker ids 6 and 7, profiles 1 and 2, selection ids 2 to 5, distinct quotes. Comments explain authority and edge direction. No new comment line exceeds 100 columns.

## The law

`rendezvous_unselected_dispatch_rejects` (LAWS.bend +32):
- It quantifies over every argument of `dispatch`, with the hypothesis `{dispatch_target_selected(state, offer, host, worker_session) == False{}}`.
- It concludes `(Change.accepted(dispatch(...)), Change.state(dispatch(...))) == (False{}, state)`.

The proof (PROOF.bend +9) is `%Equal.sym(Bool, dispatch_target_selected(...), False{}, unselected) : {... dispatch_by(_, ...) ...}` followed by `{==}`:
- `dispatch` unfolds to `dispatch_by(dispatch_target_selected(...), ...)`. The rewrite replaces the `_`-marked scrutinee with `False{}`. By computation that reduces to `Rejected{state, reason}`, whose accessors give `(False{}, state)`.
- There is no `?` goal, no `?TODO`, and no unsafe definition. It is the same rewrite form as the accepted `rendezvous_wrong_provider_evidence_rejects`.
- It is not trivial. O1 (the match bypassed) makes `bend PROOF.bend` fail, as rerun here, and so does O2 (the False arm returns another state). T1 and T2 weaken only the hypothesis, so they still check, and the tests kill them.
- The rationale is accurate and bounded: it does not claim correctness of an accepted dispatch, the reason, or host execution.
- After S1, the rationale should also say that the hypothesis is evaluated on the supplied host state, whose currency is an inner gate.

## What I verified and ran

- Read: the brief, the report, the mutation table, the review diff, the plan's Global Constraints, the Task 4 review and re-review, the ER-007 spec delta, and the relevant parts of HostPrimitives.bend (`valid`, `current`, `binding_at`, `non_delegable_session`, `open_session`, `issue`), HostIdentity.bend (sessions, restart obligation, `valid`), Issuance.bend (`registry`, the `F.Caller.subject` ruling), Frontend.bend (`Caller`, `mount`), and the Rendezvous offer and eligibility gates.
- `bend Tests.bend` (87853e0, unchanged tree): 1611 `PASS` lines, 0 FAIL, `ALL LIBRARY TESTS PASSED`, and `Rendezvous: 183 checks passed`.
- `bend PROOF.bend`: `ALL PROOFS CHECK` / `Use --verdict for mathematical validity.` LAWS.bend has 24 `law` entries. `--verdict` was not run, so no kernel verdict is claimed.
- `bend Rendezvous.bend --check-only`: `ALL PROOFS CHECK`.
- `git diff --numstat 131a835 87853e0 -- LAWS.bend PROOF.bend Tests.bend`: 32/0, 9/0, and no Tests.bend change. `git diff --stat 78449c9 87853e0` over the read-only modules shows only Task 1's two-line Tests.bend edit.
- Mutants (scratch copy; the worktree was never mutated):

  | Id | Mutation | Result |
  |---|---|---|
  | T1 | offer conjunct → True | killed; PROOF still checks |
  | T2 | caller gate → True | killed; PROOF still checks |
  | T7 | subject compare → True | killed |
  | O1 | outer match bypassed | killed; PROOF fails |
  | G4 | currency splice dropped | killed |
  | G7 | trial gate → True | killed |
  | G5 | `run_gates` NoSelection arm → Open | survives: equivalent, as argued |
  | P5 | `selection_dispatched` NoSelection → True | survives: equivalent, as argued |
  | X1 | registry keyed on stale selection id 3 | killed |
  | X2 | caller compared with the requested OfferId's provider part | survives: equivalent, see Notes |
  | X3 | binding profile compared with fixed profile 1 | **survives**: S2 |
  | X4 | registry ignores currency and dispatch | killed |
  | x6 | eligibility grant `IsCurrent` → True, dispatch section only | killed by the revocation check; with that check removed, the expiry check still passes: S5 |

  A malformed X5 failed to compile and is discarded.
- Probes PROBE0 to PROBE6 (`probe/`): the results are as cited in S1 and S4.
