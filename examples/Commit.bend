import Base
import ../Core.bend as Core
import ../Dlm.bend as Dlm
import ../Transfer.bend as Transfer
import ../Negotiation.bend as Negotiation
import ../Ledger.bend as Ledger
import ../Frontend.bend as Frontend
import ../Backplane.bend as Backplane
import ../DataOS.bend as Writ
import ./Scenario.bend as Scenario
import ./Transfer.bend as TransferExample
import ./Expect.bend as Expect

# Each function below replays pure transitions over immutable synthetic state.
# Repeating a helper does not execute a transform or charge an external account.
# A real monitor must serialize and persist the returned state exactly once.
def pinned() -> Negotiation.Step:
  +session = Negotiation.open(Scenario.request())
  Negotiation.pin(session, Negotiation.Session.revision(session), Scenario.code(),
    Scenario.negotiation(Scenario.pin_time()))

def challenged() -> Negotiation.Step:
  +session = Negotiation.Step.session(pinned())
  Negotiation.challenge(session, Negotiation.Session.revision(session), Scenario.challenge_id(),
    Scenario.negotiation(Scenario.now()))

def sample_permitted() -> Bool:
  +session = Negotiation.Step.session(challenged())
  Negotiation.sample_permit(session, Negotiation.Session.revision(session),
    Scenario.negotiation(Scenario.now()))

def sampled() -> Negotiation.Step:
  +session = Negotiation.Step.session(challenged())
  Negotiation.sample(session, Negotiation.Session.revision(session), Scenario.sample_id(),
    Scenario.negotiation(Scenario.now()))

def owners_approved() -> Negotiation.Step:
  +session = Negotiation.Step.session(sampled())
  Negotiation.approve(session, Negotiation.Session.revision(session), Scenario.negotiation(Scenario.now()))

def reserved() -> Negotiation.ReservationStep:
  +session = Negotiation.Step.session(owners_approved())
  +ledger = Scenario.initial_ledger()
  Negotiation.reserve(session, Negotiation.Session.revision(session), Ledger.revision(ledger),
    Scenario.receipt_id(), Scenario.negotiation(Scenario.now()), ledger)

def held_ledger() -> Ledger.State:
  Negotiation.ReservationStep.ledger(reserved())

def started() -> Negotiation.Step:
  +reservation = reserved()
  +session = Negotiation.ReservationStep.session(reservation)
  Negotiation.start(session, Negotiation.Session.revision(session), Scenario.negotiation(Scenario.now()),
    Negotiation.ReservationStep.ledger(reservation))

def running() -> Negotiation.Session:
  Negotiation.Step.session(started())

# Mount/open are actual protocol transitions, not hand-built descriptor records.
# Execute requests need the library's read + write + execute rights mask.
def mounted() -> Frontend.Change:
  +state = Frontend.empty()
  Frontend.mount(state, Scenario.registry(), Frontend.revision(state), Scenario.caller(),
    Frontend.request_rights(Frontend.Execute{}), Scenario.live())

def open_mount(change: Frontend.Change) -> Frontend.Change:
  match change:
    case Frontend.Rejected{state}:
      Frontend.Rejected{state}
    case Frontend.Changed{+state, id}:
      Frontend.open(state, Scenario.registry(), Frontend.revision(state),
        Frontend.Ref{Scenario.caller(), id}, Frontend.request_rights(Frontend.Execute{}), Scenario.live())

def opened() -> Frontend.Change:
  open_mount(mounted())

# The final call re-resolves the CURRENT capability registry. The same mounted
# descriptor cannot authorize a commit after its grant has been removed.
def commit_opened(change: Frontend.Change, candidate: Core.Candidate,
  principals: Dlm.Snapshot, registry: Frontend.Registry) -> Backplane.CommitResult:
  match change:
    case Frontend.Rejected{_}:
      Backplane.Rejected{running(), held_ledger()}
    case Frontend.Changed{+frontend, id}:
      +session = running()
      +ledger = held_ledger()
      Writ.commit_from_capability(session, Negotiation.Session.revision(session), Ledger.revision(ledger),
        ledger, candidate, Frontend.Ref{Scenario.caller(), id}, Frontend.revision(frontend),
        Writ.Context{Scenario.backplane(principals), frontend, registry})

def authorized_commit(candidate: Core.Candidate, principals: Dlm.Snapshot) -> Backplane.CommitResult:
  commit_opened(opened(), candidate, principals, Scenario.registry())

def revoked_commit(candidate: Core.Candidate, principals: Dlm.Snapshot) -> Backplane.CommitResult:
  commit_opened(opened(), candidate, principals, Frontend.EmptyRegistry{})

def intent_retained(result: Backplane.CommitResult, principals: Dlm.Snapshot) -> Bool:
  match result:
    case Backplane.Rejected{_, _}:
      False{}
    case Backplane.Committed{_, _, Backplane.WriteIntent{plan, output, label, Backplane.Storage{}, artifact}}:
      Transfer.Plan.equal(plan, Scenario.plan()) && TransferExample.retained(output) &&
        Backplane.ArtifactId.equal(artifact, Scenario.artifact()) &&
        Dlm.flows(principals, U32.to_nat(Scenario.authority_epoch()), Scenario.internal_label(), label)
    case _:
      False{}

# Exact comparisons for this story's one-account, one-hold ledger. A revision
# match alone would miss altered balances, hold scope, or replay records.
def same_held_ledger(a: Ledger.State, b: Ledger.State) -> Bool:
  match a b:
    case Ledger.State{ar, Ledger.Accounts{Ledger.Account{ap, ab}, Ledger.NoAccounts{}},
      Ledger.Holds{Ledger.Hold{ah, ai, ay, au, ad}, Ledger.NoHolds{}},
      Ledger.Id{as, Ledger.NoIds{}}, Ledger.NoIds{}}
      Ledger.State{br, Ledger.Accounts{Ledger.Account{bp, bb}, Ledger.NoAccounts{}},
      Ledger.Holds{Ledger.Hold{bh, bi, by, bu, bd}, Ledger.NoHolds{}},
      Ledger.Id{bs, Ledger.NoIds{}}, Ledger.NoIds{}}:
      Nat.is_eq(ar, br) && Nat.is_eq(ap, bp) && Nat.is_eq(ab, bb) &&
        Nat.is_eq(ah, bh) && Nat.is_eq(ai, bi) && Nat.is_eq(ay, by) &&
        Nat.is_eq(au, bu) && Nat.is_eq(ad, bd) && Nat.is_eq(as, bs)
    case _ _:
      False{}

def same_running_session(a: Negotiation.Session, b: Negotiation.Session) -> Bool:
  match a b:
    case Negotiation.Session{ar, aq, Negotiation.Running{}, ap, ac, ah}
      Negotiation.Session{br, bq, Negotiation.Running{}, bp, bc, bh}:
      Nat.is_eq(ar, br) && Negotiation.Request.equal(aq, bq) &&
        Nat.is_eq(ap, bp) && Nat.is_eq(ac, bc) && Nat.is_eq(ah, bh)
    case _ _:
      False{}

def check_stages() -> IO(Unit):
  do IO<Unit>:
    Expect.boolean(Negotiation.Step.accepted(pinned()), True{}, "candidate identity pinned")
    Expect.boolean(Negotiation.Step.accepted(challenged()), True{}, "fresh challenge accepted after pin")
    Expect.boolean(sample_permitted(), True{}, "paired grants permit protected sampling")
    Expect.boolean(Negotiation.Step.accepted(sampled()), True{}, "registered sample accepted")
    Expect.boolean(Negotiation.Step.accepted(owners_approved()), True{}, "origin owner approved exact plan")
    Expect.boolean(Negotiation.ReservationStep.accepted(reserved()), True{}, "reader execution units reserved")
    Expect.boolean(Negotiation.Step.accepted(started()), True{}, "negotiation started")
    Expect.boolean(Frontend.accepted(mounted()), True{}, "capability mounted in protocol model")
    Expect.boolean(Frontend.accepted(opened()), True{}, "descriptor opened in protocol model")

def check_commit(+candidate: Core.Candidate, +principals: Dlm.Snapshot) -> IO(Unit):
  do IO<Unit>:
    Expect.boolean(Backplane.accepted(authorized_commit(candidate, principals)),
      True{}, "authorized commit accepted")
    Expect.boolean(intent_retained(authorized_commit(candidate, principals), principals),
      True{}, "write intent retains origin policy and artifact")
    Expect.boolean(Negotiation.Session.is(Backplane.session(authorized_commit(candidate, principals)),
      Negotiation.Committed{}), True{}, "session reached Committed")
    Expect.natural(Ledger.balance(Backplane.ledger(authorized_commit(candidate, principals)), Scenario.reader()),
      Nat.sub(Scenario.starting_units(), Scenario.execution_units()), "reader available units after one reservation")
    # This branch starts from the original RUNNING session and held ledger, not
    # the already committed state. Revocation, not replay, must cause rejection.
    Expect.boolean(Backplane.accepted(revoked_commit(candidate, principals)),
      False{}, "revoked capability committed")
    Expect.boolean(same_held_ledger(Backplane.ledger(revoked_commit(candidate, principals)), held_ledger()),
      True{}, "revoked attempt preserves exact held ledger")
    Expect.boolean(same_running_session(Backplane.session(revoked_commit(candidate, principals)), running()),
      True{}, "revoked attempt preserves exact running session")

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print("Commit: negotiate, mount a capability, and recheck authority at release.")
    check_stages()
    candidate : Core.Candidate <- Expect.solved(Core.solve_cpu(Scenario.graph(), 0n))
    principals : Dlm.Snapshot <- Expect.some(Dlm.Snapshot, Scenario.principals(), "principal snapshot")
    check_commit(candidate, principals)
