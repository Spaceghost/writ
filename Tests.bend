import Base
import ./CoreTests.bend as Core
import ./TransferTests.bend as Transfer
import ./DlmTests.bend as Dlm
import ./LedgerTests.bend as Ledger
import ./NegotiationTests.bend as Negotiation
import ./BackplaneTests.bend as Backplane
import ./FrontendTests.bend as Frontend
import ./FacadeTests.bend as Facade
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
    Facade.main()
    Properties.main()
    IO.print("ALL LIBRARY TESTS PASSED")
