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
# only the `Effect` values in a `Admitted` step that one of these transitions
# returned. It decides nothing. The types make an alternate policy or
# publication path inexpressible rather than merely documented:
# - No transition takes a function, a template, a decision, a commit result,
#   a plan, rights, or a profile from the target. Every target-supplied input
#   is an observation (`Fact`, `TargetReport`, `RouteFact`) whose fields are
#   identities, counts, bit sets of native support, and Booleans.
# - The execution `Profile` (required families, required controls, backend)
#   is a separate monitor-owned parameter taken from the admitted request.
#   `TargetReport` has no profile field, so a target cannot select, name, or
#   downgrade the profile; its facts are only compared against it.
# - `Effect` is closed. It has no native write, publish, or diagnostic
#   variant, and `native_write_offered` has no accepting branch, so the fast
#   publication route has no value to return. Publication will be one
#   `Effect` that carries a `DataOS.commit_from_capability` result (Task 4).
# - `Denied` has no effects field: a denial cannot carry work for the target
#   (law `primitive_denied_emits_nothing`).
# Host obligation (section 2, reviewed-only): Bend datatypes are public, so a
# target could construct an `Effect` itself. A target-constructed `Effect` is
# not authorization; the binding must execute only effects taken from a
# `Admitted` this monitor returned, at the revision it returned them.
#
# Authority. `State` is monitor state: the HostIdentity table (sessions and
# entries, built only by its transitions), the admitted workers, and the
# worker counter. Worker ids are monitor-allocated. A worker's session and
# input slot are those `HostIdentity.resolve` accepted for the presented
# reference; its profile and quota limit are the monitor's admitted request.
# No caller-supplied value becomes a stored fact other than the monitor's
# own admission parameters and the amount a successful `charge` adds.
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
# Admission order (`admit_worker`), first failure reported:
#   0. revision      expected_revision differs              -> StaleRevision
#   1. identity      the input reference does not resolve on
#                    the worker's session                   -> Identity{reason}
#   2. inventory     the fact is not an `Inventory`         -> WrongPhase
#   3. families      a required family is not supported     -> UnsupportedFamily
#   4. controls      a required control is not established  -> MissingControl
#   5. accelerator   an `Accelerator` backend without
#                    `control_accelerator_isolation()`      -> UnisolatedAccelerator
#                    (checked whether or not the profile
#                    lists that control)
#   6. routes        any inventory route is not mediated    -> UnmediatedRoute
#   then commit: the worker is recorded `Running` and the only effect is
#   `DeliverInputs`, so plaintext delivery is the last step of an accepted
#   admission (PH-006). Plan ruling: there is no downgrade. An accelerator
#   profile without isolation is denied; CPU work is a separate admission
#   whose profile says `Cpu`, and the worker records that backend (PH-014).
#
# Worker runtime rulings. `charge` admits an amount only while the total stays
# within `quota_limit` and changes nothing but `quota_used`, so exhaustion
# cannot change rights or phase (PH-007). `diagnostic` accepts only a
# non-public emission, with no effect; a public emission from a protected
# worker is denied: the contract has no ungated diagnostic route, and public
# output can leave only through publication (plan ruling). A native write
# offer is always denied `FastPathUnavailable` (PH-001): it lacks the Bend
# authorization result bound to an artifact. Runtime facts require a
# `Running` worker; any other phase is `WrongPhase`. A fact of the wrong
# variant for a transition is also `WrongPhase` (it is not the observation
# that step of the protocol consumes).
#
# Failure behavior: every transition first checks `expected_revision`, then
# its own conditions in the documented order. A denial returns
# `Denied{state, reason}` with the supplied state itself and exactly one
# reason from the closed `Error` set, and no effects. A success returns
# `Admitted{state, effects}`, advancing `revision` exactly once. `use` is
# read-only and returns a `HostIdentity.Resolution`.
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
# Public entry points: `empty`, `open_session`, `use` (family 1);
# `admit_worker`, `charge`, `diagnostic`, `native_write_offered` (family 2);
# the types `Backend`, `Profile`, `TargetReport`, `RouteFact`, `Fact`,
# `Effect`, `Step`, `Error`, `Phase`, `Worker`, `Workers`, `State`; the named
# family and control bits and `first_worker`; and the accessors and
# equalities marked "Public". Every other def is an implementation helper.

# --- Interface types -------------------------------------------------------------

# The execution backend an admitted request permits.
type Backend is Data:
  Cpu{}
  Accelerator{}

# A monitor-owned execution profile, taken from the admitted request and never
# from the target: the families and controls (bit sets of the named bits
# below) the work requires, and its backend.
type Profile is Data:
  Profile{id: Nat, required_families: U32, required_controls: U32, backend: Backend}

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
# whether it may delegate; `Inventory` the worker's complete route set;
# `ResourceRequest` a worker asking for `amount` more units; `Diagnostic` a
# worker's emission and whether it would be public; `NativeWriteOffered` a
# native fast write route offered for a worker's output. Task 4 adds the
# artifact, publication, and revocation facts.
type Fact is Data:
  SessionEvidence{caller: F.Caller, origin: I.Origin, delegable: Bool}
  Inventory{routes: +List<RouteFact>}
  ResourceRequest{worker: Nat, amount: Nat}
  Diagnostic{worker: Nat, public: Bool}
  NativeWriteOffered{worker: Nat}

# The only work a target binding may perform, each returned by an admitted
# transition. `DeliverInputs` delivers the protected inputs named by the
# identity table `slot` into `worker`'s confined domain. Task 4 adds the rest.
type Effect is Data:
  DeliverInputs{worker: Nat, slot: Nat}

# A worker domain's lifecycle phase. Task 3 admits workers directly into
# `Running`; Task 4's revocation family moves them through the others.
type Phase is Data:
  Prepared{}
  Running{}
  Revoked{}
  Quiesced{}
  Reclaimed{}

# An admitted worker domain: its monitor-allocated id, the session and input
# slot `HostIdentity.resolve` accepted, the admitted profile, its phase, and
# its quota (limit from the admitted request, use from accepted charges).
type Worker is Data:
  Worker{id: Nat, session: Nat, slot: Nat, profile: Profile, phase: Phase,
    quota_limit: Nat, quota_used: Nat}

type Workers is Data:
  NoWorkers{}
  Workers{head: Worker, tail: Workers}

# The primitive layer's whole state. `next_worker` exceeds every worker id.
type State is Data:
  State{revision: Nat, identity: I.State, workers: Workers, next_worker: Nat}

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

# The output of every mutating transition. Only `Admitted` carries effects.
type Step is Data:
  Admitted{state: State, effects: +List<Effect>}
  Denied{state: State, reason: Error}

# Implementation helper: a counted lookup of workers with one id.
type WorkerLookup is Data:
  NoWorker{}
  OneWorker{worker: Worker}
  ManyWorkers{}

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

# The first worker id; 0 is never a worker.
def first_worker() -> Nat:
  1n

# The quota a newly admitted worker has used.
def no_usage() -> Nat:
  0n

# Public entry point: a primitive layer over the monitor's identity table,
# with no workers.
def empty(identity: I.State) -> State:
  State{0n, identity, NoWorkers{}, first_worker()}

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
    case State{revision, _, _, _}:
      revision

def identity(state: State) -> I.State:
  match state:
    case State{_, identity, _, _}:
      identity

def workers(state: State) -> Workers:
  match state:
    case State{_, _, workers, _}:
      workers

def next_worker(state: State) -> Nat:
  match state:
    case State{_, _, _, next_worker}:
      next_worker

def worker_id(worker: Worker) -> Nat:
  match worker:
    case Worker{id, _, _, _, _, _, _}:
      id

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

def report_families(report: TargetReport) -> U32:
  match report:
    case TargetReport{families, _}:
      families

def report_controls(report: TargetReport) -> U32:
  match report:
    case TargetReport{_, controls}:
      controls

# --- Shared helpers (implementation helpers) --------------------------------------

# Implementation helper: whether the mutating gate passes.
def current(+state: State, expected_revision: Nat) -> Bool:
  Nat.is_eq(revision(state), expected_revision)

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

# Implementation helper: advance the revision once, keeping everything else.
def advanced(state: State) -> State:
  match state:
    case State{revision, identity, workers, next_worker}:
      State{1n+revision, identity, workers, next_worker}

# --- Family 1: session binding (public: open_session, use) ------------------------

# Implementation helper: commit a bound identity table.
def with_identity(state: State, identity: I.State) -> State:
  match state:
    case State{revision, _, workers, next_worker}:
      State{1n+revision, identity, workers, next_worker}

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

# Implementation helper: open_session's revision gate.
def o_gate(ok: Bool, +state: State, report: TargetReport, fact: Fact) -> Step:
  match ok:
    case True{}:
      o_family(within(family_session(), report_families(report)), state, fact)
    case False{}:
      Denied{state, StaleRevision{}}

# Public entry point, family 1: bind a native session from the target's
# `SessionEvidence` through `HostIdentity.bind_session`, which allocates the
# session id. Requires the target to support `family_session()`. Order:
# revision, family, fact variant, then HostIdentity's own checks. No effect.
def open_session(+state: State, expected_revision: Nat, report: TargetReport, fact: Fact) -> Step:
  o_gate(current(state, expected_revision), state, report, fact)

# Implementation helper: use's revision gate.
def u_gate(ok: Bool, +state: State, +session: Nat, message: W.Message, +now: Nat) -> I.Resolution:
  match ok:
    case True{}:
      I.resolve(identity(state), I.revision(identity(state)), session, W.Message.ref(message), now)
    case False{}:
      I.Unresolved{I.StaleRevision{}}

# Public entry point, family 1, read-only: resolve the reference of a decoded
# wire `message` presented on the native session the transport identified as
# `session`, through `HostIdentity.resolve` only. The message's claimed
# subject is never read, so the effective caller is the resolved entry's
# owner. A stale `expected_revision` is `Unresolved{StaleRevision}`.
def use(+state: State, expected_revision: Nat, +session: Nat, message: W.Message, +now: Nat) -> I.Resolution:
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

# Implementation helper: record the admitted worker and allocate its id.
def commit_worker(state: State, worker: Worker) -> State:
  match state:
    case State{revision, identity, workers, next_worker}:
      State{1n+revision, identity, Workers{worker, workers}, 1n+next_worker}

# Implementation helper, step 6 and commit: plaintext is delivered only here,
# after every other admission check.
def a_routes(ok: Bool, +state: State, profile: Profile, quota_limit: Nat, +session: Nat, +slot: Nat) -> Step:
  match ok:
    case True{}:
      Admitted{commit_worker(state, Worker{next_worker(state), session, slot, profile, Running{},
        quota_limit, no_usage()}), [DeliverInputs{next_worker(state), slot}]}
    case False{}:
      Denied{state, UnmediatedRoute{}}

# Implementation helper, step 5.
def a_accelerator(ok: Bool, +state: State, profile: Profile, quota_limit: Nat, routes: +List<RouteFact>,
    +session: Nat, +slot: Nat) -> Step:
  match ok:
    case True{}:
      a_routes(routes_mediated(routes), state, profile, quota_limit, session, slot)
    case False{}:
      Denied{state, UnisolatedAccelerator{}}

# Implementation helper, step 4.
def a_controls(ok: Bool, +state: State, +profile: Profile, quota_limit: Nat, +report: TargetReport,
    routes: +List<RouteFact>, +session: Nat, +slot: Nat) -> Step:
  match ok:
    case True{}:
      a_accelerator(backend_isolated(profile_backend(profile), report), state, profile, quota_limit,
        routes, session, slot)
    case False{}:
      Denied{state, MissingControl{}}

# Implementation helper, step 3.
def a_families(ok: Bool, +state: State, +profile: Profile, quota_limit: Nat, +report: TargetReport,
    routes: +List<RouteFact>, +session: Nat, +slot: Nat) -> Step:
  match ok:
    case True{}:
      a_controls(within(profile_controls(profile), report_controls(report)), state, profile,
        quota_limit, report, routes, session, slot)
    case False{}:
      Denied{state, UnsupportedFamily{}}

# Implementation helper, step 2.
def a_inventory(inventory: Fact, +state: State, +profile: Profile, quota_limit: Nat,
    +report: TargetReport, +session: Nat, +slot: Nat) -> Step:
  match inventory:
    case Inventory{routes}:
      a_families(within(profile_families(profile), report_families(report)), state, profile,
        quota_limit, report, routes, session, slot)
    case _:
      Denied{state, WrongPhase{}}

# Implementation helper, step 1: the input reference must resolve on the
# worker's own session; the stored slot is the resolved entry's.
def a_identity(resolution: I.Resolution, +state: State, profile: Profile, quota_limit: Nat,
    report: TargetReport, inventory: Fact, +session: Nat) -> Step:
  match resolution:
    case I.Unresolved{reason}:
      Denied{state, Identity{reason}}
    case I.Resolved{entry, _}:
      a_inventory(inventory, state, profile, quota_limit, report, session, I.entry_slot(entry))

# Implementation helper, step 0.
def a_gate(ok: Bool, +state: State, profile: Profile, quota_limit: Nat, report: TargetReport,
    inventory: Fact, +session: Nat, +ref: W.Ref, +now: Nat) -> Step:
  match ok:
    case True{}:
      a_identity(I.resolve(identity(state), I.revision(identity(state)), session, ref, now), state,
        profile, quota_limit, report, inventory, session)
    case False{}:
      Denied{state, StaleRevision{}}

# Public entry point, family 2: admit a protected worker domain. `profile` and
# `quota_limit` are the monitor's admitted request; `report` and `inventory`
# are the target's facts; `ref` is the worker's input reference, presented on
# its native `session`, resolved at monitor time `now`. Checks in the
# documented admission order; on acceptance records the worker `Running` and
# returns exactly `[DeliverInputs{worker, slot}]`.
def admit_worker(+state: State, expected_revision: Nat, profile: Profile, quota_limit: Nat,
    report: TargetReport, inventory: Fact, +session: Nat, +ref: W.Ref, +now: Nat) -> Step:
  a_gate(current(state, expected_revision), state, profile, quota_limit, report, inventory, session,
    ref, now)

# Implementation helper: one worker's use after a charge.
def charged_one(ok: Bool, worker: Worker, amount: Nat) -> Worker:
  match ok worker:
    case True{} Worker{id, session, slot, profile, phase, quota_limit, quota_used}:
      Worker{id, session, slot, profile, phase, quota_limit, Nat.add(quota_used, amount)}
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
    case State{revision, identity, workers, next_worker}:
      State{1n+revision, identity, charged(workers, id, amount), next_worker}

# Implementation helper: charge's quota step.
def c_quota(ok: Bool, +state: State, +id: Nat, +amount: Nat) -> Step:
  match ok:
    case True{}:
      Admitted{commit_charge(state, id, amount), []}
    case False{}:
      Denied{state, QuotaExhausted{}}

# Implementation helper: charge's phase step.
def c_phase(ok: Bool, +state: State, +worker: Worker, +amount: Nat) -> Step:
  match ok:
    case True{}:
      c_quota(Nat.is_le(Nat.add(worker_quota_used(worker), amount), worker_quota_limit(worker)), state,
        worker_id(worker), amount)
    case False{}:
      Denied{state, WrongPhase{}}

# Implementation helper: charge's worker lookup.
def c_worker(found: WorkerLookup, +state: State, +amount: Nat) -> Step:
  match found:
    case OneWorker{+worker}:
      c_phase(is_running(worker_phase(worker)), state, worker, amount)
    case _:
      Denied{state, UnknownWorker{}}

# Implementation helper: charge's fact step.
def c_fact(fact: Fact, +state: State) -> Step:
  match fact:
    case ResourceRequest{+worker, amount}:
      c_worker(worker_at(workers(state), worker), state, amount)
    case _:
      Denied{state, WrongPhase{}}

# Implementation helper: charge's revision gate.
def c_gate(ok: Bool, +state: State, fact: Fact) -> Step:
  match ok:
    case True{}:
      c_fact(fact, state)
    case False{}:
      Denied{state, StaleRevision{}}

# Public entry point, family 2: a `ResourceRequest` from a running worker.
# Order: revision, fact variant, worker (exactly one with that id, else
# UnknownWorker), phase `Running`, then `quota_used + amount <= quota_limit`
# (else QuotaExhausted). Acceptance adds the amount to `quota_used` and
# nothing else: no rights, phase, slot, or identity change, and no effect.
def charge(+state: State, expected_revision: Nat, fact: Fact) -> Step:
  c_gate(current(state, expected_revision), state, fact)

# Implementation helper: diagnostic's sink step. Only a non-public emission
# is accepted, and it yields no effect.
def g_public(public: Bool, +state: State) -> Step:
  match public:
    case False{}:
      Admitted{advanced(state), []}
    case True{}:
      Denied{state, DiagnosticSink{}}

# Implementation helper: diagnostic's phase step.
def g_phase(ok: Bool, +state: State, public: Bool) -> Step:
  match ok:
    case True{}:
      g_public(public, state)
    case False{}:
      Denied{state, WrongPhase{}}

# Implementation helper: diagnostic's worker lookup.
def g_worker(found: WorkerLookup, +state: State, public: Bool) -> Step:
  match found:
    case OneWorker{worker}:
      g_phase(is_running(worker_phase(worker)), state, public)
    case _:
      Denied{state, UnknownWorker{}}

# Implementation helper: diagnostic's fact step.
def g_fact(fact: Fact, +state: State) -> Step:
  match fact:
    case Diagnostic{+worker, public}:
      g_worker(worker_at(workers(state), worker), state, public)
    case _:
      Denied{state, WrongPhase{}}

# Implementation helper: diagnostic's revision gate.
def g_gate(ok: Bool, +state: State, fact: Fact) -> Step:
  match ok:
    case True{}:
      g_fact(fact, state)
    case False{}:
      Denied{state, StaleRevision{}}

# Public entry point, family 2: a `Diagnostic` from a running worker. Order:
# revision, fact variant, worker, phase `Running`, then a public emission is
# denied DiagnosticSink. A non-public emission is accepted with no effect
# (the revision advances; nothing else changes).
def diagnostic(+state: State, expected_revision: Nat, fact: Fact) -> Step:
  g_gate(current(state, expected_revision), state, fact)

# Implementation helper: native_write_offered's fact step. There is no
# accepting branch.
def n_fact(fact: Fact, +state: State) -> Step:
  match fact:
    case NativeWriteOffered{_}:
      Denied{state, FastPathUnavailable{}}
    case _:
      Denied{state, WrongPhase{}}

# Implementation helper: native_write_offered's revision gate.
def n_gate(ok: Bool, +state: State, fact: Fact) -> Step:
  match ok:
    case True{}:
      n_fact(fact, state)
    case False{}:
      Denied{state, StaleRevision{}}

# Public entry point, family 2: a `NativeWriteOffered` fact. Every worker here
# runs protected work, and a native write route lacks the complete Bend
# authorization result bound to an artifact, so the offer is always denied
# FastPathUnavailable (after the revision and fact-variant checks).
def native_write_offered(+state: State, expected_revision: Nat, fact: Fact) -> Step:
  n_gate(current(state, expected_revision), state, fact)

# --- Family 3: artifacts (Task 4) -----------------------------------------------

# --- Family 4: publication (Task 4) ---------------------------------------------

# --- Family 5: revocation (Task 4) ----------------------------------------------
