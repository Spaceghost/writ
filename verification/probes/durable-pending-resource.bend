import Base

# Synthetic review probe; this does not authenticate state or prove a general law.
import ../../DurablePending.bend as P
import ../../DurableJournal.bend as J
import ../../DurableJournalTests.bend as JT
import ../../HostPrimitivesTests.bend as HT
import ../../BackplaneTests.bend as BT
import ../../FacadeTests.bend as FT
import ../../Test.bend as Test

def oversized(state: J.State) -> J.State:
  match state:
    case J.State{revision, primitive, session, ledger, _}:
      J.State{revision, primitive, session, ledger, JT.oversized_entries()}

def blocked(result: P.Attempt) -> Bool:
  match result:
    case P.TxnBlocked{P.TxnUnknown{_, _}}:
      True{}
    case _:
      False{}

def main() -> IO(Unit):
  do IO<Unit>:
    Test.check(blocked(P.attempt(P.TxnUnknown{oversized(JT.initial()), oversized(JT.initial())}, JT.start_revision(), HT.worker_id(),
      HT.clean_fact(), BT.candidate(), FT.context(), HT.frontend_revision())), "unknown blocks oversized synthetic history")
