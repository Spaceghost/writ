import Base
import ./Transfer.bend as T
import ./TransferTests.bend as TF
import ./Negotiation.bend as N
import ./NegotiationTests.bend as NF
import ./Ledger.bend as L
import ./Backplane.bend as B
import ./BackplaneTests.bend as BF
import ./Frontend.bend as F
import ./DataOS.bend as OS
import ./FacadeTests.bend as FT
import ./AuditEvent.bend as AE
import ./Test.bend as Test

# Tests for the policy-aware audit model (change add-policy-aware-audit).
# Every log, grant, sink, label table and principal in this module is
# SYNTHETIC MONITOR STATE built from the shared fixtures (TF, BF, NF,
# FacadeTests), not an authenticated issuer, and every event checked here
# comes from `AE.audited_admit` or `AE.audited_commit`, never from a
# hand-written record. Sections follow the plan's task order:
# - event_projection (Task 1): AU-001 minimal scoped event records and the
#   model part of AU-005 (recording a denial keeps the rejected state).

# --- Sentinels and synthetic inputs ------------------------------------------

# Protected failure material. The eight values appear in no fixture field, so
# finding one in an event means an excluded input reached it. They are
# 0xA0D17001 to 0xA0D17008 in decimal (Bend has no hex literal).
def sentinel_words() -> List<&2, U32>:
  [2698080257, 2698080258, 2698080259, 2698080260,
    2698080261, 2698080262, 2698080263, 2698080264]

def sentinel_token() -> T.CodeId:
  T.CodeId{2698080257, 2698080258, 2698080259, 2698080260,
    2698080261, 2698080262, 2698080263, 2698080264}

# A diagnostic whose payload, error text, credential and token are all the
# sentinels (the spec's "execution error contains source text and a
# capability token").
def sentinel_diagnostic() -> AE.Diagnostic:
  AE.Diagnostic{sentinel_words(), sentinel_words(), sentinel_words(), sentinel_token()}

def empty_diagnostic() -> AE.Diagnostic:
  AE.Diagnostic{[], [], [], T.CodeId{0, 0, 0, 0, 0, 0, 0, 0}}

def event_id() -> Nat:
  41n

def other_event_id() -> Nat:
  42n

def labels() -> AE.Labels:
  AE.NoLabels{}

# A payment receipt number used nowhere else, so its absence is observable.
def receipt_marker() -> Nat:
  3141n

# TF.context() with the same payment witness except for a distinctive receipt.
def receipt_context() -> T.Context:
  TF.single_payment(T.PaymentWitness{receipt_marker(), TF.source_object(), 99n,
    TF.code(), T.Summarize{}, TF.destination_object(), 42n, 200n})

# Grant-scope and payment values in TF.context() that are not plan fields:
# read domain 5, write domain 6, quote 42, grant and witness expiry 200.
def scope_words() -> List<&2, U32>:
  [5, 6, 42, 200]

# --- Wrapper calls -------------------------------------------------------------

def admit_as(plan: T.Plan, context: T.Context, caller: F.Caller,
    diagnostic: AE.Diagnostic, id: Nat) -> AE.AuditedAdmission:
  AE.audited_admit(plan, context, labels(), caller, diagnostic, id)

def admission(plan: T.Plan, context: T.Context) -> AE.AuditedAdmission:
  admit_as(plan, context, FT.caller(7n), empty_diagnostic(), event_id())

def admission_event(plan: T.Plan, context: T.Context) -> AE.EventRecord:
  AE.AuditedAdmission.event(admission(plan, context))

# The FacadeTests.run call, through the wrapper.
def commit_as(context: OS.Context, caller: F.Caller, expected_frontend: Nat,
    diagnostic: AE.Diagnostic) -> AE.AuditedCommit:
  AE.audited_commit(NF.running(), 6n, 1n, NF.held_ledger(), BF.candidate(),
    F.Ref{caller, 2n}, expected_frontend, context, labels(), diagnostic, event_id())

def commit_subject(context: OS.Context, subject: Nat) -> AE.AuditedCommit:
  commit_as(context, FT.caller(subject), 2n, empty_diagnostic())

def accepted_commit() -> AE.AuditedCommit:
  commit_subject(FT.context(), 7n)

def revoked_context() -> OS.Context:
  OS.Context{BF.context(), FT.descriptor(7n, 7), F.EmptyRegistry{}}

# A facade context whose unique binding names another sealed artifact.
def other_artifact_context() -> OS.Context:
  OS.Context{BF.with_binding(BF.context(), BF.with_artifact(BF.binding(), BF.other_artifact())),
    FT.descriptor(7n, 7), FT.registry(7n, 7)}

# NF.running() with its negotiated plan replaced; the facade then rejects it.
def with_session_plan(session: N.Session, plan: T.Plan) -> N.Session:
  match session:
    case N.Session{revision, N.Request{_, reader, quote, units, deadline}, stage, pinned, challenge, receipt}:
      N.Session{revision, N.Request{plan, reader, quote, units, deadline}, stage, pinned, challenge, receipt}

def moved_plan() -> T.Plan:
  T.Plan{TF.stamp(), 99n, T.OCons{T.ObjectVersion{10n, 5n}, T.OEnd{}},
    T.ObjectVersion{20n, 9n}, TF.code(), T.Summarize{}, 2}

def moved_session_commit() -> AE.AuditedCommit:
  AE.audited_commit(with_session_plan(NF.running(), moved_plan()), 6n, 1n, NF.held_ledger(),
    BF.candidate(), F.Ref{FT.caller(7n), 2n}, 2n, FT.context(), labels(), empty_diagnostic(), event_id())

# --- Test-side views (independent of AuditEvent's own tags) -------------------

def kind_code(k: AE.EventKind) -> Nat:
  match k:
    case AE.AdmissionAdmitted{}:
      0n
    case AE.AdmissionDenied{}:
      1n
    case AE.CommitAccepted{}:
      2n
    case AE.CommitRejected{}:
      3n

def phase_code(p: AE.Phase) -> Nat:
  match p:
    case AE.Admission{}:
      0n
    case AE.Commit{}:
      1n

def outcome_code(o: AE.Outcome) -> Nat:
  match o:
    case AE.Admitted{}:
      0n
    case AE.DeniedFor{r}:
      1n
    case AE.Committed{}:
      2n
    case AE.NotCommitted{}:
      3n

def denied_for(o: AE.Outcome, reason: T.Denial) -> Bool:
  match o:
    case AE.DeniedFor{r}:
      U32.is_eq(TF.denial_code(r), TF.denial_code(reason))
    case _:
      False{}

def has_kind(+e: AE.EventRecord, kind: Nat, phase: Nat, outcome: Nat) -> Bool:
  Nat.is_eq(kind_code(AE.EventRecord.kind(e)), kind) &&
    Nat.is_eq(phase_code(AE.EventRecord.phase(e)), phase) &&
    Nat.is_eq(outcome_code(AE.EventRecord.outcome(e)), outcome)

def absent(a: Maybe<&2, B.ArtifactId>) -> Bool:
  match a:
    case None{}:
      True{}
    case Some{x}:
      False{}

def no_artifact(e: AE.EventRecord) -> Bool:
  absent(AE.EventRecord.artifact(e))

def present_as(a: Maybe<&2, B.ArtifactId>, wanted: B.ArtifactId) -> Bool:
  match a:
    case None{}:
      False{}
    case Some{x}:
      B.ArtifactId.equal(x, wanted)

def artifact_is(e: AE.EventRecord, wanted: B.ArtifactId) -> Bool:
  present_as(AE.EventRecord.artifact(e), wanted)

# Test-side flattening of every EventRecord field into words.
def cat(xs: List<&2, U32>, ys: List<&2, U32>) -> List<&2, U32>:
  List.append(&2, U32, xs, ys)

def nat_word(n: Nat) -> List<&2, U32>:
  [U32.from_nat(n)]

def code_words(c: T.CodeId) -> List<&2, U32>:
  match c:
    case T.CodeId{a, b, c, d, e, f, g, h}:
      [a, b, c, d, e, f, g, h]

def version_words(v: T.ObjectVersion) -> List<&2, U32>:
  match v:
    case T.ObjectVersion{o, n}:
      [U32.from_nat(o), U32.from_nat(n)]

def objects_words(xs: T.Objects) -> List<&2, U32>:
  match xs:
    case T.OEnd{}:
      []
    case T.OCons{h, t}:
      cat(version_words(h), objects_words(t))

def stamp_words(s: T.Stamp) -> List<&2, U32>:
  match s:
    case T.Stamp{g, p, a}:
      [U32.from_nat(g), U32.from_nat(p), U32.from_nat(a)]

def artifact_words(a: Maybe<&2, B.ArtifactId>) -> List<&2, U32>:
  match a:
    case None{}:
      [0]
    case Some{B.ArtifactId{c}}:
      1 <> code_words(c)

def outcome_words(o: AE.Outcome) -> List<&2, U32>:
  match o:
    case AE.DeniedFor{r}:
      [1, TF.denial_code(r)]
    case _:
      nat_word(outcome_code(o))

def event_words(e: AE.EventRecord) -> List<&2, U32>:
  match e:
    case AE.EventRecord{v, k, i, s, p, n, x, d, st, c, op, a, o}:
      cat([U32.from_nat(v), U32.from_nat(kind_code(k)), U32.from_nat(i), U32.from_nat(s),
        U32.from_nat(phase_code(p)), U32.from_nat(n)],
        cat(objects_words(x), cat(version_words(d), cat(stamp_words(st),
          cat(code_words(c), T.OpKind.bit(op) <> cat(artifact_words(a), outcome_words(o)))))))

def contains(xs: List<&2, U32>, +w: U32) -> Bool:
  match xs:
    case []:
      False{}
    case h <> t:
      U32.is_eq(h, w) || contains(t, w)

# True when no word of `banned` occurs in `xs`.
def none_of(banned: List<&2, U32>, +xs: List<&2, U32>) -> Bool:
  match banned:
    case []:
      True{}
    case h <> t:
      Bool.not(contains(xs, h)) && none_of(t, xs)

# --- Full-state equality for commit results (test side) -----------------------

def ids_equal(a: L.Ids, b: L.Ids) -> Bool:
  match a b:
    case L.NoIds{} L.NoIds{}:
      True{}
    case L.Id{x, xs} L.Id{y, ys}:
      Nat.is_eq(x, y) && ids_equal(xs, ys)
    case _ _:
      False{}

def accounts_equal(a: L.Accounts, b: L.Accounts) -> Bool:
  match a b:
    case L.NoAccounts{} L.NoAccounts{}:
      True{}
    case L.Accounts{L.Account{p, v}, xs} L.Accounts{L.Account{q, w}, ys}:
      Nat.is_eq(p, q) && Nat.is_eq(v, w) && accounts_equal(xs, ys)
    case _ _:
      False{}

def holds_equal(a: L.Holds, b: L.Holds) -> Bool:
  match a b:
    case L.NoHolds{} L.NoHolds{}:
      True{}
    case L.Holds{L.Hold{r1, i1, p1, u1, v1}, xs} L.Holds{L.Hold{r2, i2, p2, u2, v2}, ys}:
      Nat.is_eq(r1, r2) && Nat.is_eq(i1, i2) && Nat.is_eq(p1, p2) &&
        Nat.is_eq(u1, u2) && Nat.is_eq(v1, v2) && holds_equal(xs, ys)
    case _ _:
      False{}

def ledger_equal(a: L.State, b: L.State) -> Bool:
  match a b:
    case L.State{r1, a1, h1, s1, c1} L.State{r2, a2, h2, s2, c2}:
      Nat.is_eq(r1, r2) && accounts_equal(a1, a2) && holds_equal(h1, h2) &&
        ids_equal(s1, s2) && ids_equal(c1, c2)

def stage_code(s: N.Stage) -> Nat:
  match s:
    case N.Proposed{}:
      0n
    case N.CandidateFixed{}:
      1n
    case N.Challenged{}:
      2n
    case N.Sampled{}:
      3n
    case N.OwnersApproved{}:
      4n
    case N.Reserved{}:
      5n
    case N.Running{}:
      6n
    case N.Committed{}:
      7n

def session_equal(a: N.Session, b: N.Session) -> Bool:
  match a b:
    case N.Session{v1, q1, s1, p1, c1, r1} N.Session{v2, q2, s2, p2, c2, r2}:
      Nat.is_eq(v1, v2) && N.Request.equal(q1, q2) &&
        Nat.is_eq(stage_code(s1), stage_code(s2)) && Nat.is_eq(p1, p2) &&
        Nat.is_eq(c1, c2) && Nat.is_eq(r1, r2)

# Committed results compare session, ledger and the intent's plan and artifact.
def result_equal(a: B.CommitResult, b: B.CommitResult) -> Bool:
  match a b:
    case B.Rejected{s1, l1} B.Rejected{s2, l2}:
      session_equal(s1, s2) && ledger_equal(l1, l2)
    case B.Committed{s1, l1, B.WriteIntent{p1, o1, b1, k1, a1}} B.Committed{s2, l2, B.WriteIntent{p2, o2, b2, k2, a2}}:
      session_equal(s1, s2) && ledger_equal(l1, l2) && T.Plan.equal(p1, p2) &&
        B.ArtifactId.equal(a1, a2)
    case _ _:
      False{}

# --- event_projection: AU-001 "Error includes protected content" --------------

def sentinel_admission() -> AE.EventRecord:
  AE.AuditedAdmission.event(admit_as(TF.plan(), TF.context(), F.Caller{7n, sentinel_token()},
    sentinel_diagnostic(), event_id()))

def clean_admission() -> AE.EventRecord:
  AE.AuditedAdmission.event(admit_as(TF.plan(), TF.context(), FT.caller(7n),
    empty_diagnostic(), event_id()))

def sentinel_denial() -> AE.EventRecord:
  AE.AuditedAdmission.event(admit_as(TF.plan(), TF.with_reads(TF.context(), T.ReadEnd{}),
    F.Caller{7n, sentinel_token()}, sentinel_diagnostic(), event_id()))

def clean_denial() -> AE.EventRecord:
  AE.AuditedAdmission.event(admit_as(TF.plan(), TF.with_reads(TF.context(), T.ReadEnd{}),
    FT.caller(7n), empty_diagnostic(), event_id()))

def sentinel_commit() -> AE.EventRecord:
  AE.AuditedCommit.event(commit_as(FT.context(), FT.caller(7n), 2n, sentinel_diagnostic()))

# The Ref's token itself is the sentinel; the facade rejects it (no capability).
def sentinel_token_commit() -> AE.AuditedCommit:
  commit_as(FT.context(), F.Caller{7n, sentinel_token()}, 2n, sentinel_diagnostic())

def receipt_admission() -> AE.EventRecord:
  admission_event(TF.plan(), receipt_context())

def protected_content() -> IO(Unit):
  do IO<Unit>:
    Test.check(AE.EventRecord.equal(sentinel_admission(), clean_admission()),
      "AU-001 error includes protected content: admitted event equals the one with an empty diagnostic and another caller token")
    Test.check(AE.EventRecord.equal(sentinel_denial(), clean_denial()),
      "AU-001 error includes protected content: denied event equals the one with an empty diagnostic and another caller token")
    Test.check(AE.EventRecord.equal(sentinel_commit(), AE.AuditedCommit.event(accepted_commit())),
      "AU-001 error includes protected content: committed event equals the one with an empty diagnostic")
    Test.check(none_of(sentinel_words(), event_words(sentinel_admission())) &&
      none_of(sentinel_words(), event_words(sentinel_denial())),
      "AU-001 no payload, error-text, credential or caller-token sentinel occurs in an admission event")
    Test.check(none_of(sentinel_words(), event_words(sentinel_commit())) &&
      none_of(sentinel_words(), event_words(AE.AuditedCommit.event(sentinel_token_commit()))),
      "AU-001 no diagnostic or Ref-token sentinel occurs in a commit event, accepted or rejected")
    Test.check(Bool.not(B.accepted(AE.AuditedCommit.result(sentinel_token_commit()))) &&
      has_kind(AE.AuditedCommit.event(sentinel_token_commit()), 3n, 1n, 3n),
      "AU-001 a Ref carrying an unregistered token is rejected by the facade and recorded as CommitRejected")
    Test.check(T.accepted(AE.AuditedAdmission.decision(admit_as(TF.plan(), receipt_context(),
      FT.caller(7n), empty_diagnostic(), event_id()))) &&
      none_of([U32.from_nat(receipt_marker())], event_words(receipt_admission())),
      "AU-001 the payment receipt number of an admitted transfer is absent from its event")
    Test.check(none_of(scope_words(), event_words(receipt_admission())),
      "AU-001 grant scope domains, quote and expiry are absent from the event")
    Test.check(none_of(code_words(FT.token()), event_words(receipt_admission())) &&
      none_of(code_words(FT.token()), event_words(AE.AuditedCommit.event(accepted_commit()))),
      "AU-001 the capability token words are absent from admission and commit events")

# --- event_projection: AU-001 "Committed operation is recorded" ---------------

def committed_event() -> AE.EventRecord:
  AE.AuditedCommit.event(accepted_commit())

def committed_recorded() -> IO(Unit):
  do IO<Unit>:
    Test.check(B.accepted(AE.AuditedCommit.result(accepted_commit())) &&
      result_equal(AE.AuditedCommit.result(accepted_commit()), FT.run(FT.context(), 7n, 2n)),
      "AU-001 committed operation: the wrapper returns the facade's accepted result")
    Test.check(has_kind(committed_event(), 2n, 1n, 2n),
      "AU-001 committed operation: kind CommitAccepted, phase Commit, outcome Committed")
    Test.check(Nat.is_eq(AE.EventRecord.invocation(committed_event()), T.Plan.invocation(TF.plan())),
      "AU-001 committed operation: invocation is the plan's")
    Test.check(T.Objects.equal(AE.EventRecord.sources(committed_event()), TF.source_manifest()),
      "AU-001 committed operation: exact ordered source versions")
    Test.check(T.ObjectVersion.equal(AE.EventRecord.destination(committed_event()), TF.destination_object()),
      "AU-001 committed operation: exact destination version")
    Test.check(T.Stamp.equal(AE.EventRecord.stamp(committed_event()), T.Plan.stamp(TF.plan())),
      "AU-001 committed operation: graph, policy and authority epochs are the plan's")
    Test.check(T.CodeId.equal(AE.EventRecord.code(committed_event()), TF.code()) &&
      T.OpKind.equal(AE.EventRecord.op(committed_event()), T.Summarize{}),
      "AU-001 committed operation: code and operation kind")
    Test.check(artifact_is(committed_event(), BF.artifact()),
      "AU-001 committed operation: the sealed artifact from the committed WriteIntent")
    Test.check(Nat.is_eq(AE.EventRecord.subject(committed_event()), 7n) &&
      Nat.is_eq(AE.EventRecord.event_id(committed_event()), event_id()) &&
      Nat.is_eq(AE.EventRecord.version(committed_event()), AE.event_format_version()) &&
      Nat.is_eq(AE.event_format_version(), 1n),
      "AU-001 committed operation: authenticated subject 7, monitor event id and format version")
    Test.check(artifact_is(AE.AuditedCommit.event(commit_subject(other_artifact_context(), 7n)), BF.other_artifact()),
      "AU-001 committed operation: the artifact follows the binding, not a constant")
    Test.check(Bool.not(B.accepted(AE.AuditedCommit.result(moved_session_commit()))) &&
      T.ObjectVersion.equal(AE.EventRecord.destination(AE.AuditedCommit.event(moved_session_commit())), T.ObjectVersion{20n, 9n}) &&
      T.Objects.equal(AE.EventRecord.sources(AE.AuditedCommit.event(moved_session_commit())), T.Plan.sources(moved_plan())),
      "AU-001 commit scope is the session's negotiated plan")

# Second fixtures: one field of the plan changed at a time.
def source_moved() -> T.Plan:
  T.Plan{TF.stamp(), 99n, T.OCons{T.ObjectVersion{10n, 5n}, T.OEnd{}},
    TF.destination_object(), TF.code(), T.Summarize{}, 2}

def with_stamp(s: T.Stamp) -> T.Plan:
  T.Plan{s, 99n, TF.source_manifest(), TF.destination_object(), TF.code(), T.Summarize{}, 2}

def stamp_moved(+s: T.Stamp) -> Bool:
  +e = admission_event(with_stamp(s), TF.context())
  T.Stamp.equal(AE.EventRecord.stamp(e), s) &&
    Bool.not(T.Stamp.equal(AE.EventRecord.stamp(e), TF.stamp()))

def field_changes() -> IO(Unit):
  +moved = admission_event(source_moved(), TF.context())
  +dest = admission_event(TF.plan_destination(TF.plan(), T.ObjectVersion{20n, 9n}), TF.context())
  do IO<Unit>:
    Test.check(T.Objects.equal(AE.EventRecord.sources(moved), T.Plan.sources(source_moved())) &&
      Bool.not(T.Objects.equal(AE.EventRecord.sources(moved), TF.source_manifest())),
      "AU-001 a changed source version changes the event's sources")
    Test.check(T.ObjectVersion.equal(AE.EventRecord.destination(dest), T.ObjectVersion{20n, 9n}) &&
      Bool.not(T.ObjectVersion.equal(AE.EventRecord.destination(dest), TF.destination_object())),
      "AU-001 a changed destination version changes the event's destination")
    Test.check(stamp_moved(T.Stamp{2n, 2n, 3n}), "AU-001 a changed graph epoch changes the event's stamp")
    Test.check(stamp_moved(T.Stamp{1n, 3n, 3n}), "AU-001 a changed policy epoch changes the event's stamp")
    Test.check(stamp_moved(T.Stamp{1n, 2n, 4n}), "AU-001 a changed authority epoch changes the event's stamp")

# --- event_projection: admission outcomes -------------------------------------

def origin_denied() -> T.Context:
  TF.with_origin(TF.context(), T.RCons{T.OriginRule{TF.source_object(),
    T.Bits64{1, 0}, T.Bits64{2, 0}, 7, T.CEnd{}, T.Free{}}, T.REnd{}}, 7)

def operation_denied() -> T.Context:
  TF.with_operation(TF.context(),
    T.ApprovedOperation{TF.other_code(), T.Summarize{}, 2n, T.TCons{1, T.TEnd{}}, 2})

# The wrapper's decision is the library's denial and its event records it.
def recorded_denial(context: T.Context, +reason: T.Denial) -> Bool:
  +audited = admission(TF.plan(), context)
  +e = AE.AuditedAdmission.event(audited)
  TF.denied_as(AE.AuditedAdmission.decision(audited), reason) &&
    has_kind(e, 1n, 0n, 1n) && denied_for(AE.EventRecord.outcome(e), reason) && no_artifact(e)

def denials_first() -> IO(Unit):
  do IO<Unit>:
    Test.check(recorded_denial(TF.with_live(TF.context(), T.Stamp{2n, 2n, 3n}), T.Stale{}),
      "AU-001 Stale denial is returned unchanged and recorded as AdmissionDenied DeniedFor Stale")
    Test.check(recorded_denial(TF.with_sources(TF.context(), T.SEnd{}), T.Source{}),
      "AU-001 Source denial is returned unchanged and recorded as AdmissionDenied DeniedFor Source")
    Test.check(recorded_denial(TF.with_reads(TF.context(), T.ReadEnd{}), T.Read{}),
      "AU-001 Read denial is returned unchanged and recorded as AdmissionDenied DeniedFor Read")
    Test.check(recorded_denial(TF.with_writes(TF.context(), T.WriteEnd{}), T.Write{}),
      "AU-001 Write denial is returned unchanged and recorded as AdmissionDenied DeniedFor Write")
    Test.check(recorded_denial(TF.with_sources(TF.context(), T.SCons{TF.invalid_schema_source(), T.SEnd{}}), T.Schema{}),
      "AU-001 Schema denial is returned unchanged and recorded as AdmissionDenied DeniedFor Schema")

def denials_second() -> IO(Unit):
  do IO<Unit>:
    Test.check(recorded_denial(operation_denied(), T.Operation{}),
      "AU-001 Operation denial is returned unchanged and recorded as AdmissionDenied DeniedFor Operation")
    Test.check(recorded_denial(origin_denied(), T.Origin{}),
      "AU-001 Origin denial is returned unchanged and recorded as AdmissionDenied DeniedFor Origin")
    Test.check(recorded_denial(TF.with_payments(TF.context(), T.PayEnd{}), T.Payment{}),
      "AU-001 Payment denial is returned unchanged and recorded as AdmissionDenied DeniedFor Payment")
    Test.check(recorded_denial(TF.destination_clearance(T.Bits64{0, 0}, T.Bits64{2, 0}, 7), T.Destination{}),
      "AU-001 Destination denial is returned unchanged and recorded as AdmissionDenied DeniedFor Destination")
    Test.check(recorded_denial(TF.with_origin(TF.context(), T.REnd{}, 7), T.InvalidPolicy{}),
      "AU-001 InvalidPolicy denial is returned unchanged and recorded as AdmissionDenied DeniedFor InvalidPolicy")

def admitted_recorded() -> IO(Unit):
  +audited = admission(TF.plan(), TF.context())
  +e = AE.AuditedAdmission.event(audited)
  do IO<Unit>:
    Test.check(T.accepted(AE.AuditedAdmission.decision(audited)) &&
      TF.retained_output(AE.AuditedAdmission.decision(audited), T.Bits64{1, 0}, T.Bits64{2, 0}, 7, TF.source_manifest()),
      "AU-001 an admitted decision is returned with its ticket")
    Test.check(has_kind(e, 0n, 0n, 0n) && no_artifact(e) && Nat.is_eq(AE.EventRecord.subject(e), 7n),
      "AU-001 an admitted decision is recorded as AdmissionAdmitted with no artifact")

# --- event_projection: AU-005 "Denial is recorded successfully" (model part) --

# The facade's rejection is returned unchanged, the hold is unconsumed and
# the session is still the running one; the event records only the rejection.
def recorded_rejection(+context: OS.Context, +subject: Nat) -> Bool:
  +audited = commit_subject(context, subject)
  +result = AE.AuditedCommit.result(audited)
  +e = AE.AuditedCommit.event(audited)
  Bool.not(B.accepted(result)) && result_equal(result, FT.run(context, subject, 2n)) &&
    ledger_equal(B.ledger(result), NF.held_ledger()) && session_equal(B.session(result), NF.running()) &&
    has_kind(e, 3n, 1n, 3n) && no_artifact(e) && Nat.is_eq(AE.EventRecord.subject(e), subject)

def denial_recorded() -> IO(Unit):
  do IO<Unit>:
    Test.check(recorded_rejection(revoked_context(), 7n),
      "AU-005 a commit rejected for a revoked capability is returned unchanged, keeps the hold and session, and is recorded as CommitRejected NotCommitted")
    Test.check(recorded_rejection(FT.context(), 8n),
      "AU-005 a commit rejected for the wrong subject is returned unchanged, keeps the hold and session, and is recorded as CommitRejected NotCommitted")

# --- event_projection: equality separates every varying field -----------------

# All of these are denied Stale first (the live stamp matches no plan), so
# each pair below differs in exactly one event field.
def stale_context() -> T.Context:
  TF.with_live(TF.context(), T.Stamp{9n, 9n, 9n})

def stale_event(plan: T.Plan) -> AE.EventRecord:
  admission_event(plan, stale_context())

def copy_plan() -> T.Plan:
  T.Plan{TF.stamp(), 99n, TF.source_manifest(), TF.destination_object(), TF.code(), T.Copy{}, 2}

def other_code_plan() -> T.Plan:
  T.Plan{TF.stamp(), 99n, TF.source_manifest(), TF.destination_object(), TF.other_code(), T.Summarize{}, 2}

def other_invocation_plan() -> T.Plan:
  T.Plan{TF.stamp(), 100n, TF.source_manifest(), TF.destination_object(), TF.code(), T.Summarize{}, 2}

def differs(a: AE.EventRecord, b: AE.EventRecord) -> Bool:
  Bool.not(AE.EventRecord.equal(a, b))

def equality_scope() -> IO(Unit):
  +base = stale_event(TF.plan())
  do IO<Unit>:
    Test.check(AE.EventRecord.equal(base, stale_event(TF.plan())),
      "AU-001 EventRecord.equal holds for two projections of the same decision")
    Test.check(differs(base, AE.AuditedAdmission.event(admit_as(TF.plan(), stale_context(), FT.caller(7n), empty_diagnostic(), other_event_id()))) &&
      differs(base, AE.AuditedAdmission.event(admit_as(TF.plan(), stale_context(), FT.caller(8n), empty_diagnostic(), event_id()))),
      "AU-001 EventRecord.equal separates event id and subject")
    Test.check(differs(base, stale_event(other_invocation_plan())) && differs(base, stale_event(source_moved())) &&
      differs(base, stale_event(TF.plan_destination(TF.plan(), T.ObjectVersion{20n, 9n}))),
      "AU-001 EventRecord.equal separates invocation, sources and destination")
    Test.check(differs(base, stale_event(with_stamp(T.Stamp{2n, 2n, 3n}))) &&
      differs(base, stale_event(with_stamp(T.Stamp{1n, 3n, 3n}))) &&
      differs(base, stale_event(with_stamp(T.Stamp{1n, 2n, 4n}))),
      "AU-001 EventRecord.equal separates each of the three epochs")
    Test.check(differs(base, stale_event(other_code_plan())) && differs(base, stale_event(copy_plan())),
      "AU-001 EventRecord.equal separates code and operation kind")

def equality_outcome() -> IO(Unit):
  do IO<Unit>:
    Test.check(differs(admission_event(TF.plan(), TF.with_reads(TF.context(), T.ReadEnd{})),
      admission_event(TF.plan(), TF.with_writes(TF.context(), T.WriteEnd{}))),
      "AU-001 EventRecord.equal separates two denial reasons")
    Test.check(differs(committed_event(), AE.AuditedCommit.event(commit_subject(other_artifact_context(), 7n))),
      "AU-001 EventRecord.equal separates the sealed artifact")
    Test.check(Bool.not(AE.Outcome.equal(AE.Admitted{}, AE.DeniedFor{T.Read{}})) &&
      Bool.not(AE.Outcome.equal(AE.Committed{}, AE.NotCommitted{})) &&
      Bool.not(AE.Outcome.equal(AE.Admitted{}, AE.Committed{})) &&
      AE.Outcome.equal(AE.DeniedFor{T.Payment{}}, AE.DeniedFor{T.Payment{}}),
      "AU-001 Outcome.equal separates the four outcomes")

# The exported equality helpers separate the constructors they compare. Kind
# and phase are functions of the outcome in every projected event, so these
# direct checks are what pins their tags.
def equality_helpers() -> IO(Unit):
  do IO<Unit>:
    Test.check(Bool.not(AE.EventKind.equal(AE.AdmissionAdmitted{}, AE.AdmissionDenied{})) &&
      Bool.not(AE.EventKind.equal(AE.CommitAccepted{}, AE.CommitRejected{})) &&
      Bool.not(AE.EventKind.equal(AE.AdmissionDenied{}, AE.CommitAccepted{})) &&
      Bool.not(AE.Phase.equal(AE.Admission{}, AE.Commit{})) &&
      AE.EventKind.equal(AE.CommitRejected{}, AE.CommitRejected{}) && AE.Phase.equal(AE.Commit{}, AE.Commit{}),
      "AU-001 EventKind.equal and Phase.equal separate their constructors")
    Test.check(Bool.not(AE.artifact_equal(None{}, Some{BF.artifact()})) &&
      Bool.not(AE.artifact_equal(Some{BF.artifact()}, None{})) && AE.artifact_equal(None{}, None{}),
      "AU-001 artifact_equal separates a missing from a present artifact")

def event_projection() -> IO(Unit):
  do IO<Unit>:
    protected_content()
    committed_recorded()
    field_changes()
    denials_first()
    denials_second()
    admitted_recorded()
    denial_recorded()
    equality_scope()
    equality_outcome()
    equality_helpers()

def main() -> IO(Unit):
  do IO<Unit>:
    event_projection()
    IO.print("Audit: 49 checks passed")
