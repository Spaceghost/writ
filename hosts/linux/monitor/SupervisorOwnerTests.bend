import Base
import ./SupervisorOwner.bend as O
import ./LinuxHost.bend as LH
import ./LinuxJointAuthority.bend as JA
import ./LinuxJointOwnerTests.bend as JO
import ./LocalChannel.bend as C
import ../../../HostConformanceVectors.bend as V
import ../../../HostPrimitives.bend as P
import ../../../HostPrimitivesTests.bend as PT
import ../../../Issuance.bend as Iss
import ../../../Test.bend as Test

# Synthetic role map, channel facts and clock samples over the shared joint
# owner stages; nothing here observes an OS peer or a host clock. Role 1 is
# principal 101 (the source authority that issued approval 5 in the joint
# fixture) and role 2 is principal 102, which issued no approval there. The
# running stage's clock is at 110 and the delivered grant expires at 120.

def roles() -> C.RoleMap:
  C.Role{1n, Iss.Principal{101n}, C.Role{2n, Iss.Principal{102n}, C.NoRoles{}}}

def owner_of(+state: LH.State) -> O.Owner:
  O.Owner{roles(), state}

def revoke(approval: Nat) -> +List<U32>:
  O.encode_control(O.Revoke{approval})

def authority() -> P.AdmissionAuthority:
  V.fixture_authority(110n)

def control(+state: LH.State, fact: C.ChannelFact, +bytes: +List<U32>, sample: LH.ClockSample) -> O.OwnerStep:
  O.step(owner_of(state), O.ControlMessage{fact, bytes}, sample, authority())

def high_is(clock: LH.Clock, expected: Nat) -> Bool:
  match clock:
    case LH.LiveClock{high}: Nat.is_eq(high, expected)
    case _: False{}

def poisoned(clock: LH.Clock) -> Bool:
  match clock:
    case LH.PoisonedClock{_}: True{}
    case _: False{}

def issuer_revision(owner: JA.Joint) -> Nat:
  match owner:
    case JA.Joint{issuer, _, _, _, _, _, _, _, _}: Iss.revision(issuer)
    case _: 0n

def failed(owner: JA.Joint) -> Bool:
  match owner:
    case JA.Joint{_, _, _, _, _, _, _, JA.JointFailed{_}, _}: True{}
    case _: False{}

def active(owner: JA.Joint) -> Bool:
  match owner:
    case JA.Joint{_, _, _, _, _, _, _, JA.JointActive{}, _}: True{}
    case _: False{}

def is_applied(result: O.OwnerResult) -> Bool:
  match result:
    case O.Control{O.RevokeApplied{_}}: True{}
    case _: False{}

def is_refused(result: O.OwnerResult) -> Bool:
  match result:
    case O.Control{O.RevokeRefused{_}}: True{}
    case _: False{}

def is_contained(result: O.OwnerResult) -> Bool:
  match result:
    case O.Control{O.Contained{_}}: True{}
    case _: False{}

def is_denied(result: O.OwnerResult) -> Bool:
  match result:
    case O.Control{O.ChannelDenied{_, _}}: True{}
    case _: False{}

def error_equal(a: O.ControlError, b: O.ControlError) -> Bool:
  match a b:
    case O.ControlTooLong{} O.ControlTooLong{}: True{}
    case O.ControlMisaligned{} O.ControlMisaligned{}: True{}
    case O.ControlRange{} O.ControlRange{}: True{}
    case O.ControlVersion{} O.ControlVersion{}: True{}
    case O.ControlTag{} O.ControlTag{}: True{}
    case O.ControlLength{} O.ControlLength{}: True{}
    case O.ControlKind{} O.ControlKind{}: True{}
    case _ _: False{}

def is_undecoded(result: O.OwnerResult, expected: O.ControlError) -> Bool:
  match result:
    case O.Control{O.ControlUndecoded{_, got}}: error_equal(got, expected)
    case _: False{}

def after(stepped: O.OwnerStep) -> LH.State:
  O.Owner.state(O.OwnerStep.owner(stepped))

# Policy and issuer unchanged against `before`, while the clock moved to `high`.
def only_clock_moved(+before: LH.State, +stepped: O.OwnerStep, high: Nat) -> Bool:
  +now = after(stepped)
  high_is(LH.clock(now), high) && PT.state_equal(LH.portable(now), LH.portable(before))
    && Nat.is_eq(issuer_revision(LH.joint(now)), issuer_revision(LH.joint(before)))
    && active(LH.joint(now)) && Bool.not(O.requires_containment(O.OwnerStep.result(stepped)))

# An attributed issuer revoke commits the issuer revision, retains the new
# sample and requires containment; the existing drain then stops worker 1.
def attributed_revoke_applies(+s: JO.Stages) -> Bool:
  +before = JO.stage_running(s)
  +stepped = control(before, C.FromRole{1n}, revoke(5n), LH.Sample{112n})
  +now = after(stepped)
  is_applied(O.OwnerStep.result(stepped)) && O.requires_containment(O.OwnerStep.result(stepped))
    && high_is(LH.clock(now), 112n) && failed(LH.joint(now))
    && Nat.is_gt(issuer_revision(LH.joint(now)), issuer_revision(LH.joint(before)))
    && JO.drain_correct(LH.joint_drain(now))

# Role 2 names principal 102, which did not issue approval 5. The issuer
# refuses; only the watermark advances.
def non_issuer_refused(+s: JO.Stages) -> Bool:
  +before = JO.stage_running(s)
  +stepped = control(before, C.FromRole{2n}, revoke(5n), LH.Sample{113n})
  is_refused(O.OwnerStep.result(stepped)) && only_clock_moved(before, stepped, 113n)

# One case per helper keeps generated native continuations within the
# backend's arity limit.
def denied_case(+before: LH.State, fact: C.ChannelFact) -> Bool:
  +stepped = control(before, fact, revoke(5n), LH.Sample{114n})
  is_denied(O.OwnerStep.result(stepped)) && only_clock_moved(before, stepped, 114n)

def unattributed_advances(+s: JO.Stages) -> Bool:
  +before = JO.stage_running(s)
  denied_case(before, C.UnknownSender{}) && denied_case(before, C.FromRole{9n})
    && denied_case(before, O.fact_of_verdict(6n, 1n))

def undecoded_case(+before: LH.State, +bytes: +List<U32>, reason: O.ControlError) -> Bool:
  +stepped = control(before, C.FromRole{1n}, bytes, LH.Sample{115n})
  is_undecoded(O.OwnerStep.result(stepped), reason) && only_clock_moved(before, stepped, 115n)

def malformed_advances(+s: JO.Stages) -> Bool:
  +before = JO.stage_running(s)
  undecoded_case(before, [1, 0, 0], O.ControlMisaligned{})
    && undecoded_case(before, [256, 0, 0, 0], O.ControlRange{})
    && undecoded_case(before, [1, 0, 0, 0, 9, 0, 0, 0, 1, 0, 0, 0, 5, 0, 0, 0], O.ControlTag{})
    && undecoded_case(before, [2, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 5, 0, 0, 0], O.ControlVersion{})
    && undecoded_case(before, [1, 0, 0, 0, 1, 0, 0, 0, 2, 0, 0, 0, 5, 0, 0, 0], O.ControlLength{})

def zeros(+count: Nat) -> +List<U32>:
  match count:
    case 0n: []
    case 1n+left: 0 <> zeros(left)

def oversized_advances(+s: JO.Stages) -> Bool:
  +before = JO.stage_running(s)
  +long = control(before, C.FromRole{1n}, zeros(1028n), LH.Sample{115n})
  is_undecoded(O.OwnerStep.result(long), O.ControlTooLong{}) && only_clock_moved(before, long, 115n)

# A regressing or faulted sample poisons the clock and contains the owner
# before attribution. Revocation stays available as cleanup: an issuer's revoke
# is still applied, while a refused one is reported as containment with the
# issuer unchanged.
def faulted_sample_contains(+before: LH.State, +sample: LH.ClockSample) -> Bool:
  +applied = control(before, C.FromRole{1n}, revoke(5n), sample)
  +refused = control(before, C.FromRole{2n}, revoke(5n), sample)
  +now = after(applied)
  is_applied(O.OwnerStep.result(applied)) && O.requires_containment(O.OwnerStep.result(applied))
    && poisoned(LH.clock(now)) && failed(LH.joint(now))
    && Nat.is_gt(issuer_revision(LH.joint(now)), issuer_revision(LH.joint(before)))
    && JO.drain_correct(LH.joint_drain(now))
    && is_contained(O.OwnerStep.result(refused)) && O.requires_containment(O.OwnerStep.result(refused))
    && poisoned(LH.clock(after(refused)))
    && failed(LH.joint(after(refused)))
    && Nat.is_eq(issuer_revision(LH.joint(after(refused))), issuer_revision(LH.joint(before)))

def bad_clock_contains(+s: JO.Stages) -> Bool:
  +before = JO.stage_running(s)
  faulted_sample_contains(before, LH.Sample{109n}) && faulted_sample_contains(before, LH.UnavailableClock{})
    && faulted_sample_contains(before, LH.AmbiguousClock{}) && faulted_sample_contains(before, LH.OverflowClock{})

# A sample past the delivered grant's expiry contains the owner before the
# control message is considered, though the clock itself stays live. An
# unattributed sender or a malformed payload must not mask that containment.
def expired_case(+before: LH.State, fact: C.ChannelFact, +bytes: +List<U32>) -> Bool:
  +stepped = control(before, fact, bytes, LH.Sample{125n})
  +now = after(stepped)
  is_contained(O.OwnerStep.result(stepped)) && high_is(LH.clock(now), 125n) && failed(LH.joint(now))

def expired_contains(+s: JO.Stages) -> Bool:
  +before = JO.stage_running(s)
  +issuer = control(before, C.FromRole{1n}, revoke(5n), LH.Sample{125n})
  expired_case(before, C.FromRole{2n}, revoke(5n)) && expired_case(before, C.UnknownSender{}, revoke(5n))
    && expired_case(before, C.FromRole{1n}, [1, 0, 0])
    && is_applied(O.OwnerStep.result(issuer)) && failed(LH.joint(after(issuer)))
    && Nat.is_gt(issuer_revision(LH.joint(after(issuer))), issuer_revision(LH.joint(before)))

# Serialization: a revoke step followed by a worker frame on the same owner.
# The frame sees the retained contained owner and cannot reach the worker path,
# and no effect is handed off for either step.
def revoke_then_frame(+s: JO.Stages) -> Bool:
  +first = control(JO.stage_running(s), C.FromRole{1n}, revoke(5n), LH.Sample{111n})
  +frame = {O.step(O.OwnerStep.owner(first), O.MonitorFrame{[1]}, LH.Sample{112n}, authority()) : O.OwnerStep}
  is_applied(O.OwnerStep.result(first)) && List.is_empty(&2, P.Effect, O.effects(O.OwnerStep.result(first)))
    && O.requires_containment(O.OwnerStep.result(frame))
    && List.is_empty(&2, P.Effect, O.effects(O.OwnerStep.result(frame)))

# A monitor frame advances the same watermark a later control message checks:
# after a frame at 116, a control message sampled at 115 regresses.
def regressing_after(+frame: O.OwnerStep, +revision: Nat) -> Bool:
  +later = {O.step(O.OwnerStep.owner(frame), O.ControlMessage{C.FromRole{2n}, revoke(5n)}, LH.Sample{115n},
    authority()) : O.OwnerStep}
  high_is(LH.clock(after(frame)), 116n) && is_contained(O.OwnerStep.result(later))
    && poisoned(LH.clock(after(later))) && Nat.is_eq(issuer_revision(LH.joint(after(later))), revision)

def frame_then_regressing_control(+s: JO.Stages) -> Bool:
  +before = JO.stage_running(s)
  regressing_after(O.step(owner_of(before), O.MonitorFrame{[1]}, LH.Sample{116n}, authority()),
    issuer_revision(LH.joint(before)))

def names_102(found: C.Attribution) -> Bool:
  match found:
    case C.Attributed{Iss.Principal{id}}: Nat.is_eq(id, 102n)
    case _: False{}

# The role map is part of the owner and survives every step unchanged.
def roles_retained(+s: JO.Stages) -> Bool:
  +stepped = control(JO.stage_running(s), C.FromRole{2n}, revoke(5n), LH.Sample{113n})
  names_102(C.attribute(O.Owner.roles(O.OwnerStep.owner(stepped)), C.FromRole{2n}))

def reject_equal(a: C.ChannelReject, b: C.ChannelReject) -> Bool:
  match a b:
    case C.MissingSender{} C.MissingSender{}: True{}
    case C.DuplicateSender{} C.DuplicateSender{}: True{}
    case C.PayloadTruncated{} C.PayloadTruncated{}: True{}
    case C.ControlTruncated{} C.ControlTruncated{}: True{}
    case C.UnexpectedRights{} C.UnexpectedRights{}: True{}
    case C.UnexpectedControl{} C.UnexpectedControl{}: True{}
    case C.SenderError{} C.SenderError{}: True{}
    case _ _: False{}

# A standalone owner has no issuer to revoke. After a faulted sample its refusal
# is reported as containment, not as an ordinary refusal, and the clock is
# poisoned; a current sample reports the ordinary refusal.
def standalone_fault(+result: O.OwnerResult, +clock: LH.Clock) -> Bool:
  is_contained(result) && O.requires_containment(result) && poisoned(clock)

def standalone_reports() -> Bool:
  +faulted = {O.step(owner_of(LH.initial()), O.ControlMessage{C.FromRole{1n}, revoke(5n)}, LH.UnavailableClock{},
    authority()) : O.OwnerStep}
  standalone_fault(O.OwnerStep.result(faulted), LH.clock(after(faulted)))
    && is_refused(O.OwnerStep.result(O.step(owner_of(LH.initial()), O.ControlMessage{C.FromRole{1n}, revoke(5n)},
      LH.Sample{110n}, authority())))

def drain_step(+owner: O.Owner) -> O.OwnerStep:
  O.step(owner, O.Drain{}, LH.UnavailableClock{}, authority())

def stops_worker_one(effects: +List<P.Effect>) -> Bool:
  match effects:
    case P.StopEffects{worker} <> []: Nat.is_eq(worker, 1n)
    case _: False{}

# After an applied revoke the owner is failed. A second issuer revoke (the
# fixture's unrelated approval 9) still applies, and the drain runs through the
# same `step` with no usable clock: it hands off worker 1's stop once, then
# completes with nothing more.
def drained_twice(+drained: O.OwnerStep) -> Bool:
  +again = drain_step(O.OwnerStep.owner(drained))
  stops_worker_one(O.effects(O.OwnerStep.result(drained))) && O.requires_containment(O.OwnerStep.result(drained))
    && List.is_empty(&2, P.Effect, O.effects(O.OwnerStep.result(again))) && high_is(LH.clock(after(again)), 112n)

def second_applied(+second: O.OwnerStep, +revision: Nat) -> Bool:
  is_applied(O.OwnerStep.result(second)) && Nat.is_gt(issuer_revision(LH.joint(after(second))), revision)
    && drained_twice(drain_step(O.OwnerStep.owner(second)))

def second_revoke(+first: O.OwnerStep) -> Bool:
  is_applied(O.OwnerStep.result(first))
    && second_applied(O.step(O.OwnerStep.owner(first), O.ControlMessage{C.FromRole{1n}, revoke(9n)},
      LH.Sample{112n}, authority()), issuer_revision(LH.joint(after(first))))

def cleanup_after_containment(+s: JO.Stages) -> Bool:
  second_revoke(control(JO.stage_running(s), C.FromRole{1n}, revoke(5n), LH.Sample{111n}))

def duplicate_roles() -> C.RoleMap:
  C.Role{1n, Iss.Principal{101n}, C.Role{1n, Iss.Principal{102n}, C.NoRoles{}}}

def denied_invalid(result: O.OwnerResult) -> Bool:
  match result:
    case O.Control{O.ChannelDenied{_, C.InvalidRoleMap{}}}: True{}
    case _: False{}

# An owner provisioned with an invalid role map attributes nothing, even the
# issuer's role; the watermark still advances.
def invalid_roles_deny(+s: JO.Stages) -> Bool:
  +before = JO.stage_running(s)
  +stepped = {O.step(O.Owner{duplicate_roles(), before}, O.ControlMessage{C.FromRole{1n}, revoke(5n)},
    LH.Sample{113n}, authority()) : O.OwnerStep}
  denied_invalid(O.OwnerStep.result(stepped)) && only_clock_moved(before, stepped, 113n)

def is_bad(read: O.ControlRead, expected: O.ControlError) -> Bool:
  match read:
    case O.ControlBad{got}: error_equal(got, expected)
    case _: False{}

# Version is checked before the header length: a frame wrong in both reports
# the version.
def version_before_length() -> Bool:
  is_bad(O.decode_control([2, 0, 0, 0, 1, 0, 0, 0, 2, 0, 0, 0, 5, 0, 0, 0]), O.ControlVersion{})

def verdict_is(fact: C.ChannelFact, expected: C.ChannelFact) -> Bool:
  match fact expected:
    case C.FromRole{a} C.FromRole{b}: Nat.is_eq(a, b)
    case C.UnknownSender{} C.UnknownSender{}: True{}
    case C.Malformed{a} C.Malformed{b}: reject_equal(a, b)
    case _ _: False{}

# The verdict translator follows supervisor_channel.h's enum order; an
# out-of-range number is SenderError, and the role word is used only for FromRole.
def verdicts_translate() -> Bool:
  verdict_is(O.fact_of_verdict(0n, 2n), C.FromRole{2n}) && verdict_is(O.fact_of_verdict(1n, 2n), C.UnknownSender{})
    && verdict_is(O.fact_of_verdict(2n, 2n), C.Malformed{C.MissingSender{}})
    && verdict_is(O.fact_of_verdict(3n, 2n), C.Malformed{C.DuplicateSender{}})
    && verdict_is(O.fact_of_verdict(4n, 2n), C.Malformed{C.PayloadTruncated{}})
    && verdict_is(O.fact_of_verdict(5n, 2n), C.Malformed{C.ControlTruncated{}})
    && verdict_is(O.fact_of_verdict(6n, 2n), C.Malformed{C.UnexpectedRights{}})
    && verdict_is(O.fact_of_verdict(7n, 2n), C.Malformed{C.UnexpectedControl{}})
    && verdict_is(O.fact_of_verdict(8n, 2n), C.Malformed{C.SenderError{}})
    && verdict_is(O.fact_of_verdict(9n, 2n), C.Malformed{C.SenderError{}})

def reads_approval(read: O.ControlRead, expected: Nat) -> Bool:
  match read:
    case O.ControlRead{O.Revoke{approval}}: Nat.is_eq(approval, expected)
    case _: False{}

def round_trip() -> Bool:
  reads_approval(O.decode_control(revoke(70000n)), 70000n)

# Public entry point: Tests.bend passes the stages it shares with the joint
# owner suites.
def owner_checks(+s: JO.Stages) -> IO(Unit):
  do IO<Unit>:
    Test.check(round_trip(), "SupervisorOwner control payload round-trips a revoke")
    Test.check(verdicts_translate(), "SupervisorOwner receiver verdicts translate in enum order")
    Test.check(attributed_revoke_applies(s), "SupervisorOwner issuer role revoke applies, advances clock and requires containment")
    Test.check(non_issuer_refused(s), "SupervisorOwner non-issuer role revoke is refused and only advances the clock")
    Test.check(unattributed_advances(s), "SupervisorOwner unattributed and malformed senders deny and only advance the clock")
    Test.check(malformed_advances(s), "SupervisorOwner malformed control payloads deny and only advance the clock")
    Test.check(oversized_advances(s), "SupervisorOwner oversized control payload denies and only advances the clock")
    Test.check(version_before_length(), "SupervisorOwner control decoding checks version before length")
    Test.check(bad_clock_contains(s), "SupervisorOwner faulted sample contains; issuer revoke still applies, refused revoke does not")
    Test.check(expired_contains(s), "SupervisorOwner expired owner contains; only an issuer revoke still applies")
    Test.check(revoke_then_frame(s), "SupervisorOwner revoke then frame: the frame sees containment and no effect is handed off")
    Test.check(frame_then_regressing_control(s), "SupervisorOwner frame and control share one watermark")
    Test.check(roles_retained(s), "SupervisorOwner role map is retained across steps")
    Test.check(standalone_reports(), "SupervisorOwner standalone owner reports a faulted sample as containment")
    Test.check(invalid_roles_deny(s), "SupervisorOwner invalid role map denies the issuer role and only advances the clock")
    Test.check(cleanup_after_containment(s), "SupervisorOwner revoke and drain remain available after containment")
    IO.print("SupervisorOwner: 16 checks passed")

def main() -> IO(Unit):
  owner_checks(JO.owner_stages())
