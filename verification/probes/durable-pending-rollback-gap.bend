import Base
import ../../DurablePending.bend as P
import ../../DurablePendingTests.bend as PT
import ../../DurableJournal.bend as J
import ../../DurableJournalTests.bend as JT
import ../../Test.bend as Test

# Synthetic counterexample: a fabricated pre-transaction snapshot can recreate
# TxnReady after a lost acknowledgement and produce the same candidate again.
# It performs no storage, publication, spend, crash, or recovery. TxnStaged is
# merely a proposed state, not evidence that either transaction committed.
# This observes a missing host guarantee; it is not a security law requiring
# stale snapshots to be accepted. All records and native observations are test
# fixtures; constructors do not authenticate them.

def blocked(result: P.Attempt) -> Bool:
  match result:
    case P.TxnBlocked{P.TxnUnknown{_, _}}:
      True{}
    case _:
      False{}

def same_candidate(result: P.Attempt, before: J.State, proposed: J.State) -> Bool:
  match result:
    case P.TxnStaged{P.TxnPending{again_before, again_proposed}}:
      JT.journal_equal(before, again_before) && JT.journal_equal(proposed, again_proposed)
    case _:
      False{}

def current_refuses(result: P.Attempt, expected: J.State) -> Bool:
  match result:
    case P.TxnRejected{P.TxnReady{state}, J.Replay{}}:
      JT.journal_equal(state, expected)
    case _:
      False{}

def examine(state: P.State) -> Bool:
  match state:
    case P.TxnUnknown{+before, +proposed}:
      blocked(PT.attempt(P.TxnUnknown{before, proposed}, JT.start_revision()))
        && same_candidate(PT.attempt(P.TxnReady{before}, JT.start_revision()), before, proposed)
        && current_refuses(PT.attempt(P.TxnReady{proposed}, 1n+JT.start_revision()), proposed)
    case _:
      False{}

def observe(result: P.Attempt) -> Bool:
  match result:
    case P.TxnStaged{state}:
      examine(P.lost_ack(state))
    case _:
      False{}

def main() -> IO(Unit):
  Test.check(observe(PT.attempt(PT.ready(), JT.start_revision())),
    "synthetic lost-ack rollback can restage a candidate from a fabricated stale snapshot")
