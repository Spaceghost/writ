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
# Public entry points: `audited_admit` and `audited_commit`, plus the record
# accessors and `EventRecord.equal`. Every other def (`outcome_of_decision`,
# `outcome_of_commit`, `denial_reads_scope`, `admission_scope`,
# `admission_event`, `commit_event`, `project`, the tag and equality helpers)
# is an exported implementation helper; calling one performs none of the
# library's checks and records no decision.
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

def kind_tag(kind: EventKind) -> Nat:
  match kind:
    case AdmissionAdmitted{}:
      0n
    case AdmissionDenied{}:
      1n
    case CommitAccepted{}:
      2n
    case CommitRejected{}:
      3n

def phase_tag(phase: Phase) -> Nat:
  match phase:
    case Admission{}:
      0n
    case Commit{}:
      1n

# One tag per closed T.Denial constructor, in Transfer's declaration order.
def denial_tag(reason: T.Denial) -> Nat:
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

def outcome_tag(outcome: Outcome) -> Nat:
  match outcome:
    case Admitted{}:
      0n
    case DeniedFor{reason}:
      1n
    case Committed{}:
      2n
    case NotCommitted{}:
      3n

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
  Nat.is_eq(denial_tag(a), denial_tag(b))

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
