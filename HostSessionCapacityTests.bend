import Base
import ./HostIdentity.bend as I
import ./HostIdentityTests.bend as IT
import ./HostPrimitives.bend as P
import ./HostPrimitivesTests.bend as PT
import ./HostIssueResultTests.bend as IR
import ./hosts/linux/monitor/LinuxSessionOpenTests.bend as ST
import ./hosts/linux/monitor/LinuxHost.bend as LH
import ./hosts/linux/monitor/LinuxHostTests.bend as LT
import ./hosts/linux/monitor/LinuxJointOwnerTests.bend as JT
import ./RendezvousTests.bend as RT
import ./HostConformanceVectors.bend as V
import ./Test.bend as Test

# All session facts and owner states here are synthetic.
def add_session(+state: I.State, id: Nat) -> I.State:
  match state:
    case I.State{revision, host, +incarnation, next, sessions, entries}:
      I.State{revision, host, incarnation, next,
        I.Sessions{I.Session{id, incarnation, IT.caller_a(), I.Authenticated{}, False{}}, sessions}, entries}

def identity_revision(state: I.State, revision: Nat) -> I.State:
  match state:
    case I.State{_, host, incarnation, next, sessions, entries}:
      I.State{revision, host, incarnation, next, sessions, entries}

def host_state(state: P.State, revision: Nat, identity: I.State) -> P.State:
  match state:
    case P.State{_, _, profiles, bindings, workers, next, seals, publications}:
      P.State{revision, identity, profiles, bindings, workers, next, seals, publications}

def bind(+identity: I.State, origin: I.Origin) -> I.Change:
  I.bind_session(identity, I.revision(identity), IT.caller_a(), origin, True{})

def identity_limits(+max: Nat) -> Bool:
  +base = P.identity(ST.seed())
  +full_id = add_session(base, max)
  +full_revision = identity_revision(base, max)
  I.valid(full_id) && I.valid(full_revision)
    && IT.denied(bind(full_id, I.Authenticated{}), full_id, I.CapacityExhausted{})
    && IT.denied(bind(full_revision, I.Authenticated{}), full_revision, I.CapacityExhausted{})

def identity_order(+max: Nat) -> Bool:
  +base = P.identity(ST.seed())
  +full = identity_revision(add_session(base, max), max)
  IT.denied(I.bind_session(full, 0n, IT.caller_a(), I.Inherited{999n}, True{}), full, I.StaleRevision{})
    && IT.denied(bind(full, I.Inherited{999n}), full, I.UnknownSession{})
    && IT.denied(bind(full, I.Transferred{999n}), full, I.UnknownSession{})

def identity_edge(change: I.Change, +max: Nat) -> Bool:
  match change:
    case I.Accepted{+state, +issued}:
      Nat.is_eq(issued, max) && Nat.is_eq(I.revision(state), max) && I.valid(state)
        && ST.session_matches(I.session_at(I.sessions(state), issued), True{}, IT.caller_a())
    case _: False{}

def direct_edge(+max: Nat, +previous: Nat) -> Bool:
  +base = P.identity(ST.seed())
  +edge = identity_revision(add_session(base, previous), previous)
  I.valid(edge) && identity_edge(bind(edge, I.Authenticated{}), max)

def typed(+state: P.State, +fact: P.Fact, +role: P.Role) -> P.SessionOpen:
  P.open_session_result(state, P.revision(state), PT.full_report(), fact, role)

def denied_parity(+state: P.State, +fact: P.Fact, +role: P.Role, reason: P.Error) -> Bool:
  +typed = {typed(state, fact, role) : P.SessionOpen}
  ST.denied(typed, state, reason)
    && IR.equivalent(P.SessionOpen.step(typed), P.open_session(state, P.revision(state), PT.full_report(), fact, role))
    && PT.effects_equal(P.Step.effects(P.SessionOpen.step(typed)), [])

def typed_limits(+max: Nat) -> Bool:
  +seed = ST.seed()
  +id = P.identity(seed)
  +session_full = host_state(seed, P.revision(seed), add_session(id, max))
  +identity_full = host_state(seed, P.revision(seed), identity_revision(id, max))
  +portable_full = host_state(seed, max, id)
  +both_full = host_state(seed, max, identity_revision(add_session(id, max), max))
  +client = {P.ClientRole{True{}} : P.Role}
  +worker = {P.WorkerRole{PT.cpu_id()} : P.Role}
  P.valid(session_full) && P.valid(identity_full) && P.valid(portable_full) && P.valid(both_full)
    && denied_parity(session_full, PT.client_evidence(), client, P.Identity{I.CapacityExhausted{}})
    && denied_parity(session_full, PT.worker_evidence(), worker, P.Identity{I.CapacityExhausted{}})
    && denied_parity(identity_full, PT.client_evidence(), client, P.Identity{I.CapacityExhausted{}})
    && denied_parity(identity_full, PT.worker_evidence(), worker, P.Identity{I.CapacityExhausted{}})
    && denied_parity(portable_full, PT.client_evidence(), client, P.CapacityExhausted{})
    && denied_parity(portable_full, PT.worker_evidence(), worker, P.CapacityExhausted{})
    && denied_parity(both_full, PT.client_evidence(), client, P.Identity{I.CapacityExhausted{}})
    && denied_parity(both_full, PT.worker_evidence(), worker, P.Identity{I.CapacityExhausted{}})

def typed_order(+max: Nat) -> Bool:
  +seed = ST.seed()
  +full = host_state(seed, max, identity_revision(add_session(P.identity(seed), max), max))
  +bad_origin = {P.SessionEvidence{IT.caller_a(), I.Inherited{999n}, True{}} : P.Fact}
  +bad_transfer = {P.SessionEvidence{IT.caller_a(), I.Transferred{999n}, True{}} : P.Fact}
  ST.denied(P.open_session_result(full, 0n, PT.full_report(), PT.client_evidence(), P.ClientRole{True{}}), full, P.StaleRevision{})
    && ST.denied(P.open_session_result(full, P.revision(full), PT.no_session_report(), PT.client_evidence(), P.ClientRole{True{}}), full, P.UnsupportedFamily{})
    && ST.denied(P.open_session_result(full, P.revision(full), PT.full_report(), PT.mediated_inventory(), P.ClientRole{True{}}), full, P.WrongPhase{})
    && ST.denied(P.open_session_result(full, P.revision(full), PT.full_report(), PT.worker_evidence(), P.WorkerRole{PT.unknown_profile_id()}), full, P.UnknownProfile{})
    && ST.denied(P.open_session_result(full, P.revision(full), PT.full_report(), bad_origin, P.ClientRole{True{}}), full, P.Identity{I.UnknownSession{}})
    && ST.denied(P.open_session_result(full, P.revision(full), PT.full_report(), bad_origin, P.WorkerRole{PT.cpu_id()}), full, P.Identity{I.UnknownSession{}})
    && ST.denied(P.open_session_result(full, P.revision(full), PT.full_report(), bad_transfer, P.WorkerRole{PT.cpu_id()}), full, P.Identity{I.UnknownSession{}})

def edge_binding(found: P.BindingLookup, worker: Bool) -> Bool:
  match found worker:
    case P.OneBinding{profile} True{}: Nat.is_eq(profile, PT.cpu_id())
    case P.NoBinding{} False{}: True{}
    case _ _: False{}

def typed_edge_result(+result: P.SessionOpen, +state: P.State, +max: Nat, +worker: Bool) -> Bool:
  match result:
    case P.SessionOpened{+after, +issued}:
      Nat.is_eq(issued, max) && Nat.is_eq(P.revision(after), max)
        && Nat.is_eq(I.revision(P.identity(after)), max) && P.valid(after)
        && PT.effects_equal(P.Step.effects(P.SessionOpen.step(result)), [])
        && edge_binding(P.binding_at(P.bindings(after), issued), worker)
        && Bool.pick(Bool, worker, ST.session_matches(I.session_at(I.sessions(P.identity(after)), issued), False{}, PT.caller_worker()),
          ST.session_matches(I.session_at(I.sessions(P.identity(after)), issued), True{}, PT.caller_client()))
    case _: False{}

def typed_edge(+max: Nat, +previous: Nat) -> Bool:
  +seed = ST.seed()
  +state = host_state(seed, previous, identity_revision(add_session(P.identity(seed), previous), previous))
  +client = {typed(state, PT.client_evidence(), P.ClientRole{True{}}) : P.SessionOpen}
  +worker = {typed(state, PT.worker_evidence(), P.WorkerRole{PT.cpu_id()}) : P.SessionOpen}
  P.valid(state) && typed_edge_result(client, state, max, False{}) && typed_edge_result(worker, state, max, True{})
    && IR.equivalent(P.SessionOpen.step(client), P.open_session(state, P.revision(state), PT.full_report(), PT.client_evidence(), P.ClientRole{True{}}))
    && IR.equivalent(P.SessionOpen.step(worker), P.open_session(state, P.revision(state), PT.full_report(), PT.worker_evidence(), P.WorkerRole{PT.cpu_id()}))

def linux_host(state: LH.State, p: P.State) -> LH.State:
  match state:
    case LH.State{_, records, time, owner}: LH.State{p, records, time, owner}

def standalone_limits(+max: Nat) -> Bool:
  +base = LT.rooted()
  +p = LH.portable(base)
  +id = P.identity(p)
  +id_full = linux_host(base, host_state(p, P.revision(p), add_session(id, max)))
  +rev_full = linux_host(base, host_state(p, max, id))
  LT.denied_as(LT.frame(id_full, LH.Launch{LT.full_fact()}), id_full, P.Identity{I.CapacityExhausted{}})
    && LT.denied_as(LT.frame(rev_full, LH.Launch{LT.full_fact()}), rev_full, P.CapacityExhausted{})

def joint_limits(+world: RT.Sc, max: Nat) -> Bool:
  +base = JT.sampled_initial(world)
  +p = LH.portable(base)
  +full = linux_host(base, host_state(p, max, P.identity(p)))
  +out = {LH.dispatch(full, LH.FromBroker{LH.Launch{JT.fact()}}, LH.Sample{110n}, V.fixture_authority(110n)) : LH.Outcome}
  JT.is_contained(out) && JT.is_failed(LH.joint(LH.Outcome.state(out)))
    && LT.policy_credentials_equal(full, LH.Outcome.state(out)) && PT.effects_equal(LH.Outcome.effects(out), [])

def parsed(found: Maybe<&2, Nat>, near: Maybe<&2, Nat>, which: Nat) -> Bool:
  match found near:
    case Some{max} Some{prev}:
      match which:
        case 0n: identity_limits(max)
        case 1n: identity_order(max)
        case 2n: direct_edge(max, prev)
        case 3n: typed_limits(max)
        case 4n: typed_order(max)
        case 5n: typed_edge(max, prev)
        case 6n: standalone_limits(max)
        case _: joint_limits(RT.sc_world(), max)
    case _ _: False{}

def check(which: Nat) -> Bool:
  parsed(Nat.read("281474976710655"), Nat.read("281474976710654"), which)

def main() -> IO(Unit):
  do IO<Unit>:
    Test.check(check(0n), "PH-session identity session-id and revision maximum deny unchanged")
    Test.check(check(1n), "PH-session stale and unknown-origin errors precede capacity")
    Test.check(check(2n), "PH-session identity maximum-minus-one allocates maximum id")
    Test.check(check(3n), "PH-session both roles deny identity and primitive terminal capacities")
    Test.check(check(4n), "PH-session old gate family fact profile and origin errors retain precedence")
    Test.check(check(5n), "PH-session both roles return exact maximum model id with legacy parity")
    Test.check(check(6n), "LH-session standalone launch denies terminal capacity without credentials")
    Test.check(check(7n), "LH-session joint terminal launch requires containment without effects")
    IO.print("HostSessionCapacity: 8 checks passed")
