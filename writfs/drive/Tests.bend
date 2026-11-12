import Base
import ./AuthorityTests.bend as Authority
import ./ModelTests.bend as Model
import ../DirectorySyncTests.bend as Directory
import ../../lib/Sha256StreamTests.bend as Stream

def main() -> IO(Unit):
  do IO<Unit>:
    Authority.main()
    Model.main()
    Directory.main()
    Stream.main()
    IO.print("ALL DRIVE AND STORAGE TESTS PASSED")
