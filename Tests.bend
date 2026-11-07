import Base
import ./CoreTests.bend as Core
import ./TransferTests.bend as Transfer
import ./DlmTests.bend as Dlm
import ./LedgerTests.bend as Ledger
import ./LedgerBoundaryTests.bend as LedgerBoundary
import ./NegotiationTests.bend as Negotiation
import ./BackplaneTests.bend as Backplane
import ./FrontendTests.bend as Frontend
import ./FrontendBoundaryTests.bend as FrontendBoundary
import ./FrontendRevisionV2Tests.bend as FrontendRevisionV2
import ./HostBindingTests.bend as HostBinding
import ./HostWireTests.bend as HostWire
import ./PlannerEnvelopeTests.bend as PlannerEnvelope
import ./PlannerPlanMatchTests.bend as PlannerPlanMatch
import ./PlannerFrontendCompositionTests.bend as PlannerFrontendComposition
import ./LocalityConjunctionTests.bend as LocalityConjunction
import ./StageGraphTests.bend as StageGraph
import ./HostIdentityTests.bend as HostIdentity
import ./HostPrimitivesTests.bend as HostPrimitives
import ./HostHandoffTests.bend as HostHandoff
import ./HostConformanceTests.bend as HostConformance
import ./hosts/linux/monitor/LinuxHostTests.bend as LinuxHost
import ./FacadeTests.bend as Facade
import ./IssuanceTests.bend as Issuance
import ./IssuanceBoundaryTests.bend as IssuanceBoundary
import ./AuditTests.bend as Audit
import ./RendezvousTests.bend as Rendezvous
import ./RendezvousBoundaryTests.bend as RendezvousBoundary
import ./PropertyTests.bend as Properties

def main() -> IO(Unit):
  do IO<Unit>:
    Core.main()
    Transfer.main()
    Dlm.main()
    Ledger.main()
    LedgerBoundary.main()
    Negotiation.main()
    Backplane.main()
    Frontend.main()
    FrontendBoundary.main()
    FrontendRevisionV2.main()
    HostBinding.main()
    HostWire.main()
    PlannerEnvelope.main()
    PlannerPlanMatch.main()
    PlannerFrontendComposition.main()
    LocalityConjunction.main()
    StageGraph.main()
    HostIdentity.main()
    HostPrimitives.main()
    HostHandoff.main()
    HostConformance.main()
    LinuxHost.main()
    Facade.main()
    Issuance.main()
    IssuanceBoundary.main()
    Audit.main()
    Rendezvous.main()
    RendezvousBoundary.main()
    Properties.main()
    IO.print("ALL LIBRARY TESTS PASSED")
