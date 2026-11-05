import Base
import ./HostWire.bend as W
import ./HostIdentity.bend as I
import ./Frontend.bend as F
import ./Transfer.bend as T
import ./Backplane.bend as B
import ./DataOS.bend as D

# Portable HOST PRIMITIVES (task 1.3 of the add-portable-host-contract change;
# PH-001, PH-006, PH-007, PH-014 in this part): the five primitive families
# every target binding (Genode, direct Linux, native Windows, a future kernel)
# implements, defined once here in Bend:
#   1. session binding   (`family_session()`)      this module, task 1.3
#   2. worker domains    (`family_worker()`)       this module, task 1.3
#   3. artifacts         (`family_artifact()`)     added by Task 4
#   4. publication       (`family_publication()`)  added by Task 4
#   5. revocation        (`family_revocation()`)   added by Task 4
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
#   transition. A request names a profile only by id; `admit_worker`
#   resolves the id in that table and denies an unknown one. No request
#   field carries controls, families, a backend, or a quota limit, and
#   `TargetReport` has no profile field, so a target cannot introduce or
#   lower one; its facts are only compared against the configured profile.
# - `Effect` is closed. It has no native write, publish, or diagnostic
#   variant, and `native_write_offered` has no accepting branch, so the fast
#   publication route has no value to return. Publication will be one
#   `Effect` that carries a `DataOS.commit_from_capability` result (Task 4).
# - `Denied` has no effects field: a denial cannot carry work for the target
#   (law `primitive_denied_emits_nothing`).
# Host obligations (section 2, reviewed-only): (a) Bend datatypes are public,
# so a target could construct an `Effect` itself. A target-constructed
# `Effect` is not authorization; the binding must execute only effects taken
# from an `Admitted` step this monitor returned. (b) Which configured
# profile a request uses is the admitted request's choice: the id passed to
# `admit_worker` must come from that request, never from the binding. Every
# configured profile still has to pass the admission checks below.
#
# Authority. `State` is monitor state: the HostIdentity table (sessions and
# entries, built only by its transitions), the configured profile table, the
# admitted workers, and the worker counter. Worker ids are monitor-allocated.
# A worker's session is the one `HostIdentity.resolve` accepted for the
# presented reference, and its stored input reference is rebuilt from the
# resolved entry (this host, the current incarnation, the entry's slot and
# generation), not copied from the request. Its profile and quota limit come
# from the configured table. The only target value stored is the amount a
# successful `charge` adds, bounded by the configured limit.
# Worker sessions: a worker is admitted only on a session the monitor bound
# non-delegable, so `HostIdentity.delegate` from a worker session is always
# denied NotDelegable and a worker cannot pass its inputs on. Delegability
# is reported in `SessionEvidence` (a section 2 host obligation: the binding
# reports it from how the native session was created).
# Each input entry feeds at most one worker that is not `Reclaimed`.
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
# every configured profile id names one profile; every worker id is nonzero,
# below `next_worker`, and names one worker; and no two workers that are not
# `Reclaimed` share an input entry (host, incarnation, and slot). Every
# transition first requires the expected revision and a `valid` state (a
# state failing `valid` is not one this monitor committed, so it is denied
# StaleRevision, the HostIdentity pattern), and every admitted step
# preserves `valid`.
#
# Admission order (`admit_worker`), first failure reported:
#   0. gate          revision differs, or the state is not valid -> StaleRevision
#   1. profile       the id names no configured profile     -> UnknownProfile
#   2. protected     the profile does not list `family_worker()`,
#                    or requires no control                 -> MissingControl
#   3. identity      the input reference does not resolve on
#                    the presenting session                 -> Identity{reason}
#   4. session       that session is delegable              -> DelegableSession
#   5. slot          a worker that is not Reclaimed already
#                    holds the input entry                  -> SlotOccupied
#   6. inventory     the fact is not an `Inventory`         -> WrongPhase
#   7. families      a required family is not supported     -> UnsupportedFamily
#   8. controls      a required control is not established  -> MissingControl
#   9. accelerator   an `Accelerator` backend without
#                    `control_accelerator_isolation()`      -> UnisolatedAccelerator
#                    (checked whether or not the profile
#                    lists that control)
#  10. routes        any inventory route is not mediated    -> UnmediatedRoute
#   then commit: the worker is recorded `Running` and the only effect is
#   `DeliverInputs`, naming the input by its full reference (host,
#   incarnation, slot, generation), so plaintext delivery is the last step of
#   an accepted admission (PH-006) and a delayed effect cannot name a reused
#   slot. Admission is atomic: there is no window between recording the
#   worker and the delivery. Plan ruling: there is no downgrade. An
#   accelerator profile without isolation is denied; CPU work is a separate
#   admission naming a profile whose backend is `Cpu`, and the worker
#   records that profile (PH-014). Inputs are delivered to a confined worker
#   without a Transfer/Frontend plan recheck; the plan is rechecked at
#   publication (Task 4, `DataOS.commit_from_capability`).
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
# Imports: `Backplane` and `DataOS` are imported for the publication family
# (Task 4), whose effect carries a `DataOS.commit_from_capability` result;
# this part uses neither.
#
# Public entry points: `empty`, `valid`, `open_session`, `use` (family 1);
# `admit_worker`, `charge`, `diagnostic`, `native_write_offered` (family 2);
# the types `Backend`, `Profile`, `Configured`, `Profiles`, `TargetReport`,
# `RouteFact`, `Fact`, `Effect`, `Step`, `UseResult`, `Error`, `Phase`,
# `Worker`, `Workers`, `State`; the named family, control, and right bits
# (with `no_controls` and `no_right`),
# `operation_right`, `first_worker`, `no_usage`; and the accessors and
# equalities marked "Public". Every other def is an implementation helper.

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
# worker's output. Task 4 adds the artifact, publication, and revocation
# facts.
type Fact is Data:
  SessionEvidence{caller: F.Caller, origin: I.Origin, delegable: Bool}
  Inventory{routes: +List<RouteFact>}
  ResourceRequest{worker: Nat, amount: Nat}
  Diagnostic{worker: Nat, public: Bool}
  NativeWriteOffered{worker: Nat}

# The only work a target binding may perform, each returned by an admitted
# transition. `DeliverInputs` delivers the protected inputs of the identity
# entry `input` (its full reference, as the monitor rebuilt it) into
# `worker`'s confined domain. Task 4 adds the rest.
type Effect is Data:
  DeliverInputs{worker: Nat, input: W.Ref}

# A worker domain's lifecycle phase. Admission records workers directly in
# `Running`, so no transition of this part produces `Prepared`; it is kept
# for Task 4's revocation family, and the runtime checks deny it like every
# phase other than `Running`.
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

# The primitive layer's whole state. `profiles` is fixed by `empty`;
# `next_worker` exceeds every worker id.
type State is Data:
  State{revision: Nat, identity: I.State, profiles: Profiles, workers: Workers, next_worker: Nat}

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

# The output of every mutating transition. Only `Admitted` carries effects.
type Step is Data:
  Admitted{state: State, effects: +List<Effect>}
  Denied{state: State, reason: Error}

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

# Implementation helper: a counted lookup of configured profiles with one id.
type ProfileLookup is Data:
  NoProfile{}
  OneProfile{configured: Configured}
  ManyProfiles{}

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
  State{0n, identity, profiles, NoWorkers{}, first_worker()}

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
    case State{revision, _, _, _, _}:
      revision

def identity(state: State) -> I.State:
  match state:
    case State{_, identity, _, _, _}:
      identity

def profiles(state: State) -> Profiles:
  match state:
    case State{_, _, profiles, _, _}:
      profiles

def workers(state: State) -> Workers:
  match state:
    case State{_, _, _, workers, _}:
      workers

def next_worker(state: State) -> Nat:
  match state:
    case State{_, _, _, _, next_worker}:
      next_worker

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

# Public: the structural invariants (module header). It checks structure only
# and does not authenticate the supplied state.
def valid(state: State) -> Bool:
  match state:
    case State{_, identity, +profiles, +workers, +next_worker}:
      I.valid(identity) && profiles_valid(profiles, profiles) && workers_valid(workers, workers, next_worker)

# Implementation helper: every transition's first gate.
def current(+state: State, expected_revision: Nat) -> Bool:
  Nat.is_eq(revision(state), expected_revision) && valid(state)

# Implementation helper: re-resolve a worker's input on its own session.
def reresolve(+state: State, +worker: Worker, +now: Nat) -> I.Resolution:
  I.resolve(identity(state), I.revision(identity(state)), worker_session(worker), worker_input(worker), now)

# Implementation helper: advance the revision once, keeping everything else.
def advanced(state: State) -> State:
  match state:
    case State{revision, identity, profiles, workers, next_worker}:
      State{1n+revision, identity, profiles, workers, next_worker}

# --- Family 1: session binding (public: open_session, use) ------------------------

# Implementation helper: commit a bound identity table.
def with_identity(state: State, identity: I.State) -> State:
  match state:
    case State{revision, _, profiles, workers, next_worker}:
      State{1n+revision, identity, profiles, workers, next_worker}

# Implementation helper: open_session's identity step; a HostIdentity denial
# is reported as `Identity{reason}`.
def o_bound(change: I.Change, +state: State) -> Step:
  match change:
    case I.Rejected{_, reason}:
      Denied{state, Identity{reason}}
    case I.Accepted{identity, _}:
      Admitted{with_identity(state, identity), []}

# Implementation helper: open_session's fact step.
def o_fact(fact: Fact, +state: State) -> Step:
  match fact:
    case SessionEvidence{caller, +origin, delegable}:
      o_bound(I.bind_session(identity(state), I.revision(identity(state)), caller, origin, delegable), state)
    case _:
      Denied{state, WrongPhase{}}

# Implementation helper: open_session's family step.
def o_family(ok: Bool, +state: State, fact: Fact) -> Step:
  match ok:
    case True{}:
      o_fact(fact, state)
    case False{}:
      Denied{state, UnsupportedFamily{}}

# Implementation helper: open_session's gate.
def o_gate(ok: Bool, +state: State, report: TargetReport, fact: Fact) -> Step:
  match ok:
    case True{}:
      o_family(within(family_session(), report_families(report)), state, fact)
    case False{}:
      Denied{state, StaleRevision{}}

# Public entry point, family 1: bind a native session from the target's
# `SessionEvidence` through `HostIdentity.bind_session`, which allocates the
# session id. Requires the target to support `family_session()`. Order:
# gate, family, fact variant, then HostIdentity's own checks. No effect.
def open_session(+state: State, expected_revision: Nat, report: TargetReport, fact: Fact) -> Step:
  o_gate(current(state, expected_revision), state, report, fact)

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
    case State{revision, identity, profiles, workers, next_worker}:
      State{1n+revision, identity, profiles, Workers{worker, workers}, 1n+next_worker}

# Implementation helper, step 10 and commit: plaintext is delivered only here,
# after every other admission check.
def a_routes(ok: Bool, +state: State, +configured: Configured, +session: Nat, +input: W.Ref) -> Step:
  match ok:
    case True{}:
      Admitted{commit_worker(state, Worker{next_worker(state), session, input, configured_profile(configured),
        Running{}, configured_quota(configured), no_usage()}), [DeliverInputs{next_worker(state), input}]}
    case False{}:
      Denied{state, UnmediatedRoute{}}

# Implementation helper, step 9.
def a_accelerator(ok: Bool, +state: State, +configured: Configured, routes: +List<RouteFact>,
    +session: Nat, +input: W.Ref) -> Step:
  match ok:
    case True{}:
      a_routes(routes_mediated(routes), state, configured, session, input)
    case False{}:
      Denied{state, UnisolatedAccelerator{}}

# Implementation helper, step 8.
def a_controls(ok: Bool, +state: State, +configured: Configured, +report: TargetReport,
    routes: +List<RouteFact>, +session: Nat, +input: W.Ref) -> Step:
  match ok:
    case True{}:
      a_accelerator(backend_isolated(profile_backend(configured_profile(configured)), report), state,
        configured, routes, session, input)
    case False{}:
      Denied{state, MissingControl{}}

# Implementation helper, step 7.
def a_families(ok: Bool, +state: State, +configured: Configured, +report: TargetReport,
    routes: +List<RouteFact>, +session: Nat, +input: W.Ref) -> Step:
  match ok:
    case True{}:
      a_controls(within(profile_controls(configured_profile(configured)), report_controls(report)), state,
        configured, report, routes, session, input)
    case False{}:
      Denied{state, UnsupportedFamily{}}

# Implementation helper, step 6.
def a_inventory(inventory: Fact, +state: State, +configured: Configured, +report: TargetReport,
    +session: Nat, +input: W.Ref) -> Step:
  match inventory:
    case Inventory{routes}:
      a_families(within(profile_families(configured_profile(configured)), report_families(report)), state,
        configured, report, routes, session, input)
    case _:
      Denied{state, WrongPhase{}}

# Implementation helper, step 5: one worker per input entry.
def a_slot(ok: Bool, +state: State, +configured: Configured, report: TargetReport, inventory: Fact,
    +session: Nat, +input: W.Ref) -> Step:
  match ok:
    case True{}:
      a_inventory(inventory, state, configured, report, session, input)
    case False{}:
      Denied{state, SlotOccupied{}}

# Implementation helper, step 4, the decision.
def a_delegable(delegable: Bool, +state: State, +configured: Configured, report: TargetReport,
    inventory: Fact, +session: Nat, +input: W.Ref) -> Step:
  match delegable:
    case False{}:
      a_slot(Bool.not(occupied(workers(state), input)), state, configured, report, inventory, session, input)
    case True{}:
      Denied{state, DelegableSession{}}

# Implementation helper, step 4: the presenting session must be bound
# non-delegable, so the worker cannot re-delegate its inputs.
def a_session(found: I.SessionLookup, +state: State, +configured: Configured, report: TargetReport,
    inventory: Fact, +session: Nat, +input: W.Ref) -> Step:
  match found:
    case I.OneSession{bound}:
      a_delegable(I.session_delegable(bound), state, configured, report, inventory, session, input)
    case _:
      # Unreachable after step 3 resolved on this session; kept for totality.
      Denied{state, Identity{I.UnknownSession{}}}

# Implementation helper, step 3: the input reference must resolve on the
# presenting session; the stored reference is rebuilt from the entry.
def a_identity(resolution: I.Resolution, +state: State, +configured: Configured, report: TargetReport,
    inventory: Fact, +session: Nat) -> Step:
  match resolution:
    case I.Unresolved{reason}:
      Denied{state, Identity{reason}}
    case I.Resolved{+entry, _}:
      a_session(I.session_at(I.sessions(identity(state)), session), state, configured, report, inventory,
        session, entry_ref(identity(state), entry))

# Implementation helper, step 2.
def a_protected(ok: Bool, +state: State, +configured: Configured, report: TargetReport, inventory: Fact,
    +session: Nat, +ref: W.Ref, +now: Nat) -> Step:
  match ok:
    case True{}:
      a_identity(I.resolve(identity(state), I.revision(identity(state)), session, ref, now), state,
        configured, report, inventory, session)
    case False{}:
      Denied{state, MissingControl{}}

# Implementation helper, step 1: the profile id must name one configured
# profile (more than one is unreachable from a valid state).
def a_profile(found: ProfileLookup, +state: State, report: TargetReport, inventory: Fact, +session: Nat,
    +ref: W.Ref, +now: Nat) -> Step:
  match found:
    case OneProfile{+configured}:
      a_protected(protects(configured_profile(configured)), state, configured, report, inventory, session,
        ref, now)
    case _:
      Denied{state, UnknownProfile{}}

# Implementation helper, step 0.
def a_gate(ok: Bool, +state: State, +profile: Nat, report: TargetReport, inventory: Fact, +session: Nat,
    +ref: W.Ref, +now: Nat) -> Step:
  match ok:
    case True{}:
      a_profile(profile_at(profiles(state), profile), state, report, inventory, session, ref, now)
    case False{}:
      Denied{state, StaleRevision{}}

# Public entry point, family 2: admit a protected worker domain under the
# configured profile `profile` (an id; the profile and its quota limit come
# from the monitor's table). `report` and `inventory` are the target's facts;
# `ref` is the worker's input reference, presented on its native `session`,
# resolved at monitor time `now`. Checks in the documented admission order;
# on acceptance records the worker `Running` and returns exactly
# `[DeliverInputs{worker, input}]`.
def admit_worker(+state: State, expected_revision: Nat, +profile: Nat, report: TargetReport,
    inventory: Fact, +session: Nat, +ref: W.Ref, +now: Nat) -> Step:
  a_gate(current(state, expected_revision), state, profile, report, inventory, session, ref, now)

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
    case State{revision, identity, profiles, workers, next_worker}:
      State{1n+revision, identity, profiles, charged(workers, id, amount), next_worker}

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

# --- Family 3: artifacts (Task 4) -----------------------------------------------

# --- Family 4: publication (Task 4) ---------------------------------------------

# --- Family 5: revocation (Task 4) ----------------------------------------------
