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
#   It includes the early-denial rule: an admission denied before its write
#   grant bound the plan carries ScopeNotRead and none of the plan's words.

# --- Sentinels and synthetic inputs ------------------------------------------

# Protected failure material, one distinct range per excluded input so a
# failure names the input that leaked. None of these values appears in any
# fixture field. Bend has no hex literal; the decimal values are:
# payload 0xA0D17001-02, error text 0xA0D17003-04, credential 0xA0D17005-06,
# Diagnostic token 0xA0D17101-08, caller (and Ref) token 0xA0D17201-08.
def payload_words() -> List<&2, U32>:
  [2698080257, 2698080258]

def error_text_words() -> List<&2, U32>:
  [2698080259, 2698080260]

def credential_words() -> List<&2, U32>:
  [2698080261, 2698080262]

def diagnostic_token() -> T.CodeId:
  T.CodeId{2698080513, 2698080514, 2698080515, 2698080516,
    2698080517, 2698080518, 2698080519, 2698080520}

def caller_token() -> T.CodeId:
  T.CodeId{2698080769, 2698080770, 2698080771, 2698080772,
    2698080773, 2698080774, 2698080775, 2698080776}

# The union of every excluded-input sentinel above.
def sentinel_words() -> List<&2, U32>:
  [2698080257, 2698080258, 2698080259, 2698080260, 2698080261, 2698080262,
    2698080513, 2698080514, 2698080515, 2698080516,
    2698080517, 2698080518, 2698080519, 2698080520,
    2698080769, 2698080770, 2698080771, 2698080772,
    2698080773, 2698080774, 2698080775, 2698080776]

# A diagnostic carrying each sentinel range in its own field (the spec's
# "execution error contains source text and a capability token").
def sentinel_diagnostic() -> AE.Diagnostic:
  AE.Diagnostic{payload_words(), error_text_words(), credential_words(), diagnostic_token()}

# Caller-written scope values for early-denied plans, 0xA0D17301-08. A plan
# can name any numbers, so these stand for data a caller might hide in one.
def plan_words() -> List<&2, U32>:
  [2698081025, 2698081026, 2698081027, 2698081028,
    2698081029, 2698081030, 2698081031, 2698081032]

def plan_code() -> T.CodeId:
  T.CodeId{2698081025, 2698081026, 2698081027, 2698081028,
    2698081029, 2698081030, 2698081031, 2698081032}

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
def grant_scope_words() -> List<&2, U32>:
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

def scope_words(x: AE.Scope) -> List<&2, U32>:
  match x:
    case AE.ScopeNotRead{}:
      [0]
    case AE.ScopeRead{n, xs, d, st, c, op}:
      cat([1, U32.from_nat(n)], cat(objects_words(xs), cat(version_words(d),
        cat(stamp_words(st), cat(code_words(c), [T.OpKind.bit(op)])))))

def event_words(e: AE.EventRecord) -> List<&2, U32>:
  match e:
    case AE.EventRecord{v, k, i, s, p, x, a, o}:
      cat([U32.from_nat(v), U32.from_nat(kind_code(k)), U32.from_nat(i), U32.from_nat(s),
        U32.from_nat(phase_code(p))],
        cat(scope_words(x), cat(artifact_words(a), outcome_words(o))))

# Test-side reads of the scope. Every one is False on ScopeNotRead.
def scope_absent(x: AE.Scope) -> Bool:
  match x:
    case AE.ScopeNotRead{}:
      True{}
    case AE.ScopeRead{n, xs, d, st, c, op}:
      False{}

def s_invocation_is(x: AE.Scope, +want: Nat) -> Bool:
  match x:
    case AE.ScopeNotRead{}:
      False{}
    case AE.ScopeRead{n, xs, d, st, c, op}:
      Nat.is_eq(n, want)

def s_sources_is(x: AE.Scope, want: T.Objects) -> Bool:
  match x:
    case AE.ScopeNotRead{}:
      False{}
    case AE.ScopeRead{n, xs, d, st, c, op}:
      T.Objects.equal(xs, want)

def s_destination_is(x: AE.Scope, want: T.ObjectVersion) -> Bool:
  match x:
    case AE.ScopeNotRead{}:
      False{}
    case AE.ScopeRead{n, xs, d, st, c, op}:
      T.ObjectVersion.equal(d, want)

def s_stamp_is(x: AE.Scope, want: T.Stamp) -> Bool:
  match x:
    case AE.ScopeNotRead{}:
      False{}
    case AE.ScopeRead{n, xs, d, st, c, op}:
      T.Stamp.equal(st, want)

def s_code_is(x: AE.Scope, want: T.CodeId) -> Bool:
  match x:
    case AE.ScopeNotRead{}:
      False{}
    case AE.ScopeRead{n, xs, d, st, c, op}:
      T.CodeId.equal(c, want)

def s_op_is(x: AE.Scope, want: T.OpKind) -> Bool:
  match x:
    case AE.ScopeNotRead{}:
      False{}
    case AE.ScopeRead{n, xs, d, st, c, op}:
      T.OpKind.equal(op, want)

def no_scope(e: AE.EventRecord) -> Bool:
  scope_absent(AE.EventRecord.scope(e))

def invocation_is(e: AE.EventRecord, +want: Nat) -> Bool:
  s_invocation_is(AE.EventRecord.scope(e), want)

def sources_is(e: AE.EventRecord, want: T.Objects) -> Bool:
  s_sources_is(AE.EventRecord.scope(e), want)

def destination_is(e: AE.EventRecord, want: T.ObjectVersion) -> Bool:
  s_destination_is(AE.EventRecord.scope(e), want)

def stamp_is(e: AE.EventRecord, want: T.Stamp) -> Bool:
  s_stamp_is(AE.EventRecord.scope(e), want)

def code_is(e: AE.EventRecord, want: T.CodeId) -> Bool:
  s_code_is(AE.EventRecord.scope(e), want)

def op_is(e: AE.EventRecord, want: T.OpKind) -> Bool:
  s_op_is(AE.EventRecord.scope(e), want)

# Every scope field of the event equals the plan's.
def scope_is(+e: AE.EventRecord, +p: T.Plan) -> Bool:
  invocation_is(e, T.Plan.invocation(p)) && sources_is(e, T.Plan.sources(p)) &&
    destination_is(e, T.Plan.destination(p)) && stamp_is(e, T.Plan.stamp(p)) &&
    code_is(e, T.Plan.code(p)) && op_is(e, T.Plan.kind(p))

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

def scope_expected(+e: AE.EventRecord, reads_scope: Bool) -> Bool:
  match reads_scope:
    case True{}:
      scope_is(e, TF.plan())
    case False{}:
      no_scope(e)

# --- event_projection: AU-001 "Error includes protected content" --------------

def sentinel_admission() -> AE.EventRecord:
  AE.AuditedAdmission.event(admit_as(TF.plan(), TF.context(), F.Caller{7n, caller_token()},
    sentinel_diagnostic(), event_id()))

def clean_admission() -> AE.EventRecord:
  AE.AuditedAdmission.event(admit_as(TF.plan(), TF.context(), FT.caller(7n),
    empty_diagnostic(), event_id()))

def sentinel_denial() -> AE.EventRecord:
  AE.AuditedAdmission.event(admit_as(TF.plan(), TF.with_reads(TF.context(), T.ReadEnd{}),
    F.Caller{7n, caller_token()}, sentinel_diagnostic(), event_id()))

def clean_denial() -> AE.EventRecord:
  AE.AuditedAdmission.event(admit_as(TF.plan(), TF.with_reads(TF.context(), T.ReadEnd{}),
    FT.caller(7n), empty_diagnostic(), event_id()))

def sentinel_commit() -> AE.EventRecord:
  AE.AuditedCommit.event(commit_as(FT.context(), FT.caller(7n), 2n, sentinel_diagnostic()))

# The Ref's token itself is the sentinel; the facade rejects it (no capability).
def sentinel_token_commit() -> AE.AuditedCommit:
  commit_as(FT.context(), F.Caller{7n, caller_token()}, 2n, sentinel_diagnostic())

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
    Test.check(none_of(grant_scope_words(), event_words(receipt_admission())),
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
    Test.check(invocation_is(committed_event(), T.Plan.invocation(TF.plan())),
      "AU-001 committed operation: invocation is the plan's")
    Test.check(sources_is(committed_event(), TF.source_manifest()),
      "AU-001 committed operation: exact ordered source versions")
    Test.check(destination_is(committed_event(), TF.destination_object()),
      "AU-001 committed operation: exact destination version")
    Test.check(stamp_is(committed_event(), T.Plan.stamp(TF.plan())),
      "AU-001 committed operation: graph, policy and authority epochs are the plan's")
    Test.check(code_is(committed_event(), TF.code()) &&
      op_is(committed_event(), T.Summarize{}),
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
      destination_is(AE.AuditedCommit.event(moved_session_commit()), T.ObjectVersion{20n, 9n}) &&
      sources_is(AE.AuditedCommit.event(moved_session_commit()), T.Plan.sources(moved_plan())),
      "AU-001 commit scope is the session's negotiated plan")

# A SYNTHETIC monitor context that vouches for `p`: live stamp, destination,
# operation and a write grant all bound to the plan's exact scope, one source
# policy per manifest entry, and no read grant. `T.admit` therefore passes the
# whole header (so every scope field is bound by the write grant) and denies
# Read, a reason whose event carries the scope.
def sources_for(xs: T.Objects, +epoch: Nat) -> T.Sources:
  match xs:
    case T.OEnd{}:
      T.SEnd{}
    case T.OCons{+h, t}:
      T.SCons{T.SourcePolicy{h, T.ReadDomain{5n}, 1, epoch, T.Bits64{1, 0}, T.Bits64{2, 0}, 7,
        T.RCons{T.OriginRule{h, T.Bits64{1, 0}, T.Bits64{2, 0}, 7, TF.one_code(TF.code()), T.Free{}}, T.REnd{}}},
        sources_for(t, epoch)}

def types_for(xs: T.Objects) -> T.Types:
  match xs:
    case T.OEnd{}:
      T.TEnd{}
    case T.OCons{h, t}:
      T.TCons{1, types_for(t)}

def vouched_context(+p: T.Plan) -> T.Context:
  +live = T.Plan.stamp(p)
  +epoch = T.Stamp.policy(live)
  +dst = T.Plan.destination(p)
  T.Context{live, 100n, sources_for(T.Plan.sources(p), epoch),
    T.DestinationPolicy{dst, T.WriteDomain{6n}, epoch, 2, T.Bits64{1, 0}, T.Bits64{2, 0}, 7},
    T.ApprovedOperation{T.Plan.code(p), T.Plan.kind(p), epoch, types_for(T.Plan.sources(p)), 2},
    T.ReadEnd{},
    T.WriteCons{T.WriteGrant{dst, T.WriteDomain{6n}, TF.scope_for(p, T.WriteDomain{6n}, 200n)}, T.WriteEnd{}},
    T.PayEnd{}}

def vouched(+p: T.Plan) -> AE.AuditedAdmission:
  admission(p, vouched_context(p))

def vouched_event(+p: T.Plan) -> AE.EventRecord:
  AE.AuditedAdmission.event(vouched(p))

# The vouched fixture is a Read denial whose event carries the plan's scope.
def vouched_reads(+p: T.Plan) -> Bool:
  TF.denied_as(AE.AuditedAdmission.decision(vouched(p)), T.Read{}) && scope_is(vouched_event(p), p)

# Second fixtures: one field of the plan changed at a time.
def source_moved() -> T.Plan:
  T.Plan{TF.stamp(), 99n, T.OCons{T.ObjectVersion{10n, 5n}, T.OEnd{}},
    TF.destination_object(), TF.code(), T.Summarize{}, 2}

def with_stamp(s: T.Stamp) -> T.Plan:
  T.Plan{s, 99n, TF.source_manifest(), TF.destination_object(), TF.code(), T.Summarize{}, 2}

def stamp_moved(+s: T.Stamp) -> Bool:
  +e = vouched_event(with_stamp(s))
  stamp_is(e, s) &&
    Bool.not(stamp_is(e, TF.stamp()))

def field_changes() -> IO(Unit):
  +moved = vouched_event(source_moved())
  +dest = vouched_event(TF.plan_destination(TF.plan(), T.ObjectVersion{20n, 9n}))
  do IO<Unit>:
    Test.check(sources_is(moved, T.Plan.sources(source_moved())) &&
      Bool.not(sources_is(moved, TF.source_manifest())),
      "AU-001 a changed source version changes the event's sources")
    Test.check(destination_is(dest, T.ObjectVersion{20n, 9n}) &&
      Bool.not(destination_is(dest, TF.destination_object())),
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
# Read, Origin and Payment arise after the write grant bound the plan, so the
# event carries TF.plan()'s scope; every other reason carries no scope.
def recorded_denial(context: T.Context, +reason: T.Denial, reads_scope: Bool) -> Bool:
  +audited = admission(TF.plan(), context)
  +e = AE.AuditedAdmission.event(audited)
  TF.denied_as(AE.AuditedAdmission.decision(audited), reason) &&
    has_kind(e, 1n, 0n, 1n) && denied_for(AE.EventRecord.outcome(e), reason) && no_artifact(e) &&
    scope_expected(e, reads_scope)

def denials_first() -> IO(Unit):
  do IO<Unit>:
    Test.check(recorded_denial(TF.with_live(TF.context(), T.Stamp{2n, 2n, 3n}), T.Stale{}, False{}),
      "AU-001 Stale denial is returned unchanged and recorded as AdmissionDenied DeniedFor Stale with no scope")
    Test.check(recorded_denial(TF.with_sources(TF.context(), T.SEnd{}), T.Source{}, False{}),
      "AU-001 Source denial is returned unchanged and recorded as AdmissionDenied DeniedFor Source with no scope")
    Test.check(recorded_denial(TF.with_reads(TF.context(), T.ReadEnd{}), T.Read{}, True{}),
      "AU-001 Read denial is returned unchanged and recorded as AdmissionDenied DeniedFor Read with the plan scope")
    Test.check(recorded_denial(TF.with_writes(TF.context(), T.WriteEnd{}), T.Write{}, False{}),
      "AU-001 Write denial is returned unchanged and recorded as AdmissionDenied DeniedFor Write with no scope")
    Test.check(recorded_denial(TF.with_sources(TF.context(), T.SCons{TF.invalid_schema_source(), T.SEnd{}}), T.Schema{}, False{}),
      "AU-001 Schema denial is returned unchanged and recorded as AdmissionDenied DeniedFor Schema with no scope")

def denials_second() -> IO(Unit):
  do IO<Unit>:
    Test.check(recorded_denial(operation_denied(), T.Operation{}, False{}),
      "AU-001 Operation denial is returned unchanged and recorded as AdmissionDenied DeniedFor Operation with no scope")
    Test.check(recorded_denial(origin_denied(), T.Origin{}, True{}),
      "AU-001 Origin denial is returned unchanged and recorded as AdmissionDenied DeniedFor Origin with the plan scope")
    Test.check(recorded_denial(TF.with_payments(TF.context(), T.PayEnd{}), T.Payment{}, True{}),
      "AU-001 Payment denial is returned unchanged and recorded as AdmissionDenied DeniedFor Payment with the plan scope")
    Test.check(recorded_denial(TF.destination_clearance(T.Bits64{0, 0}, T.Bits64{2, 0}, 7), T.Destination{}, False{}),
      "AU-001 Destination denial is returned unchanged and recorded as AdmissionDenied DeniedFor Destination with no scope")
    Test.check(recorded_denial(TF.with_origin(TF.context(), T.REnd{}, 7), T.InvalidPolicy{}, False{}),
      "AU-001 InvalidPolicy denial is returned unchanged and recorded as AdmissionDenied DeniedFor InvalidPolicy with no scope")

def copy_plan() -> T.Plan:
  T.Plan{TF.stamp(), 99n, TF.source_manifest(), TF.destination_object(), TF.code(), T.Copy{}, 2}

def other_code_plan() -> T.Plan:
  T.Plan{TF.stamp(), 99n, TF.source_manifest(), TF.destination_object(), TF.other_code(), T.Summarize{}, 2}

def other_invocation_plan() -> T.Plan:
  T.Plan{TF.stamp(), 100n, TF.source_manifest(), TF.destination_object(), TF.code(), T.Summarize{}, 2}

# --- event_projection: early denials carry no caller-written scope ----------

# Plans whose scope fields are the caller-chosen values 0xA0D17301-08. Each is
# denied by T.admit before its write-grant check, for the named reason, so
# nothing has bound any of these numbers.
def stuffed_source_object() -> T.ObjectVersion:
  T.ObjectVersion{2698081029n, 2698081030n}

def stuffed_destination() -> T.ObjectVersion:
  T.ObjectVersion{2698081031n, 2698081032n}

def stuffed_manifest() -> T.Objects:
  T.OCons{stuffed_source_object(), T.OEnd{}}

# Stale: the stamp itself is caller-written and matches no live epoch.
def stuffed_stale() -> T.Plan:
  T.Plan{T.Stamp{2698081025n, 2698081026n, 2698081027n}, 2698081028n, stuffed_manifest(),
    stuffed_destination(), plan_code(), T.Summarize{}, 2}

# Source: a two-entry manifest against a one-source context.
def stuffed_source() -> T.Plan:
  T.Plan{TF.stamp(), 2698081028n, T.OCons{stuffed_source_object(), T.OCons{stuffed_destination(), T.OEnd{}}},
    stuffed_destination(), plan_code(), T.Summarize{}, 2}

# Destination: a destination object the context's policy does not name.
def stuffed_destination_plan() -> T.Plan:
  T.Plan{TF.stamp(), 2698081028n, stuffed_manifest(), stuffed_destination(), plan_code(), T.Summarize{}, 2}

# Operation: a code the approved operation does not name.
def stuffed_operation() -> T.Plan:
  T.Plan{TF.stamp(), 2698081028n, stuffed_manifest(), TF.destination_object(), plan_code(), T.Summarize{}, 2}

# Schema: an output type the operation does not produce.
def stuffed_schema() -> T.Plan:
  T.Plan{TF.stamp(), 2698081028n, stuffed_manifest(), TF.destination_object(), TF.code(), T.Summarize{}, 4}

# Write: everything checked before the grant matches, but no write grant
# names this invocation and manifest.
def stuffed_write() -> T.Plan:
  T.Plan{TF.stamp(), 2698081028n, stuffed_manifest(), TF.destination_object(), TF.code(), T.Summarize{}, 2}

# Denied for `reason`, recorded with the ScopeNotRead marker, and no
# caller-written plan word occurs anywhere in the event.
def early_denial(+p: T.Plan, +reason: T.Denial) -> Bool:
  +audited = admission(p, TF.context())
  +e = AE.AuditedAdmission.event(audited)
  TF.denied_as(AE.AuditedAdmission.decision(audited), reason) && denied_for(AE.EventRecord.outcome(e), reason) &&
    no_scope(e) && none_of(plan_words(), event_words(e))

def early_denials() -> IO(Unit):
  do IO<Unit>:
    Test.check(early_denial(stuffed_stale(), T.Stale{}),
      "AU-001 a Stale-denied plan's caller-written stamp, invocation, sources, destination and code are absent from its event")
    Test.check(early_denial(stuffed_source(), T.Source{}),
      "AU-001 a Source-denied plan's caller-written scope is absent from its event")
    Test.check(early_denial(stuffed_destination_plan(), T.Destination{}),
      "AU-001 a Destination-denied plan's caller-written scope is absent from its event")
    Test.check(early_denial(stuffed_operation(), T.Operation{}),
      "AU-001 an Operation-denied plan's caller-written scope is absent from its event")
    Test.check(early_denial(stuffed_schema(), T.Schema{}),
      "AU-001 a Schema-denied plan's caller-written scope is absent from its event")
    Test.check(early_denial(stuffed_write(), T.Write{}),
      "AU-001 a Write-denied plan's caller-written scope is absent from its event")
    Test.check(AE.EventRecord.equal(admission_event(stuffed_stale(), TF.context()),
      admission_event(TF.plan(), TF.with_live(TF.context(), T.Stamp{9n, 9n, 9n}))) &&
      AE.EventRecord.equal(admission_event(stuffed_write(), TF.context()),
        admission_event(TF.plan(), TF.with_writes(TF.context(), T.WriteEnd{}))),
      "AU-001 an early-denied event is the same whatever the plan contains")
    Test.check(vouched_reads(TF.plan()) && vouched_reads(copy_plan()) && vouched_reads(source_moved()),
      "AU-001 once the write grant has bound the plan, a Read denial records the plan's scope")

def admitted_recorded() -> IO(Unit):
  +audited = admission(TF.plan(), TF.context())
  +e = AE.AuditedAdmission.event(audited)
  do IO<Unit>:
    Test.check(T.accepted(AE.AuditedAdmission.decision(audited)) &&
      TF.retained_output(AE.AuditedAdmission.decision(audited), T.Bits64{1, 0}, T.Bits64{2, 0}, 7, TF.source_manifest()),
      "AU-001 an admitted decision is returned with its ticket")
    Test.check(has_kind(e, 0n, 0n, 0n) && no_artifact(e) && Nat.is_eq(AE.EventRecord.subject(e), 7n),
      "AU-001 an admitted decision is recorded as AdmissionAdmitted with no artifact")
    Test.check(scope_is(e, TF.plan()),
      "AU-001 an admitted decision's event carries the plan's scope")

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

# All of these are vouched Read denials (scope read), so each pair below
# differs in exactly one event field.

def differs(a: AE.EventRecord, b: AE.EventRecord) -> Bool:
  Bool.not(AE.EventRecord.equal(a, b))

def equality_scope() -> IO(Unit):
  +base = vouched_event(TF.plan())
  do IO<Unit>:
    Test.check(AE.EventRecord.equal(base, vouched_event(TF.plan())),
      "AU-001 EventRecord.equal holds for two projections of the same decision")
    Test.check(differs(base, AE.AuditedAdmission.event(admit_as(TF.plan(), vouched_context(TF.plan()), FT.caller(7n), empty_diagnostic(), other_event_id()))) &&
      differs(base, AE.AuditedAdmission.event(admit_as(TF.plan(), vouched_context(TF.plan()), FT.caller(8n), empty_diagnostic(), event_id()))),
      "AU-001 EventRecord.equal separates event id and subject")
    Test.check(differs(base, vouched_event(other_invocation_plan())) && differs(base, vouched_event(source_moved())) &&
      differs(base, vouched_event(TF.plan_destination(TF.plan(), T.ObjectVersion{20n, 9n}))),
      "AU-001 EventRecord.equal separates invocation, sources and destination")
    Test.check(differs(base, vouched_event(with_stamp(T.Stamp{2n, 2n, 3n}))) &&
      differs(base, vouched_event(with_stamp(T.Stamp{1n, 3n, 3n}))) &&
      differs(base, vouched_event(with_stamp(T.Stamp{1n, 2n, 4n}))),
      "AU-001 EventRecord.equal separates each of the three epochs")
    Test.check(differs(base, vouched_event(other_code_plan())) && differs(base, vouched_event(copy_plan())),
      "AU-001 EventRecord.equal separates code and operation kind")

def equality_outcome() -> IO(Unit):
  do IO<Unit>:
    Test.check(differs(admission_event(TF.plan(), TF.with_reads(TF.context(), T.ReadEnd{})),
      admission_event(TF.plan(), TF.with_payments(TF.context(), T.PayEnd{}))),
      "AU-001 EventRecord.equal separates two denial reasons")
    Test.check(differs(committed_event(), AE.AuditedCommit.event(commit_subject(other_artifact_context(), 7n))),
      "AU-001 EventRecord.equal separates the sealed artifact")
    Test.check(Bool.not(AE.Outcome.equal(AE.Admitted{}, AE.DeniedFor{T.Read{}})) &&
      Bool.not(AE.Outcome.equal(AE.Committed{}, AE.NotCommitted{})) &&
      Bool.not(AE.Outcome.equal(AE.Admitted{}, AE.Committed{})) &&
      AE.Outcome.equal(AE.DeniedFor{T.Payment{}}, AE.DeniedFor{T.Payment{}}),
      "AU-001 Outcome.equal separates the four outcomes")

def all_reasons() -> List<&2, T.Denial>:
  [T.InvalidPolicy{}, T.Stale{}, T.Source{}, T.Read{}, T.Write{}, T.Schema{},
    T.Operation{}, T.Origin{}, T.Payment{}, T.Destination{}]

def same_bool(a: Bool, b: Bool) -> Bool:
  match a:
    case True{}:
      b
    case False{}:
      Bool.not(b)

# denial_equal holds for `r` against itself and fails against every other.
def separates(+r: T.Denial, xs: List<&2, T.Denial>) -> Bool:
  match xs:
    case []:
      True{}
    case +h <> t:
      same_bool(AE.denial_equal(r, h), U32.is_eq(TF.denial_code(r), TF.denial_code(h))) && separates(r, t)

def all_separated(xs: List<&2, T.Denial>) -> Bool:
  match xs:
    case []:
      True{}
    case h <> t:
      separates(h, all_reasons()) && all_separated(t)

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
    Test.check(Bool.not(AE.Scope.equal(AE.EventRecord.scope(vouched_event(TF.plan())), AE.ScopeNotRead{})) &&
      Bool.not(AE.Scope.equal(AE.ScopeNotRead{}, AE.EventRecord.scope(vouched_event(TF.plan())))) &&
      AE.Scope.equal(AE.ScopeNotRead{}, AE.ScopeNotRead{}),
      "AU-001 Scope.equal separates the not-read marker from a read scope")
    Test.check(all_separated(all_reasons()),
      "AU-001 denial_equal separates all ten denial reasons")

def event_projection() -> IO(Unit):
  do IO<Unit>:
    protected_content()
    committed_recorded()
    field_changes()
    denials_first()
    denials_second()
    early_denials()
    admitted_recorded()
    denial_recorded()
    equality_scope()
    equality_outcome()
    equality_helpers()

def main() -> IO(Unit):
  do IO<Unit>:
    event_projection()
    IO.print("Audit: 60 checks passed")
