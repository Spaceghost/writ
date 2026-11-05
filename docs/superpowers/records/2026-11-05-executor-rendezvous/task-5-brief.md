### Task 5: Dispatch, invalidation and the provider registry (task 1.4; ER-007, ER-006 dispatch, ER-001 dispatch)

Implements "ER-007 Scope changes trigger renewed approval" and the dispatch halves of "ER-006 Every origin approves the selected scope" and "ER-001 Provider identity is explicit".

Add the public entry point `dispatch(state, expected_revision, offer: OfferId, host: HP.State, worker_session: Nat, session: N.Session, expected_session, n_context, snapshot)`.
- Its outermost match is `dispatch_target_selected(state, offer, host, worker_session)`, which requires all of: a current selection's offer id equals `offer`; `HI.session_at(HP.identity(host)'s sessions, worker_session)` resolves to one session whose `F.Caller.subject` is the selected provider's id; that session is non-delegable; and `HP.binding_at(HP.bindings(host), worker_session)` names exactly the offer's profile. A failure denies `NotSelected` (or `WrongProfile` for the profile conjunct, reported by the inner gates).
- Plan ruling: the HostIdentity session caller is the authenticated provider identity, the same namespace as `I.Principal.id`, as the Issuance header already states for `F.Caller.subject`.
- Its gates:
  - the revision is current;
  - `N.ready(session, expected_session, N.Running{}, n_context)` (`WrongStage`);
  - the request is unchanged (`ScopeMismatch`);
  - `selection_current`, which re-runs every eligibility gate, so the grant's revocation, expiry and epoch, and the origin approvals, are all re-checked here with their exact reasons;
  - stored evidence for this selection (`MissingEvidence`);
  - the profile binding (`WrongProfile`);
  - not yet dispatched (`Replay`).
- It records `Dispatch{selection, worker_session}`.

Add the public projection `provider_registry(state, snapshot) -> F.Registry`: `I.registry(issuer, provider, now)` filtered to the selected grant's token. It is produced only while the selection is current and dispatched; otherwise it is empty. The header says the monitor must open the worker's input handle (`HostPrimitives.issue`) from this projection, rebuilt per use, and never from the raw issuer registry.

Tests (`dispatch` section):
- Dispatch to the selected provider's worker session after `N.start` on the projected context: accepted. `provider_registry` holds one capability, and `F.mount`/`open`/`checked_plan` resolve it for A.
- Dispatch to an unselected provider: B's worker session, or B's offer id: `NotSelected`. A's offer with B's worker session: `NotSelected`. A worker session bound under another profile: `WrongProfile`. A delegable client session of A: `NotSelected`.
- Cheaper provider substituted after approval: after A's selection, B submits quote 20. Dispatching B is `NotSelected`, and `select` is `AlreadySelected`. After `abandon` and a reselection of B:
  - A's origin approvals do not count for B, so B is ineligible until the origins approve B (`MissingApproval`);
  - A's evidence does not follow (`MissingEvidence`);
  - A's earlier dispatch record does not apply.

  Each step needs new scoped approval.
- Selection racing revocation: after selection, the source approval behind A's grant is revoked. Dispatch gives `Revoked`, `negotiation_context` approvals are empty, `N.start` is rejected, and `provider_registry` is empty.
- A grant that expires before dispatch: A's grant is valid while `now < 130`, selection is at 110 and dispatch at 130: `Expired`. The projected `N.Approval` `valid_until` is ≤ 130, so `N.start` at 130 is rejected too.
- Changes to the operation identity, manifest, destination or billing: a session whose request differs in invocation, manifest, destination or quote gives `ScopeMismatch`. A rendezvous opened for the new request has no offers, approvals or evidence.
- The selected offer is withdrawn by A before dispatch: `NotSelected`.
- A second dispatch: `Replay`. A stale revision: `StaleRevision`. A session not `Running`: `WrongStage`.

Law `rendezvous_unselected_dispatch_rejects`: for every argument, given `{Rendezvous.dispatch_target_selected(state, offer, host, worker_session) == False{}}`, `dispatch` gives `(accepted, state) == (False{}, state)`.
- Rationale (ER-001, ER-007): no dispatch can be recorded for a provider, offer, or worker session that is not the current selection's, whatever its approvals, evidence or price. That covers both a substituted candidate and an unselected provider.
- It does not prove that a selected dispatch is correct, or that the host executes only recorded dispatches.

Estimate about 24 checks. Check box 1.4. Mutation table.

Acceptance: green suite and proofs. `HostPrimitives.bend`, `HostIdentity.bend`, `Frontend.bend` and `Transfer.bend` are untouched (read-only use of exported helpers).

