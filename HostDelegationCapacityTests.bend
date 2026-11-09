import Base
import ./HostIdentity.bend as I
import ./HostIdentityTests.bend as IT
import ./HostPrimitives.bend as P
import ./HostPrimitivesTests.bend as PT
import ./HostWire.bend as W
import ./Transfer.bend as T
import ./hosts/linux/monitor/LinuxHost.bend as LH
import ./hosts/linux/monitor/LinuxHostTests.bend as LT
import ./hosts/linux/monitor/LinuxJointOwnerTests.bend as JT
import ./RendezvousTests.bend as RT
import ./HostConformanceVectors.bend as V
import ./Test.bend as Test

# Synthetic table/state editors and fixtures; no native identity is claimed.
def counters(state: I.State, revision: Nat, slot: Nat) -> I.State:
  match state:
    case I.State{_, host, incarnation, _, sessions, entries}: I.State{revision, host, incarnation, slot, sessions, entries}

def host_revision(state: P.State, revision: Nat) -> P.State:
  match state:
    case P.State{_, identity, profiles, bindings, workers, next, seals, publications}:
      P.State{revision, identity, profiles, bindings, workers, next, seals, publications}

def call(+state: I.State, ref: W.Ref, target: Nat, rights: U32, lifetime: Nat) -> I.Change:
  I.delegate(state, I.revision(state), IT.session_a(), ref, target, rights, lifetime, IT.now())

def prior_denials(+max: Nat) -> Bool:
  +base = IT.base()
  IT.denied(I.delegate(base, 0n, IT.session_a(), IT.bumped_root_ref(), IT.session_b(), IT.wide_rights(), max, IT.now()), base, I.StaleRevision{})
    && IT.denied(call(base, IT.bumped_root_ref(), IT.session_peer(), IT.narrow_rights(), max), base, I.StaleGeneration{})
    && IT.denied(call(base, IT.root_ref(), IT.session_unknown(), IT.narrow_rights(), max), base, I.UnknownSession{})
    && IT.denied(call(base, IT.root_ref(), IT.session_b(), IT.narrow_rights(), max), base, I.SubjectChanged{})
    && IT.denied(call(base, IT.root_ref(), IT.session_peer(), IT.wide_rights(), max), base, I.WidenedRights{})
    && IT.denied(I.delegate(IT.chain(), I.revision(IT.chain()), IT.session_worker(), IT.grandchild_ref(),
      IT.session_peer(), IT.narrow_rights(), max, IT.now()), IT.chain(), I.NotDelegable{})
    && IT.denied(I.delegate(base, I.revision(base), IT.session_a(), IT.root_ref(), IT.session_peer(),
      IT.narrow_rights(), max, IT.root_expires()), base, I.Expired{})
    && IT.denied(call(base, IT.root_ref(), IT.session_peer(), IT.narrow_rights(), max), base, I.WidenedLifetime{})

def full_limits(+max: Nat) -> Bool:
  +base = IT.base()
  +rev = counters(base, max, I.next_slot(base))
  +slot = counters(base, I.revision(base), max)
  +both = counters(base, max, max)
  I.valid(rev) && I.valid(slot) && I.valid(both)
    && IT.denied(call(rev, IT.root_ref(), IT.session_peer(), IT.narrow_rights(), IT.lifetime()), rev, I.CapacityExhausted{})
    && IT.denied(call(slot, IT.root_ref(), IT.session_peer(), IT.narrow_rights(), IT.lifetime()), slot, I.CapacityExhausted{})
    && IT.denied(call(both, IT.root_ref(), IT.session_peer(), IT.narrow_rights(), max), both, I.WidenedLifetime{})

def expected_child(slot: Nat, expires: Nat) -> I.Entry:
  I.Entry{slot, I.first_generation(), IT.session_peer(), IT.caller_a(), IT.handle_a(), IT.plan(),
    IT.narrow_rights(), expires, IT.root_slot(), True{}}

def accepted_exact(change: I.Change, +before: I.State, +slot: Nat, +expires: Nat) -> Bool:
  match change:
    case I.Rejected{_, _}: False{}
    case I.Accepted{+after, issued}:
      Nat.is_eq(issued, slot) && I.valid(after)
        && IT.entry_is(I.entry_lookup(I.entries(after), slot), expected_child(slot, expires))
        && IT.entry_is(I.entry_lookup(I.entries(after), IT.root_slot()), IT.root_entry())
        && IT.sessions_equal(I.sessions(after), I.sessions(before))

def boundaries(+max: Nat, +previous: Nat) -> Bool:
  +base = IT.base()
  +edge = counters(base, previous, previous)
  I.valid(edge)
    && accepted_exact(call(base, IT.root_ref(), IT.session_peer(), IT.narrow_rights(), 0n), base, I.next_slot(base), IT.now())
    && accepted_exact(call(base, IT.root_ref(), IT.session_peer(), IT.narrow_rights(), 80n), base, I.next_slot(base), IT.root_expires())
    && IT.denied(call(base, IT.root_ref(), IT.session_peer(), IT.narrow_rights(), 81n), base, I.WidenedLifetime{})
    && accepted_exact(call(edge, IT.root_ref(), IT.session_peer(), IT.narrow_rights(), IT.lifetime()), edge, previous, IT.child_expires())
    && Nat.is_eq(I.revision(I.Change.state(call(edge, IT.root_ref(), IT.session_peer(), IT.narrow_rights(), IT.lifetime()))), max)
    && Nat.is_eq(I.next_slot(I.Change.state(call(edge, IT.root_ref(), IT.session_peer(), IT.narrow_rights(), IT.lifetime()))), max)

def root_expiry(entries: I.Entries, +expires: Nat) -> I.Entries:
  match entries:
    case I.NoEntries{}: I.NoEntries{}
    case I.Entries{I.Entry{+slot, generation, holder, owner, handle, plan, rights, old, parent, live}, rest}:
      I.Entries{I.Entry{slot, generation, holder, owner, handle, plan, rights,
        Bool.pick(Nat, Nat.is_eq(slot, IT.root_slot()), expires, old), parent, live}, root_expiry(rest, expires)}

def max_expiry_result(change: I.Change, +before: I.State, +max: Nat) -> Bool:
  match change:
    case I.Accepted{+after, +slot}:
      I.valid(after) && IT.entry_is(I.entry_lookup(I.entries(after), slot), expected_child(slot, max))
        && IT.entry_is(I.entry_lookup(I.entries(after), IT.root_slot()), I.Entry{IT.root_slot(), I.first_generation(),
          IT.session_a(), IT.caller_a(), IT.handle_a(), IT.plan(), IT.root_rights(), max, I.root_parent(), True{}})
        && IT.sessions_equal(I.sessions(after), I.sessions(before))
    case _: False{}

def max_expiry(+max: Nat, +previous: Nat) -> Bool:
  +base = IT.base()
  +state = IT.with_entries(base, I.next_slot(base), root_expiry(I.entries(base), max))
  I.valid(state) && max_expiry_result(I.delegate(state, I.revision(state), IT.session_a(), IT.root_ref(),
    IT.session_peer(), IT.narrow_rights(), 1n, previous), state, max)

def check_accessors() -> Bool:
  +refused = {I.DelegateRefused{I.WidenedRights{}} : I.DelegateCheck}
  +ready = {I.DelegateReady{IT.root_entry()} : I.DelegateCheck}
  Bool.not(I.delegate_ready(refused)) && I.Error.equal(I.delegate_reason(refused), I.WidenedRights{})
    && Nat.is_eq(I.entry_slot(I.delegate_parent(refused)), 0n) && Bool.not(I.entry_live(I.delegate_parent(refused)))
    && I.delegate_ready(ready) && IT.entry_equal(I.delegate_parent(ready), IT.root_entry())

def preflight_actual(+max: Nat) -> Bool:
  +base = IT.base()
  +ready = {I.delegate_preflight(base, I.revision(base), IT.session_a(), IT.root_ref(), IT.session_peer(),
    IT.narrow_rights(), 0n, IT.now()) : I.DelegateCheck}
  +refused = {I.delegate_preflight(base, I.revision(base), IT.session_a(), IT.root_ref(), IT.session_peer(),
    IT.wide_rights(), max, IT.now()) : I.DelegateCheck}
  I.delegate_ready(ready) && IT.entry_equal(I.delegate_parent(ready), IT.root_entry())
    && Bool.not(I.delegate_ready(refused)) && I.Error.equal(I.delegate_reason(refused), I.WidenedRights{})
    && IT.denied(call(base, IT.root_ref(), IT.session_peer(), IT.wide_rights(), max), base, I.delegate_reason(refused))

def primitive_limits(+max: Nat) -> Bool:
  +base = PT.pub_issued()
  +full = host_revision(base, max)
  +id = P.identity(base)
  +both = {P.State{max, counters(id, max, I.next_slot(id)), P.profiles(base), P.bindings(base), P.workers(base),
    P.next_worker(base), P.seals(base), P.publications(base)} : P.State}
  P.valid(full) && P.valid(both)
    && PT.denied(P.delegate(full, P.revision(full), PT.session_client(), PT.root_ref(), PT.session_worker(),
      PT.input_rights(), PT.input_lifetime(), PT.pub_now()), full, P.CapacityExhausted{})
    && PT.denied(P.delegate(full, P.revision(full), PT.session_client(), PT.root_ref(), PT.session_worker(),
      8, max, PT.pub_now()), full, P.Identity{I.WidenedRights{}})
    && PT.denied(P.delegate(both, P.revision(both), PT.session_client(), PT.root_ref(), PT.session_worker(),
      PT.input_rights(), PT.input_lifetime(), PT.pub_now()), both, P.Identity{I.CapacityExhausted{}})

def linux_host(state: LH.State, p: P.State) -> LH.State:
  match state:
    case LH.State{_, records, time, owner}: LH.State{p, records, time, owner}

def standalone_limit(max: Nat) -> Bool:
  +base = LT.launched()
  +full = linux_host(base, host_revision(LH.portable(base), max))
  +bytes = {W.encode_bytes(W.Delegate{LT.root_ref(), V.narrow_rights(), V.narrow_lifetime(), V.word(V.session_worker())}) : +List<U32>}
  LT.denied_as(LT.worker_frame(full, V.session_client(), bytes), full, P.CapacityExhausted{})

def joint_limit(+world: RT.Sc, max: Nat) -> Bool:
  +base = JT.issued_once(world)
  +full = JT.host_revision(base, max)
  +bytes = {W.encode_bytes(W.Delegate{W.Ref{60, 1, 1, 1}, 4, 1, 1}) : +List<U32>}
  +out = {LH.dispatch(full, LH.FromWorker{1n, bytes}, LH.Sample{110n}, V.fixture_authority(110n)) : LH.Outcome}
  JT.is_contained(out) && JT.is_failed(LH.joint(LH.Outcome.state(out)))
    && LT.policy_credentials_equal(full, LH.Outcome.state(out)) && PT.effects_equal(LH.Outcome.effects(out), [])

def parsed(a: Maybe<&2, Nat>, b: Maybe<&2, Nat>, which: Nat) -> Bool:
  match a b:
    case Some{max} Some{previous}:
      match which:
        case 0n: prior_denials(max)
        case 1n: full_limits(max)
        case 2n: boundaries(max, previous)
        case 3n: max_expiry(max, previous)
        case 4n: primitive_limits(max)
        case 5n: preflight_actual(max)
        case 6n: standalone_limit(max)
        case _: joint_limit(RT.sc_world(), max)
    case _ _: False{}

def check(which: Nat) -> Bool:
  parsed(Nat.read("281474976710655"), Nat.read("281474976710654"), which)

def main() -> IO(Unit):
  do IO<Unit>:
    Test.check(check(0n), "PH-delegate overflow lifetime preserves earlier denials")
    Test.check(check(1n), "PH-delegate terminal identity counters deny after lifetime")
    Test.check(check(2n), "PH-delegate zero exact and maximum-minus-one allocation preserve parent")
    Test.check(check(3n), "PH-delegate exact maximum expiry is representable")
    Test.check(check_accessors(), "PH-delegate read-only check accessors preserve ready and invalid fallback")
    Test.check(check(4n), "PH-delegate primitive revision denies after identity and rights")
    Test.check(check(5n), "PH-delegate actual preflight result stays read-only and agrees")
    Test.check(check(6n), "LH-delegate standalone terminal capacity denies without effects")
    Test.check(check(7n), "LH-delegate joint terminal capacity requires containment")
    IO.print("HostDelegationCapacity: 9 checks passed")
