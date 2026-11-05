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
# report from native facts; the profiles stand in for an admitted request;
# the plan is the synthetic TransferTests fixture; the hand-built states
# exist only to reach denial paths no transition produces. Nothing here
# authenticates a session, confines a worker, or enforces a quota natively.
#
# Every denial is checked with `denied`: exactly the expected reason, full
# state equality with its input (identity table included, through
# HostIdentityTests' equality helpers), and no effects.
#
# Not tested here, by nature: that a binding reports its complete native
# inventory, removes or mediates routes, enforces quotas, and isolates
# devices natively, and that it executes only effects this monitor returned
# (section 2 host obligations).

# --- Identities and amounts (synthetic) ------------------------------------------
#
# Every value below is distinct from every value of another field: host 51,
# incarnation 73, subjects 31 to 33, sessions 300 to 302 (and 309 never
# bound), slots 21 and 22, handle 61, rights 6 and 4, times 120 to 400,
# profile ids 399 to 404, worker 81 (and 89 never admitted), quota 500 with
# charges 200, 300, and 301, the claimed subject 33.

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

# Session ids: the seeded supervisor 300, then the client 301 and the
# non-delegable worker 302 in bind order; 309 is never bound.
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

def root_rights() -> U32:
  6

def input_rights() -> U32:
  4

def now() -> Nat:
  120n

def root_expires() -> Nat:
  400n

def input_lifetime() -> Nat:
  50n

# Worker ids: the seeded counter makes the first admitted worker 81.
def seed_worker() -> Nat:
  81n

def worker_id() -> Nat:
  81n

def next_worker_after() -> Nat:
  82n

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

# The monitor's admitted profiles. Accelerator work requiring every control;
# CPU work requiring every control but accelerator isolation; a lower profile
# requiring two families and two controls; and an accelerator profile that
# does not list the isolation control.
def accel_profile() -> P.Profile:
  P.Profile{403n, P.all_families(), every_control(), P.Accelerator{}}

def cpu_profile() -> P.Profile:
  P.Profile{402n, P.all_families(), cpu_controls(), P.Cpu{}}

def lower_profile() -> P.Profile:
  P.Profile{399n, lower_families(), lower_controls(), P.Cpu{}}

def bare_accel_profile() -> P.Profile:
  P.Profile{404n, P.all_families(), cpu_controls(), P.Accelerator{}}

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
  1

def route_handle() -> U32:
  2

def route_shared_memory() -> U32:
  3

def route_service() -> U32:
  4

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

# A Use of the client's root claiming another subject.
def claiming_use() -> W.Message:
  W.Use{root_ref(), W.operation_read(), input_rights(), W.ClaimedSubject{subject_claimed()}}

def input_use() -> W.Message:
  W.Use{input_ref(), W.operation_read(), input_rights(), W.ClaimedSubject{subject_claimed()}}

# --- Identity table (built by HostIdentity transitions) --------------------------

def seed_identity() -> I.State:
  I.State{0n, host_id(), incarnation_id(), seed_slot(),
    I.Sessions{I.Session{session_supervisor(), incarnation_id(), caller_supervisor(), I.Authenticated{}, True{}},
      I.NoSessions{}}, I.NoEntries{}}

def client_evidence() -> P.Fact:
  P.SessionEvidence{caller_client(), I.Authenticated{}, True{}}

def worker_evidence() -> P.Fact:
  P.SessionEvidence{caller_worker(), I.Authenticated{}, False{}}

def with_client() -> I.State:
  I.Change.state(I.bind_session(seed_identity(), I.revision(seed_identity()), caller_client(),
    I.Authenticated{}, True{}))

def with_worker() -> I.State:
  I.Change.state(I.bind_session(with_client(), I.revision(with_client()), caller_worker(),
    I.Authenticated{}, False{}))

def with_root() -> I.State:
  I.Change.state(I.mint(with_worker(), I.revision(with_worker()), session_client(), handle_client(),
    TF.plan(), root_rights(), root_expires()))

# The client delegates a narrowed input entry to the worker session.
def with_input() -> I.State:
  I.Change.state(I.delegate(with_root(), I.revision(with_root()), session_client(), root_ref(),
    session_worker(), input_rights(), input_lifetime(), now()))

# --- Primitive states ---------------------------------------------------------------

def base() -> P.State:
  P.State{0n, with_input(), P.NoWorkers{}, seed_worker()}

def admit(+profile: P.Profile, +report: P.TargetReport, +inventory: P.Fact) -> P.Step:
  P.admit_worker(base(), P.revision(base()), profile, quota_limit(), report, inventory, session_worker(),
    input_ref(), now())

def expected_worker(+profile: P.Profile, +phase: P.Phase, +used: Nat) -> P.Worker:
  P.Worker{worker_id(), session_worker(), input_slot(), profile, phase, quota_limit(), used}

def admitted() -> P.State:
  P.Step.state(admit(accel_profile(), full_report(), mediated_inventory()))

def charge(+state: P.State, +fact: P.Fact) -> P.Step:
  P.charge(state, P.revision(state), fact)

def charged() -> P.State:
  P.Step.state(charge(admitted(), P.ResourceRequest{worker_id(), first_charge()}))

def diagnose(+state: P.State, +fact: P.Fact) -> P.Step:
  P.diagnostic(state, P.revision(state), fact)

# Hand-built: the admitted worker in phase Revoked.
def revoked() -> P.State:
  P.State{1n, with_input(), P.Workers{expected_worker(accel_profile(), P.Revoked{}, P.no_usage()),
    P.NoWorkers{}}, next_worker_after()}

# Hand-built: two workers under one id.
def duplicated() -> P.State:
  P.State{1n, with_input(), P.Workers{expected_worker(accel_profile(), P.Running{}, P.no_usage()),
    P.Workers{expected_worker(cpu_profile(), P.Running{}, P.no_usage()), P.NoWorkers{}}},
    next_worker_after()}

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
      Nat.is_eq(ai, bi) && Nat.is_eq(as, bs) && Nat.is_eq(al, bl) && profile_equal(ap, bp)
        && phase_equal(ah, bh) && Nat.is_eq(aq, bq) && Nat.is_eq(au, bu)

def workers_equal(a: P.Workers, b: P.Workers) -> Bool:
  match a b:
    case P.NoWorkers{} P.NoWorkers{}:
      True{}
    case P.Workers{ah, at} P.Workers{bh, bt}:
      worker_equal(ah, bh) && workers_equal(at, bt)
    case _ _:
      False{}

def state_equal(a: P.State, b: P.State) -> Bool:
  match a b:
    case P.State{ar, ai, aw, an} P.State{br, bi, bw, bn}:
      Nat.is_eq(ar, br) && IT.state_equal(ai, bi) && workers_equal(aw, bw) && Nat.is_eq(an, bn)

def effect_equal(a: P.Effect, b: P.Effect) -> Bool:
  match a b:
    case P.DeliverInputs{aw, as} P.DeliverInputs{bw, bs}:
      Nat.is_eq(aw, bw) && Nat.is_eq(as, bs)

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

# An admitted step whose state is `expected` and whose effects are `effects`.
def admitted_as(+step: P.Step, expected: P.State, effects: +List<P.Effect>) -> Bool:
  match step:
    case P.Admitted{state, got}:
      state_equal(state, expected) && effects_equal(got, effects)
    case P.Denied{_, _}:
      False{}

# A denial reporting exactly HostIdentity's `reason`, compared directly rather
# than through `P.Error.equal`, with the input state and no effects.
def denied_identity(+step: P.Step, input: P.State, reason: I.Error) -> Bool:
  match step:
    case P.Denied{state, P.Identity{got}}:
      I.Error.equal(got, reason) && state_equal(state, input) && silent(step)
    case _:
      False{}

def unresolved(resolution: I.Resolution, reason: I.Error) -> Bool:
  IT.unresolved(resolution, reason)

# A resolution whose effective caller is `caller`.
def resolved_as(resolution: I.Resolution, caller: F.Caller) -> Bool:
  match resolution:
    case I.Resolved{_, got}:
      IT.caller_equal(got, caller)
    case I.Unresolved{_}:
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
  [P.DeliverInputs{worker_id(), input_slot()}]

# --- Checks -------------------------------------------------------------------------

def missing_control(+bit: U32) -> Bool:
  denied(admit(accel_profile(), missing_report(bit), mediated_inventory()), base(), P.MissingControl{})

# Accepted admissions (PH-006, PH-014).
def accept_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(admitted_as(admit(accel_profile(), full_report(), mediated_inventory()),
      P.State{1n, with_input(), P.Workers{expected_worker(accel_profile(), P.Running{}, P.no_usage()), P.NoWorkers{}}, next_worker_after()},
      delivered()), "PH-006 an admission with every control established records the worker Running and delivers only its input slot")
    Test.check(admitted_as(admit(cpu_profile(), cpu_report(), mediated_inventory()),
      P.State{1n, with_input(), P.Workers{expected_worker(cpu_profile(), P.Running{}, P.no_usage()), P.NoWorkers{}}, next_worker_after()},
      delivered()), "PH-014 a CPU admission without accelerator isolation records backend Cpu")
    Test.check(admitted_as(admit(lower_profile(), lower_report(), mediated_inventory()),
      P.State{1n, with_input(), P.Workers{expected_worker(lower_profile(), P.Running{}, P.no_usage()), P.NoWorkers{}}, next_worker_after()},
      delivered()), "PH-006 the lower report meets the lower profile when that profile is the admitted one")

# Each control bit missing alone (PH-006 "A required kernel feature is missing").
def control_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(missing_control(P.control_address_isolation()), "PH-006 address isolation missing alone denied MissingControl with no effect")
    Test.check(missing_control(P.control_no_ambient_network()), "PH-006 no ambient network missing alone denied MissingControl with no effect")
    Test.check(missing_control(P.control_output_mediation()), "PH-006 output mediation missing alone denied MissingControl with no effect")
    Test.check(missing_control(P.control_quota()), "PH-006 quota control missing alone denied MissingControl with no effect")
    Test.check(missing_control(P.control_no_inherited_routes()), "PH-006 no inherited routes missing alone denied MissingControl with no effect")
    Test.check(missing_control(P.control_accelerator_isolation()), "PH-006 accelerator isolation missing alone denied MissingControl with no effect")

# Target reports cannot lower the monitor's profile (PH-006, PH-001).
def report_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(denied(admit(accel_profile(), no_publication_report(), mediated_inventory()), base(), P.UnsupportedFamily{}),
      "PH-006 a report without the publication family denied UnsupportedFamily with the monitor profile unchanged")
    Test.check(denied(admit(accel_profile(), lower_report(), mediated_inventory()), base(), P.UnsupportedFamily{}),
      "PH-006 a report meeting only a lower profile denied for the admitted profile with the monitor profile unchanged")
    Test.check(denied(admit(cpu_profile(), P.TargetReport{P.all_families(), lower_controls()}, mediated_inventory()), base(), P.MissingControl{}),
      "PH-006 a report with every family but only the lower profile's controls denied MissingControl")

# Route inventory (PH-006 "An inherited output remains accessible").
def inventory_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(denied(admit(accel_profile(), full_report(), leaky_inventory()), base(), P.UnmediatedRoute{}),
      "PH-006 one unmediated route among mediated ones denied UnmediatedRoute before any DeliverInputs")
    Test.check(denied(admit(accel_profile(), full_report(), leaky_first_inventory()), base(), P.UnmediatedRoute{}),
      "PH-006 an unmediated first route denied UnmediatedRoute")
    Test.check(denied(admit(accel_profile(), full_report(), P.NativeWriteOffered{worker_id()}), base(), P.WrongPhase{}),
      "PH-006 an admission given a fact other than an Inventory denied WrongPhase")

# Accelerators (PH-014 "A shared device heap exposes the original graph").
def accelerator_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(denied(admit(bare_accel_profile(), cpu_report(), mediated_inventory()), base(), P.UnisolatedAccelerator{}),
      "PH-014 an accelerator profile not listing isolation, on a target without it, denied UnisolatedAccelerator and not downgraded")
    Test.check(admitted_as(admit(bare_accel_profile(), full_report(), mediated_inventory()),
      P.State{1n, with_input(), P.Workers{expected_worker(bare_accel_profile(), P.Running{}, P.no_usage()), P.NoWorkers{}}, next_worker_after()},
      delivered()), "PH-014 the same accelerator profile is admitted once isolation is established")
    Test.check(denied_identity(P.admit_worker(base(), P.revision(base()), accel_profile(), quota_limit(), full_report(),
      mediated_inventory(), session_worker(), root_ref(), now()), base(), I.NotHolder{}),
      "PH-006 an admission presenting an input reference the worker session does not hold denied Identity NotHolder")
    Test.check(denied_identity(P.admit_worker(base(), P.revision(base()), accel_profile(), quota_limit(), full_report(),
      mediated_inventory(), session_client(), input_ref(), now()), base(), I.NotHolder{}),
      "PH-006 an admission presenting the worker's input reference on the client session denied Identity NotHolder")

# Quotas (PH-007 "A worker exhausts its resource quota").
def quota_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(admitted_as(charge(admitted(), P.ResourceRequest{worker_id(), first_charge()}),
      P.State{2n, with_input(), P.Workers{expected_worker(accel_profile(), P.Running{}, used_after_first()), P.NoWorkers{}}, next_worker_after()},
      []), "PH-007 a charge within the quota adds only to quota_used and emits nothing")
    Test.check(admitted_as(charge(charged(), P.ResourceRequest{worker_id(), exact_charge()}),
      P.State{3n, with_input(), P.Workers{expected_worker(accel_profile(), P.Running{}, used_at_limit()), P.NoWorkers{}}, next_worker_after()},
      []), "PH-007 a charge reaching exactly the quota limit is accepted")
    Test.check(denied(charge(charged(), P.ResourceRequest{worker_id(), excess_charge()}), charged(), P.QuotaExhausted{}),
      "PH-007 a charge beyond the quota denied QuotaExhausted with the state unchanged and no effect")
    Test.check(only_phase(P.workers(P.Step.state(charge(charged(), P.ResourceRequest{worker_id(), excess_charge()}))), P.Running{})
      && rights_are(input_entry_rights(P.Step.state(charge(charged(), P.ResourceRequest{worker_id(), excess_charge()}))), input_rights()),
      "PH-007 after exhaustion the worker's phase and its input entry's rights are unchanged")
    Test.check(denied(charge(admitted(), P.ResourceRequest{worker_unknown(), first_charge()}), admitted(), P.UnknownWorker{}),
      "PH-007 a charge for a worker never admitted denied UnknownWorker")
    Test.check(denied(charge(duplicated(), P.ResourceRequest{worker_id(), first_charge()}), duplicated(), P.UnknownWorker{}),
      "PH-007 a charge naming a duplicated worker id denied UnknownWorker")
    Test.check(denied(charge(revoked(), P.ResourceRequest{worker_id(), first_charge()}), revoked(), P.WrongPhase{}),
      "PH-007 a charge from a revoked worker denied WrongPhase")
    Test.check(denied(charge(admitted(), P.Diagnostic{worker_id(), False{}}), admitted(), P.WrongPhase{}),
      "PH-007 a charge given a fact other than a ResourceRequest denied WrongPhase")

# Diagnostics (PH-007 "A worker encodes a secret in diagnostics").
def diagnostic_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(denied(diagnose(admitted(), P.Diagnostic{worker_id(), True{}}), admitted(), P.DiagnosticSink{}),
      "PH-007 a public diagnostic from a running worker denied DiagnosticSink")
    Test.check(admitted_as(diagnose(admitted(), P.Diagnostic{worker_id(), False{}}),
      P.State{2n, with_input(), P.Workers{expected_worker(accel_profile(), P.Running{}, P.no_usage()), P.NoWorkers{}}, next_worker_after()},
      []), "PH-007 a non-public diagnostic is accepted with no effect")
    Test.check(denied(diagnose(admitted(), P.Diagnostic{worker_unknown(), False{}}), admitted(), P.UnknownWorker{}),
      "PH-007 a diagnostic from a worker never admitted denied UnknownWorker")
    Test.check(denied(diagnose(revoked(), P.Diagnostic{worker_id(), False{}}), revoked(), P.WrongPhase{}),
      "PH-007 a diagnostic from a revoked worker denied WrongPhase")
    Test.check(denied(diagnose(admitted(), P.ResourceRequest{worker_id(), first_charge()}), admitted(), P.WrongPhase{}),
      "PH-007 a diagnostic given a fact other than a Diagnostic denied WrongPhase")

# Native fast write route (PH-001 "An adapter offers a fast publication route").
def fastpath_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(denied(P.native_write_offered(admitted(), P.revision(admitted()), P.NativeWriteOffered{worker_id()}), admitted(), P.FastPathUnavailable{}),
      "PH-001 a native write offer for an admitted worker denied FastPathUnavailable")
    Test.check(denied(P.native_write_offered(admitted(), P.revision(admitted()), P.Diagnostic{worker_id(), True{}}), admitted(), P.WrongPhase{}),
      "PH-001 a native write offer given another fact denied WrongPhase")

# Session binding and use (family 1).
def session_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(admitted_as(P.open_session(P.empty(seed_identity()), 0n, full_report(), client_evidence()),
      P.State{1n, with_client(), P.NoWorkers{}, P.first_worker()}, []),
      "PH-002 open_session binds the evidence's caller through HostIdentity with no effect")
    Test.check(denied(P.open_session(P.empty(seed_identity()), 0n, no_session_report(), client_evidence()), P.empty(seed_identity()), P.UnsupportedFamily{}),
      "PH-001 open_session on a target without the session family denied UnsupportedFamily")
    Test.check(denied_identity(P.open_session(P.empty(seed_identity()), 0n, full_report(), P.SessionEvidence{caller_client(), I.Inherited{session_unknown()}, True{}}),
      P.empty(seed_identity()), I.UnknownSession{}),
      "PH-002 open_session with evidence inherited from an unbound session denied Identity UnknownSession")
    Test.check(denied(P.open_session(P.empty(seed_identity()), 0n, full_report(), mediated_inventory()), P.empty(seed_identity()), P.WrongPhase{}),
      "PH-001 open_session given a fact other than SessionEvidence denied WrongPhase")
    Test.check(resolved_as(P.use(base(), P.revision(base()), session_client(), claiming_use(), now()), caller_client()),
      "PH-002 a Use claiming another subject on the client's session resolves to the client's caller")
    Test.check(resolved_as(P.use(base(), P.revision(base()), session_worker(), input_use(), now()), caller_client()),
      "PH-002 the worker's Use of its input resolves to the owner's caller, not the worker session's")
    Test.check(P.Error.equal(P.Identity{I.NotHolder{}}, P.Identity{I.NotHolder{}})
      && Bool.not(P.Error.equal(P.Identity{I.NotHolder{}}, P.Identity{I.UnknownSession{}})),
      "PH-001 Error.equal compares the HostIdentity reason inside Identity")

# Every transition at a stale revision.
def revision_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(denied(P.open_session(P.empty(seed_identity()), 1n+P.revision(P.empty(seed_identity())), full_report(), client_evidence()), P.empty(seed_identity()), P.StaleRevision{}),
      "PH-001 open_session at a stale revision denied StaleRevision")
    Test.check(unresolved(P.use(base(), 1n+P.revision(base()), session_client(), claiming_use(), now()), I.StaleRevision{}),
      "PH-001 use at a stale revision denied StaleRevision")
    Test.check(denied(P.admit_worker(base(), 1n+P.revision(base()), accel_profile(), quota_limit(), full_report(),
      mediated_inventory(), session_worker(), input_ref(), now()), base(), P.StaleRevision{}),
      "PH-006 admit_worker at a stale revision denied StaleRevision")
    Test.check(denied(P.charge(admitted(), 1n+P.revision(admitted()), P.ResourceRequest{worker_id(), first_charge()}), admitted(), P.StaleRevision{}),
      "PH-007 charge at a stale revision denied StaleRevision")
    Test.check(denied(P.diagnostic(admitted(), 1n+P.revision(admitted()), P.Diagnostic{worker_id(), False{}}), admitted(), P.StaleRevision{}),
      "PH-007 diagnostic at a stale revision denied StaleRevision")
    Test.check(denied(P.native_write_offered(admitted(), 1n+P.revision(admitted()), P.NativeWriteOffered{worker_id()}), admitted(), P.StaleRevision{}),
      "PH-001 native_write_offered at a stale revision denied StaleRevision")

# The fixed check orders: each input fails two steps and must report the
# earlier one.
def order_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(denied_identity(P.admit_worker(base(), P.revision(base()), accel_profile(), quota_limit(), full_report(),
      P.NativeWriteOffered{worker_id()}, session_worker(), root_ref(), now()), base(), I.NotHolder{}),
      "PH-006 order: the input reference precedes the inventory fact")
    Test.check(denied(admit(accel_profile(), no_publication_report(), P.NativeWriteOffered{worker_id()}), base(), P.WrongPhase{}),
      "PH-006 order: the inventory fact precedes the families")
    Test.check(denied(admit(bare_accel_profile(), cpu_report(), leaky_inventory()), base(), P.UnisolatedAccelerator{}),
      "PH-014 order: accelerator isolation precedes the route inventory")
    Test.check(denied(charge(revoked(), P.ResourceRequest{worker_id(), excess_charge()}), revoked(), P.WrongPhase{}),
      "PH-007 order: the worker's phase precedes its quota")
    Test.check(denied(diagnose(revoked(), P.Diagnostic{worker_id(), True{}}), revoked(), P.WrongPhase{}),
      "PH-007 order: the worker's phase precedes the diagnostic sink")

# Public entry point, run by Tests.bend. Checks are grouped per requirement and
# fixtures are named functions, keeping each group under the native backend's
# arity limit (see the note above HostBindingTests.main).
def main() -> IO(Unit):
  do IO<Unit>:
    accept_checks()
    control_checks()
    report_checks()
    inventory_checks()
    accelerator_checks()
    quota_checks()
    diagnostic_checks()
    fastpath_checks()
    session_checks()
    revision_checks()
    order_checks()
    IO.print("HostPrimitives: 52 checks passed")
