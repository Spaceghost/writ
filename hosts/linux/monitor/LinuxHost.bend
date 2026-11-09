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
# those transitions returned. It retains launch credentials and checks their
# session binding before admission; it adds no `HostIdentity`/`HostPrimitives`
# case and no law (LAWS.bend and
# PROOF.bend are untouched), and no native fact it carries is an authority
# fact. It imports nothing under `contrib/`, `examples/`, or another
# `hosts/` target, and the contract never imports it.
#
# Authority. Every grant, binding, profile, delegation, admission, quota, and
# release decision is a shared transition's. The monitor-owned records here
# include the successful Launch's session/credential records, plus the Linux host id and starting incarnation, the versioned
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
#   `credential_check`      missing, duplicate or mismatched retained launch
#                          credential for this incarnation/session -> LaunchMismatch
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
# Barrier binding. A Barrier's caller must match the session, and its launch
# credential must match the unique record retained from that same session's
# successful Launch in this incarnation (else LaunchMismatch). Both launch
# and peer must agree within each frame. These are comparisons of broker-framed
# model facts, not kernel authentication; the native broker must acquire and
# correlate real credentials, process lifetime, endpoint and session (Task 2).
# Imported primitive states have no launch records and fail closed at Barrier.
# Accepted restart clears the records; denied restart retains them. The endpoint is
# fixed at Launch (`open_session` records the origin) and ignored at the
# Barrier. The request snapshot is the only request admission reads; its
# reference must resolve on the barrier's session and its actual operation and
# rights must authorize execution. A divergent snapshot cannot grant rights
# beyond that resolved entry; the trusted broker must still copy it faithfully. A `Checked`/`Granted` result authorizes no
# broker action in section 1; Task 4's resource lookup must act on the
# monitor's resolution, never on worker bytes. The adapter implements no
# replay rule: a repeated Launch opens another session, so the broker issues
# one Launch per launch-record generation (Task 2 frames the generation).
#
# Dispatch. `dispatch` applies at most one shared transition per framed input:
#   Launch{fact}            -> `session_evidence_of`, `report_of`, then
#                              `P.open_session_result` with `worker_role()`
#   Barrier{s, fact, bytes} -> the launch check, `session_check`, the retained
#                              credential check, `report_of`, `inventory_of`,
#                              `W.decode_bytes`; the original Use goes to
#                              `P.admit_worker` on session `s`, with the
#                              separately supplied trusted authority snapshot
#   Usage{worker, amount}   -> `P.charge`
#   Emission{worker, public}-> `P.diagnostic`
#   FromWorker{s, bytes}    -> `W.decode_bytes`; Use -> `P.use` (read-only),
#                              Delegate -> `P.delegate` from session `s`
# The authority snapshot is an owner-side argument to dispatch/serve, never
# worker bytes. Its registry and Transfer projections need one trusted issuer,
# subject and sampled time; these subjectless grant lists cannot prove that.
# Checked/Granted from worker P.use is read-only and authorizes no release.
# A rejected fact (`Untranslated`), undecodable bytes (`Undecoded`), or a frame
# with no route in this task (`Unrouted`: a barrier request that is not a Use,
# and a worker Complete or Release, whose HostPublication transitions are
# section 2) runs no policy transition. A trusted clock sample may have
# advanced the clock component before this decision.
#
# Effects. `Outcome.effects` is the only effect list the broker executes. It
# is `P.Step.effects` of the step a shared transition returned, and empty for
# every other outcome, including a successful session open. The distinct
# `Opened` result exposes the exact ID returned by that same transition in
# memory only. `LINUXMON1` retains its old diagnostic format and is not a
# correlated session receipt. `P.Effect` is closed and has no publish variant, and no
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
# Failure behavior: every refusal preserves the supplied portable policy state
# and credential records and has no effect; a shared transition's denial is
# its `P.Denied` step unchanged. The separately retained clock may advance on
# a denial or malformed input, or become poisoned after a bad sample. This
# deliberately changes the older composite-state denial guarantee to meet
# LH-012 without changing the shared policy denial law. Samples come only from
# the trusted monitor owner, never from a worker or an untrusted frame.
#
# Public entry points: `linux_host`, `linux_incarnation`; `linux_worker_v1`,
# `profile_name`, `required_controls`, `linux_controls`, `quota_limit`,
# `linux_worker_profile`, `profiles`, `worker_role`, `initial`; the types
# `State`, `Clock`, `ClockSample`, `Credential`, `CredentialRecords`, `Endpoint`, `LinuxRoute`, `LinuxFact`, `Rejection`,
# `EvidenceResult`, `ReportResult`, `BrokerFrame`, `Input`, `Outcome`; the
# translators `launch_check`, `session_check`, `credential_check`, `session_evidence_of`, `report_of`,
# `inventory_of`; `portable`, `credentials`, `clock`, `without_credentials`, `restart`, `revoke`,
# `dispatch`, `serve`, `next`, `Outcome.state`, `Outcome.effects`, and
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
def initial() -> State:
  State{P.empty(I.empty(linux_host(), linux_incarnation()), profiles()), NoCredentials{}, FreshClock{}}

# --- Native facts (what the broker frames) ----------------------------------------

# A process credential: uid, gid, pid, and process start time (from
# `SO_PEERCRED` and `/proc/PID/stat`, matched through a pidfd). Local facts
# only.
type Credential is Data:
  Credential{uid: Nat, gid: Nat, pid: Nat, start: Nat}

# These records are monitor-owned observations, not portable credentials.
# A record is inserted only alongside the exact successful session opening.
type CredentialRecords is Data:
  NoCredentials{}
  CredentialRecord{incarnation: Nat, session: Nat, credential: Credential, rest: CredentialRecords}

# The owner supplies a checked sample before every untrusted request. Failed
# samples and regression poison the clock permanently for this instance.
# These public values do not authenticate the source or resist rollback. An
# equal sample is permitted; a frozen, replayed or slow clock is not detected.
type Clock is Data:
  FreshClock{}
  LiveClock{high: Nat}
  PoisonedClock{high: Maybe<&2, Nat>}

type ClockSample is Data:
  Sample{now: Nat}
  UnavailableClock{}
  AmbiguousClock{}
  OverflowClock{}

type State is Data:
  State{portable: P.State, credentials: CredentialRecords, clock: Clock}

def portable(state: State) -> P.State:
  match state:
    case State{p, _, _}: p

def credentials(state: State) -> CredentialRecords:
  match state:
    case State{_, records, _}: records

def clock(state: State) -> Clock:
  match state:
    case State{_, _, value}: value

def clock_poison(value: Clock) -> Clock:
  match value:
    case FreshClock{}: PoisonedClock{None{}}
    case LiveClock{high}: PoisonedClock{Some{high}}
    case PoisonedClock{high}: PoisonedClock{high}

def clock_update(value: Clock, sample: ClockSample) -> Clock:
  match value sample:
    case FreshClock{} Sample{now}: LiveClock{now}
    case LiveClock{+high} Sample{+now}:
      Bool.pick(Clock, Nat.is_le(high, now), LiveClock{now}, PoisonedClock{Some{high}})
    case PoisonedClock{high} _: PoisonedClock{high}
    case _ _: clock_poison(value)

def clock_current(value: Clock, now: Nat) -> Bool:
  match value:
    case LiveClock{high}: Nat.is_eq(high, now)
    case _: False{}

# Importing a primitive state never invents provenance for its sessions.
def without_credentials(state: P.State) -> State:
  State{state, NoCredentials{}, PoisonedClock{None{}}}

# Count all same-incarnation, same-session records; ambiguous state refuses.
type CredentialLookup is Data:
  NoCredential{}
  OneCredential{credential: Credential}
  ManyCredentials{}

def credential_found(found: CredentialLookup, credential: Credential) -> CredentialLookup:
  match found:
    case NoCredential{}: OneCredential{credential}
    case _: ManyCredentials{}

def credential_choose(same: Bool, found: CredentialLookup, credential: Credential) -> CredentialLookup:
  match same:
    case False{}: found
    case True{}: credential_found(found, credential)

def credential_lookup_acc(records: CredentialRecords, +incarnation: Nat, +session: Nat,
    found: CredentialLookup) -> CredentialLookup:
  match records:
    case NoCredentials{}: found
    case CredentialRecord{i, s, credential, rest}:
      credential_lookup_acc(rest, incarnation, session,
        credential_choose(Nat.is_eq(i, incarnation) && Nat.is_eq(s, session), found, credential))

def credential_lookup(records: CredentialRecords, incarnation: Nat, session: Nat) -> CredentialLookup:
  credential_lookup_acc(records, incarnation, session, NoCredential{})

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
  LaunchMismatch{}
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
    case LaunchMismatch{} LaunchMismatch{}: True{}
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
# nothing and binds the fact to no session; `session_check` and
# `credential_check` provide the model's Barrier comparisons. It refuses a
# fact whose own fields disagree.
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

# Bind the barrier to the unique credential retained at this session's launch.
def credential_matches(found: CredentialLookup, launch: Credential) -> Maybe<&2, Rejection>:
  match found:
    case OneCredential{credential}:
      reject_if(Bool.not(credential_equal(credential, launch)), LaunchMismatch{}, None{})
    case _: Some{LaunchMismatch{}}

def credential_check(fact: LinuxFact, records: CredentialRecords, incarnation: Nat, session: Nat) -> Maybe<&2, Rejection>:
  match fact:
    case LinuxFact{_, _, _, launch, _, _, _, _, _}:
      credential_matches(credential_lookup(records, incarnation, session), launch)

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

# What one input did. `Opened` carries the exact session issued by the shared
# transition for a successful Launch. It is an in-memory descriptive value,
# not a correlated wire receipt or evidence of native caller authentication.
# `Stepped` holds any other step a shared transition returned;
# `Checked` a read-only `P.use` result; the other three run no policy
# transition. They retain the state after the independent clock sample.
type Outcome is Data:
  Opened{state: State, session: Nat}
  Stepped{credentials: CredentialRecords, clock: Clock, step: P.Step}
  Checked{state: State, result: P.UseResult}
  Untranslated{state: State, reason: Rejection}
  Undecoded{state: State, reason: W.WireError}
  Unrouted{state: State}
  ClockFault{state: State}

def Outcome.state(outcome: Outcome) -> State:
  match outcome:
    case Opened{state, _}: state
    case Stepped{records, time, step}: State{P.Step.state(step), records, time}
    case Checked{state, _}: state
    case Untranslated{state, _}: state
    case Undecoded{state, _}: state
    case Unrouted{state}: state
    case ClockFault{state}: state

def Outcome.effects(outcome: Outcome) -> +List<P.Effect>:
  match outcome:
    case Stepped{_, _, step}: P.Step.effects(step)
    case _: []

# Faulting changes only the clock, never policy state or launch credentials.
def clock_fault(state: State) -> Outcome:
  match state:
    case State{p, records, time}: ClockFault{State{p, records, clock_poison(time)}}

# The trusted caller of this existing implementation helper must supply the
# actual same-call shared Step. This helper cannot verify Step provenance;
# public constructors/Steps are not authenticated and cannot establish effects.
def stepped(+state: State, +step: P.Step, now: Nat) -> Outcome:
  f = Bool.pick(Unit -> Outcome, clock_current(clock(state), now),
    x => Stepped{credentials(state), clock(state), step}, x => clock_fault(state))
  f(Unit{})

# Clear launch bindings only when the shared restart actually commits. The
# cleanup result is derived here, never supplied as an arbitrary Step.
def restart(+state: State, +expected_revision: Nat, successor: Nat) -> Outcome:
  +step = H.restart(portable(state), expected_revision, successor)
  accepted = Bool.not(Maybe.is_some(&2, P.Error, P.Step.reason(step)))
  Stepped{Bool.pick(CredentialRecords, accepted, NoCredentials{}, credentials(state)), clock(state), step}

# Trusted in-process monitor action: authorization to retire this slot has
# already been established by the owning monitor, never by worker bytes or a
# slot alone. Retain the returned state before executing its StopEffects.
# This neither authenticates the action nor connects Issuance revocation or
# any native transport; the shared transition supplies all checks and effects.
def revoke(+state: State, +expected_revision: Nat, +slot: Nat) -> Outcome:
  Stepped{credentials(state), clock(state), H.revoke(portable(state), expected_revision, slot)}

def current_incarnation(state: State) -> Nat:
  I.incarnation(P.identity(portable(state)))

def launch_result(+result: P.SessionOpen, +state: State, credential: Credential, now: Nat) -> Outcome:
  match result:
    case P.SessionOpened{p, session}:
      f = Bool.pick(Unit -> Outcome, clock_current(clock(state), now),
        x => Opened{State{p, CredentialRecord{current_incarnation(state), session, credential, credentials(state)},
          clock(state)}, session}, x => clock_fault(state))
      f(Unit{})
    case P.SessionOpenDenied{_, _}:
      stepped(state, P.SessionOpen.step(result), now)

def launch_report(report: ReportResult, +state: State, evidence: P.Fact, credential: Credential, +now: Nat) -> Outcome:
  match report:
    case Report{target}:
      +p = portable(state)
      f = Bool.pick(Unit -> Outcome, clock_current(clock(state), now),
        x => launch_result(P.open_session_result(p, P.revision(p), target, evidence, worker_role()), state, credential, now),
        x => clock_fault(state))
      f(Unit{})
    case NoReport{reason}: Untranslated{state, reason}

def launch_with(evidence: EvidenceResult, report: ReportResult, +state: State, credential: Credential, now: Nat) -> Outcome:
  match evidence:
    case Evidence{fact}: launch_report(report, state, fact, credential, now)
    case NoEvidence{reason}: Untranslated{state, reason}

def barrier_checks(+fact: LinuxFact, +state: State, +session: Nat) -> Maybe<&2, Rejection>:
  first_of(launch_check(fact, current_incarnation(state)),
    first_of(session_check(fact, P.identity(portable(state)), session),
      credential_check(fact, credentials(state), current_incarnation(state), session)))

def barrier_reason(found: Maybe<&2, Rejection>) -> Rejection:
  match found:
    case Some{reason}: reason
    case None{}: LaunchMismatch{}

def barrier_is_use(message: W.Message) -> Bool:
  match message:
    case W.Use{_, _, _, _}: True{}
    case _: False{}

# Recompute provenance here even for direct trusted-helper callers. No
# caller-supplied preflight result can reach the shared admission entry.
def barrier_with(+message: W.Message, report: P.TargetReport, inventory: P.Fact, +state: State,
    +session: Nat, +fact: LinuxFact, +now: Nat, authority: P.AdmissionAuthority) -> Outcome:
  ({+found => Bool.pick(Unit -> Outcome, Maybe.is_some(&2, Rejection, found),
    x => Untranslated{state, barrier_reason(found)},
    x => Bool.pick(Unit -> Outcome, barrier_is_use(message),
      y => Bool.pick(Unit -> Outcome, clock_current(clock(state), now),
        z => stepped(state, P.admit_worker(portable(state), P.revision(portable(state)), report, inventory,
          session, message, now, authority), now), z => clock_fault(state))(Unit{}),
      y => Unrouted{state})(Unit{}))(Unit{}) : Maybe<&2, Rejection> -> Outcome})(barrier_checks(fact, state, session))

def barrier_use(message: W.Message, report: P.TargetReport, inventory: P.Fact, state: State,
    session: Nat, fact: LinuxFact, now: Nat, authority: P.AdmissionAuthority) -> Outcome:
  barrier_with(message, report, inventory, state, session, fact, now, authority)

def barrier_request(decoded: W.DecodeResult, report: P.TargetReport, inventory: P.Fact, +state: State,
    +session: Nat, fact: LinuxFact, +now: Nat, authority: P.AdmissionAuthority) -> Outcome:
  match decoded:
    case W.Decoded{message}: barrier_use(message, report, inventory, state, session, fact, now, authority)
    case W.Malformed{reason}: Undecoded{state, reason}

def barrier_report(report: ReportResult, inventory: P.Fact, +state: State, +session: Nat,
    fact: LinuxFact, decoded: W.DecodeResult, +now: Nat, authority: P.AdmissionAuthority) -> Outcome:
  match report:
    case Report{target}: barrier_request(decoded, target, inventory, state, session, fact, now, authority)
    case NoReport{reason}: Untranslated{state, reason}

# Preserve provenance denial before report or request decoding; rechecked at
# the final shared admission call as well.
def barrier_preflight(report: ReportResult, inventory: P.Fact, +state: State,
    +session: Nat, +fact: LinuxFact, decoded: W.DecodeResult, +now: Nat, authority: P.AdmissionAuthority) -> Outcome:
  ({+found => Bool.pick(Unit -> Outcome, Maybe.is_some(&2, Rejection, found),
    x => Untranslated{state, barrier_reason(found)},
    x => barrier_report(report, inventory, state, session, fact, decoded, now, authority))(Unit{})
    : Maybe<&2, Rejection> -> Outcome})(barrier_checks(fact, state, session))

def on_broker(+state: State, frame: BrokerFrame, +now: Nat, authority: P.AdmissionAuthority) -> Outcome:
  match frame:
    case Launch{+fact}:
      match fact:
        case LinuxFact{_, _, _, credential, _, _, _, _, _}:
          f = Bool.pick(Unit -> Outcome, clock_current(clock(state), now),
            x => launch_with(session_evidence_of(fact, current_incarnation(state)), report_of(fact), state, credential, now),
            x => clock_fault(state))
          f(Unit{})
    case Barrier{+session, +fact, request}:
      f = Bool.pick(Unit -> Outcome, clock_current(clock(state), now),
        x => barrier_preflight(report_of(fact), inventory_of(fact), state,
          session, fact, W.decode_bytes(request), now, authority), x => clock_fault(state))
      f(Unit{})
    case Usage{worker, amount}:
      +p = portable(state)
      f = Bool.pick(Unit -> Outcome, clock_current(clock(state), now),
        x => stepped(state, P.charge(p, P.revision(p), P.ResourceRequest{worker, amount}, now), now),
        x => clock_fault(state))
      f(Unit{})
    case Emission{worker, public}:
      +p = portable(state)
      f = Bool.pick(Unit -> Outcome, clock_current(clock(state), now),
        x => stepped(state, P.diagnostic(p, P.revision(p), P.Diagnostic{worker, public}, now), now),
        x => clock_fault(state))
      f(Unit{})

def worker_message(+message: W.Message, +state: State, +session: Nat, +now: Nat) -> Outcome:
  match message:
    case W.Use{_, _, _, _}:
      +p = portable(state)
      f = Bool.pick(Unit -> Outcome, clock_current(clock(state), now),
        x => Checked{state, P.use(p, P.revision(p), session, message, now)}, x => clock_fault(state))
      f(Unit{})
    case W.Delegate{ref, rights, lifetime, target}:
      +p = portable(state)
      f = Bool.pick(Unit -> Outcome, clock_current(clock(state), now),
        x => stepped(state, P.delegate(p, P.revision(p), session, ref, U32.to_nat(target), rights, U32.to_nat(lifetime), now), now),
        x => clock_fault(state))
      f(Unit{})
    case _: Unrouted{state}

def on_worker(+state: State, +session: Nat, decoded: W.DecodeResult, +now: Nat) -> Outcome:
  match decoded:
    case W.Decoded{message}: worker_message(message, state, session, now)
    case W.Malformed{reason}:
      f = Bool.pick(Unit -> Outcome, clock_current(clock(state), now),
        x => Undecoded{state, reason}, x => clock_fault(state))
      f(Unit{})

# Trusted implementation helper, not a broker/native entry. Equality with a
# retained high-water mark does not prove this is a fresh physical sample;
# the private owner must call `dispatch` or `serve` with an actual new sample.
def route_sampled(+state: State, input: Input, +now: Nat, authority: P.AdmissionAuthority) -> Outcome:
  match input:
    case FromBroker{frame}:
      f = Bool.pick(Unit -> Outcome, clock_current(clock(state), now),
        x => on_broker(state, frame, now, authority), x => clock_fault(state))
      f(Unit{})
    case FromWorker{+session, bytes}:
      f = Bool.pick(Unit -> Outcome, clock_current(clock(state), now),
        x => on_worker(state, session, W.decode_bytes(bytes), now), x => clock_fault(state))
      f(Unit{})

# The sample is supplied by the trusted owner, not by `Input`. A malformed or
# denied request still retains the sampled clock independently of policy.
def dispatch(state: State, input: Input, sample: ClockSample, authority: P.AdmissionAuthority) -> Outcome:
  match state sample:
    case State{p, records, old} Sample{+now}:
      +updated = clock_update(old, Sample{now})
      +next = {State{p, records, updated} : State}
      f = Bool.pick(Unit -> Outcome, clock_current(updated, now),
        x => route_sampled(next, input, now, authority), x => clock_fault(next))
      f(Unit{})
    case State{p, records, old} _:
      ClockFault{State{p, records, clock_poison(old)}}

# --- Broker channel codec and monitor service (task 1.2) --------------------------
#
# The proposed broker frame layout for the monitor's private request channel,
# and the one reply line the
# monitor returns. The codec is a boundary, not policy: it turns bytes into an
# `Input` and runs the same checked route as `dispatch`; every decision is still the translators' and
# the shared transitions'. It does not check family or control bits (that is
# `report_of`'s UnknownFamily/UncreditedControl) and never reads a worker's
# request bytes (they reach only `W.decode_bytes` through `dispatch`).
#
# Layout `LINUXB` version 1. Every field is one U32 word carried little-endian
# (4 bytes, least significant first), as HostWire. Word 0 is
# `frame_version()`, word 1 the tag, word 2 the body length in words, then the
# body:
#   tag 1 Launch    fact
#   tag 2 Barrier   session, fact, request
#   tag 3 Usage     worker, amount
#   tag 4 Emission  worker, public (0 or 1)
#   tag 5 Worker    session, request          (the `FromWorker` channel)
# fact (25 words, then 3 per route): subject, token (8 words), incarnation,
#   launch credential (uid, gid, pid, start low word, start high word),
#   peer credential (same five), endpoint kind (0 Launched, 1 InheritedFrom,
#   2 TransferredFrom), endpoint session (0 when Launched), families,
#   controls, route count (at most `max_routes()`), then per route:
#   descriptor, kind, mediated (0 or 1).
# request: a byte count (at most `max_request_bytes()`), then that many words,
#   each one byte value of the worker's frame, uninterpreted here.
# Tag 5 is the only way worker bytes reach the worker channel, and only the
# broker writes this channel: a worker writes its session socket, never this
# one, so worker bytes are framed as a request and cannot be read as a fact.
#
# Failure behavior: decoding is total and returns `Framed{input}` or
# `Unframed{reason}`. Check order: more than `max_frame_bytes()` bytes ->
# FrameTooLong; a byte count not a multiple of 4 -> FrameMisaligned; a value
# above 255 -> FrameRange; fewer than three header words -> FrameLength;
# version -> FrameVersion; header length differing from the body's word count
# -> FrameLength; unknown tag -> FrameTag; a body shorter or longer than its
# tag's layout -> FrameLength; an endpoint kind, mediated or public flag, route
# count, or request count out of its bound -> FrameRange. An unframed input
# runs no policy transition and keeps the state after the trusted sample.
#
# Service. `serve(state, bytes, sample)` samples before decoding one frame;
# `next` is the state the monitor retains before the broker performs
# `served_effects`; `reply` is one ASCII line
#   LINUXMON1 <TAB> status <TAB> detail <TAB> table <LF>
# status: ADMITTED, DENIED (a shared transition's step), GRANTED, REFUSED (a
# read-only `P.use` result), UNTRANSLATED (a translator rejection),
# UNDECODED (a HostWire error), UNROUTED, UNFRAMED (a codec error); detail:
# the effect count, the error or rejection name, or the granted caller's
# subject; table: the retained revision and up to `max_rendered_sessions()`
# sessions as id:caller-subject:origin. The reply carries no worker byte and
# no payload; it is the broker's only view of a decision.

def frame_version() -> U32:
  1

def frame_launch() -> U32:
  1

def frame_barrier() -> U32:
  2

def frame_usage() -> U32:
  3

def frame_emission() -> U32:
  4

def frame_worker() -> U32:
  5

# The most routes one fact may carry, the broker's request snapshot cap (one
# word above the longest HostWire frame, so an oversized worker frame reaches
# `W.decode_bytes` and is refused TooLong there), and the frame byte cap.
def max_routes() -> Nat:
  16n

def max_request_bytes() -> Nat:
  Nat.add(W.max_bytes(), 4n)

def max_frame_bytes() -> Nat:
  512n

def max_rendered_sessions() -> Nat:
  8n

# 2^32, the weight of a high word.
def word_span() -> Nat:
  Nat.add(4294967295n, 1n)

type FrameError is Data:
  FrameTooLong{}
  FrameMisaligned{}
  FrameRange{}
  FrameVersion{}
  FrameTag{}
  FrameLength{}

type FrameResult is Data:
  Framed{input: Input}
  Unframed{reason: FrameError}

type Served is Data:
  Served{outcome: Outcome}
  NotFramed{state: State, reason: FrameError}

# Implementation helper types for the decoder.
type Packed is Data:
  Packed{words: +List<U32>}
  Unpacked{reason: FrameError}

type FrameKind is Data:
  KindLaunch{}
  KindBarrier{}
  KindUsage{}
  KindEmission{}
  KindWorker{}
  KindUnknown{}

type RoutesRead is Data:
  RoutesRead{routes: +List<LinuxRoute>, rest: +List<U32>}
  RoutesBad{reason: FrameError}

type FactRead is Data:
  FactRead{fact: LinuxFact, rest: +List<U32>}
  FactBad{reason: FrameError}

type RequestRead is Data:
  RequestRead{bytes: +List<U32>}
  RequestBad{reason: FrameError}

def FrameError.equal(a: FrameError, b: FrameError) -> Bool:
  match a b:
    case FrameTooLong{} FrameTooLong{}: True{}
    case FrameMisaligned{} FrameMisaligned{}: True{}
    case FrameRange{} FrameRange{}: True{}
    case FrameVersion{} FrameVersion{}: True{}
    case FrameTag{} FrameTag{}: True{}
    case FrameLength{} FrameLength{}: True{}
    case _ _: False{}

# Implementation helper: four little-endian byte values as one word.
def pack_word(b0: U32, b1: U32, b2: U32, b3: U32) -> U32:
  U32.or(U32.or(b0, U32.shln(b1, 8n)), U32.or(U32.shln(b2, 16n), U32.shln(b3, 24n)))

def prepend_word(word: U32, rest: Packed) -> Packed:
  match rest:
    case Packed{words}:
      Packed{word <> words}
    case Unpacked{reason}:
      Unpacked{reason}

# Implementation helper: bytes to words, four at a time; a remainder is
# FrameMisaligned.
def pack(bytes: +List<U32>) -> Packed:
  match bytes:
    case []:
      Packed{[]}
    case b0 <> b1 <> b2 <> b3 <> rest:
      prepend_word(pack_word(b0, b1, b2, b3), pack(rest))
    case _:
      Unpacked{FrameMisaligned{}}

def all_bytes(bytes: +List<U32>) -> Bool:
  match bytes:
    case []:
      True{}
    case byte <> rest:
      U32.is_le(byte, 255) && all_bytes(rest)

def nat_of(word: U32) -> Nat:
  U32.to_nat(word)

def credential_of(uid: U32, gid: U32, pid: U32, low: U32, high: U32) -> Credential:
  Credential{nat_of(uid), nat_of(gid), nat_of(pid), Nat.add(nat_of(low), Nat.mul(nat_of(high), word_span()))}

# Implementation helpers: `chosen` when `ok`, otherwise `otherwise`.
def pick_flag(ok: Bool, chosen: Maybe<&2, Bool>, otherwise: Maybe<&2, Bool>) -> Maybe<&2, Bool>:
  match ok:
    case True{}:
      chosen
    case False{}:
      otherwise

def pick_endpoint(ok: Bool, chosen: Maybe<&2, Endpoint>, otherwise: Maybe<&2, Endpoint>) -> Maybe<&2, Endpoint>:
  match ok:
    case True{}:
      chosen
    case False{}:
      otherwise

def pick_kind(ok: Bool, chosen: FrameKind, otherwise: FrameKind) -> FrameKind:
  match ok:
    case True{}:
      chosen
    case False{}:
      otherwise

def pick_frame(ok: Bool, chosen: FrameResult, otherwise: FrameResult) -> FrameResult:
  match ok:
    case True{}:
      chosen
    case False{}:
      otherwise

def pick_request(ok: Bool, chosen: RequestRead, otherwise: RequestRead) -> RequestRead:
  match ok:
    case True{}:
      chosen
    case False{}:
      otherwise

# A 0/1 flag word; any other value is out of range.
def flag_of(+word: U32) -> Maybe<&2, Bool>:
  pick_flag(U32.is_eq(word, 0), Some{False{}}, pick_flag(U32.is_eq(word, 1), Some{True{}}, None{}))

# The endpoint kind and session words; a Launched endpoint names no session.
def endpoint_of(+kind: U32, +from: U32) -> Maybe<&2, Endpoint>:
  pick_endpoint(U32.is_eq(kind, 0) && U32.is_eq(from, 0), Some{Launched{}},
    pick_endpoint(U32.is_eq(kind, 1), Some{InheritedFrom{nat_of(from)}},
      pick_endpoint(U32.is_eq(kind, 2), Some{TransferredFrom{nat_of(from)}}, None{})))

def route_then(mediated: Maybe<&2, Bool>, descriptor: Nat, kind: U32, rest: RoutesRead) -> RoutesRead:
  match mediated rest:
    case Some{flag} RoutesRead{routes, after}:
      RoutesRead{LinuxRoute{descriptor, kind, flag} <> routes, after}
    case None{} _:
      RoutesBad{FrameRange{}}
    case Some{_} RoutesBad{reason}:
      RoutesBad{reason}

def parse_routes(count: Nat, words: +List<U32>) -> RoutesRead:
  match count:
    case 0n:
      RoutesRead{[], words}
    case 1n+left:
      match words:
        case descriptor <> kind <> mediated <> rest:
          route_then(flag_of(mediated), nat_of(descriptor), kind, parse_routes(left, rest))
        case _:
          RoutesBad{FrameLength{}}

def routes_bounded(over: Bool, count: Nat, words: +List<U32>) -> RoutesRead:
  match over:
    case True{}:
      RoutesBad{FrameRange{}}
    case False{}:
      parse_routes(count, words)

def routes_within(+count: U32, words: +List<U32>) -> RoutesRead:
  routes_bounded(Nat.is_gt(nat_of(count), max_routes()), nat_of(count), words)

def fact_with_routes(endpoint: Maybe<&2, Endpoint>, subject: Nat, token: T.CodeId, incarnation: Nat,
    launch: Credential, peer: Credential, families: U32, controls: U32, routes: RoutesRead) -> FactRead:
  match endpoint routes:
    case Some{arrived} RoutesRead{list, rest}:
      FactRead{LinuxFact{subject, token, incarnation, launch, peer, arrived, families, controls, list}, rest}
    case None{} _:
      FactBad{FrameRange{}}
    case Some{_} RoutesBad{reason}:
      FactBad{reason}

def parse_fact(words: +List<U32>) -> FactRead:
  match words:
    case subject <> a <> b <> c <> d <> e <> f <> g <> h <> incarnation <> lu <> lg <> lp <> ll <> lh <> pu <> pg <>
        pp <> pl <> ph <> kind <> from <> families <> controls <> count <> rest:
      fact_with_routes(endpoint_of(kind, from), nat_of(subject), T.CodeId{a, b, c, d, e, f, g, h}, nat_of(incarnation),
        credential_of(lu, lg, lp, ll, lh), credential_of(pu, pg, pp, pl, ph), families, controls,
        routes_within(count, rest))
    case _:
      FactBad{FrameLength{}}

# A request: its count, then exactly that many byte words, ending the body.
def parse_request(words: +List<U32>) -> RequestRead:
  match words:
    case +count <> +rest:
      pick_request(Nat.is_gt(nat_of(count), max_request_bytes()), RequestBad{FrameRange{}},
        pick_request(Nat.is_eq(nat_of(count), List.length(&2, U32, rest)), RequestRead{rest},
          RequestBad{FrameLength{}}))
    case _:
      RequestBad{FrameLength{}}

def broker_input(frame: BrokerFrame) -> FrameResult:
  Framed{FromBroker{frame}}

def launch_body(read: FactRead) -> FrameResult:
  match read:
    case FactRead{fact, []}:
      broker_input(Launch{fact})
    case FactRead{_, _}:
      Unframed{FrameLength{}}
    case FactBad{reason}:
      Unframed{reason}

def barrier_request_of(session: Nat, fact: LinuxFact, request: RequestRead) -> FrameResult:
  match request:
    case RequestRead{bytes}:
      broker_input(Barrier{session, fact, bytes})
    case RequestBad{reason}:
      Unframed{reason}

def barrier_fact(session: Nat, read: FactRead) -> FrameResult:
  match read:
    case FactRead{fact, rest}:
      barrier_request_of(session, fact, parse_request(rest))
    case FactBad{reason}:
      Unframed{reason}

def barrier_body(body: +List<U32>) -> FrameResult:
  match body:
    case session <> rest:
      barrier_fact(nat_of(session), parse_fact(rest))
    case _:
      Unframed{FrameLength{}}

def usage_body(body: +List<U32>) -> FrameResult:
  match body:
    case [worker, amount]:
      broker_input(Usage{nat_of(worker), nat_of(amount)})
    case _:
      Unframed{FrameLength{}}

def emission_flag(worker: Nat, flag: Maybe<&2, Bool>) -> FrameResult:
  match flag:
    case Some{public}:
      broker_input(Emission{worker, public})
    case None{}:
      Unframed{FrameRange{}}

def emission_body(body: +List<U32>) -> FrameResult:
  match body:
    case [worker, public]:
      emission_flag(nat_of(worker), flag_of(public))
    case _:
      Unframed{FrameLength{}}

def worker_request(session: Nat, request: RequestRead) -> FrameResult:
  match request:
    case RequestRead{bytes}:
      Framed{FromWorker{session, bytes}}
    case RequestBad{reason}:
      Unframed{reason}

def worker_body(body: +List<U32>) -> FrameResult:
  match body:
    case session <> rest:
      worker_request(nat_of(session), parse_request(rest))
    case _:
      Unframed{FrameLength{}}

def frame_kind(+tag: U32) -> FrameKind:
  pick_kind(U32.is_eq(tag, frame_launch()), KindLaunch{},
    pick_kind(U32.is_eq(tag, frame_barrier()), KindBarrier{},
      pick_kind(U32.is_eq(tag, frame_usage()), KindUsage{},
        pick_kind(U32.is_eq(tag, frame_emission()), KindEmission{},
          pick_kind(U32.is_eq(tag, frame_worker()), KindWorker{}, KindUnknown{})))))

def frame_body(kind: FrameKind, body: +List<U32>) -> FrameResult:
  match kind:
    case KindLaunch{}:
      launch_body(parse_fact(body))
    case KindBarrier{}:
      barrier_body(body)
    case KindUsage{}:
      usage_body(body)
    case KindEmission{}:
      emission_body(body)
    case KindWorker{}:
      worker_body(body)
    case KindUnknown{}:
      Unframed{FrameTag{}}

def frame_words(+words: +List<U32>) -> FrameResult:
  match words:
    case +version <> +tag <> +length <> +body:
      pick_frame(Bool.not(U32.is_eq(version, frame_version())), Unframed{FrameVersion{}},
        pick_frame(Bool.not(Nat.is_eq(nat_of(length), List.length(&2, U32, body))), Unframed{FrameLength{}},
          frame_body(frame_kind(tag), body)))
    case _:
      Unframed{FrameLength{}}

def frame_in_range(in_range: Bool, packed: Packed) -> FrameResult:
  match packed:
    case Unpacked{reason}:
      Unframed{reason}
    case Packed{words}:
      pick_frame(in_range, frame_words(words), Unframed{FrameRange{}})

# Bound the input before running the non-tail-recursive frame parsers. A
# branch, rather than a value-selecting helper, keeps generated backends from
# evaluating the parser on an oversized frame.
def frame_within(fuel: Nat, bytes: +List<U32>) -> Bool:
  match fuel bytes:
    case _ Nil{}:
      True{}
    case 0n Con{_, _}:
      False{}
    case 1n+remaining Con{_, rest}:
      frame_within(remaining, rest)

def decode_bounded(within: Bool, +bytes: +List<U32>) -> FrameResult:
  match within:
    case False{}:
      Unframed{FrameTooLong{}}
    case True{}:
      frame_in_range(all_bytes(bytes), pack(bytes))

# Public entry point: decode one broker-channel frame (see the layout above).
def decode_frame(+bytes: +List<U32>) -> FrameResult:
  decode_bounded(frame_within(max_frame_bytes(), bytes), bytes)

def served_of(result: FrameResult, +state: State, +now: Nat, authority: P.AdmissionAuthority) -> Served:
  match result:
    case Framed{input}:
      Served{route_sampled(state, input, now, authority)}
    case Unframed{reason}:
      f = Bool.pick(Unit -> Served, clock_current(clock(state), now),
        x => NotFramed{state, reason}, x => Served{clock_fault(state)})
      f(Unit{})

# Sample before decoding; malformed input cannot suppress a clock observation.
def serve(state: State, bytes: +List<U32>, sample: ClockSample, authority: P.AdmissionAuthority) -> Served:
  match state sample:
    case State{p, records, old} Sample{+now}:
      +updated = clock_update(old, Sample{now})
      +next = {State{p, records, updated} : State}
      f = Bool.pick(Unit -> Served, clock_current(updated, now),
        x => served_of(decode_frame(bytes), next, now, authority), x => Served{clock_fault(next)})
      f(Unit{})
    case State{p, records, old} _:
      Served{ClockFault{State{p, records, clock_poison(old)}}}

# Public entry point: the state the monitor retains before any effect.
def next(served: Served) -> State:
  match served:
    case Served{outcome}:
      Outcome.state(outcome)
    case NotFramed{state, _}:
      state

# Public entry point: the only effects the broker may execute for a frame.
def served_effects(served: Served) -> +List<P.Effect>:
  match served:
    case Served{outcome}:
      Outcome.effects(outcome)
    case NotFramed{_, _}:
      []

# --- Reply rendering ----------------------------------------------------------------

def identity_error_name(error: I.Error) -> String:
  match error:
    case I.ForeignHost{}: "ForeignHost"
    case I.StaleIncarnation{}: "StaleIncarnation"
    case I.Forged{}: "Forged"
    case I.Retired{}: "Retired"
    case I.Ambiguous{}: "Ambiguous"
    case I.StaleGeneration{}: "StaleGeneration"
    case I.NotHolder{}: "NotHolder"
    case I.InheritedEndpoint{}: "InheritedEndpoint"
    case I.TransferredEndpoint{}: "TransferredEndpoint"
    case I.SubjectChanged{}: "SubjectChanged"
    case I.NotDelegable{}: "NotDelegable"
    case I.WidenedRights{}: "WidenedRights"
    case I.WidenedLifetime{}: "WidenedLifetime"
    case I.Expired{}: "Expired"
    case I.UnknownSession{}: "UnknownSession"
    case I.StaleRevision{}: "StaleRevision"

def error_name(error: P.Error) -> String:
  match error:
    case P.Identity{inner}: "Identity:" ++ identity_error_name(inner)
    case P.UnsupportedFamily{}: "UnsupportedFamily"
    case P.MissingControl{}: "MissingControl"
    case P.UnmediatedRoute{}: "UnmediatedRoute"
    case P.UnisolatedAccelerator{}: "UnisolatedAccelerator"
    case P.QuotaExhausted{}: "QuotaExhausted"
    case P.DiagnosticSink{}: "DiagnosticSink"
    case P.FastPathUnavailable{}: "FastPathUnavailable"
    case P.UnknownWorker{}: "UnknownWorker"
    case P.WrongPhase{}: "WrongPhase"
    case P.StaleRevision{}: "StaleRevision"
    case P.UnknownProfile{}: "UnknownProfile"
    case P.DelegableSession{}: "DelegableSession"
    case P.SlotOccupied{}: "SlotOccupied"
    case P.RightsNotHeld{}: "RightsNotHeld"
    case P.OperationNotPermitted{}: "OperationNotPermitted"
    case P.LiveWriter{}: "LiveWriter"
    case P.NotSealed{}: "NotSealed"
    case P.Retargeted{}: "Retargeted"
    case P.ArtifactMismatch{}: "ArtifactMismatch"
    case P.CommitRejected{}: "CommitRejected"
    case P.Replay{}: "Replay"
    case P.Substitution{}: "Substitution"
    case P.Unrecorded{}: "Unrecorded"
    case P.NotQuiesced{}: "NotQuiesced"
    case P.PlanMismatch{}: "PlanMismatch"
    case P.OwnerMismatch{}: "OwnerMismatch"
    case P.LeaseExceeded{}: "LeaseExceeded"
    case P.AuthorityUnavailable{}: "AuthorityUnavailable"

def rejection_name(reason: Rejection) -> String:
  match reason:
    case StaleLaunch{}: "StaleLaunch"
    case PeerMismatch{}: "PeerMismatch"
    case SessionMismatch{}: "SessionMismatch"
    case LaunchMismatch{}: "LaunchMismatch"
    case UnknownFamily{}: "UnknownFamily"
    case UncreditedControl{}: "UncreditedControl"

def wire_error_name(reason: W.WireError) -> String:
  match reason:
    case W.UnknownVersion{}: "UnknownVersion"
    case W.UnknownTag{}: "UnknownTag"
    case W.BadLength{}: "BadLength"
    case W.TooLong{}: "TooLong"
    case W.OutOfRange{}: "OutOfRange"

def frame_error_name(reason: FrameError) -> String:
  match reason:
    case FrameTooLong{}: "FrameTooLong"
    case FrameMisaligned{}: "FrameMisaligned"
    case FrameRange{}: "FrameRange"
    case FrameVersion{}: "FrameVersion"
    case FrameTag{}: "FrameTag"
    case FrameLength{}: "FrameLength"

def step_status(step: P.Step) -> String:
  match step:
    case P.Admitted{_, _}: "ADMITTED"
    case P.Denied{_, _}: "DENIED"

def step_detail(step: P.Step) -> String:
  match step:
    case P.Admitted{_, effects}: "effects=" ++ Nat.show(List.length(&2, P.Effect, effects))
    case P.Denied{_, reason}: error_name(reason)

def use_status(result: P.UseResult) -> String:
  match result:
    case P.Granted{_, _}: "GRANTED"
    case P.Refused{_}: "REFUSED"

def use_detail(result: P.UseResult) -> String:
  match result:
    case P.Granted{_, caller}: "caller=" ++ Nat.show(I.caller_subject(caller))
    case P.Refused{reason}: error_name(reason)

def outcome_status(outcome: Outcome) -> String:
  match outcome:
    case Opened{_, _}: "ADMITTED"
    case Stepped{_, _, step}: step_status(step)
    case Checked{_, result}: use_status(result)
    case Untranslated{_, _}: "UNTRANSLATED"
    case Undecoded{_, _}: "UNDECODED"
    case Unrouted{_}: "UNROUTED"
    case ClockFault{_}: "CLOCKFAULT"

def outcome_detail(outcome: Outcome) -> String:
  match outcome:
    case Opened{_, _}: "effects=0"
    case Stepped{_, _, step}: step_detail(step)
    case Checked{_, result}: use_detail(result)
    case Untranslated{_, reason}: rejection_name(reason)
    case Undecoded{_, reason}: wire_error_name(reason)
    case Unrouted{_}: "-"
    case ClockFault{_}: "CLOCK"

def served_status(served: Served) -> String:
  match served:
    case Served{outcome}: outcome_status(outcome)
    case NotFramed{_, _}: "UNFRAMED"

def served_detail(served: Served) -> String:
  match served:
    case Served{outcome}: outcome_detail(outcome)
    case NotFramed{_, reason}: frame_error_name(reason)

def origin_text(origin: I.Origin) -> String:
  match origin:
    case I.Authenticated{}: "A"
    case I.Inherited{parent}: "I" ++ Nat.show(parent)
    case I.Transferred{from}: "T" ++ Nat.show(from)

def session_text(session: I.Session) -> String:
  match session:
    case I.Session{id, _, caller, origin, _}:
      Nat.show(id) ++ ":" ++ Nat.show(I.caller_subject(caller)) ++ ":" ++ origin_text(origin)

def session_texts(sessions: I.Sessions, budget: Nat) -> List<&2, String>:
  match sessions:
    case I.NoSessions{}:
      []
    case I.Sessions{session, rest}:
      match budget:
        case 0n:
          ["+"]
        case 1n+left:
          session_text(session) <> session_texts(rest, left)

def sessions_field(texts: List<&2, String>) -> String:
  match texts:
    case []:
      "-"
    case first <> rest:
      String.join(first <> rest, ",")

def table_of(+state: State) -> String:
  +p = portable(state)
  "rev=" ++ Nat.show(P.revision(p)) ++ ";" ++
    sessions_field(session_texts(I.sessions(P.identity(p)), max_rendered_sessions()))

# Public entry point: the one reply line for a served frame (see above).
def reply(+served: Served) -> String:
  String.join(["LINUXMON1", served_status(served), served_detail(served), table_of(next(served))], "\t") ++ "\n"
