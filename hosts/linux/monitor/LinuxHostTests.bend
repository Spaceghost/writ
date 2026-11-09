import Base
import ./LinuxHost.bend as LH
import ../../../HostConformanceVectors.bend as V
import ../../../HostConformanceTests.bend as CT
import ../../../HostPrimitivesTests.bend as PT
import ../../../HostIdentityTests.bend as IT
import ../../../HostWire.bend as W
import ../../../HostIdentity.bend as I
import ../../../HostPrimitives.bend as P
import ../../../HostPublication.bend as H
import ../../../Frontend.bend as F
import ../../../Transfer.bend as T
import ../../../Test.bend as Test

# Model tests for the Linux host monitor adapter (hosts/linux/monitor/
# LinuxHost.bend; add-linux-host task 1.1; LH-001 and LH-005 model halves,
# and the model consumption of LH-002, LH-003, LH-004, LH-006, LH-007).
#
# Every session, subject, credential, report, inventory, descriptor, and fact
# here is SYNTHETIC MONITOR STATE, standing in for what a real broker would
# report; nothing here authenticates a caller or confines a worker. The
# client session, its root, and its delegation to the worker are opened
# through the shared transitions directly (the client reaches the monitor
# through another frontend, not the Linux worker broker), with
# HostConformanceVectors' fixture evidence, Frontend state, and plan. The
# accelerator profile in `accelerator_*` is a HYPOTHETICAL table that
# `LH.profiles()` does not offer; it exists only to show the shared
# UnisolatedAccelerator path refuses the Linux broker's report.
#
# Groups: constants and the profile table; translators (each named against a
# known `LinuxFact`, each rejection); dispatch over the two channels (every
# refusal asserts full primitive-state equality with its input and no
# effect); profile admission (each required control and each family omitted
# in turn, then the complete report); and the replay of the 37
# HostConformanceVectors vectors through a Linux adapter fixture whose report
# and inventory are `LH.report_of`/`LH.inventory_of` of a broker-shaped fact.
# The replay reuses HostConformanceTests' per-adapter chains and renderers
# (`CT.ph*_ok`, `CT.ph*_line`, `CT.lines_for`) unchanged, with the Linux
# fixture as the adapter. Its lines are printed with the prefix `LINUX `, so
# `grep '^VECTOR PH-'` of the suite output still yields exactly
# verification/portable-host-vectors.txt, and
# `grep '^LINUX VECTOR ' | cut -c7-` yields the Linux replay for `cmp`.
# The replay is the shared harness run with the Linux fixture's identity,
# report, and inventory; it does not pass through `LH.dispatch`, whose launch
# check, session check, Barrier routing, and channel split are covered by the
# dispatch checks, not by the replay.
#
# Not tested here, by nature: that the native broker reports true
# credentials, controls, and inventories, or executes only returned effects
# (Tasks 2 to 4, native evidence under contrib/native-hosts/linux/).
#
# Public entry point: main. Everything else is an implementation helper.

# --- Synthetic broker facts ---------------------------------------------------------

def subject_a() -> Nat:
  V.subject()

def token_of(caller: F.Caller) -> T.CodeId:
  match caller:
    case F.Caller{_, token}:
      token

# The launch record's code token: the worker caller's of the vectors.
def launch_token() -> T.CodeId:
  token_of(V.worker_caller())

def launch_caller() -> F.Caller:
  F.Caller{subject_a(), launch_token()}

# The credential the launch record expects (uid 1000, gid 1000, pid 4242,
# start 917), and five peers that are not it: the parent that created a
# socketpair, a process reusing pid 4242 later, the same pid under another
# uid, the same pid under another gid, and another pid that obtained the
# endpoint.
def launch_credential() -> LH.Credential:
  LH.Credential{1000n, 1000n, 4242n, 917n}

def parent_credential() -> LH.Credential:
  LH.Credential{1000n, 1000n, 4200n, 900n}

def reused_pid_credential() -> LH.Credential:
  LH.Credential{1000n, 1000n, 4242n, 999n}

def other_uid_credential() -> LH.Credential:
  LH.Credential{1001n, 1000n, 4242n, 917n}

def other_gid_credential() -> LH.Credential:
  LH.Credential{1000n, 1001n, 4242n, 917n}

# Another process holding the endpoint: same uid, gid, and start time,
# another pid.
def other_pid_credential() -> LH.Credential:
  LH.Credential{1000n, 1000n, 4243n, 917n}

# A self-consistent credential of another process (uid 2000, pid 5555).
def foreign_credential() -> LH.Credential:
  LH.Credential{2000n, 2000n, 5555n, 41n}

# Descriptor kinds (descriptive only) and the worker's inventory: the private
# result channel, the broker session socket, and the input descriptor
# delivered by SCM_RIGHTS, all mediated.
def kind_result_channel() -> U32:
  101

def kind_broker_socket() -> U32:
  102

def kind_input() -> U32:
  103

def broker_routes() -> +List<LH.LinuxRoute>:
  [LH.LinuxRoute{3n, kind_result_channel(), True{}}, LH.LinuxRoute{4n, kind_broker_socket(), True{}},
    LH.LinuxRoute{5n, kind_input(), True{}}]

# The same inventory with an inherited descriptor the broker does not mediate.
def leaky_routes() -> +List<LH.LinuxRoute>:
  [LH.LinuxRoute{3n, kind_result_channel(), True{}}, LH.LinuxRoute{9n, kind_input(), False{}}]

def fact_with(incarnation: Nat, peer: LH.Credential, endpoint: LH.Endpoint, families: U32, controls: U32,
    routes: +List<LH.LinuxRoute>) -> LH.LinuxFact:
  LH.LinuxFact{subject_a(), launch_token(), incarnation, launch_credential(), peer, endpoint, families, controls,
    routes}

# The complete broker fact: this incarnation, the launched process, every
# family, exactly the profile's controls, the mediated inventory.
def full_fact() -> LH.LinuxFact:
  fact_with(LH.linux_incarnation(), launch_credential(), LH.Launched{}, P.all_families(), LH.required_controls(),
    broker_routes())

def controls_fact(controls: U32) -> LH.LinuxFact:
  fact_with(LH.linux_incarnation(), launch_credential(), LH.Launched{}, P.all_families(), controls, broker_routes())

def families_fact(families: U32) -> LH.LinuxFact:
  fact_with(LH.linux_incarnation(), launch_credential(), LH.Launched{}, families, LH.required_controls(),
    broker_routes())

def peer_fact(peer: LH.Credential) -> LH.LinuxFact:
  fact_with(LH.linux_incarnation(), peer, LH.Launched{}, P.all_families(), LH.required_controls(), broker_routes())

def endpoint_fact(endpoint: LH.Endpoint) -> LH.LinuxFact:
  fact_with(LH.linux_incarnation(), launch_credential(), endpoint, P.all_families(), LH.required_controls(),
    broker_routes())

# A launch record naming incarnation 5, which is no session, profile, or
# successor id of these fixtures.
def stale_incarnation() -> Nat:
  5n

def stale_fact() -> LH.LinuxFact:
  fact_with(stale_incarnation(), launch_credential(), LH.Launched{}, P.all_families(), LH.required_controls(),
    broker_routes())

# The incarnation after restart: 7, which is no session or profile id here.
def linux_successor() -> Nat:
  7n

# A launch record of the successor incarnation (after restart).
def successor_fact() -> LH.LinuxFact:
  fact_with(linux_successor(), launch_credential(), LH.Launched{}, P.all_families(), LH.required_controls(),
    broker_routes())

# The reviewer's probe: another subject (99) with the client's token and a
# self-consistent credential of another process.
def foreign_fact() -> LH.LinuxFact:
  LH.LinuxFact{99n, token_of(V.client_caller()), LH.linux_incarnation(), foreign_credential(), foreign_credential(),
    LH.Launched{}, P.all_families(), LH.required_controls(), broker_routes()}

# The launch subject with another token (the client's).
def other_token_fact() -> LH.LinuxFact:
  LH.LinuxFact{subject_a(), token_of(V.client_caller()), LH.linux_incarnation(), launch_credential(),
    launch_credential(), LH.Launched{}, P.all_families(), LH.required_controls(), broker_routes()}

def leaky_fact() -> LH.LinuxFact:
  fact_with(LH.linux_incarnation(), launch_credential(), LH.Launched{}, P.all_families(), LH.required_controls(),
    leaky_routes())

# A bit no contract family or control names.
def unnamed_bit() -> U32:
  64

def without(+bits: U32, bit: U32) -> U32:
  U32.sub(bits, bit)

def with_bit(bits: U32, bit: U32) -> U32:
  U32.or(bits, bit)

# --- Translation results --------------------------------------------------------------

def report_or_empty(result: LH.ReportResult) -> P.TargetReport:
  match result:
    case LH.Report{report}:
      report
    case LH.NoReport{_}:
      P.TargetReport{0, 0}

def linux_report() -> P.TargetReport:
  report_or_empty(LH.report_of(full_fact()))

def evidence_is(result: LH.EvidenceResult, caller: F.Caller, origin: I.Origin) -> Bool:
  match result:
    case LH.Evidence{P.SessionEvidence{got, +got_origin, delegable}}:
      I.caller_equal(got, caller) && IT.origin_equal(got_origin, origin) && Bool.not(delegable)
    case _:
      False{}

def evidence_rejected(result: LH.EvidenceResult, reason: LH.Rejection) -> Bool:
  match result:
    case LH.NoEvidence{got}:
      LH.Rejection.equal(got, reason)
    case LH.Evidence{_}:
      False{}

def report_is(result: LH.ReportResult, families: U32, controls: U32) -> Bool:
  match result:
    case LH.Report{P.TargetReport{f, c}}:
      U32.is_eq(f, families) && U32.is_eq(c, controls)
    case LH.NoReport{_}:
      False{}

def report_rejected(result: LH.ReportResult, reason: LH.Rejection) -> Bool:
  match result:
    case LH.NoReport{got}:
      LH.Rejection.equal(got, reason)
    case LH.Report{_}:
      False{}

def routes_are(routes: +List<P.RouteFact>, expected: +List<P.RouteFact>) -> Bool:
  match routes expected:
    case Nil{} Nil{}:
      True{}
    case Con{P.RouteFact{ak, am}, at} Con{P.RouteFact{bk, bm}, bt}:
      U32.is_eq(ak, bk) && Bool.not(Bool.xor(am, bm)) && routes_are(at, bt)
    case _ _:
      False{}

def inventory_is(fact: P.Fact, expected: +List<P.RouteFact>) -> Bool:
  match fact:
    case P.Inventory{routes}:
      routes_are(routes, expected)
    case _:
      False{}

# --- The Linux adapter fixture for the conformance vectors --------------------------

# The third binding: the Linux host and incarnation, adapter A's host as the
# foreign one, no prefaced entry, and the broker-shaped report and inventory.
def linux_adapter() -> V.Adapter:
  V.Adapter{LH.linux_host(), LH.linux_incarnation(), linux_successor(), V.host_a(), False{}, linux_report(),
    LH.inventory_of(full_fact())}

def L() -> V.Adapter:
  linux_adapter()

# Fixture helpers retain the Linux-owned provenance alongside shared transitions.
def apply_step(+state: LH.State, step: P.Step) -> LH.State:
  LH.State{P.Step.state(step), LH.credentials(state), LH.clock(state)}

def credentials_equal(a: LH.CredentialRecords, b: LH.CredentialRecords) -> Bool:
  match a b:
    case LH.NoCredentials{} LH.NoCredentials{}: True{}
    case LH.CredentialRecord{ai, as, ac, ar} LH.CredentialRecord{bi, bs, bc, br}:
      Nat.is_eq(ai, bi) && Nat.is_eq(as, bs) && LH.credential_equal(ac, bc) && credentials_equal(ar, br)
    case _ _: False{}

# Policy and credentials only; the independently sampled clock may advance.
def policy_credentials_equal(+a: LH.State, +b: LH.State) -> Bool:
  PT.state_equal(LH.portable(a), LH.portable(b)) && credentials_equal(LH.credentials(a), LH.credentials(b))

# --- Dispatch fixtures (the Linux monitor from `LH.initial()`) ----------------------

def now() -> Nat:
  V.now()

def frame(+state: LH.State, f: LH.BrokerFrame) -> LH.Outcome:
  LH.dispatch(state, LH.FromBroker{f}, LH.Sample{now()})

def worker_frame(+state: LH.State, +session: Nat, bytes: +List<U32>) -> LH.Outcome:
  LH.dispatch(state, LH.FromWorker{session, bytes}, LH.Sample{now()})

def after(+outcome: LH.Outcome) -> LH.State:
  LH.Outcome.state(outcome)

# The client session (id 1), opened through the shared transition.
def with_client() -> LH.State:
  +s = LH.initial()
  +p = LH.portable(s)
  apply_step(s, P.open_session(p, P.revision(p), linux_report(), V.client_evidence(), V.client_role()))

# The client's root on the vectors' Frontend handle and plan.
def rooted_in(+s: LH.State) -> LH.State:
  +p = LH.portable(s)
  apply_step(s, P.issue(p, P.revision(p), V.session_client(), V.fixture_frontend_state(), V.fixture_frontend(), V.fixture_registry(), V.fixture_transfer(), V.root_handle(), V.plan(),
    V.root_rights(), V.root_expires()))

def rooted() -> LH.State:
  rooted_in(with_client())

def launch_outcome() -> LH.Outcome:
  frame(rooted(), LH.Launch{full_fact()})

# The worker session (id 2), opened by the broker's Launch.
def launched() -> LH.State:
  after(launch_outcome())

def root_ref() -> W.Ref:
  V.ref_to(L(), V.Root{})

def input_ref() -> W.Ref:
  V.ref_to(L(), V.Input{})

def delegated_in(+s: LH.State) -> LH.State:
  +p = LH.portable(s)
  apply_step(s, P.delegate(p, P.revision(p), V.session_client(), root_ref(), V.session_worker(), V.root_rights(),
    U32.to_nat(V.input_lifetime()), now()))

# The client delegates its root to the worker session as the input.
def delegated() -> LH.State:
  delegated_in(launched())

def input_use(claim: U32) -> +List<U32>:
  V.use_bytes(input_ref(), claim)

def barrier_of(fact: LH.LinuxFact, request: +List<U32>) -> LH.BrokerFrame:
  LH.Barrier{V.session_worker(), fact, request}

def barrier_on(+s: LH.State, fact: LH.LinuxFact) -> LH.Outcome:
  frame(s, barrier_of(fact, input_use(V.claim_none())))

def admit_outcome() -> LH.Outcome:
  barrier_on(delegated(), full_fact())

def admitted() -> LH.State:
  after(admit_outcome())

def worker() -> Nat:
  P.first_worker()

def release_bytes(ref: W.Ref) -> +List<U32>:
  V.le_bytes(W.wire_version() <> W.tag_release() <> W.width_release() <> V.ref_words(ref, []))

# Three bytes: not a whole word.
def short_bytes() -> +List<U32>:
  [1, 0, 0]

# The worker tries to pass its input on to the client session.
def worker_delegation() -> +List<U32>:
  V.delegate_bytes(input_ref(), V.narrow_rights(), V.narrow_lifetime(), V.session_client())

# --- Outcome assertions -----------------------------------------------------------

def no_effect(+outcome: LH.Outcome) -> Bool:
  PT.effects_equal(LH.Outcome.effects(outcome), [])

def step_denied(outcome: LH.Outcome, +input: LH.State, reason: P.Error) -> Bool:
  match outcome:
    case LH.Stepped{_, _, step}:
      PT.denied(step, LH.portable(input), reason)
    case _:
      False{}

# A shared transition's denial with exactly `reason`, unchanged policy and
# credential records, and no effect; the sampled clock may advance.
def denied_as(+outcome: LH.Outcome, +input: LH.State, reason: P.Error) -> Bool:
  no_effect(outcome) && step_denied(outcome, input, reason) && policy_credentials_equal(LH.Outcome.state(outcome), input)

def step_identity_denied(outcome: LH.Outcome, +input: LH.State, reason: I.Error) -> Bool:
  match outcome:
    case LH.Stepped{_, _, step}:
      PT.denied_identity(step, LH.portable(input), reason)
    case _:
      False{}

def identity_denied(+outcome: LH.Outcome, +input: LH.State, reason: I.Error) -> Bool:
  no_effect(outcome) && step_identity_denied(outcome, input, reason) && policy_credentials_equal(LH.Outcome.state(outcome), input)

def untranslated_as(outcome: LH.Outcome, +input: LH.State, reason: LH.Rejection) -> Bool:
  match outcome:
    case LH.Untranslated{state, got}:
      LH.Rejection.equal(got, reason) && policy_credentials_equal(state, input)
    case _:
      False{}

# A broker fact refused before any transition: exactly `reason`, the input
# state, no effect.
def untranslated(+outcome: LH.Outcome, +input: LH.State, reason: LH.Rejection) -> Bool:
  no_effect(outcome) && untranslated_as(outcome, input, reason)

def undecoded_as(outcome: LH.Outcome, +input: LH.State, reason: W.WireError) -> Bool:
  match outcome:
    case LH.Undecoded{state, got}:
      W.WireError.equal(got, reason) && policy_credentials_equal(state, input)
    case _:
      False{}

def undecoded(+outcome: LH.Outcome, +input: LH.State, reason: W.WireError) -> Bool:
  no_effect(outcome) && undecoded_as(outcome, input, reason)

def unrouted_as(outcome: LH.Outcome, +input: LH.State) -> Bool:
  match outcome:
    case LH.Unrouted{state}:
      policy_credentials_equal(state, input)
    case _:
      False{}

def unrouted(+outcome: LH.Outcome, +input: LH.State) -> Bool:
  no_effect(outcome) && unrouted_as(outcome, input)

def checked_as(outcome: LH.Outcome, +input: LH.State, +slot: Nat, caller: F.Caller) -> Bool:
  match outcome:
    case LH.Checked{state, P.Granted{+entry, got}}:
      policy_credentials_equal(state, input) && Nat.is_eq(I.entry_slot(entry), slot) && I.caller_equal(got, caller)
        && W.Ref.equal(P.entry_ref(P.identity(LH.portable(input)), entry), input_ref())
    case _:
      False{}

# A read-only use granted at `slot` with effective caller `caller`, the input
# state, no effect.
def checked_at(+outcome: LH.Outcome, +input: LH.State, +slot: Nat, caller: F.Caller) -> Bool:
  no_effect(outcome) && checked_as(outcome, input, slot, caller)

def admitted_with(+outcome: LH.Outcome, +revision: Nat, effects: +List<P.Effect>) -> Bool:
  match outcome:
    case LH.Opened{state, _}:
      Nat.is_eq(P.revision(LH.portable(state)), revision) && PT.effects_equal([], effects)
    case LH.Stepped{_, _, P.Admitted{state, got}}:
      Nat.is_eq(P.revision(state), revision) && PT.effects_equal(got, effects)
    case _:
      False{}

# The worker the retained state records for `id`: Running, on the worker
# session, with the input reference rebuilt from the table.
def worker_running(found: P.WorkerLookup, +session: Nat, +input: W.Ref) -> Bool:
  match found:
    case P.OneWorker{+w}:
      P.is_running(P.worker_phase(w)) && Nat.is_eq(P.worker_session(w), session)
        && W.Ref.equal(P.worker_input(w), input)
    case _:
      False{}

def quota_used(found: P.WorkerLookup) -> Nat:
  match found:
    case P.OneWorker{w}:
      P.worker_quota_used(w)
    case _:
      I.no_id()

def bound_v1(found: P.BindingLookup) -> Bool:
  match found:
    case P.OneBinding{profile}:
      Nat.is_eq(profile, LH.linux_worker_v1())
    case _:
      False{}

def session_is(found: I.SessionLookup, caller: F.Caller) -> Bool:
  match found:
    case I.OneSession{+s}:
      I.caller_equal(I.session_caller(s), caller) && Bool.not(I.session_delegable(s))
        && IT.origin_equal(I.session_origin(s), I.Authenticated{})
    case _:
      False{}

# --- Profile checks ---------------------------------------------------------------

def table_is_v1(profiles: P.Profiles) -> Bool:
  match profiles:
    case P.Profiles{P.Configured{P.Profile{id, families, controls, P.Cpu{}}, quota}, P.NoProfiles{}}:
      Nat.is_eq(id, LH.linux_worker_v1()) && U32.is_eq(families, P.all_families())
        && U32.is_eq(controls, V.cpu_controls()) && Nat.is_eq(quota, LH.quota_limit())
    case _:
      False{}

def initial_ok() -> Bool:
  +s = LH.portable(LH.initial())
  P.valid(s) && Nat.is_eq(P.revision(s), 0n) && Nat.is_eq(I.host(P.identity(s)), LH.linux_host())
    && Nat.is_eq(I.incarnation(P.identity(s)), LH.linux_incarnation()) && table_is_v1(P.profiles(s))

def constants_ok() -> Bool:
  Bool.not(Nat.is_eq(LH.linux_host(), 0n)) && Bool.not(Nat.is_eq(LH.linux_incarnation(), 0n))
    && Bool.not(Nat.is_eq(LH.linux_host(), V.host_a())) && Bool.not(Nat.is_eq(LH.linux_host(), V.host_b()))
    && String.eq(LH.profile_name(), "linux-worker-v1") && Bool.not(Nat.is_eq(LH.quota_limit(), 0n))

def omitting_control(bit: U32) -> Bool:
  denied_as(barrier_on(delegated(), controls_fact(without(LH.required_controls(), bit))), delegated(),
    P.MissingControl{})

def omitting_family(bit: U32) -> Bool:
  denied_as(barrier_on(delegated(), families_fact(without(P.all_families(), bit))), delegated(),
    P.UnsupportedFamily{})

def every_family_required() -> Bool:
  omitting_family(P.family_session()) && omitting_family(P.family_worker()) && omitting_family(P.family_artifact())
    && omitting_family(P.family_publication()) && omitting_family(P.family_revocation())

def launch_without_session_family() -> Bool:
  denied_as(frame(rooted(), LH.Launch{families_fact(without(P.all_families(), P.family_session()))}), rooted(),
    P.UnsupportedFamily{})

def complete_report_admits() -> Bool:
  admitted_with(admit_outcome(), 1n+P.revision(LH.portable(delegated())), [P.DeliverInputs{worker(), input_ref()}])
    && PT.effects_equal(LH.Outcome.effects(admit_outcome()), [P.DeliverInputs{worker(), input_ref()}])

# The state the monitor retains before the broker delivers already records
# the worker Running on the input the effect names.
def retained_before_delivery() -> Bool:
  worker_running(P.worker_at(P.workers(LH.portable(admitted())), worker()), V.session_worker(), input_ref())

# Only `linux-worker-v1` is configured: a worker session under any other
# profile id is refused by the shared transition.
def other_profile_unknown() -> Bool:
  +s = LH.portable(rooted())
  PT.denied(P.open_session(s, P.revision(s), linux_report(), V.worker_evidence(), P.WorkerRole{2n}), s,
    P.UnknownProfile{})

# HYPOTHETICAL accelerator table (not offered by `LH.profiles()`).
def accelerator_profiles() -> P.Profiles:
  P.Profiles{P.Configured{P.Profile{LH.linux_worker_v1(), P.all_families(), LH.required_controls(), P.Accelerator{}},
    LH.quota_limit()}, P.NoProfiles{}}

def accelerator_delegated() -> LH.State:
  +s = P.empty(I.empty(LH.linux_host(), LH.linux_incarnation()), accelerator_profiles())
  +client = P.Step.state(P.open_session(s, P.revision(s), linux_report(), V.client_evidence(), V.client_role()))
  # Synthetic clock state isolates the accelerator decision, not host recovery.
  delegated_in(after(frame(rooted_in(LH.State{client, LH.NoCredentials{}, LH.LiveClock{now()}}), LH.Launch{full_fact()})))

def accelerator_refused() -> Bool:
  denied_as(barrier_on(accelerator_delegated(), full_fact()), accelerator_delegated(), P.UnisolatedAccelerator{})

# --- Checks -------------------------------------------------------------------------

def profile_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(constants_ok(), "LH-001 linux_host and linux_incarnation are nonzero, differ from adapters A and B, and the profile is named linux-worker-v1 with a nonzero quota")
    Test.check(initial_ok(), "LH-001 initial() is a valid empty state on the Linux host and incarnation whose only configured profile is linux-worker-v1: every family, every control but accelerator isolation, Cpu, quota_limit")
    Test.check(other_profile_unknown(), "LH-001 a worker session under any profile id but linux-worker-v1 is denied UnknownProfile with the policy state unchanged and no effect")
    Test.check(omitting_control(P.control_address_isolation()), "LH-005 a barrier report without control_address_isolation is denied MissingControl with the policy state unchanged and no effect")
    Test.check(omitting_control(P.control_no_ambient_network()), "LH-005 a barrier report without control_no_ambient_network is denied MissingControl with the policy state unchanged and no effect")
    Test.check(omitting_control(P.control_output_mediation()), "LH-005 a barrier report without control_output_mediation is denied MissingControl with the policy state unchanged and no effect")
    Test.check(omitting_control(P.control_quota()), "LH-005 a barrier report without control_quota is denied MissingControl with the policy state unchanged and no effect")
    Test.check(omitting_control(P.control_no_inherited_routes()), "LH-005 a barrier report without control_no_inherited_routes is denied MissingControl with the policy state unchanged and no effect")

def admission_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(every_family_required(), "LH-001 a barrier report omitting any one of the five families is denied UnsupportedFamily with the policy state unchanged and no effect")
    Test.check(launch_without_session_family(), "LH-001 a Launch whose report omits family_session is denied UnsupportedFamily by open_session with the policy state unchanged and no effect")
    Test.check(complete_report_admits(), "LH-001 LH-003 a barrier report with every required control admits once and its only effect, in the step and in Outcome.effects, is one DeliverInputs naming the worker's input")
    Test.check(retained_before_delivery(), "LH-003 the state retained before DeliverInputs records the worker Running on the worker session with the delivered input reference")
    Test.check(accelerator_refused(), "LH-001 under a hypothetical accelerator profile the Linux report is denied UnisolatedAccelerator by the shared path with the policy state unchanged and no effect")
    Test.check(denied_as(barrier_on(delegated(), leaky_fact()), delegated(), P.UnmediatedRoute{}), "LH-004 a barrier inventory with an unmediated inherited descriptor is denied UnmediatedRoute with the policy state unchanged and no effect")

# --- Translator checks --------------------------------------------------------------

def translator_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(evidence_is(LH.session_evidence_of(full_fact(), LH.linux_incarnation()), launch_caller(), I.Authenticated{}), "LH-002 session_evidence_of gives the launch record's subject and token, Authenticated, non-delegable")
    Test.check(evidence_is(LH.session_evidence_of(endpoint_fact(LH.InheritedFrom{1n}), LH.linux_incarnation()), launch_caller(), I.Inherited{1n}) && evidence_is(LH.session_evidence_of(endpoint_fact(LH.TransferredFrom{1n}), LH.linux_incarnation()), launch_caller(), I.Transferred{1n}), "LH-007 session_evidence_of reports an inherited or transferred endpoint as Inherited or Transferred from that session")
    Test.check(evidence_rejected(LH.session_evidence_of(stale_fact(), LH.linux_incarnation()), LH.StaleLaunch{}), "LH-002 session_evidence_of rejects a launch record from another monitor incarnation StaleLaunch")
    Test.check(evidence_rejected(LH.session_evidence_of(peer_fact(parent_credential()), LH.linux_incarnation()), LH.PeerMismatch{}), "LH-002 session_evidence_of rejects a parent-created socketpair peer PeerMismatch")
    Test.check(evidence_rejected(LH.session_evidence_of(peer_fact(reused_pid_credential()), LH.linux_incarnation()), LH.PeerMismatch{}), "LH-002 session_evidence_of rejects a reused pid with another start time PeerMismatch")
    Test.check(evidence_rejected(LH.session_evidence_of(peer_fact(other_uid_credential()), LH.linux_incarnation()), LH.PeerMismatch{}), "LH-002 session_evidence_of rejects a peer under another uid PeerMismatch")
    Test.check(evidence_rejected(LH.session_evidence_of(peer_fact(other_pid_credential()), LH.linux_incarnation()), LH.PeerMismatch{}), "LH-002 session_evidence_of rejects an endpoint held by another pid PeerMismatch")
    Test.check(evidence_rejected(LH.session_evidence_of(peer_fact(other_gid_credential()), LH.linux_incarnation()), LH.PeerMismatch{}), "LH-002 session_evidence_of rejects a peer under another gid PeerMismatch")
    Test.check(report_is(LH.report_of(full_fact()), P.all_families(), LH.required_controls()), "LH-001 report_of copies the binding's families and established controls exactly")
    Test.check(report_rejected(LH.report_of(families_fact(with_bit(P.all_families(), unnamed_bit()))), LH.UnknownFamily{}), "LH-001 report_of rejects a family bit outside all_families UnknownFamily")
    Test.check(report_rejected(LH.report_of(controls_fact(with_bit(LH.required_controls(), P.control_accelerator_isolation()))), LH.UncreditedControl{}), "LH-001 report_of rejects an accelerator isolation bit the Linux broker cannot credit UncreditedControl")
    Test.check(report_rejected(LH.report_of(controls_fact(with_bit(LH.required_controls(), unnamed_bit()))), LH.UncreditedControl{}), "LH-001 report_of rejects an unnamed control bit UncreditedControl")
    Test.check(inventory_is(LH.inventory_of(full_fact()), [P.RouteFact{kind_result_channel(), True{}}, P.RouteFact{kind_broker_socket(), True{}}, P.RouteFact{kind_input(), True{}}]) && inventory_is(LH.inventory_of(leaky_fact()), [P.RouteFact{kind_result_channel(), True{}}, P.RouteFact{kind_input(), False{}}]), "LH-004 inventory_of gives one route per descriptor in order with its kind and mediation and no descriptor number")

# --- Dispatch checks ----------------------------------------------------------------

def launch_ok() -> Bool:
  admitted_with(launch_outcome(), 1n+P.revision(LH.portable(rooted())), [])
    && session_is(I.session_at(I.sessions(P.identity(LH.portable(launched()))), V.session_worker()), launch_caller())
    && bound_v1(P.binding_at(P.bindings(LH.portable(launched())), V.session_worker()))

def charged() -> LH.State:
  after(frame(admitted(), LH.Usage{worker(), 1000n}))

def usage_ok() -> Bool:
  admitted_with(frame(admitted(), LH.Usage{worker(), 1000n}), 1n+P.revision(LH.portable(admitted())), [])
    && Nat.is_eq(quota_used(P.worker_at(P.workers(LH.portable(charged())), worker())), 1000n)

# The monitor restarted as `linux_successor()` from the admitted state.
def restarted() -> LH.State:
  +s = admitted()
  LH.Outcome.state(LH.restart(s, P.revision(LH.portable(s)), linux_successor()))

def restart_ok() -> Bool:
  Nat.is_eq(I.incarnation(P.identity(LH.portable(restarted()))), linux_successor())
    && admitted_with(frame(restarted(), LH.Launch{successor_fact()}), 1n+P.revision(LH.portable(restarted())), [])
    && session_is(I.session_at(I.sessions(P.identity(LH.portable(after(frame(restarted(), LH.Launch{successor_fact()}))))),
      I.first_slot()), launch_caller())

def barrier_session(session: Nat) -> LH.Outcome:
  frame(delegated(), LH.Barrier{session, full_fact(), input_use(V.claim_none())})

def restart_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(untranslated(frame(restarted(), LH.Launch{full_fact()}), restarted(), LH.StaleLaunch{}), "LH-002 LH-008 after a restart a Launch carrying the previous incarnation's launch record is refused StaleLaunch with the policy state unchanged and no effect")
    Test.check(restart_ok(), "LH-002 after a restart a Launch carrying the successor incarnation's launch record opens a worker session with the launch caller and no effect")
    Test.check(untranslated(frame(restarted(), barrier_of(full_fact(), input_use(V.claim_none()))), restarted(), LH.StaleLaunch{}), "LH-002 LH-008 after a restart a Barrier carrying the previous incarnation's launch record is refused StaleLaunch with the policy state unchanged and no effect")

def session_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(untranslated(barrier_on(delegated(), foreign_fact()), delegated(), LH.SessionMismatch{}), "LH-002 a Barrier on the worker session whose fact names another subject, token, and process is refused SessionMismatch with the policy state unchanged and no effect")
    Test.check(untranslated(barrier_on(delegated(), other_token_fact()), delegated(), LH.SessionMismatch{}), "LH-002 a Barrier whose fact names the session's subject with another token is refused SessionMismatch with the policy state unchanged and no effect")
    Test.check(untranslated(barrier_session(V.session_client()), delegated(), LH.SessionMismatch{}), "LH-002 a Barrier attributing the worker's fact to the client session is refused SessionMismatch with the policy state unchanged and no effect")
    Test.check(untranslated(barrier_session(9n), delegated(), LH.SessionMismatch{}), "LH-002 a Barrier naming a session the identity table does not hold is refused SessionMismatch with the policy state unchanged and no effect")

def launch_dispatch_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(launch_ok(), "LH-002 a broker Launch opens one non-delegable worker session with the launch caller bound to linux-worker-v1 and no effect")
    Test.check(untranslated(frame(rooted(), LH.Launch{peer_fact(parent_credential())}), rooted(), LH.PeerMismatch{}), "LH-002 a Launch from a socketpair parent is refused PeerMismatch before any transition with the policy state unchanged and no effect")
    Test.check(untranslated(frame(rooted(), LH.Launch{stale_fact()}), rooted(), LH.StaleLaunch{}), "LH-002 a Launch with another incarnation's launch record is refused StaleLaunch with the policy state unchanged and no effect")
    Test.check(untranslated(frame(rooted(), LH.Launch{families_fact(with_bit(P.all_families(), unnamed_bit()))}), rooted(), LH.UnknownFamily{}), "LH-001 a Launch reporting an unknown family bit is refused UnknownFamily with the policy state unchanged and no effect")
    Test.check(untranslated(frame(rooted(), LH.Launch{controls_fact(with_bit(LH.required_controls(), P.control_accelerator_isolation()))}), rooted(), LH.UncreditedControl{}), "LH-001 a Launch crediting accelerator isolation is refused UncreditedControl with the policy state unchanged and no effect")

def barrier_dispatch_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(untranslated(barrier_on(delegated(), stale_fact()), delegated(), LH.StaleLaunch{}), "LH-002 a Barrier with another incarnation's launch record is refused StaleLaunch with the policy state unchanged and no effect")
    Test.check(untranslated(barrier_on(delegated(), peer_fact(reused_pid_credential())), delegated(), LH.PeerMismatch{}), "LH-002 a Barrier from a reused pid is refused PeerMismatch with the policy state unchanged and no effect")
    Test.check(untranslated(barrier_on(delegated(), controls_fact(with_bit(LH.required_controls(), unnamed_bit()))), delegated(), LH.UncreditedControl{}), "LH-001 a Barrier crediting an unnamed control is refused UncreditedControl with the policy state unchanged and no effect")
    Test.check(undecoded(frame(delegated(), barrier_of(full_fact(), short_bytes())), delegated(), W.BadLength{}), "LH-006 a Barrier whose request snapshot is not a whole frame is Undecoded with the policy state unchanged and no effect")
    Test.check(unrouted(frame(delegated(), barrier_of(full_fact(), worker_delegation())), delegated()), "LH-006 a Barrier whose request is not a Use admits nothing: Unrouted with the policy state unchanged and no effect")
    Test.check(policy_credentials_equal(after(frame(delegated(), barrier_of(full_fact(), input_use(V.claim_other())))), admitted()), "LH-002 a Barrier request claiming subject B admits exactly as the unclaimed request")

def worker_dispatch_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(checked_at(worker_frame(admitted(), V.session_worker(), input_use(V.claim_other())), admitted(), V.slot_of(L(), V.Input{}), V.client_caller()) && checked_at(worker_frame(admitted(), V.session_worker(), input_use(V.claim_none())), admitted(), V.slot_of(L(), V.Input{}), V.client_caller()), "LH-002 a worker Use claiming subject B on A's session resolves to A's entry, reference, and owner, as with no claim, read-only with no effect")
    Test.check(identity_denied(worker_frame(admitted(), V.session_worker(), worker_delegation()), admitted(), I.NotDelegable{}), "LH-007 a worker Delegate from the worker session is denied NotDelegable with the policy state unchanged and no effect")
    Test.check(undecoded(worker_frame(admitted(), V.session_worker(), short_bytes()), admitted(), W.BadLength{}), "LH-006 worker bytes that are not a whole frame are Undecoded with the policy state unchanged and no effect")
    Test.check(unrouted(worker_frame(admitted(), V.session_worker(), V.complete_bytes(input_ref())), admitted()) && unrouted(worker_frame(admitted(), V.session_worker(), release_bytes(input_ref())), admitted()), "LH-006 a worker Complete or Release runs no transition in section 1: Unrouted with the policy state unchanged and no effect")
    Test.check(usage_ok(), "PH-007 a broker Usage within quota_limit is charged once with no effect")
    Test.check(denied_as(frame(charged(), LH.Usage{worker(), 25n}), charged(), P.QuotaExhausted{}), "PH-007 a broker Usage past quota_limit is denied QuotaExhausted with the policy state unchanged and no effect")
    Test.check(denied_as(frame(admitted(), LH.Emission{worker(), True{}}), admitted(), P.DiagnosticSink{}) && admitted_with(frame(admitted(), LH.Emission{worker(), False{}}), 1n+P.revision(LH.portable(admitted())), []), "LH-009 a public worker emission is denied DiagnosticSink with the policy state unchanged; a confined one is admitted with no effect")

# --- Conformance replay through the Linux adapter -----------------------------------

def same(ok: Bool, line: String, expected: String) -> Bool:
  ok && String.eq(line, expected)

def linux_lines() -> List<&2, String>:
  CT.lines_for(L())

def compare_line() -> String:
  CT.line_of("PH-012-1", "compare", CT.compare_outcome(CT.strings_equal(linux_lines(), CT.lines_for(V.adapter_a()))
    && CT.strings_equal(linux_lines(), CT.lines_for(V.adapter_b())), List.length(&2, String, linux_lines())))

def fixture_ok() -> Bool:
  U32.is_eq(P.report_families(V.adapter_report(L())), P.all_families())
    && U32.is_eq(P.report_controls(V.adapter_report(L())), LH.required_controls())
    && inventory_is(V.adapter_inventory(L()), [P.RouteFact{kind_result_channel(), True{}}, P.RouteFact{kind_broker_socket(), True{}}, P.RouteFact{kind_input(), True{}}])
    && Nat.is_eq(V.adapter_host(L()), LH.linux_host()) && Nat.is_eq(V.adapter_incarnation(L()), LH.linux_incarnation())

# The 37 replay lines: the 36 decision lines, then the comparison line.
def replay_lines() -> List<&2, String>:
  List.append(&2, String, linux_lines(), [compare_line()])

# Keep each vector in a separate diagnostic so bounded hosts can emit it.
def emit_replay(lines: List<&2, String>) -> IO(Unit):
  match lines:
    case Nil{}:
      IO.pure(Unit, Unit{})
    case Con{line, rest}:
      do IO<Unit>:
        IO.print("LINUX " ++ line)
        emit_replay(rest)

def replay_plan_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(fixture_ok(), "LH-010 the Linux adapter fixture is the Linux host and incarnation with report_of and inventory_of of the broker fact")
    Test.check(same(CT.ph009_1_ok(L()), CT.ph009_1_line(L()), V.expected_ph009_1()), "LH-010 PH-009-1 replays on the Linux adapter with adapter A's and B's outcome and line")
    Test.check(same(CT.ph005_1_ok(L()), CT.ph005_1_line(L()), V.expected_ph005_1()), "LH-010 PH-005-1 replays on the Linux adapter with adapter A's and B's outcome and line")
    Test.check(same(CT.ph005_2_ok(L()), CT.ph005_2_line(L()), V.expected_ph005_2()), "LH-010 PH-005-2 replays on the Linux adapter with adapter A's and B's outcome and line")
    Test.check(same(CT.ph005_3_ok(L()), CT.ph005_3_line(L()), V.expected_ph005_3()), "LH-010 PH-005-3 replays on the Linux adapter with adapter A's and B's outcome and line")
    Test.check(same(CT.ph005_4_ok(L()), CT.ph005_4_line(L()), V.expected_ph005_4()), "LH-010 PH-005-4 replays on the Linux adapter with adapter A's and B's outcome and line")
    Test.check(same(CT.ph005_5_ok(L()), CT.ph005_5_line(L()), V.expected_ph005_5()), "LH-010 PH-005-5 replays on the Linux adapter with adapter A's and B's outcome and line")
    Test.check(same(CT.ph005_6_ok(L()), CT.ph005_6_line(L()), V.expected_ph005_6()), "LH-010 PH-005-6 replays on the Linux adapter with adapter A's and B's outcome and line")

def replay_gap_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(same(CT.ph005_7_ok(L()), CT.ph005_7_line(L()), V.expected_ph005_7()), "LH-010 PH-005-7 replays on the Linux adapter with adapter A's and B's outcome and line")
    Test.check(same(CT.ph005_8_ok(L()), CT.ph005_8_line(L()), V.expected_ph005_8()), "LH-010 PH-005-8 replays on the Linux adapter with adapter A's and B's outcome and line")
    Test.check(same(CT.ph005_9_ok(L()), CT.ph005_9_line(L()), V.expected_ph005_9()), "LH-010 PH-005-9 replays on the Linux adapter with adapter A's and B's outcome and line")
    Test.check(same(CT.ph005_10_ok(L()), CT.ph005_10_line(L()), V.expected_ph005_10()), "LH-010 PH-005-10 replays on the Linux adapter with adapter A's and B's outcome and line")
    Test.check(same(CT.ph005_11_ok(L()), CT.ph005_11_line(L()), V.expected_ph005_11()), "LH-010 PH-005-11 replays on the Linux adapter with adapter A's and B's outcome and line")
    Test.check(same(CT.ph005_12_ok(L()), CT.ph005_12_line(L()), V.expected_ph005_12()), "LH-010 PH-005-12 replays on the Linux adapter with adapter A's and B's outcome and line")
    Test.check(same(CT.ph005_13_ok(L()), CT.ph005_13_line(L()), V.expected_ph005_13()), "LH-010 PH-005-13 replays on the Linux adapter with adapter A's and B's outcome and line")
    Test.check(same(CT.ph005_14_ok(L()), CT.ph005_14_line(L()), V.expected_ph005_14()), "LH-010 PH-005-14 replays on the Linux adapter with adapter A's and B's outcome and line")

def replay_caller_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(same(CT.ph002_1_ok(L()), CT.ph002_1_line(L()), V.expected_ph002_1()), "LH-010 PH-002-1 replays on the Linux adapter with adapter A's and B's outcome and line")
    Test.check(same(CT.ph002_2_ok(L()), CT.ph002_2_line(L()), V.expected_ph002_2()), "LH-010 PH-002-2 replays on the Linux adapter with adapter A's and B's outcome and line")
    Test.check(same(CT.ph002_3_ok(L()), CT.ph002_3_line(L()), V.expected_ph002_3()), "LH-010 PH-002-3 replays on the Linux adapter with adapter A's and B's outcome and line")
    Test.check(same(CT.ph002_4_ok(L()), CT.ph002_4_line(L()), V.expected_ph002_4()), "LH-010 PH-002-4 replays on the Linux adapter with adapter A's and B's outcome and line")
    Test.check(same(CT.ph002_5_ok(L()), CT.ph002_5_line(L()), V.expected_ph002_5()), "LH-010 PH-002-5 replays on the Linux adapter with adapter A's and B's outcome and line")
    Test.check(same(CT.ph003_1_ok(L()), CT.ph003_1_line(L()), V.expected_ph003_1()), "LH-010 PH-003-1 replays on the Linux adapter with adapter A's and B's outcome and line")
    Test.check(same(CT.ph003_2_ok(L()), CT.ph003_2_line(L()), V.expected_ph003_2()), "LH-010 PH-003-2 replays on the Linux adapter with adapter A's and B's outcome and line")
    Test.check(same(CT.ph003_3_ok(L()), CT.ph003_3_line(L()), V.expected_ph003_3()), "LH-010 PH-003-3 replays on the Linux adapter with adapter A's and B's outcome and line")

def replay_revocation_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(same(CT.ph010_1_ok(L()), CT.ph010_1_line(L()), V.expected_ph010_1()), "LH-010 PH-010-1 replays on the Linux adapter with adapter A's and B's outcome and line")
    Test.check(same(CT.ph009_2_ok(L()), CT.ph009_2_line(L()), V.expected_ph009_2()), "LH-010 PH-009-2 replays on the Linux adapter with adapter A's and B's outcome and line")
    Test.check(same(CT.ph010_2_ok(L()), CT.ph010_2_line(L()), V.expected_ph010_2()), "LH-010 PH-010-2 replays on the Linux adapter with adapter A's and B's outcome and line")
    Test.check(same(CT.ph010_3_ok(L()), CT.ph010_3_line(L()), V.expected_ph010_3()), "LH-010 PH-010-3 replays on the Linux adapter with adapter A's and B's outcome and line")
    Test.check(same(CT.ph010_4_ok(L()), CT.ph010_4_line(L()), V.expected_ph010_4()), "LH-010 PH-010-4 replays on the Linux adapter with adapter A's and B's outcome and line")
    Test.check(same(CT.ph010_5_ok(L()), CT.ph010_5_line(L()), V.expected_ph010_5()), "LH-010 PH-010-5 replays on the Linux adapter with adapter A's and B's outcome and line")
    Test.check(same(CT.ph010_6_ok(L()), CT.ph010_6_line(L()), V.expected_ph010_6()), "LH-010 PH-010-6 replays on the Linux adapter with adapter A's and B's outcome and line")

def replay_restart_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(same(CT.ph009_3_ok(L()), CT.ph009_3_line(L()), V.expected_ph009_3()), "LH-010 PH-009-3 replays on the Linux adapter with adapter A's and B's outcome and line")
    Test.check(same(CT.ph004_1_ok(L()), CT.ph004_1_line(L()), V.expected_ph004_1()), "LH-010 PH-004-1 replays on the Linux adapter with adapter A's and B's outcome and line")
    Test.check(same(CT.ph004_2_ok(L()), CT.ph004_2_line(L()), V.expected_ph004_2()), "LH-010 PH-004-2 replays on the Linux adapter with adapter A's and B's outcome and line")
    Test.check(same(CT.ph004_3_ok(L()), CT.ph004_3_line(L()), V.expected_ph004_3()), "LH-010 PH-004-3 replays on the Linux adapter with adapter A's and B's outcome and line")
    Test.check(same(CT.ph009_4_ok(L()), CT.ph009_4_line(L()), V.expected_ph009_4()), "LH-010 PH-009-4 replays on the Linux adapter with adapter A's and B's outcome and line")
    Test.check(same(CT.ph009_5_ok(L()), CT.ph009_5_line(L()), V.expected_ph009_5()), "LH-010 PH-009-5 replays on the Linux adapter with adapter A's and B's outcome and line")

def replay_compare_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(CT.strings_equal(linux_lines(), V.expected_lines()) && CT.strings_equal(linux_lines(), CT.lines_for(V.adapter_a())) && CT.strings_equal(linux_lines(), CT.lines_for(V.adapter_b())), "LH-010 the Linux adapter's 36 decision lines equal V.expected_lines() and adapters A's and B's")
    Test.check(String.eq(compare_line(), V.expected_ph012_1()), "LH-010 PH-012-1 the Linux adapter compared with adapters A and B renders the expected compare line")
    emit_replay(replay_lines())

# Synthetic framed facts only. These exercise the actual LINUXB decode/serve
# path; they do not authenticate a process, establish a kernel observation,
# enforce a descriptor boundary, or satisfy native Linux acceptance.
# The launch record and current peer are monitor-owned test fixtures. The
# broker must bind each Barrier's launch record to the session; the adapter
# compares the credentials in one frame and does not retain that binding.

def synthetic_words_of_token(token: T.CodeId, tail: +List<U32>) -> +List<U32>:
  match token:
    case T.CodeId{a, b, c, d, e, f, g, h}:
      a <> b <> c <> d <> e <> f <> g <> h <> tail

def synthetic_words_of_credential(credential: LH.Credential, tail: +List<U32>) -> +List<U32>:
  match credential:
    case LH.Credential{uid, gid, pid, +start}:
      U32.from_nat(uid) <> U32.from_nat(gid) <> U32.from_nat(pid) <>
        U32.from_nat(Nat.mod(start, LH.word_span())) <> U32.from_nat(Nat.div(start, LH.word_span())) <> tail

# Version 1's three mediated routes are fixed test data, not an OS inventory.
def synthetic_route_words(tail: +List<U32>) -> +List<U32>:
  3 <> 3 <> 101 <> 1 <> 4 <> 102 <> 1 <> 5 <> 103 <> 1 <> tail

def synthetic_fact_words(subject: Nat, token: T.CodeId, incarnation: Nat, launch: LH.Credential,
    peer: LH.Credential, tail: +List<U32>) -> +List<U32>:
  U32.from_nat(subject) <> synthetic_words_of_token(token, U32.from_nat(incarnation) <>
    synthetic_words_of_credential(launch, synthetic_words_of_credential(peer,
      0 <> 0 <> P.all_families() <> LH.required_controls() <> synthetic_route_words(tail))))

def synthetic_framed(tag: U32, +body: +List<U32>) -> +List<U32>:
  V.le_bytes(LH.frame_version() <> tag <> U32.from_nat(List.length(&2, U32, body)) <> body)

def synthetic_launch_bytes(+launch: LH.Credential, +peer: LH.Credential, incarnation: Nat) -> +List<U32>:
  synthetic_framed(LH.frame_launch(), synthetic_fact_words(subject_a(), launch_token(), incarnation, launch, peer, []))

def synthetic_barrier_bytes(session: Nat, subject: Nat, token: T.CodeId, incarnation: Nat,
    launch: LH.Credential, peer: LH.Credential) -> +List<U32>:
  +request = input_use(V.claim_none())
  synthetic_framed(LH.frame_barrier(), U32.from_nat(session) <> synthetic_fact_words(subject, token, incarnation, launch, peer,
    U32.from_nat(List.length(&2, U32, request)) <> request))

def synthetic_launch_served(launch: LH.Credential, peer: LH.Credential, incarnation: Nat) -> LH.Served:
  LH.serve(rooted(), synthetic_launch_bytes(launch, peer, incarnation), LH.Sample{now()})

def synthetic_barrier_served(session: Nat, subject: Nat, token: T.CodeId, incarnation: Nat,
    launch: LH.Credential, peer: LH.Credential) -> LH.Served:
  LH.serve(delegated(), synthetic_barrier_bytes(session, subject, token, incarnation, launch, peer), LH.Sample{now()})

def synthetic_denied(+served: LH.Served, +expected: LH.State, reason: LH.Rejection) -> Bool:
  match served:
    case LH.Served{outcome}:
      untranslated(outcome, expected, reason) && policy_credentials_equal(LH.next(served), expected)
        && PT.effects_equal(LH.served_effects(served), [])
    case _:
      False{}

def synthetic_launch_denied(peer: LH.Credential, reason: LH.Rejection) -> Bool:
  synthetic_denied(synthetic_launch_served(launch_credential(), peer, LH.linux_incarnation()), rooted(), reason)

def synthetic_barrier_denied(peer: LH.Credential, reason: LH.Rejection) -> Bool:
  synthetic_denied(synthetic_barrier_served(V.session_worker(), subject_a(), launch_token(), LH.linux_incarnation(),
    launch_credential(), peer), delegated(), reason)

def synthetic_launch_accepted(served: LH.Served, credential: LH.Credential) -> Bool:
  match served:
    case LH.Served{+outcome}:
      admitted_with(outcome, 1n+P.revision(LH.portable(rooted())), [])
        && PT.state_equal(LH.portable(LH.Outcome.state(outcome)), LH.portable(launched()))
        && credentials_equal(LH.credentials(LH.Outcome.state(outcome)),
          LH.CredentialRecord{LH.linux_incarnation(), V.session_worker(), credential, LH.NoCredentials{}})
        && session_is(I.session_at(I.sessions(P.identity(LH.portable(LH.Outcome.state(outcome)))), V.session_worker()),
          launch_caller())
    case _:
      False{}

def synthetic_valid_launch() -> Bool:
  synthetic_launch_accepted(synthetic_launch_served(launch_credential(), launch_credential(), LH.linux_incarnation()), launch_credential())

def synthetic_valid_barrier() -> Bool:
  +served = synthetic_barrier_served(V.session_worker(), subject_a(), launch_token(), LH.linux_incarnation(),
    launch_credential(), launch_credential())
  policy_credentials_equal(LH.next(served), admitted())
    && PT.effects_equal(LH.served_effects(served), [P.DeliverInputs{worker(), input_ref()}])

def synthetic_high_start() -> LH.Credential:
  LH.Credential{1000n, 1000n, 4242n, Nat.add(LH.word_span(), 917n)}

def synthetic_different_high_start() -> LH.Credential:
  LH.Credential{1000n, 1000n, 4242n, Nat.add(Nat.mul(LH.word_span(), 2n), 917n)}

def synthetic_high_start_matches() -> Bool:
  synthetic_launch_accepted(synthetic_launch_served(synthetic_high_start(), synthetic_high_start(), LH.linux_incarnation()), synthetic_high_start())

def synthetic_high_start_mismatch() -> Bool:
  synthetic_denied(synthetic_launch_served(synthetic_high_start(), synthetic_different_high_start(), LH.linux_incarnation()), rooted(), LH.PeerMismatch{})

def synthetic_wrong_subject() -> Bool:
  synthetic_denied(synthetic_barrier_served(V.session_worker(), 99n, launch_token(), LH.linux_incarnation(), launch_credential(),
    launch_credential()), delegated(), LH.SessionMismatch{})

def synthetic_wrong_token() -> Bool:
  synthetic_denied(synthetic_barrier_served(V.session_worker(), subject_a(), token_of(V.client_caller()), LH.linux_incarnation(),
    launch_credential(), launch_credential()), delegated(), LH.SessionMismatch{})

def synthetic_wrong_session(session: Nat) -> Bool:
  synthetic_denied(synthetic_barrier_served(session, subject_a(), launch_token(), LH.linux_incarnation(), launch_credential(),
    launch_credential()), delegated(), LH.SessionMismatch{})

def synthetic_stale_launch() -> Bool:
  synthetic_denied(synthetic_launch_served(launch_credential(), launch_credential(), stale_incarnation()), rooted(),
    LH.StaleLaunch{})

def synthetic_stale_barrier() -> Bool:
  synthetic_denied(synthetic_barrier_served(V.session_worker(), subject_a(), launch_token(), stale_incarnation(),
    launch_credential(), launch_credential()), delegated(), LH.StaleLaunch{})

# Synthetic raw frames for the public decoder's outer bound. Tail recursion
# builds the over-limit input without asking the decoder to construct it.
def synthetic_zero_bytes(size: Nat, tail: +List<U32>) -> +List<U32>:
  match size:
    case 0n:
      tail
    case 1n+n:
      synthetic_zero_bytes(n, 0 <> tail)

def synthetic_unframed(result: LH.FrameResult, expected: LH.FrameError) -> Bool:
  match result:
    case LH.Unframed{reason}:
      LH.FrameError.equal(reason, expected)
    case _:
      False{}

def synthetic_served_unframed(+served: LH.Served, +expected: LH.State, reason: LH.FrameError) -> Bool:
  match served:
    case LH.NotFramed{state, got}:
      LH.FrameError.equal(got, reason) && policy_credentials_equal(state, expected)
        && policy_credentials_equal(LH.next(served), expected) && PT.effects_equal(LH.served_effects(served), [])
    case _:
      False{}

def synthetic_frame_limit_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(synthetic_unframed(LH.decode_frame(synthetic_zero_bytes(512n, [])), LH.FrameVersion{}),
      "synthetic LINUXB exact byte limit reaches frame validation")
    Test.check(synthetic_unframed(LH.decode_frame(synthetic_zero_bytes(513n, [])), LH.FrameTooLong{}),
      "synthetic LINUXB rejects a frame one byte above the limit")
    Test.check(synthetic_unframed(LH.decode_frame(synthetic_zero_bytes(10000n, [])), LH.FrameTooLong{}),
      "synthetic LINUXB rejects a very oversized frame before packing")
    Test.check(synthetic_served_unframed(LH.serve(rooted(), synthetic_zero_bytes(10000n, []), LH.Sample{now()}), rooted(),
      LH.FrameTooLong{}), "synthetic LINUXB over-limit service leaves policy state unchanged")
    Test.check(synthetic_unframed(LH.decode_frame(256 <> synthetic_zero_bytes(512n, [])), LH.FrameTooLong{}),
      "synthetic LINUXB oversized frame takes precedence over out-of-range byte")
    Test.check(synthetic_unframed(LH.decode_frame(256 <> synthetic_zero_bytes(510n, [])), LH.FrameMisaligned{}),
      "synthetic LINUXB in-bound misalignment takes precedence over out-of-range byte")
    Test.check(synthetic_unframed(LH.decode_frame(256 <> synthetic_zero_bytes(511n, [])), LH.FrameRange{}),
      "synthetic LINUXB aligned in-bound out-of-range byte is refused")

# Entry point: synthetic monitor-service checks, not native qualification.
def synthetic_identity_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(synthetic_valid_launch(), "synthetic LINUXB launch with matching peer opens the expected worker session")
    Test.check(synthetic_valid_barrier(), "synthetic LINUXB barrier with matching peer admits the expected input effect")
    Test.check(synthetic_launch_denied(parent_credential(), LH.PeerMismatch{}), "synthetic LINUXB launch rejects parent socketpair peer")
    Test.check(synthetic_launch_denied(other_uid_credential(), LH.PeerMismatch{}), "synthetic LINUXB launch rejects peer uid mismatch")
    Test.check(synthetic_launch_denied(other_gid_credential(), LH.PeerMismatch{}), "synthetic LINUXB launch rejects peer gid mismatch")
    Test.check(synthetic_launch_denied(other_pid_credential(), LH.PeerMismatch{}), "synthetic LINUXB launch rejects peer pid mismatch")
    Test.check(synthetic_launch_denied(reused_pid_credential(), LH.PeerMismatch{}), "synthetic LINUXB launch rejects peer start-time low-word mismatch")
    Test.check(synthetic_high_start_matches(), "synthetic LINUXB launch preserves a matching nonzero start-time high word")
    Test.check(synthetic_high_start_mismatch(), "synthetic LINUXB launch rejects peer start-time high-word mismatch")
    Test.check(synthetic_barrier_denied(parent_credential(), LH.PeerMismatch{}), "synthetic LINUXB barrier rejects parent socketpair peer")
    Test.check(synthetic_barrier_denied(other_uid_credential(), LH.PeerMismatch{}), "synthetic LINUXB barrier rejects peer uid mismatch")
    Test.check(synthetic_barrier_denied(other_gid_credential(), LH.PeerMismatch{}), "synthetic LINUXB barrier rejects peer gid mismatch")
    Test.check(synthetic_barrier_denied(other_pid_credential(), LH.PeerMismatch{}), "synthetic LINUXB barrier rejects peer pid mismatch")
    Test.check(synthetic_barrier_denied(reused_pid_credential(), LH.PeerMismatch{}), "synthetic LINUXB barrier rejects peer start-time mismatch")
    Test.check(synthetic_stale_launch(), "synthetic LINUXB launch rejects an old monitor incarnation")
    Test.check(synthetic_stale_barrier(), "synthetic LINUXB barrier rejects an old monitor incarnation")
    Test.check(synthetic_wrong_subject(), "synthetic LINUXB barrier rejects a foreign launch subject")
    Test.check(synthetic_wrong_token(), "synthetic LINUXB barrier rejects a foreign launch token")
    Test.check(synthetic_wrong_session(V.session_client()), "synthetic LINUXB barrier rejects a different existing session")
    Test.check(synthetic_wrong_session(9n), "synthetic LINUXB barrier rejects a missing session")

# Public entry point, run by Tests.bend. Checks are grouped so that no do
# block nears the native backend's arity limit (HostBindingTests.bend).
def main() -> IO(Unit):
  do IO<Unit>:
    profile_checks()
    admission_checks()
    translator_checks()
    synthetic_identity_checks()
    synthetic_frame_limit_checks()
    launch_dispatch_checks()
    barrier_dispatch_checks()
    session_checks()
    restart_checks()
    worker_dispatch_checks()
    replay_plan_checks()
    replay_gap_checks()
    replay_caller_checks()
    replay_revocation_checks()
    replay_restart_checks()
    replay_compare_checks()
    IO.print("LinuxHost: 118 checks passed")
