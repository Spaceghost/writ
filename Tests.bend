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
import ./FrontendLegacyConversionTests.bend as FrontendLegacyConversion
import ./FrontendCleanupReserveTests.bend as FrontendCleanupReserve
import ./FrontendReserveWordsTests.bend as FrontendReserveWords
import ./HostBindingSnapshotTests.bend as HostBindingSnapshot
import ./HostBindingTests.bend as HostBinding
import ./HostWireTests.bend as HostWire
import ./PosixMountFrameTests.bend as PosixMountFrame
import ./PlannerEnvelopeTests.bend as PlannerEnvelope
import ./PlannerPlanMatchTests.bend as PlannerPlanMatch
import ./PlannerFrontendCompositionTests.bend as PlannerFrontendComposition
import ./LocalityConjunctionTests.bend as LocalityConjunction
import ./StageGraphTests.bend as StageGraph
import ./StagePortsTests.bend as StagePorts
import ./HostIdentityTests.bend as HostIdentity
import ./HostIdentityAncestryTests.bend as HostIdentityAncestry
import ./HostPrimitivesTests.bend as HostPrimitives
import ./HostIssueCurrentTests.bend as HostIssueCurrent
import ./HostIssueResultTests.bend as HostIssueResult
import ./HostAdmissionCurrentTests.bend as HostAdmissionCurrent
import ./HostHandoffTests.bend as HostHandoff
import ./HostConformanceTests.bend as HostConformance
import ./hosts/linux/monitor/LinuxHostTests.bend as LinuxHost
import ./hosts/linux/monitor/LinuxSessionOpenTests.bend as LinuxSessionOpen
import ./hosts/linux/monitor/LinuxCredentialBindingTests.bend as LinuxCredentialBinding
import ./hosts/linux/monitor/LinuxClockTests.bend as LinuxClock
import ./FacadeTests.bend as Facade
import ./LocalSupervisorTests.bend as LocalSupervisor
import ./IssuanceTests.bend as Issuance
import ./IssuanceBoundaryTests.bend as IssuanceBoundary
import ./AuditTests.bend as Audit
import ./RendezvousTests.bend as Rendezvous
import ./RendezvousBoundaryTests.bend as RendezvousBoundary
import ./PropertyTests.bend as Properties

def linux_tests() -> IO(Unit):
  do IO<Unit>:
    LinuxHost.main()
    LinuxSessionOpen.main()
    LinuxCredentialBinding.main()
    LinuxClock.main()

# Keep host corpus ordering while bounding generated continuation arity.
def host_tests() -> IO(Unit):
  do IO<Unit>:
    HostIdentity.main()
    HostIdentityAncestry.main()
    HostPrimitives.main()
    HostIssueCurrent.main()
    HostIssueResult.main()
    HostHandoff.main()
    HostConformance.main()
    HostAdmissionCurrent.main()

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
    FrontendLegacyConversion.main()
    FrontendCleanupReserve.main()
    FrontendReserveWords.main()
    HostBindingSnapshot.main()
    HostBinding.main()
    HostWire.main()
    PosixMountFrame.main()
    PlannerEnvelope.main()
    PlannerPlanMatch.main()
    PlannerFrontendComposition.main()
    LocalityConjunction.main()
    StageGraph.main()
    StagePorts.main()
    host_tests()
    linux_tests()
    Facade.main()
    LocalSupervisor.main()
    Issuance.main()
    IssuanceBoundary.main()
    Audit.main()
    Rendezvous.main()
    RendezvousBoundary.main()
    Properties.main()
    IO.print("ALL LIBRARY TESTS PASSED")
