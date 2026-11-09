import Base
import /home/jadams/tmp/writ-linux-joint-owner/RendezvousTests.bend as RT
import /home/jadams/tmp/writ-linux-joint-owner/Rendezvous.bend as R

def main() -> Bool:
  R.Change.accepted(RT.sc_dispatch(RT.sc_world()))
