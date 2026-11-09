import Base
import ./HostPrimitives.bend as P
import ./HostPrimitivesTests.bend as PT
import ./HostAdmissionCurrentTests.bend as AT
import ./HostWire.bend as W
import ./Frontend.bend as F
import ./HostConformanceVectors.bend as V
import ./RendezvousTests.bend as RT
import ./hosts/linux/monitor/LinuxHost.bend as LH
import ./hosts/linux/monitor/LinuxHostTests.bend as LT
import ./hosts/linux/monitor/LinuxJointOwnerTests.bend as JT
import ./Test.bend as Test

# Synthetic model records only; no native identity or host is authenticated.
def counters(state: P.State, revision: Nat, next: Nat) -> P.State:
  match state:
    case P.State{_, identity, profiles, bindings, workers, _, seals, publications}:
      P.State{revision, identity, profiles, bindings, workers, next, seals, publications}

def admission(+state: P.State) -> P.Step:
  PT.admit_on(state, PT.full_report(), PT.mediated_inventory())

def direct_zero(+maximum: Nat) -> Bool:
  +base = PT.base()
  +zero = counters(base, P.revision(base), 0n)
  +zero_full = counters(base, maximum, 0n)
  P.valid(zero) && P.valid(zero_full)
    && PT.denied(admission(zero), zero, P.InvalidAllocatorState{})
    && PT.denied(admission(zero_full), zero_full, P.InvalidAllocatorState{})

def direct_full(+maximum: Nat) -> Bool:
  +base = PT.base()
  +worker_full = counters(base, P.revision(base), maximum)
  +revision_full = counters(base, maximum, P.next_worker(base))
  +both_full = counters(base, maximum, maximum)
  P.valid(worker_full) && P.valid(revision_full) && P.valid(both_full)
    && PT.denied(admission(worker_full), worker_full, P.CapacityExhausted{})
    && PT.denied(admission(revision_full), revision_full, P.CapacityExhausted{})
    && PT.denied(admission(both_full), both_full, P.CapacityExhausted{})

def admitted_edge(step: P.Step, +maximum: Nat, +previous: Nat) -> Bool:
  match step:
    case P.Denied{_, _}: False{}
    case P.Admitted{+after, P.DeliverInputs{worker, ref} <> []}:
      Nat.is_eq(worker, previous) && W.Ref.equal(ref, PT.input_ref())
        && Nat.is_eq(P.revision(after), maximum) && Nat.is_eq(P.next_worker(after), maximum)
        && P.valid(after)
    case _: False{}

def edge(+maximum: Nat, +previous: Nat) -> Bool:
  +state = counters(PT.base(), previous, previous)
  P.valid(state) && admitted_edge(admission(state), maximum, previous)

def earlier_failures(+maximum: Nat) -> Bool:
  +state = counters(PT.base(), maximum, 0n)
  +execute = {AT.request(W.operation_execute(), 4) : W.Message}
  P.valid(state)
    && PT.denied(P.admit_worker(state, 0n, PT.full_report(), PT.mediated_inventory(), PT.session_worker(),
      execute, PT.now(), AT.authority()), state, P.StaleRevision{})
    && AT.denied(state, AT.request(W.operation_read(), 4), AT.authority(), P.OperationNotPermitted{})
    && AT.denied(state, execute, AT.with_registry(F.EmptyRegistry{}), P.AuthorityUnavailable{})
    && PT.denied(P.admit_worker(state, P.revision(state), PT.full_report(), PT.leaky_inventory(), PT.session_worker(),
      execute, PT.now(), AT.authority()), state, P.UnmediatedRoute{})

def linux_counter(state: LH.State, revision: Nat, next: Nat) -> LH.State:
  match state:
    case LH.State{p, records, clock, owner}: LH.State{counters(p, revision, next), records, clock, owner}

def standalone_zero() -> Bool:
  +base = LT.delegated()
  +zero = linux_counter(base, P.revision(LH.portable(base)), 0n)
  P.valid(LH.portable(zero)) && LT.denied_as(LT.barrier_on(zero, LT.full_fact()), zero, P.InvalidAllocatorState{})

def joint_zero_result(+outcome: LH.Outcome, +before: LH.State) -> Bool:
  match outcome:
    case LH.ContainmentRequired{+after}:
      JT.is_failed(LH.joint(after)) && JT.clock_still_live(LH.clock(after))
        && LT.policy_credentials_equal(after, before) && PT.effects_equal(LH.Outcome.effects(outcome), [])
        && JT.is_contained(JT.delivery_of(after))
        && PT.effects_equal(LH.Outcome.effects(JT.delivery_of(after)), [])
    case _: False{}

def joint_zero(+world: RT.Sc) -> Bool:
  +base = JT.issued_once(world)
  +zero = linux_counter(base, P.revision(LH.portable(base)), 0n)
  P.valid(LH.portable(zero)) && Bool.not(LH.joint_commit_room(zero))
    && joint_zero_result(JT.delivery_of(zero), zero)

def joint_old_failure(+world: RT.Sc) -> Bool:
  +base = JT.issued_once(world)
  +zero = linux_counter(base, P.revision(LH.portable(base)), 0n)
  +read = {W.Use{W.Ref{60, 1, 1, 1}, W.operation_read(), 4, W.ClaimedSubject{0}} : W.Message}
  +outcome = {LH.dispatch(zero, LH.FromBroker{LH.Barrier{1n, JT.fact(), W.encode_bytes(read)}},
    LH.Sample{110n}, V.fixture_authority(110n)) : LH.Outcome}
  +unmediated = {LH.dispatch(zero, LH.FromBroker{LH.Barrier{1n, JT.leaky_fact(), W.encode_bytes(JT.guard_use())}},
    LH.Sample{110n}, V.fixture_authority(110n)) : LH.Outcome}
  LT.denied_as(outcome, zero, P.OperationNotPermitted{}) && Bool.not(JT.is_failed(LH.joint(LH.Outcome.state(outcome))))
    && LT.denied_as(unmediated, zero, P.UnmediatedRoute{})
    && Bool.not(JT.is_failed(LH.joint(LH.Outcome.state(unmediated))))

def with_parsed(a: Maybe<&2, Nat>, b: Maybe<&2, Nat>, which: Nat) -> Bool:
  match a b:
    case Some{max} Some{previous}:
      match which:
        case 0n: direct_zero(max)
        case 1n: direct_full(max)
        case 2n: edge(max, previous)
        case _: earlier_failures(max)
    case _ _: False{}

def parsed(which: Nat) -> Bool:
  with_parsed(Nat.read("281474976710655"), Nat.read("281474976710654"), which)

def main() -> IO(Unit):
  do IO<Unit>:
    Test.check(parsed(0n), "PH-worker zero allocator denies unchanged before capacity")
    Test.check(parsed(1n), "PH-worker terminal worker and revision counters deny unchanged")
    Test.check(parsed(2n), "PH-worker max-minus-one admits valid model worker beyond U32")
    Test.check(parsed(3n), "PH-worker earlier admission and authority denials retain precedence")
    Test.check(standalone_zero(), "LH-worker standalone zero denies with no effects")
    Test.check(joint_zero(RT.sc_world()), "LH-worker joint zero contains without delivery and stays failed")
    Test.check(joint_old_failure(RT.sc_world()), "LH-worker joint earlier denial precedes zero containment")
    IO.print("HostWorkerCapacity: 7 checks passed")
