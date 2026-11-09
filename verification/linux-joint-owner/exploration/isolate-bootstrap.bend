import Base
import /home/jadams/tmp/writ-linux-joint-owner/hosts/linux/monitor/LinuxHost.bend as LH
import /home/jadams/tmp/writ-linux-joint-owner/hosts/linux/monitor/LinuxJointOwnerTests.bend as JT
import /home/jadams/tmp/writ-linux-joint-owner/RendezvousTests.bend as RT

def main() -> Bool:
  JT.boot_rejects_dispatched(RT.sc_world())
