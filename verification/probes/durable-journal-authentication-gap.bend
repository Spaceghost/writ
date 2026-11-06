import Base
import ../../DurableJournal.bend as J
import ../../DurableJournalTests.bend as T
import ../../HostPrimitivesTests.bend as P
import ../../Ledger.bend as L
import ../../Negotiation.bend as N
import ../../NegotiationTests.bend as NT

# Synthetic counterexample to treating journal coherence as authentication.
# This is an observation, not a requirement that an altered record be accepted.
# It changes an in-memory journal receipt and adds that receipt to an in-memory
# ledger's seen IDs; it neither reads nor modifies native or protected storage.

def add_seen(ledger: L.State) -> L.State:
  match ledger:
    case L.State{rev, accounts, holds, seen, committed}:
      L.State{rev, accounts, holds, L.Id{9999n, seen}, committed}

def alter(state: J.State) -> J.State:
  match state:
    case J.State{rev, host, session, ledger, J.More{J.Entry{invocation, _, request, intent}, rest}}:
      J.State{rev, host, session, add_seen(ledger), J.More{J.Entry{invocation, 9999n, request, intent}, rest}}
    case _:
      state

def show(answer: J.Inspection) -> String:
  match answer:
    case J.Matches{}:
      "MATCHES: pure coherence did not authenticate the original receipt"
    case _:
      "REFUSED: the altered state did not match"

def observe(state: J.State) -> String:
  match state:
    case J.State{rev, host, session, ledger, J.More{J.Entry{inv, receipt, request, +intent}, rest}}:
      show(J.inspect(J.State{rev, host, session, ledger, J.More{J.Entry{inv, receipt, request, intent}, rest}},
        1n+T.start_revision(), P.invocation(), 9999n, N.Session.request(NT.running()), intent))
    case _:
      "NO ENTRY: probe fixture did not advance"

def main() -> IO(Unit):
  IO.print(observe(alter(T.advanced_state(T.advance()))))
