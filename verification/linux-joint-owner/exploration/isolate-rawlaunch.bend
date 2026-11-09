import Base
import /home/jadams/tmp/writ-linux-joint-owner/hosts/linux/monitor/LinuxHost.bend as LH
import /home/jadams/tmp/writ-linux-joint-owner/hosts/linux/monitor/LinuxJointOwnerTests.bend as JT
import /home/jadams/tmp/writ-linux-joint-owner/RendezvousTests.bend as RT
import /home/jadams/tmp/writ-linux-joint-owner/Issuance.bend as ISS
import /home/jadams/tmp/writ-linux-joint-owner/HostPrimitives.bend as P

def boot(+w: RT.Sc) -> LH.State:
  +issuer = {RT.sc_issuer(w) : ISS.State}
  JT.with_clock(LH.joint_initial(issuer, RT.sc_evidenced(w), RT.sc_policies(), RT.sc_running(w), RT.sc_raw(issuer, 110n)), 110n)

def main() -> Nat:
  P.revision(LH.portable(LH.Outcome.state(LH.launch_fact(boot(RT.sc_world()), JT.fact(), 110n))))
