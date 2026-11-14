import Base
import ./SupervisorApproval.bend as SA
import ./SupervisorOwner.bend as O
import ./SupervisorOwnerTests.bend as OT
import ./SupervisorWire.bend as SW
import ./SupervisorWireTests.bend as OTW
import ./LinuxHost.bend as LH
import ./LinuxJointAuthority.bend as JA
import ./LinuxJointOwnerTests.bend as JO
import ./LocalChannel.bend as C
import ../../../Issuance.bend as Iss
import ../../../IssuanceTests.bend as IT
import ../../../Transfer.bend as T
import ../../../TransferTests.bend as TF
import ../../../HostPrimitivesTests.bend as PT
import ../../../Test.bend as Test

# Approval submission over the supervisor control channel, on the synthetic
# joint owner's running stage (clock 110, issuer revision 15, next id 16;
# low serials of principals 101 and 102 already consumed) with the synthetic role
# map 1 -> 101 (read authority for domain 5), 2 -> 102 (write authority for
# domain 6). The approvals are synthetic records, not an authenticated
# operator's; the checks show which principal the owner submits them as and
# that the issuer, not this channel, decides.

# Serial 900 (unused in the fixture) of the source authority: read domain 5, source 10v4, the fixture
# scope, rights 3, valid until 200.
def fresh_source() -> Iss.SourceApproval:
  Iss.SourceApproval{1n, 900n, IT.source_authority(), TF.source_object(), IT.read5(), IT.scope(), 3, 200n}

# Serial 900 of the write authority: write domain 6, destination 20v8.
def fresh_write() -> Iss.WriteApproval:
  Iss.WriteApproval{1n, 900n, IT.write_authority(), TF.destination_object(), IT.write6(), IT.scope(), 3, 200n}

# Principal 102 claims to be the read authority for domain 5.
def forged_source() -> Iss.SourceApproval:
  Iss.SourceApproval{1n, 901n, IT.write_authority(), TF.source_object(), IT.read5(), IT.scope(), 3, 200n}

# Principal 101 claims to be the write authority for domain 6.
def forged_write() -> Iss.WriteApproval:
  Iss.WriteApproval{1n, 902n, IT.source_authority(), TF.destination_object(), IT.write6(), IT.scope(), 3, 200n}

# The source authority's approval valid until `until` (exclusive), serial 903.
def source_until(+until: Nat) -> Iss.SourceApproval:
  Iss.SourceApproval{1n, 903n, IT.source_authority(), TF.source_object(), IT.read5(), IT.scope(), 3, until}

def submit_source(approval: Iss.SourceApproval) -> +List<U32>:
  O.encode_control(O.SubmitSource{approval})

def submit_write(approval: Iss.WriteApproval) -> +List<U32>:
  O.encode_control(O.SubmitWrite{approval})

# The datagrams the native test sends (supervisor-owner-test.c).
def source_hex() -> String:
  "01000000020000001d0000000100000084030000650000000a000000040000000500000001000000020000000300000063000000010000000a00000004000000140000000800000007000000070000000700000007000000070000000700000007000000070000000300000002000000060000000700000003000000c8000000"

def write_hex() -> String:
  "01000000030000001d00000001000000840300006600000014000000080000000600000001000000020000000300000063000000010000000a00000004000000140000000800000007000000070000000700000007000000070000000700000007000000070000000300000002000000060000000700000003000000c8000000"

def revoke16_hex() -> String:
  "01000000010000000100000010000000"

def same_bytes(a: +List<U32>, b: +List<U32>) -> Bool:
  match a b:
    case Nil{} Nil{}: True{}
    case Con{x, xs} Con{y, ys}: U32.is_eq(x, y) && same_bytes(xs, ys)
    case _ _: False{}

def hex_is(hexed: Maybe<&2, +List<U32>>, +bytes: +List<U32>) -> Bool:
  match hexed:
    case Some{decoded}: same_bytes(decoded, bytes)
    case None{}: False{}

def reencoded(read: O.ControlRead) -> +List<U32>:
  match read:
    case O.ControlRead{control}: O.encode_control(control)
    case O.ControlBad{_}: []

def round_trips(+bytes: +List<U32>) -> Bool:
  same_bytes(reencoded(O.decode_control(bytes)), bytes)

# A three-source Copy plan, so the manifest reader takes more than one pair.
def wide_scope() -> Iss.Scope:
  Iss.Scope{T.Plan{TF.stamp(), 98n, T.OCons{TF.source_object(), T.OCons{IT.second_source(),
    T.OCons{TF.source_object(), T.OEnd{}}}}, TF.destination_object(), TF.code(), T.Copy{}, 4},
    IT.write6(), IT.subject()}

def wide_source() -> Iss.SourceApproval:
  Iss.SourceApproval{1n, 4n, IT.source_authority(), TF.source_object(), IT.read5(), wide_scope(), 1, 150n}

# The fixture plan as a Transform, so every kind word is read back.
def transform_write() -> Iss.WriteApproval:
  Iss.WriteApproval{1n, 5n, IT.write_authority(), TF.destination_object(), IT.write6(),
    Iss.Scope{T.Plan{TF.stamp(), 99n, TF.source_manifest(), TF.destination_object(), TF.code(),
      T.Transform{}, 2}, IT.write6(), IT.subject()}, 2, 180n}

# The test writer's bytes are the native test's hex, and decoding then
# re-encoding returns the same bytes for each kind and a wider manifest.
def codec_round_trip() -> Bool:
  hex_is(SW.payload(source_hex()), submit_source(fresh_source()))
    && hex_is(SW.payload(write_hex()), submit_write(fresh_write()))
    && round_trips(submit_source(fresh_source())) && round_trips(submit_write(fresh_write()))
    && round_trips(submit_source(wide_source())) && round_trips(submit_write(transform_write()))

def body() -> +List<U32>:
  SA.encode_parts(SA.source_parts(fresh_source()))

def is_length(read: SA.PartsRead) -> Bool:
  match read:
    case SA.PartsLength{}: True{}
    case _: False{}

def is_kind(read: SA.PartsRead) -> Bool:
  match read:
    case SA.PartsKind{}: True{}
    case _: False{}

def without_last(words: +List<U32>) -> +List<U32>:
  match words:
    case []: []
    case _ <> []: []
    case w <> rest: w <> without_last(rest)

# Replaces word `index` (0-based) of `words` with `value`.
def with_word(words: +List<U32>, +index: Nat, +value: U32) -> +List<U32>:
  match words index:
    case Nil{} _: []
    case Con{_, rest} 0n: value <> rest
    case Con{w, rest} 1n+left: w <> with_word(rest, left, value)

# Word 10 is the manifest count and word 30 the kind (29 words, one source).
def body_faults() -> Bool:
  is_length(SA.decode_parts(without_last(body())))
    && is_length(SA.decode_parts(List.append(&2, U32, body(), [0])))
    && is_length(SA.decode_parts(with_word(body(), 10n, 2)))
    && is_length(SA.decode_parts(with_word(body(), 10n, 0)))
    && is_length(SA.decode_parts([1, 2, 101]))
    && is_kind(SA.decode_parts(with_word(body(), 23n, 4)))
    && is_kind(SA.decode_parts(with_word(body(), 23n, 0)))

def control_faults() -> Bool:
  OT.is_bad(O.decode_control(O.framed(2, with_word(body(), 23n, 9))), O.ControlKind{})
    && OT.is_bad(O.decode_control(O.framed(3, without_last(body()))), O.ControlLength{})
    && OT.is_bad(O.decode_control(O.framed(4, body())), O.ControlTag{})
    && OT.is_bad(O.decode_control(with_word(submit_source(fresh_source()), 8n, 30)), O.ControlLength{})

def next_id(owner: JA.Joint) -> Nat:
  match owner:
    case JA.Joint{+issuer, _, _, _, _, _, _, _, _}: Iss.next_id(issuer)
    case _: 0n

def accepted_as(result: O.OwnerResult, +id: Nat) -> Bool:
  match result:
    case O.Control{O.ApprovalAccepted{_, got}}: Nat.is_eq(got, id)
    case _: False{}

def is_refused(result: O.OwnerResult) -> Bool:
  match result:
    case O.Control{O.ApprovalRefused{_}}: True{}
    case _: False{}

def send(+state: LH.State, +role: Nat, +bytes: +List<U32>, +now: Nat) -> O.OwnerStep:
  OT.control(state, C.FromRole{role}, bytes, LH.Sample{now})

# Accepted at revision 15 as id 16: the issuer advances by one, the clock to
# the sample, and nothing else changes; no containment is required.
def accepted_case(+before: LH.State, +role: Nat, +bytes: +List<U32>) -> Bool:
  +stepped = send(before, role, bytes, 111n)
  +now = OT.after(stepped)
  accepted_as(O.OwnerStep.result(stepped), next_id(LH.joint(before)))
    && Bool.not(O.requires_containment(O.OwnerStep.result(stepped)))
    && OT.high_is(LH.clock(now), 111n) && OT.active(LH.joint(now))
    && PT.state_equal(LH.portable(now), LH.portable(before))
    && Nat.is_eq(OT.issuer_revision(LH.joint(now)), (1n + OT.issuer_revision(LH.joint(before)) : Nat))
    && Nat.is_eq(next_id(LH.joint(now)), (1n + next_id(LH.joint(before)) : Nat))

def authorities_accepted(+s: JO.Stages) -> Bool:
  +before = JO.stage_running(s)
  accepted_case(before, 1n, submit_source(fresh_source()))
    && accepted_case(before, 2n, submit_write(fresh_write()))

def refused_case(+before: LH.State, +role: Nat, +bytes: +List<U32>) -> Bool:
  +stepped = send(before, role, bytes, 111n)
  is_refused(O.OwnerStep.result(stepped)) && OT.only_clock_moved(before, stepped, 111n)

# The record's issuer claim is checked against the attributed principal, and
# the directory against that principal: role 2 cannot submit principal 101's
# approval or claim the read domain it does not control, and role 1 can
# neither submit principal 102's write approval nor claim write domain 6.
def wrong_principal_refused(+s: JO.Stages) -> Bool:
  +before = JO.stage_running(s)
  refused_case(before, 2n, submit_source(fresh_source()))
    && refused_case(before, 2n, submit_source(forged_source()))
    && refused_case(before, 1n, submit_write(fresh_write()))
    && refused_case(before, 1n, submit_write(forged_write()))

# Serial 1 is already consumed in the fixture, and a resubmitted serial 900
# is a replay.
def replay_refused(+s: JO.Stages) -> Bool:
  +before = JO.stage_running(s)
  +first = OT.after(send(before, 1n, submit_source(fresh_source()), 111n))
  refused_case(before, 1n, submit_source(IT.good_source()))
    && refused_case(first, 1n, submit_source(fresh_source()))

# The issuer judges the lifetime at the sampled time (111): an approval valid
# until 111 is expired, one valid until 112 is accepted.
def lifetime_at_sample(+s: JO.Stages) -> Bool:
  +before = JO.stage_running(s)
  refused_case(before, 1n, submit_source(source_until(111n)))
    && accepted_case(before, 1n, submit_source(source_until(112n)))

def is_applied(result: O.OwnerResult) -> Bool:
  match result:
    case O.Control{O.RevokeApplied{_}}: True{}
    case _: False{}

def revoke_refused(result: O.OwnerResult) -> Bool:
  match result:
    case O.Control{O.RevokeRefused{_}}: True{}
    case _: False{}

# The submitted approval 16 is revocable by its issuer's role only, through the
# existing revoke path, which requires containment.
def submitted_revocable(+s: JO.Stages) -> Bool:
  +first = OT.after(send(JO.stage_running(s), 1n, submit_source(fresh_source()), 111n))
  +applied = send(first, 1n, OT.revoke(16n), 112n)
  revoke_refused(O.OwnerStep.result(send(first, 2n, OT.revoke(16n), 112n)))
    && is_applied(O.OwnerStep.result(applied)) && O.requires_containment(O.OwnerStep.result(applied))

def not_submitted(+before: LH.State, sample: LH.ClockSample) -> Bool:
  +stepped = OT.control(before, C.FromRole{1n}, submit_source(fresh_source()), sample)
  OT.is_contained(O.OwnerStep.result(stepped)) && O.requires_containment(O.OwnerStep.result(stepped))
    && Nat.is_eq(next_id(LH.joint(OT.after(stepped))), next_id(LH.joint(before)))

# Submission is not cleanup: with an unavailable or regressing sample, once
# the delivered grant has expired (125, as in SupervisorOwnerTests), and on an
# owner already contained by a revoke, nothing is submitted and containment is
# reported.
def contained_not_submitted(+s: JO.Stages) -> Bool:
  +before = JO.stage_running(s)
  +revoked = OT.after(send(before, 1n, OT.revoke(5n), 111n))
  not_submitted(before, LH.UnavailableClock{}) && not_submitted(before, LH.Sample{100n})
    && not_submitted(before, LH.Sample{125n}) && not_submitted(revoked, LH.Sample{112n})

def is_submit_contained(submitted: LH.JointSubmission) -> Bool:
  match submitted:
    case LH.SubmitContained{_}: True{}
    case _: False{}

def clock_at(+state: LH.State, +now: Nat) -> LH.State:
  match state:
    case LH.State{p, records, _, owner}: LH.State{p, records, LH.LiveClock{now}, owner}

def terminal_case(+s: JO.Stages, value: Maybe<&2, Nat>) -> Bool:
  match value:
    case Some{maximum}:
      is_submit_contained(LH.joint_submit(JO.issuer_revision_set(JO.stage_running(s), maximum),
        IT.source_authority(), Iss.SourceEntry{fresh_source()}, 110n))
    case None{}: False{}

# `LH.joint_submit` directly: an active owner whose retained clock is past the
# grant's expiry, and an issuer at the revision bound, submit nothing and
# require containment, although the owner path never reaches them.
def joint_submit_guarded(+s: JO.Stages) -> Bool:
  is_submit_contained(LH.joint_submit(clock_at(JO.stage_running(s), 125n), IT.source_authority(),
    Iss.SourceEntry{fresh_source()}, 125n))
    && terminal_case(s, Nat.read("281474976710655"))

# The same sequence over LINUXSUP1: accepted, refused for the wrong role,
# accepted write, then the issuer's revoke of id 16 requires containment.
def wire_sequence(+s: JO.Stages) -> Bool:
  String.eq(OTW.run(OTW.wire(s), [OTW.from_role("1", "111", source_hex()), OTW.from_role("2", "112", source_hex()),
      OTW.from_role("2", "113", write_hex()), OTW.from_role("1", "114", revoke16_hex())]),
    OTW.line("1", "APPROVAL_ACCEPTED", "0", "-") ++ OTW.line("2", "APPROVAL_REFUSED", "0", "-") ++
    OTW.line("3", "APPROVAL_ACCEPTED", "0", "-") ++ OTW.line("4", "REVOKE_APPLIED", "1", "-"))

# Public entry point: Tests.bend passes the stages it shares with the joint
# owner suites.
def approval_checks(+s: JO.Stages) -> IO(Unit):
  do IO<Unit>:
    Test.check(codec_round_trip(), "SupervisorApproval submissions round-trip and match the native test's bytes")
    Test.check(body_faults(), "SupervisorApproval short, long, miscounted and unknown-kind bodies are refused")
    Test.check(control_faults(), "SupervisorOwner submission payload faults report kind, length and tag")
    Test.check(authorities_accepted(s), "SupervisorOwner each role's own approval is accepted without containment")
    Test.check(wrong_principal_refused(s), "SupervisorOwner a role cannot submit another principal's approval")
    Test.check(replay_refused(s), "SupervisorOwner a consumed serial is refused as a replay")
    Test.check(lifetime_at_sample(s), "SupervisorOwner an approval's lifetime is judged at the sampled time")
    Test.check(submitted_revocable(s), "SupervisorOwner a submitted approval is revocable only by its issuer role")
    Test.check(contained_not_submitted(s), "SupervisorOwner nothing is submitted on a faulted, expired or contained owner")
    Test.check(joint_submit_guarded(s), "LinuxHost joint submit refuses a stale retained clock and a terminal issuer revision")
    Test.check(wire_sequence(s), "SupervisorWire approval submission sequence replies exactly")
    IO.print("SupervisorApproval: 11 checks passed")

def main() -> IO(Unit):
  approval_checks(JO.owner_stages())
