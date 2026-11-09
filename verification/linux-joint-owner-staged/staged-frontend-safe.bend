import Base
import /home/jadams/tmp/writ-joint-owner-staged/Test.bend as Test
import /home/jadams/tmp/writ-joint-owner-staged/hosts/linux/monitor/LinuxJointOwnerTests.bend as JT
import /home/jadams/tmp/writ-joint-owner-staged/hosts/linux/monitor/LinuxHost.bend as LH
import /home/jadams/tmp/writ-joint-owner-staged/RendezvousTests.bend as RT

def probe(limit: Maybe<&2, Nat>) -> Bool:
  match limit:
    case None{}: False{}
    case Some{maximum}: JT.action_contained(LH.joint_issue(JT.frontend_revision_set(JT.dispatch_ready(RT.sc_world()), maximum), 1n, 4, 120n, 110n))

def main() -> IO(Unit):
  do IO<Unit>:
    Test.check(probe(Nat.read("281474976710655")), "guarded frontend capacity")
