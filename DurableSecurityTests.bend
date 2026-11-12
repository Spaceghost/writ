import Base
import ./HostPrimitivesTests.bend as Host
import ./AuditTests.bend as Audit
import ./DurablePublicationTests.bend as Durable

# Focused native CPU regression entry point: the existing host publication
# and audit gates plus the durable protocol that composes them. All fixtures
# are synthetic; this is not native storage or confinement qualification.
def main() -> IO(Unit):
  do IO<Unit>:
    Host.main()
    Audit.main()
    Durable.main()
    IO.print("ALL DURABLE SECURITY TESTS PASSED")
