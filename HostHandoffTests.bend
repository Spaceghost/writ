import Base
import ./HostHandoff.bend as H
import ./HostPrimitives.bend as P
import ./HostIdentity.bend as I
import ./HostWire.bend as W
import ./HostPrimitivesTests.bend as PT
import ./Test.bend as Test

# All identities, adapter evidence and route inventories here are SYNTHETIC.
# No test authenticates an OS peer, proves native route completeness, or
# grants confinement. Only the real HostPrimitives admission may emit input.

def binding() -> H.Binding:
  H.Binding{9n, PT.incarnation_id(), PT.session_worker(), 41n, PT.input_ref()}

def evidence(at: Nat) -> H.Evidence:
  H.Evidence{at, 9n, PT.incarnation_id(), PT.session_worker(), 41n,
    True{}, True{}, True{}, True{}, True{}}

def before_retire(at: Nat) -> H.Evidence:
  H.Evidence{at, 9n, PT.incarnation_id(), PT.session_worker(), 41n,
    True{}, True{}, True{}, True{}, False{}}

def wrong_launch(at: Nat) -> H.Evidence:
  H.Evidence{at, 10n, PT.incarnation_id(), PT.session_worker(), 41n,
    True{}, True{}, True{}, True{}, True{}}

def wrong_incarnation(at: Nat) -> H.Evidence:
  H.Evidence{at, 9n, 74n, PT.session_worker(), 41n,
    True{}, True{}, True{}, True{}, True{}}

def wrong_session(at: Nat) -> H.Evidence:
  H.Evidence{at, 9n, PT.incarnation_id(), PT.session_unknown(), 41n,
    True{}, True{}, True{}, True{}, True{}}

def wrong_image(at: Nat) -> H.Evidence:
  H.Evidence{at, 9n, PT.incarnation_id(), PT.session_worker(), 42n,
    True{}, True{}, True{}, True{}, True{}}

def unsafe_channels(at: Nat) -> H.Evidence:
  H.Evidence{at, 9n, PT.incarnation_id(), PT.session_worker(), 41n,
    True{}, True{}, True{}, False{}, True{}}

def unauthenticated(at: Nat) -> H.Evidence:
  H.Evidence{at, 9n, PT.incarnation_id(), PT.session_worker(), 41n,
    True{}, False{}, True{}, True{}, True{}}

def missing_controls(at: Nat) -> H.Evidence:
  H.Evidence{at, 9n, PT.incarnation_id(), PT.session_worker(), 41n,
    True{}, True{}, False{}, True{}, True{}}

def dead(at: Nat) -> H.Evidence:
  H.Evidence{at, 9n, PT.incarnation_id(), PT.session_worker(), 41n,
    False{}, True{}, True{}, True{}, True{}}

def initial() -> H.State:
  H.initial(binding())

def observed() -> H.State:
  H.step_state(H.observe(initial(), 0n, before_retire(0n), True{}))

def ready() -> H.State:
  H.step_state(H.handoff(observed(), 1n, evidence(1n)))

def phase_equal(a: H.Phase, b: H.Phase) -> Bool:
  match a b:
    case H.Created{} H.Created{}: True{}
    case H.Observed{} H.Observed{}: True{}
    case H.HandoffClosed{} H.HandoffClosed{}: True{}
    case H.Attempted{} H.Attempted{}: True{}
    case H.Retired{} H.Retired{}: True{}
    case _ _: False{}

def state_equal(a: H.State, b: H.State) -> Bool:
  H.State{ar, ap, H.Binding{al, ai, as, am, ax}} = a
  H.State{br, bp, H.Binding{bl, bi, bs, bm, bx}} = b
  Nat.is_eq(ar, br) && phase_equal(ap, bp) && Nat.is_eq(al, bl) && Nat.is_eq(ai, bi) &&
    Nat.is_eq(as, bs) && Nat.is_eq(am, bm) && W.Ref.equal(ax, bx)

def reason_equal(a: H.Error, b: H.Error) -> Bool:
  match a b:
    case H.WrongPhase{} H.WrongPhase{}: True{}
    case H.StaleRevision{} H.StaleRevision{}: True{}
    case H.UntrustedFacts{} H.UntrustedFacts{}: True{}
    case H.InvalidReport{} H.InvalidReport{}: True{}
    case _ _: False{}

def denied(step: H.Step, state: H.State, reason: H.Error) -> Bool:
  match step:
    case H.Denied{actual, got}: state_equal(actual, state) && reason_equal(got, reason)
    case _: False{}

def aborted(step: H.Step, revision: Nat, reason: H.Error) -> Bool:
  match step:
    case H.Aborted{actual, got}:
      state_equal(actual, H.State{revision, H.Retired{}, binding()}) && reason_equal(got, reason)
    case _: False{}

def moved(step: H.Step, phase: H.Phase, revision: Nat) -> Bool:
  match step:
    case H.Moved{H.State{actual, actual_phase, _}}:
      Nat.is_eq(actual, revision) && phase_equal(actual_phase, phase)
    case _: False{}

def attempt(state: H.State, expected: Nat, fact: H.Evidence, core: P.State,
  core_revision: Nat, inventory: P.Fact, now: Nat) -> H.Step:
  H.admit(state, expected, fact, core, core_revision, PT.full_report(), inventory, now)

def success(step: H.Step) -> Bool:
  match step:
    case H.Attempt{H.State{revision, H.Attempted{}, _}, P.Admitted{core, effects}}:
      Nat.is_eq(revision, 3n) && PT.state_equal(core, PT.after_admit(PT.accel_profile())) &&
        PT.effects_equal(effects, [P.DeliverInputs{PT.worker_id(), PT.input_ref()}])
    case _: False{}

def core_denied(step: H.Step, revision: Nat, expected: P.State, reason: P.Error) -> Bool:
  match step:
    case H.Attempt{H.State{actual, H.Attempted{}, _}, P.Denied{core, got}}:
      Nat.is_eq(actual, revision) && PT.state_equal(core, expected) && P.Error.equal(got, reason)
    case _: False{}

def retired_core() -> P.State:
  PT.table_on(PT.base(), 0n, PT.with_input_retired())

def main() -> IO(Unit):
  do IO<Unit>:
    Test.check(moved(H.observe(initial(), 0n, before_retire(0n), True{}), H.Observed{}, 1n),
      "HH-001 preflight report changes only synthetic phase")
    Test.check(aborted(H.observe(initial(), 0n, evidence(0n), False{}), 1n, H.InvalidReport{}),
      "HH-001 malformed report poisons local preflight")
    Test.check(denied(H.observe(initial(), 1n, evidence(0n), True{}), initial(), H.StaleRevision{}),
      "HH-001 stale preflight revision denied")
    Test.check(aborted(H.observe(initial(), 0n, wrong_launch(0n), True{}), 1n, H.UntrustedFacts{}),
      "HH-002 wrong launch lifetime denied")
    Test.check(aborted(H.observe(initial(), 0n, wrong_incarnation(0n), True{}), 1n, H.UntrustedFacts{}),
      "HH-002 wrong monitor incarnation denied")
    Test.check(aborted(H.observe(initial(), 0n, wrong_session(0n), True{}), 1n, H.UntrustedFacts{}),
      "HH-002 wrong session denied")
    Test.check(aborted(H.observe(initial(), 0n, wrong_image(0n), True{}), 1n, H.UntrustedFacts{}),
      "HH-002 wrong held image denied")
    Test.check(aborted(H.observe(initial(), 0n, dead(0n), True{}), 1n, H.UntrustedFacts{}),
      "HH-002 dead worker denied")
    Test.check(aborted(H.observe(observed(), 1n, evidence(1n), True{}), 2n, H.WrongPhase{}),
      "HH-003 duplicate report denied")
    Test.check(aborted(H.handoff(observed(), 1n, before_retire(1n)), 2n, H.UntrustedFacts{}),
      "HH-003 unretired handoff denied")
    Test.check(aborted(H.handoff(observed(), 1n, unsafe_channels(1n)), 2n, H.UntrustedFacts{}),
      "HH-003 unmediated channel denied")
    Test.check(moved(H.handoff(observed(), 1n, evidence(1n)), H.HandoffClosed{}, 2n),
      "HH-003 verified synthetic handoff consumes phase")
    Test.check(aborted(H.handoff(ready(), 2n, evidence(2n)), 3n, H.WrongPhase{}),
      "HH-003 duplicate handoff denied")
    Test.check(aborted(attempt(observed(), 1n, evidence(2n), PT.base(), 0n, PT.mediated_inventory(), PT.now()),
      2n, H.WrongPhase{}), "HH-004 early admission has no effect")
    Test.check(core_denied(attempt(ready(), 2n, evidence(2n), PT.base(), 1n, PT.mediated_inventory(), PT.now()),
      3n, PT.base(), P.StaleRevision{}), "HH-004 core stale revision denied by existing gate")
    Test.check(core_denied(attempt(ready(), 2n, evidence(2n), PT.base(), 0n, PT.leaky_inventory(), PT.now()),
      3n, PT.base(), P.UnmediatedRoute{}), "HH-004 core rejects unmediated native route fact")
    Test.check(core_denied(attempt(ready(), 2n, evidence(2n), retired_core(), 0n, PT.mediated_inventory(), PT.now()),
      3n, retired_core(), P.Identity{I.Retired{}}), "HH-004 core rejects revoked input")
    Test.check(success(attempt(ready(), 2n, evidence(2n), PT.base(), 0n, PT.mediated_inventory(), PT.now())),
      "HH-004 only real admission emits exact DeliverInputs effect")
    Test.check(moved(H.retire(ready(), 2n), H.Retired{}, 3n),
      "HH-005 timeout retirement has no protected effect")
    Test.check(denied(attempt(H.step_state(H.retire(ready(), 2n)), 3n, evidence(3n), PT.base(), 0n,
      PT.mediated_inventory(), PT.now()), H.step_state(H.retire(ready(), 2n)), H.WrongPhase{}),
      "HH-005 retired preflight cannot admit")
    Test.check(denied(H.handoff(observed(), 0n, evidence(2n)), observed(), H.StaleRevision{}),
      "HH-006 copied old handoff revision denied against current state")
    Test.check(denied(H.admit(H.step_state(attempt(ready(), 2n, evidence(2n), PT.base(), 0n,
      PT.mediated_inventory(), PT.now())), 3n, evidence(3n), PT.admitted(), P.revision(PT.admitted()),
      PT.full_report(), PT.mediated_inventory(), PT.now()),
      H.step_state(attempt(ready(), 2n, evidence(2n), PT.base(), 0n, PT.mediated_inventory(), PT.now())), H.WrongPhase{}),
      "HH-006 duplicate admission with current monitor state denied")
    Test.check(core_denied(attempt(ready(), 2n, evidence(2n), PT.admitted(), P.revision(PT.admitted()),
      PT.mediated_inventory(), PT.now()), 3n, PT.admitted(), P.SlotOccupied{}),
      "HH-006 copied ready phase cannot readmit occupied core slot")
    Test.check(core_denied(attempt(ready(), 2n, evidence(2n), PT.base(), 0n, PT.mediated_inventory(), PT.input_expires()),
      3n, PT.base(), P.Identity{I.Expired{}}), "HH-006 existing identity gate rejects expired input")
    Test.check(success(attempt(ready(), 2n, evidence(2n), PT.base(), 0n, PT.mediated_inventory(), PT.now())),
      "HH-006 identical synthetic snapshots require trusted current-state installation")
    Test.check(denied(H.observe(H.step_state(H.observe(initial(), 0n, evidence(0n), False{})), 1n, evidence(1n), True{}),
      H.step_state(H.observe(initial(), 0n, evidence(0n), False{})), H.WrongPhase{}),
      "HH-007 malformed report cannot be retried after poison")
    Test.check(denied(H.handoff(H.step_state(H.handoff(observed(), 1n, before_retire(1n))), 2n, evidence(2n)),
      H.step_state(H.handoff(observed(), 1n, before_retire(1n))), H.WrongPhase{}),
      "HH-007 uncertain handoff cannot be retried after poison")
    Test.check(denied(attempt(H.step_state(attempt(ready(), 2n, evidence(2n), PT.base(), 0n,
      PT.leaky_inventory(), PT.now())), 3n, evidence(3n), PT.base(), 0n, PT.mediated_inventory(), PT.now()),
      H.step_state(attempt(ready(), 2n, evidence(2n), PT.base(), 0n, PT.leaky_inventory(), PT.now())), H.WrongPhase{}),
      "HH-007 denied native-route fact consumes the attempt")
    Test.check(denied(H.handoff(H.step_state(H.retire(observed(), 1n)), 2n, evidence(2n)),
      H.step_state(H.retire(observed(), 1n)), H.WrongPhase{}),
      "HH-007 trusted adapter retires connection after stale protocol failure")
    Test.check(core_denied(H.admit(ready(), 2n, evidence(2n), PT.base(), 0n,
      PT.missing_report(P.control_no_ambient_network()), PT.mediated_inventory(), PT.now()),
      3n, PT.base(), P.MissingControl{}), "HH-004 existing gate rejects missing control")
    Test.check(denied(H.observe(H.step_state(H.observe(observed(), 1n, evidence(1n), True{})), 2n,
      evidence(2n), True{}), H.step_state(H.observe(observed(), 1n, evidence(1n), True{})), H.WrongPhase{}),
      "HH-007 duplicate report poisons preflight before retry")
    Test.check(denied(H.handoff(H.step_state(H.handoff(ready(), 2n, evidence(2n))), 3n, evidence(3n)),
      H.step_state(H.handoff(ready(), 2n, evidence(2n))), H.WrongPhase{}),
      "HH-007 duplicate handoff poisons preflight before retry")
    Test.check(aborted(attempt(ready(), 2n, evidence(2n), PT.table_on(PT.base(), 0n, PT.restarted_identity()),
      0n, PT.mediated_inventory(), PT.now()), 3n, H.UntrustedFacts{}),
      "HH-006 restarted monitor incarnation aborts stale preflight")
    Test.check(aborted(H.handoff(observed(), 1n, evidence(0n)), 2n, H.UntrustedFacts{}),
      "HH-006 stale trusted evidence cannot advance a later phase")
    Test.check(aborted(H.observe(initial(), 0n, unauthenticated(0n), True{}), 1n, H.UntrustedFacts{}),
      "HH-002 unauthenticated synthetic peer aborts preflight")
    Test.check(aborted(H.observe(initial(), 0n, missing_controls(0n), True{}), 1n, H.UntrustedFacts{}),
      "HH-002 missing synthetic control aborts preflight")
    Test.check(aborted(attempt(ready(), 2n, unsafe_channels(2n), PT.base(), 0n,
      PT.mediated_inventory(), PT.now()), 3n, H.UntrustedFacts{}),
      "HH-006 route facts rechecked before actual admission")
