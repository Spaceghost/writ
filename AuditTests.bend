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
import ./Dlm.bend as D
import ./Test.bend as Test

# Tests for the policy-aware audit model (change add-policy-aware-audit).
# Every log, grant, sink, label table and principal in this module is
# SYNTHETIC MONITOR STATE built from the shared fixtures (TF, BF, NF,
# FacadeTests), not an authenticated issuer, and every event checked in
# event_projection comes from `AE.audited_admit` or `AE.audited_commit`,
# never from a hand-written record (event_format alone also decodes
# hand-written SYNTHETIC records, as the plan allows for decoder tests).
# Sections follow the plan's task order:
# - event_projection (Task 1): AU-001 minimal scoped event records and the
#   model part of AU-005 (recording a denial keeps the rejected state).
#   It includes the early-denial rule: an admission denied before its write
#   grant bound the plan carries ScopeNotRead and none of the plan's words.
# - event_format (Task 2): AU-001's versioned canonical encoding and its
#   field allowlist. Round trips use projected events from the wrappers and,
#   as the plan allows for decoder tests only, hand-written SYNTHETIC records
#   with a distinct value in every field (so a field moved or dropped shows).
#   The malformed word lists are built test-side from the documented layout,
#   never from the encoder, so the layout itself is pinned.
# - event_policy (Task 3): AU-002 event policies include observed
#   influences. Every policy checked comes from the record a wrapper returned
#   (or, to pin a helper, from that helper over the same fixtures). Alice,
#   Bob and Mallory each have a distinct label, so a derivation or join that
#   drops one owner shows; the label tables and sinks are SYNTHETIC.

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

# --- event_format: helpers ------------------------------------------------------

# A test-side field: tag word and value words; `fields_words` adds the length.
type WField is Data:
  WField{tag: U32, values: List<&2, U32>}

def words_equal(a: List<&2, U32>, b: List<&2, U32>) -> Bool:
  match a b:
    case Nil{} Nil{}:
      True{}
    case Con{x, xs} Con{y, ys}:
      U32.is_eq(x, y) && words_equal(xs, ys)
    case _ _:
      False{}

def len_word(vs: List<&2, U32>) -> U32:
  U32.from_nat(List.length(&2, U32, vs))

# Tag word, length word, values, for every field in order.
def fields_words(fs: List<&2, WField>) -> List<&2, U32>:
  match fs:
    case Nil{}:
      Nil{}
    case Con{WField{t, +vs}, rest}:
      t <> len_word(vs) <> cat(vs, fields_words(rest))

# A version-1 header with the true body length in front of `fs`.
def framed(kind: U32, fs: List<&2, WField>) -> List<&2, U32>:
  +b = fields_words(fs)
  1 <> kind <> len_word(b) <> b

# A header with every word given, in front of `fs`.
def raw(version: U32, kind: U32, length: U32, fs: List<&2, WField>) -> List<&2, U32>:
  version <> kind <> length <> fields_words(fs)

# Test-side reason codes, independent of FormatError.equal.
def reason_code(e: AE.FormatError) -> Nat:
  match e:
    case AE.UnknownVersion{}:
      1n
    case AE.UnknownKind{}:
      2n
    case AE.NotAllowed{}:
      3n
    case AE.OutOfOrder{}:
      4n
    case AE.BadLength{}:
      5n
    case AE.TooLong{}:
      6n
    case AE.OutOfRange{}:
      7n

def rejected(r: AE.DecodeResult, reason: AE.FormatError) -> Bool:
  match r:
    case AE.Decoded{e}:
      False{}
    case AE.Malformed{found}:
      Nat.is_eq(reason_code(found), reason_code(reason))

def all_reasons_format() -> List<&2, AE.FormatError>:
  [AE.UnknownVersion{}, AE.UnknownKind{}, AE.NotAllowed{}, AE.OutOfOrder{}, AE.BadLength{},
    AE.TooLong{}, AE.OutOfRange{}]

# FormatError.equal holds for `r` against itself and fails against every other.
def format_separates(+r: AE.FormatError, xs: List<&2, AE.FormatError>) -> Bool:
  match xs:
    case []:
      True{}
    case +h <> t:
      same_bool(AE.FormatError.equal(r, h), Nat.is_eq(reason_code(r), reason_code(h))) &&
        format_separates(r, t)

def format_all_separated(xs: List<&2, AE.FormatError>) -> Bool:
  match xs:
    case []:
      True{}
    case h <> t:
      format_separates(h, all_reasons_format()) && format_all_separated(t)

def nothing_built(m: Maybe<&2, AE.EventRecord>) -> Bool:
  match m:
    case None{}:
      True{}
    case Some{e}:
      False{}

def builds_nothing(r: AE.DecodeResult) -> Bool:
  nothing_built(AE.DecodeResult.event(r))

def refused(m: Maybe<&2, List<&2, U32>>) -> Bool:
  match m:
    case None{}:
      True{}
    case Some{ws}:
      False{}

def encodes_as(m: Maybe<&2, List<&2, U32>>, ws: List<&2, U32>) -> Bool:
  match m:
    case None{}:
      False{}
    case Some{xs}:
      words_equal(xs, ws)

# The encoding, or the empty list (which decodes BadLength) when refused.
def encoded(+e: AE.EventRecord) -> List<&2, U32>:
  Maybe.default(&2, List<&2, U32>, AE.encode(e), [])

# A decoded event equals `e` under EventRecord.equal and under the test-side
# flattening `event_words`, which does not depend on AuditEvent's equality.
def decoded_matches(r: AE.DecodeResult, +e: AE.EventRecord) -> Bool:
  match r:
    case AE.Decoded{+d}:
      AE.EventRecord.equal(d, e) && words_equal(event_words(d), event_words(e))
    case AE.Malformed{reason}:
      False{}

# decode(encode(e)) == Decoded{e}.
def round_trips(+e: AE.EventRecord) -> Bool:
  decoded_matches(AE.decode(encoded(e)), e)

def all_round_trip(es: List<&2, AE.EventRecord>) -> Bool:
  match es:
    case Nil{}:
      True{}
    case Con{e, rest}:
      round_trips(e) && all_round_trip(rest)

# The reverse direction: an accepted word list re-encodes to itself.
def reencoded(r: AE.DecodeResult, ws: List<&2, U32>) -> Bool:
  match r:
    case AE.Decoded{e}:
      encodes_as(AE.encode(e), ws)
    case AE.Malformed{reason}:
      False{}

def reencodes(+ws: List<&2, U32>) -> Bool:
  reencoded(AE.decode(ws), ws)

def decode_fields(kind: U32, fs: List<&2, WField>) -> AE.DecodeResult:
  AE.decode(framed(kind, fs))

# --- event_format: SYNTHETIC records with a distinct value in every field ------

# Hand-written records (decoder tests only; never stored in a log). Event id
# 1001, subject 1002, invocation 1003, sources (1004, 1005) and (1006, 1007),
# destination (1008, 1009), stamp (1010, 1011, 1012), code 1013-1020,
# operation Transform (word 2), artifact digest 1021-1028.
def d_sources() -> T.Objects:
  T.OCons{T.ObjectVersion{1004n, 1005n}, T.OCons{T.ObjectVersion{1006n, 1007n}, T.OEnd{}}}

def d_destination() -> T.ObjectVersion:
  T.ObjectVersion{1008n, 1009n}

def d_stamp() -> T.Stamp:
  T.Stamp{1010n, 1011n, 1012n}

def d_code() -> T.CodeId:
  T.CodeId{1013, 1014, 1015, 1016, 1017, 1018, 1019, 1020}

def d_artifact() -> B.ArtifactId:
  B.ArtifactId{T.CodeId{1021, 1022, 1023, 1024, 1025, 1026, 1027, 1028}}

def scope_with(n: Nat, xs: T.Objects, d: T.ObjectVersion, st: T.Stamp) -> AE.Scope:
  AE.ScopeRead{n, xs, d, st, d_code(), T.Transform{}}

def d_scope() -> AE.Scope:
  scope_with(1003n, d_sources(), d_destination(), d_stamp())

def record(k: AE.EventKind, p: AE.Phase, x: AE.Scope, a: Maybe<&2, B.ArtifactId>,
    o: AE.Outcome) -> AE.EventRecord:
  AE.EventRecord{1n, k, 1001n, 1002n, p, x, a, o}

def committed_with(x: AE.Scope) -> AE.EventRecord:
  record(AE.CommitAccepted{}, AE.Commit{}, x, Some{d_artifact()}, AE.Committed{})

def d_committed() -> AE.EventRecord:
  committed_with(d_scope())

def d_rejected() -> AE.EventRecord:
  record(AE.CommitRejected{}, AE.Commit{}, d_scope(), None{}, AE.NotCommitted{})

def d_admitted() -> AE.EventRecord:
  record(AE.AdmissionAdmitted{}, AE.Admission{}, d_scope(), None{}, AE.Admitted{})

def d_denied(r: T.Denial, x: AE.Scope) -> AE.EventRecord:
  record(AE.AdmissionDenied{}, AE.Admission{}, x, None{}, AE.DeniedFor{r})

def d_early(r: T.Denial) -> AE.EventRecord:
  d_denied(r, AE.ScopeNotRead{})

def d_late(r: T.Denial) -> AE.EventRecord:
  d_denied(r, d_scope())

# Test-side: the reasons whose events carry a scope (Read, Origin, Payment).
def d_denials() -> List<&2, AE.EventRecord>:
  [d_early(T.InvalidPolicy{}), d_early(T.Stale{}), d_early(T.Source{}), d_late(T.Read{}),
    d_early(T.Write{}), d_early(T.Schema{}), d_early(T.Operation{}), d_late(T.Origin{}),
    d_late(T.Payment{}), d_early(T.Destination{})]

# d_committed() in the documented layout: header version 1, kind 3, body 53.
def committed_golden() -> List<&2, U32>:
  [1, 3, 53, 1, 1, 1001, 2, 1, 1002, 3, 1, 1, 4, 1, 1003,
    5, 4, 1004, 1005, 1006, 1007, 6, 2, 1008, 1009, 7, 3, 1010, 1011, 1012,
    8, 8, 1013, 1014, 1015, 1016, 1017, 1018, 1019, 1020, 9, 1, 2,
    10, 8, 1021, 1022, 1023, 1024, 1025, 1026, 1027, 1028, 11, 1, 2]

# d_early(Stale): kind 2, every scope field and the artifact length 0, the
# outcome DeniedFor (1) with reason Stale (1).
def early_golden() -> List<&2, U32>:
  [1, 2, 27, 1, 1, 1001, 2, 1, 1002, 3, 1, 0, 4, 0, 5, 0, 6, 0, 7, 0, 8, 0, 9, 0,
    10, 0, 11, 2, 1, 1]

# The fields of d_committed(), one function each, for building malformed lists.
def f_id() -> WField:
  WField{1, [1001]}

def f_subject() -> WField:
  WField{2, [1002]}

def f_phase() -> WField:
  WField{3, [1]}

def f_invocation() -> WField:
  WField{4, [1003]}

def f_sources() -> WField:
  WField{5, [1004, 1005, 1006, 1007]}

def f_destination() -> WField:
  WField{6, [1008, 1009]}

def f_stamp() -> WField:
  WField{7, [1010, 1011, 1012]}

def f_code() -> WField:
  WField{8, [1013, 1014, 1015, 1016, 1017, 1018, 1019, 1020]}

def f_op() -> WField:
  WField{9, [2]}

def f_artifact() -> WField:
  WField{10, [1021, 1022, 1023, 1024, 1025, 1026, 1027, 1028]}

def f_outcome() -> WField:
  WField{11, [2]}

def f_empty(tag: U32) -> WField:
  WField{tag, []}

# The scope fields, invocation to operation kind.
def scope_fields(rest: List<&2, WField>) -> List<&2, WField>:
  f_invocation() <> f_sources() <> f_destination() <> f_stamp() <> f_code() <> f_op() <> rest

def empty_scope_fields(rest: List<&2, WField>) -> List<&2, WField>:
  f_empty(4) <> f_empty(5) <> f_empty(6) <> f_empty(7) <> f_empty(8) <> f_empty(9) <> rest

# d_committed() as fields; each variant below changes one thing.
def committed_fields() -> List<&2, WField>:
  f_id() <> f_subject() <> f_phase() <> scope_fields([f_artifact(), f_outcome()])

# Committed fields with the given phase, scope part, artifact and outcome.
def committed_parts(ph: WField, scope: List<&2, WField>) -> List<&2, WField>:
  f_id() <> f_subject() <> ph <> scope

def with_outcome(o: WField) -> List<&2, WField>:
  f_id() <> f_subject() <> f_phase() <> scope_fields([f_artifact(), o])

def with_artifact(a: WField) -> List<&2, WField>:
  f_id() <> f_subject() <> f_phase() <> scope_fields([a, f_outcome()])

# Committed fields with one scope field replaced.
def with_sources(s: WField) -> List<&2, WField>:
  f_id() <> f_subject() <> f_phase() <> f_invocation() <> s <> f_destination() <> f_stamp() <>
    f_code() <> f_op() <> f_artifact() <> f_outcome() <> Nil{}

def with_stamp_field(s: WField) -> List<&2, WField>:
  f_id() <> f_subject() <> f_phase() <> f_invocation() <> f_sources() <> f_destination() <> s <>
    f_code() <> f_op() <> f_artifact() <> f_outcome() <> Nil{}

def with_op(o: WField) -> List<&2, WField>:
  f_id() <> f_subject() <> f_phase() <> f_invocation() <> f_sources() <> f_destination() <> f_stamp() <>
    f_code() <> o <> f_artifact() <> f_outcome() <> Nil{}

def with_phase(p: WField) -> List<&2, WField>:
  f_id() <> f_subject() <> p <> scope_fields([f_artifact(), f_outcome()])

# An admission (kind 1 or 2) with the given scope part and outcome, no artifact.
def admission_fields(scope: List<&2, WField>, o: WField) -> List<&2, WField>:
  f_id() <> f_subject() <> WField{3, [0]} <> List.append(&2, WField, scope, [f_empty(10), o])

# A CommitRejected event (no artifact) with the given sources field.
def rejected_with_sources(s: WField) -> List<&2, WField>:
  f_id() <> f_subject() <> f_phase() <> f_invocation() <> s <> f_destination() <> f_stamp() <>
    f_code() <> f_op() <> f_empty(10) <> WField{11, [3]} <> Nil{}

# An AdmissionAdmitted-shaped event (scope read, no artifact) with the given
# phase and outcome fields.
def admitted_parts(ph: WField, o: WField) -> List<&2, WField>:
  f_id() <> f_subject() <> ph <> scope_fields([f_empty(10), o])

def sixteen_pairs() -> List<&2, U32>:
  [1004, 1005, 1004, 1005, 1004, 1005, 1004, 1005, 1004, 1005, 1004, 1005, 1004, 1005, 1004, 1005,
    1004, 1005, 1004, 1005, 1004, 1005, 1004, 1005, 1004, 1005, 1004, 1005, 1004, 1005, 1004, 1005]

def seventeen_pairs() -> List<&2, U32>:
  1004 <> 1005 <> sixteen_pairs()

# n copies of the source version (1004, 1005).
def sources_n(n: Nat) -> T.Objects:
  match n:
    case 0n:
      T.OEnd{}
    case 1n+p:
      T.OCons{T.ObjectVersion{1004n, 1005n}, sources_n(p)}

# 2^32, computed test-side.
def two_32() -> Nat:
  Nat.add(4294967295n, 1n)

def with_ids(+e: AE.EventRecord, id: Nat, subject: Nat) -> AE.EventRecord:
  match e:
    case AE.EventRecord{v, k, _, _, p, x, a, o}:
      AE.EventRecord{v, k, id, subject, p, x, a, o}

def with_version(+e: AE.EventRecord, v: Nat) -> AE.EventRecord:
  match e:
    case AE.EventRecord{_, k, i, s, p, x, a, o}:
      AE.EventRecord{v, k, i, s, p, x, a, o}

def with_kind(+e: AE.EventRecord, k: AE.EventKind) -> AE.EventRecord:
  match e:
    case AE.EventRecord{v, _, i, s, p, x, a, o}:
      AE.EventRecord{v, k, i, s, p, x, a, o}

def with_phase_value(+e: AE.EventRecord, p: AE.Phase) -> AE.EventRecord:
  match e:
    case AE.EventRecord{v, k, i, s, _, x, a, o}:
      AE.EventRecord{v, k, i, s, p, x, a, o}

def decoded_differs(r: AE.DecodeResult, +other: AE.EventRecord) -> Bool:
  match r:
    case AE.Decoded{d}:
      Bool.not(AE.EventRecord.equal(d, other))
    case AE.Malformed{reason}:
      False{}

# Test-side copy of the allowlist, independent of AuditEvent's constants.
def expected_tags() -> List<&2, Nat>:
  [1n, 2n, 3n, 4n, 5n, 6n, 7n, 8n, 9n, 10n, 11n]

def tags_are(tags: AE.FieldTags, want: List<&2, Nat>) -> Bool:
  match tags want:
    case AE.NoTags{} Nil{}:
      True{}
    case AE.FieldTag{t, rest} Con{w, ws}:
      Nat.is_eq(t, w) && tags_are(rest, ws)
    case _ _:
      False{}

def all_allowed(ts: List<&2, Nat>) -> Bool:
  match ts:
    case Nil{}:
      True{}
    case Con{t, rest}:
      AE.field_allowed(t) && all_allowed(rest)

# --- event_format: projected events (from the wrappers) ------------------------

def projected_denials() -> List<&2, AE.EventRecord>:
  [admission_event(TF.plan(), TF.with_live(TF.context(), T.Stamp{2n, 2n, 3n})),
    admission_event(TF.plan(), TF.with_sources(TF.context(), T.SEnd{})),
    admission_event(TF.plan(), TF.with_reads(TF.context(), T.ReadEnd{})),
    admission_event(TF.plan(), TF.with_writes(TF.context(), T.WriteEnd{})),
    admission_event(TF.plan(), TF.with_sources(TF.context(), T.SCons{TF.invalid_schema_source(), T.SEnd{}})),
    admission_event(TF.plan(), operation_denied()),
    admission_event(TF.plan(), origin_denied()),
    admission_event(TF.plan(), TF.with_payments(TF.context(), T.PayEnd{})),
    admission_event(TF.plan(), TF.destination_clearance(T.Bits64{0, 0}, T.Bits64{2, 0}, 7)),
    admission_event(TF.plan(), TF.with_origin(TF.context(), T.REnd{}, 7))]

def rejected_event() -> AE.EventRecord:
  AE.AuditedCommit.event(commit_subject(revoked_context(), 7n))

# --- event_format: round trips --------------------------------------------------

def format_round_trips() -> IO(Unit):
  do IO<Unit>:
    Test.check(round_trips(admission_event(TF.plan(), TF.context())),
      "AU-001 format: a projected AdmissionAdmitted event round trips")
    Test.check(all_round_trip(projected_denials()),
      "AU-001 format: projected AdmissionDenied events for all ten denial reasons round trip, early ones with ScopeNotRead")
    Test.check(round_trips(committed_event()) && round_trips(AE.AuditedCommit.event(commit_subject(other_artifact_context(), 7n))),
      "AU-001 format: projected CommitAccepted events round trip with their artifact")
    Test.check(round_trips(rejected_event()),
      "AU-001 format: a projected CommitRejected event round trips with no artifact")
    Test.check(round_trips(admission_event(stuffed_stale(), TF.context())) &&
      round_trips(admission_event(stuffed_write(), TF.context())) &&
      none_of(plan_words(), encoded(admission_event(stuffed_stale(), TF.context()))) &&
      none_of(plan_words(), encoded(admission_event(stuffed_write(), TF.context()))),
      "AU-001 format: ScopeNotRead events round trip and no caller-written plan word occurs in their encoding")
    Test.check(none_of(sentinel_words(), encoded(sentinel_admission())) &&
      none_of(sentinel_words(), encoded(sentinel_denial())) &&
      none_of(sentinel_words(), encoded(sentinel_commit())),
      "AU-001 format: no diagnostic or caller-token sentinel occurs in an encoded event")
    Test.check(round_trips(d_admitted()) && round_trips(d_committed()) && round_trips(d_rejected()),
      "AU-001 format: distinct-valued AdmissionAdmitted, CommitAccepted and CommitRejected records round trip")
    Test.check(all_round_trip(d_denials()),
      "AU-001 format: distinct-valued AdmissionDenied records round trip for every denial reason")
    Test.check(round_trips(d_early(T.Stale{})) && round_trips(d_early(T.Write{})),
      "AU-001 format: distinct-valued ScopeNotRead records round trip")

def format_layout() -> IO(Unit):
  do IO<Unit>:
    Test.check(encodes_as(AE.encode(d_committed()), committed_golden()),
      "AU-001 format: encode emits the documented layout (header, then tag, length and values per field in allowlist order)")
    Test.check(encodes_as(AE.encode(d_early(T.Stale{})), early_golden()),
      "AU-001 format: under ScopeNotRead every scope field and the absent artifact are length 0")
    Test.check(reencodes(committed_golden()) && reencodes(early_golden()) &&
      reencodes(encoded(d_late(T.Payment{}))) && reencodes(encoded(d_rejected())),
      "AU-001 format: accepted word lists re-encode to exactly themselves")
    Test.check(decoded_differs(AE.decode(committed_golden()), with_version(d_committed(), 2n)),
      "AU-001 format: a decoded record and one differing only in version compare unequal")
    Test.check(decoded_differs(AE.decode(committed_golden()), with_kind(d_committed(), AE.CommitRejected{})),
      "AU-001 format: a decoded record and one differing only in kind compare unequal")
    Test.check(decoded_differs(AE.decode(committed_golden()), with_phase_value(d_committed(), AE.Admission{})),
      "AU-001 format: a decoded record and one differing only in phase compare unequal")

# --- event_format: the allowlist ------------------------------------------------

def format_allowlist() -> IO(Unit):
  do IO<Unit>:
    Test.check(tags_are(AE.field_allowlist(), expected_tags()),
      "AU-001 format: field_allowlist() is exactly tags 1 to 11 in order")
    Test.check(all_allowed(expected_tags()),
      "AU-001 format: field_allowed accepts every allowlisted tag")
    Test.check(Bool.not(AE.field_allowed(AE.field_reserved_payload())) &&
      Bool.not(AE.field_allowed(AE.field_reserved_token())) &&
      Bool.not(AE.field_allowed(AE.field_reserved_text())) &&
      Bool.not(AE.field_allowed(0n)) && Bool.not(AE.field_allowed(15n)),
      "AU-001 format: field_allowed refuses the reserved payload, token and text tags, 0 and 15")
    Test.check(Nat.is_eq(AE.max_words(), 85n),
      "AU-001 format: the length cap is 3 header words, 2 per field and 60 value words")

# --- event_format: encoder refusals ---------------------------------------------

def format_encode_bounds() -> IO(Unit):
  do IO<Unit>:
    Test.check(refused(AE.encode(committed_with(scope_with(two_32(), d_sources(), d_destination(), d_stamp())))),
      "AU-001 format: encode of an invocation of 2^32 is None")
    Test.check(round_trips(committed_with(scope_with(4294967295n, d_sources(), d_destination(), d_stamp()))),
      "AU-001 format: an invocation of 2^32 - 1 encodes and round trips")
    Test.check(refused(AE.encode(with_ids(d_committed(), two_32(), 1002n))) &&
      refused(AE.encode(with_ids(d_committed(), 1001n, two_32()))),
      "AU-001 format: encode of an event id or subject of 2^32 is None")
    Test.check(refused(AE.encode(committed_with(scope_with(1003n, T.OCons{T.ObjectVersion{two_32(), 1005n}, T.OEnd{}}, d_destination(), d_stamp())))) &&
      refused(AE.encode(committed_with(scope_with(1003n, T.OCons{T.ObjectVersion{1004n, 1005n}, T.OCons{T.ObjectVersion{1006n, two_32()}, T.OEnd{}}}, d_destination(), d_stamp())))),
      "AU-001 format: encode of a source object or version of 2^32 is None")
    Test.check(refused(AE.encode(committed_with(scope_with(1003n, d_sources(), T.ObjectVersion{two_32(), 1009n}, d_stamp())))) &&
      refused(AE.encode(committed_with(scope_with(1003n, d_sources(), T.ObjectVersion{1008n, two_32()}, d_stamp())))),
      "AU-001 format: encode of a destination object or version of 2^32 is None")
    Test.check(refused(AE.encode(committed_with(scope_with(1003n, d_sources(), d_destination(), T.Stamp{two_32(), 1011n, 1012n})))) &&
      refused(AE.encode(committed_with(scope_with(1003n, d_sources(), d_destination(), T.Stamp{1010n, two_32(), 1012n})))) &&
      refused(AE.encode(committed_with(scope_with(1003n, d_sources(), d_destination(), T.Stamp{1010n, 1011n, two_32()})))),
      "AU-001 format: encode of any of the three epochs at 2^32 is None")
    Test.check(refused(AE.encode(committed_with(scope_with(1003n, sources_n(17n), d_destination(), d_stamp())))),
      "AU-001 format: encode of 17 sources (more than max_sources) is None")
    Test.check(round_trips(committed_with(scope_with(1003n, sources_n(16n), d_destination(), d_stamp()))),
      "AU-001 format: 16 sources encode and round trip")

def format_encode_coherence() -> IO(Unit):
  do IO<Unit>:
    Test.check(refused(AE.encode(with_version(d_committed(), 2n))),
      "AU-001 format: encode of a record whose version is not the format's is None")
    Test.check(refused(AE.encode(with_kind(d_committed(), AE.AdmissionAdmitted{}))),
      "AU-001 format: encode of a record whose kind contradicts its outcome is None")
    Test.check(refused(AE.encode(with_phase_value(d_committed(), AE.Admission{}))),
      "AU-001 format: encode of a record whose phase contradicts its kind is None")
    Test.check(refused(AE.encode(record(AE.CommitRejected{}, AE.Commit{}, d_scope(), Some{d_artifact()}, AE.NotCommitted{}))) &&
      refused(AE.encode(record(AE.CommitAccepted{}, AE.Commit{}, d_scope(), None{}, AE.Committed{}))),
      "AU-001 format: encode of an artifact on a rejected commit, or none on an accepted one, is None")
    Test.check(refused(AE.encode(d_denied(T.Stale{}, d_scope()))) &&
      refused(AE.encode(d_denied(T.Read{}, AE.ScopeNotRead{}))) &&
      refused(AE.encode(committed_with(AE.ScopeNotRead{}))),
      "AU-001 format: encode of a scope on an early denial, or none on a scope-reading outcome, is None")

# --- event_format: decoder rejections --------------------------------------------

def format_header() -> IO(Unit):
  do IO<Unit>:
    Test.check(rejected(AE.decode(raw(0, 3, 53, committed_fields())), AE.UnknownVersion{}),
      "AU-001 format: version 0 denied UnknownVersion")
    Test.check(rejected(AE.decode(raw(2, 3, 53, committed_fields())), AE.UnknownVersion{}),
      "AU-001 format: version 2 denied UnknownVersion")
    Test.check(rejected(AE.decode(raw(4294967295, 3, 53, committed_fields())), AE.UnknownVersion{}),
      "AU-001 format: version 0xFFFFFFFF denied UnknownVersion")
    Test.check(rejected(AE.decode(raw(1, 0, 53, committed_fields())), AE.UnknownKind{}),
      "AU-001 format: kind 0 denied UnknownKind")
    Test.check(rejected(AE.decode(raw(1, 5, 53, committed_fields())), AE.UnknownKind{}),
      "AU-001 format: kind 5 denied UnknownKind")
    Test.check(rejected(AE.decode([]), AE.BadLength{}) && rejected(AE.decode([1]), AE.BadLength{}) &&
      rejected(AE.decode([1, 3]), AE.BadLength{}),
      "AU-001 format: empty input, a version word only, and version and kind only denied BadLength")
    Test.check(rejected(AE.decode(raw(1, 3, 52, committed_fields())), AE.BadLength{}),
      "AU-001 format: a body length word one short denied BadLength")
    Test.check(rejected(AE.decode(raw(1, 3, 54, committed_fields())), AE.BadLength{}),
      "AU-001 format: a body length word one long denied BadLength")
    Test.check(rejected(AE.decode(List.take(&2, U32, committed_golden(), 55n)), AE.BadLength{}),
      "AU-001 format: a truncated body denied BadLength")
    Test.check(rejected(AE.decode(cat(committed_golden(), [0])), AE.BadLength{}),
      "AU-001 format: one trailing word denied BadLength")

def format_reserved() -> IO(Unit):
  +payload = decode_fields(3, f_id() <> f_subject() <> WField{12, payload_words()} <> f_phase() <>
    scope_fields([f_artifact(), f_outcome()]))
  +token = decode_fields(3, f_id() <> f_subject() <> f_phase() <> f_invocation() <> f_sources() <>
    f_destination() <> f_stamp() <> WField{13, code_words(caller_token())} <> f_op() <> f_artifact() <> f_outcome() <> Nil{})
  +text = decode_fields(3, WField{14, error_text_words()} <> committed_fields())
  do IO<Unit>:
    Test.check(rejected(payload, AE.NotAllowed{}) && builds_nothing(payload),
      "AU-001 format: a field tagged as payload (12) is denied NotAllowed and builds no event")
    Test.check(rejected(token, AE.NotAllowed{}) && builds_nothing(token),
      "AU-001 format: a field tagged as a token (13) in place of the code is denied NotAllowed and builds no event")
    Test.check(rejected(text, AE.NotAllowed{}) && builds_nothing(text),
      "AU-001 format: a field tagged as text (14) before the event id is denied NotAllowed and builds no event")
    Test.check(rejected(decode_fields(3, f_id() <> WField{0, [1002]} <> Nil{}), AE.NotAllowed{}) &&
      rejected(decode_fields(3, f_id() <> WField{15, [1002]} <> Nil{}), AE.NotAllowed{}),
      "AU-001 format: field tags 0 and 15 are denied NotAllowed")

def format_order() -> IO(Unit):
  do IO<Unit>:
    Test.check(rejected(decode_fields(3, f_subject() <> f_id() <> f_phase() <> scope_fields([f_artifact(), f_outcome()])), AE.OutOfOrder{}),
      "AU-001 format: two fields out of allowlist order denied OutOfOrder")
    Test.check(rejected(decode_fields(3, f_id() <> f_subject() <> f_subject() <> f_phase() <> scope_fields([f_artifact(), f_outcome()])), AE.OutOfOrder{}),
      "AU-001 format: a duplicate field denied OutOfOrder")
    Test.check(rejected(decode_fields(3, f_id() <> f_phase() <> scope_fields([f_artifact(), f_outcome()])), AE.OutOfOrder{}),
      "AU-001 format: a missing middle field (the subject) denied OutOfOrder")
    Test.check(rejected(decode_fields(3, f_id() <> f_subject() <> f_phase() <> scope_fields([f_artifact()])), AE.BadLength{}),
      "AU-001 format: a missing last field (the outcome) denied BadLength")
    Test.check(rejected(AE.decode(cat(raw(1, 3, 54, committed_fields()), [0])), AE.BadLength{}),
      "AU-001 format: a word after the last field, counted by the body length, denied BadLength")
    Test.check(rejected(AE.decode(cat(List.take(&2, U32, committed_golden(), 53n), [11, 5, 2])), AE.BadLength{}),
      "AU-001 format: a field length word naming more words than remain denied BadLength")

def format_widths() -> IO(Unit):
  do IO<Unit>:
    Test.check(rejected(decode_fields(3, with_stamp_field(WField{7, [1010, 1011]})), AE.BadLength{}),
      "AU-001 format: a field one word short (stamp length 2) denied BadLength")
    Test.check(rejected(decode_fields(3, with_stamp_field(WField{7, [1010, 1011, 1012, 1013]})), AE.BadLength{}),
      "AU-001 format: a field one word long (stamp length 4) denied BadLength")
    Test.check(rejected(decode_fields(3, WField{1, [1001, 1001]} <> f_subject() <> f_phase() <> scope_fields([f_artifact(), f_outcome()])), AE.BadLength{}) &&
      rejected(decode_fields(3, f_id() <> f_empty(2) <> f_phase() <> scope_fields([f_artifact(), f_outcome()])), AE.BadLength{}) &&
      rejected(decode_fields(3, with_phase(WField{3, [1, 1]})), AE.BadLength{}),
      "AU-001 format: event id, subject and phase of other than one word denied BadLength")
    Test.check(rejected(decode_fields(3, f_id() <> f_subject() <> f_phase() <> WField{4, [1003, 1003]} <> f_sources() <> f_destination() <>
      f_stamp() <> f_code() <> f_op() <> f_artifact() <> f_outcome() <> Nil{}), AE.BadLength{}) &&
      rejected(decode_fields(3, f_id() <> f_subject() <> f_phase() <> f_invocation() <> f_sources() <> WField{6, [1008]} <>
        f_stamp() <> f_code() <> f_op() <> f_artifact() <> f_outcome() <> Nil{}), AE.BadLength{}) &&
      rejected(decode_fields(3, f_id() <> f_subject() <> f_phase() <> f_invocation() <> f_sources() <> f_destination() <>
        f_stamp() <> WField{8, [1013, 1014, 1015, 1016, 1017, 1018, 1019]} <> f_op() <> f_artifact() <> f_outcome() <> Nil{}), AE.BadLength{}) &&
      rejected(decode_fields(3, with_op(WField{9, [2, 2]})), AE.BadLength{}),
      "AU-001 format: invocation, destination, code and operation of the wrong width denied BadLength")
    Test.check(rejected(decode_fields(3, with_sources(WField{5, [1004, 1005, 1006]})), AE.BadLength{}),
      "AU-001 format: an odd number of source words denied BadLength")
    Test.check(rejected(decode_fields(4, rejected_with_sources(WField{5, seventeen_pairs()})), AE.TooLong{}) &&
      Nat.is_le(List.length(&2, U32, framed(4, rejected_with_sources(WField{5, seventeen_pairs()}))), AE.max_words()),
      "AU-001 format: more than max_sources sources denied TooLong (inside the length cap)")
    Test.check(Bool.not(builds_nothing(decode_fields(3, with_sources(WField{5, sixteen_pairs()})))),
      "AU-001 format: exactly max_sources sources decode")
    Test.check(rejected(AE.decode(List.replicate(U32, 86n, 1)), AE.TooLong{}),
      "AU-001 format: more than max_words words denied TooLong")
    Test.check(rejected(decode_fields(3, with_artifact(WField{10, [1021, 1022, 1023, 1024, 1025, 1026, 1027]})), AE.BadLength{}),
      "AU-001 format: an artifact of seven words denied BadLength")

def format_scope_widths() -> IO(Unit):
  do IO<Unit>:
    Test.check(rejected(decode_fields(2, admission_fields(f_empty(4) <> f_sources() <> f_empty(6) <> f_empty(7) <>
      f_empty(8) <> f_empty(9) <> Nil{}, WField{11, [1, 1]})), AE.BadLength{}) &&
      rejected(decode_fields(2, admission_fields(f_empty(4) <> f_empty(5) <> f_empty(6) <> f_empty(7) <>
        f_empty(8) <> f_op() <> Nil{}, WField{11, [1, 1]})), AE.BadLength{}),
      "AU-001 format: an empty invocation with another scope field present denied BadLength")
    Test.check(rejected(decode_fields(3, f_id() <> f_subject() <> f_phase() <> f_invocation() <> f_sources() <> f_empty(6) <>
      f_stamp() <> f_code() <> f_op() <> f_artifact() <> f_outcome() <> Nil{}), AE.BadLength{}),
      "AU-001 format: a present invocation with an empty destination denied BadLength")
    Test.check(rejected(decode_fields(2, admission_fields(empty_scope_fields(Nil{}), WField{11, [1]})), AE.BadLength{}),
      "AU-001 format: a DeniedFor outcome without its reason word denied BadLength")
    Test.check(rejected(decode_fields(3, with_outcome(WField{11, [2, 1]})), AE.BadLength{}),
      "AU-001 format: a Committed outcome with a second word denied BadLength")

def format_ranges() -> IO(Unit):
  do IO<Unit>:
    Test.check(rejected(decode_fields(3, with_phase(WField{3, [2]})), AE.OutOfRange{}),
      "AU-001 format: phase word 2 denied OutOfRange")
    Test.check(rejected(decode_fields(3, with_op(WField{9, [3]})), AE.OutOfRange{}) &&
      rejected(decode_fields(3, with_op(WField{9, [0]})), AE.OutOfRange{}),
      "AU-001 format: operation words 0 and 3 denied OutOfRange")
    Test.check(rejected(decode_fields(3, with_outcome(WField{11, [7]})), AE.OutOfRange{}),
      "AU-001 format: outcome word 7 denied OutOfRange")
    Test.check(rejected(decode_fields(2, admission_fields(empty_scope_fields(Nil{}), WField{11, [1, 10]})), AE.OutOfRange{}),
      "AU-001 format: reason word 10 denied OutOfRange")
    Test.check(rejected(decode_fields(3, with_phase(WField{3, [0]})), AE.OutOfRange{}),
      "AU-001 format: an Admission phase on a CommitAccepted event denied OutOfRange")
    Test.check(rejected(decode_fields(1, committed_fields()), AE.OutOfRange{}),
      "AU-001 format: a Committed outcome under kind AdmissionAdmitted denied OutOfRange")
    Test.check(rejected(decode_fields(4, with_outcome(WField{11, [3]})), AE.OutOfRange{}) &&
      rejected(decode_fields(1, f_id() <> f_subject() <> WField{3, [0]} <> scope_fields([f_artifact(), WField{11, [0]}])), AE.OutOfRange{}),
      "AU-001 format: an artifact on a CommitRejected or AdmissionAdmitted event denied OutOfRange")
    Test.check(rejected(decode_fields(2, admission_fields(scope_fields(Nil{}), WField{11, [1, 1]})), AE.OutOfRange{}) &&
      rejected(decode_fields(2, admission_fields(empty_scope_fields(Nil{}), WField{11, [1, 3]})), AE.OutOfRange{}),
      "AU-001 format: a scope on a Stale denial, or none on a Read denial, denied OutOfRange")
    Test.check(rejected(decode_fields(3, committed_parts(f_phase(), empty_scope_fields([f_artifact(), f_outcome()]))), AE.OutOfRange{}),
      "AU-001 format: a CommitAccepted event without a scope denied OutOfRange")

# The fixed check order: each input fails two checks and must report the
# earlier one.
def format_check_order() -> IO(Unit):
  do IO<Unit>:
    Test.check(rejected(AE.decode(2 <> List.replicate(U32, 85n, 1)), AE.TooLong{}),
      "AU-001 format order: the length cap precedes the version")
    Test.check(rejected(AE.decode(raw(2, 5, 53, committed_fields())), AE.UnknownVersion{}),
      "AU-001 format order: the version precedes the kind")
    Test.check(rejected(AE.decode(raw(1, 5, 52, committed_fields())), AE.UnknownKind{}),
      "AU-001 format order: the kind precedes the body length")
    Test.check(rejected(decode_fields(3, WField{1, [1001, 1001]} <> f_subject() <> WField{12, payload_words()} <> Nil{}), AE.NotAllowed{}),
      "AU-001 format order: the field walk precedes field widths")
    Test.check(rejected(decode_fields(1, with_stamp_field(WField{7, [1010]})), AE.BadLength{}) &&
      rejected(decode_fields(1, with_phase(WField{3, [7]})), AE.OutOfRange{}) &&
      rejected(decode_fields(4, with_outcome(WField{11, [3, 3]})), AE.BadLength{}),
      "AU-001 format order: field widths and values precede coherence")

# Rejections that a mutant could otherwise turn into a coherent record: each
# input here would decode if its check were removed.
def format_isolated() -> IO(Unit):
  do IO<Unit>:
    Test.check(rejected(AE.decode(cat([1, 3, 51], cat(List.take(&2, U32, List.drop(&2, U32, committed_golden(), 3n), 50n), [11]))), AE.BadLength{}),
      "AU-001 format: a field tag with no length word denied BadLength")
    Test.check(rejected(decode_fields(1, admitted_parts(WField{3, [2]}, WField{11, [0]})), AE.OutOfRange{}),
      "AU-001 format: phase word 2 on an admission event denied OutOfRange")
    Test.check(rejected(decode_fields(1, admitted_parts(WField{3, [0]}, WField{11, [7]})), AE.OutOfRange{}),
      "AU-001 format: outcome word 7 on an admission event denied OutOfRange")
    Test.check(rejected(decode_fields(1, admitted_parts(WField{3, [0]}, WField{11, [0, 0, 0]})), AE.BadLength{}) &&
      rejected(decode_fields(1, admitted_parts(WField{3, [0]}, f_empty(11))), AE.BadLength{}),
      "AU-001 format: an outcome of three words or of none denied BadLength")
    Test.check(rejected(decode_fields(1, admitted_parts(WField{3, [0]}, WField{11, [1, 3]})), AE.OutOfRange{}) &&
      rejected(decode_fields(4, f_id() <> f_subject() <> f_phase() <> scope_fields([f_empty(10), f_outcome()])), AE.OutOfRange{}),
      "AU-001 format: an outcome contradicting only the kind (a Read denial under AdmissionAdmitted, Committed under CommitRejected) denied OutOfRange")
    Test.check(refused(AE.encode(with_kind(d_late(T.Read{}), AE.AdmissionAdmitted{}))),
      "AU-001 format: encode of a record whose kind alone contradicts its outcome is None")
    Test.check(refused(AE.field_values(AE.field_reserved_payload(), d_committed())) &&
      refused(AE.field_values(AE.field_reserved_token(), d_committed())) &&
      refused(AE.field_values(AE.field_reserved_text(), d_committed())),
      "AU-001 format: the encoder has no value for a reserved tag, so it could not emit one even if the allowlist named it")
    Test.check(format_all_separated(all_reasons_format()),
      "AU-001 format: FormatError.equal separates all seven reasons")
    Test.check(AE.DecodeResult.equal(AE.decode(committed_golden()), AE.Decoded{d_committed()}) &&
      Bool.not(AE.DecodeResult.equal(AE.decode(committed_golden()), AE.Decoded{d_rejected()})) &&
      Bool.not(AE.DecodeResult.equal(AE.decode(committed_golden()), AE.Malformed{AE.BadLength{}})) &&
      Bool.not(AE.DecodeResult.equal(AE.Malformed{AE.BadLength{}}, AE.Decoded{d_committed()})) &&
      Bool.not(AE.DecodeResult.equal(AE.Malformed{AE.BadLength{}}, AE.Malformed{AE.TooLong{}})),
      "AU-001 format: DecodeResult.equal separates events, reasons, and an event from a rejection")

def event_format() -> IO(Unit):
  do IO<Unit>:
    format_round_trips()
    format_layout()
    format_allowlist()
    format_encode_bounds()
    format_encode_coherence()
    format_header()
    format_reserved()
    format_order()
    format_widths()
    format_scope_widths()
    format_ranges()
    format_check_order()
    format_isolated()

# --- event_policy (Task 3): AU-002 event policies include observed influences --
# Every label table, sink and principal below is SYNTHETIC MONITOR STATE.
# Principals come from D.fixture(3n): Alice Named{0}, Bob Named{1}, and
# Mallory Named{2}, the outsider. Each owner's label is distinct, so a join
# or a derivation that drops one owner shows.

def alice() -> D.Principal:
  D.Named{0}

def bob() -> D.Principal:
  D.Named{1}

def mallory() -> D.Principal:
  D.Named{2}

# An owner's label: owned by and readable by that principal only.
def owner_label(+p: D.Principal) -> D.Label:
  D.Label{D.Rule{p, p}, D.Rule{D.Bottom{}, D.Bottom{}}}

def two_owner_label(+a: D.Principal, +b: D.Principal) -> D.Label:
  D.join(owner_label(a), owner_label(b))

def snapshot() -> D.Snapshot:
  D.fixture(3n)

def policy_epoch() -> Nat:
  3n

# The source secrecy and untrusted sets of the fixtures below.
def source_secrecy() -> T.Bits64:
  T.Bits64{1, 0}

def source_untrusted() -> T.Bits64:
  T.Bits64{2, 0}

def sink_with(id: Nat, label: D.Label) -> AE.Sink:
  AE.Sink{id, label, source_secrecy(), source_untrusted()}

# Sink 1 is cleared for Alice only, sink 2 for Bob only, sink 3 for both,
# sink 4 for Alice, Bob and Mallory, sink 7 for Mallory only. Sinks 5 and 6
# satisfy both owners' labels but lack the secrecy bit (5) or the untrusted
# tolerance (6).
def sink_alice() -> AE.Sink:
  sink_with(1n, owner_label(alice()))

def sink_bob() -> AE.Sink:
  sink_with(2n, owner_label(bob()))

def sink_both() -> AE.Sink:
  sink_with(3n, two_owner_label(alice(), bob()))

def sink_all() -> AE.Sink:
  sink_with(4n, D.join(two_owner_label(alice(), bob()), owner_label(mallory())))

def sink_uncleared() -> AE.Sink:
  AE.Sink{5n, two_owner_label(alice(), bob()), T.Bits64.zero(), source_untrusted()}

def sink_intolerant() -> AE.Sink:
  AE.Sink{6n, two_owner_label(alice(), bob()), source_secrecy(), T.Bits64.zero()}

def sink_mallory() -> AE.Sink:
  sink_with(7n, owner_label(mallory()))

def fixture_sinks() -> List<&2, AE.Sink>:
  [sink_alice(), sink_bob(), sink_both(), sink_all(), sink_uncleared(),
    sink_intolerant(), sink_mallory()]

def releasable(policy: AE.EventPolicy, sink: AE.Sink) -> Bool:
  AE.releasable(snapshot(), policy_epoch(), policy, sink)

def releasable_to_none(+policy: AE.EventPolicy, sinks: List<&2, AE.Sink>) -> Bool:
  match sinks:
    case []:
      True{}
    case s <> rest:
      Bool.not(releasable(policy, s)) && releasable_to_none(policy, rest)

# --- event_policy: test-side equality ------------------------------------------

def principal_eq(a: D.Principal, b: D.Principal) -> Bool:
  match a b:
    case D.Bottom{} D.Bottom{}:
      True{}
    case D.Top{} D.Top{}:
      True{}
    case D.Named{x} D.Named{y}:
      U32.is_eq(x, y)
    case D.Unsupported{} D.Unsupported{}:
      True{}
    case _ _:
      False{}

def dlm_policy_eq(a: D.Policy, b: D.Policy) -> Bool:
  match a b:
    case D.Rule{ao, ad} D.Rule{bo, bd}:
      principal_eq(ao, bo) && principal_eq(ad, bd)
    case D.Join{al, ar} D.Join{bl, br}:
      dlm_policy_eq(al, bl) && dlm_policy_eq(ar, br)
    case D.Meet{al, ar} D.Meet{bl, br}:
      dlm_policy_eq(al, bl) && dlm_policy_eq(ar, br)
    case _ _:
      False{}

def label_eq(a: D.Label, b: D.Label) -> Bool:
  match a b:
    case D.Label{ac, ai} D.Label{bc, bi}:
      dlm_policy_eq(ac, bc) && dlm_policy_eq(ai, bi)

def edge_eq(a: AE.Edge, b: AE.Edge) -> Bool:
  match a b:
    case AE.DataEdge{} AE.DataEdge{}:
      True{}
    case AE.ControlEdge{} AE.ControlEdge{}:
      True{}
    case _ _:
      False{}

def influence_eq(a: AE.Influence, b: AE.Influence) -> Bool:
  match a b:
    case AE.Influence{ao, al, ae} AE.Influence{bo, bl, be}:
      principal_eq(ao, bo) && label_eq(al, bl) && edge_eq(ae, be)

def influences_eq(a: AE.Influences, b: AE.Influences) -> Bool:
  match a b:
    case AE.NoInfluences{} AE.NoInfluences{}:
      True{}
    case AE.Influenced{ah, at} AE.Influenced{bh, bt}:
      influence_eq(ah, bh) && influences_eq(at, bt)
    case _ _:
      False{}

# The test-side EventPolicy.equal: influences in order, secrecy, untrusted.
def event_policy_equal(a: AE.EventPolicy, b: AE.EventPolicy) -> Bool:
  match a b:
    case AE.EventPolicy{ax, as, au} AE.EventPolicy{bx, bs, bu}:
      influences_eq(ax, bx) && T.Bits64.equal(as, bs) && T.Bits64.equal(au, bu)

def has_influence(xs: AE.Influences, +wanted: AE.Influence) -> Bool:
  match xs:
    case AE.NoInfluences{}:
      False{}
    case AE.Influenced{h, t}:
      influence_eq(h, wanted) || has_influence(t, wanted)

def owners_eq(a: AE.Owners, b: AE.Owners) -> Bool:
  match a b:
    case AE.NoOwners{} AE.NoOwners{}:
      True{}
    case AE.Owned{ah, at} AE.Owned{bh, bt}:
      principal_eq(ah, bh) && owners_eq(at, bt)
    case _ _:
      False{}

def data_of(+p: D.Principal) -> AE.Influence:
  AE.Influence{p, owner_label(p), AE.DataEdge{}}

def control_of(+p: D.Principal) -> AE.Influence:
  AE.Influence{p, owner_label(p), AE.ControlEdge{}}

def maximal_data() -> AE.Influence:
  AE.Influence{D.Top{}, D.maximal_restriction(), AE.DataEdge{}}

def maximal_control() -> AE.Influence:
  AE.Influence{D.Top{}, D.maximal_restriction(), AE.ControlEdge{}}

# --- event_policy: "Denial reveals a protected source fact" -------------------

# Bob's source object 11 and Alice's destination object 20 (TF's destination).
def bob_source() -> T.ObjectVersion:
  T.ObjectVersion{11n, 4n}

def bob_plan() -> T.Plan:
  T.Plan{TF.stamp(), 99n, T.OCons{bob_source(), T.OEnd{}}, TF.destination_object(),
    TF.code(), T.Summarize{}, 2}

# A SYNTHETIC monitor context for bob_plan: one source policy for object 11
# (schema, approved codes and payment rule as given), TF's destination and
# operation, read and write grants bound to the plan, and `pays`.
def bob_context(schema: U32, codes: T.Codes, payment: T.PaymentRule, pays: T.Payments) -> T.Context:
  +s = TF.scope_for(bob_plan(), T.WriteDomain{6n}, 200n)
  T.Context{TF.stamp(), 100n,
    T.SCons{T.SourcePolicy{bob_source(), T.ReadDomain{5n}, schema, 2n, source_secrecy(), source_untrusted(), 7,
      T.RCons{T.OriginRule{bob_source(), source_secrecy(), source_untrusted(), 7, codes, payment}, T.REnd{}}}, T.SEnd{}},
    TF.destination(), TF.operation(),
    T.ReadCons{T.ReadGrant{bob_source(), T.ReadDomain{5n}, s}, T.ReadEnd{}},
    T.WriteCons{T.WriteGrant{TF.destination_object(), T.WriteDomain{6n}, s}, T.WriteEnd{}}, pays}

def bob_witness() -> T.Payments:
  T.PayCons{T.PaymentWitness{1n, bob_source(), 99n, TF.code(), T.Summarize{},
    TF.destination_object(), 42n, 200n}, T.PayEnd{}}

def bob_admitted_context() -> T.Context:
  bob_context(1, TF.one_code(TF.code()), T.Charge{42n, 4}, bob_witness())

# The origin rule's approved codes leave out the plan's code.
def bob_origin_context() -> T.Context:
  bob_context(1, TF.one_code(TF.other_code()), T.Charge{42n, 4}, bob_witness())

def bob_payment_context() -> T.Context:
  bob_context(1, TF.one_code(TF.code()), T.Charge{42n, 4}, T.PayEnd{})

def bob_schema_context() -> T.Context:
  bob_context(3, TF.one_code(TF.code()), T.Charge{42n, 4}, bob_witness())

def bob_labels() -> AE.Labels:
  AE.Labelled{AE.ObjectLabel{bob_source(), bob(), owner_label(bob())},
    AE.Labelled{AE.ObjectLabel{TF.destination_object(), alice(), owner_label(alice())}, AE.NoLabels{}}}

def admit_labelled(+plan: T.Plan, context: T.Context, labels: AE.Labels, subject: Nat) -> AE.AuditedAdmission:
  AE.audited_admit(plan, context, labels, FT.caller(subject), empty_diagnostic(), event_id())

def admission_policy_of(a: AE.AuditedAdmission) -> AE.EventPolicy:
  AE.Recorded.policy(AE.AuditedAdmission.recorded(a))

# Alice (subject 0) asks for Bob's object 11.
def bob_audited(context: T.Context) -> AE.AuditedAdmission:
  admit_labelled(bob_plan(), context, bob_labels(), 0n)

def bob_policy(context: T.Context) -> AE.EventPolicy:
  admission_policy_of(bob_audited(context))

# The denial is the library's, the event records the reason, its influences
# hold Bob's label as data and as control, and it reaches the both-owners
# sink but not Alice's.
def protected_denial(+context: T.Context, +reason: T.Denial) -> Bool:
  +audited = bob_audited(context)
  +xs = AE.EventPolicy.influences(admission_policy_of(audited))
  TF.denied_as(AE.AuditedAdmission.decision(audited), reason) &&
    denied_for(AE.EventRecord.outcome(AE.AuditedAdmission.event(audited)), reason) &&
    has_influence(xs, data_of(bob())) && has_influence(xs, control_of(bob()))

def withheld_from_alice(+context: T.Context) -> Bool:
  +policy = bob_policy(context)
  Bool.not(releasable(policy, sink_alice())) && releasable(policy, sink_both())

def denial_reveals() -> IO(Unit):
  do IO<Unit>:
    Test.check(protected_denial(bob_origin_context(), T.Origin{}),
      "AU-002 denial reveals a protected source fact: an Origin denial for Bob's object 11 is recorded DeniedFor Origin with Bob's label as data and as control")
    Test.check(withheld_from_alice(bob_origin_context()),
      "AU-002 denial reveals a protected source fact: the Origin denial event is not releasable to Alice-only sink 1 and is releasable to sink 3")
    Test.check(protected_denial(bob_payment_context(), T.Payment{}) && withheld_from_alice(bob_payment_context()),
      "AU-002 denial reveals a protected source fact: a Payment denial carries Bob's label, withheld from sink 1, released to sink 3")
    Test.check(protected_denial(bob_schema_context(), T.Schema{}) && withheld_from_alice(bob_schema_context()),
      "AU-002 denial reveals a protected source fact: a Schema denial carries Bob's label, withheld from sink 1, released to sink 3")
    Test.check(Bool.not(releasable(bob_policy(bob_origin_context()), sink_bob())) &&
      Bool.not(releasable(bob_policy(bob_origin_context()), sink_mallory())),
      "AU-002 the Origin denial event is withheld from Bob-only sink 2 (Alice's destination and request) and from Mallory's sink 7")
    Test.check(has_influence(AE.EventPolicy.influences(bob_policy(bob_origin_context())), data_of(alice())) &&
      has_influence(AE.EventPolicy.influences(bob_policy(bob_origin_context())), control_of(alice())),
      "AU-002 the destination's owner label is an influence as data and as control")
    Test.check(AE.EventRecord.equal(AE.Recorded.event(AE.AuditedAdmission.recorded(bob_audited(bob_origin_context()))),
      AE.AuditedAdmission.event(bob_audited(bob_origin_context()))),
      "AU-002 the record holds the same event the wrapper returns")

# --- event_policy: the requester's influence (Task 1 obligation 1) -------------

def requester_of(+p: D.Principal) -> AE.Influence:
  AE.Influence{p, owner_label(p), AE.ControlEdge{}}

def mallory_policy() -> AE.EventPolicy:
  admission_policy_of(admit_labelled(bob_plan(), bob_origin_context(), bob_labels(), 2n))

def requester_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(has_influence(AE.EventPolicy.influences(bob_policy(bob_origin_context())), requester_of(alice())),
      "AU-002 an admission event carries the requester's own label (Alice, subject 0) as a control influence")
    Test.check(has_influence(AE.EventPolicy.influences(mallory_policy()), requester_of(mallory())) &&
      Bool.not(releasable(mallory_policy(), sink_both())) && releasable(mallory_policy(), sink_all()),
      "AU-002 Mallory's denied request is withheld from the Alice-and-Bob sink 3, which may not learn that Mallory asked, and released to sink 4")
    Test.check(has_influence(AE.EventPolicy.influences(admission_policy_of(admit_labelled(bob_plan(), bob_origin_context(), bob_labels(), two_32()))), maximal_control()) &&
      influence_eq(AE.requester_influence(two_32()), maximal_control()) &&
      influence_eq(AE.requester_influence(0n), requester_of(alice())),
      "AU-002 a subject of 2^32 does not wrap onto Alice's id 0: its requester influence is the maximal restriction")
    Test.check(releasable_to_none(admission_policy_of(admit_labelled(bob_plan(), bob_origin_context(), bob_labels(), 7n)), fixture_sinks()),
      "AU-002 a requester outside the DLM registry (subject 7) makes the event releasable to no fixture sink")

# --- event_policy: "Multiple owners contribute evidence" ----------------------

# Bob's source 11 and Alice's second source 12, Alice's destination 20.
def alice_source() -> T.ObjectVersion:
  T.ObjectVersion{12n, 4n}

def shared_plan() -> T.Plan:
  T.Plan{TF.stamp(), 99n, T.OCons{bob_source(), T.OCons{alice_source(), T.OEnd{}}},
    TF.destination_object(), TF.code(), T.Summarize{}, 2}

# A second Alice entry added to bob_labels().
def shared_labels() -> AE.Labels:
  AE.Labelled{AE.ObjectLabel{alice_source(), alice(), owner_label(alice())}, bob_labels()}

# vouched_context gives one source policy per manifest object, so every
# object the context names is in the table.
def shared_policy() -> AE.EventPolicy:
  admission_policy_of(admit_labelled(shared_plan(), vouched_context(shared_plan()), shared_labels(), 0n))

# Bob's label for object 11, Alice's for objects 12 and 20, and Alice as the
# requester: two owners, first Bob (the first source), then Alice.
def multiple_owners() -> IO(Unit):
  +xs = AE.EventPolicy.influences(shared_policy())
  do IO<Unit>:
    Test.check(has_influence(xs, data_of(bob())) && has_influence(xs, data_of(alice())) &&
      owners_eq(AE.event_owners(xs), AE.Owned{bob(), AE.Owned{alice(), AE.NoOwners{}}}),
      "AU-002 multiple owners contribute evidence: Bob and Alice are separate influences and event_owners gives Bob then Alice")
    Test.check(Bool.not(has_influence(xs, AE.Influence{alice(), two_owner_label(alice(), bob()), AE.DataEdge{}})) &&
      Bool.not(has_influence(xs, AE.Influence{bob(), two_owner_label(bob(), alice()), AE.DataEdge{}})),
      "AU-002 multiple owners contribute evidence: no owner's influence is merged into another's label")
    Test.check(Bool.not(releasable(shared_policy(), sink_alice())) && releasable(shared_policy(), sink_both()),
      "AU-002 multiple owners contribute evidence: a sink satisfying Alice but not Bob is withheld, one satisfying both is released")
    Test.check(has_influence(xs, data_of(bob())) && has_influence(xs, control_of(bob())) &&
      has_influence(AE.EventPolicy.influences(admission_policy_of(admit_labelled(shared_plan(), vouched_context(shared_plan()), bob_labels(), 0n))), data_of(bob())),
      "AU-002 multiple owners contribute evidence: a second Alice entry in the label table does not remove Bob's influence")
    Test.check(owners_eq(AE.event_owners(AE.NoInfluences{}), AE.NoOwners{}) &&
      owners_eq(AE.event_owners(AE.Influenced{data_of(alice()), AE.Influenced{data_of(alice()), AE.NoInfluences{}}}),
        AE.Owned{alice(), AE.NoOwners{}}),
      "AU-002 event_owners lists each owner once")

# --- event_policy: fail closed on the label table -----------------------------

# Object 11 has no entry; object 11 has two identical entries; object 11 has
# two entries naming different owners.
def unlabelled() -> AE.Labels:
  AE.Labelled{AE.ObjectLabel{TF.destination_object(), alice(), owner_label(alice())}, AE.NoLabels{}}

def duplicated() -> AE.Labels:
  AE.Labelled{AE.ObjectLabel{bob_source(), bob(), owner_label(bob())}, bob_labels()}

def conflicting() -> AE.Labels:
  AE.Labelled{AE.ObjectLabel{bob_source(), alice(), owner_label(alice())}, bob_labels()}

def table_policy(labels: AE.Labels) -> AE.EventPolicy:
  admission_policy_of(admit_labelled(bob_plan(), bob_origin_context(), labels, 0n))

def lookup_missing(x: AE.LabelLookup) -> Bool:
  match x:
    case AE.LabelMissing{}:
      True{}
    case _:
      False{}

def lookup_ambiguous(x: AE.LabelLookup) -> Bool:
  match x:
    case AE.LabelAmbiguous{}:
      True{}
    case _:
      False{}

def fails_closed(+labels: AE.Labels) -> Bool:
  +xs = AE.EventPolicy.influences(table_policy(labels))
  has_influence(xs, maximal_data()) && has_influence(xs, maximal_control()) &&
    Bool.not(has_influence(xs, data_of(bob()))) && releasable_to_none(table_policy(labels), fixture_sinks())

def table_fail_closed() -> IO(Unit):
  do IO<Unit>:
    Test.check(lookup_missing(AE.label_lookup(unlabelled(), bob_source())) && fails_closed(unlabelled()),
      "AU-002 an unlabelled source gives the maximal-restriction influence and the event is releasable to no fixture sink")
    Test.check(lookup_ambiguous(AE.label_lookup(duplicated(), bob_source())) && fails_closed(duplicated()),
      "AU-002 two identical label entries for one object give the maximal-restriction influence and no fixture sink")
    Test.check(lookup_ambiguous(AE.label_lookup(conflicting(), bob_source())) && fails_closed(conflicting()),
      "AU-002 two label entries naming different owners give the maximal-restriction influence and no fixture sink")
    Test.check(releasable_to_none(table_policy(AE.NoLabels{}), fixture_sinks()),
      "AU-002 an empty label table gives an event releasable to no fixture sink")
    Test.check(influence_eq(AE.object_influence(unlabelled(), bob_source(), AE.DataEdge{}), maximal_data()) &&
      influence_eq(AE.object_influence(duplicated(), bob_source(), AE.ControlEdge{}), maximal_control()) &&
      influence_eq(AE.object_influence(bob_labels(), bob_source(), AE.DataEdge{}), data_of(bob())),
      "AU-002 object_influence returns the table entry, or the maximal restriction on a missing or ambiguous entry")

# --- event_policy: secrecy, untrusted influence and the snapshot epoch --------

# One source with secrecy {1} and untrusted {2}, whose origin rule adds
# secrecy {4} and untrusted {8}; TF.pair_context's two sources.
def origin_bits_context() -> T.Context:
  TF.with_origin(TF.context(), T.RCons{T.OriginRule{TF.source_object(),
    T.Bits64{4, 0}, T.Bits64{8, 0}, 7, TF.one_code(TF.code()), T.Free{}}, T.REnd{}}, 7)

# Two origin rules on one source: secrecy {4} and {16}, untrusted {8} and {32}.
def two_origins_context() -> T.Context:
  TF.with_origin(TF.context(), T.RCons{T.OriginRule{TF.source_object(),
    T.Bits64{4, 0}, T.Bits64{8, 0}, 7, TF.one_code(TF.code()), T.Free{}},
    T.RCons{T.OriginRule{TF.source_object(), T.Bits64{16, 0}, T.Bits64{32, 0}, 7,
      TF.one_code(TF.code()), T.Free{}}, T.REnd{}}}, 7)

def secrecy_checks() -> IO(Unit):
  +policy = bob_policy(bob_origin_context())
  do IO<Unit>:
    Test.check(releasable(policy, sink_both()) && Bool.not(releasable(policy, sink_uncleared())),
      "AU-002 a sink whose DLM label flows but whose clearance lacks the source's secrecy bit is withheld")
    Test.check(Bool.not(releasable(policy, sink_intolerant())),
      "AU-002 a sink whose DLM label flows but which does not tolerate the source's untrusted bit is withheld")
    Test.check(T.Bits64.equal(AE.EventPolicy.secrecy(policy), source_secrecy()) &&
      T.Bits64.equal(AE.EventPolicy.untrusted(policy), source_untrusted()),
      "AU-002 the event's secrecy and untrusted sets are the source policy's")
    Test.check(T.Bits64.equal(AE.context_secrecy(TF.pair_context()), T.Bits64{5, 2147483648}) &&
      T.Bits64.equal(AE.context_untrusted(TF.pair_context()), T.Bits64{10, 0}),
      "AU-002 context secrecy and untrusted sets join every source policy in the context")
    Test.check(T.Bits64.equal(AE.context_secrecy(origin_bits_context()), T.Bits64{5, 0}) &&
      T.Bits64.equal(AE.context_untrusted(origin_bits_context()), T.Bits64{10, 0}),
      "AU-002 context secrecy and untrusted sets include an origin rule's bits outside its source's")
    Test.check(T.Bits64.equal(AE.context_secrecy(two_origins_context()), T.Bits64{21, 0}) &&
      T.Bits64.equal(AE.context_untrusted(two_origins_context()), T.Bits64{42, 0}),
      "AU-002 context secrecy and untrusted sets join every origin rule of a source")
    Test.check(Bool.not(AE.releasable(snapshot(), 4n, policy, sink_both())),
      "AU-002 an event is withheld when the snapshot epoch is not the expected epoch")

# --- event_policy: the policy is outcome-independent --------------------------

def outcome_independent() -> IO(Unit):
  do IO<Unit>:
    Test.check(T.accepted(AE.AuditedAdmission.decision(bob_audited(bob_admitted_context()))) &&
      event_policy_equal(bob_policy(bob_admitted_context()), bob_policy(bob_origin_context())),
      "AU-002 an admitted event and an Origin-denied event for the same plan and label table have equal influences, secrecy and untrusted sets")
    Test.check(event_policy_equal(bob_policy(bob_admitted_context()), bob_policy(bob_payment_context())) &&
      event_policy_equal(bob_policy(bob_admitted_context()), AE.admission_policy(bob_plan(), bob_admitted_context(), bob_labels(), 0n)),
      "AU-002 a Payment-denied event has the admitted event's policy, which is admission_policy of the request")
    Test.check(Bool.not(event_policy_equal(bob_policy(bob_admitted_context()), mallory_policy())) &&
      Bool.not(event_policy_equal(bob_policy(bob_origin_context()), table_policy(unlabelled()))),
      "AU-002 the test-side EventPolicy.equal separates a different requester and a different label table")

# --- event_policy: control copies and the context's own policies --------------

# The context's source policy names object 13 (labelled Mallory) while the
# plan names 11: admission denies, and the denial depends on object 13's
# policy, so Mallory's label is a control influence.
def foreign_policy_context() -> T.Context:
  TF.with_sources(bob_admitted_context(), T.SCons{T.SourcePolicy{T.ObjectVersion{13n, 4n}, T.ReadDomain{5n}, 1, 2n,
    source_secrecy(), source_untrusted(), 7, T.RCons{TF.origin(), T.REnd{}}}, T.SEnd{}})

def foreign_labels() -> AE.Labels:
  AE.Labelled{AE.ObjectLabel{T.ObjectVersion{13n, 4n}, mallory(), owner_label(mallory())}, bob_labels()}

# TF.pair_context names source policies for objects 10 and 30 and a
# destination policy for object 20; each gets its own owner here.
def pair_policy_labels() -> AE.Labels:
  AE.Labelled{AE.ObjectLabel{TF.source_object(), bob(), owner_label(bob())},
    AE.Labelled{AE.ObjectLabel{TF.second_object(), alice(), owner_label(alice())},
      AE.Labelled{AE.ObjectLabel{TF.destination_object(), mallory(), owner_label(mallory())}, AE.NoLabels{}}}}

def control_checks() -> IO(Unit):
  +xs = AE.EventPolicy.influences(bob_policy(bob_origin_context()))
  +foreign = AE.EventPolicy.influences(admission_policy_of(admit_labelled(bob_plan(), foreign_policy_context(), foreign_labels(), 0n)))
  do IO<Unit>:
    Test.check(influences_eq(AE.decision_influences(bob_labels(), bob_plan()),
      AE.Influenced{data_of(bob()), AE.Influenced{data_of(alice()),
        AE.Influenced{control_of(bob()), AE.Influenced{control_of(alice()), AE.NoInfluences{}}}}}),
      "AU-002 decision_influences is the sources and destination as data, then the same objects as control")
    Test.check(influences_eq(AE.source_influences(shared_labels(), T.Plan.sources(shared_plan())),
      AE.Influenced{data_of(bob()), AE.Influenced{data_of(alice()), AE.NoInfluences{}}}),
      "AU-002 source_influences gives one data influence per source in manifest order")
    Test.check(TF.denied_as(AE.AuditedAdmission.decision(admit_labelled(bob_plan(), foreign_policy_context(), foreign_labels(), 0n)), T.Source{}) &&
      has_influence(foreign, control_of(mallory())) && Bool.not(has_influence(foreign, data_of(mallory()))),
      "AU-002 a context source policy for another object (13, Mallory's) is a control influence of the Source denial")
    Test.check(has_influence(xs, control_of(bob())) && has_influence(xs, control_of(alice())),
      "AU-002 the control copies of the plan's objects are on the event")
    Test.check(influences_eq(AE.context_influences(pair_policy_labels(), TF.pair_context()),
      AE.Influenced{control_of(bob()), AE.Influenced{control_of(alice()),
        AE.Influenced{control_of(mallory()), AE.NoInfluences{}}}}),
      "AU-002 context_influences is every context source policy's object, then the destination policy's object, as control")

# --- event_policy: commit events and the resolved binding ---------------------
# NF.running()'s plan is TF.plan(): Bob's source 10, Alice's destination 20.
# The committing subject is 7, so these checks use a SYNTHETIC registry of
# eight named principals (0 to 7, no delegations) in which subject 7 is a
# registered principal.

def commit_labels() -> AE.Labels:
  AE.Labelled{AE.ObjectLabel{TF.source_object(), bob(), owner_label(bob())},
    AE.Labelled{AE.ObjectLabel{TF.destination_object(), alice(), owner_label(alice())}, AE.NoLabels{}}}

def commit_labelled(context: OS.Context, subject: Nat) -> AE.AuditedCommit:
  AE.audited_commit(NF.running(), 6n, 1n, NF.held_ledger(), BF.candidate(),
    F.Ref{FT.caller(subject), 2n}, 2n, context, commit_labels(), empty_diagnostic(), event_id())

def commit_policy_of(context: OS.Context, subject: Nat) -> AE.EventPolicy:
  AE.Recorded.policy(AE.AuditedCommit.recorded(commit_labelled(context, subject)))

def prepared_or_fixture(m: Maybe<&2, D.Snapshot>) -> D.Snapshot:
  match m:
    case Some{s}:
      s
    case None{}:
      D.fixture(3n)

def eight_principals() -> D.Snapshot:
  prepared_or_fixture(D.prepare(3n, 8, D.NoEdges{}))

def subject_seven() -> D.Principal:
  D.Named{7}

# A binding whose labels are Mallory's: the binding's source label and its
# destination label are joined into one control influence, owned by Alice.
def mallory_binding_context() -> OS.Context:
  OS.Context{BF.with_binding(BF.context(), B.Binding{NF.request(), BF.graph(), BF.sink(),
    owner_label(mallory()), owner_label(mallory()), B.Storage{}, BF.artifact()}),
    FT.descriptor(7n, 7), FT.registry(7n, 7)}

def no_binding_context() -> OS.Context:
  OS.Context{BF.with_bindings(BF.context(), B.NoBindings{}), FT.descriptor(7n, 7), FT.registry(7n, 7)}

# Alice, Bob and subject 7; with Mallory added.
def commit_sink() -> AE.Sink:
  sink_with(8n, D.join(two_owner_label(alice(), bob()), owner_label(subject_seven())))

def commit_sink_mallory() -> AE.Sink:
  sink_with(9n, D.join(D.join(two_owner_label(alice(), bob()), owner_label(subject_seven())), owner_label(mallory())))

def commit_releasable(policy: AE.EventPolicy, sink: AE.Sink) -> Bool:
  AE.releasable(eight_principals(), 3n, policy, sink)

def binding_checks() -> IO(Unit):
  +xs = AE.EventPolicy.influences(commit_policy_of(FT.context(), 7n))
  +mx = AE.EventPolicy.influences(commit_policy_of(mallory_binding_context(), 7n))
  do IO<Unit>:
    Test.check(B.accepted(AE.AuditedCommit.result(commit_labelled(FT.context(), 7n))) &&
      has_influence(xs, AE.binding_influence(BF.binding(), alice())) &&
      has_influence(xs, AE.Influence{alice(), D.join(D.secret_untrusted(), D.secret_untrusted()), AE.ControlEdge{}}),
      "AU-002 a commit event's policy includes BF.binding()'s joined source and destination labels as a control influence owned by the destination's owner")
    Test.check(has_influence(mx, AE.Influence{alice(), D.join(owner_label(mallory()), owner_label(mallory())), AE.ControlEdge{}}) &&
      Bool.not(has_influence(mx, AE.binding_influence(BF.binding(), alice()))),
      "AU-002 the commit binding influence follows the resolved binding's labels")
    Test.check(commit_releasable(commit_policy_of(FT.context(), 7n), commit_sink()) &&
      Bool.not(commit_releasable(commit_policy_of(mallory_binding_context(), 7n), commit_sink())) &&
      commit_releasable(commit_policy_of(mallory_binding_context(), 7n), commit_sink_mallory()),
      "AU-002 a committed event is withheld from a sink that satisfies the object and requester labels but not the binding's")
    Test.check(Bool.not(B.accepted(AE.AuditedCommit.result(commit_labelled(no_binding_context(), 7n)))) &&
      has_influence(AE.EventPolicy.influences(commit_policy_of(no_binding_context(), 7n)), maximal_control()),
      "AU-002 a commit with no resolvable binding carries the maximal-restriction control influence")
    Test.check(has_influence(xs, requester_of(subject_seven())) && has_influence(xs, data_of(bob())) &&
      has_influence(xs, control_of(alice())) &&
      T.Bits64.equal(AE.EventPolicy.secrecy(commit_policy_of(FT.context(), 7n)), source_secrecy()) &&
      T.Bits64.equal(AE.EventPolicy.untrusted(commit_policy_of(FT.context(), 7n)), source_untrusted()),
      "AU-002 a commit event carries the requester, the session plan's objects and the transfer context's secrecy and untrusted sets")
    Test.check(AE.EventRecord.equal(AE.Recorded.event(AE.AuditedCommit.recorded(commit_labelled(FT.context(), 7n))),
      AE.AuditedCommit.event(commit_labelled(FT.context(), 7n))),
      "AU-002 the commit record holds the same event the wrapper returns")
    Test.check(event_policy_equal(commit_policy_of(revoked_context(), 7n), commit_policy_of(FT.context(), 7n)),
      "AU-002 a rejected commit has the accepted commit's policy (the policy does not read the result)")

def event_policy() -> IO(Unit):
  do IO<Unit>:
    denial_reveals()
    requester_checks()
    multiple_owners()
    table_fail_closed()
    secrecy_checks()
    outcome_independent()
    control_checks()
    binding_checks()

def main() -> IO(Unit):
  do IO<Unit>:
    event_projection()
    event_format()
    event_policy()
    IO.print("Audit: 191 checks passed")
