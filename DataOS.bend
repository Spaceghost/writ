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
# These public Data constructors describe state; constructing one does not
# authenticate a caller, issue a capability, or create an authority boundary.
type Context is Data:
  Context{backplane: Backplane.Context, frontend: Frontend.State, capabilities: Frontend.Registry}

# CPU reference solver. Its candidate is evidence for verify(), not permission
# to publish data. The monitor retains the original graph for verification.
def solve(graph: Core.Graph, rounds: Nat) -> Core.SolveResult:
  Core.solve_cpu(graph, rounds)

# Check the proposed assignment against every original graph constraint and
# the live stamp. Sink policy and effect rights still require the final gate.
def verify(graph: Core.Graph, candidate: Core.Candidate, live: Core.Stamp) -> Core.Check:
  Core.verify(graph, candidate, live)

# Read authority and write authority are separate, but admission requires both
# for this exact plan. A returned ticket is not a durable grant or a write.
def admit(plan: Transfer.Plan, context: Transfer.Context) -> Transfer.Decision:
  Transfer.admit(plan, context)

# Evaluate confidentiality and integrity flow in the supplied principal world.
# True does not replace capability, owner-approval, or payment checks.
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
# expected_frontend, expected_session and expected_ledger name three independent
# current revisions; matching integers alone do not serialize a concurrent host.
# Execute requires read, write and execute rights. The resolved plan must equal
# the negotiated plan, and the authenticated descriptor owner must be its reader.
# Host-facing release routes use this facade, not its unchecked helper functions.
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
