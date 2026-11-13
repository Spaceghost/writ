import Base
import ./SupervisorWire.bend as SW
import ./SupervisorOwnerTests.bend as OT
import ./LinuxJointOwnerTests.bend as JO
import ./LinuxHost.bend as LH

# SYNTHETIC TEST PROVISIONING for the native supervisor driver test only
# (contrib/native-hosts/linux/supervisor-owner-test.c). Built with
# `bend hosts/linux/monitor/SupervisorDriverModule.bend -o <outside>/supervisor-driver.mjs`
# and run by runtime/supervisor-policy.mjs.
#
# `initial()` is the joint owner fixture's running stage (synthetic issuer,
# clock at 110, the delivered worker 1 grant expiring at 120, approval 5
# issued by principal 101) with NO role map and the fixture admission
# authority. The driver's first frame must be `PROVISION` with a protected
# record whose issuer root is that synthetic issuer's root; only then does the
# record's role map attribute channel messages (SupervisorProvision). The
# issuer itself is not installed by the record and is not authenticated; the
# clock is not a host epoch. The protocol and every decision are
# `SupervisorWire` / `SupervisorProvision` / `SupervisorOwner`'s.

def running() -> LH.State:
  JO.stage_running(JO.owner_stages())

def initial() -> SW.State:
  SW.unprovisioned(running(), OT.authority())

def dispatch(+state: SW.State, line: String) -> SW.Step:
  SW.dispatch(state, line)

def next(step: SW.Step) -> SW.State:
  SW.next(step)

def reply(step: SW.Step) -> String:
  SW.reply(step)

def main() -> String:
  reply(dispatch(initial(), "LINUXSUP1\tDRAIN\t0\t0\t0\t0\t-"))
