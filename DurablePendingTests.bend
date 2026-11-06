import Base
import ./DurablePending.bend as P
import ./DurableJournal.bend as J
import ./DurableJournalTests.bend as JT
import ./HostPrimitivesTests.bend as HT
import ./BackplaneTests.bend as BT
import ./FacadeTests.bend as FT
import ./Test.bend as Test

# Synthetic journal and host observations; no storage or release takes place.
def attempt(state: P.State, expected: Nat) -> P.Attempt:
  P.attempt(state, expected, HT.worker_id(), HT.clean_fact(), BT.candidate(), FT.context(), HT.frontend_revision())

def ready() -> P.State:
  P.TxnReady{JT.initial()}

def pending(result: P.Attempt) -> P.State:
  match result:
    case P.TxnStaged{state}:
      state
    case _:
      ready()

def is_staged(result: P.Attempt) -> Bool:
  match result:
    case P.TxnStaged{P.TxnPending{before, proposed}}:
      JT.journal_equal(before, JT.initial()) && JT.journal_equal(proposed, JT.advanced_state(JT.advance()))
    case _:
      False{}

def blocked_pending(result: P.Attempt) -> Bool:
  match result:
    case P.TxnBlocked{P.TxnPending{before, proposed}}:
      JT.journal_equal(before, JT.initial()) && JT.journal_equal(proposed, JT.advanced_state(JT.advance()))
    case _:
      False{}

def blocked_unknown(result: P.Attempt) -> Bool:
  match result:
    case P.TxnBlocked{P.TxnUnknown{before, proposed}}:
      JT.journal_equal(before, JT.initial()) && JT.journal_equal(proposed, JT.advanced_state(JT.advance()))
    case _:
      False{}

def is_unknown(state: P.State) -> Bool:
  match state:
    case P.TxnUnknown{before, proposed}:
      JT.journal_equal(before, JT.initial()) && JT.journal_equal(proposed, JT.advanced_state(JT.advance()))
    case _:
      False{}

def rejected_stale(result: P.Attempt) -> Bool:
  match result:
    case P.TxnRejected{P.TxnReady{before}, J.Stale{}}:
      JT.journal_equal(before, JT.initial())
    case _:
      False{}

def rejected_host(result: P.Attempt) -> Bool:
  match result:
    case P.TxnRejected{P.TxnReady{before}, J.Host{_}}:
      JT.journal_equal(before, JT.revoked_initial())
    case _:
      False{}

def blocked_state(result: P.Attempt) -> P.State:
  match result:
    case P.TxnBlocked{state}:
      state
    case _:
      ready()

def main() -> IO(Unit):
  do IO<Unit>:
    Test.check(is_staged(attempt(ready(), JT.start_revision())),
      "durable pending stages one prospective journal transition without replacing the original")
    Test.check(blocked_pending(attempt(pending(attempt(ready(), JT.start_revision())), JT.start_revision())),
      "durable pending blocks a second authorization before acknowledgement")
    Test.check(is_unknown(P.lost_ack(pending(attempt(ready(), JT.start_revision())))),
      "durable pending lost acknowledgement retains original and proposed states as unknown")
    Test.check(blocked_unknown(attempt(P.lost_ack(pending(attempt(ready(), JT.start_revision()))), JT.start_revision())),
      "durable pending blocks a new authorization after a lost acknowledgement")
    Test.check(blocked_unknown(attempt(blocked_state(attempt(P.lost_ack(pending(attempt(ready(), JT.start_revision()))),
      JT.start_revision())), 1n+JT.start_revision())),
      "durable pending remains blocked across retries with a changed expected revision")
    Test.check(is_unknown(P.lost_ack(P.lost_ack(pending(attempt(ready(), JT.start_revision()))))),
      "durable pending repeated lost acknowledgement cannot resolve the unknown outcome")
    Test.check(rejected_stale(attempt(ready(), 1n+JT.start_revision())),
      "durable pending stale authorization leaves the original journal ready")
    Test.check(rejected_host(attempt(P.TxnReady{JT.revoked_initial()}, JT.start_revision())),
      "durable pending host denial leaves the entire original journal ready")
