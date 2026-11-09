import Base
import /home/jadams/tmp/writ-linux-joint-owner/hosts/linux/monitor/LinuxHost.bend as LH
import /home/jadams/tmp/writ-linux-joint-owner/HostPrimitives.bend as P

def main() -> Nat:
  P.revision(LH.portable(LH.JointAction.state(LH.joint_dispatch(LH.initial(), 1n, 0n))))
