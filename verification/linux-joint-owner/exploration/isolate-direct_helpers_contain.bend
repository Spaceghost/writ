import Base
import /home/jadams/tmp/writ-linux-joint-owner/hosts/linux/monitor/LinuxJointOwnerTests.bend as JT
import /home/jadams/tmp/writ-linux-joint-owner/RendezvousTests.bend as RT

def main() -> Bool:
  JT.direct_helpers_contain(RT.sc_world())
