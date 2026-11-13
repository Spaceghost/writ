import Base
import ./SupervisorWire.bend as SW
import ./SupervisorOwnerTests.bend as OT
import ./LinuxJointOwnerTests.bend as JO
import ../../../HostPrimitives.bend as P
import ../../../Test.bend as Test

# LINUXSUP1 framing over the synthetic joint owner's running stage (clock 110,
# worker 1 grant expiring at 120, approval 5 issued by principal 101) and the
# synthetic role map 1 -> 101, 2 -> 102. Expected replies are exact strings.

def wire(+s: JO.Stages) -> SW.State:
  SW.provisioned(OT.owner_of(JO.stage_running(s)), OT.authority())

def replies(frames: List<&2, String>, state: SW.State) -> String:
  match frames:
    case []:
      ""
    case frame <> rest:
      +stepped = SW.dispatch(state, frame)
      SW.reply(stepped) ++ replies(rest, SW.next(stepped))

def run(state: SW.State, frames: List<&2, String>) -> String:
  replies(frames, state)

def frame(op: String, verdict: String, role: String, clock: String, now: String, argument: String) -> String:
  String.join(["LINUXSUP1", op, verdict, role, clock, now, argument], "\t")

def revoke5() -> String:
  "01000000010000000100000005000000"

def from_role(role: String, now: String, argument: String) -> String:
  frame("CONTROL", "0", role, "0", now, argument)

def drain() -> String:
  frame("DRAIN", "0", "0", "0", "0", "-")

def line(sequence: String, outcome: String, contain: String, effects: String) -> String:
  String.join(["LINUXSUP1", sequence, outcome, contain, effects], "\t") ++ "\n"

def zeros(n: Nat) -> String:
  match n:
    case 0n: ""
    case 1n+k: "00" ++ zeros(k)

def issuer_sequence(+s: JO.Stages) -> Bool:
  String.eq(run(wire(s), [from_role("2", "112", revoke5()), from_role("1", "113", revoke5()), drain(), drain()]),
    line("1", "REVOKE_REFUSED", "0", "-") ++ line("2", "REVOKE_APPLIED", "1", "-") ++
    line("3", "DRAIN_STEP", "1", "S1") ++ line("4", "DRAIN_COMPLETE", "1", "-"))

def denials(+s: JO.Stages) -> Bool:
  String.eq(run(wire(s), [frame("CONTROL", "1", "0", "0", "111", revoke5()),
      frame("CONTROL", "9", "1", "0", "112", revoke5()), from_role("1", "113", "010203"),
      from_role("1", "114", ""), from_role("3", "115", revoke5())]),
    line("1", "CHANNEL_DENIED", "0", "-") ++ line("2", "CHANNEL_DENIED", "0", "-") ++
    line("3", "CONTROL_UNDECODED", "0", "-") ++ line("4", "CONTROL_UNDECODED", "0", "-") ++
    line("5", "CHANNEL_DENIED", "0", "-"))

# Each multi-step check is split into one-case helpers to stay within the
# native backend's continuation arity limit (247).
def faulted_kinds(+s: JO.Stages) -> Bool:
  String.eq(run(wire(s), [frame("CONTROL", "0", "2", "1", "0", revoke5()), frame("CONTROL", "0", "1", "2", "0", revoke5())]),
    line("1", "CONTAINED", "1", "-") ++ line("2", "REVOKE_APPLIED", "1", "-"))

def expired_kind(+s: JO.Stages) -> Bool:
  String.eq(run(wire(s), [from_role("2", "125", revoke5())]), line("1", "CONTAINED", "1", "-"))

def regressing_kind(+s: JO.Stages) -> Bool:
  String.eq(run(wire(s), [from_role("2", "115", revoke5()), from_role("2", "112", revoke5())]),
    line("1", "REVOKE_REFUSED", "0", "-") ++ line("2", "CONTAINED", "1", "-"))

def clock_kinds(+s: JO.Stages) -> Bool:
  faulted_kinds(s) && expired_kind(s) && regressing_kind(s)

def stops(+s: JO.Stages, bad: String) -> Bool:
  String.eq(run(wire(s), [bad, drain()]), line("1", "ERROR", "1", "-") ++ line("2", "STOPPED", "1", "-"))

def framing_errors_stop(+s: JO.Stages) -> Bool:
  stops(s, String.join(["LINUXSUP2", "DRAIN", "0", "0", "0", "0", "-"], "\t")) &&
  stops(s, from_role("1", "0113", revoke5())) &&
  stops(s, String.join(["LINUXSUP1", "DRAIN", "0", "0", "0", "-"], "\t")) &&
  stops(s, drain() ++ "\t-") &&
  stops(s, frame("REVOKE", "0", "1", "0", "113", revoke5())) &&
  stops(s, from_role("1", "113", "0A000000")) &&
  stops(s, from_role("1", "113", "010")) &&
  stops(s, frame("DRAIN", "0", "0", "0", "1", "-")) &&
  stops(s, frame("FRAME", "1", "0", "0", "113", "00")) &&
  stops(s, frame("CONTROL", "0", "1", "1", "5", revoke5())) &&
  stops(s, frame("CONTROL", "0", "1", "4", "0", revoke5())) &&
  stops(s, from_role("1", "4294967296", revoke5()))

def payload_at_bound(+s: JO.Stages) -> Bool:
  String.eq(run(wire(s), [from_role("1", "113", zeros(4096n))]), line("1", "CONTROL_UNDECODED", "0", "-"))

def payload_bound(+s: JO.Stages) -> Bool:
  payload_at_bound(s) && stops(s, from_role("1", "113", zeros(4097n)))

def frame_then_message(+s: JO.Stages) -> Bool:
  String.eq(run(wire(s), [frame("FRAME", "0", "0", "0", "112", "00"), from_role("2", "111", revoke5())]),
    line("1", "NOT_FRAMED", "0", "-") ++ line("2", "CONTAINED", "1", "-"))

def message_then_frame(+s: JO.Stages) -> Bool:
  String.eq(run(wire(s), [from_role("1", "112", revoke5()), frame("FRAME", "0", "0", "0", "113", "00")]),
    line("1", "REVOKE_APPLIED", "1", "-") ++ line("2", "SERVED", "1", "-"))

def frames_share_owner(+s: JO.Stages) -> Bool:
  frame_then_message(s) && message_then_frame(s)

def bounded_and_stopped(+s: JO.Stages) -> Bool:
  +owner = OT.owner_of(JO.stage_running(s))
  String.eq(SW.reply(SW.dispatch(SW.State{owner, OT.authority(), 100000, False{}}, drain())),
    line("100001", "EXHAUSTED", "1", "-")) &&
  String.eq(SW.reply(SW.dispatch(SW.State{owner, OT.authority(), 5, True{}}, from_role("1", "113", revoke5()))),
    line("6", "STOPPED", "1", "-"))

def effects_render() -> Bool:
  String.eq(SW.render_effects([P.StopEffects{1n}, P.Reclaim{2n}, P.StopEffects{30n}]), "S1,R2,S30") &&
  String.eq(SW.render_effects([]), "-")

def wire_checks(+s: JO.Stages) -> IO(Unit):
  do IO<Unit>:
    Test.check(issuer_sequence(s), "SupervisorWire refused, applied and drained revoke replies in sequence")
    Test.check(denials(s), "SupervisorWire unattributed senders and malformed payloads deny without containment")
    Test.check(clock_kinds(s), "SupervisorWire faulted, expired and regressing samples contain")
    Test.check(framing_errors_stop(s), "SupervisorWire malformed frames reply ERROR and stop the interpreter")
    Test.check(payload_bound(s), "SupervisorWire forwards a 4096-byte payload and rejects 4097 bytes")
    Test.check(frames_share_owner(s), "SupervisorWire monitor frames and control messages share one owner and watermark")
    Test.check(bounded_and_stopped(s), "SupervisorWire exhausted and stopped interpreters require containment")
    Test.check(effects_render(), "SupervisorWire renders effects in order")
    IO.print("SupervisorWire: 8 checks passed")

def main() -> IO(Unit):
  wire_checks(JO.owner_stages())
