import Base
import ../../../HostWire.bend as W
import ../../../HostIdentity.bend as I
import ../../../HostPrimitives.bend as P
import ../../../HostPublication.bend as H
import ../../../Frontend.bend as F
import ../../../Transfer.bend as T

# Linux host monitor ADAPTER GLUE for the direct Linux target (add-linux-host,
# task 1.1; the model half of LH-001 and LH-005 and the model consumption of
# LH-002, LH-003, LH-004, LH-006, and LH-007). This is a third binding of the
# portable host contract (HostWire, HostIdentity, HostPrimitives,
# HostPublication), beside the two synthetic adapters of
# HostConformanceVectors.bend. It supplies only `P.Fact`, `P.TargetReport`,
# `P.RouteFact`, and `P.SessionEvidence` values to the shared transitions and
# hands the broker only the `P.Effect` values of an `Admitted` step one of
# those transitions returned. It decides nothing: it adds no transition, no
# `Error`, no `HostIdentity`/`HostPrimitives` case, and no law (LAWS.bend and
# PROOF.bend are untouched), and no native fact it carries is an authority
# fact. It imports nothing under `contrib/`, `examples/`, or another
# `hosts/` target, and the contract never imports it.
#
# Authority. Every grant, binding, profile, delegation, admission, quota, and
# release decision is a shared transition's. The monitor-owned records here
# are constants: the Linux host id and starting incarnation, the versioned
# profile table (`profiles`, one configured profile `linux-worker-v1`), and
# the role a broker-launched session is opened in (`worker_role`, the
# monitor's decision, never a fact field). A `LinuxFact` is an observation
# the trusted broker framed: the trusted launch record's subject, code token,
# and monitor incarnation; the launch record's expected process credential
# and the connected peer's `SO_PEERCRED`/pidfd credential; how the endpoint
# arrived; which contract families the binding implements; which controls it
# established; and the worker's complete descriptor inventory. A uid, pid,
# start time, or descriptor number is a local fact, never a portable
# credential (AGENTS.md, docs/PLATFORMS.md): the peer credential is only
# compared with the launch record's, and the caller is built from the launch
# record's subject and token, never from a uid. A descriptor number is
# dropped by `inventory_of`; only the route's kind and mediation reach the
# contract.
#
# Translators (pure; each rejection is named and leaves the monitor state
# untouched because no transition runs):
#   `session_evidence_of`  launch record from another monitor incarnation
#                                                   -> StaleLaunch
#                          peer credential (uid, gid, pid, start time)
#                          differs from the launch record's -> PeerMismatch
#                          (a parent-created socketpair reports the parent;
#                          a reused pid reports another start time, LH-002)
#                          else `SessionEvidence{launch caller, origin,
#                          delegable = False}`
#   `session_check`        (Barrier only) the barrier's session is not
#                          exactly one session of the identity table, or
#                          its caller is not the fact's launch subject and
#                          token                    -> SessionMismatch
#   `report_of`            a family bit outside `P.all_families()`
#                                                   -> UnknownFamily
#                          a control bit outside `linux_controls()` (the
#                          accelerator isolation bit or an unnamed bit)
#                                                   -> UncreditedControl
#                          else `TargetReport{families, controls}`
#   `inventory_of`         total: `Inventory{routes}`, one `RouteFact{kind,
#                          mediated}` per reported descriptor, in order
# No helper produces a `Context`, `Binding`, plan, rights grant, profile, or
# caller that a transition treats as authority: `SessionEvidence` is consumed
# only by `open_session`, which allocates the session id and decides
# delegability (the evidence's False can only narrow), and `TargetReport` and
# `Inventory` are only compared against the profile the session was bound
# under.
#
# Profile `linux-worker-v1` (LH-001, LH-005; plan ruling). Required families:
# `P.all_families()`. Required controls: every control but accelerator
# isolation. Backend `Cpu`. Quota limit `quota_limit()`. The control-to-kernel
# mapping the broker must satisfy before it reports a control bit (mirrored in
# hosts/linux/INVENTORY.md; native evidence is Tasks 2 to 4):
#   `control_address_isolation`   private mount, IPC, PID, and UTS
#                                 namespaces, a pivoted root, nondumpable
#   `control_no_ambient_network`  a private network namespace with seccomp
#                                 denying socket creation
#   `control_output_mediation`    only the private result channel survives;
#                                 every public stream is closed
#   `control_quota`               the address-space, CPU, NOFILE, and NPROC
#                                 rlimits and zero core and file-size rlimits
#   `control_no_inherited_routes` the descriptor allowlist, `SCM_RIGHTS`-only
#                                 input, and denied descriptor import
# A report short of any required control is denied MissingControl by
# `admit_worker`, so no worker admits under a reduced set (LH-005). No
# `Accelerator` profile is offered in section 1, and the Linux broker cannot
# credit `control_accelerator_isolation` (`report_of` refuses it), so an
# accelerator profile, were one configured, would be denied by the shared
# UnisolatedAccelerator path; this module defines no accelerator path.
#
# Two input channels (plan ruling). `Input` has two constructors. The trusted
# broker channel (`FromBroker`) carries native facts: `Launch` (a worker
# process the broker launched and authenticated), `Barrier` (the worker
# reached the input-delivery barrier: the broker's confinement facts, plus
# the bounded, immutable snapshot of the worker's request bytes it copied,
# LH-006), `Usage` (a resource request it observed), and `Emission` (an
# output attempt it observed). The untrusted worker channel (`FromWorker`)
# carries only HostWire bytes and the session the broker's transport
# identified; it has no `LinuxFact` field, so a worker cannot supply a fact.
# Worker bytes, on either channel, pass only through `W.decode_bytes` and
# yield descriptions: a `W.Ref` names a table entry and carries no authority,
# and the claimed subject is never read (the Use pattern below discards it,
# and `P.use` ignores it).
#
# Barrier binding. A Barrier's fact must name the caller of the session it
# admits (`session_check`, else SessionMismatch), so a barrier the broker
# attributed to the wrong worker's session is refused. The monitor stores no
# launch credential, so the barrier's `launch`/`peer` comparison is a
# consistency check on the frame: that the barrier credential is the
# session's launch credential is a broker obligation (Task 2). The endpoint is
# fixed at Launch (`open_session` records the origin) and ignored at the
# Barrier. The request snapshot is the only request admission reads: only
# its reference is used and it must resolve on the barrier's session, so a
# snapshot that diverges from the worker's own frame admits at most an entry
# that session already holds. A `Checked`/`Granted` result authorizes no
# broker action in section 1; Task 4's resource lookup must act on the
# monitor's resolution, never on worker bytes. The adapter implements no
# replay rule: a repeated Launch opens another session, so the broker issues
# one Launch per launch-record generation (Task 2 frames the generation).
#
# Dispatch. `dispatch` applies at most one shared transition per framed input:
#   Launch{fact}            -> `session_evidence_of`, `report_of`, then
#                              `P.open_session` with `worker_role()`
#   Barrier{s, fact, bytes} -> the launch check, `session_check`, `report_of`,
#                              `inventory_of`,
#                              `W.decode_bytes`; a Use's reference goes to
#                              `P.admit_worker` on session `s`
#   Usage{worker, amount}   -> `P.charge`
#   Emission{worker, public}-> `P.diagnostic`
#   FromWorker{s, bytes}    -> `W.decode_bytes`; Use -> `P.use` (read-only),
#                              Delegate -> `P.delegate` from session `s`
# A rejected fact (`Untranslated`), undecodable bytes (`Undecoded`), or a frame
# with no route in this task (`Unrouted`: a barrier request that is not a Use,
# and a worker Complete or Release, whose HostPublication transitions are
# section 2) runs no transition and returns the supplied state.
#
# Effects. `Outcome.effects` is the only effect list the broker executes. It
# is `P.Step.effects` of the step a shared transition returned, and empty for
# every other outcome. `P.Effect` is closed and has no publish variant, and no
# `Outcome` constructor holds a `H.PublishEffect`, so the types forbid this
# module handing the broker a publication effect. Bend constructors are
# public, so the types cannot stop Bend code from writing an `Admitted` or
# `DeliverInputs` value; this module never does (it constructs no
# `P.Step` and no `P.Effect`), and the broker must execute only effects taken
# from an `Outcome` this monitor returned (HostPrimitives host obligation (a)).
# Ordering (contrib/native-hosts/PROTOCOL.md): the monitor retains
# `Outcome.state` before the broker performs any of `Outcome.effects`; an
# admitted `DeliverInputs` is therefore issued only after the state recording
# the worker `Running` is retained.
#
# Failure behavior: every refusal returns the supplied primitive state and no
# effect; a shared transition's denial is its `P.Denied` step unchanged.
# Monitor time `now` is the monitor's trusted clock (host obligation (c)).
#
# Public entry points: `linux_host`, `linux_incarnation`; `linux_worker_v1`,
# `profile_name`, `required_controls`, `linux_controls`, `quota_limit`,
# `linux_worker_profile`, `profiles`, `worker_role`, `initial`; the types
# `Credential`, `Endpoint`, `LinuxRoute`, `LinuxFact`, `Rejection`,
# `EvidenceResult`, `ReportResult`, `BrokerFrame`, `Input`, `Outcome`; the
# translators `launch_check`, `session_check`, `session_evidence_of`, `report_of`,
# `inventory_of`; `dispatch`, `Outcome.state`, `Outcome.effects`, and
# `Rejection.equal`. Every other def is an implementation helper.

# --- Host identity and profile table (monitor constants) --------------------------

# The Linux monitor's host id (distinct from the conformance adapters' 51
# and 52) and its starting incarnation. Both nonzero.
def linux_host() -> Nat:
  60n

def linux_incarnation() -> Nat:
  1n

# The configured profile's id and versioned name.
def linux_worker_v1() -> Nat:
  1n

def profile_name() -> String:
  "linux-worker-v1"

# The controls `linux-worker-v1` requires: every control but accelerator
# isolation.
def required_controls() -> U32:
  (P.control_address_isolation() .|. P.control_no_ambient_network() .|. P.control_output_mediation()
    .|. P.control_quota() .|. P.control_no_inherited_routes() : U32)

# The controls the section-1 Linux broker can credit (each has a kernel
# mapping above). Equal to `required_controls()` today; kept separate because
# it names what a report may carry, not what the profile requires.
def linux_controls() -> U32:
  (P.control_address_isolation() .|. P.control_no_ambient_network() .|. P.control_output_mediation()
    .|. P.control_quota() .|. P.control_no_inherited_routes() : U32)

# The quota a worker admitted under `linux-worker-v1` gets (enforced natively
# by the broker's rlimits; accounted by `P.charge`).
def quota_limit() -> Nat:
  1024n

def linux_worker_profile() -> P.Profile:
  P.Profile{linux_worker_v1(), P.all_families(), required_controls(), P.Cpu{}}

# The configured profile table: `linux-worker-v1` only.
def profiles() -> P.Profiles:
  P.Profiles{P.Configured{linux_worker_profile(), quota_limit()}, P.NoProfiles{}}

# The monitor's role for every session the broker launches: a worker under
# `linux-worker-v1`. A monitor decision, not a fact field.
def worker_role() -> P.Role:
  P.WorkerRole{linux_worker_v1()}

# The Linux monitor's starting state: an empty identity table on this host
# and incarnation, with the configured profile table.
def initial() -> P.State:
  P.empty(I.empty(linux_host(), linux_incarnation()), profiles())

# --- Native facts (what the broker frames) ----------------------------------------

# A process credential: uid, gid, pid, and process start time (from
# `SO_PEERCRED` and `/proc/PID/stat`, matched through a pidfd). Local facts
# only.
type Credential is Data:
  Credential{uid: Nat, gid: Nat, pid: Nat, start: Nat}

# How the worker's session endpoint arrived, as the broker observed it.
type Endpoint is Data:
  Launched{}
  InheritedFrom{parent_session: Nat}
  TransferredFrom{from_session: Nat}

# One descriptor of the worker's complete inventory: its number (a local
# fact, dropped by `inventory_of`), its kind (descriptive), and whether the
# broker mediates it.
type LinuxRoute is Data:
  LinuxRoute{descriptor: Nat, kind: U32, mediated: Bool}

# One broker-framed observation. `subject`, `token`, and `incarnation` are
# the trusted launch record's; `launch` is the credential the launch record
# expects and `peer` the one the kernel reported for the connected peer;
# `endpoint` is how the endpoint arrived; `families` and `controls` are the
# contract bits the binding implements and the controls it established
# (under the mapping in the header); `routes` is the worker's complete
# descriptor inventory.
type LinuxFact is Data:
  LinuxFact{subject: Nat, token: T.CodeId, incarnation: Nat, launch: Credential, peer: Credential,
    endpoint: Endpoint, families: U32, controls: U32, routes: +List<LinuxRoute>}

# Why a broker fact was not translated. None is a contract `Error`; a
# rejected fact reaches no transition.
type Rejection is Data:
  StaleLaunch{}
  PeerMismatch{}
  SessionMismatch{}
  UnknownFamily{}
  UncreditedControl{}

type EvidenceResult is Data:
  Evidence{fact: P.Fact}
  NoEvidence{reason: Rejection}

type ReportResult is Data:
  Report{report: P.TargetReport}
  NoReport{reason: Rejection}

def Rejection.equal(a: Rejection, b: Rejection) -> Bool:
  match a b:
    case StaleLaunch{} StaleLaunch{}: True{}
    case PeerMismatch{} PeerMismatch{}: True{}
    case SessionMismatch{} SessionMismatch{}: True{}
    case UnknownFamily{} UnknownFamily{}: True{}
    case UncreditedControl{} UncreditedControl{}: True{}
    case _ _: False{}

# --- Translators ------------------------------------------------------------------

# Implementation helper: the same uid, gid, pid, and start time.
def credential_equal(a: Credential, b: Credential) -> Bool:
  match a b:
    case Credential{au, ag, ap, ast} Credential{bu, bg, bp, bst}:
      Nat.is_eq(au, bu) && Nat.is_eq(ag, bg) && Nat.is_eq(ap, bp) && Nat.is_eq(ast, bst)

# Implementation helper: `reason` when `failed`, else `rest`.
def reject_if(failed: Bool, reason: Rejection, rest: Maybe<&2, Rejection>) -> Maybe<&2, Rejection>:
  match failed:
    case True{}:
      Some{reason}
    case False{}:
      rest

# The launch check, shared by `Launch` and `Barrier`: the fact's launch
# record names this monitor's current incarnation (else StaleLaunch), and the
# peer credential it carries equals the launch credential it carries (else
# PeerMismatch). Both are comparisons inside one frame: it authenticates
# nothing and binds the fact to no session (`session_check` does that for a
# Barrier); it refuses a fact whose own fields disagree.
def launch_check(+fact: LinuxFact, +incarnation: Nat) -> Maybe<&2, Rejection>:
  match fact:
    case LinuxFact{_, _, launched, launch, peer, _, _, _, _}:
      reject_if(Bool.not(Nat.is_eq(launched, incarnation)), StaleLaunch{},
        reject_if(Bool.not(credential_equal(peer, launch)), PeerMismatch{}, None{}))

# Implementation helper: whether the one session found has `caller`.
def session_caller_is(found: I.SessionLookup, caller: F.Caller) -> Bool:
  match found:
    case I.OneSession{bound}:
      I.caller_equal(I.session_caller(bound), caller)
    case _:
      False{}

# The Barrier's session check: `session` is exactly one session of
# `identity` and its caller is the fact's launch subject and token (else
# SessionMismatch). A comparison only; it binds and grants nothing.
def session_check(+fact: LinuxFact, +identity: I.State, +session: Nat) -> Maybe<&2, Rejection>:
  match fact:
    case LinuxFact{subject, token, _, _, _, _, _, _, _}:
      reject_if(Bool.not(session_caller_is(I.session_at(I.sessions(identity), session), F.Caller{subject, token})),
        SessionMismatch{}, None{})

# Implementation helper: the first rejection of two checks.
def first_of(first: Maybe<&2, Rejection>, second: Maybe<&2, Rejection>) -> Maybe<&2, Rejection>:
  match first:
    case Some{reason}:
      Some{reason}
    case None{}:
      second

# Implementation helper: the contract origin of an observed endpoint.
def origin_of(endpoint: Endpoint) -> I.Origin:
  match endpoint:
    case Launched{}:
      I.Authenticated{}
    case InheritedFrom{parent}:
      I.Inherited{parent}
    case TransferredFrom{from}:
      I.Transferred{from}

# Implementation helper: the evidence of a fact that passed the launch check.
# The caller is the launch record's subject and token; a worker's evidence is
# never delegable.
def evidence_of(fact: LinuxFact) -> P.Fact:
  match fact:
    case LinuxFact{subject, token, _, _, _, endpoint, _, _, _}:
      P.SessionEvidence{F.Caller{subject, token}, origin_of(endpoint), False{}}

def evidence_if(found: Maybe<&2, Rejection>, fact: LinuxFact) -> EvidenceResult:
  match found:
    case None{}:
      Evidence{evidence_of(fact)}
    case Some{reason}:
      NoEvidence{reason}

# Translator: the `SessionEvidence` of a broker fact, checked against the
# monitor's current incarnation `incarnation`.
def session_evidence_of(+fact: LinuxFact, +incarnation: Nat) -> EvidenceResult:
  evidence_if(launch_check(fact, incarnation), fact)

# Implementation helper: `report_of` after its bit checks.
def report_if(found: Maybe<&2, Rejection>, families: U32, controls: U32) -> ReportResult:
  match found:
    case None{}:
      Report{P.TargetReport{families, controls}}
    case Some{reason}:
      NoReport{reason}

# Translator: the `TargetReport` of a broker fact. Families must be contract
# families (else UnknownFamily) and controls ones this broker can credit
# (else UncreditedControl); the bits are otherwise copied, never widened.
def report_of(+fact: LinuxFact) -> ReportResult:
  match fact:
    case LinuxFact{_, _, _, _, _, _, +families, +controls, _}:
      report_if(reject_if(Bool.not(P.within(families, P.all_families())), UnknownFamily{},
        reject_if(Bool.not(P.within(controls, linux_controls())), UncreditedControl{}, None{})),
        families, controls)

# Implementation helper: one route per descriptor, number dropped.
def routes_of(routes: +List<LinuxRoute>) -> +List<P.RouteFact>:
  match routes:
    case []:
      []
    case LinuxRoute{_, kind, mediated} <> rest:
      P.RouteFact{kind, mediated} <> routes_of(rest)

# Translator: the `Inventory` of a broker fact's complete descriptor set.
def inventory_of(fact: LinuxFact) -> P.Fact:
  match fact:
    case LinuxFact{_, _, _, _, _, _, _, _, routes}:
      P.Inventory{routes_of(routes)}

# --- Channels and outcomes --------------------------------------------------------

# A frame on the trusted broker channel (see the header).
type BrokerFrame is Data:
  Launch{fact: LinuxFact}
  Barrier{session: Nat, fact: LinuxFact, request: +List<U32>}
  Usage{worker: Nat, amount: Nat}
  Emission{worker: Nat, public: Bool}

# One framed input. `FromWorker.session` is the session the broker's
# transport identified for the worker's connection; `bytes` are untrusted.
type Input is Data:
  FromBroker{frame: BrokerFrame}
  FromWorker{session: Nat, bytes: +List<U32>}

# What one input did. `Stepped` holds the step a shared transition returned;
# `Checked` a read-only `P.use` result with the unchanged state; the other
# three ran no transition and hold the supplied state.
type Outcome is Data:
  Stepped{step: P.Step}
  Checked{state: P.State, result: P.UseResult}
  Untranslated{state: P.State, reason: Rejection}
  Undecoded{state: P.State, reason: W.WireError}
  Unrouted{state: P.State}

# The state the monitor retains before the broker performs any effect.
def Outcome.state(outcome: Outcome) -> P.State:
  match outcome:
    case Stepped{step}:
      P.Step.state(step)
    case Checked{state, _}:
      state
    case Untranslated{state, _}:
      state
    case Undecoded{state, _}:
      state
    case Unrouted{state}:
      state

# The only effects the broker may execute: an admitted step's, else none.
def Outcome.effects(outcome: Outcome) -> +List<P.Effect>:
  match outcome:
    case Stepped{step}:
      P.Step.effects(step)
    case _:
      []

# --- Dispatch: broker channel -----------------------------------------------------

def current_incarnation(+state: P.State) -> Nat:
  I.incarnation(P.identity(state))

# Implementation helper: Launch after its evidence translated.
def launch_report(report: ReportResult, +state: P.State, evidence: P.Fact) -> Outcome:
  match report:
    case Report{target}:
      Stepped{P.open_session(state, P.revision(state), target, evidence, worker_role())}
    case NoReport{reason}:
      Untranslated{state, reason}

def launch_with(evidence: EvidenceResult, report: ReportResult, +state: P.State) -> Outcome:
  match evidence:
    case Evidence{fact}:
      launch_report(report, state, fact)
    case NoEvidence{reason}:
      Untranslated{state, reason}

# Implementation helper: the barrier's request; only a Use names the input to
# admit, and its claimed subject is discarded unread.
def barrier_use(message: W.Message, report: P.TargetReport, inventory: P.Fact, +state: P.State,
    +session: Nat, +now: Nat) -> Outcome:
  match message:
    case W.Use{ref, _, _, _}:
      Stepped{P.admit_worker(state, P.revision(state), report, inventory, session, ref, now)}
    case _:
      Unrouted{state}

def barrier_request(decoded: W.DecodeResult, report: P.TargetReport, inventory: P.Fact, +state: P.State,
    +session: Nat, +now: Nat) -> Outcome:
  match decoded:
    case W.Decoded{message}:
      barrier_use(message, report, inventory, state, session, now)
    case W.Malformed{reason}:
      Undecoded{state, reason}

def barrier_report(report: ReportResult, inventory: P.Fact, +state: P.State, +session: Nat,
    decoded: W.DecodeResult, +now: Nat) -> Outcome:
  match report:
    case Report{target}:
      barrier_request(decoded, target, inventory, state, session, now)
    case NoReport{reason}:
      Untranslated{state, reason}

def barrier_with(found: Maybe<&2, Rejection>, report: ReportResult, inventory: P.Fact, +state: P.State,
    +session: Nat, decoded: W.DecodeResult, +now: Nat) -> Outcome:
  match found:
    case None{}:
      barrier_report(report, inventory, state, session, decoded, now)
    case Some{reason}:
      Untranslated{state, reason}

def on_broker(+state: P.State, frame: BrokerFrame, +now: Nat) -> Outcome:
  match frame:
    case Launch{+fact}:
      launch_with(session_evidence_of(fact, current_incarnation(state)), report_of(fact), state)
    case Barrier{+session, +fact, request}:
      barrier_with(first_of(launch_check(fact, current_incarnation(state)),
        session_check(fact, P.identity(state), session)), report_of(fact), inventory_of(fact), state,
        session, W.decode_bytes(request), now)
    case Usage{worker, amount}:
      Stepped{P.charge(state, P.revision(state), P.ResourceRequest{worker, amount}, now)}
    case Emission{worker, public}:
      Stepped{P.diagnostic(state, P.revision(state), P.Diagnostic{worker, public}, now)}

# --- Dispatch: worker channel -----------------------------------------------------

# Implementation helper: a decoded worker message on its transport session.
def worker_message(+message: W.Message, +state: P.State, +session: Nat, +now: Nat) -> Outcome:
  match message:
    case W.Use{_, _, _, _}:
      Checked{state, P.use(state, P.revision(state), session, message, now)}
    case W.Delegate{ref, rights, lifetime, target}:
      Stepped{P.delegate(state, P.revision(state), session, ref, U32.to_nat(target), rights, U32.to_nat(lifetime),
        now)}
    case _:
      Unrouted{state}

def on_worker(+state: P.State, +session: Nat, decoded: W.DecodeResult, +now: Nat) -> Outcome:
  match decoded:
    case W.Decoded{message}:
      worker_message(message, state, session, now)
    case W.Malformed{reason}:
      Undecoded{state, reason}

# Public entry point: apply one framed input to the monitor's primitive state
# at monitor time `now` (see the header). The caller retains
# `Outcome.state(result)` before the broker performs `Outcome.effects(result)`.
def dispatch(+state: P.State, input: Input, +now: Nat) -> Outcome:
  match input:
    case FromBroker{frame}:
      on_broker(state, frame, now)
    case FromWorker{+session, bytes}:
      on_worker(state, session, W.decode_bytes(bytes), now)
