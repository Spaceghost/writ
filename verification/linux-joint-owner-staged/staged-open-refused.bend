import Base
import /home/jadams/tmp/writ-joint-staged-mutant/hosts/linux/monitor/LinuxJointOwnerTests.bend as JT
import /home/jadams/tmp/writ-joint-staged-mutant/hosts/linux/monitor/LinuxHost.bend as LH
import /home/jadams/tmp/writ-joint-staged-mutant/RendezvousTests.bend as RT
import /home/jadams/tmp/writ-joint-staged-mutant/Test.bend as Test

def refused(action: LH.JointAction) -> Bool:
  match action:
    case LH.JointRefused{_}: True{}
    case _: False{}

def main() -> IO(Unit):
  do IO<Unit>:
    Test.check(refused(LH.joint_issue(JT.dispatch_ready(RT.sc_world()), 1n, 8, 120n, 110n)), "open-refusal deferred issue trap")
