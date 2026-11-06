import Base
import ./DurableJournal.bend as J
import ./HostPublication.bend as H
import ./Core.bend as C
import ./DataOS.bend as OS

# Experimental monitor-local staging model for an unacknowledged transaction.
# `attempt` runs the existing journal gate once from TxnReady; TxnPending and TxnUnknown
# block further attempts. `lost_ack` records uncertainty without choosing a
# committed outcome. The proposed state is not durable, current, an effect,
# or a permit. There is intentionally no transition out of TxnUnknown: a negative
# lookup is not enough while an earlier write can still commit, and authenticated
# lookup, a fencing protocol, a current rollback witness, and restart persistence
# are not implemented. This model does not establish any of those properties.
#
# The monitor must own and serialize the complete state; public constructors,
# results, and caller-provided values authenticate nothing. Recreating TxnReady from
# an old snapshot bypasses this simulation. Its private diagnostic states may
# disclose protected policy and transaction information; they are not a public
# status API. Public entry points: `attempt` and `lost_ack`; `stage_from` is an
# implementation helper. None returns or performs a publication effect.

type State is Data:
  TxnReady{journal: J.State}
  TxnPending{before: J.State, proposed: J.State}
  TxnUnknown{before: J.State, proposed: J.State}

type Attempt is Data:
  TxnStaged{state: State}
  TxnBlocked{state: State}
  TxnRejected{state: State, reason: J.Error}

def stage_from(before: J.State, result: J.Transition) -> Attempt:
  match result:
    case J.Advanced{proposed}:
      TxnStaged{TxnPending{before, proposed}}
    case J.Denied{_, reason}:
      TxnRejected{TxnReady{before}, reason}

# A staged value describes a prospective atomic update, not a storage outcome.
def attempt(+state: State, expected_revision: Nat, worker: Nat, fact: H.ArtifactFact,
    candidate: C.Candidate, context: OS.Context, frontend_revision: Nat) -> Attempt:
  match state:
    case TxnReady{+journal}:
      stage_from(journal, J.authorize(journal, expected_revision, worker, fact, candidate, context, frontend_revision))
    case _:
      TxnBlocked{state}

# Loss says only that the outcome is unknown. Repeated loss stays unknown.
def lost_ack(state: State) -> State:
  match state:
    case TxnPending{before, proposed}:
      TxnUnknown{before, proposed}
    case _:
      state
