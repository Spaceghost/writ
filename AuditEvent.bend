import Base
import ./Core.bend as C
import ./Transfer.bend as T
import ./Ledger.bend as L
import ./Frontend.bend as F
import ./Backplane.bend as B
import ./Negotiation.bend as N
import ./Dlm.bend as D
import ./DataOS.bend as OS

# Policy-aware AUDIT EVENT MODEL (change add-policy-aware-audit, AU-001 and
# the model part of AU-005). An audit event is a PROJECTION of exactly one
# library decision, never a second decision. Each wrapper below calls the
# library once (the transfer admission check, or the DataOS capability commit
# facade), binds that result, returns it unchanged and projects the event from
# it. This module recomputes no accept/deny outcome, re-runs no gate to find a
# reason, produces no WriteIntent, never calls the backplane's commit
# transition directly, and adds no release route and no declassification. It
# performs no IO, storage append, cryptography or signature verification.
#
# Why a wrapper cannot alter the library result (structural, not by care):
# - The returned decision or commit result is the variable bound to the single
#   library call; the record holding it is built from that variable.
# - The projections consume the library value and return only `Outcome`,
#   `Scope`, `Maybe<ArtifactId>` or `EventRecord`. None of those types holds a
#   Decision, a CommitResult, a session or a ledger, so nothing computed while
#   projecting can flow back into what the wrapper returns.
# - No def in this module constructs a `T.Decision` or `B.CommitResult`; those
#   constructors appear here only as match patterns.
# - The laws `audit_admit_returns_library_decision` and
#   `audit_commit_returns_library_result` state the equality for all inputs.
#
# Allowlist: what each field is and the check under which it entered the
# event. The type is the allowlist; nothing else can be stored.
# - `version`: the constant `event_format_version()`.
# - `kind`, `phase`: functions of `outcome` (`kind_of`, `phase_of`).
# - `event_id`: the monitor's fresh identifier, a trusted parameter.
# - `subject`: the frontend-authenticated subject (`F.Caller.subject`, or the
#   Ref's caller subject via `OS.subject`). On commit the facade additionally
#   requires that subject to own the descriptor and to be the negotiated
#   reader; on admission it is the host's transport-verified identity, which
#   `T.admit` does not consult. The caller token is never read.
# - `scope` (invocation, ordered source versions, destination version, the
#   stamp's graph, policy and authority epochs, code, operation kind). These
#   are fields of a plan, so they can carry arbitrary caller-chosen numbers
#   and are NOT free of caller text by type. They are admitted only when a
#   monitor-installed authority has bound them:
#   - Admission: `T.admit` checks, in order, the stamp against the live epochs
#     (Stale), the manifest shape (Source), the destination object
#     (Destination), code and kind (Operation), output schema (Schema), the
#     destination's kinds (Destination) and finally a write grant whose scope
#     names the plan's exact invocation, ordered inputs, destination, code,
#     kind and stamp (Write). Only once that write grant matched is every
#     scope field bound to a monitor-installed grant. `Read`, `Origin` and
#     `Payment` arise only after that point, so their events and admitted
#     events carry `ScopeRead`. Every reason that can arise earlier (`Stale`,
#     `Source`, `Destination`, `Operation`, `Schema`, `Write`) carries
#     `ScopeNotRead{}`, which has no fields, so nothing the caller wrote can
#     appear. `InvalidPolicy` also carries `ScopeNotRead{}` (controller
#     ruling, fail closed). The classification is by the reason the library
#     returned (`denial_reads_scope`), never by re-running a check; a reason
#     that can occur both early and late is treated as early.
#   - Commit: the plan of the session the facade was given, which is
#     monitor-owned negotiated state (owner approvals, budget, hold), not a
#     proposal made at this call. It is recorded for accepted and rejected
#     commits alike.
# - `artifact`: on an accepted commit only, the sealed artifact id from the
#   WriteIntent. It is a digest DERIVED FROM THE OUTPUT'S CONTENT, so it
#   enables confirmation of low-entropy outputs.
# - `outcome`: a closed constructor; `DeniedFor` carries the closed `T.Denial`
#   the library returned, never text. A commit rejection carries no reason:
#   `Backplane.Rejected` exposes none, and finding one would re-run the gates.
# Excluded by construction (no field can hold them): payload bytes, error
# text, credentials, the capability or caller token, grants and grant scope
# objects, payment witnesses and receipts, request bodies, the plan's output
# type.
#
# Confidentiality of the allowed fields is the event policy's job (Task 3),
# not the type's. Task 3 obligations recorded here:
# 1. Every admission event's policy includes the requesting subject's
#    influence (a control edge with the requester's label or clearance), or
#    the event fails closed: even a vouched scope and the denial reason are
#    shaped by what the requester chose to ask.
# 2. Every commit event's policy includes the resolved `Backplane.Binding`'s
#    source and destination labels and is never released below the output's
#    label, because `artifact` is a digest of the sealed content.
#
# Trusted inputs (supplied by the monitor, never by the caller):
# - `event_id`, a fresh identifier (Bend generates none); query views and
#   exports omit it, it exists for durable idempotency (section 2).
# - `labels`, the monitor-owned object label table (consumed from Task 3 on;
#   unused by these projections).
# - The transfer context and the DataOS context, exactly as the library's own
#   entry points require them.
# - The caller's subject as already authenticated by the frontend.
# `Diagnostic` is the raw failure material a host may hold (payload, error
# text, credential, token). The wrappers take it, and the caller, as
# parameters so that the laws can show both are dropped; this module has no
# accessor for it, so `grep -c 'Diagnostic[.]' AuditEvent.bend` is 0.
#
# Constructing an audit record authenticates nothing. `EventRecord`, `Diagnostic`,
# `AuditedAdmission` and `AuditedCommit` are public Data records, a model, not
# unforgeable evidence: an event is evidence of a decision only when it came
# from a wrapper here in the same invocation as that decision. Recording does
# not make the decision durable, does not append to any log, and does not
# consume a reservation (a rejected commit keeps the caller's session and
# ledger because the facade's result is returned unchanged).
#
# Canonical encoding (format version 1; AU-001 "versioned canonical binary
# event format with an allowlist of fields"). The encoder and decoder are a
# BOUNDARY, NOT POLICY: they decide nothing about authority, visibility or
# release, and a decoded event is a description of a record, not evidence
# that any decision happened (only a wrapper's own output is that). Decoding
# yields an `EventRecord` or exactly one `FormatError`, never a partial
# record and never a field the allowlist does not name.
# - `field_allowlist()` is the single allowlist: the ordered tags 1 to 11
#   (`field_event_id` ... `field_outcome`). The encoder emits exactly those
#   fields in that order, the decoder walks exactly those tags in that order,
#   and `field_allowed` reads that list. Tags 12, 13 and 14
#   (`field_reserved_payload`, `_token`, `_text`) are reserved and never
#   allowed; the version field is the header's, not a body field.
# - Layout: every value is one little-endian U32 word, as in HostWire (a byte
#   transport, when one exists, carries each word least significant byte
#   first). Header: `event_format_version()`, the kind tag
#   (`kind_admission_admitted()` 1 ... `kind_commit_rejected()` 4), the body
#   length in words. Body: every allowlisted field in order, each a tag word,
#   a length word and that many value words. Widths: event id, subject,
#   phase, invocation and operation kind (`T.OpKind.bit`) one word each; an
#   object version two (object, version); sources two per entry, at most
#   `max_sources()` entries; the stamp three (graph, policy, authority); the
#   code eight; the artifact eight, or length 0 for None; the outcome one
#   word (`outcome_tag`), plus one `reason_tag` word for DeniedFor. Under
#   `ScopeNotRead{}` every scope field (invocation to operation kind) is
#   present with length 0; the invocation field's length selects the scope.
# - `encode` returns None, never a truncated list, when a Nat field is at or
#   above `word_limit()` (2^32), when there are more than `max_sources()`
#   sources, or when the record is not coherent (`event_coherent`: the
#   version is the format's and kind, phase, artifact and scope relate to the
#   outcome as `project` relates them). So every word list `encode` returns
#   decodes to its event.
# - Decode check order (fixed; input ending before a header word is BadLength
#   at that step):
#   1. length cap: more than `max_words()` words         -> TooLong
#   2. version: word 0 is not `event_format_version()`    -> UnknownVersion
#   3. kind: word 1 is not one of the four kind tags      -> UnknownKind
#   4. body length: word 2 differs from the words after it -> BadLength
#   5. field walk, for each tag of `field_allowlist()` in order:
#      no word left (a missing last field)                  -> BadLength
#      a tag `field_allowed` refuses (12, 13, 14, any other) -> NotAllowed
#      an allowlisted tag other than the next one (a repeat,
#      an earlier field, or a later one after a skipped field) -> OutOfOrder
#      no length word, or fewer value words than it names     -> BadLength
#   6. words left after the last allowlisted field          -> BadLength
#   7. values, field by field in allowlist order: a width other than the
#      field's -> BadLength, except that sources longer than `max_sources()`
#      entries are TooLong (before their parity is checked) and that the
#      scope fields must be all empty or all present; a phase, operation,
#      outcome or reason word outside its closed set -> OutOfRange
#   8. coherence: `event_coherent` fails (a phase contradicting the kind, an
#      outcome contradicting the kind, an artifact on anything but an
#      accepted commit, a scope on an early denial or none on a scope-reading
#      outcome)                                            -> OutOfRange
# - Canonicity: the field order and widths are fixed, every field is
#   mandatory, and each value has one word form, so an accepted word list is
#   the unique encoding of its event: decode(encode(e)) == Decoded{e} for
#   every encodable e, and encode of a decoded event is its input words.
# Per-field sensitivity (Task 6 copies these into docs/AUDIT.md):
# - version, kind, phase: public format facts, but kind and phase reveal that
#   an admission or commit was attempted at all.
# - event_id: a monitor sequence number; it reveals ordering and volume, so
#   query views and exports omit it (section 2 idempotency only).
# - subject: who acted; identifying and linkable across events.
# - invocation, sources, destination, stamp, code, operation kind: what was
#   asked, over which exact object versions, under which epochs. Plan
#   numbers bound by a monitor grant, but they reveal object identities,
#   versions and access patterns; absent (length 0) for early denials.
# - artifact: a digest of the sealed output; it permits confirming a guessed
#   low-entropy output, so it is as sensitive as the output itself.
# - outcome and reason: whether the request passed, and which check refused
#   it, which reveals facts about grants, payment and source policy state.
# Encoding properties are tested (AuditTests, event_format), not proved: the
# codec works over U32 words, which are not inductive, and a law about it
# would restate the definitions.
#
# Public entry points: `audited_admit` and `audited_commit`, plus the record
# accessors and `EventRecord.equal`; for the encoding, `encode`, `decode`,
# `field_allowlist`, `field_allowed`, the named constants (format version,
# kind, phase, outcome and field tags, `max_sources`, `word_limit`,
# `max_words`), `FormatError.equal`, `DecodeResult.equal` and
# `DecodeResult.event`. Every other def (`outcome_of_decision`,
# `outcome_of_commit`, `denial_reads_scope`, `admission_scope`,
# `admission_event`, `commit_event`, `project`, the tag and equality helpers,
# and the encoding and decoding helpers) is an exported implementation
# helper; calling one performs none of the library's checks, records no
# decision, and (for the codec helpers) skips the decoder's other checks.
#
# Laws (LAWS.bend):
# - `audit_admission_event_ignores_diagnostic`: for every plan, context,
#   labels, subject, two caller tokens, two diagnostics and event id, the
#   admission events are equal. No payload, error text, credential or caller
#   token influences any event field, for every decision including every
#   denial.
# - `audit_commit_event_ignores_diagnostic`: the commit event equals the
#   projection, without any diagnostic and with any other caller token, of
#   the result the facade returned. The token is an authority input to the
#   facade, so it may change the decision; it influences the event only
#   through that decision, never as a field.
# - `audit_admit_returns_library_decision` and
#   `audit_commit_returns_library_result`: the wrappers return exactly what
#   the library returned, so a denied transfer stays denied with its reason,
#   and a rejected commit keeps the caller's session and ledger.
# None of them claims durability, append success, or that a host calls the
# wrapper at all; those are section 2 and host obligations. The scope rule is
# tested (AuditTests), not proved.

# --- Records -----------------------------------------------------------------
# Naming: the design's `Event` and `Kind` are `EventRecord` and `EventKind`
# here, because Base already declares a type `Event` and `Kind` is a keyword.

type EventKind is Data:
  AdmissionAdmitted{}
  AdmissionDenied{}
  CommitAccepted{}
  CommitRejected{}

type Phase is Data:
  Admission{}
  Commit{}

# Projected from the library value by outcome_of_decision/outcome_of_commit
# only. DeniedFor carries the reason the library itself returned.
type Outcome is Data:
  Admitted{}
  DeniedFor{reason: T.Denial}
  Committed{}
  NotCommitted{}

# The plan fields an event may carry. `ScopeNotRead` is the explicit marker
# for an admission denied before a write grant bound the plan; it has no
# fields, so an early-denied event cannot hold any caller-written scope.
type Scope is Data:
  ScopeNotRead{}
  ScopeRead{invocation: Nat, sources: T.Objects, destination: T.ObjectVersion,
    stamp: T.Stamp, code: T.CodeId, op: T.OpKind}

# The allowlisted event (see the header for each field's admission check).
type EventRecord is Data:
  EventRecord{version: Nat, kind: EventKind, event_id: Nat, subject: Nat,
    phase: Phase, scope: Scope, artifact: Maybe<&2, B.ArtifactId>, outcome: Outcome}

# Raw failure material a host holds when it calls audit. No field of it is
# ever read by a projection; it is a parameter so the laws can quantify it.
type Diagnostic is Data:
  Diagnostic{payload: List<&2, U32>, error_text: List<&2, U32>,
    credential: List<&2, U32>, token: T.CodeId}

# Monitor-owned object labels (owner and DLM label per exact object version).
# Consumed by the event policy derivation (Task 3); never caller input.
type ObjectLabel is Data:
  ObjectLabel{object: T.ObjectVersion, owner: D.Principal, label: D.Label}

type Labels is Data:
  NoLabels{}
  Labelled{head: ObjectLabel, rest: Labels}

# The library's decision, unchanged, next to its projected event.
type AuditedAdmission is Data:
  AuditedAdmission{decision: T.Decision, event: EventRecord}

# The facade's commit result, unchanged, next to its projected event.
type AuditedCommit is Data:
  AuditedCommit{result: B.CommitResult, event: EventRecord}

# --- Named constants and tags ------------------------------------------------

def event_format_version() -> Nat:
  1n

# Kind tags, the header's second word. 0 and every value above 4 are unknown.
def kind_admission_admitted() -> Nat:
  1n

def kind_admission_denied() -> Nat:
  2n

def kind_commit_accepted() -> Nat:
  3n

def kind_commit_rejected() -> Nat:
  4n

def kind_tag(kind: EventKind) -> Nat:
  match kind:
    case AdmissionAdmitted{}:
      kind_admission_admitted()
    case AdmissionDenied{}:
      kind_admission_denied()
    case CommitAccepted{}:
      kind_commit_accepted()
    case CommitRejected{}:
      kind_commit_rejected()

# Phase words (the phase field's single value word).
def phase_admission() -> Nat:
  0n

def phase_commit() -> Nat:
  1n

def phase_tag(phase: Phase) -> Nat:
  match phase:
    case Admission{}:
      phase_admission()
    case Commit{}:
      phase_commit()

# One tag per closed T.Denial constructor, in Transfer's declaration order:
# ten distinct values, 0 to 9. It is the reason word of a DeniedFor outcome.
def reason_tag(reason: T.Denial) -> Nat:
  match reason:
    case T.InvalidPolicy{}:
      0n
    case T.Stale{}:
      1n
    case T.Source{}:
      2n
    case T.Read{}:
      3n
    case T.Write{}:
      4n
    case T.Schema{}:
      5n
    case T.Operation{}:
      6n
    case T.Origin{}:
      7n
    case T.Payment{}:
      8n
    case T.Destination{}:
      9n

# Outcome words (the outcome field's first value word). Only DeniedFor is
# followed by a reason word.
def outcome_admitted() -> Nat:
  0n

def outcome_denied() -> Nat:
  1n

def outcome_committed() -> Nat:
  2n

def outcome_not_committed() -> Nat:
  3n

def outcome_tag(outcome: Outcome) -> Nat:
  match outcome:
    case Admitted{}:
      outcome_admitted()
    case DeniedFor{reason}:
      outcome_denied()
    case Committed{}:
      outcome_committed()
    case NotCommitted{}:
      outcome_not_committed()

# --- Projection --------------------------------------------------------------

# The ONLY place an admission outcome is derived: it matches the Decision that
# the transfer admission check returned and copies its reason. It evaluates no check.
def outcome_of_decision(decision: T.Decision) -> Outcome:
  match decision:
    case T.Denied{reason}:
      DeniedFor{reason}
    case T.Admitted{ticket}:
      Admitted{}

# The ONLY place a commit outcome is derived: it matches the CommitResult the
# facade returned. Rejected exposes no reason, so none is invented.
def outcome_of_commit(result: B.CommitResult) -> Outcome:
  match result:
    case B.Committed{session, ledger, intent}:
      Committed{}
    case B.Rejected{session, ledger}:
      NotCommitted{}

# The sealed artifact of an accepted commit, read from its WriteIntent; a
# rejection names no artifact. The id is a digest derived from the output's
# content (Task 3 labels it with the binding's labels).
def artifact_of_commit(result: B.CommitResult) -> Maybe<&2, B.ArtifactId>:
  match result:
    case B.Committed{session, ledger, intent}:
      Some{B.WriteIntent.artifact(intent)}
    case B.Rejected{session, ledger}:
      None{}

# Admission names no artifact: nothing has been executed or sealed yet.
def no_artifact() -> Maybe<&2, B.ArtifactId>:
  None{}

# Kind is a function of the outcome, so it cannot disagree with it.
def kind_of(outcome: Outcome) -> EventKind:
  match outcome:
    case Admitted{}:
      AdmissionAdmitted{}
    case DeniedFor{reason}:
      AdmissionDenied{}
    case Committed{}:
      CommitAccepted{}
    case NotCommitted{}:
      CommitRejected{}

def phase_of(kind: EventKind) -> Phase:
  match kind:
    case AdmissionAdmitted{}:
      Admission{}
    case AdmissionDenied{}:
      Admission{}
    case CommitAccepted{}:
      Commit{}
    case CommitRejected{}:
      Commit{}

# The authenticated subject of a frontend caller. The token is never read.
def caller_subject(caller: F.Caller) -> Nat:
  match caller:
    case F.Caller{subject, _}:
      subject

# The scope fields of a plan the monitor has bound. The output type is not on
# the allowlist and is dropped.
def scope_of_plan(plan: T.Plan) -> Scope:
  match plan:
    case T.Plan{stamp, invocation, sources, destination, code, op, _}:
      ScopeRead{invocation, sources, destination, stamp, code, op}

# Named policy bit per closed denial reason: True only for the reasons that
# T.admit can return only after the header's write-grant check bound every
# scope field (Read, Origin, Payment). Every reason that can arise in the
# header, and InvalidPolicy (ruling), is False: its event carries no scope.
def denial_reads_scope(reason: T.Denial) -> Bool:
  match reason:
    case T.InvalidPolicy{}:
      False{}
    case T.Stale{}:
      False{}
    case T.Source{}:
      False{}
    case T.Read{}:
      True{}
    case T.Write{}:
      False{}
    case T.Schema{}:
      False{}
    case T.Operation{}:
      False{}
    case T.Origin{}:
      True{}
    case T.Payment{}:
      True{}
    case T.Destination{}:
      False{}

# Fail closed: a reason that does not vouch for the plan yields the marker.
def scope_gate(reads: Bool, plan: T.Plan) -> Scope:
  match reads:
    case True{}:
      scope_of_plan(plan)
    case False{}:
      ScopeNotRead{}

# The scope an admission event may carry, chosen from the Decision the library
# returned. It reads the plan only when the decision vouches for it.
def admission_scope(plan: T.Plan, decision: T.Decision) -> Scope:
  match decision:
    case T.Denied{reason}:
      scope_gate(denial_reads_scope(reason), plan)
    case T.Admitted{ticket}:
      scope_of_plan(plan)

# The single record constructor.
def project(subject: Nat, scope: Scope, +outcome: Outcome,
    artifact: Maybe<&2, B.ArtifactId>, event_id: Nat) -> EventRecord:
  +kind = kind_of(outcome)
  EventRecord{event_format_version(), kind, event_id, subject, phase_of(kind),
    scope, artifact, outcome}

# Subject from the authenticated caller, scope and outcome from the decision
# the library returned.
def admission_event(plan: T.Plan, +decision: T.Decision, caller: F.Caller,
    event_id: Nat) -> EventRecord:
  project(caller_subject(caller), admission_scope(plan, decision),
    outcome_of_decision(decision), no_artifact(), event_id)

# Scope from the negotiated plan of the session the facade was given, subject
# from the Ref's authenticated caller, outcome and artifact from the result.
def commit_event(session: N.Session, ref: F.Ref, +result: B.CommitResult,
    event_id: Nat) -> EventRecord:
  project(OS.subject(ref), scope_of_plan(N.Session.plan(session)),
    outcome_of_commit(result), artifact_of_commit(result), event_id)

# --- Public entry points -----------------------------------------------------

# Public entry point. Calls the transfer admission check exactly once and
# returns its Decision unchanged beside the projected event. `labels` and
# `diagnostic` are accepted and not read here (labels feed Task 3's policy).
# Failure behaviour is the library's: a denial is returned as the same
# Denied{reason}; recording it is not a second decision.
def audited_admit(+plan: T.Plan, context: T.Context, labels: Labels,
    caller: F.Caller, diagnostic: Diagnostic, event_id: Nat) -> AuditedAdmission:
  +decision = T.admit(plan, context)
  AuditedAdmission{decision, admission_event(plan, decision, caller, event_id)}

# Public entry point. Calls the DataOS capability commit facade exactly once,
# with exactly the facade's arguments, and returns its CommitResult unchanged
# beside the projected event. A rejection therefore keeps the caller's
# session and ledger (no reservation is consumed by recording), and the only
# release route is the facade's own.
def audited_commit(+session: N.Session, expected_session: Nat,
    expected_ledger: Nat, ledger: L.State, candidate: C.Candidate, +ref: F.Ref,
    expected_frontend: Nat, context: OS.Context, labels: Labels,
    diagnostic: Diagnostic, event_id: Nat) -> AuditedCommit:
  +result = OS.commit_from_capability(session, expected_session, expected_ledger,
    ledger, candidate, ref, expected_frontend, context)
  AuditedCommit{result, commit_event(session, ref, result, event_id)}

# --- Accessors (public entry points) ------------------------------------------

def AuditedAdmission.decision(a: AuditedAdmission) -> T.Decision:
  match a:
    case AuditedAdmission{decision, _}:
      decision

def AuditedAdmission.event(a: AuditedAdmission) -> EventRecord:
  match a:
    case AuditedAdmission{_, event}:
      event

def AuditedCommit.result(a: AuditedCommit) -> B.CommitResult:
  match a:
    case AuditedCommit{result, _}:
      result

def AuditedCommit.event(a: AuditedCommit) -> EventRecord:
  match a:
    case AuditedCommit{_, event}:
      event

def EventRecord.version(e: EventRecord) -> Nat:
  match e:
    case EventRecord{v, _, _, _, _, _, _, _}:
      v

def EventRecord.kind(e: EventRecord) -> EventKind:
  match e:
    case EventRecord{_, k, _, _, _, _, _, _}:
      k

def EventRecord.event_id(e: EventRecord) -> Nat:
  match e:
    case EventRecord{_, _, i, _, _, _, _, _}:
      i

def EventRecord.subject(e: EventRecord) -> Nat:
  match e:
    case EventRecord{_, _, _, s, _, _, _, _}:
      s

def EventRecord.phase(e: EventRecord) -> Phase:
  match e:
    case EventRecord{_, _, _, _, p, _, _, _}:
      p

def EventRecord.scope(e: EventRecord) -> Scope:
  match e:
    case EventRecord{_, _, _, _, _, x, _, _}:
      x

def EventRecord.artifact(e: EventRecord) -> Maybe<&2, B.ArtifactId>:
  match e:
    case EventRecord{_, _, _, _, _, _, a, _}:
      a

def EventRecord.outcome(e: EventRecord) -> Outcome:
  match e:
    case EventRecord{_, _, _, _, _, _, _, o}:
      o

# --- Equality ----------------------------------------------------------------

def EventKind.equal(a: EventKind, b: EventKind) -> Bool:
  Nat.is_eq(kind_tag(a), kind_tag(b))

def Phase.equal(a: Phase, b: Phase) -> Bool:
  Nat.is_eq(phase_tag(a), phase_tag(b))

def denial_equal(a: T.Denial, b: T.Denial) -> Bool:
  Nat.is_eq(reason_tag(a), reason_tag(b))

def Outcome.equal(a: Outcome, b: Outcome) -> Bool:
  match a b:
    case DeniedFor{ra} DeniedFor{rb}:
      denial_equal(ra, rb)
    case _ _:
      Nat.is_eq(outcome_tag(a), outcome_tag(b))

def Scope.equal(a: Scope, b: Scope) -> Bool:
  match a b:
    case ScopeNotRead{} ScopeNotRead{}:
      True{}
    case ScopeRead{an, ax, ad, at, ac, ao} ScopeRead{bn, bx, bd, bt, bc, bo}:
      Nat.is_eq(an, bn) && T.Objects.equal(ax, bx) &&
        T.ObjectVersion.equal(ad, bd) && T.Stamp.equal(at, bt) &&
        T.CodeId.equal(ac, bc) && T.OpKind.equal(ao, bo)
    case _ _:
      False{}

def artifact_equal(a: Maybe<&2, B.ArtifactId>, b: Maybe<&2, B.ArtifactId>) -> Bool:
  match a b:
    case None{} None{}:
      True{}
    case Some{x} Some{y}:
      B.ArtifactId.equal(x, y)
    case _ _:
      False{}

# Public entry point. Field-by-field equality over every allowlisted field.
def EventRecord.equal(a: EventRecord, b: EventRecord) -> Bool:
  match a b:
    case EventRecord{av, ak, ai, as, ap, ax, aa, au}
      EventRecord{bv, bk, bi, bs, bp, bx, ba, bu}:
      Nat.is_eq(av, bv) && EventKind.equal(ak, bk) && Nat.is_eq(ai, bi) &&
        Nat.is_eq(as, bs) && Phase.equal(ap, bp) && Scope.equal(ax, bx) &&
        artifact_equal(aa, ba) && Outcome.equal(au, bu)

# --- Canonical encoding, format version 1 (boundary, not policy) --------------
# See the header section "Canonical encoding" for the layout, the check order
# and canonicity. Nothing below decides, grants, or releases anything.

type FieldTags is Data:
  NoTags{}
  FieldTag{tag: Nat, rest: FieldTags}

# Closed set of decode failures. Every rejected word list names exactly one.
type FormatError is Data:
  UnknownVersion{}
  UnknownKind{}
  NotAllowed{}
  OutOfOrder{}
  BadLength{}
  TooLong{}
  OutOfRange{}

# The result of decoding: a description of one event, or one failure reason.
type DecodeResult is Data:
  Decoded{event: EventRecord}
  Malformed{reason: FormatError}

# Implementation helper: the value words of each walked field, in allowlist
# order.
type RawFields is Data:
  RawEnd{}
  RawField{values: List<&2, U32>, rest: RawFields}

# Implementation helper: one field read by the walk (its values and the words
# after it), or the reason the walk stopped.
type FieldStep is Data:
  StepOk{values: List<&2, U32>, rest: List<&2, U32>}
  StepFail{reason: FormatError}

# Implementation helper: every allowlisted field walked, or a failure.
type Walk is Data:
  Walked{fields: RawFields, rest: List<&2, U32>}
  WalkFailed{reason: FormatError}

# Field tags, in allowlist order (which is also the record's field order).
def field_event_id() -> Nat:
  1n

def field_subject() -> Nat:
  2n

def field_phase() -> Nat:
  3n

def field_invocation() -> Nat:
  4n

def field_sources() -> Nat:
  5n

def field_destination() -> Nat:
  6n

def field_stamp() -> Nat:
  7n

def field_code() -> Nat:
  8n

def field_op() -> Nat:
  9n

def field_artifact() -> Nat:
  10n

def field_outcome() -> Nat:
  11n

# Reserved tags (controller ruling): a payload, a token and free text. They
# are named so that tests can present them; they are never on the allowlist,
# so the decoder rejects each NotAllowed and builds no event from it.
def field_reserved_payload() -> Nat:
  12n

def field_reserved_token() -> Nat:
  13n

def field_reserved_text() -> Nat:
  14n

# Public entry point: THE allowlist. The encoder emits exactly these fields in
# this order, the decoder walks exactly these tags in this order, and
# `field_allowed` reads this list; no other def names the set of tags.
def field_allowlist() -> FieldTags:
  FieldTag{field_event_id(), FieldTag{field_subject(), FieldTag{field_phase(),
    FieldTag{field_invocation(), FieldTag{field_sources(), FieldTag{field_destination(),
      FieldTag{field_stamp(), FieldTag{field_code(), FieldTag{field_op(),
        FieldTag{field_artifact(), FieldTag{field_outcome(), NoTags{}}}}}}}}}}}}

# Implementation helper: whether `tag` occurs in `tags`.
def tag_listed(tags: FieldTags, +tag: Nat) -> Bool:
  match tags:
    case NoTags{}:
      False{}
    case FieldTag{t, rest}:
      Nat.is_eq(t, tag) || tag_listed(rest, tag)

# Public entry point: whether `tag` names an allowlisted field.
def field_allowed(tag: Nat) -> Bool:
  tag_listed(field_allowlist(), tag)

# Implementation helper: the number of tags in `tags`.
def tag_count(tags: FieldTags) -> Nat:
  match tags:
    case NoTags{}:
      0n
    case FieldTag{t, rest}:
      1n+tag_count(rest)

# Most ordered source versions an encoded event may carry (controller ruling).
def max_sources() -> Nat:
  16n

# Every Nat field must be below this to fit one word without truncation.
def word_limit() -> Nat:
  Nat.add(4294967295n, 1n)

# The header: version, kind tag, body length.
def header_words() -> Nat:
  3n

# Each field: a tag word and a length word before its values.
def field_header_words() -> Nat:
  2n

# Value widths in words.
def width_word() -> Nat:
  1n

def width_object() -> Nat:
  2n

def width_stamp() -> Nat:
  3n

def width_code() -> Nat:
  8n

def width_denied_outcome() -> Nat:
  2n

# The widest value words of each field, in allowlist order: event id,
# subject, phase, invocation, max_sources() object versions, destination,
# stamp, code, operation kind, artifact digest, denied outcome.
def max_value_words() -> Nat:
  Nat.add(width_word(), Nat.add(width_word(), Nat.add(width_word(),
    Nat.add(width_word(), Nat.add(Nat.mul(max_sources(), width_object()),
      Nat.add(width_object(), Nat.add(width_stamp(), Nat.add(width_code(),
        Nat.add(width_word(), Nat.add(width_code(), width_denied_outcome()))))))))))

# Public: the longest accepted word list (a bound; no single event reaches it,
# because only a commit carries an artifact and only a denial a reason).
def max_words() -> Nat:
  Nat.add(header_words(), Nat.add(Nat.mul(field_header_words(), tag_count(field_allowlist())),
    max_value_words()))

# --- Encoding helpers -------------------------------------------------------

# Implementation helper: one Nat as one word. Callers have checked `fits`
# first (`encode` refuses otherwise), so this never truncates in `encode`.
def word(n: Nat) -> U32:
  U32.from_nat(n)

def fits(n: Nat) -> Bool:
  Nat.is_lt(n, word_limit())

def object_fits(v: T.ObjectVersion) -> Bool:
  match v:
    case T.ObjectVersion{o, n}:
      fits(o) && fits(n)

def objects_fit(xs: T.Objects) -> Bool:
  match xs:
    case T.OEnd{}:
      True{}
    case T.OCons{h, t}:
      object_fits(h) && objects_fit(t)

def objects_count(xs: T.Objects) -> Nat:
  match xs:
    case T.OEnd{}:
      0n
    case T.OCons{h, t}:
      1n+objects_count(t)

def stamp_fits(s: T.Stamp) -> Bool:
  match s:
    case T.Stamp{g, p, a}:
      fits(g) && fits(p) && fits(a)

# Every Nat in the scope fits one word.
def scope_fits(x: Scope) -> Bool:
  match x:
    case ScopeNotRead{}:
      True{}
    case ScopeRead{n, xs, d, st, c, op}:
      fits(n) && objects_fit(xs) && object_fits(d) && stamp_fits(st)

# At most max_sources() ordered source versions.
def sources_within(x: Scope) -> Bool:
  match x:
    case ScopeNotRead{}:
      True{}
    case ScopeRead{n, xs, d, st, c, op}:
      Nat.is_le(objects_count(xs), max_sources())

# Every Nat field of the record fits one word.
def record_fits(e: EventRecord) -> Bool:
  match e:
    case EventRecord{v, k, i, s, p, x, a, o}:
      fits(i) && fits(s) && scope_fits(x)

def record_sources_within(e: EventRecord) -> Bool:
  match e:
    case EventRecord{v, k, i, s, p, x, a, o}:
      sources_within(x)

def is_present(a: Maybe<&2, B.ArtifactId>) -> Bool:
  match a:
    case None{}:
      False{}
    case Some{x}:
      True{}

def scope_present(x: Scope) -> Bool:
  match x:
    case ScopeNotRead{}:
      False{}
    case ScopeRead{n, xs, d, st, c, op}:
      True{}

def same_bool(a: Bool, b: Bool) -> Bool:
  match a:
    case True{}:
      b
    case False{}:
      Bool.not(b)

# Only an accepted commit names an artifact (artifact_of_commit, no_artifact).
def artifact_fits_kind(k: EventKind, a: Maybe<&2, B.ArtifactId>) -> Bool:
  match k:
    case CommitAccepted{}:
      is_present(a)
    case _:
      Bool.not(is_present(a))

# Whether an event with this outcome carries a scope (admission_scope and
# commit_event): every outcome but an early denial does.
def outcome_reads_scope(o: Outcome) -> Bool:
  match o:
    case Admitted{}:
      True{}
    case DeniedFor{reason}:
      denial_reads_scope(reason)
    case Committed{}:
      True{}
    case NotCommitted{}:
      True{}

# Implementation helper: the fields relate as `project` relates them. The
# version is the format's, kind follows the outcome, phase follows the kind,
# only an accepted commit has an artifact, and the scope is present exactly
# when the outcome reads it. A record failing this is not one any wrapper
# could produce: `encode` refuses it and `decode` rejects it OutOfRange.
def event_coherent(e: EventRecord) -> Bool:
  match e:
    case EventRecord{v, +k, i, s, p, x, a, +o}:
      Nat.is_eq(v, event_format_version()) && EventKind.equal(kind_of(o), k) &&
        Phase.equal(p, phase_of(k)) && artifact_fits_kind(k, a) &&
        same_bool(outcome_reads_scope(o), scope_present(x))

def object_words(v: T.ObjectVersion, rest: List<&2, U32>) -> List<&2, U32>:
  match v:
    case T.ObjectVersion{o, n}:
      word(o) <> word(n) <> rest

def objects_words(xs: T.Objects) -> List<&2, U32>:
  match xs:
    case T.OEnd{}:
      []
    case T.OCons{h, t}:
      object_words(h, objects_words(t))

def stamp_words(s: T.Stamp) -> List<&2, U32>:
  match s:
    case T.Stamp{g, p, a}:
      [word(g), word(p), word(a)]

def code_words(c: T.CodeId) -> List<&2, U32>:
  match c:
    case T.CodeId{a, b, c, d, e, f, g, h}:
      [a, b, c, d, e, f, g, h]

# The value words of each scope field; every one is empty under ScopeNotRead.
def invocation_values(x: Scope) -> List<&2, U32>:
  match x:
    case ScopeNotRead{}:
      []
    case ScopeRead{n, xs, d, st, c, op}:
      [word(n)]

def sources_values(x: Scope) -> List<&2, U32>:
  match x:
    case ScopeNotRead{}:
      []
    case ScopeRead{n, xs, d, st, c, op}:
      objects_words(xs)

def destination_values(x: Scope) -> List<&2, U32>:
  match x:
    case ScopeNotRead{}:
      []
    case ScopeRead{n, xs, d, st, c, op}:
      object_words(d, [])

def stamp_values(x: Scope) -> List<&2, U32>:
  match x:
    case ScopeNotRead{}:
      []
    case ScopeRead{n, xs, d, st, c, op}:
      stamp_words(st)

def code_values(x: Scope) -> List<&2, U32>:
  match x:
    case ScopeNotRead{}:
      []
    case ScopeRead{n, xs, d, st, c, op}:
      code_words(c)

def op_values(x: Scope) -> List<&2, U32>:
  match x:
    case ScopeNotRead{}:
      []
    case ScopeRead{n, xs, d, st, c, op}:
      [T.OpKind.bit(op)]

# The artifact field is empty (length 0) for None.
def artifact_values(a: Maybe<&2, B.ArtifactId>) -> List<&2, U32>:
  match a:
    case None{}:
      []
    case Some{B.ArtifactId{c}}:
      code_words(c)

def outcome_values(o: Outcome) -> List<&2, U32>:
  match o:
    case DeniedFor{reason}:
      [word(outcome_denied()), word(reason_tag(reason))]
    case _:
      [word(outcome_tag(o))]

# Implementation helper: `chosen` when `ok`, otherwise `otherwise`.
def pick_values(ok: Bool, chosen: Maybe<&2, List<&2, U32>>,
    otherwise: Maybe<&2, List<&2, U32>>) -> Maybe<&2, List<&2, U32>>:
  match ok:
    case True{}:
      chosen
    case False{}:
      otherwise

# Implementation helper: the value words of field `tag` of the record. A tag
# with no field of the record (none, while the allowlist is the record's
# fields) is None, so `encode` fails rather than emit an empty field for it.
def field_values(+tag: Nat, e: EventRecord) -> Maybe<&2, List<&2, U32>>:
  match e:
    case EventRecord{v, k, i, s, p, +x, a, o}:
      pick_values(Nat.is_eq(tag, field_event_id()), Some{[word(i)]},
        pick_values(Nat.is_eq(tag, field_subject()), Some{[word(s)]},
          pick_values(Nat.is_eq(tag, field_phase()), Some{[word(phase_tag(p))]},
            pick_values(Nat.is_eq(tag, field_invocation()), Some{invocation_values(x)},
              pick_values(Nat.is_eq(tag, field_sources()), Some{sources_values(x)},
                pick_values(Nat.is_eq(tag, field_destination()), Some{destination_values(x)},
                  pick_values(Nat.is_eq(tag, field_stamp()), Some{stamp_values(x)},
                    pick_values(Nat.is_eq(tag, field_code()), Some{code_values(x)},
                      pick_values(Nat.is_eq(tag, field_op()), Some{op_values(x)},
                        pick_values(Nat.is_eq(tag, field_artifact()), Some{artifact_values(a)},
                          pick_values(Nat.is_eq(tag, field_outcome()), Some{outcome_values(o)},
                            None{})))))))))))

# Implementation helper: tag word, length word, values, then the rest.
def emit_field(tag: Nat, values: Maybe<&2, List<&2, U32>>,
    rest: Maybe<&2, List<&2, U32>>) -> Maybe<&2, List<&2, U32>>:
  match values rest:
    case Some{+vs} Some{r}:
      Some{word(tag) <> word(List.length(&2, U32, vs)) <> List.append(&2, U32, vs, r)}
    case _ _:
      None{}

# Implementation helper: every field of `tags`, in order.
def emit(tags: FieldTags, +e: EventRecord) -> Maybe<&2, List<&2, U32>>:
  match tags:
    case NoTags{}:
      Some{[]}
    case FieldTag{+t, rest}:
      emit_field(t, field_values(t, e), emit(rest, e))

# Implementation helper: the header in front of the body.
def frame(kind: EventKind, body: Maybe<&2, List<&2, U32>>) -> Maybe<&2, List<&2, U32>>:
  match body:
    case None{}:
      None{}
    case Some{+b}:
      Some{word(event_format_version()) <> word(kind_tag(kind)) <>
        word(List.length(&2, U32, b)) <> b}

def encode_checked(ok: Bool, +e: EventRecord) -> Maybe<&2, List<&2, U32>>:
  match ok:
    case True{}:
      frame(EventRecord.kind(e), emit(field_allowlist(), e))
    case False{}:
      None{}

# Public entry point: the canonical word encoding of `event`. It is None, and
# never a truncated encoding, when a Nat field is at or above `word_limit()`,
# when there are more than `max_sources()` sources, or when the record is not
# coherent (`event_coherent`), so every Some it returns decodes to `event`.
def encode(+event: EventRecord) -> Maybe<&2, List<&2, U32>>:
  encode_checked(event_coherent(event) && record_fits(event) &&
    record_sources_within(event), event)

# --- Decoding helpers -------------------------------------------------------

# Implementation helper: a header word as a kind; None for an unknown tag,
# including 0 and every value above 4.
def pick_kind(ok: Bool, chosen: EventKind, otherwise: Maybe<&2, EventKind>) -> Maybe<&2, EventKind>:
  match ok:
    case True{}:
      Some{chosen}
    case False{}:
      otherwise

def kind_of_word(+n: Nat) -> Maybe<&2, EventKind>:
  pick_kind(Nat.is_eq(n, kind_admission_admitted()), AdmissionAdmitted{},
    pick_kind(Nat.is_eq(n, kind_admission_denied()), AdmissionDenied{},
      pick_kind(Nat.is_eq(n, kind_commit_accepted()), CommitAccepted{},
        pick_kind(Nat.is_eq(n, kind_commit_rejected()), CommitRejected{}, None{}))))

def pick_phase(ok: Bool, chosen: Phase, otherwise: Maybe<&2, Phase>) -> Maybe<&2, Phase>:
  match ok:
    case True{}:
      Some{chosen}
    case False{}:
      otherwise

def phase_of_word(+n: Nat) -> Maybe<&2, Phase>:
  pick_phase(Nat.is_eq(n, phase_admission()), Admission{},
    pick_phase(Nat.is_eq(n, phase_commit()), Commit{}, None{}))

def pick_op(ok: Bool, chosen: T.OpKind, otherwise: Maybe<&2, T.OpKind>) -> Maybe<&2, T.OpKind>:
  match ok:
    case True{}:
      Some{chosen}
    case False{}:
      otherwise

def op_of_word(+w: U32) -> Maybe<&2, T.OpKind>:
  pick_op(U32.is_eq(w, T.OpKind.bit(T.Copy{})), T.Copy{},
    pick_op(U32.is_eq(w, T.OpKind.bit(T.Transform{})), T.Transform{},
      pick_op(U32.is_eq(w, T.OpKind.bit(T.Summarize{})), T.Summarize{}, None{})))

def pick_reason(ok: Bool, chosen: T.Denial, otherwise: Maybe<&2, T.Denial>) -> Maybe<&2, T.Denial>:
  match ok:
    case True{}:
      Some{chosen}
    case False{}:
      otherwise

# The inverse of reason_tag over its ten values; None for any other word.
def reason_of_word(+n: Nat) -> Maybe<&2, T.Denial>:
  pick_reason(Nat.is_eq(n, reason_tag(T.InvalidPolicy{})), T.InvalidPolicy{},
    pick_reason(Nat.is_eq(n, reason_tag(T.Stale{})), T.Stale{},
      pick_reason(Nat.is_eq(n, reason_tag(T.Source{})), T.Source{},
        pick_reason(Nat.is_eq(n, reason_tag(T.Read{})), T.Read{},
          pick_reason(Nat.is_eq(n, reason_tag(T.Write{})), T.Write{},
            pick_reason(Nat.is_eq(n, reason_tag(T.Schema{})), T.Schema{},
              pick_reason(Nat.is_eq(n, reason_tag(T.Operation{})), T.Operation{},
                pick_reason(Nat.is_eq(n, reason_tag(T.Origin{})), T.Origin{},
                  pick_reason(Nat.is_eq(n, reason_tag(T.Payment{})), T.Payment{},
                    pick_reason(Nat.is_eq(n, reason_tag(T.Destination{})), T.Destination{},
                      None{}))))))))))

def pick_outcome(ok: Bool, chosen: Outcome, otherwise: Maybe<&2, Outcome>) -> Maybe<&2, Outcome>:
  match ok:
    case True{}:
      Some{chosen}
    case False{}:
      otherwise

# A one-word outcome: Admitted, Committed or NotCommitted. The DeniedFor word
# never reaches this (it needs its reason word; `single_outcome`).
def outcome_of_word(+n: Nat) -> Maybe<&2, Outcome>:
  pick_outcome(Nat.is_eq(n, outcome_admitted()), Admitted{},
    pick_outcome(Nat.is_eq(n, outcome_committed()), Committed{},
      pick_outcome(Nat.is_eq(n, outcome_not_committed()), NotCommitted{}, None{})))

# --- The field walk ---------------------------------------------------------

def prepend_value(w: U32, step: FieldStep) -> FieldStep:
  match step:
    case StepOk{vs, rest}:
      StepOk{w <> vs, rest}
    case StepFail{reason}:
      StepFail{reason}

# Implementation helper: exactly `n` value words, or BadLength when the body
# ends first (a length word naming more words than remain).
def take_values(n: Nat, words: List<&2, U32>) -> FieldStep:
  match n words:
    case 0n ws:
      StepOk{[], ws}
    case 1n+p Con{w, ws}:
      prepend_value(w, take_values(p, ws))
    case 1n+p Nil{}:
      StepFail{BadLength{}}

def read_length(words: List<&2, U32>) -> FieldStep:
  match words:
    case Nil{}:
      StepFail{BadLength{}}
    case Con{length, body}:
      take_values(U32.to_nat(length), body)

def check_next(next: Bool, after: List<&2, U32>) -> FieldStep:
  match next:
    case True{}:
      read_length(after)
    case False{}:
      StepFail{OutOfOrder{}}

def check_field_tag(allowed: Bool, next: Bool, after: List<&2, U32>) -> FieldStep:
  match allowed:
    case True{}:
      check_next(next, after)
    case False{}:
      StepFail{NotAllowed{}}

# Implementation helper: the field `expected` names, at the front of `words`.
# No word left is BadLength (a missing last field or a cut body); a tag the
# allowlist does not name is NotAllowed; an allowlisted tag other than
# `expected` (a repeat, an earlier field, or a later one after a skipped
# mandatory field) is OutOfOrder.
def read_field(+expected: Nat, words: List<&2, U32>) -> FieldStep:
  match words:
    case Nil{}:
      StepFail{BadLength{}}
    case Con{+tag, after}:
      check_field_tag(field_allowed(U32.to_nat(tag)), Nat.is_eq(U32.to_nat(tag), expected), after)

def prepend_field(values: List<&2, U32>, w: Walk) -> Walk:
  match w:
    case Walked{fields, rest}:
      Walked{RawField{values, fields}, rest}
    case WalkFailed{reason}:
      WalkFailed{reason}

# Implementation helper: `step` is the field read for the previous tag;
# `tags` are the allowlisted tags still to read, in order.
def walk(tags: FieldTags, step: FieldStep) -> Walk:
  match tags step:
    case NoTags{} StepOk{values, rest}:
      Walked{RawField{values, RawEnd{}}, rest}
    case FieldTag{t, more} StepOk{values, rest}:
      prepend_field(values, walk(more, read_field(t, rest)))
    case _ StepFail{reason}:
      WalkFailed{reason}

# Implementation helper: walk the body against `tags` in order.
def walk_all(tags: FieldTags, body: List<&2, U32>) -> Walk:
  match tags:
    case NoTags{}:
      Walked{RawEnd{}, body}
    case FieldTag{t, more}:
      walk(more, read_field(t, body))

# --- Field values -----------------------------------------------------------

def in_range(-A: Data, m: Maybe<&2, A>) -> Result<&2, &2, FormatError, A>:
  match m:
    case None{}:
      Fail{OutOfRange{}}
    case Some{x}:
      Done{x}

def parse_word(vs: List<&2, U32>) -> Result<&2, &2, FormatError, Nat>:
  match vs:
    case Con{w, Nil{}}:
      Done{U32.to_nat(w)}
    case _:
      Fail{BadLength{}}

def parse_phase(vs: List<&2, U32>) -> Result<&2, &2, FormatError, Phase>:
  match vs:
    case Con{w, Nil{}}:
      in_range(Phase, phase_of_word(U32.to_nat(w)))
    case _:
      Fail{BadLength{}}

def parse_object(vs: List<&2, U32>) -> Result<&2, &2, FormatError, T.ObjectVersion>:
  match vs:
    case Con{o, Con{n, Nil{}}}:
      Done{T.ObjectVersion{U32.to_nat(o), U32.to_nat(n)}}
    case _:
      Fail{BadLength{}}

def prepend_object(v: T.ObjectVersion, r: Result<&2, &2, FormatError, T.Objects>)
    -> Result<&2, &2, FormatError, T.Objects>:
  match r:
    case Done{xs}:
      Done{T.OCons{v, xs}}
    case Fail{e}:
      Fail{e}

# Pairs of words as ordered object versions; an odd word is BadLength.
def parse_pairs(vs: List<&2, U32>) -> Result<&2, &2, FormatError, T.Objects>:
  match vs:
    case Nil{}:
      Done{T.OEnd{}}
    case Con{o, Con{n, rest}}:
      prepend_object(T.ObjectVersion{U32.to_nat(o), U32.to_nat(n)}, parse_pairs(rest))
    case Con{o, Nil{}}:
      Fail{BadLength{}}

def sources_checked(over: Bool, vs: List<&2, U32>) -> Result<&2, &2, FormatError, T.Objects>:
  match over:
    case True{}:
      Fail{TooLong{}}
    case False{}:
      parse_pairs(vs)

# More than max_sources() object versions is TooLong, checked before parity.
def parse_sources(+vs: List<&2, U32>) -> Result<&2, &2, FormatError, T.Objects>:
  sources_checked(Nat.is_gt(List.length(&2, U32, vs), Nat.mul(max_sources(), width_object())), vs)

def parse_stamp(vs: List<&2, U32>) -> Result<&2, &2, FormatError, T.Stamp>:
  match vs:
    case Con{g, Con{p, Con{a, Nil{}}}}:
      Done{T.Stamp{U32.to_nat(g), U32.to_nat(p), U32.to_nat(a)}}
    case _:
      Fail{BadLength{}}

def parse_code(vs: List<&2, U32>) -> Result<&2, &2, FormatError, T.CodeId>:
  match vs:
    case Con{a, Con{b, Con{c, Con{d, Con{e, Con{f, Con{g, Con{h, Nil{}}}}}}}}}:
      Done{T.CodeId{a, b, c, d, e, f, g, h}}
    case _:
      Fail{BadLength{}}

def parse_op(vs: List<&2, U32>) -> Result<&2, &2, FormatError, T.OpKind>:
  match vs:
    case Con{w, Nil{}}:
      in_range(T.OpKind, op_of_word(w))
    case _:
      Fail{BadLength{}}

def is_empty(vs: List<&2, U32>) -> Bool:
  match vs:
    case Nil{}:
      True{}
    case Con{w, rest}:
      False{}

def scope_not_read(empty: Bool) -> Result<&2, &2, FormatError, Scope>:
  match empty:
    case True{}:
      Done{ScopeNotRead{}}
    case False{}:
      Fail{BadLength{}}

def scope_read(n: Nat, srcs: List<&2, U32>, dst: List<&2, U32>, st: List<&2, U32>,
    code: List<&2, U32>, op: List<&2, U32>) -> Result<&2, &2, FormatError, Scope>:
  do Result<&2, &2, FormatError, Scope>:
    xs : T.Objects <- parse_sources(srcs)
    d : T.ObjectVersion <- parse_object(dst)
    s : T.Stamp <- parse_stamp(st)
    c : T.CodeId <- parse_code(code)
    o : T.OpKind <- parse_op(op)
    return ScopeRead{n, xs, d, s, c, o}

# The invocation field selects the scope: empty means ScopeNotRead, and then
# every other scope field must be empty too; one word means ScopeRead, and
# then every scope field has its fixed width. Any mixture is BadLength.
def parse_scope(inv: List<&2, U32>, srcs: List<&2, U32>, dst: List<&2, U32>,
    st: List<&2, U32>, code: List<&2, U32>, op: List<&2, U32>) -> Result<&2, &2, FormatError, Scope>:
  match inv:
    case Nil{}:
      scope_not_read(is_empty(srcs) && is_empty(dst) && is_empty(st) && is_empty(code) && is_empty(op))
    case Con{n, Nil{}}:
      scope_read(U32.to_nat(n), srcs, dst, st, code, op)
    case _:
      Fail{BadLength{}}

def artifact_some(r: Result<&2, &2, FormatError, T.CodeId>)
    -> Result<&2, &2, FormatError, Maybe<&2, B.ArtifactId>>:
  match r:
    case Done{c}:
      Done{Some{B.ArtifactId{c}}}
    case Fail{e}:
      Fail{e}

# Empty is no artifact; otherwise exactly one eight-word digest.
def parse_artifact(vs: List<&2, U32>) -> Result<&2, &2, FormatError, Maybe<&2, B.ArtifactId>>:
  match vs:
    case Nil{}:
      Done{None{}}
    case Con{w, rest}:
      artifact_some(parse_code(Con{w, rest}))

def single_outcome(denied: Bool, +n: Nat) -> Result<&2, &2, FormatError, Outcome>:
  match denied:
    case True{}:
      Fail{BadLength{}}
    case False{}:
      in_range(Outcome, outcome_of_word(n))

def denied_reason(m: Maybe<&2, T.Denial>) -> Result<&2, &2, FormatError, Outcome>:
  match m:
    case None{}:
      Fail{OutOfRange{}}
    case Some{reason}:
      Done{DeniedFor{reason}}

def denied_outcome(denied: Bool, r: Nat) -> Result<&2, &2, FormatError, Outcome>:
  match denied:
    case True{}:
      denied_reason(reason_of_word(r))
    case False{}:
      Fail{BadLength{}}

# One word for Admitted, Committed and NotCommitted; the DeniedFor word and
# one reason word. The DeniedFor word alone, or another word with a second
# word, is BadLength; an unknown outcome or reason word is OutOfRange.
def parse_outcome(vs: List<&2, U32>) -> Result<&2, &2, FormatError, Outcome>:
  match vs:
    case Con{+w, Nil{}}:
      single_outcome(Nat.is_eq(U32.to_nat(w), outcome_denied()), U32.to_nat(w))
    case Con{w, Con{r, Nil{}}}:
      denied_outcome(Nat.is_eq(U32.to_nat(w), outcome_denied()), U32.to_nat(r))
    case _:
      Fail{BadLength{}}

def build(kind: EventKind, id: List<&2, U32>, subj: List<&2, U32>, ph: List<&2, U32>,
    inv: List<&2, U32>, srcs: List<&2, U32>, dst: List<&2, U32>, st: List<&2, U32>,
    code: List<&2, U32>, op: List<&2, U32>, art: List<&2, U32>, out: List<&2, U32>)
    -> Result<&2, &2, FormatError, EventRecord>:
  do Result<&2, &2, FormatError, EventRecord>:
    i : Nat <- parse_word(id)
    s : Nat <- parse_word(subj)
    p : Phase <- parse_phase(ph)
    x : Scope <- parse_scope(inv, srcs, dst, st, code, op)
    a : Maybe<&2, B.ArtifactId> <- parse_artifact(art)
    o : Outcome <- parse_outcome(out)
    return EventRecord{event_format_version(), kind, i, s, p, x, a, o}

# Implementation helper: the walked fields, positionally in allowlist order
# (which is the record's field order). Any other number of fields, which only
# an allowlist disagreeing with the record could produce, is BadLength.
def interpret(kind: EventKind, fields: RawFields) -> Result<&2, &2, FormatError, EventRecord>:
  match fields:
    case RawField{id, RawField{subj, RawField{ph, RawField{inv, RawField{srcs, RawField{dst,
      RawField{st, RawField{code, RawField{op, RawField{art, RawField{out, RawEnd{}}}}}}}}}}}}:
      build(kind, id, subj, ph, inv, srcs, dst, st, code, op, art, out)
    case _:
      Fail{BadLength{}}

def coherent_checked(ok: Bool, e: EventRecord) -> DecodeResult:
  match ok:
    case True{}:
      Decoded{e}
    case False{}:
      Malformed{OutOfRange{}}

def check_coherent(r: Result<&2, &2, FormatError, EventRecord>) -> DecodeResult:
  match r:
    case Fail{reason}:
      Malformed{reason}
    case Done{+e}:
      coherent_checked(event_coherent(e), e)

def check_trailing(rest: List<&2, U32>, kind: EventKind, fields: RawFields) -> DecodeResult:
  match rest:
    case Nil{}:
      check_coherent(interpret(kind, fields))
    case Con{w, more}:
      Malformed{BadLength{}}

def check_walk(kind: EventKind, w: Walk) -> DecodeResult:
  match w:
    case WalkFailed{reason}:
      Malformed{reason}
    case Walked{fields, rest}:
      check_trailing(rest, kind, fields)

def check_body_length(ok: Bool, kind: EventKind, body: List<&2, U32>) -> DecodeResult:
  match ok:
    case True{}:
      check_walk(kind, walk_all(field_allowlist(), body))
    case False{}:
      Malformed{BadLength{}}

def decode_length(kind: EventKind, words: List<&2, U32>) -> DecodeResult:
  match words:
    case Nil{}:
      Malformed{BadLength{}}
    case Con{length, +body}:
      check_body_length(Nat.is_eq(U32.to_nat(length), List.length(&2, U32, body)), kind, body)

def check_kind(kind: Maybe<&2, EventKind>, words: List<&2, U32>) -> DecodeResult:
  match kind:
    case None{}:
      Malformed{UnknownKind{}}
    case Some{k}:
      decode_length(k, words)

def decode_kind(words: List<&2, U32>) -> DecodeResult:
  match words:
    case Nil{}:
      Malformed{BadLength{}}
    case Con{k, rest}:
      check_kind(kind_of_word(U32.to_nat(k)), rest)

def check_version(ok: Bool, words: List<&2, U32>) -> DecodeResult:
  match ok:
    case True{}:
      decode_kind(words)
    case False{}:
      Malformed{UnknownVersion{}}

def decode_version(words: List<&2, U32>) -> DecodeResult:
  match words:
    case Nil{}:
      Malformed{BadLength{}}
    case Con{v, rest}:
      check_version(Nat.is_eq(U32.to_nat(v), event_format_version()), rest)

def check_cap(over: Bool, words: List<&2, U32>) -> DecodeResult:
  match over:
    case True{}:
      Malformed{TooLong{}}
    case False{}:
      decode_version(words)

# Public entry point: decode one word list in the fixed check order (header
# "Canonical encoding"). The result is a description of an event or exactly
# one FormatError; no partial event is ever returned.
def decode(+words: List<&2, U32>) -> DecodeResult:
  check_cap(Nat.is_gt(List.length(&2, U32, words), max_words()), words)

# --- Decode result accessors and equality (public) --------------------------

def FormatError.equal(a: FormatError, b: FormatError) -> Bool:
  match a b:
    case UnknownVersion{} UnknownVersion{}: True{}
    case UnknownKind{} UnknownKind{}: True{}
    case NotAllowed{} NotAllowed{}: True{}
    case OutOfOrder{} OutOfOrder{}: True{}
    case BadLength{} BadLength{}: True{}
    case TooLong{} TooLong{}: True{}
    case OutOfRange{} OutOfRange{}: True{}
    case _ _: False{}

def DecodeResult.equal(a: DecodeResult, b: DecodeResult) -> Bool:
  match a b:
    case Decoded{x} Decoded{y}:
      EventRecord.equal(x, y)
    case Malformed{x} Malformed{y}:
      FormatError.equal(x, y)
    case _ _:
      False{}

# The decoded event; None for a rejected word list, which builds none.
def DecodeResult.event(r: DecodeResult) -> Maybe<&2, EventRecord>:
  match r:
    case Decoded{e}:
      Some{e}
    case Malformed{_}:
      None{}
