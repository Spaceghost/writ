import Base
import ./LinuxHost.bend as LH
import ./LinuxHostTests.bend as LT
import ../../../HostConformanceVectors.bend as V
import ../../../HostPrimitives.bend as P
import ../../../HostPrimitivesTests.bend as PT
import ../../../HostIdentity.bend as I
import ../../../HostWire.bend as W
import ../../../Test.bend as Test

# Synthetic supervisor samples only: no kernel clock or authentication is implied.
def high_is(clock: LH.Clock, high: Nat) -> Bool:
  match clock:
    case LH.LiveClock{actual}: Nat.is_eq(actual, high)
    case _: False{}

def poisoned_at(clock: LH.Clock, high: Nat) -> Bool:
  match clock:
    case LH.PoisonedClock{Some{actual}}: Nat.is_eq(actual, high)
    case _: False{}

def poisoned_unknown(clock: LH.Clock) -> Bool:
  match clock:
    case LH.PoisonedClock{None{}}: True{}
    case _: False{}

def fault(+result: LH.Outcome, +before: LH.State, high: Nat) -> Bool:
  match result:
    case LH.ClockFault{+after}:
      LT.policy_credentials_equal(after, before) && poisoned_at(LH.clock(after), high)
        && PT.effects_equal(LH.Outcome.effects(result), [])
    case _: False{}

def sample_authority(sample: LH.ClockSample) -> P.AdmissionAuthority:
  match sample:
    case LH.Sample{now}: V.fixture_authority(now)
    case _: V.fixture_authority(100n)

def use(+state: LH.State, +sample: LH.ClockSample) -> LH.Outcome:
  LH.dispatch(state, LH.FromWorker{V.session_worker(), LT.input_use(V.claim_none())}, sample, sample_authority(sample))

def expired_150(+result: LH.Outcome, +before: LH.State) -> Bool:
  match result:
    case LH.Checked{+after, P.Refused{P.Identity{I.Expired{}}}}:
      LT.policy_credentials_equal(after, before) && high_is(LH.clock(after), 150n)
        && PT.effects_equal(LH.Outcome.effects(result), [])
    case _: False{}

def expired_then_regression() -> Bool:
  +before = LT.delegated()
  +expired = use(before, LH.Sample{150n})
  +after = LH.Outcome.state(expired)
  expired_150(expired, before) && fault(use(after, LH.Sample{149n}), after, 150n)

def malformed_150(+served: LH.Served, +before: LH.State) -> Bool:
  match served:
    case LH.NotFramed{+after, LH.FrameMisaligned{}}:
      LT.policy_credentials_equal(after, before) && high_is(LH.clock(after), 150n)
        && PT.effects_equal(LH.served_effects(served), [])
    case _: False{}

def malformed_then_regression() -> Bool:
  +before = LT.delegated()
  +bad = LH.serve(before, LT.short_bytes(), LH.Sample{150n}, V.fixture_authority(150n))
  +after = LH.next(bad)
  malformed_150(bad, before) && fault(use(after, LH.Sample{149n}), after, 150n)

def fresh_malformed_then_regression() -> Bool:
  +before = LH.initial()
  +bad = LH.serve(before, LT.short_bytes(), LH.Sample{150n}, V.fixture_authority(150n))
  +after = LH.next(bad)
  malformed_150(bad, before) && fault(use(after, LH.Sample{149n}), after, 150n)

def sample_faults() -> Bool:
  +s = LT.delegated()
  fault(use(s, LH.UnavailableClock{}), s, 100n)
    && fault(use(s, LH.AmbiguousClock{}), s, 100n)
    && fault(use(s, LH.OverflowClock{}), s, 100n)

def granted(result: LH.Outcome) -> Bool:
  match result:
    case LH.Checked{_, P.Granted{_, _}}: True{}
    case _: False{}

def equal_and_increasing() -> Bool:
  +s = LT.delegated()
  +first = use(s, LH.Sample{149n})
  +after = LH.Outcome.state(first)
  +equal = use(after, LH.Sample{149n})
  granted(first) && granted(equal) && high_is(LH.clock(LH.Outcome.state(equal)), 149n)

def healthy_barriers() -> Bool:
  +s = LT.delegated()
  +direct = LH.dispatch(s, LH.FromBroker{LT.barrier_of(LT.full_fact(), LT.input_use(V.claim_none()))}, LH.Sample{149n}, V.fixture_authority(149n))
  +served = LH.serve(s, LT.synthetic_barrier_bytes(V.session_worker(), LT.subject_a(), LT.launch_token(),
    LH.linux_incarnation(), LT.launch_credential(), LT.launch_credential()), LH.Sample{149n}, V.fixture_authority(149n))
  PT.effects_equal(LH.Outcome.effects(direct), [P.DeliverInputs{LT.worker(), LT.input_ref()}])
    && PT.effects_equal(LH.served_effects(served), [P.DeliverInputs{LT.worker(), LT.input_ref()}])
    && high_is(LH.clock(LH.Outcome.state(direct)), 149n) && high_is(LH.clock(LH.next(served)), 149n)

def stays_poisoned() -> Bool:
  +s = LT.delegated()
  +bad = use(s, LH.Sample{99n})
  +poisoned = LH.Outcome.state(bad)
  fault(bad, s, 100n) && fault(use(poisoned, LH.Sample{200n}), poisoned, 100n)

def imported_denied(result: LH.Outcome, state: LH.State) -> Bool:
  match result:
    case LH.ClockFault{+after}:
      LT.policy_credentials_equal(after, state) && poisoned_unknown(LH.clock(after))
    case _: False{}

def import_fails_closed() -> Bool:
  +s = LH.without_credentials(LH.portable(LT.delegated()))
  poisoned_unknown(LH.clock(s)) && imported_denied(use(s, LH.Sample{200n}), s)

def fresh_unavailable_stays_poisoned() -> Bool:
  +before = LH.initial()
  +bad = use(before, LH.UnavailableClock{})
  +after = LH.Outcome.state(bad)
  imported_denied(bad, before) && poisoned_unknown(LH.clock(after))
    && imported_denied(use(after, LH.Sample{200n}), after)

def barrier_direct(decoded: W.DecodeResult, +state: LH.State, +now: Nat, +high: Nat) -> Bool:
  match decoded:
    case W.Decoded{+message}:
      fault(LH.barrier_with(message, LT.linux_report(), LH.inventory_of(LT.full_fact()), state,
        V.session_worker(), LT.full_fact(), now, V.fixture_authority(now)), state, high)
        && fault(LH.worker_message(message, state, V.session_worker(), now), state, high)
    case _: False{}

def direct_helpers_reject() -> Bool:
  +before = LT.delegated()
  +s = LH.Outcome.state(use(before, LH.Sample{150n}))
  barrier_direct(W.decode_bytes(LT.input_use(V.claim_none())), s, 149n, 150n)
    && fault(LH.on_broker(s, LT.barrier_of(LT.full_fact(), LT.input_use(V.claim_none())), 149n, V.fixture_authority(149n)), s, 150n)
    && fault(LH.route_sampled(s, LH.FromWorker{V.session_worker(), LT.input_use(V.claim_none())}, 149n, V.fixture_authority(149n)), s, 150n)

def direct_delegate(decoded: W.DecodeResult, +state: LH.State) -> Bool:
  match decoded:
    case W.Decoded{message}:
      fault(LH.worker_message(message, state, V.session_worker(), 100n), state, 100n)
    case _: False{}

def poisoned_helpers_reject() -> Bool:
  +before = LT.delegated()
  +s = LH.Outcome.state(use(before, LH.UnavailableClock{}))
  barrier_direct(W.decode_bytes(LT.input_use(V.claim_none())), s, 100n, 100n)
    && fault(LH.on_broker(s, LT.barrier_of(LT.full_fact(), LT.input_use(V.claim_none())), 100n, V.fixture_authority(100n)), s, 100n)
    && fault(LH.route_sampled(s, LH.FromWorker{V.session_worker(), LT.input_use(V.claim_none())}, 100n, V.fixture_authority(100n)), s, 100n)
    && fault(LH.on_broker(s, LH.Launch{LT.full_fact()}, 100n, V.fixture_authority(100n)), s, 100n)
    && fault(LH.on_broker(s, LH.Usage{LT.worker(), 1n}, 100n, V.fixture_authority(100n)), s, 100n)
    && fault(LH.on_broker(s, LH.Emission{LT.worker(), True{}}, 100n, V.fixture_authority(100n)), s, 100n)
    && direct_delegate(W.decode_bytes(LT.worker_delegation()), s)

def actual_step_rejected(+state: LH.State) -> Bool:
  +p = LH.portable(state)
  +step = P.admit_worker(p, P.revision(p), LT.linux_report(), LH.inventory_of(LT.full_fact()),
    V.session_worker(), PT.execute_request(LT.input_ref()), 149n, V.fixture_authority(149n))
  PT.effects_equal(P.Step.effects(step), [P.DeliverInputs{LT.worker(), LT.input_ref()}])
    && fault(LH.stepped(state, step, 149n), state, 150n)

def stale_step_rejected() -> Bool:
  +s = LT.delegated()
  actual_step_rejected(LH.Outcome.state(use(s, LH.Sample{150n})))

def cleanup_after_poison() -> Bool:
  +s = LT.admitted()
  +poison = LH.Outcome.state(use(s, LH.UnavailableClock{}))
  +rev = LH.revoke(poison, P.revision(LH.portable(poison)), V.slot_of(LT.L(), V.Input{}))
  +restart = LH.restart(poison, P.revision(LH.portable(poison)), LT.linux_successor())
  PT.effects_equal(LH.Outcome.effects(rev), [P.StopEffects{LT.worker()}])
    && PT.effects_equal(LH.Outcome.effects(restart), [P.StopEffects{LT.worker()}])
    && poisoned_at(LH.clock(LH.Outcome.state(rev)), 100n)
    && poisoned_at(LH.clock(LH.Outcome.state(restart)), 100n)
    && fault(use(LH.Outcome.state(restart), LH.Sample{200n}), LH.Outcome.state(restart), 100n)

def failed_cleanup_after_poison() -> Bool:
  +s = LT.admitted()
  +poison = LH.Outcome.state(use(s, LH.UnavailableClock{}))
  +restart = LH.restart(poison, 0n, LT.linux_successor())
  +revoke = LH.revoke(poison, 0n, 0n)
  LT.denied_as(restart, poison, P.StaleRevision{}) && LT.denied_as(revoke, poison, P.StaleRevision{})
    && poisoned_at(LH.clock(LH.Outcome.state(restart)), 100n)
    && poisoned_at(LH.clock(LH.Outcome.state(revoke)), 100n)

# A deliberate max-revision state lets the separate trap control show that
# calling admit_worker would overflow. A stale clock must avoid evaluating it.
def max_revision(+state: LH.State, max: Nat) -> LH.State:
  match state:
    case LH.State{P.State{_, identity, profiles, bindings, workers, next_worker, seals, publications}, records, _}:
      LH.State{P.State{max, identity, profiles, bindings, workers, next_worker, seals, publications}, records,
        LH.LiveClock{150n}}

def max_value(parsed: Maybe<&2, Nat>) -> Bool:
  match parsed:
    case Some{max}: barrier_direct(W.decode_bytes(LT.input_use(V.claim_none())), max_revision(LT.delegated(), max), 149n, 150n)
    case None{}: False{}

def lazy_failure_control() -> Bool:
  max_value(Nat.read("281474976710655"))

def main() -> IO(Unit):
  do IO<Unit>:
    Test.check(expired_then_regression(), "LH-clock: denied expiry retains sample before later regression")
    Test.check(malformed_then_regression(), "LH-clock: malformed frame retains sample before later regression")
    Test.check(fresh_malformed_then_regression(), "LH-clock: first malformed frame retains its sample before regression")
    Test.check(sample_faults(), "LH-clock: unavailable ambiguous and overflow poison without policy change")
    Test.check(equal_and_increasing(), "LH-clock: equal and increasing trusted samples permit current use")
    Test.check(healthy_barriers(), "LH-clock: healthy dispatch and framed serve retain exact delivery effect")
    Test.check(stays_poisoned(), "LH-clock: a later valid sample cannot clear poison")
    Test.check(import_fails_closed(), "LH-clock: portable import has no clock provenance and stays poisoned")
    Test.check(fresh_unavailable_stays_poisoned(), "LH-clock: first unavailable sample poisons a fresh instance")
    Test.check(direct_helpers_reject(), "LH-clock: direct worker broker and barrier helpers reject stale time")
    Test.check(poisoned_helpers_reject(), "LH-clock: poisoned direct helpers cannot deliver or grant")
    Test.check(stale_step_rejected(), "LH-clock: existing Step packager rejects an actual stale delivery")
    Test.check(cleanup_after_poison(), "LH-clock: revoke and restart preserve poison and exact stop effects")
    Test.check(failed_cleanup_after_poison(), "LH-clock: denied cleanup preserves poison credentials and policy")
    Test.check(lazy_failure_control(), "LH-clock: stale clock avoids evaluating overflow-prone admission")
    IO.print("LinuxClock: 15 checks passed")
