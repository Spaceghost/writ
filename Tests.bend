import Base
import ./CoreTests.bend as Core
import ./TransferTests.bend as Transfer
import ./DlmTests.bend as Dlm
import ./LedgerTests.bend as Ledger
import ./NegotiationTests.bend as Negotiation
import ./BackplaneTests.bend as Backplane
import ./FrontendTests.bend as Frontend
import ./HostBindingTests.bend as HostBinding
import ./HostWireTests.bend as HostWire
import ./PlannerEnvelopeTests.bend as PlannerEnvelope
import ./PlannerPlanMatchTests.bend as PlannerPlanMatch
import ./PlannerFrontendCompositionTests.bend as PlannerFrontendComposition
import ./HostIdentityTests.bend as HostIdentity
import ./HostPrimitivesTests.bend as HostPrimitives
import ./HostHandoffTests.bend as HostHandoff
import ./HostConformanceTests.bend as HostConformance
import ./hosts/linux/monitor/LinuxHostTests.bend as LinuxHost
import ./FacadeTests.bend as Facade
import ./IssuanceTests.bend as Issuance
import ./AuditTests.bend as Audit
import ./RendezvousTests.bend as Rendezvous
import ./PropertyTests.bend as Properties

def main() -> IO(Unit):
  do IO<Unit>:
    Core.main()
    Transfer.main()
    Dlm.main()
    Ledger.main()
    Negotiation.main()
    Backplane.main()
    Frontend.main()
    HostBinding.main()
    HostWire.main()
    PlannerEnvelope.main()
    PlannerPlanMatch.main()
    PlannerFrontendComposition.main()
    HostIdentity.main()
    HostPrimitives.main()
    HostHandoff.main()
    HostConformance.main()
    LinuxHost.main()
    Facade.main()
    Issuance.main()
    Audit.main()
    Rendezvous.main()
    Properties.main()
    IO.print("ALL LIBRARY TESTS PASSED")
