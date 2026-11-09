import Base
import /home/jadams/tmp/writ-linux-joint-owner/hosts/linux/monitor/LinuxHost.bend as LH
import /home/jadams/tmp/writ-linux-joint-owner/hosts/linux/monitor/LinuxJointOwnerTests.bend as JT
import /home/jadams/tmp/writ-linux-joint-owner/RendezvousTests.bend as RT
import /home/jadams/tmp/writ-linux-joint-owner/HostPrimitives.bend as P

def main() -> Nat:
  P.revision(LH.portable(JT.launched(RT.sc_world())))
