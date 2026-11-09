import Base
import /home/jadams/tmp/writ-joint-box-experiment/hosts/linux/monitor/LinuxHost.bend as LH
import /home/jadams/tmp/writ-joint-box-experiment/HostPrimitives.bend as P

def main() -> Nat:
  P.revision(LH.portable(LH.JointAction.state(LH.joint_dispatch(LH.initial(), 1n, 0n))))
