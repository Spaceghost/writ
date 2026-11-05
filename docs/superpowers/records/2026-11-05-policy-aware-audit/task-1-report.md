# Task 1 report: allowlisted event projection and the two wrappers

Status: DONE_WITH_CONCERNS (concerns at the end: two renames forced by the
language, one law restated because the brief's literal form is false, and
four extra import lines in LAWS.bend).

Implements AU-001 "Minimal scoped event records" (scenarios "Error includes
protected content" and "Committed operation is recorded") and the model part
of AU-005 ("Denial is recorded successfully"). No box in `tasks.md` is
checked (1.1 is checked after Task 2).

## Files

- New: `AuditEvent.bend`, `AuditTests.bend`.
- Extended: `Tests.bend` (one import after the Issuance import, one
  `Audit.main()` after `Issuance.main()`; 2 added lines, nothing else),
  `LAWS.bend` and `PROOF.bend` (additions only, appended after
  `publication_refused_emits_nothing`).
- Records: this report, `activity.log`.
- Mutants and captures (outside the tree):
  `../writ-build/policy-aware-audit/mutants/task-1/<id>/`,
  `../writ-build/policy-aware-audit/mutants/task-1.tsv`, `tests.txt`,
  `audit.txt`, `proof.txt` in `../writ-build/policy-aware-audit/`.

## The record and helpers (`AuditEvent.bend`)

Types:
- `EventRecord{version, kind, event_id, subject, phase, invocation, sources,
  destination, stamp, code, op, artifact, outcome}`: the allowlisted event.
  It is the plan's `Event`, renamed (see concerns).
- `EventKind` (`AdmissionAdmitted | AdmissionDenied | CommitAccepted |
  CommitRejected`): the plan's `Kind`, renamed.
- `Phase` (`Admission | Commit`).
- `Outcome` (`Admitted | DeniedFor{reason} | Committed | NotCommitted`).
- `Diagnostic{payload, error_text, credential, token}`: raw failure
  material, taken as a parameter and never read.
- `ObjectLabel` / `Labels`: the monitor-owned label table, typed now so
  `labels` has a type; Task 3 consumes it.
- `AuditedAdmission{decision, event}`, `AuditedCommit{result, event}`.
- Accessors for every field of each record.

Helpers, each with its purpose:
- `event_format_version()`: named format version 1 (pinned by a test).
- `outcome_of_decision`, `outcome_of_commit`: the only places an outcome is
  derived. Each matches on the library value and copies the reason
  (admission) or nothing (commit). They evaluate no check.
- `artifact_of_commit`: the sealed artifact read from the committed
  WriteIntent, or `None` on rejection. `no_artifact()` gives the admission
  value (`None`).
- `kind_of(outcome)`, `phase_of(kind)`: kind is a function of the outcome,
  and phase a function of the kind, so neither can disagree with the outcome.
- `caller_subject(caller)`: the authenticated subject. The token is never
  read.
- `project(plan, subject, outcome, artifact, event_id)`: the single record
  constructor. The plan's output type is dropped, not allowlisted.
- `admission_event(plan, decision, caller, event_id)`: scope from `plan`,
  subject from `caller_subject`, outcome from `outcome_of_decision`.
- `commit_event(session, ref, result, event_id)`: scope from
  `N.Session.plan(session)`, subject from `OS.subject(ref)`, outcome and
  artifact from the result.
- Tags and equality: `kind_tag`, `phase_tag`, `denial_tag`, `outcome_tag`,
  `EventKind.equal`, `Phase.equal`, `denial_equal`, `Outcome.equal`,
  `artifact_equal`, `EventRecord.equal` (field by field over all 13
  fields).

The module header covers four points. The event is a projection of one
library decision, never a second decision. The trusted inputs are
`event_id`, `labels`, both contexts, and the frontend-authenticated subject.
Constructing an audit record authenticates nothing. The wrappers add no
release route and no declassification. The header also lists the public
entry points (`audited_admit`, `audited_commit`, the accessors,
`EventRecord.equal`) and says that every other def is an implementation
helper that performs none of the library's checks. Its Laws paragraph
covers the four laws.

## The wrappers, and why they cannot alter the result

- `audited_admit(plan, context, labels, caller, diagnostic, event_id)` binds
  `+decision = T.admit(plan, context)` once and returns
  `AuditedAdmission{decision, admission_event(plan, decision, caller, event_id)}`.
- `audited_commit(session, expected_session, expected_ledger, ledger,
  candidate, ref, expected_frontend, context, labels, diagnostic, event_id)`
  binds `+result = OS.commit_from_capability(...)` with exactly the facade's
  eight arguments and returns `AuditedCommit{result, commit_event(session,
  ref, result, event_id)}`.

These guarantees are structural:
1. The returned field is the variable bound to the single library call.
2. The projections consume that value and return only `Outcome`,
   `Maybe<ArtifactId>` or `EventRecord`. None of these holds a Decision,
   CommitResult, session or ledger, so nothing computed while projecting can
   flow back.
3. No def constructs a `T.Decision` or `B.CommitResult`. Those constructors
   occur only as match patterns (`grep -nE "T\.(Denied|Admitted)\{|B\.(Committed|Rejected)\{" AuditEvent.bend`
   gives lines 208, 210, 217, 219, 226 and 228, all `case` lines).
4. `audit_admit_returns_library_decision` and
   `audit_commit_returns_library_result` prove the equality for all inputs.

Grep acceptance (the event = projection rule):
- `grep -c "T.admit(" AuditEvent.bend` is 1.
- `grep -c "commit_from_capability(" AuditEvent.bend` is 1.
- `Backplane.commit` and `B.commit(` do not occur.

## Excluded fields and the checks that pin them

The type is the allowlist: `EventRecord` has no field that can hold any of
these. Each exclusion is also pinned by a test and, where the input is
quantified, by a law:

| Excluded input | Test check(s) | Law |
|---|---|---|
| diagnostic payload | "AU-001 error includes protected content: admitted event equals the one with an empty diagnostic and another caller token" (and the denied and committed variants); "AU-001 no payload, error-text, credential or caller-token sentinel occurs in an admission event"; "AU-001 no diagnostic or Ref-token sentinel occurs in a commit event, accepted or rejected" | both `*_ignores_diagnostic` |
| diagnostic error text | same as payload | both |
| diagnostic credential | same as payload | both |
| diagnostic token | same as payload | both |
| frontend caller token (admission) | "...admitted event equals the one with an empty diagnostic and another caller token"; sentinel-absence check; "AU-001 the capability token words are absent from admission and commit events" | `audit_admission_event_ignores_diagnostic` |
| Ref caller token (commit) | "AU-001 no diagnostic or Ref-token sentinel occurs in a commit event, accepted or rejected"; capability-token absence check | `audit_commit_event_ignores_diagnostic` |
| payment receipt | "AU-001 the payment receipt number of an admitted transfer is absent from its event" (receipt 3141 in an otherwise identical `TF.context()`) | none (context is not varied by the laws) |
| grant scope (read domain 5, write domain 6, quote 42, expiry 200) | "AU-001 grant scope domains, quote and expiry are absent from the event" | none |
| plan output type | dropped in `project` (no field exists to hold it) | none |
| commit rejection reason | none exists; `Backplane.Rejected` exposes none, and the event carries `NotCommitted{}` | `audit_commit_returns_library_result` |

The sentinels are `0xA0D17001` to `0xA0D17008`, written in decimal
(2698080257 to 2698080264) because Bend has no hex literal.

## Tests (`AuditTests.bend`, section `event_projection`): 49 checks

The header marks every log, grant, sink, label table and principal as
SYNTHETIC MONITOR STATE. Every event comes from a wrapper. Fixtures are
reused by import (`TF`, `BF`, `NF`, `FacadeTests`).

The defs are `protected_content` (9), `committed_recorded` (11),
`field_changes` (5), `denials_first` (5), `denials_second` (5),
`admitted_recorded` (2), `denial_recorded` (2), `equality_scope` (5),
`equality_outcome` (3) and `equality_helpers` (2). Coverage:
- "Error includes protected content": sentinel diagnostic plus sentinel
  caller token versus an empty diagnostic plus another token, through
  `EventRecord.equal`. This is checked for an admitted event, a denied event
  and a committed event.
  - The test-side `event_words` flattening contains no sentinel, for
    admission and for commit, accepted or rejected.
  - A Ref carrying the sentinel token is rejected by the facade and recorded
    as `CommitRejected`.
  - The receipt, the grant-scope words and the `FacadeTests.token()` words
    are absent.
- "Committed operation is recorded":
  - The result equals `FacadeTests.run(context(), 7, 2)` and is accepted.
  - The kind is `CommitAccepted`, the phase `Commit` and the outcome
    `Committed`.
  - The event records invocation 99, exactly `TF.source_manifest()`, the
    destination version, a stamp equal to the plan's in all three epochs,
    the code, `Summarize`, `Some{BF.artifact()}` and subject 7.
  - The event id and format version are 1. The artifact follows the binding
    (`BF.other_artifact()`).
  - The commit scope is the session's negotiated plan.
- Second fixtures: changing the source version, the destination version, or
  the graph, policy or authority epoch changes exactly that event field.
- Ten admission denials (Stale, Source, Read, Write, Schema, Operation,
  Origin, Payment, Destination, InvalidPolicy): `TF.denied_as(decision,
  reason)` holds, and the event is `AdmissionDenied`, `DeniedFor{reason}`,
  phase `Admission`, with no artifact. The reason is compared with
  `TF.denial_code`, not with Audit's own tag.
- Admitted: the decision is accepted with the expected ticket, and the event
  is `AdmissionAdmitted` with no artifact.
- "Denial is recorded successfully" covers the revoked capability and subject
  8. In both cases:
  - The event is `CommitRejected` and `NotCommitted`, with no artifact.
  - The result equals the facade's.
  - The ledger equals `NF.held_ledger()` (full test-side equality: revision,
    accounts, holds, seen and committed ids), so the hold is unconsumed.
  - The session equals `NF.running()`.
- Equality separation: `EventRecord.equal` separates event id, subject,
  invocation, sources, destination, each epoch, code, operation kind, two
  denial reasons and the artifact. Each pair differs in one field: all are
  Stale denials against a stale live stamp. `Outcome.equal`,
  `EventKind.equal`, `Phase.equal` and `artifact_equal` separate their
  constructors.

The brief estimated about 30 checks. The 19 extra checks come from the
mutation standard: equality separation and the helper tags.

## Laws (LAWS.bend, PROOF.bend): 17 + 4 = 21

Each law has its rationale in the comment above it in `LAWS.bend` and in
the Laws paragraph of the `AuditEvent.bend` header. Every proof is a
complete `{==}` with no hole, and each has a mutant that breaks it.

1. `audit_admission_event_ignores_diagnostic`. Stated exactly as in the
   brief: for all plan, context, labels, subject, t1/t2, d1/d2 and
   event_id, the events of `audited_admit(..., F.Caller{subject, t1}, d1,
   ...)` and `(..., F.Caller{subject, t2}, d2, ...)` are equal.
   - Rationale: no payload, error text, credential or caller token can
     influence any event field, for every decision including every denial.
   - What the proof covers: both sides reduce to `project` over the same
     stuck `Transfer.admit(plan, context)`, and `caller_subject` reduces on
     the literal caller.
   - Does not claim: storage, durability, append success, correctness of
     the other fields, or that a host calls the wrapper.
   - Breaking mutants: X1 (diagnostic token copied into code) and X2 to X5.
2. `audit_commit_event_ignores_diagnostic`, restated (see concerns): the
   event of `audited_commit(..., F.Ref{F.Caller{subject, t1}, id}, ...,
   diagnostic, event_id)` equals `commit_event(session,
   F.Ref{F.Caller{subject, t2}, id}, DataOS.commit_from_capability(... t1
   ...), event_id)`. This holds for every session, revision, ledger,
   candidate, subject, id, t1/t2, frontend revision, context, labels,
   diagnostic and event_id.
   - Rationale: the diagnostic never influences the event, and the token
     influences it only through the facade's own decision.
   - Does not claim: the same exclusions as law 1.
   - Breaking mutants: X12 (the Ref token copied into code) and X8 to X11
     (diagnostic fields).
3. `audit_admit_returns_library_decision`:
   `AuditedAdmission.decision(audited_admit(...)) == Transfer.admit(plan,
   context)`.
   - Rationale: a denied transfer stays denied with its reason, and
     recording is not a second decision.
   - Breaking mutants: W1 (`Denied{Stale}` on the Denied branch) and W2 (on
     the Admitted branch).
4. `audit_commit_returns_library_result`:
   `AuditedCommit.result(audited_commit(...)) ==
   DataOS.commit_from_capability(...)` with the same arguments.
   - Rationale: a rejected commit keeps the caller's session and ledger, so
     no reservation is consumed by recording (AU-005), and the facade stays
     the only release route.
   - Does not claim: that a denial append succeeds (section 2).
   - Breaking mutants: W3 (Committed turned into Rejected) and W4 (the
     session of a Rejected result advanced).

Laws 3 and 4 are close to restatements of the wrapper, and the brief asks
for them as stated. They are not trivially true in the plan's sense,
because a mutant of the implementation breaks each one (W1 to W4 above,
confirmed by `bend PROOF.bend` failing on that law).

`git diff master -- LAWS.bend PROOF.bend` shows added lines only (0 removed
lines). No existing law or proof is touched.

## Removal map (mutation pass)

Method:
- Each mutant ran in a scratch copy under
  `../writ-build/policy-aware-audit/mutants/task-1/<id>/`, one mutation at a
  time to `AuditEvent.bend`.
- The excluded-field and wrapper mutants use small leak helpers inserted
  above the entry points.
- Each mutant ran `bend AuditTests.bend` and `bend PROOF.bend`. The first
  `FAIL` line is the killing check.

Batches:
- The first batch found 8 survivors: F12, E1, E2, E5, E17, T4, T5 and T6.
  The diagnostic-field mutants X1 to X4 and X8 to X11 did not compile
  (their helper called an accessor defined below it). That was fixed and the
  whole batch was rerun.
- New checks after the first batch:
  - The format version is pinned to 1 (kills F12).
  - "AU-001 EventKind.equal and Phase.equal separate their constructors"
    (kills T4, T5 and T6).
  - "AU-001 artifact_equal separates a missing from a present artifact"
    (kills E17).
- Final batch: 68 mutants, 65 killed by a test (14 of those also by a law),
  3 equivalent, 0 unexplained survivors. This table is from a clean rerun
  (old mutant output deleted, script kept under the lane's own scratch
  directory) that I watched complete, after the controller reported that
  another lane had touched the shared scratchpad and this output directory.

| Id | Mutation | Tests | Proof |
|---|---|---|---|
| O1 | outcome_of_decision Denied arm -> DeniedFor{Stale} | killed: "AU-001 Source denial is returned unchanged and recorded as AdmissionDenied DeniedFor Source" | proofs check |
| O2 | outcome_of_decision Denied arm -> Admitted | killed: "AU-001 Stale denial is returned unchanged and recorded as AdmissionDenied DeniedFor Stale" | proofs check |
| O3 | outcome_of_decision Admitted arm -> DeniedFor{Stale} | killed: "AU-001 an admitted decision is recorded as AdmissionAdmitted with no artifact" | proofs check |
| O4 | outcome_of_commit Committed arm -> NotCommitted | killed: "AU-001 committed operation: kind CommitAccepted, phase Commit, outcome Committed" | proofs check |
| O5 | outcome_of_commit Rejected arm -> Committed | killed: "AU-001 a Ref carrying an unregistered token is rejected by the facade and recorded as CommitRejected" | proofs check |
| A1 | artifact_of_commit Committed arm -> None | killed: "AU-001 committed operation: the sealed artifact from the committed WriteIntent" | proofs check |
| A2 | artifact_of_commit Rejected arm -> Some constant | killed: "AU-005 a commit rejected for a revoked capability is returned unchanged, keeps the hold and session, and is recorded as CommitRejected NotCommitted" | proofs check |
| A3 | no_artifact -> Some constant | killed: "AU-001 Stale denial is returned unchanged and recorded as AdmissionDenied DeniedFor Stale" | proofs check |
| K1 | kind_of Admitted -> AdmissionDenied | killed: "AU-001 an admitted decision is recorded as AdmissionAdmitted with no artifact" | proofs check |
| K2 | kind_of DeniedFor -> AdmissionAdmitted | killed: "AU-001 Stale denial is returned unchanged and recorded as AdmissionDenied DeniedFor Stale" | proofs check |
| K3 | kind_of Committed -> CommitRejected | killed: "AU-001 committed operation: kind CommitAccepted, phase Commit, outcome Committed" | proofs check |
| K4 | kind_of NotCommitted -> CommitAccepted | killed: "AU-001 a Ref carrying an unregistered token is rejected by the facade and recorded as CommitRejected" | proofs check |
| P1 | phase_of AdmissionAdmitted -> Commit | killed: "AU-001 an admitted decision is recorded as AdmissionAdmitted with no artifact" | proofs check |
| P2 | phase_of AdmissionDenied -> Commit | killed: "AU-001 Stale denial is returned unchanged and recorded as AdmissionDenied DeniedFor Stale" | proofs check |
| P3 | phase_of CommitAccepted -> Admission | killed: "AU-001 committed operation: kind CommitAccepted, phase Commit, outcome Committed" | proofs check |
| P4 | phase_of CommitRejected -> Admission | killed: "AU-001 a Ref carrying an unregistered token is rejected by the facade and recorded as CommitRejected" | proofs check |
| F1 | caller_subject -> 0 | killed: "AU-001 an admitted decision is recorded as AdmissionAdmitted with no artifact" | proofs check |
| F2 | commit_event subject -> 0 | killed: "AU-001 committed operation: authenticated subject 7, monitor event id and format version" | proofs check |
| F3 | project event_id -> 0 | killed: "AU-001 committed operation: authenticated subject 7, monitor event id and format version" | proofs check |
| F4 | project invocation -> 0 | killed: "AU-001 committed operation: invocation is the plan's" | proofs check |
| F5 | project sources -> OEnd | killed: "AU-001 committed operation: exact ordered source versions" | proofs check |
| F6 | project destination -> 0/0 | killed: "AU-001 committed operation: exact destination version" | proofs check |
| F7 | project stamp -> drop authority epoch | killed: "AU-001 committed operation: graph, policy and authority epochs are the plan's" | proofs check |
| F8 | project code -> zero | killed: "AU-001 committed operation: code and operation kind" | proofs check |
| F9 | project op -> Copy | killed: "AU-001 committed operation: code and operation kind" | proofs check |
| F10 | project artifact -> None | killed: "AU-001 committed operation: the sealed artifact from the committed WriteIntent" | proofs check |
| F11 | project outcome -> Admitted | killed: "AU-001 a Ref carrying an unregistered token is rejected by the facade and recorded as CommitRejected" | proofs check |
| F12 | event_format_version -> 2 | killed: "AU-001 committed operation: authenticated subject 7, monitor event id and format version" | proofs check |
| X1 | diagnostic.token -> admission code | killed: "AU-001 error includes protected content: admitted event equals the one with an empty diagnostic and another caller token" | fails `audit_admission_event_ignores_diagnostic` |
| X2 | diagnostic.payload -> admission event_id | killed: "AU-001 error includes protected content: admitted event equals the one with an empty diagnostic and another caller token" | fails `audit_admission_event_ignores_diagnostic` |
| X3 | diagnostic.error_text -> admission subject | killed: "AU-001 error includes protected content: admitted event equals the one with an empty diagnostic and another caller token" | fails `audit_admission_event_ignores_diagnostic` |
| X4 | diagnostic.credential -> admission invocation | killed: "AU-001 error includes protected content: admitted event equals the one with an empty diagnostic and another caller token" | fails `audit_admission_event_ignores_diagnostic` |
| X5 | caller token -> admission code | killed: "AU-001 error includes protected content: admitted event equals the one with an empty diagnostic and another caller token" | fails `audit_admission_event_ignores_diagnostic` |
| X6 | payment receipt -> admission event_id | killed: "AU-001 the payment receipt number of an admitted transfer is absent from its event" | proofs check |
| X7 | grant write domain -> admission event_id | killed: "AU-001 grant scope domains, quote and expiry are absent from the event" | proofs check |
| X8 | diagnostic.token -> commit code | killed: "AU-001 error includes protected content: committed event equals the one with an empty diagnostic" | fails `audit_commit_event_ignores_diagnostic` |
| X9 | diagnostic.payload -> commit event_id | killed: "AU-001 error includes protected content: committed event equals the one with an empty diagnostic" | fails `audit_commit_event_ignores_diagnostic` |
| X10 | diagnostic.error_text -> commit subject | killed: "AU-001 error includes protected content: committed event equals the one with an empty diagnostic" | fails `audit_commit_event_ignores_diagnostic` |
| X11 | diagnostic.credential -> commit invocation | killed: "AU-001 error includes protected content: committed event equals the one with an empty diagnostic" | fails `audit_commit_event_ignores_diagnostic` |
| X12 | Ref token -> commit code | killed: "AU-001 no diagnostic or Ref-token sentinel occurs in a commit event, accepted or rejected" | fails `audit_commit_event_ignores_diagnostic` |
| W1 | audited_admit returns Denied{Stale} on the Denied branch | killed: "AU-001 Source denial is returned unchanged and recorded as AdmissionDenied DeniedFor Source" | fails `audit_admit_returns_library_decision` |
| W2 | audited_admit returns Denied{Stale} on the Admitted branch | killed: "AU-001 the payment receipt number of an admitted transfer is absent from its event" | fails `audit_admit_returns_library_decision` |
| W3 | audited_commit turns Committed into Rejected | killed: "AU-001 committed operation: the wrapper returns the facade's accepted result" | fails `audit_commit_returns_library_result` |
| W4 | audited_commit advances the session of a Rejected result | killed: "AU-005 a commit rejected for a revoked capability is returned unchanged, keeps the hold and session, and is recorded as CommitRejected NotCommitted" | fails `audit_commit_returns_library_result` |
| E1 | EventRecord.equal ignores version | survived (equivalent, see below) | proofs check |
| E2 | EventRecord.equal ignores kind | survived (equivalent, see below) | proofs check |
| E3 | EventRecord.equal ignores event_id | killed: "AU-001 EventRecord.equal separates event id and subject" | proofs check |
| E4 | EventRecord.equal ignores subject | killed: "AU-001 EventRecord.equal separates event id and subject" | proofs check |
| E5 | EventRecord.equal ignores phase | survived (equivalent, see below) | proofs check |
| E6 | EventRecord.equal ignores invocation | killed: "AU-001 EventRecord.equal separates invocation, sources and destination" | proofs check |
| E7 | EventRecord.equal ignores sources | killed: "AU-001 EventRecord.equal separates invocation, sources and destination" | proofs check |
| E8 | EventRecord.equal ignores destination | killed: "AU-001 EventRecord.equal separates invocation, sources and destination" | proofs check |
| E9 | EventRecord.equal ignores stamp | killed: "AU-001 EventRecord.equal separates each of the three epochs" | proofs check |
| E10 | EventRecord.equal ignores code | killed: "AU-001 EventRecord.equal separates code and operation kind" | proofs check |
| E11 | EventRecord.equal ignores op | killed: "AU-001 EventRecord.equal separates code and operation kind" | proofs check |
| E12 | EventRecord.equal ignores artifact | killed: "AU-001 EventRecord.equal separates the sealed artifact" | proofs check |
| E13 | EventRecord.equal ignores outcome | killed: "AU-001 EventRecord.equal separates two denial reasons" | proofs check |
| E14 | Outcome.equal DeniedFor arm -> True | killed: "AU-001 EventRecord.equal separates two denial reasons" | proofs check |
| E15 | Outcome.equal other arm -> True | killed: "AU-001 Outcome.equal separates the four outcomes" | proofs check |
| E16 | artifact_equal None/None -> False | killed: "AU-001 error includes protected content: admitted event equals the one with an empty diagnostic and another caller token" | proofs check |
| E17 | artifact_equal mixed -> True | killed: "AU-001 artifact_equal separates a missing from a present artifact" | proofs check |
| E18 | artifact_equal Some/Some -> True | killed: "AU-001 EventRecord.equal separates the sealed artifact" | proofs check |
| T1 | denial_tag Read collides with Write | killed: "AU-001 EventRecord.equal separates two denial reasons" | proofs check |
| T2 | outcome_tag Committed collides with NotCommitted | killed: "AU-001 Outcome.equal separates the four outcomes" | proofs check |
| T3 | outcome_tag Admitted collides with Committed | killed: "AU-001 Outcome.equal separates the four outcomes" | proofs check |
| T4 | kind_tag AdmissionAdmitted collides with AdmissionDenied | killed: "AU-001 EventKind.equal and Phase.equal separate their constructors" | proofs check |
| T5 | kind_tag CommitAccepted collides with CommitRejected | killed: "AU-001 EventKind.equal and Phase.equal separate their constructors" | proofs check |
| T6 | phase_tag Admission collides with Commit | killed: "AU-001 EventKind.equal and Phase.equal separate their constructors" | proofs check |

Equivalent mutants (argument):
- E1: `EventRecord.equal` ignores `version`. Every event any wrapper can
  produce carries `event_format_version()`, so no pair of projected events
  differs in version. Only a hand-written record or a decoded one (Task 2)
  could differ. Task 2's decoder tests are where a different version first
  exists.
- E2: ignores `kind`. `kind = kind_of(outcome)` in `project`, so two
  projected events with equal outcomes have equal kinds. `outcome` is still
  compared (E13 and E14 are killed).
- E5: ignores `phase`. `phase = phase_of(kind)`, the same argument through
  E2.
The tag helpers behind these comparisons are pinned directly (T4 to T6 are
killed), so the comparisons are correct when Task 2 starts comparing decoded
records.

Mutants X6 and X7 (payment receipt and grant write domain copied into the
event) are killed by tests but not by a law. The laws quantify the caller
and the diagnostic, not the context, because the context legitimately
determines the scope fields.

## Commands and last lines

All commands use `export PATH="$HOME/.local/share/writ-toolchains/bend-2.0.39/bend/bin:$PATH"; export BEND_NO_TELEMETRY=1`.

- `bend AuditEvent.bend --check-only` ends `ALL PROOFS CHECK`.
- `bend AuditTests.bend` ends `Audit: 49 checks passed` (49 PASS lines).
- `bend Tests.bend` ends:
  ```
  Property: 324 checks passed; 320 graph cases, each checked against CPU and Bend parallel producers
  ALL LIBRARY TESTS PASSED
  ```
  The PASS total, counting both the `PASS:` and `PASS ` forms
  (`grep -cE "^PASS(:| )"`), was 1428 before this task. This tree prints
  1428 plus 49 new checks = 1477. There are no FAIL lines.
- `bend PROOF.bend` ends:
  ```
  ALL PROOFS CHECK
  Use --verdict for mathematical validity.
  ```
  `LAWS.bend` has 21 laws.
- `--verdict` was not run. The plan schedules one attempt in Task 6. This is
  the JS/interpreter run only, with no native build and no GPU claim.

No count pin was touched. `README.md`, `docs/INSTALL.md`,
`utils/nix/writ.nix`, `.github/workflows/*` and `VERIFICATION.md` are
unchanged.

## Concerns

1. **Two renames forced by Bend.**
   - Base already declares a type `Event` (duplicate declaration), so the
     design's `Event` is `EventRecord`. Its helpers are `EventRecord.equal`
     and the `EventRecord.*` accessors, and the test-side flattening is
     `event_words`.
   - `Kind` is a keyword, so the design's `Kind` is `EventKind`.
   - Later briefs (Tasks 2 to 5) should use these names. Field names and
     constructors are as designed.
2. **`audit_commit_event_ignores_diagnostic` is restated.** The brief asks
   for event equality between two wrapper calls whose Ref tokens differ.
   That statement is false: the facade resolves the capability by that
   token, so `t1` registered and `t2` not gives `CommitAccepted` against
   `CommitRejected` (the check "a Ref carrying an unregistered token is
   rejected by the facade and recorded as CommitRejected" shows this
   concretely). The law instead equates the wrapper's event with
   `commit_event` of the same facade result, built with any other token and
   with no diagnostic. That is the strongest true form. It excludes the
   diagnostic outright and the token as a field, while the token still
   reaches the decision as it must. The rationale in `LAWS.bend` explains
   this. I did not weaken any security law; this is a new law whose
   literal form could not hold. Please confirm the ruling.
3. **`LAWS.bend` has four extra import lines.** The plan says "one import
   line each for the Audit modules". The law statements must name
   `Frontend.Caller` and `Frontend.Ref` (constructors), `Core.Candidate`,
   `DataOS.Context` and `Backplane.CommitResult`, and Bend resolves no name
   through another module's import (probed: `expected : a defined name`).
   So `LAWS.bend` also imports `Core`, `Frontend`, `Backplane` and `DataOS`.
   These are additions only. `PROOF.bend` adds only the AuditEvent import.
4. **`labels` is typed now.** `ObjectLabel` and `Labels` are defined in this
   task, as the shared design gives them, so that the signatures carry a
   real type. They carry no logic until Task 3.
5. **Housekeeping slip, cleaned up.** My first probe and the first,
   interrupted mutation run wrote under
   `/mnt/MediaVolume/Media/src/github.com/spaceghost/writ-build/policy-aware-audit/`
   instead of `writ-lanes/writ-build/`. I removed that directory. The parent
   `spaceghost/writ-build/` was created by that probe, and
   `executor-rendezvous` has since written into it, so I left it alone.
   Nothing touched any worktree.
6. **Shared scratchpad.** The controller reported that the
   executor-rendezvous lane overwrote my mutation script in the shared
   session scratchpad and ran it once, writing to this lane's mutant
   directory. After that I moved the script to `scratchpad/policy-aware-audit/`
   and checked that it still holds my 68 mutants. I then deleted
   `../writ-build/policy-aware-audit/mutants/` and regenerated the whole
   batch. The removal map above comes from that clean run, which I watched
   complete, and it matches the earlier run.
