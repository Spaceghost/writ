import Base
import /home/jadams/tmp/writ-joint-box-experiment/hosts/linux/monitor/LinuxHost.bend as LH

def main() -> LH.JointAction:
  LH.joint_issue(LH.initial(), 1n, 4, 120n, 110n)
