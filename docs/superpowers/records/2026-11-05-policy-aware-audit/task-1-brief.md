### Task 1: Allowlisted event projection and the two wrappers (task 1.1, first half; AU-001, AU-005 model part)

Implements "AU-001 Minimal scoped event records" (scenarios "Error includes protected content" and "Committed operation is recorded") and the model part of "AU-005 Denial recording preserves rejected operation state" (scenario "Denial is recorded successfully": the transfer remains denied and the reservation is not consumed by recording).

Create `AuditEvent.bend`, importing `Base`, `Guard`, `Transfer as T`, `Frontend as F`, `Backplane as B`, `Negotiation as N`, `Dlm as D` and `DataOS as OS`. Add:
- the types `Event`, `Kind`, `Phase`, `Outcome` and `Diagnostic`, with accessors;
- `outcome_of_decision(T.Decision) -> Outcome` and `outcome_of_commit(B.CommitResult) -> Outcome`, the only places an outcome is derived. Each matches on the library value and computes nothing else;
- `admission_event(plan, decision, caller: F.Caller, event_id) -> Event`, taking the scope from `plan`, the subject from `caller`'s subject (its token is never read) and the outcome from `decision`;
- `commit_event(session, ref, result, event_id) -> Event`, taking the scope from `N.Session.plan(session)`, the subject from `OS.subject(ref)`, and the artifact from the committed `WriteIntent` (`None` on rejection);
- the public entry point `audited_admit(plan, context, labels, caller, diagnostic, event_id) -> AuditedAdmission{decision, event}`. It binds `decision = T.admit(plan, context)` once and returns it unchanged next to `admission_event(plan, decision, caller, event_id)`. `labels` is unused until Task 3;
- the public entry point `audited_commit(session, expected_session, expected_ledger, ledger, candidate, ref, expected_frontend, context: OS.Context, labels, diagnostic, event_id) -> AuditedCommit{result, event}`. It calls `OS.commit_from_capability` once with exactly the facade's arguments and returns that result unchanged.

Write the module header: the event is a projection of one library decision, never a second decision; the trusted inputs (`event_id`, `labels`, the contexts, the caller's subject as already authenticated by the frontend); that constructing an Audit record authenticates nothing; that the wrappers add no release route; and the public entry points.

Add laws:
- `audit_admission_event_ignores_diagnostic`: for all `plan`, `context`, `labels`, `subject`, tokens `t1`/`t2`, diagnostics `d1`/`d2` and `event_id`, `AuditedAdmission.event(audited_admit(plan, context, labels, F.Caller{subject, t1}, d1, event_id)) == AuditedAdmission.event(audited_admit(plan, context, labels, F.Caller{subject, t2}, d2, event_id))`. Rationale: no payload, error text, credential or caller token can influence any event field, for every decision, including every denial. Mutant to show: copy `diagnostic.token` into `code`.
- `audit_commit_event_ignores_diagnostic`: the same for `audited_commit`, quantified over the Ref's caller token and the diagnostic.
- `audit_admit_returns_library_decision`: `AuditedAdmission.decision(audited_admit(plan, context, labels, caller, diagnostic, event_id)) == T.admit(plan, context)` for all inputs. Rationale: auditing never changes a decision, so a denied transfer stays denied with its reason, and recording is not a second decision. Mutant to show: return `Denied{Stale{}}` on one branch.
- `audit_commit_returns_library_result`: `AuditedCommit.result(audited_commit(...)) == OS.commit_from_capability(...)` with the same arguments. Rationale: a rejected commit keeps the caller's session and ledger, so no reservation is consumed by recording (AU-005), and the only release route is unchanged. Each law states what it does not claim: durability, append success, or that a host calls the wrapper.

Tests (`event_projection` section) in `AuditTests.bend`, registered in `Tests.bend` now (one import, one call):
- "Error includes protected content":
  - A diagnostic whose payload, error text and credential words, and whose `F.Caller` token words, are the sentinels `0xA0D17001` to `0xA0D17008` (values chosen to appear in no fixture field) gives an event equal (`Event.equal`) to the one built with an empty diagnostic and another token.
  - An `Event.words` helper (a test-side flattening of every field) contains no sentinel.
  - The event carries no grant scope, payment receipt or capability token from `TF.context()`. The receipt number and `FacadeTests.token()` words are absent.
- "Committed operation is recorded":
  - `audited_commit` on `FacadeTests.context()` with subject 7 gives `CommitAccepted`, invocation `T.Plan.invocation(TF.plan())`, the exact `TF.source_manifest()` versions, the destination version, a stamp equal to the plan's stamp in all three epochs, the code and kind, `Some{BF.artifact()}`, and subject 7.
  - Changing any one of a source version, the destination version or each of the three epochs in a second fixture changes the corresponding event field.
- Admission denials, one per reachable `T.Denial` using the `TF.with_*` fixtures (`Stale`, `Source`, `Read`, `Write`, `Schema`, `Operation`, `Origin`, `Payment`, `Destination`, `InvalidPolicy`): the wrapper's decision satisfies `TF.denied_as(..., reason)`, and the event is `AdmissionDenied` with `DeniedFor{reason}`.
- Admitted: the decision is accepted, and the event is `AdmissionAdmitted` with no artifact.
- "Denial is recorded successfully": a commit rejected for a revoked frontend capability or a wrong subject (subject 8, as in `FacadeTests`) gives `CommitRejected` and `NotCommitted{}`. The wrapper's result equals the facade's result, its ledger equals `NF.held_ledger()` (the hold is unconsumed), and its session equals `NF.running()`.

Estimate about 30 checks. Laws: the four above. Do not check any box yet (1.1 is checked after Task 2).

Acceptance:
- Suite green at 1428 plus about 30.
- `ALL PROOFS CHECK` with 21 laws (or the recorded exception).
- The `grep` counts in the event = projection rule hold.
- The mutation table shows every outcome arm and every excluded-field mutant killed.

