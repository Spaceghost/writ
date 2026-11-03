import Base
import ./Core.bend as Core
import ./Dlm.bend as Dlm
import ./Transfer.bend as Transfer
import ./Negotiation.bend as Negotiation
import ./Ledger.bend as Ledger
import ./Frontend.bend as Frontend
import ./Backplane.bend as Backplane

# Public facade for the Bend 2 library. Import the component modules when
# constructing their typed records. Context, state and authenticated Caller
# records belong to the monitor; external callers provide IDs and proposals.
type Context is Data:
  Context{backplane: Backplane.Context, frontend: Frontend.State, capabilities: Frontend.Registry}

def solve(graph: Core.Graph, rounds: Nat) -> Core.SolveResult:
  Core.solve_cpu(graph, rounds)

def verify(graph: Core.Graph, candidate: Core.Candidate, live: Core.Stamp) -> Core.Check:
  Core.verify(graph, candidate, live)

def admit(plan: Transfer.Plan, context: Transfer.Context) -> Transfer.Decision:
  Transfer.admit(plan, context)

def flows(snapshot: Dlm.Snapshot, epoch: Nat, source: Dlm.Label, destination: Dlm.Label) -> Bool:
  Dlm.flows(snapshot, epoch, source, destination)

def subject(ref: Frontend.Ref) -> Nat:
  match ref:
    case Frontend.Ref{Frontend.Caller{subject, _}, _}:
      subject

def commit_allowed(ok: Bool, +session: Negotiation.Session, expected_session: Nat,
  expected_ledger: Nat, +ledger: Ledger.State, candidate: Core.Candidate,
  context: Backplane.Context) -> Backplane.CommitResult:
  match ok:
    case False{}:
      Backplane.Rejected{session, ledger}
    case True{}:
      Backplane.commit(session, expected_session, expected_ledger, ledger, candidate, context)

def commit_resolved(resolved: Maybe<&2, Transfer.Plan>, +session: Negotiation.Session,
  expected_session: Nat, expected_ledger: Nat, ledger: Ledger.State, candidate: Core.Candidate,
  caller: Nat, context: Backplane.Context) -> Backplane.CommitResult:
  match resolved:
    case None{}:
      Backplane.Rejected{session, ledger}
    case Some{plan}:
      ok = Transfer.Plan.equal(plan, Negotiation.Session.plan(session)) &&
        Nat.is_eq(caller, Negotiation.Request.reader(Negotiation.Session.request(session)))
      commit_allowed(ok, session, expected_session, expected_ledger, ledger, candidate, context)

# POSIX/S3 adapters can share this final entry point. It re-resolves the live
# capability descriptor at commit, then invokes the entire Bend backplane.
# The returned WriteIntent is descriptive; only the serialized monitor may
# execute it together with persistence of the updated session and ledger.
def commit_from_capability(session: Negotiation.Session, expected_session: Nat,
  expected_ledger: Nat, ledger: Ledger.State, candidate: Core.Candidate,
  +ref: Frontend.Ref, expected_frontend: Nat, context: Context) -> Backplane.CommitResult:
  match context:
    case Context{+backplane, frontend, registry}:
      transfer = Negotiation.Context.transfer(Backplane.Context.negotiation(backplane))
      resolved = Frontend.checked_plan(frontend, registry, expected_frontend, ref,
        Frontend.Execute{}, transfer)
      commit_resolved(resolved, session, expected_session, expected_ledger, ledger,
        candidate, subject(ref), backplane)
