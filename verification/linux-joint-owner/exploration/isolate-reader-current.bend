import Base
import /home/jadams/tmp/writ-linux-joint-owner/hosts/linux/monitor/LinuxJointAuthority.bend as JA
import /home/jadams/tmp/writ-linux-joint-owner/RendezvousTests.bend as RT
import /home/jadams/tmp/writ-linux-joint-owner/Issuance.bend as ISS
import /home/jadams/tmp/writ-linux-joint-owner/Rendezvous.bend as R

def run(+w: RT.Sc) -> Bool:
  +issuer = {RT.sc_issuer(w) : ISS.State}
  +rendezvous = {RT.sc_evidenced(w) : R.State}
  JA.reader_current(issuer, rendezvous, RT.sc_running(w), RT.sc_raw(issuer, 110n),
    JA.joint_snapshot(issuer, rendezvous, RT.sc_policies(), 110n), 110n)

def main() -> Bool:
  run(RT.sc_world())
