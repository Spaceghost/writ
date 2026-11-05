import Base
import ./HostPrimitives.bend as P
import ./HostIdentity.bend as I
import ./HostWire.bend as W
import ./Frontend.bend as F
import ./Transfer.bend as T
import ./TransferTests.bend as TF
import ./HostIdentityTests.bend as IT
import ./Test.bend as Test

# Scenario tests for the portable host primitives (HostPrimitives.bend), task
# 1.3 of the add-portable-host-contract change: family 1 (session binding)
# and family 2 (worker domains), for PH-001 "One policy implementation across
# hosts", PH-006 "Required confinement precedes plaintext", PH-007 "Quotas and
# observable channels are bounded", and the model part of PH-014
# "Unisolated accelerators cannot access protected state". Task 4 extends
# this module with families 3 to 5. One named check per outcome.
#
# Every fixture here is SYNTHETIC MONITOR STATE, not authentication. The
# callers, session evidence, target reports, route inventories, resource
# requests, and diagnostics below stand in for what a real binding would
# report from native facts; the configured profile table stands in for the
# monitor's negotiated profiles; the plan is the synthetic TransferTests
# fixture; the hand-built states exist only to reach denial paths no
# transition produces. Nothing here authenticates a session, confines a
# worker, or enforces a quota natively.
#
# Every denial is checked with `denied`: exactly the expected reason, full
# state equality with its input (identity table included, through
# HostIdentityTests' equality helpers), and no effects.
#
# Not tested here, by nature: that a binding reports its complete native
# inventory and true delegability, removes or mediates routes, enforces
# quotas, and isolates devices natively, that it names only the admitted
# request's profile id, and that it executes only effects this monitor
# returned (section 2 host obligations).

# --- Identities and amounts (synthetic) ------------------------------------------
#
# Every value below is distinct from every value of another field: host 51,
# incarnation 73, subjects 31 to 33, sessions 300 to 302 (and 309 never
# bound), slots 21 and 22, handle 61, rights 7, 6, 4, 2, 1 (requests), times
# 120, 170, and 400, profile ids 399, 402, 403, 404, 405, 406 (and 408 never
# configured), worker ids 80 to 83 (and 89 never admitted), quota 500 with
# charges 200, 300, and 301, the claimed subject 33, route kinds 91 to 94,
# operation code 9 outside the wire's set, delegation lifetime 10.

def host_id() -> Nat:
  51n

def incarnation_id() -> Nat:
  73n

def subject_client() -> Nat:
  31n

def subject_supervisor() -> Nat:
  32n

# A subject a wire message claims; no session is bound for it.
def subject_claimed() -> U32:
  33

def caller_client() -> F.Caller:
  F.Caller{subject_client(), TF.code()}

# The worker session's caller: the client's subject with another token, so
# delegation to it is admitted while its own caller differs from the owner's.
def caller_worker() -> F.Caller:
  F.Caller{subject_client(), TF.other_code()}

def caller_supervisor() -> F.Caller:
  F.Caller{subject_supervisor(), TF.code()}

# Session ids: the seeded supervisor 300, then the delegable client 301 and
# the non-delegable worker 302 in bind order; 309 is never bound.
def session_supervisor() -> Nat:
  300n

def session_client() -> Nat:
  301n

def session_worker() -> Nat:
  302n

def session_unknown() -> Nat:
  309n

def handle_client() -> Nat:
  61n

# The seeded slot counter: the client's root is 21, the worker's input 22.
def seed_slot() -> Nat:
  21n

def root_slot() -> Nat:
  21n

def input_slot() -> Nat:
  22n

# The root holds read, write, and execute; the worker's input execute only.
def root_rights() -> U32:
  7

def input_rights() -> U32:
  4

# Requested rights: execute plus write (wider than the input), write only,
# and read only.
def wide_request() -> U32:
  6

def write_request() -> U32:
  2

def read_request() -> U32:
  1

def now() -> Nat:
  120n

def root_expires() -> Nat:
  400n

def input_lifetime() -> Nat:
  50n

# now + input_lifetime: the input's exclusive expiry.
def input_expires() -> Nat:
  170n

# Worker ids: the seeded counter makes the first admitted worker 81; 80 and
# 82 appear only in hand-built states.
def seed_worker() -> Nat:
  81n

def worker_id() -> Nat:
  81n

def other_worker() -> Nat:
  82n

def earlier_worker() -> Nat:
  80n

def next_worker_after() -> Nat:
  82n

def next_worker_two() -> Nat:
  83n

def worker_unknown() -> Nat:
  89n

def quota_limit() -> Nat:
  500n

def first_charge() -> Nat:
  200n

def exact_charge() -> Nat:
  300n

def excess_charge() -> Nat:
  301n

def used_after_first() -> Nat:
  200n

def used_at_limit() -> Nat:
  500n

def unknown_operation() -> U32:
  9

def delegate_lifetime() -> U32:
  10

# --- Families, controls, profiles, and reports -----------------------------------

def every_control() -> U32:
  (P.control_address_isolation() .|. P.control_no_ambient_network() .|. P.control_output_mediation()
    .|. P.control_quota() .|. P.control_no_inherited_routes() .|. P.control_accelerator_isolation() : U32)

def cpu_controls() -> U32:
  (P.control_address_isolation() .|. P.control_no_ambient_network() .|. P.control_output_mediation()
    .|. P.control_quota() .|. P.control_no_inherited_routes() : U32)

def lower_families() -> U32:
  (P.family_session() .|. P.family_worker() : U32)

def lower_controls() -> U32:
  (P.control_address_isolation() .|. P.control_no_ambient_network() : U32)

def without(+mask: U32, +bit: U32) -> U32:
  (mask .^. bit : U32)

# Profile ids of the monitor's configured table, and one never configured.
def accel_id() -> Nat:
  403n

def cpu_id() -> Nat:
  402n

def lower_id() -> Nat:
  399n

def bare_accel_id() -> Nat:
  404n

def no_worker_id() -> Nat:
  405n

def no_control_id() -> Nat:
  406n

def unknown_profile_id() -> Nat:
  408n

# Accelerator work requiring every control; CPU work requiring every control
# but accelerator isolation; a lower profile requiring two families and two
# controls; an accelerator profile that does not list the isolation control;
# a profile not listing the worker family; and one requiring no control.
def accel_profile() -> P.Profile:
  P.Profile{accel_id(), P.all_families(), every_control(), P.Accelerator{}}

def cpu_profile() -> P.Profile:
  P.Profile{cpu_id(), P.all_families(), cpu_controls(), P.Cpu{}}

def lower_profile() -> P.Profile:
  P.Profile{lower_id(), lower_families(), lower_controls(), P.Cpu{}}

def bare_accel_profile() -> P.Profile:
  P.Profile{bare_accel_id(), P.all_families(), cpu_controls(), P.Accelerator{}}

def no_worker_profile() -> P.Profile:
  P.Profile{no_worker_id(), without(P.all_families(), P.family_worker()), every_control(), P.Cpu{}}

def no_control_profile() -> P.Profile:
  P.Profile{no_control_id(), P.all_families(), P.no_controls(), P.Cpu{}}

def configured(+profile: P.Profile) -> P.Configured:
  P.Configured{profile, quota_limit()}

# The monitor's configured profile table.
def table() -> P.Profiles:
  P.Profiles{configured(accel_profile()), P.Profiles{configured(cpu_profile()),
    P.Profiles{configured(lower_profile()), P.Profiles{configured(bare_accel_profile()),
      P.Profiles{configured(no_worker_profile()), P.Profiles{configured(no_control_profile()), P.NoProfiles{}}}}}}}

# Hand-built: a table naming profile 403 twice.
def doubled_table() -> P.Profiles:
  P.Profiles{configured(accel_profile()), P.Profiles{configured(accel_profile()), P.NoProfiles{}}}

def full_report() -> P.TargetReport:
  P.TargetReport{P.all_families(), every_control()}

# A target with every control but accelerator isolation.
def cpu_report() -> P.TargetReport:
  P.TargetReport{P.all_families(), cpu_controls()}

def missing_report(+bit: U32) -> P.TargetReport:
  P.TargetReport{P.all_families(), without(every_control(), bit)}

def no_publication_report() -> P.TargetReport:
  P.TargetReport{without(P.all_families(), P.family_publication()), every_control()}

# The facts a target reports when it meets only the lower profile.
def lower_report() -> P.TargetReport:
  P.TargetReport{lower_families(), lower_controls()}

def no_session_report() -> P.TargetReport:
  P.TargetReport{without(P.all_families(), P.family_session()), every_control()}

# --- Inventories (synthetic route facts) -----------------------------------------

def route_descriptor() -> U32:
  91

def route_handle() -> U32:
  92

def route_shared_memory() -> U32:
  93

def route_service() -> U32:
  94

def mediated_inventory() -> P.Fact:
  P.Inventory{[P.RouteFact{route_descriptor(), True{}}, P.RouteFact{route_handle(), True{}},
    P.RouteFact{route_shared_memory(), True{}}, P.RouteFact{route_service(), True{}}]}

# One inherited shared-memory route left unmediated among mediated ones.
def leaky_inventory() -> P.Fact:
  P.Inventory{[P.RouteFact{route_descriptor(), True{}}, P.RouteFact{route_shared_memory(), False{}},
    P.RouteFact{route_service(), True{}}]}

def leaky_first_inventory() -> P.Fact:
  P.Inventory{[P.RouteFact{route_handle(), False{}}, P.RouteFact{route_service(), True{}}]}

# --- Wire references (descriptions only) ----------------------------------------

def word(n: Nat) -> U32:
  U32.from_nat(n)

def ref_at(slot: Nat) -> W.Ref:
  W.Ref{word(host_id()), word(incarnation_id()), word(slot), word(I.first_generation())}

def root_ref() -> W.Ref:
  ref_at(root_slot())

def input_ref() -> W.Ref:
  ref_at(input_slot())

def use_of(+ref: W.Ref, +operation: U32, +rights: U32) -> W.Message:
  W.Use{ref, operation, rights, W.ClaimedSubject{subject_claimed()}}

# A Use of the client's root claiming another subject.
def claiming_use() -> W.Message:
  use_of(root_ref(), W.operation_execute(), input_rights())

def input_use() -> W.Message:
  use_of(input_ref(), W.operation_execute(), input_rights())

# --- Identity table (built by HostIdentity transitions) --------------------------

def seed_identity() -> I.State:
  I.State{0n, host_id(), incarnation_id(), seed_slot(),
    I.Sessions{I.Session{session_supervisor(), incarnation_id(), caller_supervisor(), I.Authenticated{}, True{}},
      I.NoSessions{}}, I.NoEntries{}}

def client_evidence() -> P.Fact:
  P.SessionEvidence{caller_client(), I.Authenticated{}, True{}}

def nondelegable_client_evidence() -> P.Fact:
  P.SessionEvidence{caller_client(), I.Authenticated{}, False{}}

def worker_evidence() -> P.Fact:
  P.SessionEvidence{caller_worker(), I.Authenticated{}, False{}}

# The worker's evidence claiming the session may delegate.
def claiming_worker_evidence() -> P.Fact:
  P.SessionEvidence{caller_worker(), I.Authenticated{}, True{}}

# The client session as HostIdentity binds it directly (the expected result).
def direct_client() -> I.State:
  I.Change.state(I.bind_session(seed_identity(), I.revision(seed_identity()), caller_client(),
    I.Authenticated{}, True{}))

def seed_state() -> P.State:
  P.State{0n, seed_identity(), table(), P.NoBindings{}, P.NoWorkers{}, seed_worker()}

# The monitor opens the client session (301) and then the worker session
# (302) under the accelerator profile.
def opened_client() -> P.State:
  P.Step.state(P.open_session(seed_state(), P.revision(seed_state()), full_report(), client_evidence(), P.ClientRole{}))

def open_worker(+evidence: P.Fact) -> P.State:
  P.Step.state(P.open_session(opened_client(), P.revision(opened_client()), full_report(), evidence,
    P.WorkerRole{accel_id()}))

def opened_worker() -> P.State:
  open_worker(worker_evidence())

def with_client() -> I.State:
  P.identity(opened_client())

def with_worker() -> I.State:
  P.identity(opened_worker())

def root_on(+table: I.State) -> I.State:
  I.Change.state(I.mint(table, I.revision(table), session_client(), handle_client(),
    TF.plan(), root_rights(), root_expires()))

# The client delegates a narrowed input entry to the worker session.
def input_on(+table: I.State) -> I.State:
  I.Change.state(I.delegate(root_on(table), I.revision(root_on(table)), session_client(), root_ref(),
    session_worker(), input_rights(), input_lifetime(), now()))

def with_input() -> I.State:
  input_on(with_worker())

# The same table after the monitor retired the worker's input.
def with_input_retired() -> I.State:
  I.Change.state(I.retire(with_input(), I.revision(with_input()), input_slot()))

# --- Primitive states ---------------------------------------------------------------

# The worker session bound under configured profile `profile`, as
# `open_session` with `WorkerRole{profile}` records it.
def binding_for(+profile: Nat) -> P.Bindings:
  P.Bindings{P.Binding{session_worker(), profile}, P.NoBindings{}}

def worker_binding() -> P.Bindings:
  binding_for(accel_id())

# The input table with the worker session bound under `profile`. The binding
# for the accelerator profile is the one `open_session` recorded
# (`opened_worker()`); the others are the same shape for other profiles.
def base_under(+profile: Nat) -> P.State:
  P.State{0n, with_input(), table(), binding_for(profile), P.NoWorkers{}, seed_worker()}

def base() -> P.State:
  base_under(accel_id())

def admit_on(+state: P.State, +report: P.TargetReport, +inventory: P.Fact) -> P.Step:
  P.admit_worker(state, P.revision(state), report, inventory, session_worker(), input_ref(), now())

# An admission on the worker session bound under `profile`.
def admit(+profile: Nat, +report: P.TargetReport, +inventory: P.Fact) -> P.Step:
  admit_on(base_under(profile), report, inventory)

def worker_as(+id: Nat, +input: W.Ref, +profile: P.Profile, +phase: P.Phase, +used: Nat) -> P.Worker:
  P.Worker{id, session_worker(), input, profile, phase, quota_limit(), used}

def expected_worker(+profile: P.Profile, +phase: P.Phase, +used: Nat) -> P.Worker:
  worker_as(worker_id(), input_ref(), profile, phase, used)

# The state one admission under `profile` commits from `base()`.
def after_admit(+profile: P.Profile) -> P.State:
  P.State{1n, with_input(), table(), binding_for(P.profile_id(profile)), P.Workers{expected_worker(profile, P.Running{}, P.no_usage()), P.NoWorkers{}},
    next_worker_after()}

def admitted() -> P.State:
  P.Step.state(admit(accel_id(), full_report(), mediated_inventory()))

def charge(+state: P.State, +fact: P.Fact) -> P.Step:
  P.charge(state, P.revision(state), fact, now())

def charged() -> P.State:
  P.Step.state(charge(admitted(), P.ResourceRequest{worker_id(), first_charge()}))

def diagnose(+state: P.State, +fact: P.Fact) -> P.Step:
  P.diagnostic(state, P.revision(state), fact, now())

def one_worker(+identity: I.State, +worker: P.Worker) -> P.State:
  P.State{1n, identity, table(), worker_binding(), P.Workers{worker, P.NoWorkers{}}, next_worker_after()}

# A second worker session (303) opened under the CPU profile after the first,
# then the input delegated to the first; both bindings are recorded.
def opened_two_workers() -> P.State:
  P.Step.state(P.open_session(opened_worker(), P.revision(opened_worker()), full_report(), worker_evidence(),
    P.WorkerRole{cpu_id()}))

def two_bound() -> P.State:
  P.State{0n, input_on(P.identity(opened_two_workers())), table(), P.bindings(opened_two_workers()), P.NoWorkers{},
    seed_worker()}

# The input table with no worker binding: session 302 is non-delegable but
# was not opened as a worker session.
def unbound() -> P.State:
  P.State{0n, with_input(), table(), P.NoBindings{}, P.NoWorkers{}, seed_worker()}

# Hand-built: the input already occupied by worker 81, with the worker
# session bound under the profile not listing the worker family.
def occupied_unprotected() -> P.State:
  P.State{1n, with_input(), table(), binding_for(no_worker_id()), P.Workers{expected_worker(accel_profile(),
    P.Running{}, P.no_usage()), P.NoWorkers{}}, next_worker_after()}

# Hand-built: the admitted worker in phase Revoked, having used 200 units.
def revoked() -> P.State:
  one_worker(with_input(), expected_worker(accel_profile(), P.Revoked{}, used_after_first()))

# Hand-built: the admitted worker in phase Prepared.
def prepared() -> P.State:
  one_worker(with_input(), expected_worker(accel_profile(), P.Prepared{}, P.no_usage()))

# The admitted worker after the monitor retired its input entry.
def retired() -> P.State:
  one_worker(with_input_retired(), expected_worker(accel_profile(), P.Running{}, P.no_usage()))

# Hand-built: a worker recorded on the client's root slot, so the root is
# occupied while its holder (the client) is delegable.
def root_occupied() -> P.State:
  one_worker(with_input(), worker_as(worker_id(), root_ref(), accel_profile(), P.Running{}, P.no_usage()))

# Hand-built: the input's earlier worker 80 was reclaimed.
def reclaimed_input() -> P.State:
  P.State{0n, with_input(), table(), worker_binding(), P.Workers{worker_as(earlier_worker(), input_ref(), accel_profile(),
    P.Reclaimed{}, P.no_usage()), P.NoWorkers{}}, seed_worker()}

# Hand-built: a reclaimed worker 80 and a running worker 81 on one input.
def reclaimed_and_running() -> P.State:
  P.State{1n, with_input(), table(), worker_binding(), P.Workers{expected_worker(accel_profile(), P.Running{}, P.no_usage()),
    P.Workers{worker_as(earlier_worker(), input_ref(), accel_profile(), P.Reclaimed{}, P.no_usage()),
      P.NoWorkers{}}}, next_worker_after()}

# Hand-built: the reclaimed worker 80 listed before the running worker 81, both
# on the input.
def running_after_reclaimed() -> P.State:
  P.State{1n, with_input(), table(), worker_binding(), P.Workers{worker_as(earlier_worker(), input_ref(), accel_profile(),
    P.Reclaimed{}, P.no_usage()), P.Workers{expected_worker(accel_profile(), P.Running{}, P.no_usage()),
      P.NoWorkers{}}}, next_worker_after()}

# What admitting worker 82 on the input commits from `root_occupied()`.
def root_and_input() -> P.State:
  P.State{2n, with_input(), table(), worker_binding(), P.Workers{worker_as(other_worker(), input_ref(), accel_profile(), P.Running{},
    P.no_usage()), P.Workers{worker_as(worker_id(), root_ref(), accel_profile(), P.Running{}, P.no_usage()),
      P.NoWorkers{}}}, next_worker_two()}

# --- Hand-built states that fail `valid` (synthetic) ------------------------------

# An identity table with a child wider than its parent (HostIdentityTests).
def invalid_identity() -> P.State:
  P.State{0n, IT.widened_child(), table(), P.NoBindings{}, P.NoWorkers{}, seed_worker()}

def zero_worker() -> P.State:
  P.State{1n, with_input(), table(), worker_binding(), P.Workers{worker_as(0n, input_ref(), accel_profile(), P.Running{},
    P.no_usage()), P.NoWorkers{}}, next_worker_after()}

# next_worker (50) does not exceed the worker id (81).
def unallocated_worker() -> P.State:
  P.State{1n, with_input(), table(), worker_binding(), P.Workers{expected_worker(accel_profile(), P.Running{}, P.no_usage()),
    P.NoWorkers{}}, 50n}

def duplicated() -> P.State:
  P.State{1n, with_input(), table(), worker_binding(), P.Workers{expected_worker(accel_profile(), P.Running{}, P.no_usage()),
    P.Workers{worker_as(worker_id(), root_ref(), cpu_profile(), P.Running{}, P.no_usage()), P.NoWorkers{}}},
    next_worker_after()}

def shared_input() -> P.State:
  P.State{1n, with_input(), table(), worker_binding(), P.Workers{expected_worker(accel_profile(), P.Running{}, P.no_usage()),
    P.Workers{worker_as(other_worker(), input_ref(), cpu_profile(), P.Running{}, P.no_usage()), P.NoWorkers{}}},
    next_worker_two()}

def with_bindings(+bindings: P.Bindings) -> P.State:
  P.State{0n, with_input(), table(), bindings, P.NoWorkers{}, seed_worker()}

def bound_unknown_session() -> P.State:
  with_bindings(P.Bindings{P.Binding{session_unknown(), accel_id()}, P.NoBindings{}})

def bound_delegable_session() -> P.State:
  with_bindings(P.Bindings{P.Binding{session_client(), accel_id()}, P.NoBindings{}})

def bound_twice() -> P.State:
  with_bindings(P.Bindings{P.Binding{session_worker(), accel_id()}, P.Bindings{P.Binding{session_worker(), cpu_id()}, P.NoBindings{}}})

def bound_unconfigured() -> P.State:
  with_bindings(binding_for(unknown_profile_id()))

def doubled_profiles() -> P.State:
  P.State{0n, with_input(), doubled_table(), P.NoBindings{}, P.NoWorkers{}, seed_worker()}

# --- Equality helpers ---------------------------------------------------------------

def backend_equal(a: P.Backend, b: P.Backend) -> Bool:
  match a b:
    case P.Cpu{} P.Cpu{}:
      True{}
    case P.Accelerator{} P.Accelerator{}:
      True{}
    case _ _:
      False{}

def profile_equal(a: P.Profile, b: P.Profile) -> Bool:
  match a b:
    case P.Profile{ai, af, ac, ab} P.Profile{bi, bf, bc, bb}:
      Nat.is_eq(ai, bi) && U32.is_eq(af, bf) && U32.is_eq(ac, bc) && backend_equal(ab, bb)

def configured_equal(a: P.Configured, b: P.Configured) -> Bool:
  match a b:
    case P.Configured{ap, aq} P.Configured{bp, bq}:
      profile_equal(ap, bp) && Nat.is_eq(aq, bq)

def profiles_equal(a: P.Profiles, b: P.Profiles) -> Bool:
  match a b:
    case P.NoProfiles{} P.NoProfiles{}:
      True{}
    case P.Profiles{ah, at} P.Profiles{bh, bt}:
      configured_equal(ah, bh) && profiles_equal(at, bt)
    case _ _:
      False{}

def phase_equal(a: P.Phase, b: P.Phase) -> Bool:
  match a b:
    case P.Prepared{} P.Prepared{}:
      True{}
    case P.Running{} P.Running{}:
      True{}
    case P.Revoked{} P.Revoked{}:
      True{}
    case P.Quiesced{} P.Quiesced{}:
      True{}
    case P.Reclaimed{} P.Reclaimed{}:
      True{}
    case _ _:
      False{}

def worker_equal(a: P.Worker, b: P.Worker) -> Bool:
  match a b:
    case P.Worker{ai, as, al, ap, ah, aq, au} P.Worker{bi, bs, bl, bp, bh, bq, bu}:
      Nat.is_eq(ai, bi) && Nat.is_eq(as, bs) && W.Ref.equal(al, bl) && profile_equal(ap, bp)
        && phase_equal(ah, bh) && Nat.is_eq(aq, bq) && Nat.is_eq(au, bu)

def workers_equal(a: P.Workers, b: P.Workers) -> Bool:
  match a b:
    case P.NoWorkers{} P.NoWorkers{}:
      True{}
    case P.Workers{ah, at} P.Workers{bh, bt}:
      worker_equal(ah, bh) && workers_equal(at, bt)
    case _ _:
      False{}

def binding_equal(a: P.Binding, b: P.Binding) -> Bool:
  match a b:
    case P.Binding{as, ap} P.Binding{bs, bp}:
      Nat.is_eq(as, bs) && Nat.is_eq(ap, bp)

def bindings_equal(a: P.Bindings, b: P.Bindings) -> Bool:
  match a b:
    case P.NoBindings{} P.NoBindings{}:
      True{}
    case P.Bindings{ah, at} P.Bindings{bh, bt}:
      binding_equal(ah, bh) && bindings_equal(at, bt)
    case _ _:
      False{}

def state_equal(a: P.State, b: P.State) -> Bool:
  match a b:
    case P.State{ar, ai, ap, ab, aw, an} P.State{br, bi, bp, bb, bw, bn}:
      Nat.is_eq(ar, br) && IT.state_equal(ai, bi) && profiles_equal(ap, bp) && bindings_equal(ab, bb)
        && workers_equal(aw, bw)
        && Nat.is_eq(an, bn)

# Task 4 adds effect variants; each then needs its own arm here.
def effect_equal(a: P.Effect, b: P.Effect) -> Bool:
  match a b:
    case P.DeliverInputs{aw, ai} P.DeliverInputs{bw, bi}:
      Nat.is_eq(aw, bw) && W.Ref.equal(ai, bi)

def effects_equal(a: +List<P.Effect>, b: +List<P.Effect>) -> Bool:
  match a b:
    case Nil{} Nil{}:
      True{}
    case Con{ah, at} Con{bh, bt}:
      effect_equal(ah, bh) && effects_equal(at, bt)
    case _ _:
      False{}

# --- Result helpers -----------------------------------------------------------------

# No effect for the target to execute.
def silent(+step: P.Step) -> Bool:
  effects_equal(P.Step.effects(step), [])

# A denial with exactly `reason` that hands back `input` unchanged and emits
# nothing.
def denied(+step: P.Step, input: P.State, reason: P.Error) -> Bool:
  match step:
    case P.Denied{state, got}:
      P.Error.equal(got, reason) && state_equal(state, input) && silent(step)
    case P.Admitted{_, _}:
      False{}

# A denial reporting exactly HostIdentity's `reason`, compared directly rather
# than through `P.Error.equal`, with the input state and no effects.
def denied_identity(+step: P.Step, input: P.State, reason: I.Error) -> Bool:
  match step:
    case P.Denied{state, P.Identity{got}}:
      I.Error.equal(got, reason) && state_equal(state, input) && silent(step)
    case _:
      False{}

# An admitted step whose state is `expected` and whose effects are `effects`.
def admitted_as(+step: P.Step, expected: P.State, effects: +List<P.Effect>) -> Bool:
  match step:
    case P.Admitted{state, got}:
      state_equal(state, expected) && effects_equal(got, effects)
    case P.Denied{_, _}:
      False{}

# A use granted with effective caller `caller`.
def granted_as(result: P.UseResult, caller: F.Caller) -> Bool:
  match result:
    case P.Granted{_, got}:
      IT.caller_equal(got, caller)
    case P.Refused{_}:
      False{}

def refused(result: P.UseResult, reason: P.Error) -> Bool:
  match result:
    case P.Refused{got}:
      P.Error.equal(got, reason)
    case P.Granted{_, _}:
      False{}

def refused_identity(result: P.UseResult, reason: I.Error) -> Bool:
  match result:
    case P.Refused{P.Identity{got}}:
      I.Error.equal(got, reason)
    case _:
      False{}

def identity_rejected(change: I.Change, reason: I.Error) -> Bool:
  match change:
    case I.Rejected{_, got}:
      I.Error.equal(got, reason)
    case I.Accepted{_, _}:
      False{}

def input_rights_of(resolution: I.Resolution) -> Maybe<&2, U32>:
  match resolution:
    case I.Resolved{entry, _}:
      Some{I.entry_rights(entry)}
    case I.Unresolved{_}:
      None{}

# The rights of the input entry the worker holds, read through the table.
def input_entry_rights(+state: P.State) -> Maybe<&2, U32>:
  input_rights_of(I.resolve(P.identity(state), I.revision(P.identity(state)), session_worker(), input_ref(), now()))

def rights_are(found: Maybe<&2, U32>, expected: U32) -> Bool:
  match found:
    case Some{rights}:
      U32.is_eq(rights, expected)
    case None{}:
      False{}

# The single admitted worker's phase.
def only_phase(workers: P.Workers, expected: P.Phase) -> Bool:
  match workers:
    case P.Workers{worker, P.NoWorkers{}}:
      phase_equal(P.worker_phase(worker), expected)
    case _:
      False{}

def delivered() -> +List<P.Effect>:
  [P.DeliverInputs{worker_id(), input_ref()}]

def use_on(+state: P.State, +session: Nat, +message: W.Message) -> P.UseResult:
  P.use(state, P.revision(state), session, message, now())

def only_profile(workers: P.Workers, expected: P.Profile) -> Bool:
  match workers:
    case P.Workers{P.Worker{_, _, _, profile, _, _, _}, P.NoWorkers{}}:
      profile_equal(profile, expected)
    case _:
      False{}

# The single worker's profile after an admitted step.
def admitted_under(+step: P.Step, expected: P.Profile) -> Bool:
  match step:
    case P.Admitted{state, effects}:
      effects_equal(effects, delivered()) && only_profile(P.workers(state), expected)
    case P.Denied{_, _}:
      False{}

# --- Checks -------------------------------------------------------------------------

def missing_control(+bit: U32) -> Bool:
  denied(admit(accel_id(), missing_report(bit), mediated_inventory()), base_under(accel_id()), P.MissingControl{})

# Accepted admissions (PH-006, PH-014).
def accept_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(admitted_as(admit(accel_id(), full_report(), mediated_inventory()), after_admit(accel_profile()), delivered()),
      "PH-006 an admission with every control established records the worker Running and delivers only its input reference")
    Test.check(admitted_as(admit(cpu_id(), cpu_report(), mediated_inventory()), after_admit(cpu_profile()), delivered()),
      "PH-014 a CPU admission without accelerator isolation records backend Cpu")
    Test.check(admitted_as(admit(lower_id(), lower_report(), mediated_inventory()), after_admit(lower_profile()), delivered()),
      "PH-006 the lower report meets the lower profile when that profile is the admitted one")
    Test.check(admitted_as(admit(bare_accel_id(), full_report(), mediated_inventory()), after_admit(bare_accel_profile()), delivered()),
      "PH-014 the same accelerator profile is admitted once isolation is established")
    Test.check(admitted_as(admit_on(reclaimed_input(), full_report(), mediated_inventory()), reclaimed_and_running(), delivered()),
      "PH-006 an input whose earlier worker was reclaimed admits a new worker")

# Each control bit missing alone (PH-006 "A required kernel feature is missing").
def control_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(missing_control(P.control_address_isolation()), "PH-006 address isolation missing alone denied MissingControl with no effect")
    Test.check(missing_control(P.control_no_ambient_network()), "PH-006 no ambient network missing alone denied MissingControl with no effect")
    Test.check(missing_control(P.control_output_mediation()), "PH-006 output mediation missing alone denied MissingControl with no effect")
    Test.check(missing_control(P.control_quota()), "PH-006 quota control missing alone denied MissingControl with no effect")
    Test.check(missing_control(P.control_no_inherited_routes()), "PH-006 no inherited routes missing alone denied MissingControl with no effect")
    Test.check(missing_control(P.control_accelerator_isolation()), "PH-006 accelerator isolation missing alone denied MissingControl with no effect")

# The configured profile table (PH-001: no request carries a profile).
def profile_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(denied(admit_on(unbound(), full_report(), mediated_inventory()), unbound(), P.UnknownProfile{}),
      "PH-001 an admission on a non-delegable session with no bound profile denied UnknownProfile")
    Test.check(denied(admit(accel_id(), cpu_report(), mediated_inventory()), base_under(accel_id()), P.MissingControl{})
      && admitted_as(admit(cpu_id(), cpu_report(), mediated_inventory()), after_admit(cpu_profile()), delivered()),
      "PH-001 a later request cannot switch profiles: a session bound under the accelerator profile is denied on a CPU-only report that the CPU profile accepts")
    Test.check(P.valid(two_bound()) && admitted_under(admit_on(two_bound(), full_report(), mediated_inventory()), accel_profile()),
      "PH-001 an admission reads the presenting session's own binding when another worker session is bound under another profile")
    Test.check(denied(admit(no_worker_id(), full_report(), mediated_inventory()), base_under(no_worker_id()), P.MissingControl{}),
      "PH-006 a profile not listing the worker family denied MissingControl with no effect")
    Test.check(denied(admit(no_control_id(), P.TargetReport{P.no_controls(), P.no_controls()}, P.Inventory{[]}), base_under(no_control_id()), P.MissingControl{}),
      "PH-006 a profile requiring no controls admits nothing")

# Target reports cannot lower the monitor's profile (PH-006, PH-001).
def report_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(denied(admit(accel_id(), no_publication_report(), mediated_inventory()), base_under(accel_id()), P.UnsupportedFamily{}),
      "PH-006 a report without the publication family denied UnsupportedFamily with the monitor profile unchanged")
    Test.check(denied(admit(accel_id(), lower_report(), mediated_inventory()), base_under(accel_id()), P.UnsupportedFamily{}),
      "PH-006 a report meeting only a lower profile denied for the admitted profile with the monitor profile unchanged")
    Test.check(denied(admit(cpu_id(), P.TargetReport{P.all_families(), lower_controls()}, mediated_inventory()), base_under(cpu_id()), P.MissingControl{}),
      "PH-006 a report with every family but only the lower profile's controls denied MissingControl")

# Route inventory (PH-006 "An inherited output remains accessible").
def inventory_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(denied(admit(accel_id(), full_report(), leaky_inventory()), base_under(accel_id()), P.UnmediatedRoute{}),
      "PH-006 one unmediated route among mediated ones denied UnmediatedRoute before any DeliverInputs")
    Test.check(denied(admit(accel_id(), full_report(), leaky_first_inventory()), base_under(accel_id()), P.UnmediatedRoute{}),
      "PH-006 an unmediated first route denied UnmediatedRoute")
    Test.check(denied(admit(accel_id(), full_report(), P.NativeWriteOffered{worker_id()}), base_under(accel_id()), P.WrongPhase{}),
      "PH-006 an admission given a fact other than an Inventory denied WrongPhase")

# Accelerators (PH-014 "A shared device heap exposes the original graph").
def accelerator_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(denied(admit(bare_accel_id(), cpu_report(), mediated_inventory()), base_under(bare_accel_id()), P.UnisolatedAccelerator{}),
      "PH-014 an accelerator profile not listing isolation, on a target without it, denied UnisolatedAccelerator and not downgraded")

# The input reference and its session (PH-006, PH-007).
def identity_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(denied_identity(P.admit_worker(base(), P.revision(base()), full_report(),
      mediated_inventory(), session_worker(), root_ref(), now()), base(), I.NotHolder{}),
      "PH-006 an admission presenting an input reference the worker session does not hold denied Identity NotHolder")
    Test.check(denied_identity(P.admit_worker(base(), P.revision(base()), full_report(),
      mediated_inventory(), session_client(), input_ref(), now()), base(), I.NotHolder{}),
      "PH-006 an admission presenting the worker's input reference on the client session denied Identity NotHolder")
    Test.check(denied(P.admit_worker(base(), P.revision(base()), full_report(),
      mediated_inventory(), session_client(), root_ref(), now()), base(), P.DelegableSession{}),
      "PH-007 an admission on a delegable session denied DelegableSession with no effect")
    Test.check(identity_rejected(I.delegate(P.identity(admitted()), I.revision(P.identity(admitted())), session_worker(),
      input_ref(), session_client(), input_rights(), input_lifetime(), now()), I.NotDelegable{}),
      "PH-007 after admission a delegation from the worker session denied NotDelegable")
    Test.check(denied(admit_on(admitted(), full_report(), mediated_inventory()), admitted(), P.SlotOccupied{}),
      "PH-006 a second admission on an occupied input slot denied SlotOccupied with no DeliverInputs")
    Test.check(denied(admit_on(running_after_reclaimed(), full_report(), mediated_inventory()), running_after_reclaimed(), P.SlotOccupied{}),
      "PH-006 an input held by a running worker listed after a reclaimed one denied SlotOccupied")
    Test.check(admitted_as(admit_on(root_occupied(), full_report(), mediated_inventory()), root_and_input(),
      [P.DeliverInputs{other_worker(), input_ref()}]),
      "PH-006 a worker on another slot does not block admission on the input")

# Quotas (PH-007 "A worker exhausts its resource quota").
def quota_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(admitted_as(charge(admitted(), P.ResourceRequest{worker_id(), first_charge()}),
      P.State{2n, with_input(), table(), worker_binding(), P.Workers{expected_worker(accel_profile(), P.Running{}, used_after_first()), P.NoWorkers{}}, next_worker_after()},
      []), "PH-007 a charge within the quota adds only to quota_used and emits nothing")
    Test.check(admitted_as(charge(charged(), P.ResourceRequest{worker_id(), exact_charge()}),
      P.State{3n, with_input(), table(), worker_binding(), P.Workers{expected_worker(accel_profile(), P.Running{}, used_at_limit()), P.NoWorkers{}}, next_worker_after()},
      []), "PH-007 a charge reaching exactly the quota limit is accepted")
    Test.check(denied(charge(charged(), P.ResourceRequest{worker_id(), excess_charge()}), charged(), P.QuotaExhausted{}),
      "PH-007 a charge beyond the quota denied QuotaExhausted with the state unchanged and no effect")
    Test.check(only_phase(P.workers(P.Step.state(charge(charged(), P.ResourceRequest{worker_id(), excess_charge()}))), P.Running{})
      && rights_are(input_entry_rights(P.Step.state(charge(charged(), P.ResourceRequest{worker_id(), excess_charge()}))), input_rights()),
      "PH-007 after exhaustion the worker's phase and its input entry's rights are unchanged")
    Test.check(denied(charge(admitted(), P.ResourceRequest{worker_unknown(), first_charge()}), admitted(), P.UnknownWorker{}),
      "PH-007 a charge for a worker never admitted denied UnknownWorker")
    Test.check(denied(charge(revoked(), P.ResourceRequest{worker_id(), first_charge()}), revoked(), P.WrongPhase{}),
      "PH-007 a charge from a revoked worker denied WrongPhase")
    Test.check(denied(charge(prepared(), P.ResourceRequest{worker_id(), first_charge()}), prepared(), P.WrongPhase{}),
      "PH-007 a charge from a prepared worker denied WrongPhase")
    Test.check(denied(charge(admitted(), P.Diagnostic{worker_id(), False{}}), admitted(), P.WrongPhase{}),
      "PH-007 a charge given a fact other than a ResourceRequest denied WrongPhase")
    Test.check(denied_identity(charge(retired(), P.ResourceRequest{worker_id(), first_charge()}), retired(), I.Retired{}),
      "PH-007 a charge after the worker's input was retired denied Identity Retired")
    Test.check(denied_identity(P.charge(admitted(), P.revision(admitted()), P.ResourceRequest{worker_id(), first_charge()}, input_expires()),
      admitted(), I.Expired{}), "PH-007 a charge at the input's expiry denied Identity Expired")

# Diagnostics (PH-007 "A worker encodes a secret in diagnostics").
def diagnostic_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(denied(diagnose(admitted(), P.Diagnostic{worker_id(), True{}}), admitted(), P.DiagnosticSink{}),
      "PH-007 a public diagnostic from a running worker denied DiagnosticSink")
    Test.check(admitted_as(diagnose(admitted(), P.Diagnostic{worker_id(), False{}}),
      P.State{2n, with_input(), table(), worker_binding(), P.Workers{expected_worker(accel_profile(), P.Running{}, P.no_usage()), P.NoWorkers{}}, next_worker_after()},
      []), "PH-007 a non-public diagnostic is accepted with no effect")
    Test.check(denied(diagnose(admitted(), P.Diagnostic{worker_unknown(), False{}}), admitted(), P.UnknownWorker{}),
      "PH-007 a diagnostic from a worker never admitted denied UnknownWorker")
    Test.check(denied(diagnose(revoked(), P.Diagnostic{worker_id(), False{}}), revoked(), P.WrongPhase{}),
      "PH-007 a diagnostic from a revoked worker denied WrongPhase")
    Test.check(denied(diagnose(admitted(), P.ResourceRequest{worker_id(), first_charge()}), admitted(), P.WrongPhase{}),
      "PH-007 a diagnostic given a fact other than a Diagnostic denied WrongPhase")
    Test.check(denied_identity(diagnose(retired(), P.Diagnostic{worker_id(), False{}}), retired(), I.Retired{}),
      "PH-007 a diagnostic after the worker's input was retired denied Identity Retired")

# Native fast write route (PH-001 "An adapter offers a fast publication route").
def fastpath_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(denied(P.native_write_offered(admitted(), P.revision(admitted()), P.NativeWriteOffered{worker_id()}), admitted(), P.FastPathUnavailable{}),
      "PH-001 a native write offer for an admitted worker denied FastPathUnavailable")
    Test.check(denied(P.native_write_offered(admitted(), P.revision(admitted()), P.Diagnostic{worker_id(), True{}}), admitted(), P.WrongPhase{}),
      "PH-001 a native write offer given another fact denied WrongPhase")

# Session binding (family 1).
def session_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(admitted_as(P.open_session(P.empty(seed_identity(), table()), 0n, full_report(), client_evidence(), P.ClientRole{}),
      P.State{1n, direct_client(), table(), P.NoBindings{}, P.NoWorkers{}, P.first_worker()}, []),
      "PH-002 open_session binds the evidence's caller through HostIdentity with no effect")
    Test.check(denied(P.open_session(P.empty(seed_identity(), table()), 0n, no_session_report(), client_evidence(), P.ClientRole{}), P.empty(seed_identity(), table()), P.UnsupportedFamily{}),
      "PH-001 open_session on a target without the session family denied UnsupportedFamily")
    Test.check(denied_identity(P.open_session(P.empty(seed_identity(), table()), 0n, full_report(), P.SessionEvidence{caller_client(), I.Inherited{session_unknown()}, True{}}, P.ClientRole{}),
      P.empty(seed_identity(), table()), I.UnknownSession{}),
      "PH-002 open_session with evidence inherited from an unbound session denied Identity UnknownSession")
    Test.check(denied(P.open_session(P.empty(seed_identity(), table()), 0n, full_report(), mediated_inventory(), P.ClientRole{}), P.empty(seed_identity(), table()), P.WrongPhase{}),
      "PH-001 open_session given a fact other than SessionEvidence denied WrongPhase")
    Test.check(admitted_as(P.open_session(P.empty(seed_identity(), table()), 0n, full_report(), claiming_worker_evidence(), P.WorkerRole{cpu_id()}),
      P.State{1n, I.Change.state(I.bind_session(seed_identity(), I.revision(seed_identity()), caller_worker(), I.Authenticated{}, False{})),
        table(), P.Bindings{P.Binding{session_client(), cpu_id()}, P.NoBindings{}}, P.NoWorkers{}, P.first_worker()}, []),
      "PH-002 open_session as a worker binds the session non-delegable under its profile even when the target reports it delegable")
    Test.check(identity_rejected(I.delegate(input_on(P.identity(open_worker(claiming_worker_evidence()))),
      I.revision(input_on(P.identity(open_worker(claiming_worker_evidence())))), session_worker(), input_ref(), session_client(),
      input_rights(), input_lifetime(), now()), I.NotDelegable{}),
      "PH-007 a worker session the target reported delegable still cannot delegate")
    Test.check(admitted_as(P.open_session(P.empty(seed_identity(), table()), 0n, full_report(), nondelegable_client_evidence(), P.ClientRole{}),
      P.State{1n, I.Change.state(I.bind_session(seed_identity(), I.revision(seed_identity()), caller_client(), I.Authenticated{}, False{})),
        table(), P.NoBindings{}, P.NoWorkers{}, P.first_worker()}, []),
      "PH-002 a client session the evidence reports non-delegable is bound non-delegable")
    Test.check(denied(P.open_session(P.empty(seed_identity(), table()), 0n, full_report(), worker_evidence(), P.WorkerRole{unknown_profile_id()}),
      P.empty(seed_identity(), table()), P.UnknownProfile{}),
      "PH-001 open_session as a worker under a profile id the monitor has not configured denied UnknownProfile")
    Test.check(denied_identity(P.open_session(P.empty(seed_identity(), table()), 0n, full_report(), P.SessionEvidence{caller_worker(), I.Inherited{session_unknown()}, False{}}, P.WorkerRole{accel_id()}),
      P.empty(seed_identity(), table()), I.UnknownSession{}),
      "PH-002 open_session as a worker with evidence inherited from an unbound session denied Identity UnknownSession")
    Test.check(bindings_equal(P.bindings(opened_worker()), worker_binding()) && IT.state_equal(with_worker(),
      I.Change.state(I.bind_session(direct_client(), I.revision(direct_client()), caller_worker(), I.Authenticated{}, False{}))),
      "PH-002 open_session records the worker session's profile binding used by the fixtures")
    Test.check(P.Error.equal(P.Identity{I.NotHolder{}}, P.Identity{I.NotHolder{}})
      && Bool.not(P.Error.equal(P.Identity{I.NotHolder{}}, P.Identity{I.UnknownSession{}})),
      "PH-001 Error.equal compares the HostIdentity reason inside Identity")

# Use (family 1): identity, rights, operation, message type.
def use_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(granted_as(use_on(base(), session_client(), claiming_use()), caller_client()),
      "PH-002 a Use claiming another subject on the client's session resolves to the client's caller")
    Test.check(granted_as(use_on(base(), session_worker(), input_use()), caller_client()),
      "PH-002 the worker's Use of its input resolves to the owner's caller, not the worker session's")
    Test.check(granted_as(use_on(base(), session_client(), use_of(root_ref(), W.operation_read(), read_request())), caller_client())
      && granted_as(use_on(base(), session_client(), use_of(root_ref(), W.operation_write(), write_request())), caller_client()),
      "PH-002 a read and a write within the root's rights are granted")
    Test.check(refused(use_on(base(), session_worker(), use_of(input_ref(), W.operation_execute(), wide_request())), P.RightsNotHeld{}),
      "PH-002 a Use requesting rights the entry lacks denied RightsNotHeld")
    Test.check(refused(use_on(base(), session_worker(), use_of(input_ref(), W.operation_write(), input_rights())), P.OperationNotPermitted{}),
      "PH-002 a Use for a write outside its requested rights denied OperationNotPermitted")
    Test.check(refused(use_on(base(), session_worker(), use_of(input_ref(), W.operation_read(), input_rights())), P.OperationNotPermitted{}),
      "PH-002 a Use for a read outside its requested rights denied OperationNotPermitted")
    Test.check(refused(use_on(base(), session_client(), use_of(root_ref(), unknown_operation(), root_rights())), P.OperationNotPermitted{}),
      "PH-002 a Use naming an operation outside the wire's set denied OperationNotPermitted")
    Test.check(refused(use_on(base(), session_worker(), W.Delegate{input_ref(), input_rights(), delegate_lifetime(), word(session_client())}), P.WrongPhase{}),
      "PH-001 use given a Delegate message denied WrongPhase")
    Test.check(refused_identity(use_on(base(), session_client(), input_use()), I.NotHolder{}),
      "PH-002 a Use of the worker's input on the client session denied Identity NotHolder")

# Every transition at a stale revision.
def revision_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(denied(P.open_session(P.empty(seed_identity(), table()), 1n+P.revision(P.empty(seed_identity(), table())), full_report(), client_evidence(), P.ClientRole{}), P.empty(seed_identity(), table()), P.StaleRevision{}),
      "PH-001 open_session at a stale revision denied StaleRevision")
    Test.check(refused(P.use(base(), 1n+P.revision(base()), session_client(), claiming_use(), now()), P.StaleRevision{}),
      "PH-001 use at a stale revision denied StaleRevision")
    Test.check(denied(P.admit_worker(base(), 1n+P.revision(base()), full_report(),
      mediated_inventory(), session_worker(), input_ref(), now()), base(), P.StaleRevision{}),
      "PH-006 admit_worker at a stale revision denied StaleRevision")
    Test.check(denied(P.charge(admitted(), 1n+P.revision(admitted()), P.ResourceRequest{worker_id(), first_charge()}, now()), admitted(), P.StaleRevision{}),
      "PH-007 charge at a stale revision denied StaleRevision")
    Test.check(denied(P.diagnostic(admitted(), 1n+P.revision(admitted()), P.Diagnostic{worker_id(), False{}}, now()), admitted(), P.StaleRevision{}),
      "PH-007 diagnostic at a stale revision denied StaleRevision")
    Test.check(denied(P.native_write_offered(admitted(), 1n+P.revision(admitted()), P.NativeWriteOffered{worker_id()}), admitted(), P.StaleRevision{}),
      "PH-001 native_write_offered at a stale revision denied StaleRevision")

# The structural invariants and the valid gate.
def valid_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(P.valid(base()) && P.valid(admitted()) && P.valid(charged()) && P.valid(retired())
      && P.valid(P.Step.state(diagnose(admitted(), P.Diagnostic{worker_id(), False{}})))
      && P.valid(P.Step.state(P.open_session(P.empty(seed_identity(), table()), 0n, full_report(), client_evidence(), P.ClientRole{})))
      && P.valid(reclaimed_and_running()),
      "PH-001 states built by the transitions satisfy valid")
    Test.check(Bool.not(P.valid(invalid_identity())), "PH-001 valid rejects a state whose identity table is not valid")
    Test.check(Bool.not(P.valid(zero_worker())), "PH-001 valid rejects worker id 0")
    Test.check(Bool.not(P.valid(unallocated_worker())), "PH-001 valid rejects a worker id not below next_worker")
    Test.check(Bool.not(P.valid(duplicated())), "PH-001 valid rejects two workers under one id")
    Test.check(Bool.not(P.valid(shared_input())), "PH-006 valid rejects two unreclaimed workers on one input")
    Test.check(Bool.not(P.valid(doubled_profiles())), "PH-001 valid rejects a profile id configured twice")
    Test.check(Bool.not(P.valid(bound_unknown_session())), "PH-001 valid rejects a profile binding for a session not in the identity table")
    Test.check(Bool.not(P.valid(bound_delegable_session())), "PH-007 valid rejects a profile binding for a delegable session")
    Test.check(Bool.not(P.valid(bound_twice())), "PH-001 valid rejects a session bound to two profiles")
    Test.check(Bool.not(P.valid(bound_unconfigured())), "PH-001 valid rejects a binding to a profile id not configured")

# Every transition on a state that fails `valid`.
def gate_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(denied(admit_on(invalid_identity(), full_report(), mediated_inventory()), invalid_identity(), P.StaleRevision{}),
      "PH-006 an admission over an identity table that is not valid denied StaleRevision")
    Test.check(denied(P.open_session(invalid_identity(), P.revision(invalid_identity()), full_report(), client_evidence(), P.ClientRole{}), invalid_identity(), P.StaleRevision{}),
      "PH-001 open_session on a state that is not valid denied StaleRevision")
    Test.check(refused(use_on(invalid_identity(), session_client(), claiming_use()), P.StaleRevision{}),
      "PH-001 use on a state that is not valid denied StaleRevision")
    Test.check(denied(charge(unallocated_worker(), P.ResourceRequest{worker_id(), first_charge()}), unallocated_worker(), P.StaleRevision{}),
      "PH-007 a charge on a state that is not valid denied StaleRevision")
    Test.check(denied(diagnose(duplicated(), P.Diagnostic{worker_id(), False{}}), duplicated(), P.StaleRevision{}),
      "PH-007 a diagnostic on a state that is not valid denied StaleRevision")
    Test.check(denied(P.native_write_offered(shared_input(), P.revision(shared_input()), P.NativeWriteOffered{worker_id()}), shared_input(), P.StaleRevision{}),
      "PH-001 a native write offer on a state that is not valid denied StaleRevision")

# The fixed check orders: each input fails two steps and must report the
# earlier one.
def order_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(denied_identity(P.admit_worker(unbound(), P.revision(unbound()), full_report(),
      mediated_inventory(), session_worker(), root_ref(), now()), unbound(), I.NotHolder{}),
      "PH-001 order: the input reference precedes the bound profile")
    Test.check(denied_identity(P.admit_worker(base_under(no_worker_id()), P.revision(base_under(no_worker_id())), full_report(),
      mediated_inventory(), session_worker(), root_ref(), now()), base_under(no_worker_id()), I.NotHolder{}),
      "PH-006 order: the input reference precedes the protected-profile check")
    Test.check(denied(admit_on(occupied_unprotected(), full_report(), mediated_inventory()), occupied_unprotected(), P.MissingControl{}),
      "PH-006 order: the protected-profile check precedes the occupied slot")
    Test.check(denied(P.admit_worker(root_occupied(), P.revision(root_occupied()), full_report(),
      mediated_inventory(), session_client(), root_ref(), now()), root_occupied(), P.DelegableSession{}),
      "PH-007 order: the delegable session precedes the occupied slot")
    Test.check(denied(admit_on(admitted(), full_report(), P.NativeWriteOffered{worker_id()}), admitted(), P.SlotOccupied{}),
      "PH-006 order: the occupied slot precedes the inventory fact")
    Test.check(denied_identity(P.admit_worker(base(), P.revision(base()), full_report(),
      P.NativeWriteOffered{worker_id()}, session_worker(), root_ref(), now()), base(), I.NotHolder{}),
      "PH-006 order: the input reference precedes the inventory fact")
    Test.check(denied(admit(accel_id(), no_publication_report(), P.NativeWriteOffered{worker_id()}), base_under(accel_id()), P.WrongPhase{}),
      "PH-006 order: the inventory fact precedes the families")
    Test.check(denied(admit(bare_accel_id(), cpu_report(), leaky_inventory()), base_under(bare_accel_id()), P.UnisolatedAccelerator{}),
      "PH-014 order: accelerator isolation precedes the route inventory")
    Test.check(denied(charge(revoked(), P.ResourceRequest{worker_id(), excess_charge()}), revoked(), P.WrongPhase{}),
      "PH-007 order: the worker's phase precedes its quota")
    Test.check(denied_identity(charge(retired(), P.ResourceRequest{worker_id(), excess_charge()}), retired(), I.Retired{}),
      "PH-007 order: the input's re-resolution precedes the quota")
    Test.check(denied(diagnose(revoked(), P.Diagnostic{worker_id(), True{}}), revoked(), P.WrongPhase{}),
      "PH-007 order: the worker's phase precedes the diagnostic sink")
    Test.check(denied_identity(diagnose(retired(), P.Diagnostic{worker_id(), True{}}), retired(), I.Retired{}),
      "PH-007 order: the input's re-resolution precedes the diagnostic sink")
    Test.check(refused(use_on(base(), session_worker(), use_of(input_ref(), W.operation_read(), wide_request())), P.RightsNotHeld{}),
      "PH-002 order: the held rights precede the operation")

# Public entry point, run by Tests.bend. Checks are grouped per requirement and
# fixtures are named functions, keeping each group under the native backend's
# arity limit (see the note above HostBindingTests.main).
def main() -> IO(Unit):
  do IO<Unit>:
    accept_checks()
    control_checks()
    profile_checks()
    report_checks()
    inventory_checks()
    accelerator_checks()
    identity_checks()
    quota_checks()
    diagnostic_checks()
    fastpath_checks()
    session_checks()
    use_checks()
    revision_checks()
    valid_checks()
    gate_checks()
    order_checks()
    IO.print("HostPrimitives: 104 checks passed")
