import Base
import ./LinuxHost.bend as LH
import ./LinuxJointAuthority.bend as JA
import ./LinuxHostTests.bend as LT
import ./LinuxJointOwnerTests.bend as JT
import ./LinuxClockTests.bend as LC
import ../../../HostPrimitives.bend as P
import ../../../HostPrimitivesTests.bend as PT
import ../../../HostConformanceVectors.bend as V
import ../../../RendezvousTests.bend as RT
import ../../../IssuanceTests.bend as IT
import ../../../HostWire.bend as W
import ../../../Test.bend as Test

# Synthetic owner state and session-loss signals; no OS process is observed.
def running(world: RT.Sc) -> LH.State:
  LH.Outcome.state(JT.delivered(world))

def stopped_history(owner: JA.Joint) -> Bool:
  match owner:
    case JA.Joint{_, _, _, _, _, _, JA.NoLineage{}, JA.JointFailed{P.StopEffects{1n} <> []}, JA.NoJoint{}}: True{}
    case _: False{}

def lost_active(+world: RT.Sc) -> Bool:
  +before = {running(world) : LH.State}
  +result = {LH.session_lost(before) : LH.Outcome}
  +after = {LH.Outcome.state(result) : LH.State}
  JT.deliver_result(JT.delivered(world)) && JT.is_contained(result) && JT.is_failed(LH.joint(after))
    && LT.policy_credentials_equal(before, after) && JT.clock_still_live(LH.clock(after))
    && PT.effects_equal(LH.Outcome.effects(result), [])
    && JT.is_contained(LH.session_lost(after))
    && LT.policy_credentials_equal(after, LH.Outcome.state(LH.session_lost(after)))
    && PT.effects_equal(LH.Outcome.effects(LH.session_lost(after)), [])

def joint_frame() -> +List<U32>:
  +request = W.encode_bytes(JT.guard_use())
  +credential = {LH.Credential{1000n, 1000n, 4242n, 917n} : LH.Credential}
  LT.synthetic_framed(LH.frame_barrier(), 1 <> LT.synthetic_fact_words(201n, RT.token_a(), 1n,
    credential, credential, U32.from_nat(List.length(&2, U32, request)) <> request))

def after_loss_routes(+state: LH.State) -> Bool:
  +authority = {V.fixture_authority(110n) : P.AdmissionAuthority}
  +broker = {LH.dispatch(state, LH.FromBroker{LH.Barrier{1n, JT.fact(), W.encode_bytes(JT.guard_use())}},
    LH.Sample{110n}, authority) : LH.Outcome}
  +worker = {LH.dispatch(state, LH.FromWorker{1n, W.encode_bytes(JT.guard_use())},
    LH.Sample{110n}, authority) : LH.Outcome}
  JT.is_contained(broker) && JT.is_contained(worker)
    && PT.effects_equal(LH.Outcome.effects(broker), []) && PT.effects_equal(LH.Outcome.effects(worker), [])
    && JT.action_contained(LH.joint_issue(state, 1n, 4, 120n, 110n))
    && JT.action_contained(LH.joint_dispatch(state, 1n, 110n))

def after_serve(+world: RT.Sc) -> Bool:
  +ready = {JT.issued_once(world) : LH.State}
  +positive = {LH.serve(ready, joint_frame(), LH.Sample{110n}, V.fixture_authority(110n)) : LH.Served}
  +running = {LH.next(positive) : LH.State}
  +lost = {LH.Outcome.state(LH.session_lost(running)) : LH.State}
  +after = {LH.serve(lost, joint_frame(), LH.Sample{110n}, V.fixture_authority(110n)) : LH.Served}
  PT.effects_equal(LH.served_effects(positive), [P.DeliverInputs{1n, W.Ref{60, 1, 1, 1}}])
    && String.eq(LH.served_status(after), "FAILSTOP") && String.eq(LH.served_detail(after), "not-processed")
    && PT.effects_equal(LH.served_effects(after), []) && JT.is_failed(LH.joint(LH.next(after)))
    && JT.direct_helpers_for(lost, 110n) && after_loss_routes(lost)

def after_drain(drain: LH.JointDrain) -> Bool:
  match drain:
    case LH.JointDrainStep{+state, P.StopEffects{1n} <> []}:
      +again = {LH.session_lost(state) : LH.Outcome}
      JT.is_contained(again) && PT.effects_equal(LH.Outcome.effects(again), [])
        && stopped_history(LH.joint(LH.Outcome.state(again)))
        && JT.drain_complete(LH.joint_drain(LH.Outcome.state(again)))
    case _: False{}

def loss_drains(world: RT.Sc) -> Bool:
  +lost = {LH.Outcome.state(LH.session_lost(running(world))) : LH.State}
  after_drain(LH.joint_drain(lost))

def restarted_loss(+result: LH.Outcome) -> Bool:
  match result:
    case LH.RestartContained{+state, P.StopEffects{1n} <> []}:
      +again = {LH.session_lost(state) : LH.Outcome}
      JT.restart_result(result) && JT.is_contained(again) && PT.effects_equal(LH.Outcome.effects(again), [])
        && stopped_history(LH.joint(LH.Outcome.state(again)))
        && JT.drain_complete(LH.joint_drain(LH.Outcome.state(again)))
    case _: False{}

def issuer_equal(a: JA.Joint, b: JA.Joint) -> Bool:
  match a b:
    case JA.Joint{ai, _, _, _, _, _, _, _, JA.NoJoint{}} JA.Joint{bi, _, _, _, _, _, _, _, JA.NoJoint{}}:
      IT.State.equal(ai, bi)
    case _ _: False{}

def issuer_after_drain(drain: LH.JointDrain, before: JA.Joint) -> Bool:
  match drain:
    case LH.JointDrainStep{+state, P.StopEffects{1n} <> []}:
      issuer_equal(LH.joint(state), before) && JT.issuer_has_revocation(LH.joint(state))
    case _: False{}

def issuer_retained(+world: RT.Sc) -> Bool:
  +revoked = {LH.joint_revoke(running(world), IT.source_authority(), 5n) : LH.JointAction}
  +before = {LH.JointAction.state(revoked) : LH.State}
  +signal = {LH.session_lost(before) : LH.Outcome}
  +after = {LH.Outcome.state(signal) : LH.State}
  JT.revoke_is_applied(revoked) && JT.issuer_has_revocation(LH.joint(before))
    && JT.is_contained(signal) && PT.effects_equal(LH.Outcome.effects(signal), [])
    && issuer_equal(LH.joint(before), LH.joint(after))
    && issuer_after_drain(LH.joint_drain(after), LH.joint(before))

def restart_after_loss(world: RT.Sc) -> Bool:
  +lost = {LH.Outcome.state(LH.session_lost(running(world))) : LH.State}
  restarted_loss(LH.restart(lost, P.revision(LH.portable(lost)), 2n))

def poison_before_loss(world: RT.Sc) -> Bool:
  +before = {running(world) : LH.State}
  +poison = {LH.Outcome.state(LH.dispatch(before, LH.FromWorker{1n, [1]}, LH.Sample{109n}, V.fixture_authority(110n))) : LH.State}
  +lost = {LH.session_lost(poison) : LH.Outcome}
  JT.is_failed(LH.joint(poison)) && LC.poisoned_at(LH.clock(poison), 110n)
    && JT.is_contained(lost) && LC.poisoned_at(LH.clock(LH.Outcome.state(lost)), 110n)
    && LT.policy_credentials_equal(poison, LH.Outcome.state(lost)) && PT.effects_equal(LH.Outcome.effects(lost), [])
    && JT.drain_correct(LH.joint_drain(LH.Outcome.state(lost)))

def standalone_result(+result: LH.Outcome, +before: LH.State) -> Bool:
  match result:
    case LH.Unrouted{+after}:
      LT.policy_credentials_equal(before, after) && LC.high_is(LH.clock(before), 100n)
        && LC.high_is(LH.clock(after), 100n) && PT.effects_equal(LH.Outcome.effects(result), [])
    case _: False{}

def standalone_unchanged() -> Bool:
  standalone_result(LH.session_lost(LT.delegated()), LT.delegated())

def malformed_owner(world: RT.Sc) -> Bool:
  +before = {JT.nested_owner_state(running(world)) : LH.State}
  +result = {LH.session_lost(before) : LH.Outcome}
  +after = {LH.Outcome.state(result) : LH.State}
  JT.is_contained(result) && JT.nested_retained(after) && LT.policy_credentials_equal(before, after)
    && PT.effects_equal(LH.Outcome.effects(result), []) && JT.malformed_input_guards(after)
    && JT.malformed_control_guards(after) && JT.nested_drain(LH.joint_drain(after))

def incomplete_at(world: RT.Sc, max: Nat) -> Bool:
  +before = {JT.host_revision(running(world), max) : LH.State}
  +after = {LH.Outcome.state(LH.session_lost(before)) : LH.State}
  JT.drain_incomplete_unchanged(LH.joint_drain(after), after)
    && PT.effects_equal(LH.Outcome.effects(LH.session_lost(after)), [])

def incomplete(world: RT.Sc, parsed: Maybe<&2, Nat>) -> Bool:
  match parsed:
    case Some{max}: incomplete_at(world, max)
    case None{}: False{}

def main() -> IO(Unit):
  do IO<Unit>:
    Test.check(lost_active(RT.sc_world()), "LH-session-loss running worker retains state and requires containment")
    Test.check(after_serve(RT.sc_world()), "LH-session-loss valid framed delivery and direct helpers stop after loss")
    Test.check(loss_drains(RT.sc_world()), "LH-session-loss drain emits exact stop once and preserves history")
    Test.check(restart_after_loss(RT.sc_world()), "LH-session-loss restart emits actual stop and stays contained")
    Test.check(issuer_retained(RT.sc_world()), "LH-session-loss retains exact revoked issuer through drain")
    Test.check(poison_before_loss(RT.sc_world()), "LH-session-loss preserves poisoned clock and cleanup")
    Test.check(standalone_unchanged(), "LH-session-loss standalone state is unrouted and unchanged")
    Test.check(malformed_owner(RT.sc_world()), "LH-session-loss malformed owner stays unnormalized and contained")
    Test.check(incomplete(RT.sc_world(), Nat.read("281474976710655")), "LH-session-loss terminal cleanup remains incomplete")
    IO.print("LinuxSessionLoss: 9 checks passed")
