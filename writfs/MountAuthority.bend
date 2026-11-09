import Base
import ../Core.bend as Core
import ../Dlm.bend as Dlm
import ../Transfer.bend as Transfer
import ../Negotiation.bend as Negotiation
import ../Ledger.bend as Ledger
import ../Frontend.bend as Frontend
import ../Backplane.bend as Backplane
import ../DataOS.bend as DataOS
import ../contrib/rclone/bend/Authority.bend as Reference

# Fixed local standing profile for public native-host canaries. The trusted
# supervisor, not a mounted client, assigns the single reader domain. These
# records do not authenticate a host, issue external grants or qualify its
# confinement. Retain the full commit result and the exact historical Frontend
# state and reference used by that commit, even if later native setup fails.
# The retained Frontend is not a current registry or authenticated issuer.
type Grant is Data:
  NoGrant{}
  Granted{commit: Backplane.CommitResult, frontend: Frontend.State, ref: Frontend.Ref}

def source() -> Transfer.ObjectVersion:
  Transfer.ObjectVersion{1n, 1n}

def destination() -> Transfer.ObjectVersion:
  Transfer.ObjectVersion{2n, 1n}

def plan() -> Transfer.Plan:
  Reference.plan(source(), destination(), 1)

def committed(result: Backplane.CommitResult) -> Bool:
  match result:
    case Backplane.Rejected{_, _}:
      False{}
    case Backplane.Committed{_, _, _}:
      True{}

def descriptor(change: Frontend.Change, +session: Negotiation.Session,
  +ledger: Ledger.State, candidate: Core.Candidate, context: Backplane.Context,
  registry: Frontend.Registry) -> Grant:
  match change:
    case Frontend.Rejected{_}:
      NoGrant{}
    case Frontend.Changed{+frontend, id}:
      +ref = {Frontend.Ref{Reference.caller(1), id} : Frontend.Ref}
      ({+result => Bool.pick(Unit -> Grant, committed(result),
        x => Granted{result, frontend, ref}, x => NoGrant{})(Unit{}) : Backplane.CommitResult -> Grant})(
          DataOS.commit_from_capability(session, Negotiation.Session.revision(session),
            Ledger.revision(ledger), ledger, candidate, ref,
            Frontend.revision(frontend), DataOS.Context{context, frontend, registry}))

def finish(solved: Core.SolveResult, principals: Maybe<&2, Dlm.Snapshot>,
  request: Negotiation.Request, graph: Core.Graph, +public: Bool,
  artifact: Backplane.ArtifactId, +context: Negotiation.Context,
  reservation: Negotiation.ReservationStep, +registry: Frontend.Registry,
  current: Frontend.Registry) -> Grant:
  match solved principals reservation:
    case Core.Solved{candidate, _} Some{principals}
      Negotiation.ReservationAdvanced{+reserved, +ledger}:
      session = Negotiation.Step.session(Negotiation.start(reserved,
        Negotiation.Session.revision(reserved), context, ledger))
      descriptor(Reference.open_descriptor(registry, 1), session, ledger, candidate,
        Backplane.Context{context, Reference.core_stamp(), principals,
          Backplane.Bindings{Backplane.Binding{request, graph, Reference.sink(public),
            Reference.label(), Reference.destination_label(public),
            Backplane.Storage{}, artifact}, Backplane.NoBindings{}}}, current)
    case _ _ _:
      NoGrant{}

def registry(revoked: Bool) -> Frontend.Registry:
  match revoked:
    case True{}:
      Frontend.EmptyRegistry{}
    case False{}:
      Reference.registry(plan(), 1)

def authorize(artifact: Backplane.ArtifactId, +public: Bool, revoked: Bool) -> Grant:
  +policy = Reference.imported_policy(source())
  +request = Reference.request(plan())
  +context = Reference.negotiation(plan(),
    Reference.transfer(source(), policy, destination(), public, 1, 3n), 1)
  pin_context = Reference.negotiation(plan(),
    Reference.transfer(source(), policy, destination(), public, 1, 1n), 1)
  +graph = Reference.graph(policy)
  finish(Core.solve_cpu(graph, 0n), Dlm.prepare(1n, 2, Dlm.NoEdges{}), request,
    graph, public, artifact, context, Reference.running(request, pin_context, context, 1),
    Reference.registry(plan(), 1), registry(revoked))

def allowed(grant: Grant) -> Bool:
  match grant:
    case NoGrant{}:
      False{}
    case Granted{Backplane.Committed{_, _, _}, _, _}:
      True{}
    case _:
      False{}

def artifact_matches(grant: Grant, artifact: Backplane.ArtifactId) -> Bool:
  match grant:
    case NoGrant{}:
      False{}
    case Granted{Backplane.Committed{_, _, intent}, _, _}:
      Backplane.ArtifactId.equal(Backplane.WriteIntent.artifact(intent), artifact)
    case _:
      False{}

def committed_revision(grant: Grant) -> Nat:
  match grant:
    case NoGrant{}:
      0n
    case Granted{Backplane.Committed{session, _, _}, _, _}:
      Negotiation.Session.revision(session)
    case _:
      0n

def ledger_revision(grant: Grant) -> Nat:
  match grant:
    case NoGrant{}:
      0n
    case Granted{Backplane.Committed{_, ledger, _}, _, _}:
      Ledger.revision(ledger)
    case _:
      0n
