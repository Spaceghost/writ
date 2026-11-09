import Base
import ./HostWire.bend as W
import ./HostIdentity.bend as I
import ./Frontend.bend as F
import ./Transfer.bend as T

# Portable HOST PRIMITIVES (task 1.3 of the add-portable-host-contract change;
# PH-001, PH-006, PH-007, PH-014 here, PH-008 to PH-010 in HostPublication):
# the five primitive families every target binding (Genode, direct Linux,
# native Windows, a future kernel) implements, defined once in Bend:
#   1. session binding   (`family_session()`)      this module
#   2. worker domains    (`family_worker()`)       this module
#   3. artifacts         (`family_artifact()`)     HostPublication.bend
#   4. publication       (`family_publication()`)  HostPublication.bend
#   5. revocation        (`family_revocation()`)   HostPublication.bend
# All five share this module's types (`State`, `Step`, `Effect`, `Error`,
# `Phase`) and its `valid` gate; families 3 to 5 are in a separate module
# only because of this one's size.
#
# Binding contract (PH-001). A target binding supplies only `Fact` values (and
# its `TargetReport` and route inventory, which are facts too) and executes
# only the `Effect` values in an `Admitted` step that one of these
# transitions returned. It decides nothing. What the types exclude:
# - No transition takes a function, a template, a decision, a commit result,
#   a plan, rights, controls, families, a quota, or a profile from the
#   target. Every target-supplied input is an observation (`Fact`,
#   `TargetReport`, `RouteFact`) whose fields are identities, counts, bit
#   sets of native support, and Booleans.
# - Execution profiles are monitor state: `State.profiles`, the configured
#   (or negotiated) table, fixed by `empty` and never written by a
#   transition. The profile a worker runs under is fixed once, when the
#   monitor opens its session (`open_session` with `WorkerRole{profile}`, a
#   configured id, else UnknownProfile), and recorded in `State.bindings`.
#   `admit_worker` and every later transition read that stored binding; no
#   later request has a profile field, so no request can switch a session to
#   another configured profile. No request field carries controls,
#   families, a backend, or a quota limit, and `TargetReport` has no
#   profile field, so a target cannot introduce or lower one; its facts are
#   only compared against the bound profile.
# - Delegability is monitor state: `open_session` binds a worker session
#   non-delegable by construction, and admission reads the delegability the
#   identity table stored. A client session is delegable only when the
#   monitor's `ClientRole{delegable}` allows it and the evidence's flag
#   agrees (AND): the evidence can only narrow, never make a session
#   delegable that the monitor's role does not allow.
# - `Effect` is closed. It has no native write, publish, recall, or
#   diagnostic variant, and `native_write_offered` has no accepting branch,
#   so the fast publication route has no value to return. The publication
#   effect is `HostPublication.Publish`, a separate type that no `Step` can
#   carry; only `HostPublication.publish` returns it, after
#   `DataOS.commit_from_capability` (HostPublication header).
# - `Denied` has no effects field: a denial cannot carry work for the target
#   (law `primitive_denied_emits_nothing`).
# Host obligations (section 2, reviewed-only): (a) Bend datatypes are public,
# so a target could construct an `Effect` itself. A target-constructed
# `Effect` is not authorization; the binding must execute only effects taken
# from an `Admitted` step this monitor returned. (b) The `Role` passed to
# `open_session` is the monitor's own decision from its admitted request
# (which sessions are workers, and under which configured profile, and
# whether a client session may delegate), never a value the binding chose.
# (c) The monitor's clock is trusted and monotone: every `now` passed to
# `use`, `delegate`, `admit_worker`, `charge`, `diagnostic`, and
# HostPublication's `seal` and `complete` is monitor time, and nothing here
# checks that it never moves backwards (a clock that did would revive an
# expired entry for those checks; `publish` reads the DataOS context's
# clock). (d) `issue`'s `frontend` is the monitor's own Frontend state
# (see `issue`).
#
# Authority. `State` is monitor state: the HostIdentity table (sessions and
# entries, changed only through this layer's transitions: `open_session`,
# `issue`, `delegate`, and HostPublication's `revoke` and `restart`), the
# configured profile table, the admitted workers, the worker counter, the
# sealed artifacts, and the publication records. Worker ids are monitor-allocated.
# A worker's session is the one `HostIdentity.resolve` accepted for the
# presented reference, and its stored input reference is rebuilt from the
# resolved entry (this host, the current incarnation, the entry's slot and
# generation), not copied from the request. Its profile and quota limit come
# from the configured table. The only target value stored is the amount a
# successful `charge` adds, bounded by the configured limit.
# Worker sessions: a worker is admitted only on a session the identity table
# records non-delegable and `bindings` records as a worker session, so
# `HostIdentity.delegate` from a worker session is always denied
# NotDelegable and a worker cannot pass its inputs on, whatever the target
# reported.
# Each identity entry feeds at most one worker that is not `Reclaimed`
# (occupancy compares host, incarnation, and slot). This is one worker per
# entry, not per Frontend handle or root: two children delegated from one
# root are two entries and may feed two confined workers over the same
# handle and plan; publication still releases at most one of them for the
# plan's invocation (the second is denied Replay).
# Host obligations (section 2): the adapter identifies the worker a runtime
# fact came from (as it identifies the session a message arrived on); the
# inventory it reports is the worker's complete native route set; it removes
# or mediates every route before execution; it enforces the quota natively;
# and an accelerator profile's isolation is a real device boundary. The model
# decides on these facts; it cannot observe them.
#
# Edge direction: native harness -> `HostWire.decode` -> `use` (with the
# transport's session) -> `HostIdentity.resolve`; native facts -> the family
# transitions here -> `Step` -> the binding executes `Step.effects`. This
# module never imports `hosts/`, `contrib/`, or `examples/`.
#
# Invariants (`valid`): the identity table satisfies `HostIdentity.valid`;
# every configured profile id names one profile; every bound session is
# bound once, is one non-delegable session of the identity table, and names
# a configured profile; every worker id is nonzero,
# below `next_worker`, and names one worker; no two workers that are not
# `Reclaimed` share an input entry (host, incarnation, and slot); every sealed
# record names one worker and no worker is sealed twice; and every recorded
# invocation is recorded once. Every
# transition first requires the expected revision and a `valid` state (a
# state failing `valid` is not one this monitor committed, so it is denied
# StaleRevision, the HostIdentity pattern), and every admitted step
# preserves `valid`.
#
# Admission order (`admit_worker`), first failure reported:
#   1. gate          revision differs, or the state is not valid -> StaleRevision
#   2. identity      the input reference does not resolve on
#                    the presenting session                 -> Identity{reason}
#   3. session       the identity table records that session
#                    delegable                              -> DelegableSession
#   4. profile       no profile is bound to the session     -> UnknownProfile
#                    (its bound id is configured: `valid`)
#   5. protected     the profile does not list `family_worker()`,
#                    or requires no control                 -> MissingControl
#   6. slot          a worker that is not Reclaimed already
#                    holds the input entry                  -> SlotOccupied
#   7. inventory     the fact is not an `Inventory`         -> WrongPhase
#   8. families      a required family is not supported     -> UnsupportedFamily
#   9. controls      a required control is not established  -> MissingControl
#  10. accelerator   an `Accelerator` backend without
#                    `control_accelerator_isolation()`      -> UnisolatedAccelerator
#                    (checked whether or not the profile
#                    lists that control)
#  11. routes        any inventory route is not mediated    -> UnmediatedRoute
#   then commit: the worker is recorded `Running` and the only effect is
#   `DeliverInputs`, naming the input by its full reference (host,
#   incarnation, slot, generation), so plaintext delivery is the last step of
#   an accepted admission (PH-006) and a delayed effect cannot name a reused
#   slot. Admission is atomic: there is no window between recording the
#   worker and the delivery. Plan ruling: there is no downgrade. An
#   accelerator profile without isolation is denied; CPU work is a separate
#   worker session bound under a profile whose backend is `Cpu`, and the worker
#   records that profile (PH-014). Inputs are delivered to a confined worker
#   without a Transfer/Frontend plan recheck; the plan is rechecked at
#   publication (`HostPublication.publish`, through `DataOS.commit_from_capability`).
#
# Use order (`use`, read-only): gate -> the message is a wire `Use` (else
# WrongPhase) -> `HostIdentity.resolve` (Identity{reason}) -> the requested
# rights are within the entry's rights (RightsNotHeld) -> the operation's
# right (`operation_right`) is within the requested rights
# (OperationNotPermitted). The claimed subject is never read.
#
# Worker runtime rulings. `charge` and `diagnostic` check, in order: gate,
# fact variant (WrongPhase), exactly one worker with the id (UnknownWorker),
# phase `Running` (WrongPhase), then re-resolve the worker's input reference
# on its session at monitor time `now` (Identity{reason}), so a retired or
# expired input stops the worker's runtime facts. Then `charge` admits an
# amount only while the total stays within `quota_limit` and changes nothing
# but `quota_used`, so exhaustion cannot change rights or phase (PH-007).
# `diagnostic` accepts only a non-public emission, with no effect; a public
# emission from a protected worker is denied DiagnosticSink: the contract has
# no ungated diagnostic route, and public output can leave only through
# publication (plan ruling). A native write offer is always denied
# `FastPathUnavailable` (PH-001): it lacks the Bend authorization result bound
# to an artifact. A fact of the wrong variant for a transition is
# `WrongPhase` (it is not the observation that step of the protocol consumes).
#
# Failure behavior: on any denial a transition returns `Denied{state,
# reason}` with the supplied state itself and exactly one reason from the
# closed `Error` set, and no effects. A success returns `Admitted{state,
# effects}`, advancing `revision` exactly once. `use` is read-only and
# returns a `UseResult`.
#
# Law `primitive_denied_preserves_state` (LAWS.bend, proved in PROOF.bend):
# for every State and Error, `Step.state(Denied{state, reason}) == state`.
# Law `primitive_denied_emits_nothing`: for every State and Error,
# `Step.effects(Denied{state, reason}) == []`. Both hold by computation of the
# accessors. They fix the contract every denial path relies on: a denial
# hands back the caller's own state and yields no effect for a target to
# execute, so an effect exists only on an admitted transition. They do not
# assert which transitions deny, that a reason is the right one, or that an
# accepted step's effects are correct; HostPrimitivesTests covers those.
#
# Public entry points: `empty`, `valid`, `open_session_result`, `open_session`, `issue_result`,
# `SessionOpen.step`, `IssueResult.step`, `use`, `issue`,
# `delegate` (family 1); the types `Role`, `Binding`, `Bindings`;
# `admit_worker`, `charge`, `diagnostic`, `native_write_offered` (family 2);
# the types `Backend`, `Profile`, `Configured`, `Profiles`, `TargetReport`,
# `RouteFact`, `Fact`, `Effect`, `Step`, `IssueResult`, `UseResult`, `Error`, `Phase`,
# `Worker`, `Workers`, `State`, `Sealed`, `Seals`, `Publication`,
# `Publications`; the named family, control, and right bits
# (with `no_controls` and `no_right`),
# `operation_right`, `first_worker`, `no_usage`; and the accessors and
# equalities marked "Public". Every other def is an implementation helper;
# HostPublication reuses `current`, `reresolve`, `advanced`, `is_running`,
# `is_reclaimed`, `worker_at`, `count_worker`, `seal_at`, `publication_at`,
# `entry_ref`, and `same_entry`, and the lookup types.

# --- Interface types -------------------------------------------------------------

# The execution backend a profile permits.
type Backend is Data:
  Cpu{}
  Accelerator{}

# An execution profile: the families and controls (bit sets of the named bits
# below) the work requires, and its backend. Profiles exist only in the
# monitor's configured table (`Configured`); no request carries one.
type Profile is Data:
  Profile{id: Nat, required_families: U32, required_controls: U32, backend: Backend}

# One configured profile with the quota limit a worker admitted under it gets.
type Configured is Data:
  Configured{profile: Profile, quota_limit: Nat}

type Profiles is Data:
  NoProfiles{}
  Profiles{head: Configured, tail: Profiles}

# The target's native facts: the families its binding implements and the
# controls it has established for this worker. It names no profile.
type TargetReport is Data:
  TargetReport{supported_families: U32, established_controls: U32}

# One entry of a worker's complete native route inventory (a descriptor,
# handle, shared-memory route, or service), and whether the binding mediates
# it. `kind` is descriptive only; no decision reads it.
type RouteFact is Data:
  RouteFact{kind: U32, mediated: Bool}

# Observations a target binding reports. No variant carries a decision, a
# commit result, a plan, rights, or a profile. `SessionEvidence` is the
# authenticated native caller of a new session, how its endpoint arrived, and
# whether it may delegate (false for a worker session); `Inventory` the
# worker's complete route set; `ResourceRequest` a worker asking for `amount`
# more units; `Diagnostic` a worker's emission and whether it would be
# public; `NativeWriteOffered` a native fast write route offered for a
# worker's output. The artifact, quiescence, and completion facts are
# HostPublication's own types.
type Fact is Data:
  SessionEvidence{caller: F.Caller, origin: I.Origin, delegable: Bool}
  Inventory{routes: +List<RouteFact>}
  ResourceRequest{worker: Nat, amount: Nat}
  Diagnostic{worker: Nat, public: Bool}
  NativeWriteOffered{worker: Nat}

# The only work a target binding may perform from a `Step`, each returned by
# an admitted transition. `DeliverInputs` delivers the protected inputs of the
# identity entry `input` (its full reference, as the monitor rebuilt it) into
# `worker`'s confined domain. `Reconcile` tells the binding that the
# publication this monitor recorded for `invocation`, of artifact `digest`, to
# destination object version `destination`, is the outcome to finish or
# confirm after a crash. All three fields are copied from the monitor's
# record, and `HostPublication.reconcile` emits it only when the binding's
# logged digest and destination equal the recorded ones. The record does not
# hold the committed intent's output policy, label, or backend, so those are
# not checked at recovery (host obligation, section 2.3).
# `StopEffects` stops every future native effect of `worker` (it recalls and
# erases nothing). `Reclaim` releases `worker`'s quiesced native resources.
# There is deliberately no publish variant: a publication effect is
# `HostPublication.Publish`, which no `Step` can carry (HostPublication
# header), and there is no recall or erase variant.
type Effect is Data:
  DeliverInputs{worker: Nat, input: W.Ref}
  Reconcile{invocation: Nat, digest: T.CodeId, destination: T.ObjectVersion}
  StopEffects{worker: Nat}
  Reclaim{worker: Nat}

# A worker domain's lifecycle phase. Admission records workers directly in
# `Running`, so no transition produces `Prepared`; the runtime checks deny it
# like every phase other than `Running`. Revocation moves `Running` to
# `Revoked`, quiescence `Revoked` to `Quiesced`, and reclamation `Quiesced`
# to `Reclaimed` (HostPublication).
type Phase is Data:
  Prepared{}
  Running{}
  Revoked{}
  Quiesced{}
  Reclaimed{}

# An admitted worker domain: its monitor-allocated id, the session
# `HostIdentity.resolve` accepted, its input entry's reference rebuilt from
# the table, the configured profile, its phase, and its quota (the configured
# limit, and the use from accepted charges).
type Worker is Data:
  Worker{id: Nat, session: Nat, input: W.Ref, profile: Profile, phase: Phase,
    quota_limit: Nat, quota_used: Nat}

type Workers is Data:
  NoWorkers{}
  Workers{head: Worker, tail: Workers}

# The monitor's decision, at bind time, of what a new session is for: a
# client session (`delegable` False makes it non-delegable whatever the
# evidence reports), or a worker session bound under configured profile
# `profile`. The monitor takes it from its own admitted request; it is never
# target evidence.
type Role is Data:
  ClientRole{delegable: Bool}
  WorkerRole{profile: Nat}

# The configured profile a worker session was bound under.
type Binding is Data:
  Binding{session: Nat, profile: Nat}

type Bindings is Data:
  NoBindings{}
  Bindings{head: Binding, tail: Bindings}

# The artifact a worker sealed (family 3, `HostPublication.seal`): the exact
# object, version, and content digest the binding reported with no writer of
# any kind. Monitor state; only `seal` writes it.
type Sealed is Data:
  Sealed{worker: Nat, object: Nat, version: Nat, digest: T.CodeId}

type Seals is Data:
  NoSeals{}
  Seals{head: Sealed, tail: Seals}

# One recorded publication (family 4): the negotiated plan's invocation, the
# sealed digest that `HostPublication.publish` released for it, and the
# committed intent's destination object version. Monitor state; only
# `publish` writes it, and no transition removes it.
type Publication is Data:
  Publication{invocation: Nat, digest: T.CodeId, destination: T.ObjectVersion}

type Publications is Data:
  NoPublications{}
  Publications{head: Publication, tail: Publications}

# The primitive layer's whole state. `profiles` is fixed by `empty`;
# `bindings` records, for each session `open_session` bound as a worker
# session, the configured profile it was bound under; `next_worker` exceeds
# every worker id; `seals` holds each worker's sealed artifact and
# `publications` each released invocation (families 3 and 4, written only by
# HostPublication's `seal` and `publish`).
type State is Data:
  State{revision: Nat, identity: I.State, profiles: Profiles, bindings: Bindings, workers: Workers,
    next_worker: Nat, seals: Seals, publications: Publications}

# Closed set of denial reasons. Every denied transition names exactly one.
type Error is Data:
  Identity{error: I.Error}
  UnsupportedFamily{}
  MissingControl{}
  UnmediatedRoute{}
  UnisolatedAccelerator{}
  QuotaExhausted{}
  DiagnosticSink{}
  FastPathUnavailable{}
  UnknownWorker{}
  WrongPhase{}
  StaleRevision{}
  UnknownProfile{}
  DelegableSession{}
  SlotOccupied{}
  RightsNotHeld{}
  OperationNotPermitted{}
  LiveWriter{}
  NotSealed{}
  Retargeted{}
  ArtifactMismatch{}
  CommitRejected{}
  Replay{}
  Substitution{}
  Unrecorded{}
  NotQuiesced{}
  PlanMismatch{}
  OwnerMismatch{}
  LeaseExceeded{}
  AuthorityUnavailable{}

# The output of every mutating transition. Only `Admitted` carries effects.
type Step is Data:
  Admitted{state: State, effects: +List<Effect>}
  Denied{state: State, reason: Error}

# The ID is the exact value returned by the same HostIdentity transition that
# installs the session. This in-memory value is descriptive, not an
# authenticated receipt or a replacement for serialization and native identity.
type SessionOpen is Data:
  SessionOpened{state: State, session: Nat}
  SessionOpenDenied{state: State, reason: Error}

# Compatibility projection: session opening has no native effects. Existing
# callers of open_session receive exactly the original Step representation.
def SessionOpen.step(result: SessionOpen) -> Step:
  match result:
    case SessionOpened{state, _}:
      Admitted{state, []}
    case SessionOpenDenied{state, reason}:
      Denied{state, reason}

# The exact identity slot from the same successful mint. It is an in-memory
# model value, not a native receipt or proof of wire representability.
type IssueResult is Data:
  Issued{state: State, slot: Nat}
  IssueDenied{state: State, reason: Error}

# Compatibility projection: root issuance never emits native effects.
def IssueResult.step(result: IssueResult) -> Step:
  match result:
    case Issued{state, _}: Admitted{state, []}
    case IssueDenied{state, reason}: Denied{state, reason}

# The read-only result of `use`: the entry and its effective caller (the
# entry's owner), or one reason.
type UseResult is Data:
  Granted{entry: I.Entry, caller: F.Caller}
  Refused{reason: Error}

# Implementation helper: a counted lookup of workers with one id.
type WorkerLookup is Data:
  NoWorker{}
  OneWorker{worker: Worker}
  ManyWorkers{}

# Implementation helper: a counted lookup of the profile bound to a session.
type BindingLookup is Data:
  NoBinding{}
  OneBinding{profile: Nat}
  ManyBindings{}

# Implementation helper: a counted lookup of configured profiles with one id.
type ProfileLookup is Data:
  NoProfile{}
  OneProfile{configured: Configured}
  ManyProfiles{}

# Implementation helper: a counted lookup of a worker's sealed record.
type SealLookup is Data:
  NoSeal{}
  OneSeal{sealed: Sealed}
  ManySeals{}

# Implementation helper: a counted lookup of an invocation's publication.
type PublicationLookup is Data:
  NoPublication{}
  OnePublication{publication: Publication}
  ManyPublications{}

# --- Named constants (public) -----------------------------------------------------

def family_session() -> U32:
  1

def family_worker() -> U32:
  2

def family_artifact() -> U32:
  4

def family_publication() -> U32:
  8

def family_revocation() -> U32:
  16

# Every family; a portable binding implements all five.
def all_families() -> U32:
  31

def control_address_isolation() -> U32:
  1

def control_no_ambient_network() -> U32:
  2

def control_output_mediation() -> U32:
  4

def control_quota() -> U32:
  8

def control_no_inherited_routes() -> U32:
  16

def control_accelerator_isolation() -> U32:
  32

# The empty control set; a profile requiring it protects nothing.
def no_controls() -> U32:
  0

# The empty right set: what `operation_right` gives an operation outside the
# wire's set, which `operation_permitted` refuses.
def no_right() -> U32:
  0

# Protocol right bits, as an identity entry's `rights` holds them.
def right_read() -> U32:
  1

def right_write() -> U32:
  2

def right_execute() -> U32:
  4

# The first worker id; 0 is never a worker.
def first_worker() -> Nat:
  1n

# The quota a newly admitted worker has used.
def no_usage() -> Nat:
  0n

# Public entry point: a primitive layer over the monitor's identity table and
# its configured profile table, with no workers.
def empty(identity: I.State, profiles: Profiles) -> State:
  State{0n, identity, profiles, NoBindings{}, NoWorkers{}, first_worker(), NoSeals{}, NoPublications{}}

# --- Accessors and equality (public) ----------------------------------------------

def Error.equal(a: Error, b: Error) -> Bool:
  match a b:
    case Identity{x} Identity{y}: I.Error.equal(x, y)
    case UnsupportedFamily{} UnsupportedFamily{}: True{}
    case MissingControl{} MissingControl{}: True{}
    case UnmediatedRoute{} UnmediatedRoute{}: True{}
    case UnisolatedAccelerator{} UnisolatedAccelerator{}: True{}
    case QuotaExhausted{} QuotaExhausted{}: True{}
    case DiagnosticSink{} DiagnosticSink{}: True{}
    case FastPathUnavailable{} FastPathUnavailable{}: True{}
    case UnknownWorker{} UnknownWorker{}: True{}
    case WrongPhase{} WrongPhase{}: True{}
    case StaleRevision{} StaleRevision{}: True{}
    case UnknownProfile{} UnknownProfile{}: True{}
    case DelegableSession{} DelegableSession{}: True{}
    case SlotOccupied{} SlotOccupied{}: True{}
    case RightsNotHeld{} RightsNotHeld{}: True{}
    case OperationNotPermitted{} OperationNotPermitted{}: True{}
    case LiveWriter{} LiveWriter{}: True{}
    case NotSealed{} NotSealed{}: True{}
    case Retargeted{} Retargeted{}: True{}
    case ArtifactMismatch{} ArtifactMismatch{}: True{}
    case CommitRejected{} CommitRejected{}: True{}
    case Replay{} Replay{}: True{}
    case Substitution{} Substitution{}: True{}
    case Unrecorded{} Unrecorded{}: True{}
    case NotQuiesced{} NotQuiesced{}: True{}
    case PlanMismatch{} PlanMismatch{}: True{}
    case OwnerMismatch{} OwnerMismatch{}: True{}
    case LeaseExceeded{} LeaseExceeded{}: True{}
    case AuthorityUnavailable{} AuthorityUnavailable{}: True{}
    case _ _: False{}

# Public accessor: the resulting state; on denial, the supplied state.
def Step.state(step: Step) -> State:
  match step:
    case Admitted{state, _}:
      state
    case Denied{state, _}:
      state

# Public accessor: the effects to execute; empty on denial.
def Step.effects(step: Step) -> +List<Effect>:
  match step:
    case Admitted{_, effects}:
      effects
    case Denied{_, _}:
      []

# Public accessor: the denial reason; None for an admitted step.
def Step.reason(step: Step) -> Maybe<&2, Error>:
  match step:
    case Admitted{_, _}:
      None{}
    case Denied{_, reason}:
      Some{reason}

def revision(state: State) -> Nat:
  match state:
    case State{revision, _, _, _, _, _, _, _}:
      revision

def identity(state: State) -> I.State:
  match state:
    case State{_, identity, _, _, _, _, _, _}:
      identity

def profiles(state: State) -> Profiles:
  match state:
    case State{_, _, profiles, _, _, _, _, _}:
      profiles

def bindings(state: State) -> Bindings:
  match state:
    case State{_, _, _, bindings, _, _, _, _}:
      bindings

def workers(state: State) -> Workers:
  match state:
    case State{_, _, _, _, workers, _, _, _}:
      workers

def next_worker(state: State) -> Nat:
  match state:
    case State{_, _, _, _, _, next_worker, _, _}:
      next_worker

def seals(state: State) -> Seals:
  match state:
    case State{_, _, _, _, _, _, seals, _}:
      seals

def publications(state: State) -> Publications:
  match state:
    case State{_, _, _, _, _, _, _, publications}:
      publications

def worker_id(worker: Worker) -> Nat:
  match worker:
    case Worker{id, _, _, _, _, _, _}:
      id

def worker_session(worker: Worker) -> Nat:
  match worker:
    case Worker{_, session, _, _, _, _, _}:
      session

def worker_input(worker: Worker) -> W.Ref:
  match worker:
    case Worker{_, _, input, _, _, _, _}:
      input

def worker_phase(worker: Worker) -> Phase:
  match worker:
    case Worker{_, _, _, _, phase, _, _}:
      phase

def worker_quota_limit(worker: Worker) -> Nat:
  match worker:
    case Worker{_, _, _, _, _, quota_limit, _}:
      quota_limit

def worker_quota_used(worker: Worker) -> Nat:
  match worker:
    case Worker{_, _, _, _, _, _, quota_used}:
      quota_used

def profile_id(profile: Profile) -> Nat:
  match profile:
    case Profile{id, _, _, _}:
      id

def profile_families(profile: Profile) -> U32:
  match profile:
    case Profile{_, families, _, _}:
      families

def profile_controls(profile: Profile) -> U32:
  match profile:
    case Profile{_, _, controls, _}:
      controls

def profile_backend(profile: Profile) -> Backend:
  match profile:
    case Profile{_, _, _, backend}:
      backend

def configured_profile(configured: Configured) -> Profile:
  match configured:
    case Configured{profile, _}:
      profile

def configured_quota(configured: Configured) -> Nat:
  match configured:
    case Configured{_, quota_limit}:
      quota_limit

def sealed_worker(sealed: Sealed) -> Nat:
  match sealed:
    case Sealed{worker, _, _, _}:
      worker

def sealed_object(sealed: Sealed) -> Nat:
  match sealed:
    case Sealed{_, object, _, _}:
      object

def sealed_version(sealed: Sealed) -> Nat:
  match sealed:
    case Sealed{_, _, version, _}:
      version

def sealed_digest(sealed: Sealed) -> T.CodeId:
  match sealed:
    case Sealed{_, _, _, digest}:
      digest

def publication_invocation(publication: Publication) -> Nat:
  match publication:
    case Publication{invocation, _, _}:
      invocation

def publication_digest(publication: Publication) -> T.CodeId:
  match publication:
    case Publication{_, digest, _}:
      digest

def publication_destination(publication: Publication) -> T.ObjectVersion:
  match publication:
    case Publication{_, _, destination}:
      destination

def report_families(report: TargetReport) -> U32:
  match report:
    case TargetReport{families, _}:
      families

def report_controls(report: TargetReport) -> U32:
  match report:
    case TargetReport{_, controls}:
      controls

# --- Shared helpers (implementation helpers) --------------------------------------

# Implementation helper: whether every bit of `required` is in `have`.
def within(+required: U32, have: U32) -> Bool:
  T.word_subset(required, have)

# Implementation helper: whether `phase` is `Running`.
def is_running(phase: Phase) -> Bool:
  match phase:
    case Running{}:
      True{}
    case _:
      False{}

# Implementation helper: whether `phase` is `Reclaimed`.
def is_reclaimed(phase: Phase) -> Bool:
  match phase:
    case Reclaimed{}:
      True{}
    case _:
      False{}

# Implementation helper: whether two references name one entry slot of one
# host incarnation (generation aside: a slot is never reused within an
# incarnation).
def same_entry(a: W.Ref, b: W.Ref) -> Bool:
  match a b:
    case W.Ref{ah, ai, as, _} W.Ref{bh, bi, bs, _}:
      U32.is_eq(ah, bh) && U32.is_eq(ai, bi) && U32.is_eq(as, bs)

# Implementation helper: add one candidate to a counted worker lookup.
def count_worker(ok: Bool, worker: Worker, rest: WorkerLookup) -> WorkerLookup:
  match ok rest:
    case False{} rest:
      rest
    case True{} NoWorker{}:
      OneWorker{worker}
    case True{} OneWorker{_}:
      ManyWorkers{}
    case True{} ManyWorkers{}:
      ManyWorkers{}

# Implementation helper: every worker with id `id`, counted, so a duplicated
# id is reported instead of resolved by list order.
def worker_at(workers: Workers, +id: Nat) -> WorkerLookup:
  match workers:
    case NoWorkers{}:
      NoWorker{}
    case Workers{+worker, rest}:
      count_worker(Nat.is_eq(worker_id(worker), id), worker, worker_at(rest, id))

# Implementation helper: add one candidate to a counted profile lookup.
def count_profile(ok: Bool, configured: Configured, rest: ProfileLookup) -> ProfileLookup:
  match ok rest:
    case False{} rest:
      rest
    case True{} NoProfile{}:
      OneProfile{configured}
    case True{} OneProfile{_}:
      ManyProfiles{}
    case True{} ManyProfiles{}:
      ManyProfiles{}

# Implementation helper: every configured profile with id `id`, counted.
def profile_at(profiles: Profiles, +id: Nat) -> ProfileLookup:
  match profiles:
    case NoProfiles{}:
      NoProfile{}
    case Profiles{+configured, rest}:
      count_profile(Nat.is_eq(profile_id(configured_profile(configured)), id), configured,
        profile_at(rest, id))

# Implementation helper: count one more when `ok`.
def tally(ok: Bool, n: Nat) -> Nat:
  match ok:
    case True{}:
      1n+n
    case False{}:
      n

# Implementation helper: how many workers carry id `id`.
def id_count(workers: Workers, +id: Nat) -> Nat:
  match workers:
    case NoWorkers{}:
      0n
    case Workers{worker, rest}:
      tally(Nat.is_eq(worker_id(worker), id), id_count(rest, id))

# Implementation helper: whether a worker that is not Reclaimed holds the
# entry `input` names.
def occupied(workers: Workers, +input: W.Ref) -> Bool:
  match workers:
    case NoWorkers{}:
      False{}
    case Workers{+worker, rest}:
      (Bool.not(is_reclaimed(worker_phase(worker))) && same_entry(worker_input(worker), input))
        || occupied(rest, input)

# Implementation helper: how many workers that are not Reclaimed hold the
# entry `input` names.
def occupants(workers: Workers, +input: W.Ref) -> Nat:
  match workers:
    case NoWorkers{}:
      0n
    case Workers{+worker, rest}:
      tally(Bool.not(is_reclaimed(worker_phase(worker))) && same_entry(worker_input(worker), input),
        occupants(rest, input))

# Implementation helper: `valid`'s worker clauses.
def workers_valid(workers: Workers, +all: Workers, +next: Nat) -> Bool:
  match workers:
    case NoWorkers{}:
      True{}
    case Workers{+worker, rest}:
      Nat.is_gt(worker_id(worker), 0n) && Nat.is_lt(worker_id(worker), next)
        && Nat.is_eq(id_count(all, worker_id(worker)), 1n)
        && (is_reclaimed(worker_phase(worker)) || Nat.is_eq(occupants(all, worker_input(worker)), 1n))
        && workers_valid(rest, all, next)

# Implementation helper: how many configured profiles carry id `id`.
def profile_count(profiles: Profiles, +id: Nat) -> Nat:
  match profiles:
    case NoProfiles{}:
      0n
    case Profiles{configured, rest}:
      tally(Nat.is_eq(profile_id(configured_profile(configured)), id), profile_count(rest, id))

# Implementation helper: `valid`'s profile clause.
def profiles_valid(profiles: Profiles, +all: Profiles) -> Bool:
  match profiles:
    case NoProfiles{}:
      True{}
    case Profiles{configured, rest}:
      Nat.is_eq(profile_count(all, profile_id(configured_profile(configured))), 1n)
        && profiles_valid(rest, all)

# Implementation helper: add one candidate to a counted binding lookup.
def count_binding(ok: Bool, profile: Nat, rest: BindingLookup) -> BindingLookup:
  match ok rest:
    case False{} rest:
      rest
    case True{} NoBinding{}:
      OneBinding{profile}
    case True{} OneBinding{_}:
      ManyBindings{}
    case True{} ManyBindings{}:
      ManyBindings{}

def binding_session(binding: Binding) -> Nat:
  match binding:
    case Binding{session, _}:
      session

def binding_profile(binding: Binding) -> Nat:
  match binding:
    case Binding{_, profile}:
      profile

# Implementation helper: the profile bound to session `session`, counted.
def binding_at(bindings: Bindings, +session: Nat) -> BindingLookup:
  match bindings:
    case NoBindings{}:
      NoBinding{}
    case Bindings{+binding, rest}:
      count_binding(Nat.is_eq(binding_session(binding), session), binding_profile(binding),
        binding_at(rest, session))

# Implementation helper: whether a session lookup found exactly one session,
# bound non-delegable.
def non_delegable_session(found: I.SessionLookup) -> Bool:
  match found:
    case I.OneSession{session}:
      Bool.not(I.session_delegable(session))
    case _:
      False{}

# Implementation helper: whether a binding lookup found exactly one binding.
def one_binding(found: BindingLookup) -> Bool:
  match found:
    case OneBinding{_}:
      True{}
    case _:
      False{}

# Implementation helper: `valid`'s binding clauses: each bound session is
# bound once, is one non-delegable session of the identity table, and names
# a configured profile.
def bindings_valid(bindings: Bindings, +all: Bindings, +sessions: I.Sessions, +profiles: Profiles) -> Bool:
  match bindings:
    case NoBindings{}:
      True{}
    case Bindings{+binding, rest}:
      one_binding(binding_at(all, binding_session(binding)))
        && non_delegable_session(I.session_at(sessions, binding_session(binding)))
        && Nat.is_eq(profile_count(profiles, binding_profile(binding)), 1n)
        && bindings_valid(rest, all, sessions, profiles)

# Implementation helper: add one candidate to a counted seal lookup.
def count_seal(ok: Bool, sealed: Sealed, rest: SealLookup) -> SealLookup:
  match ok rest:
    case False{} rest:
      rest
    case True{} NoSeal{}:
      OneSeal{sealed}
    case True{} OneSeal{_}:
      ManySeals{}
    case True{} ManySeals{}:
      ManySeals{}

# Implementation helper: every sealed record of worker `worker`, counted.
def seal_at(seals: Seals, +worker: Nat) -> SealLookup:
  match seals:
    case NoSeals{}:
      NoSeal{}
    case Seals{+sealed, rest}:
      count_seal(Nat.is_eq(sealed_worker(sealed), worker), sealed, seal_at(rest, worker))

# Implementation helper: whether a seal lookup found exactly one record.
def one_seal(found: SealLookup) -> Bool:
  match found:
    case OneSeal{_}:
      True{}
    case _:
      False{}

# Implementation helper: `valid`'s seal clauses: each sealed record names one
# worker, and no worker has two sealed records.
def seals_valid(seals: Seals, +all: Seals, +workers: Workers) -> Bool:
  match seals:
    case NoSeals{}:
      True{}
    case Seals{+sealed, rest}:
      Nat.is_eq(id_count(workers, sealed_worker(sealed)), 1n) && one_seal(seal_at(all, sealed_worker(sealed)))
        && seals_valid(rest, all, workers)

# Implementation helper: add one candidate to a counted publication lookup.
def count_publication(ok: Bool, publication: Publication, rest: PublicationLookup) -> PublicationLookup:
  match ok rest:
    case False{} rest:
      rest
    case True{} NoPublication{}:
      OnePublication{publication}
    case True{} OnePublication{_}:
      ManyPublications{}
    case True{} ManyPublications{}:
      ManyPublications{}

# Implementation helper: every recorded publication of `invocation`, counted.
def publication_at(publications: Publications, +invocation: Nat) -> PublicationLookup:
  match publications:
    case NoPublications{}:
      NoPublication{}
    case Publications{+publication, rest}:
      count_publication(Nat.is_eq(publication_invocation(publication), invocation), publication,
        publication_at(rest, invocation))

# Implementation helper: whether a publication lookup found exactly one record.
def one_publication(found: PublicationLookup) -> Bool:
  match found:
    case OnePublication{_}:
      True{}
    case _:
      False{}

# Implementation helper: `valid`'s publication clause: each invocation is
# recorded once.
def publications_valid(publications: Publications, +all: Publications) -> Bool:
  match publications:
    case NoPublications{}:
      True{}
    case Publications{+publication, rest}:
      one_publication(publication_at(all, publication_invocation(publication)))
        && publications_valid(rest, all)

# Public: the structural invariants (module header). It checks structure only
# and does not authenticate the supplied state.
def valid(state: State) -> Bool:
  match state:
    case State{_, +identity, +profiles, +bindings, +workers, +next_worker, +seals, +publications}:
      I.valid(identity) && profiles_valid(profiles, profiles)
        && bindings_valid(bindings, bindings, I.sessions(identity), profiles)
        && workers_valid(workers, workers, next_worker)
        && seals_valid(seals, seals, workers)
        && publications_valid(publications, publications)

# Implementation helper: every transition's first gate.
def current(+state: State, expected_revision: Nat) -> Bool:
  Nat.is_eq(revision(state), expected_revision) && valid(state)

# Implementation helper: re-resolve a worker's input on its own session.
def reresolve(+state: State, +worker: Worker, +now: Nat) -> I.Resolution:
  I.resolve(identity(state), I.revision(identity(state)), worker_session(worker), worker_input(worker), now)

# Implementation helper: advance the revision once, keeping everything else.
def advanced(state: State) -> State:
  match state:
    case State{revision, identity, profiles, bindings, workers, next_worker, seals, publications}:
      State{1n+revision, identity, profiles, bindings, workers, next_worker, seals, publications}

# --- Family 1: session binding (public: open_session, use, issue, delegate) ------

# Implementation helper: commit a bound identity table.
def with_identity(state: State, identity: I.State) -> State:
  match state:
    case State{revision, _, profiles, bindings, workers, next_worker, seals, publications}:
      State{1n+revision, identity, profiles, bindings, workers, next_worker, seals, publications}

# Implementation helper: commit a bound identity table and record that the
# issued session is a worker session bound under `profile`.
def with_worker_session(state: State, identity: I.State, +session: Nat, +profile: Nat) -> State:
  match state:
    case State{revision, _, profiles, bindings, workers, next_worker, seals, publications}:
      State{1n+revision, identity, profiles, Bindings{Binding{session, profile}, bindings}, workers, next_worker,
        seals, publications}

# Implementation helper: a client session's identity step; a HostIdentity
# denial is reported as `Identity{reason}`.
def o_bound(change: I.Change, +state: State) -> SessionOpen:
  match change:
    case I.Rejected{_, reason}:
      SessionOpenDenied{state, Identity{reason}}
    case I.Accepted{identity, issued}:
      SessionOpened{with_identity(state, identity), issued}

# Implementation helper: a worker session's identity step.
def o_worker_bound(change: I.Change, +state: State, +profile: Nat) -> SessionOpen:
  match change:
    case I.Rejected{_, reason}:
      SessionOpenDenied{state, Identity{reason}}
    case I.Accepted{identity, +issued}:
      SessionOpened{with_worker_session(state, identity, issued, profile), issued}

# Implementation helper: a worker session's profile step. The session is
# bound non-delegable whatever the evidence reports.
def o_worker(found: ProfileLookup, +state: State, +profile: Nat, caller: F.Caller, +origin: I.Origin) -> SessionOpen:
  match found:
    case OneProfile{_}:
      o_worker_bound(I.bind_session(identity(state), I.revision(identity(state)), caller, origin, False{}),
        state, profile)
    case _:
      SessionOpenDenied{state, UnknownProfile{}}

# Implementation helper: open_session's role step. A client session is
# delegable only if the monitor's role allows it and the evidence does not
# deny it: the evidence's flag can only narrow, never grant.
def o_role(role: Role, +state: State, caller: F.Caller, +origin: I.Origin, delegable: Bool) -> SessionOpen:
  match role:
    case ClientRole{allowed}:
      o_bound(I.bind_session(identity(state), I.revision(identity(state)), caller, origin, allowed && delegable),
        state)
    case WorkerRole{+profile}:
      o_worker(profile_at(profiles(state), profile), state, profile, caller, origin)

# Implementation helper: open_session's fact step.
def o_fact(fact: Fact, +state: State, role: Role) -> SessionOpen:
  match fact:
    case SessionEvidence{caller, +origin, delegable}:
      o_role(role, state, caller, origin, delegable)
    case _:
      SessionOpenDenied{state, WrongPhase{}}

# Implementation helper: open_session's family step.
def o_family(ok: Bool, +state: State, fact: Fact, role: Role) -> SessionOpen:
  match ok:
    case True{}:
      o_fact(fact, state, role)
    case False{}:
      SessionOpenDenied{state, UnsupportedFamily{}}

# Implementation helper: open_session's gate.
def o_gate(ok: Bool, +state: State, report: TargetReport, fact: Fact, role: Role) -> SessionOpen:
  match ok:
    case True{}:
      o_family(within(family_session(), report_families(report)), state, fact, role)
    case False{}:
      SessionOpenDenied{state, StaleRevision{}}

# Public entry points, family 1: bind a native session from the target's
# `SessionEvidence` through `HostIdentity.bind_session`, which allocates the
# session id, in the role the monitor decided (`role`, from its admitted
# request, never from the target). Requires the target to support
# `family_session()`. Order: gate, family, fact variant, role, then
# HostIdentity's own checks. A `ClientRole` session is delegable only when
# the evidence also says so; a `WorkerRole{profile}` session needs a
# configured `profile` (else UnknownProfile), is always bound non-delegable,
# and is recorded in `bindings` under that profile. No effect. The typed
# result carries the ID from this transition; it is not a wire receipt or
# authentication. `open_session` projects the same result to the legacy Step.
def open_session_result(+state: State, expected_revision: Nat, report: TargetReport, fact: Fact, role: Role) -> SessionOpen:
  o_gate(current(state, expected_revision), state, report, fact, role)

def open_session(+state: State, expected_revision: Nat, report: TargetReport, fact: Fact, role: Role) -> Step:
  SessionOpen.step(open_session_result(state, expected_revision, report, fact, role))

# Implementation helper: choose a right.
def pick_right(ok: Bool, chosen: U32, otherwise: U32) -> U32:
  match ok:
    case True{}:
      chosen
    case False{}:
      otherwise

# Public: the right a wire operation needs, or `no_right()` for an operation
# outside the wire's set.
def operation_right(+operation: U32) -> U32:
  pick_right(U32.is_eq(operation, W.operation_read()), right_read(),
    pick_right(U32.is_eq(operation, W.operation_write()), right_write(),
      pick_right(U32.is_eq(operation, W.operation_execute()), right_execute(), no_right())))

# Implementation helper: whether `operation` is a wire operation whose right
# is within the requested `rights`.
def operation_permitted(+operation: U32, +rights: U32) -> Bool:
  Bool.not(U32.is_eq(operation_right(operation), no_right())) && within(operation_right(operation), rights)

# Implementation helper: use's operation step.
def u_operation(ok: Bool, entry: I.Entry, caller: F.Caller) -> UseResult:
  match ok:
    case True{}:
      Granted{entry, caller}
    case False{}:
      Refused{OperationNotPermitted{}}

# Implementation helper: use's rights step: the requested rights must be held.
def u_rights(ok: Bool, entry: I.Entry, caller: F.Caller, +operation: U32, +rights: U32) -> UseResult:
  match ok:
    case True{}:
      u_operation(operation_permitted(operation, rights), entry, caller)
    case False{}:
      Refused{RightsNotHeld{}}

# Implementation helper: use's identity step.
def u_resolved(resolution: I.Resolution, +operation: U32, +rights: U32) -> UseResult:
  match resolution:
    case I.Unresolved{reason}:
      Refused{Identity{reason}}
    case I.Resolved{+entry, caller}:
      u_rights(within(rights, I.entry_rights(entry)), entry, caller, operation, rights)

# Implementation helper: use's message step; only a wire `Use` is a use.
def u_message(message: W.Message, +state: State, +session: Nat, +now: Nat) -> UseResult:
  match message:
    case W.Use{ref, operation, rights, _}:
      u_resolved(I.resolve(identity(state), I.revision(identity(state)), session, ref, now), operation, rights)
    case _:
      Refused{WrongPhase{}}

# Implementation helper: use's gate.
def u_gate(ok: Bool, +state: State, +session: Nat, message: W.Message, +now: Nat) -> UseResult:
  match ok:
    case True{}:
      u_message(message, state, session, now)
    case False{}:
      Refused{StaleRevision{}}

# Public entry point, family 1, read-only: a decoded wire `message` presented
# on the native session the transport identified as `session`, at monitor
# time `now`, in the documented use order. The reference resolves through
# `HostIdentity.resolve` only; the claimed subject is never read, so the
# effective caller is the resolved entry's owner.
def use(+state: State, expected_revision: Nat, +session: Nat, message: W.Message, +now: Nat) -> UseResult:
  u_gate(current(state, expected_revision), state, session, message, now)

# Implementation helper: an identity-table change that issues no session
# (`delegate`): a HostIdentity denial is `Identity{reason}`; an
# accepted change commits the table, advances the revision once, and emits
# nothing.
def changed(change: I.Change, +state: State) -> Step:
  match change:
    case I.Rejected{_, reason}:
      Denied{state, Identity{reason}}
    case I.Accepted{identity, _}:
      Admitted{with_identity(state, identity), []}

# Implementation helper: whether Frontend handle `handle` is owned by
# `caller` (the same subject and the same token).
def owned_by(handle: F.Handle, +caller: F.Caller) -> Bool:
  match handle:
    case F.Handle{_, _, subject, token, _, _, _, _, _}:
      Nat.is_eq(subject, I.caller_subject(caller)) && T.CodeId.equal(token, F.caller_token(caller))

# Implementation helper: issue's owner comparison. The session lookup must
# name one session whose bound caller owns the handle. An unbound or
# ambiguous session passes this step only to be denied by `HostIdentity.mint`
# (UnknownSession, Ambiguous), which needs the same lookup.
def owner_matches(found: I.SessionLookup, handle: F.Handle) -> Bool:
  match found:
    case I.OneSession{session}:
      owned_by(handle, I.session_caller(session))
    case I.NoSession{}:
      True{}
    case I.ManySessions{}:
      True{}

def handle_expires(handle: F.Handle) -> Nat:
  match handle:
    case F.Handle{_, _, _, _, _, _, _, expires, _}:
      expires

# Implementation helper: the first failing binding field, in order plan,
# owner, rights, lease; None when all four hold.
def first_unbound(plan_ok: Bool, owner_ok: Bool, rights_ok: Bool, lease_ok: Bool) -> Maybe<&2, Error>:
  match plan_ok owner_ok rights_ok lease_ok:
    case False{} _ _ _:
      Some{PlanMismatch{}}
    case True{} False{} _ _:
      Some{OwnerMismatch{}}
    case True{} True{} False{} _:
      Some{RightsNotHeld{}}
    case True{} True{} True{} False{}:
      Some{LeaseExceeded{}}
    case True{} True{} True{} True{}:
      None{}

# Implementation helper: issue's binding of the new entry to Frontend handle
# `found`: a handle the monitor's Frontend state does not hold is
# PlanMismatch; otherwise the handle must carry exactly `plan`
# (PlanMismatch), be owned by the session's caller (OwnerMismatch), hold
# every right in `rights` (RightsNotHeld), and expire no earlier than
# `expires` (LeaseExceeded; both clocks are exclusive, `now < expires`).
def unbound(found: Maybe<&2, F.Handle>, owner: I.SessionLookup, +plan: T.Plan, +rights: U32, +expires: Nat)
    -> Maybe<&2, Error>:
  match found:
    case Some{+handle}:
      first_unbound(T.Plan.equal(F.handle_plan(handle), plan), owner_matches(owner, handle),
        T.word_subset(rights, F.handle_rights(handle)), Nat.is_le(expires, handle_expires(handle)))
    case None{}:
      Some{PlanMismatch{}}

# Read-only check of the bound caller's whole current Frontend scope and
# paired transfer plan. It does not authenticate or refresh the supplied
# monitor-owned registry, context or Frontend state.
def issue_live_handle(found: Maybe<&2, F.Handle>, context: T.Context) -> Bool:
  match found:
    case None{}: False{}
    case Some{handle}: T.accepted(T.admit(F.handle_plan(handle), context))

def issue_live_session(found: I.SessionLookup, frontend: F.State, frontend_revision: Nat,
    registry: F.Registry, +context: T.Context, handle: Nat) -> Bool:
  match found:
    case I.OneSession{session}:
      issue_live_handle(F.authorized(frontend, registry, frontend_revision,
        F.Ref{I.session_caller(session), handle}, F.live(context)), context)
    case _: False{}

# Read-only extraction used only after a failed binding was observed.
def issue_binding_reason(failed: Maybe<&2, Error>) -> Error:
  match failed:
    case Some{reason}: reason
    case None{}: PlanMismatch{}

# Read-only projection used only after the same change reports an issued slot.
# The None fallback is never returned in Issued: that branch requires Some.
def issue_slot(found: Maybe<&2, Nat>) -> Nat:
  match found:
    case Some{slot}: slot
    case None{}: 0n

# Public entry points, family 1: issue one root through HostIdentity.mint.
# issue_result exposes its exact same-transition model slot; issue projects it.
# The model Nat is not a wire receipt and may not fit HostWire's U32 field.
# The trusted monitor supplies its current Frontend state and revision, live
# registry and paired Transfer context from one serialized authority snapshot.
# Existing host revision, plan, owner, rights, lease and identity denials take
# precedence. Only then is the whole handle scope checked against that trusted
# snapshot, and its plan admitted by Transfer. Failure returns the original
# state and no effect. Mounted and zero/execute-only attenuated rights remain
# valid; no operation is invented. The owner must also revalidate later uses.
# The supplied records are trusted inputs, not authenticated issuer state or
# proof that a snapshot is current. A healthy mint at exhausted Nat slot or
# revision capacity can still abort; stale authority is checked before mint.
def issue_result(+state: State, expected_revision: Nat, +session: Nat, +frontend: F.State,
    frontend_revision: Nat, +registry: F.Registry, +context: T.Context, +handle: Nat, +plan: T.Plan,
    +rights: U32, +expires: Nat) -> IssueResult:
  f = Bool.pick(Unit -> IssueResult, current(state, expected_revision),
    x => ({+failed => Bool.pick(Unit -> IssueResult, Maybe.is_some(&2, Error, failed),
      y => IssueDenied{state, issue_binding_reason(failed)},
      y => ({+identity_error => Bool.pick(Unit -> IssueResult, Maybe.is_some(&2, I.Error, identity_error),
        z => IssueDenied{state, Identity{I.mint_reason(identity_error)}},
        z => Bool.pick(Unit -> IssueResult, issue_live_session(I.session_at(I.sessions(identity(state)), session),
          frontend, frontend_revision, registry, context, handle),
          w => ({+minted => Bool.pick(Unit -> IssueResult, I.Change.accepted(minted),
            v => Bool.pick(Unit -> IssueResult, Maybe.is_some(&2, Nat, I.Change.issued(minted)),
              u => Issued{with_identity(state, I.Change.state(minted)), issue_slot(I.Change.issued(minted))},
              u => IssueDenied{state, AuthorityUnavailable{}})(Unit{}),
            v => IssueDenied{state, Identity{I.mint_reason(I.Change.reason(minted))}})(Unit{})
            : I.Change -> IssueResult})(I.mint(identity(state), I.revision(identity(state)), session, handle,
              plan, rights, expires)),
          w => IssueDenied{state, AuthorityUnavailable{}})(Unit{}))(Unit{}) : Maybe<&2, I.Error> -> IssueResult})(I.mint_preflight(identity(state), I.revision(identity(state)), session)))(Unit{})
        : Maybe<&2, Error> -> IssueResult})(unbound(F.find_handle(F.handles(frontend), handle),
          I.session_at(I.sessions(identity(state)), session), plan, rights, expires)),
    x => IssueDenied{state, StaleRevision{}})
  f(Unit{})

# Legacy callers project the same one-gate result; this does not remint.
def issue(state: State, expected_revision: Nat, session: Nat, frontend: F.State,
    frontend_revision: Nat, registry: F.Registry, context: T.Context, handle: Nat, plan: T.Plan,
    rights: U32, expires: Nat) -> Step:
  IssueResult.step(issue_result(state, expected_revision, session, frontend, frontend_revision, registry,
    context, handle, plan, rights, expires))

# Implementation helper: delegate's gate.
def d_gate(ok: Bool, +state: State, +session: Nat, +ref: W.Ref, target: Nat, rights: U32, +lifetime: Nat,
    +now: Nat) -> Step:
  match ok:
    case True{}:
      changed(I.delegate(identity(state), I.revision(identity(state)), session, ref, target, rights, lifetime,
        now), state)
    case False{}:
      Denied{state, StaleRevision{}}

# Public entry point, family 1: session `session` (the transport identified
# it) delegates the entry `ref` names to session `target` with `rights` for
# `lifetime` from monitor time `now`, through `HostIdentity.delegate` (which
# re-resolves the parent and denies NotDelegable from a worker session,
# SubjectChanged, WidenedRights, and WidenedLifetime). Order: gate, then
# HostIdentity's checks (`Identity{reason}`). No effect. A delegation is a
# primitive transition so that the primitive revision covers every change to
# the identity table.
def delegate(+state: State, expected_revision: Nat, +session: Nat, +ref: W.Ref, target: Nat, rights: U32,
    +lifetime: Nat, +now: Nat) -> Step:
  d_gate(current(state, expected_revision), state, session, ref, target, rights, lifetime, now)

# --- Family 2: worker domains (public: admit_worker, charge, diagnostic,
# --- native_write_offered) ---------------------------------------------------------

# Implementation helper: whether every route in the inventory is mediated.
def routes_mediated(routes: +List<RouteFact>) -> Bool:
  match routes:
    case []:
      True{}
    case RouteFact{_, mediated} <> rest:
      mediated && routes_mediated(rest)

# Implementation helper: whether the backend's isolation is established. A
# CPU backend needs no device isolation; an accelerator needs
# `control_accelerator_isolation()` whatever its profile lists.
def backend_isolated(backend: Backend, +report: TargetReport) -> Bool:
  match backend:
    case Cpu{}:
      True{}
    case Accelerator{}:
      within(control_accelerator_isolation(), report_controls(report))

# Implementation helper: whether a profile describes protected worker work:
# it lists the worker family and requires at least one control.
def protects(+profile: Profile) -> Bool:
  within(family_worker(), profile_families(profile))
    && Bool.not(U32.is_eq(profile_controls(profile), no_controls()))

# Implementation helper: the reference of `entry` in this table, rebuilt from
# monitor state (host, current incarnation, slot, generation).
def entry_ref(+identity: I.State, +entry: I.Entry) -> W.Ref:
  W.Ref{U32.from_nat(I.host(identity)), U32.from_nat(I.incarnation(identity)),
    U32.from_nat(I.entry_slot(entry)), U32.from_nat(I.entry_generation(entry))}

# Implementation helper: record the admitted worker and allocate its id.
def commit_worker(state: State, worker: Worker) -> State:
  match state:
    case State{revision, identity, profiles, bindings, workers, next_worker, seals, publications}:
      State{1n+revision, identity, profiles, bindings, Workers{worker, workers}, 1n+next_worker, seals,
        publications}

# Implementation helper, step 11 and commit: plaintext is delivered only here,
# after every other admission check.
def a_routes(ok: Bool, +state: State, +configured: Configured, +session: Nat, +input: W.Ref) -> Step:
  match ok:
    case True{}:
      Admitted{commit_worker(state, Worker{next_worker(state), session, input, configured_profile(configured),
        Running{}, configured_quota(configured), no_usage()}), [DeliverInputs{next_worker(state), input}]}
    case False{}:
      Denied{state, UnmediatedRoute{}}

# Implementation helper, step 10.
def a_accelerator(ok: Bool, +state: State, +configured: Configured, routes: +List<RouteFact>,
    +session: Nat, +input: W.Ref) -> Step:
  match ok:
    case True{}:
      a_routes(routes_mediated(routes), state, configured, session, input)
    case False{}:
      Denied{state, UnisolatedAccelerator{}}

# Implementation helper, step 9.
def a_controls(ok: Bool, +state: State, +configured: Configured, +report: TargetReport,
    routes: +List<RouteFact>, +session: Nat, +input: W.Ref) -> Step:
  match ok:
    case True{}:
      a_accelerator(backend_isolated(profile_backend(configured_profile(configured)), report), state,
        configured, routes, session, input)
    case False{}:
      Denied{state, MissingControl{}}

# Implementation helper, step 8.
def a_families(ok: Bool, +state: State, +configured: Configured, +report: TargetReport,
    routes: +List<RouteFact>, +session: Nat, +input: W.Ref) -> Step:
  match ok:
    case True{}:
      a_controls(within(profile_controls(configured_profile(configured)), report_controls(report)), state,
        configured, report, routes, session, input)
    case False{}:
      Denied{state, UnsupportedFamily{}}

# Implementation helper, step 7.
def a_inventory(inventory: Fact, +state: State, +configured: Configured, +report: TargetReport,
    +session: Nat, +input: W.Ref) -> Step:
  match inventory:
    case Inventory{routes}:
      a_families(within(profile_families(configured_profile(configured)), report_families(report)), state,
        configured, report, routes, session, input)
    case _:
      Denied{state, WrongPhase{}}

# Implementation helper, step 6: one worker per input entry.
def a_slot(ok: Bool, +state: State, +configured: Configured, report: TargetReport, inventory: Fact,
    +session: Nat, +input: W.Ref) -> Step:
  match ok:
    case True{}:
      a_inventory(inventory, state, configured, report, session, input)
    case False{}:
      Denied{state, SlotOccupied{}}

# Implementation helper, step 5.
def a_protected(ok: Bool, +state: State, +configured: Configured, report: TargetReport, inventory: Fact,
    +session: Nat, +input: W.Ref) -> Step:
  match ok:
    case True{}:
      a_slot(Bool.not(occupied(workers(state), input)), state, configured, report, inventory, session, input)
    case False{}:
      Denied{state, MissingControl{}}

# Implementation helper, step 4, the configured profile. A bound profile id
# that is not configured once is unreachable from a valid state.
def a_profile(found: ProfileLookup, +state: State, report: TargetReport, inventory: Fact, +session: Nat,
    +input: W.Ref) -> Step:
  match found:
    case OneProfile{+configured}:
      a_protected(protects(configured_profile(configured)), state, configured, report, inventory, session,
        input)
    case _:
      Denied{state, UnknownProfile{}}

# Implementation helper, step 4: the profile the session was bound under at
# `open_session`. A session with no worker binding has no profile to admit
# under (more than one binding is unreachable from a valid state).
def a_bound(found: BindingLookup, +state: State, report: TargetReport, inventory: Fact, +session: Nat,
    +input: W.Ref) -> Step:
  match found:
    case OneBinding{+profile}:
      a_profile(profile_at(profiles(state), profile), state, report, inventory, session, input)
    case _:
      Denied{state, UnknownProfile{}}

# Implementation helper, step 3, the decision: the stored delegability.
def a_delegable(delegable: Bool, +state: State, report: TargetReport, inventory: Fact, +session: Nat,
    +input: W.Ref) -> Step:
  match delegable:
    case False{}:
      a_bound(binding_at(bindings(state), session), state, report, inventory, session, input)
    case True{}:
      Denied{state, DelegableSession{}}

# Implementation helper, step 3: the presenting session must be one the
# monitor recorded non-delegable, so the worker cannot re-delegate its inputs.
def a_session(found: I.SessionLookup, +state: State, report: TargetReport, inventory: Fact, +session: Nat,
    +input: W.Ref) -> Step:
  match found:
    case I.OneSession{bound}:
      a_delegable(I.session_delegable(bound), state, report, inventory, session, input)
    case _:
      # Unreachable after step 2 resolved on this session; kept for totality.
      Denied{state, Identity{I.UnknownSession{}}}

# Implementation helper, step 2: the input reference must resolve on the
# presenting session; the stored reference is rebuilt from the entry.
def a_identity(resolution: I.Resolution, +state: State, report: TargetReport, inventory: Fact,
    +session: Nat) -> Step:
  match resolution:
    case I.Unresolved{reason}:
      Denied{state, Identity{reason}}
    case I.Resolved{+entry, _}:
      a_session(I.session_at(I.sessions(identity(state)), session), state, report, inventory, session,
        entry_ref(identity(state), entry))

# Implementation helper, step 1.
def a_gate(ok: Bool, +state: State, report: TargetReport, inventory: Fact, +session: Nat, +ref: W.Ref,
    +now: Nat) -> Step:
  match ok:
    case True{}:
      a_identity(I.resolve(identity(state), I.revision(identity(state)), session, ref, now), state, report,
        inventory, session)
    case False{}:
      Denied{state, StaleRevision{}}

# Public entry point, family 2: admit a protected worker domain on worker
# session `session`, under the configured profile that session was bound
# under at `open_session` (the request names no profile; the profile and its
# quota limit come from the monitor's tables). `report` and `inventory` are
# the target's facts; `ref` is the worker's input reference, resolved on
# `session` at monitor time `now`. Checks in the documented admission order;
# on acceptance records the worker `Running` and returns exactly
# `[DeliverInputs{worker, input}]`.
def admit_worker(+state: State, expected_revision: Nat, report: TargetReport, inventory: Fact,
    +session: Nat, +ref: W.Ref, +now: Nat) -> Step:
  a_gate(current(state, expected_revision), state, report, inventory, session, ref, now)

# Implementation helper: one worker's use after a charge.
def charged_one(ok: Bool, worker: Worker, amount: Nat) -> Worker:
  match ok worker:
    case True{} Worker{id, session, input, profile, phase, quota_limit, quota_used}:
      Worker{id, session, input, profile, phase, quota_limit, Nat.add(quota_used, amount)}
    case False{} worker:
      worker

# Implementation helper: add `amount` to the use of worker `id` only.
def charged(workers: Workers, +id: Nat, +amount: Nat) -> Workers:
  match workers:
    case NoWorkers{}:
      NoWorkers{}
    case Workers{+worker, rest}:
      Workers{charged_one(Nat.is_eq(worker_id(worker), id), worker, amount), charged(rest, id, amount)}

# Implementation helper: commit an accepted charge.
def commit_charge(state: State, +id: Nat, +amount: Nat) -> State:
  match state:
    case State{revision, identity, profiles, bindings, workers, next_worker, seals, publications}:
      State{1n+revision, identity, profiles, bindings, charged(workers, id, amount), next_worker, seals,
        publications}

# Implementation helper: charge's quota step.
def c_quota(ok: Bool, +state: State, +id: Nat, +amount: Nat) -> Step:
  match ok:
    case True{}:
      Admitted{commit_charge(state, id, amount), []}
    case False{}:
      Denied{state, QuotaExhausted{}}

# Implementation helper: charge's re-resolution step.
def c_live(resolution: I.Resolution, +state: State, +worker: Worker, +amount: Nat) -> Step:
  match resolution:
    case I.Resolved{_, _}:
      c_quota(Nat.is_le(Nat.add(worker_quota_used(worker), amount), worker_quota_limit(worker)), state,
        worker_id(worker), amount)
    case I.Unresolved{reason}:
      Denied{state, Identity{reason}}

# Implementation helper: charge's phase step.
def c_phase(ok: Bool, +state: State, +worker: Worker, +amount: Nat, +now: Nat) -> Step:
  match ok:
    case True{}:
      c_live(reresolve(state, worker, now), state, worker, amount)
    case False{}:
      Denied{state, WrongPhase{}}

# Implementation helper: charge's worker lookup (more than one worker with an
# id is unreachable from a valid state).
def c_worker(found: WorkerLookup, +state: State, +amount: Nat, +now: Nat) -> Step:
  match found:
    case OneWorker{+worker}:
      c_phase(is_running(worker_phase(worker)), state, worker, amount, now)
    case _:
      Denied{state, UnknownWorker{}}

# Implementation helper: charge's fact step.
def c_fact(fact: Fact, +state: State, +now: Nat) -> Step:
  match fact:
    case ResourceRequest{+worker, amount}:
      c_worker(worker_at(workers(state), worker), state, amount, now)
    case _:
      Denied{state, WrongPhase{}}

# Implementation helper: charge's gate.
def c_gate(ok: Bool, +state: State, fact: Fact, +now: Nat) -> Step:
  match ok:
    case True{}:
      c_fact(fact, state, now)
    case False{}:
      Denied{state, StaleRevision{}}

# Public entry point, family 2: a `ResourceRequest` from a running worker, at
# monitor time `now`, in the documented runtime order, then
# `quota_used + amount <= quota_limit` (else QuotaExhausted). Acceptance adds
# the amount to `quota_used` and nothing else: no rights, phase, input, or
# identity change, and no effect.
def charge(+state: State, expected_revision: Nat, fact: Fact, +now: Nat) -> Step:
  c_gate(current(state, expected_revision), state, fact, now)

# Implementation helper: diagnostic's sink step. Only a non-public emission
# is accepted, and it yields no effect.
def g_public(public: Bool, +state: State) -> Step:
  match public:
    case False{}:
      Admitted{advanced(state), []}
    case True{}:
      Denied{state, DiagnosticSink{}}

# Implementation helper: diagnostic's re-resolution step.
def g_live(resolution: I.Resolution, +state: State, public: Bool) -> Step:
  match resolution:
    case I.Resolved{_, _}:
      g_public(public, state)
    case I.Unresolved{reason}:
      Denied{state, Identity{reason}}

# Implementation helper: diagnostic's phase step.
def g_phase(ok: Bool, +state: State, +worker: Worker, public: Bool, +now: Nat) -> Step:
  match ok:
    case True{}:
      g_live(reresolve(state, worker, now), state, public)
    case False{}:
      Denied{state, WrongPhase{}}

# Implementation helper: diagnostic's worker lookup.
def g_worker(found: WorkerLookup, +state: State, public: Bool, +now: Nat) -> Step:
  match found:
    case OneWorker{+worker}:
      g_phase(is_running(worker_phase(worker)), state, worker, public, now)
    case _:
      Denied{state, UnknownWorker{}}

# Implementation helper: diagnostic's fact step.
def g_fact(fact: Fact, +state: State, +now: Nat) -> Step:
  match fact:
    case Diagnostic{+worker, public}:
      g_worker(worker_at(workers(state), worker), state, public, now)
    case _:
      Denied{state, WrongPhase{}}

# Implementation helper: diagnostic's gate.
def g_gate(ok: Bool, +state: State, fact: Fact, +now: Nat) -> Step:
  match ok:
    case True{}:
      g_fact(fact, state, now)
    case False{}:
      Denied{state, StaleRevision{}}

# Public entry point, family 2: a `Diagnostic` from a running worker, at
# monitor time `now`, in the documented runtime order; then a public emission
# is denied DiagnosticSink. A non-public emission is accepted with no effect
# (the revision advances; nothing else changes).
def diagnostic(+state: State, expected_revision: Nat, fact: Fact, +now: Nat) -> Step:
  g_gate(current(state, expected_revision), state, fact, now)

# Implementation helper: native_write_offered's fact step. There is no
# accepting branch.
def n_fact(fact: Fact, +state: State) -> Step:
  match fact:
    case NativeWriteOffered{_}:
      Denied{state, FastPathUnavailable{}}
    case _:
      Denied{state, WrongPhase{}}

# Implementation helper: native_write_offered's gate.
def n_gate(ok: Bool, +state: State, fact: Fact) -> Step:
  match ok:
    case True{}:
      n_fact(fact, state)
    case False{}:
      Denied{state, StaleRevision{}}

# Public entry point, family 2: a `NativeWriteOffered` fact. Every worker here
# runs protected work, and a native write route lacks the complete Bend
# authorization result bound to an artifact, so the offer is always denied
# FastPathUnavailable (after the gate and the fact-variant check).
def native_write_offered(+state: State, expected_revision: Nat, fact: Fact) -> Step:
  n_gate(current(state, expected_revision), state, fact)

# --- Family 3: artifacts ------------------------------------------------------------
# `seal`, in HostPublication.bend (this module's size; the types it writes,
# `Sealed` and `Seals`, are above).

# --- Family 4: publication ----------------------------------------------------------
# `publish` and `reconcile`, in HostPublication.bend (`Publication`,
# `Publications`, and the `Reconcile` effect are above; the publication effect
# itself is defined there, beside its only constructor site).

# --- Family 5: revocation -----------------------------------------------------------
# `revoke`, `restart`, `quiesce`, `reclaim`, and `complete`, in
# HostPublication.bend (the `StopEffects` and `Reclaim` effects are above).
