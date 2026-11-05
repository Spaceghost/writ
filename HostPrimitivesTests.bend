import Base
import ./HostPrimitives.bend as P
import ./HostIdentity.bend as I
import ./HostWire.bend as W
import ./Frontend.bend as F
import ./Transfer.bend as T
import ./TransferTests.bend as TF
import ./HostIdentityTests.bend as IT
import ./Test.bend as Test
import ./HostPublication.bend as H
import ./FacadeTests.bend as FF
import ./BackplaneTests.bend as BF
import ./NegotiationTests.bend as NF
import ./Backplane.bend as B
import ./Ledger.bend as L
import ./Negotiation.bend as N
import ./DataOS.bend as OS

# Scenario tests for the portable host primitives (HostPrimitives.bend), task
# 1.3 of the add-portable-host-contract change: family 1 (session binding)
# and family 2 (worker domains), for PH-001 "One policy implementation across
# hosts", PH-006 "Required confinement precedes plaintext", PH-007 "Quotas and
# observable channels are bounded", and the model part of PH-014
# "Unisolated accelerators cannot access protected state"; and families 3 to
# 5 (HostPublication.bend: sealing, publication with recovery, revocation
# with quiescence) for PH-008 "Artifact sealing excludes all writers", PH-009
# "Publication observes one current authority boundary", and PH-010
# "Revocation includes quiescence and stale completion rejection", with the
# family 1 wrappers `issue` and `delegate`. One named check per outcome.
#
# Every fixture here is SYNTHETIC MONITOR STATE, not authentication. The
# callers, session evidence, target reports, route inventories, resource
# requests, and diagnostics below stand in for what a real binding would
# report from native facts; the configured profile table stands in for the
# monitor's negotiated profiles; the plan is the synthetic TransferTests
# fixture; the Negotiation session, ledger, candidate, DataOS context,
# Frontend descriptor, and Backplane bindings are the synthetic
# NegotiationTests, BackplaneTests, and FacadeTests fixtures; the artifact
# facts, quiescence facts, and completions stand in for native observations;
# the hand-built states exist only to reach denial paths no transition
# produces. Nothing here authenticates a session, confines a worker, enforces
# a quota natively, seals bytes, quiesces a device, or makes a publication
# durable.
#
# Every denial is checked with `denied`: exactly the expected reason, full
# state equality with its input (identity table included, through
# HostIdentityTests' equality helpers), and no effects. Every publication
# refusal is checked with `refused_as`: the reason, full state equality, the
# supplied session's and ledger's revisions unchanged, and no `Publish`.
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
  P.State{0n, seed_identity(), table(), P.NoBindings{}, P.NoWorkers{}, seed_worker(), P.NoSeals{}, P.NoPublications{}}

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
  P.State{0n, with_input(), table(), binding_for(profile), P.NoWorkers{}, seed_worker(), P.NoSeals{}, P.NoPublications{}}

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
    next_worker_after(), P.NoSeals{}, P.NoPublications{}}

def admitted() -> P.State:
  P.Step.state(admit(accel_id(), full_report(), mediated_inventory()))

def charge(+state: P.State, +fact: P.Fact) -> P.Step:
  P.charge(state, P.revision(state), fact, now())

def charged() -> P.State:
  P.Step.state(charge(admitted(), P.ResourceRequest{worker_id(), first_charge()}))

def diagnose(+state: P.State, +fact: P.Fact) -> P.Step:
  P.diagnostic(state, P.revision(state), fact, now())

def one_worker(+identity: I.State, +worker: P.Worker) -> P.State:
  P.State{1n, identity, table(), worker_binding(), P.Workers{worker, P.NoWorkers{}}, next_worker_after(), P.NoSeals{}, P.NoPublications{}}

# A second worker session (303) opened under the CPU profile after the first,
# then the input delegated to the first; both bindings are recorded.
def opened_two_workers() -> P.State:
  P.Step.state(P.open_session(opened_worker(), P.revision(opened_worker()), full_report(), worker_evidence(),
    P.WorkerRole{cpu_id()}))

def two_bound() -> P.State:
  P.State{0n, input_on(P.identity(opened_two_workers())), table(), P.bindings(opened_two_workers()), P.NoWorkers{},
    seed_worker(), P.NoSeals{}, P.NoPublications{}}

# The input table with no worker binding: session 302 is non-delegable but
# was not opened as a worker session.
def unbound() -> P.State:
  P.State{0n, with_input(), table(), P.NoBindings{}, P.NoWorkers{}, seed_worker(), P.NoSeals{}, P.NoPublications{}}

# Hand-built: the input already occupied by worker 81, with the worker
# session bound under the profile not listing the worker family.
def occupied_unprotected() -> P.State:
  P.State{1n, with_input(), table(), binding_for(no_worker_id()), P.Workers{expected_worker(accel_profile(),
    P.Running{}, P.no_usage()), P.NoWorkers{}}, next_worker_after(), P.NoSeals{}, P.NoPublications{}}

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
    P.Reclaimed{}, P.no_usage()), P.NoWorkers{}}, seed_worker(), P.NoSeals{}, P.NoPublications{}}

# Hand-built: a reclaimed worker 80 and a running worker 81 on one input.
def reclaimed_and_running() -> P.State:
  P.State{1n, with_input(), table(), worker_binding(), P.Workers{expected_worker(accel_profile(), P.Running{}, P.no_usage()),
    P.Workers{worker_as(earlier_worker(), input_ref(), accel_profile(), P.Reclaimed{}, P.no_usage()),
      P.NoWorkers{}}}, next_worker_after(), P.NoSeals{}, P.NoPublications{}}

# Hand-built: the reclaimed worker 80 listed before the running worker 81, both
# on the input.
def running_after_reclaimed() -> P.State:
  P.State{1n, with_input(), table(), worker_binding(), P.Workers{worker_as(earlier_worker(), input_ref(), accel_profile(),
    P.Reclaimed{}, P.no_usage()), P.Workers{expected_worker(accel_profile(), P.Running{}, P.no_usage()),
      P.NoWorkers{}}}, next_worker_after(), P.NoSeals{}, P.NoPublications{}}

# What admitting worker 82 on the input commits from `root_occupied()`.
def root_and_input() -> P.State:
  P.State{2n, with_input(), table(), worker_binding(), P.Workers{worker_as(other_worker(), input_ref(), accel_profile(), P.Running{},
    P.no_usage()), P.Workers{worker_as(worker_id(), root_ref(), accel_profile(), P.Running{}, P.no_usage()),
      P.NoWorkers{}}}, next_worker_two(), P.NoSeals{}, P.NoPublications{}}

# --- Hand-built states that fail `valid` (synthetic) ------------------------------

# An identity table with a child wider than its parent (HostIdentityTests).
def invalid_identity() -> P.State:
  P.State{0n, IT.widened_child(), table(), P.NoBindings{}, P.NoWorkers{}, seed_worker(), P.NoSeals{}, P.NoPublications{}}

def zero_worker() -> P.State:
  P.State{1n, with_input(), table(), worker_binding(), P.Workers{worker_as(0n, input_ref(), accel_profile(), P.Running{},
    P.no_usage()), P.NoWorkers{}}, next_worker_after(), P.NoSeals{}, P.NoPublications{}}

# next_worker (50) does not exceed the worker id (81).
def unallocated_worker() -> P.State:
  P.State{1n, with_input(), table(), worker_binding(), P.Workers{expected_worker(accel_profile(), P.Running{}, P.no_usage()),
    P.NoWorkers{}}, 50n, P.NoSeals{}, P.NoPublications{}}

def duplicated() -> P.State:
  P.State{1n, with_input(), table(), worker_binding(), P.Workers{expected_worker(accel_profile(), P.Running{}, P.no_usage()),
    P.Workers{worker_as(worker_id(), root_ref(), cpu_profile(), P.Running{}, P.no_usage()), P.NoWorkers{}}},
    next_worker_after(), P.NoSeals{}, P.NoPublications{}}

def shared_input() -> P.State:
  P.State{1n, with_input(), table(), worker_binding(), P.Workers{expected_worker(accel_profile(), P.Running{}, P.no_usage()),
    P.Workers{worker_as(other_worker(), input_ref(), cpu_profile(), P.Running{}, P.no_usage()), P.NoWorkers{}}},
    next_worker_two(), P.NoSeals{}, P.NoPublications{}}

def with_bindings(+bindings: P.Bindings) -> P.State:
  P.State{0n, with_input(), table(), bindings, P.NoWorkers{}, seed_worker(), P.NoSeals{}, P.NoPublications{}}

def bound_unknown_session() -> P.State:
  with_bindings(P.Bindings{P.Binding{session_unknown(), accel_id()}, P.NoBindings{}})

def bound_delegable_session() -> P.State:
  with_bindings(P.Bindings{P.Binding{session_client(), accel_id()}, P.NoBindings{}})

def bound_twice() -> P.State:
  with_bindings(P.Bindings{P.Binding{session_worker(), accel_id()}, P.Bindings{P.Binding{session_worker(), cpu_id()}, P.NoBindings{}}})

def bound_unconfigured() -> P.State:
  with_bindings(binding_for(unknown_profile_id()))

def doubled_profiles() -> P.State:
  P.State{0n, with_input(), doubled_table(), P.NoBindings{}, P.NoWorkers{}, seed_worker(), P.NoSeals{}, P.NoPublications{}}

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

# Families 3 to 5: the sealed and publication records.

def sealed_equal(a: P.Sealed, b: P.Sealed) -> Bool:
  match a b:
    case P.Sealed{aw, ao, av, ad} P.Sealed{bw, bo, bv, bd}:
      Nat.is_eq(aw, bw) && Nat.is_eq(ao, bo) && Nat.is_eq(av, bv) && T.CodeId.equal(ad, bd)

def seals_equal(a: P.Seals, b: P.Seals) -> Bool:
  match a b:
    case P.NoSeals{} P.NoSeals{}:
      True{}
    case P.Seals{ah, at} P.Seals{bh, bt}:
      sealed_equal(ah, bh) && seals_equal(at, bt)
    case _ _:
      False{}

def publication_equal(a: P.Publication, b: P.Publication) -> Bool:
  match a b:
    case P.Publication{ai, ad} P.Publication{bi, bd}:
      Nat.is_eq(ai, bi) && T.CodeId.equal(ad, bd)

def publications_equal(a: P.Publications, b: P.Publications) -> Bool:
  match a b:
    case P.NoPublications{} P.NoPublications{}:
      True{}
    case P.Publications{ah, at} P.Publications{bh, bt}:
      publication_equal(ah, bh) && publications_equal(at, bt)
    case _ _:
      False{}

def state_equal(a: P.State, b: P.State) -> Bool:
  match a b:
    case P.State{ar, ai, ap, ab, aw, an, asl, apb} P.State{br, bi, bp, bb, bw, bn, bsl, bpb}:
      Nat.is_eq(ar, br) && IT.state_equal(ai, bi) && profiles_equal(ap, bp) && bindings_equal(ab, bb)
        && workers_equal(aw, bw)
        && Nat.is_eq(an, bn) && seals_equal(asl, bsl) && publications_equal(apb, bpb)

# One arm per effect variant; different variants are unequal.
def effect_equal(a: P.Effect, b: P.Effect) -> Bool:
  match a b:
    case P.DeliverInputs{aw, ai} P.DeliverInputs{bw, bi}:
      Nat.is_eq(aw, bw) && W.Ref.equal(ai, bi)
    case P.Reconcile{ai, ad} P.Reconcile{bi, bd}:
      Nat.is_eq(ai, bi) && T.CodeId.equal(ad, bd)
    case P.StopEffects{aw} P.StopEffects{bw}:
      Nat.is_eq(aw, bw)
    case P.Reclaim{aw} P.Reclaim{bw}:
      Nat.is_eq(aw, bw)
    case _ _:
      False{}

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
      P.State{2n, with_input(), table(), worker_binding(), P.Workers{expected_worker(accel_profile(), P.Running{}, used_after_first()), P.NoWorkers{}}, next_worker_after(), P.NoSeals{}, P.NoPublications{}},
      []), "PH-007 a charge within the quota adds only to quota_used and emits nothing")
    Test.check(admitted_as(charge(charged(), P.ResourceRequest{worker_id(), exact_charge()}),
      P.State{3n, with_input(), table(), worker_binding(), P.Workers{expected_worker(accel_profile(), P.Running{}, used_at_limit()), P.NoWorkers{}}, next_worker_after(), P.NoSeals{}, P.NoPublications{}},
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
      P.State{2n, with_input(), table(), worker_binding(), P.Workers{expected_worker(accel_profile(), P.Running{}, P.no_usage()), P.NoWorkers{}}, next_worker_after(), P.NoSeals{}, P.NoPublications{}},
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
      P.State{1n, direct_client(), table(), P.NoBindings{}, P.NoWorkers{}, P.first_worker(), P.NoSeals{}, P.NoPublications{}}, []),
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
        table(), P.Bindings{P.Binding{session_client(), cpu_id()}, P.NoBindings{}}, P.NoWorkers{}, P.first_worker(), P.NoSeals{}, P.NoPublications{}}, []),
      "PH-002 open_session as a worker binds the session non-delegable under its profile even when the target reports it delegable")
    Test.check(identity_rejected(I.delegate(input_on(P.identity(open_worker(claiming_worker_evidence()))),
      I.revision(input_on(P.identity(open_worker(claiming_worker_evidence())))), session_worker(), input_ref(), session_client(),
      input_rights(), input_lifetime(), now()), I.NotDelegable{}),
      "PH-007 a worker session the target reported delegable still cannot delegate")
    Test.check(admitted_as(P.open_session(P.empty(seed_identity(), table()), 0n, full_report(), nondelegable_client_evidence(), P.ClientRole{}),
      P.State{1n, I.Change.state(I.bind_session(seed_identity(), I.revision(seed_identity()), caller_client(), I.Authenticated{}, False{})),
        table(), P.NoBindings{}, P.NoWorkers{}, P.first_worker(), P.NoSeals{}, P.NoPublications{}}, []),
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

# --- Families 3 to 5: values (synthetic) ----------------------------------------------
#
# The publication chain reuses the FacadeTests descriptor: the client session's
# caller is FacadeTests' subject 7 with its token, and its root entry names
# Frontend handle 2, the handle that descriptor opens, so
# `DataOS.commit_from_capability` resolves the same descriptor FacadeTests
# commits through. The worker session has subject 7 with TransferTests'
# other token. Times: the chain runs at 100, the DataOS context's time is 110,
# the input expires at 150. Objects 701 and 702, versions 3 and 4, the
# BackplaneTests artifact digest (and its other artifact), invocation 999
# never recorded, successor incarnation 74, completion sequence 1.

def pub_subject() -> Nat:
  7n

def pub_handle() -> Nat:
  2n

def pub_now() -> Nat:
  100n

def pub_caller() -> F.Caller:
  FF.caller(pub_subject())

def pub_worker_caller() -> F.Caller:
  F.Caller{pub_subject(), TF.other_code()}

def object_id() -> Nat:
  701n

def other_object() -> Nat:
  702n

def object_version() -> Nat:
  3n

def other_version() -> Nat:
  4n

def one_writer() -> Nat:
  1n

def digest_of(artifact: B.ArtifactId) -> T.CodeId:
  match artifact:
    case B.ArtifactId{digest}:
      digest

def sealed_digest() -> T.CodeId:
  digest_of(BF.artifact())

def other_digest() -> T.CodeId:
  digest_of(BF.other_artifact())

def invocation() -> Nat:
  T.Plan.invocation(TF.plan())

def unknown_invocation() -> Nat:
  999n

def successor() -> Nat:
  74n

def sequence() -> U32:
  1

def expected_session() -> Nat:
  6n

def expected_ledger() -> Nat:
  1n

def frontend_revision() -> Nat:
  2n

def stale_frontend_revision() -> Nat:
  1n

# The generation `retire` gives the input entry.
def retired_generation() -> Nat:
  1n+I.first_generation()

# A time at the input's exclusive expiry on the publication chain.
def pub_expiry() -> Nat:
  150n

# --- Families 3 to 5: the publication chain (built by primitive transitions) ---------

def pub_client_evidence() -> P.Fact:
  P.SessionEvidence{pub_caller(), I.Authenticated{}, True{}}

def pub_worker_evidence() -> P.Fact:
  P.SessionEvidence{pub_worker_caller(), I.Authenticated{}, False{}}

def pub_opened_client() -> P.State:
  P.Step.state(P.open_session(seed_state(), P.revision(seed_state()), full_report(), pub_client_evidence(),
    P.ClientRole{}))

def pub_opened() -> P.State:
  P.Step.state(P.open_session(pub_opened_client(), P.revision(pub_opened_client()), full_report(),
    pub_worker_evidence(), P.WorkerRole{accel_id()}))

# The monitor's Frontend state: the FacadeTests descriptor (handle 2 carries
# the TransferTests plan).
def pub_frontend() -> F.State:
  FF.descriptor(pub_subject(), root_rights())

# A plan naming another destination (object 21) than the handle's plan.
def other_plan() -> T.Plan:
  TF.plan_destination(TF.plan(), T.ObjectVersion{21n, 8n})

# A Frontend handle id the descriptor never opened.
def unopened_handle() -> Nat:
  9n

def issue_for(+state: P.State, +session: Nat, +handle: Nat, +plan: T.Plan) -> P.Step:
  P.issue(state, P.revision(state), session, pub_frontend(), handle, plan, root_rights(), root_expires())

def issue_on(+state: P.State, +session: Nat) -> P.Step:
  issue_for(state, session, pub_handle(), TF.plan())

def pub_issued() -> P.State:
  P.Step.state(issue_on(pub_opened(), session_client()))

def delegate_on(+state: P.State, +session: Nat, +ref: W.Ref, +target: Nat) -> P.Step:
  P.delegate(state, P.revision(state), session, ref, target, input_rights(), input_lifetime(), pub_now())

def pub_delegated() -> P.State:
  P.Step.state(delegate_on(pub_issued(), session_client(), root_ref(), session_worker()))

def pub_admitted() -> P.State:
  P.Step.state(P.admit_worker(pub_delegated(), P.revision(pub_delegated()), full_report(), mediated_inventory(),
    session_worker(), input_ref(), pub_now()))

def fact_of(+worker: Nat, +object: Nat, +version: Nat, +digest: T.CodeId, +cpu: Nat, +mappings: Nat,
    +devices: Nat) -> H.ArtifactFact:
  H.ArtifactFact{worker, object, version, digest, cpu, mappings, devices}

def clean_fact() -> H.ArtifactFact:
  fact_of(worker_id(), object_id(), object_version(), sealed_digest(), H.no_writers(), H.no_writers(),
    H.no_writers())

def sealed_record() -> P.Sealed:
  P.Sealed{worker_id(), object_id(), object_version(), sealed_digest()}

def seal_on(+state: P.State, +fact: H.ArtifactFact, +time: Nat) -> P.Step:
  H.seal(state, P.revision(state), fact, time)

def pub_sealed() -> P.State:
  P.Step.state(seal_on(pub_admitted(), clean_fact(), pub_now()))

def publish_with(+state: P.State, +fact: H.ArtifactFact, context: OS.Context, frontend: Nat) -> H.PublishResult:
  H.publish(state, P.revision(state), worker_id(), fact, NF.running(), expected_session(), expected_ledger(),
    NF.held_ledger(), BF.candidate(), context, frontend)

def publish_on(+state: P.State, +fact: H.ArtifactFact) -> H.PublishResult:
  publish_with(state, fact, FF.context(), frontend_revision())

def published() -> P.State:
  H.PublishResult.state(publish_on(pub_sealed(), clean_fact()))

def publication_record() -> P.Publications:
  P.Publications{P.Publication{invocation(), sealed_digest()}, P.NoPublications{}}

# DataOS contexts each failing one commit check, and one binding a different
# artifact (all synthetic, from FacadeTests and BackplaneTests).
def revoked_registry_context() -> OS.Context:
  OS.Context{BF.context(), FF.descriptor(pub_subject(), root_rights()), F.EmptyRegistry{}}

def public_label_context() -> OS.Context:
  OS.Context{BF.with_binding(BF.context(), BF.public_binding()), FF.descriptor(pub_subject(), root_rights()),
    FF.registry(pub_subject(), root_rights())}

def other_artifact_context() -> OS.Context:
  OS.Context{BF.with_binding(BF.context(), BF.with_artifact(BF.binding(), BF.other_artifact())),
    FF.descriptor(pub_subject(), root_rights()), FF.registry(pub_subject(), root_rights())}

# The DataOS context at the input's expiry.
def expired_context() -> OS.Context:
  OS.Context{BF.with_negotiation(BF.context(), NF.context(pub_expiry())), FF.descriptor(pub_subject(), root_rights()),
    FF.registry(pub_subject(), root_rights())}

def reconcile_on(+state: P.State, +invocation: Nat, +digest: T.CodeId) -> P.Step:
  H.reconcile(state, P.revision(state), invocation, digest)

def revoke_on(+state: P.State, +slot: Nat) -> P.Step:
  H.revoke(state, P.revision(state), slot)

def restart_on(+state: P.State, +successor: Nat) -> P.Step:
  H.restart(state, P.revision(state), successor)

def quiesce_on(+state: P.State, +worker: Nat, +generation: Nat) -> P.Step:
  H.quiesce(state, P.revision(state), H.QuiescedFact{worker, generation})

def reclaim_on(+state: P.State, +worker: Nat) -> P.Step:
  H.reclaim(state, P.revision(state), worker)

def completion(+session: Nat, +ref: W.Ref) -> H.CompletionFact:
  H.CompletionFact{session, W.Complete{ref, sequence(), W.status_ok()}}

def complete_on(+state: P.State, +fact: H.CompletionFact) -> P.Step:
  H.complete(state, P.revision(state), fact, now())

# A state with every field of `state` but the revision and the two records.
def records_on(+state: P.State, +revision: Nat, seals: P.Seals, publications: P.Publications) -> P.State:
  P.State{revision, P.identity(state), P.profiles(state), P.bindings(state), P.workers(state), P.next_worker(state),
    seals, publications}

# A state with every field of `state` but the revision and the identity table.
def table_on(+state: P.State, +revision: Nat, identity: I.State) -> P.State:
  P.State{revision, identity, P.profiles(state), P.bindings(state), P.workers(state), P.next_worker(state),
    P.seals(state), P.publications(state)}

def sealed_expected() -> P.State:
  records_on(pub_admitted(), 1n+P.revision(pub_admitted()), P.Seals{sealed_record(), P.NoSeals{}},
    P.NoPublications{})

def published_expected() -> P.State:
  records_on(pub_sealed(), 1n+P.revision(pub_sealed()), P.seals(pub_sealed()), publication_record())

# The base chain (admitted worker 81 on input 22) after the monitor revoked
# the input, then the quiescence and the reclamation.
def revoked_expected() -> P.State:
  P.State{2n, with_input_retired(), table(), worker_binding(), P.Workers{expected_worker(accel_profile(), P.Revoked{},
    P.no_usage()), P.NoWorkers{}}, next_worker_after(), P.NoSeals{}, P.NoPublications{}}

def revoked_now() -> P.State:
  P.Step.state(revoke_on(admitted(), input_slot()))

def quiesced_expected() -> P.State:
  P.State{3n, with_input_retired(), table(), worker_binding(), P.Workers{expected_worker(accel_profile(), P.Quiesced{},
    P.no_usage()), P.NoWorkers{}}, next_worker_after(), P.NoSeals{}, P.NoPublications{}}

def quiesced_now() -> P.State:
  P.Step.state(quiesce_on(revoked_now(), worker_id(), retired_generation()))

def reclaimed_expected() -> P.State:
  P.State{4n, with_input_retired(), table(), worker_binding(), P.Workers{expected_worker(accel_profile(), P.Reclaimed{},
    P.no_usage()), P.NoWorkers{}}, next_worker_after(), P.NoSeals{}, P.NoPublications{}}

def restarted_identity() -> I.State:
  I.Change.state(I.restart(with_input(), I.revision(with_input()), successor()))

def restarted_expected() -> P.State:
  P.State{2n, restarted_identity(), table(), P.NoBindings{}, P.Workers{expected_worker(accel_profile(), P.Revoked{},
    P.no_usage()), P.NoWorkers{}}, next_worker_after(), P.NoSeals{}, P.NoPublications{}}

def restarted_now() -> P.State:
  P.Step.state(restart_on(admitted(), successor()))

def completed_expected() -> P.State:
  P.advanced(admitted())

# Hand-built: the sealed publication chain with the worker in phase Revoked
# while its input entry is still live.
def sealed_revoked() -> P.State:
  P.State{P.revision(pub_sealed()), P.identity(pub_sealed()), table(), P.bindings(pub_sealed()),
    P.Workers{P.Worker{worker_id(), session_worker(), input_ref(), accel_profile(), P.Revoked{}, quota_limit(),
      P.no_usage()}, P.NoWorkers{}}, next_worker_after(), P.seals(pub_sealed()), P.NoPublications{}}

# Hand-built: the admitted publication chain plus a reclaimed worker 82,
# which alone has a sealed record.
def other_sealed() -> P.State:
  P.State{P.revision(pub_admitted()), P.identity(pub_admitted()), table(), P.bindings(pub_admitted()),
    P.Workers{P.Worker{worker_id(), session_worker(), input_ref(), accel_profile(), P.Running{}, quota_limit(),
      P.no_usage()}, P.Workers{worker_as(other_worker(), root_ref(), accel_profile(), P.Reclaimed{}, P.no_usage()),
      P.NoWorkers{}}}, next_worker_two(), P.Seals{P.Sealed{other_worker(), object_id(), object_version(), sealed_digest()},
      P.NoSeals{}}, P.NoPublications{}}

# Hand-built: the input table plus a second client root (slot 23), with three
# running workers whose recorded input references differ from the live input
# entry in exactly one field each: the generation (81), the incarnation (82),
# and the host (80). No transition records such references.
def spare_root() -> I.State:
  I.Change.state(I.mint(with_input(), I.revision(with_input()), session_client(), handle_client(), TF.plan(),
    root_rights(), root_expires()))

def spare_slot() -> Nat:
  23n

def mismatched_refs() -> P.State:
  P.State{1n, spare_root(), table(), worker_binding(), P.Workers{worker_as(worker_id(), W.Ref{word(host_id()),
    word(incarnation_id()), word(input_slot()), word(retired_generation())}, accel_profile(), P.Running{}, P.no_usage()),
    P.Workers{worker_as(other_worker(), W.Ref{word(host_id()), word(72n), word(input_slot()), word(I.first_generation())},
      accel_profile(), P.Running{}, P.no_usage()), P.Workers{worker_as(earlier_worker(), W.Ref{word(52n),
      word(incarnation_id()), word(input_slot()), word(I.first_generation())}, accel_profile(), P.Running{}, P.no_usage()),
      P.NoWorkers{}}}}, next_worker_two(), P.NoSeals{}, P.NoPublications{}}

# Hand-built states that fail `valid`'s seal and publication clauses.
def sealed_unknown_worker() -> P.State:
  records_on(admitted(), 1n, P.Seals{P.Sealed{worker_unknown(), object_id(), object_version(), sealed_digest()},
    P.NoSeals{}}, P.NoPublications{})

def sealed_twice() -> P.State:
  records_on(pub_sealed(), P.revision(pub_sealed()), P.Seals{sealed_record(), P.Seals{P.Sealed{worker_id(),
    other_object(), object_version(), sealed_digest()}, P.NoSeals{}}}, P.NoPublications{})

def recorded_twice() -> P.State:
  records_on(published(), P.revision(published()), P.seals(published()), P.Publications{P.Publication{invocation(),
    sealed_digest()}, publication_record()})

# A context whose registry was revoked and whose binding names another artifact.
def rejected_other_artifact_context() -> OS.Context:
  OS.Context{BF.with_binding(BF.context(), BF.with_artifact(BF.binding(), BF.other_artifact())),
    FF.descriptor(pub_subject(), root_rights()), F.EmptyRegistry{}}

# --- Families 3 to 5: result helpers --------------------------------------------------

def no_publication(effects: +List<H.PublishEffect>) -> Bool:
  match effects:
    case Nil{}:
      True{}
    case _:
      False{}

# Exactly one `Publish`, whose intent names `artifact`.
def one_publish(effects: +List<H.PublishEffect>, artifact: B.ArtifactId) -> Bool:
  match effects:
    case Con{H.Publish{intent}, Nil{}}:
      B.ArtifactId.equal(B.WriteIntent.artifact(intent), artifact)
    case _:
      False{}

# A publication with state `expected`, one `Publish` of the sealed artifact,
# a committed result naming it, and a ledger spent exactly once.
def published_as(+result: H.PublishResult, expected: P.State) -> Bool:
  match result:
    case H.Published{state, commit, effects}:
      state_equal(state, expected) && one_publish(effects, BF.artifact()) && BF.artifact_matches(commit, BF.artifact())
        && Nat.is_eq(L.revision(B.ledger(commit)), 1n+L.revision(NF.held_ledger()))
    case H.Refused{_, _, _, _}:
      False{}

# A refusal with exactly `reason` that hands back `input`, the supplied
# Negotiation session and ledger (their revisions unchanged), and no effect.
def refused_as(+result: H.PublishResult, input: P.State, reason: P.Error) -> Bool:
  match result:
    case H.Refused{state, session, ledger, got}:
      P.Error.equal(got, reason) && state_equal(state, input)
        && Nat.is_eq(N.Session.revision(session), N.Session.revision(NF.running()))
        && Nat.is_eq(L.revision(ledger), L.revision(NF.held_ledger())) && no_publication(H.PublishResult.effects(result))
    case H.Published{_, _, _}:
      False{}

# The same, reporting exactly HostIdentity's `reason`, compared directly.
def refused_identity_as(+result: H.PublishResult, input: P.State, reason: I.Error) -> Bool:
  match result:
    case H.Refused{state, session, ledger, P.Identity{got}}:
      I.Error.equal(got, reason) && state_equal(state, input)
        && Nat.is_eq(N.Session.revision(session), N.Session.revision(NF.running()))
        && Nat.is_eq(L.revision(ledger), L.revision(NF.held_ledger())) && no_publication(H.PublishResult.effects(result))
    case _:
      False{}

def found_phase(found: P.WorkerLookup, expected: P.Phase) -> Bool:
  match found:
    case P.OneWorker{worker}:
      phase_equal(P.worker_phase(worker), expected)
    case _:
      False{}

# Whether exactly one worker has id `id` and its phase is `expected`.
def phase_of(workers: P.Workers, +id: Nat, expected: P.Phase) -> Bool:
  found_phase(P.worker_at(workers, id), expected)

def reconciled() -> +List<P.Effect>:
  [P.Reconcile{invocation(), sealed_digest()}]

def stop_81() -> +List<P.Effect>:
  [P.StopEffects{worker_id()}]

def admitted_effects(+step: P.Step, effects: +List<P.Effect>) -> Bool:
  match step:
    case P.Admitted{_, got}:
      effects_equal(got, effects)
    case P.Denied{_, _}:
      False{}

# --- Families 3 to 5: checks ----------------------------------------------------------

# Family 1 wrappers: issue (HostIdentity.mint) and delegate (PH-001, PH-005).
def wrapper_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(admitted_as(issue_on(pub_opened(), session_client()), table_on(pub_opened(), 1n+P.revision(pub_opened()),
      I.Change.state(I.mint(P.identity(pub_opened()), I.revision(P.identity(pub_opened())), session_client(), pub_handle(),
        TF.plan(), root_rights(), root_expires()))), []),
      "PH-001 issue commits HostIdentity.mint's table, advances the revision once, and emits nothing")
    Test.check(denied_identity(issue_on(pub_opened(), session_unknown()), pub_opened(), I.UnknownSession{}),
      "PH-001 issue on an unbound session denied Identity UnknownSession")
    Test.check(denied(issue_for(pub_opened(), session_client(), pub_handle(), other_plan()), pub_opened(),
      P.PlanMismatch{}), "PH-005 issue for a plan other than its Frontend handle's plan denied PlanMismatch")
    Test.check(denied(issue_for(pub_opened(), session_client(), unopened_handle(), TF.plan()), pub_opened(),
      P.PlanMismatch{}), "PH-005 issue for a handle the monitor's Frontend state does not hold denied PlanMismatch")
    Test.check(denied(issue_for(pub_opened(), session_unknown(), pub_handle(), other_plan()), pub_opened(),
      P.PlanMismatch{}), "PH-005 order: issue's plan binding precedes HostIdentity's checks")
    Test.check(admitted_as(delegate_on(pub_issued(), session_client(), root_ref(), session_worker()),
      table_on(pub_issued(), 1n+P.revision(pub_issued()), I.Change.state(I.delegate(P.identity(pub_issued()),
        I.revision(P.identity(pub_issued())), session_client(), root_ref(), session_worker(), input_rights(),
        input_lifetime(), pub_now()))), []),
      "PH-005 delegate commits HostIdentity.delegate's table, advances the revision once, and emits nothing")
    Test.check(denied_identity(delegate_on(pub_delegated(), session_worker(), input_ref(), session_client()), pub_delegated(),
      I.NotDelegable{}),
      "PH-007 a delegation from the worker session through the primitive layer denied Identity NotDelegable")

# Family 3: sealing (PH-008).
def seal_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(admitted_as(seal_on(pub_admitted(), clean_fact(), pub_now()), sealed_expected(), []),
      "PH-008 a seal with zero writers records the exact object, version, and digest with no effect")
    Test.check(denied(seal_on(pub_admitted(), fact_of(worker_id(), object_id(), object_version(), sealed_digest(), one_writer(),
      H.no_writers(), H.no_writers()), pub_now()), pub_admitted(), P.LiveWriter{}),
      "PH-008 a seal with one CPU writer denied LiveWriter")
    Test.check(denied(seal_on(pub_admitted(), fact_of(worker_id(), object_id(), object_version(), sealed_digest(), H.no_writers(),
      one_writer(), H.no_writers()), pub_now()), pub_admitted(), P.LiveWriter{}),
      "PH-008 a read-only seal with one writable mapping left denied LiveWriter")
    Test.check(denied(seal_on(pub_admitted(), fact_of(worker_id(), object_id(), object_version(), sealed_digest(), H.no_writers(),
      H.no_writers(), one_writer()), pub_now()), pub_admitted(), P.LiveWriter{}),
      "PH-008 a seal with one device writer denied LiveWriter")
    Test.check(denied(seal_on(pub_admitted(), fact_of(worker_unknown(), object_id(), object_version(), sealed_digest(),
      H.no_writers(), H.no_writers(), H.no_writers()), pub_now()), pub_admitted(), P.UnknownWorker{}),
      "PH-008 a seal for a worker never admitted denied UnknownWorker")
    Test.check(denied(seal_on(revoked(), clean_fact(), now()), revoked(), P.WrongPhase{}),
      "PH-008 a seal from a revoked worker denied WrongPhase")
    Test.check(denied_identity(seal_on(retired(), clean_fact(), now()), retired(), I.Retired{}),
      "PH-008 a seal after the worker's input was retired denied Identity Retired")
    Test.check(denied(seal_on(pub_sealed(), fact_of(worker_id(), other_object(), object_version(), sealed_digest(),
      H.no_writers(), H.no_writers(), H.no_writers()), pub_now()), pub_sealed(), P.WrongPhase{}),
      "PH-008 a second seal for a sealed worker denied WrongPhase and the record is not replaced")
    Test.check(denied(seal_on(pub_sealed(), fact_of(worker_id(), other_object(), object_version(), sealed_digest(),
      one_writer(), H.no_writers(), H.no_writers()), pub_now()), pub_sealed(), P.WrongPhase{}),
      "PH-008 order: the once-only seal precedes the writer counts")
    Test.check(denied(seal_on(revoked(), fact_of(worker_id(), object_id(), object_version(), sealed_digest(), one_writer(),
      H.no_writers(), H.no_writers()), now()), revoked(), P.WrongPhase{}),
      "PH-008 order: the worker's phase precedes the writer counts")

# Family 4: an accepted publication and the current-artifact step (PH-008, PH-009).
def publish_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(published_as(publish_on(pub_sealed(), clean_fact()), published_expected()),
      "PH-009 a publication through DataOS.commit_from_capability emits exactly one Publish of the sealed digest and spends the ledger once")
    Test.check(refused_as(publish_on(pub_admitted(), clean_fact()), pub_admitted(), P.NotSealed{}),
      "PH-009 a publication before any seal denied NotSealed")
    Test.check(refused_as(publish_on(other_sealed(), clean_fact()), other_sealed(), P.NotSealed{}),
      "PH-009 another worker's sealed record does not seal this worker's publication: denied NotSealed")
    Test.check(refused_as(publish_on(pub_sealed(), fact_of(worker_id(), other_object(), object_version(), sealed_digest(),
      H.no_writers(), H.no_writers(), H.no_writers())), pub_sealed(), P.Retargeted{}),
      "PH-008 a path retargeted to another object denied Retargeted")
    Test.check(refused_as(publish_on(pub_sealed(), fact_of(worker_id(), object_id(), other_version(), sealed_digest(),
      H.no_writers(), H.no_writers(), H.no_writers())), pub_sealed(), P.Retargeted{}),
      "PH-008 a path retargeted to another version denied Retargeted")
    Test.check(refused_as(publish_on(pub_sealed(), fact_of(worker_id(), object_id(), object_version(), other_digest(),
      H.no_writers(), H.no_writers(), H.no_writers())), pub_sealed(), P.Retargeted{}),
      "PH-008 a path retargeted to another digest denied Retargeted")
    Test.check(refused_as(publish_on(pub_sealed(), fact_of(other_worker(), object_id(), object_version(), sealed_digest(),
      H.no_writers(), H.no_writers(), H.no_writers())), pub_sealed(), P.Retargeted{}),
      "PH-008 a current fact naming another worker denied Retargeted")
    Test.check(refused_as(publish_on(pub_sealed(), fact_of(worker_id(), object_id(), object_version(), sealed_digest(),
      H.no_writers(), one_writer(), H.no_writers())), pub_sealed(), P.LiveWriter{}),
      "PH-008 a writable mapping reappearing before publication denied LiveWriter")
    Test.check(refused_as(publish_on(pub_sealed(), fact_of(worker_id(), object_id(), object_version(), other_digest(),
      one_writer(), H.no_writers(), H.no_writers())), pub_sealed(), P.Retargeted{}),
      "PH-008 order: the retarget check precedes the writer counts")
    Test.check(refused_as(publish_on(sealed_revoked(), clean_fact()), sealed_revoked(), P.WrongPhase{}),
      "PH-009 a publication for a worker not Running denied WrongPhase")
    Test.check(refused_as(publish_on(sealed_revoked(), fact_of(worker_id(), object_id(), object_version(), sealed_digest(),
      one_writer(), H.no_writers(), H.no_writers())), sealed_revoked(), P.LiveWriter{}),
      "PH-009 order: the writer counts precede the worker's phase")
    Test.check(refused_identity_as(publish_with(pub_sealed(), clean_fact(), expired_context(), frontend_revision()), pub_sealed(),
      I.Expired{}),
      "PH-009 a publication at the input's expiry on the DataOS context's clock denied Identity Expired")

# Family 4: commit denials, the artifact binding, revocation, and replay (PH-001, PH-009).
def commit_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(refused_as(publish_with(pub_sealed(), clean_fact(), revoked_registry_context(), frontend_revision()), pub_sealed(),
      P.CommitRejected{}),
      "PH-001 a publication whose capability registry was revoked denied CommitRejected with the session and ledger returned")
    Test.check(refused_as(publish_with(pub_sealed(), clean_fact(), FF.context(), stale_frontend_revision()), pub_sealed(),
      P.CommitRejected{}),
      "PH-001 a publication at a stale frontend revision denied CommitRejected with the session and ledger returned")
    Test.check(refused_as(publish_with(pub_sealed(), clean_fact(), public_label_context(), frontend_revision()), pub_sealed(),
      P.CommitRejected{}),
      "PH-001 a publication to a public label denied CommitRejected with the session and ledger returned")
    Test.check(refused_as(publish_with(pub_sealed(), clean_fact(), other_artifact_context(), frontend_revision()), pub_sealed(),
      P.ArtifactMismatch{}),
      "PH-009 a committed binding naming another artifact denied ArtifactMismatch with the session and ledger returned")
    Test.check(refused_as(publish_with(pub_sealed(), clean_fact(), rejected_other_artifact_context(), frontend_revision()), pub_sealed(),
      P.CommitRejected{}),
      "PH-009 order: the commit precedes the artifact binding")
    Test.check(refused_identity_as(publish_on(P.Step.state(revoke_on(pub_sealed(), input_slot())), clean_fact()),
      P.Step.state(revoke_on(pub_sealed(), input_slot())), I.Retired{}),
      "PH-009 revocation of the input before authorization denies the publication Identity Retired")
    Test.check(refused_identity_as(publish_on(P.Step.state(revoke_on(pub_sealed(), root_slot())), clean_fact()),
      P.Step.state(revoke_on(pub_sealed(), root_slot())), I.Retired{}),
      "PH-009 revocation of the client's root before authorization denies the publication Identity Retired")
    Test.check(refused_as(publish_on(P.Step.state(revoke_on(pub_sealed(), input_slot())), fact_of(worker_id(), other_object(),
      object_version(), sealed_digest(), H.no_writers(), H.no_writers(), H.no_writers())),
      P.Step.state(revoke_on(pub_sealed(), input_slot())), P.Retargeted{}),
      "PH-009 order: the current artifact precedes the re-resolution")
    Test.check(refused_as(publish_on(published(), clean_fact()), published(), P.Replay{}),
      "PH-009 a second publication of the same invocation denied Replay with no second spend")
    Test.check(refused_as(publish_with(published(), clean_fact(), revoked_registry_context(), frontend_revision()), published(),
      P.Replay{}),
      "PH-009 order: the replay check precedes the commit")
    Test.check(refused_identity_as(publish_on(P.Step.state(revoke_on(published(), input_slot())), clean_fact()),
      P.Step.state(revoke_on(published(), input_slot())), I.Retired{}),
      "PH-009 order: the re-resolution precedes the replay check")

# Family 4: recovery (PH-009, "Crash recovery repeats a publication attempt").
def reconcile_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(admitted_as(reconcile_on(published(), invocation(), sealed_digest()), P.advanced(published()), reconciled()),
      "PH-009 reconcile of a recorded invocation with its digest emits Reconcile with no commit and no spending")
    Test.check(denied(reconcile_on(published(), invocation(), other_digest()), published(), P.Substitution{}),
      "PH-009 reconcile with a different digest denied Substitution")
    Test.check(denied(reconcile_on(published(), unknown_invocation(), sealed_digest()), published(), P.Unrecorded{}),
      "PH-009 reconcile of an unrecorded invocation denied Unrecorded")
    Test.check(denied(reconcile_on(pub_sealed(), invocation(), sealed_digest()), pub_sealed(), P.Unrecorded{}),
      "PH-009 reconcile before any publication denied Unrecorded and authorizes nothing")
    Test.check(admitted_as(reconcile_on(P.Step.state(revoke_on(published(), input_slot())), invocation(), sealed_digest()),
      P.advanced(P.Step.state(revoke_on(published(), input_slot()))), reconciled()),
      "PH-010 after revocation the recorded publication still reconciles to the same outcome")
    Test.check(publications_equal(P.publications(P.Step.state(revoke_on(published(), input_slot()))), publication_record())
        && admitted_effects(revoke_on(published(), input_slot()), stop_81()),
      "PH-010 revocation after publication leaves the record unchanged and emits only StopEffects, no recall")
    Test.check(admitted_as(reconcile_on(P.Step.state(restart_on(published(), successor())), invocation(), sealed_digest()),
      P.advanced(P.Step.state(restart_on(published(), successor()))), reconciled()),
      "PH-009 after a restart the recorded publication still reconciles to the same outcome")

# Family 5: revoke, quiesce, reclaim, restart (PH-010).
def teardown_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(admitted_as(revoke_on(admitted(), input_slot()), revoked_expected(), stop_81()),
      "PH-010 revoke retires the input, moves its worker to Revoked, and emits StopEffects for it")
    Test.check(admitted_effects(revoke_on(admitted(), root_slot()), stop_81())
        && phase_of(P.workers(P.Step.state(revoke_on(admitted(), root_slot()))), worker_id(), P.Revoked{}),
      "PH-010 revoking the client's root revokes the worker on the delegated input")
    Test.check(admitted_effects(revoke_on(root_and_input(), input_slot()), [P.StopEffects{other_worker()}])
        && phase_of(P.workers(P.Step.state(revoke_on(root_and_input(), input_slot()))), worker_id(), P.Running{}),
      "PH-010 revoking one input leaves a worker on another entry Running")
    Test.check(admitted_effects(revoke_on(revoked_now(), root_slot()), [])
        && phase_of(P.workers(P.Step.state(revoke_on(revoked_now(), root_slot()))), worker_id(), P.Revoked{}),
      "PH-010 a later revocation does not stop an already revoked worker again")
    Test.check(admitted_effects(revoke_on(mismatched_refs(), spare_slot()), [P.StopEffects{worker_id()},
      P.StopEffects{other_worker()}, P.StopEffects{earlier_worker()}]),
      "PH-010 a revocation stops every running worker whose input reference is not live at its host, incarnation, and generation")
    Test.check(admitted_effects(revoke_on(quiesced_now(), root_slot()), [])
        && phase_of(P.workers(P.Step.state(revoke_on(quiesced_now(), root_slot()))), worker_id(), P.Quiesced{}),
      "PH-010 a later revocation leaves a quiesced worker Quiesced")
    Test.check(phase_of(P.workers(P.Step.state(quiesce_on(P.Step.state(revoke_on(root_and_input(), input_slot())), other_worker(),
      retired_generation()))), worker_id(), P.Running{}),
      "PH-010 quiescing one worker leaves another worker's phase unchanged")
    Test.check(denied_identity(revoke_on(admitted(), worker_unknown()), admitted(), I.Forged{}),
      "PH-010 revoke of a slot never allocated denied Identity Forged")
    Test.check(denied_identity(revoke_on(revoked_now(), input_slot()), revoked_now(), I.Retired{}),
      "PH-010 revoke of an already retired slot denied Identity Retired")
    Test.check(denied(reclaim_on(revoked_now(), worker_id()), revoked_now(), P.NotQuiesced{}),
      "PH-010 reclaim after revoke but before quiesce denied NotQuiesced")
    Test.check(denied(reclaim_on(admitted(), worker_id()), admitted(), P.NotQuiesced{}),
      "PH-010 reclaim of a running worker denied NotQuiesced")
    Test.check(denied_identity(quiesce_on(revoked_now(), worker_id(), I.first_generation()), revoked_now(), I.StaleGeneration{}),
      "PH-010 quiesce naming the pre-revocation generation denied Identity StaleGeneration")
    Test.check(denied(quiesce_on(admitted(), worker_id(), I.first_generation()), admitted(), P.WrongPhase{}),
      "PH-010 order: quiesce of a running worker denied WrongPhase before its generation")
    Test.check(denied(quiesce_on(revoked_now(), worker_unknown(), retired_generation()), revoked_now(), P.UnknownWorker{}),
      "PH-010 quiesce of a worker never admitted denied UnknownWorker")
    Test.check(admitted_as(quiesce_on(revoked_now(), worker_id(), retired_generation()), quiesced_expected(), []),
      "PH-010 quiesce with the retired generation moves the worker to Quiesced with no effect")
    Test.check(admitted_as(reclaim_on(quiesced_now(), worker_id()), reclaimed_expected(), [P.Reclaim{worker_id()}]),
      "PH-010 the order revoke, quiesce, reclaim is accepted and reclaim emits only Reclaim")
    Test.check(denied(reclaim_on(quiesced_now(), worker_unknown()), quiesced_now(), P.UnknownWorker{}),
      "PH-010 reclaim of a worker never admitted denied UnknownWorker")
    Test.check(denied(quiesce_on(quiesced_now(), worker_id(), retired_generation()), quiesced_now(), P.WrongPhase{}),
      "PH-010 a second quiesce denied WrongPhase")
    Test.check(denied(reclaim_on(P.Step.state(reclaim_on(quiesced_now(), worker_id())), worker_id()),
      P.Step.state(reclaim_on(quiesced_now(), worker_id())), P.NotQuiesced{}),
      "PH-010 a second reclaim denied NotQuiesced")
    Test.check(admitted_as(restart_on(admitted(), successor()), restarted_expected(), stop_81()),
      "PH-010 restart drops the bindings, moves running workers to Revoked, and emits StopEffects")
    Test.check(denied_identity(restart_on(admitted(), incarnation_id()), admitted(), I.StaleIncarnation{}),
      "PH-010 restart to an incarnation not greater denied Identity StaleIncarnation")
    Test.check(admitted_effects(reclaim_on(P.Step.state(quiesce_on(restarted_now(), worker_id(), retired_generation())),
      worker_id()), [P.Reclaim{worker_id()}]),
      "PH-010 a worker revoked by restart is quiesced and reclaimed in order")

# Family 5: stale completions (PH-010, "A device completes after teardown").
def completion_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(admitted_as(complete_on(admitted(), completion(session_worker(), input_ref())), completed_expected(), []),
      "PH-010 a completion for the running worker's live input is accepted with no effect")
    Test.check(denied_identity(complete_on(revoked_now(), completion(session_worker(), input_ref())), revoked_now(), I.Retired{}),
      "PH-010 a completion after revoke with the old generation denied Identity Retired")
    Test.check(denied_identity(complete_on(restarted_now(), completion(session_worker(), input_ref())), restarted_now(),
      I.StaleIncarnation{}),
      "PH-010 a completion after restart with the old incarnation denied Identity StaleIncarnation")
    Test.check(denied(complete_on(admitted(), H.CompletionFact{session_worker(), input_use()}), admitted(), P.WrongPhase{}),
      "PH-010 a completion fact carrying a Use message denied WrongPhase")
    Test.check(denied(complete_on(revoked(), completion(session_worker(), input_ref())), revoked(), P.WrongPhase{}),
      "PH-010 a completion for a revoked worker whose entry is still live denied WrongPhase")
    Test.check(denied(complete_on(admitted(), completion(session_client(), root_ref())), admitted(), P.UnknownWorker{}),
      "PH-010 a completion naming an entry no worker holds denied UnknownWorker")
    Test.check(denied(complete_on(reclaimed_input(), completion(session_worker(), input_ref())), reclaimed_input(),
      P.UnknownWorker{}),
      "PH-010 a completion for an entry held only by a reclaimed worker denied UnknownWorker")
    Test.check(denied_identity(complete_on(admitted(), completion(session_client(), input_ref())), admitted(), I.NotHolder{}),
      "PH-010 a completion for the worker's input on the client session denied Identity NotHolder")

# Families 3 to 5: the revision and valid gate (PH-001).
def publication_gate_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(denied(H.seal(pub_admitted(), 1n+P.revision(pub_admitted()), clean_fact(), pub_now()), pub_admitted(),
      P.StaleRevision{}), "PH-008 seal at a stale revision denied StaleRevision")
    Test.check(refused_as(H.publish(pub_sealed(), 1n+P.revision(pub_sealed()), worker_id(), clean_fact(), NF.running(),
      expected_session(), expected_ledger(), NF.held_ledger(), BF.candidate(), FF.context(), frontend_revision()), pub_sealed(),
      P.StaleRevision{}), "PH-009 publish at a stale revision denied StaleRevision")
    Test.check(denied(H.reconcile(published(), 1n+P.revision(published()), invocation(), sealed_digest()), published(),
      P.StaleRevision{}), "PH-009 reconcile at a stale revision denied StaleRevision")
    Test.check(denied(H.revoke(admitted(), 1n+P.revision(admitted()), input_slot()), admitted(), P.StaleRevision{}),
      "PH-010 revoke at a stale revision denied StaleRevision")
    Test.check(denied(H.restart(admitted(), 1n+P.revision(admitted()), successor()), admitted(), P.StaleRevision{}),
      "PH-010 restart at a stale revision denied StaleRevision")
    Test.check(denied(H.quiesce(revoked_now(), 1n+P.revision(revoked_now()), H.QuiescedFact{worker_id(), retired_generation()}),
      revoked_now(), P.StaleRevision{}), "PH-010 quiesce at a stale revision denied StaleRevision")
    Test.check(denied(H.reclaim(quiesced_now(), 1n+P.revision(quiesced_now()), worker_id()), quiesced_now(), P.StaleRevision{}),
      "PH-010 reclaim at a stale revision denied StaleRevision")
    Test.check(denied(H.complete(admitted(), 1n+P.revision(admitted()), completion(session_worker(), input_ref()), now()),
      admitted(), P.StaleRevision{}), "PH-010 complete at a stale revision denied StaleRevision")
    Test.check(denied(P.issue(pub_opened(), 1n+P.revision(pub_opened()), session_client(), pub_frontend(), pub_handle(), TF.plan(), root_rights(),
      root_expires()), pub_opened(), P.StaleRevision{}), "PH-001 issue at a stale revision denied StaleRevision")
    Test.check(denied(P.delegate(pub_issued(), 1n+P.revision(pub_issued()), session_client(), root_ref(), session_worker(),
      input_rights(), input_lifetime(), pub_now()), pub_issued(), P.StaleRevision{}),
      "PH-005 the primitive delegate at a stale revision denied StaleRevision")

# Families 3 to 5: `valid` and the gate on a state failing it (PH-001).
def publication_valid_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(P.valid(pub_admitted()) && P.valid(pub_sealed()) && P.valid(published()) && P.valid(revoked_now())
        && P.valid(quiesced_now()) && P.valid(P.Step.state(reclaim_on(quiesced_now(), worker_id()))) && P.valid(restarted_now())
        && P.valid(P.Step.state(revoke_on(published(), input_slot()))),
      "PH-001 states built by the family 1 and 3 to 5 transitions satisfy valid")
    Test.check(Bool.not(P.valid(sealed_unknown_worker())), "PH-008 valid rejects a sealed record naming no worker")
    Test.check(Bool.not(P.valid(sealed_twice())), "PH-008 valid rejects a worker sealed twice")
    Test.check(Bool.not(P.valid(recorded_twice())), "PH-009 valid rejects an invocation recorded twice")
    Test.check(denied(seal_on(sealed_twice(), clean_fact(), pub_now()), sealed_twice(), P.StaleRevision{}),
      "PH-008 a seal on a state that is not valid denied StaleRevision")
    Test.check(refused_as(publish_on(sealed_twice(), clean_fact()), sealed_twice(), P.StaleRevision{}),
      "PH-009 a publication on a state that is not valid denied StaleRevision")
    Test.check(denied(reconcile_on(recorded_twice(), invocation(), sealed_digest()), recorded_twice(), P.StaleRevision{}),
      "PH-009 reconcile on a state that is not valid denied StaleRevision")
    Test.check(denied(revoke_on(sealed_twice(), input_slot()), sealed_twice(), P.StaleRevision{}),
      "PH-010 revoke on a state that is not valid denied StaleRevision")
    Test.check(denied(restart_on(sealed_twice(), successor()), sealed_twice(), P.StaleRevision{}),
      "PH-010 restart on a state that is not valid denied StaleRevision")
    Test.check(denied(quiesce_on(sealed_twice(), worker_id(), retired_generation()), sealed_twice(), P.StaleRevision{}),
      "PH-010 quiesce on a state that is not valid denied StaleRevision")
    Test.check(denied(reclaim_on(sealed_twice(), worker_id()), sealed_twice(), P.StaleRevision{}),
      "PH-010 reclaim on a state that is not valid denied StaleRevision")
    Test.check(denied(H.complete(sealed_twice(), P.revision(sealed_twice()), completion(session_worker(), input_ref()), pub_now()),
      sealed_twice(), P.StaleRevision{}),
      "PH-010 complete on a state that is not valid denied StaleRevision")
    Test.check(denied(issue_on(sealed_twice(), session_client()), sealed_twice(), P.StaleRevision{}),
      "PH-001 issue on a state that is not valid denied StaleRevision")
    Test.check(denied(delegate_on(sealed_twice(), session_client(), root_ref(), session_worker()), sealed_twice(),
      P.StaleRevision{}),
      "PH-005 the primitive delegate on a state that is not valid denied StaleRevision")
    Test.check(P.Error.equal(P.Replay{}, P.Replay{}) && Bool.not(P.Error.equal(P.Replay{}, P.Unrecorded{}))
        && Bool.not(P.Error.equal(P.LiveWriter{}, P.Retargeted{})) && Bool.not(P.Error.equal(P.NotQuiesced{}, P.WrongPhase{})),
      "PH-001 Error.equal distinguishes the publication and revocation reasons")

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
    wrapper_checks()
    seal_checks()
    publish_checks()
    commit_checks()
    reconcile_checks()
    teardown_checks()
    completion_checks()
    publication_gate_checks()
    publication_valid_checks()
    IO.print("HostPrimitives: 206 checks passed")
