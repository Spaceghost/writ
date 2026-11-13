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
# issued by principal 101) with the synthetic role map 1 -> 101, 2 -> 102 and
# the fixture admission authority. Nothing here is an authenticated issuer,
# an installed role map or a host clock epoch; it exists so the native driver
# can be exercised against a real owner. The protocol and every decision are
# `SupervisorWire` / `SupervisorOwner`'s.

def running() -> LH.State:
  JO.stage_running(JO.owner_stages())

def initial() -> SW.State:
  SW.provisioned(OT.owner_of(running()), OT.authority())

def dispatch(+state: SW.State, line: String) -> SW.Step:
  SW.dispatch(state, line)

def next(step: SW.Step) -> SW.State:
  SW.next(step)

def reply(step: SW.Step) -> String:
  SW.reply(step)

def main() -> String:
  reply(dispatch(initial(), "LINUXSUP1\tDRAIN\t0\t0\t0\t0\t-"))
