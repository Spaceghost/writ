import Base
import ../../Core.bend as Core
import ../../Dlm.bend as Dlm
import ../../Transfer.bend as Transfer
import ../../Negotiation.bend as Negotiation
import ../../Ledger.bend as Ledger
import ../../Frontend.bend as Frontend
import ../../Backplane.bend as Backplane
import ../../DataOS.bend as DataOS
import ../../contrib/rclone/bend/Authority.bend as Reference
import ../Native.bend as Native

# SYNTHETIC AUTHORITY FOR PUBLIC TEST DATA. This example reuses the existing
# local reference profile to exercise the real capability/commit gate. It is
# neither a registry nor an issuer. Production monitors supply their own current
# Gate and registered logical/native mappings to Native.authorize.
# Logical IDs 1 and 2 are local fixture IDs, never truncated UUIDs or GUIDs.
def source_object() -> Transfer.ObjectVersion:
  Transfer.ObjectVersion{1n, 1n}

def destination_object() -> Transfer.ObjectVersion:
  Transfer.ObjectVersion{2n, 1n}

def policy(+code: Transfer.CodeId) -> Transfer.OutputPolicy:
  Transfer.OutputPolicy{Core.bytes_type(), Reference.secrecy(), Reference.untrusted(),
    Reference.copy_kind(),
    Transfer.RCons{Transfer.OriginRule{source_object(), Reference.secrecy(),
      Reference.untrusted(), Reference.copy_kind(),
      Transfer.CCons{code, Transfer.CEnd{}}, Transfer.Free{}}, Transfer.REnd{}}}

def plan(code: Transfer.CodeId) -> Transfer.Plan:
  Transfer.Plan{Reference.stamp(), 2n,
    Transfer.OCons{source_object(), Transfer.OEnd{}}, destination_object(), code,
    Transfer.Copy{}, Core.bytes_type()}

def transfer(+code: Transfer.CodeId, public: Bool, time: Nat) -> Transfer.Context:
  +scope : Transfer.GrantScope = Transfer.GrantScope{2n, Transfer.OCons{source_object(), Transfer.OEnd{}},
    destination_object(), Transfer.WriteDomain{2n}, code, Transfer.Copy{},
    Reference.stamp(), 4n}
  Transfer.Context{Reference.stamp(), time,
    Transfer.SCons{Transfer.OutputPolicy.as_source(policy(code), source_object(),
      Transfer.ReadDomain{1n}, 1n), Transfer.SEnd{}},
    Transfer.DestinationPolicy{destination_object(), Transfer.WriteDomain{2n}, 1n,
      Core.bytes_type(), Reference.clearance(public), Reference.untrusted(), Reference.copy_kind()},
    Transfer.ApprovedOperation{code, Transfer.Copy{}, 1n,
      Transfer.TCons{Core.bytes_type(), Transfer.TEnd{}}, Core.bytes_type()},
    Transfer.ReadCons{Transfer.ReadGrant{source_object(), Transfer.ReadDomain{1n}, scope},
      Transfer.ReadEnd{}},
    Transfer.WriteCons{Transfer.WriteGrant{destination_object(), Transfer.WriteDomain{2n}, scope},
      Transfer.WriteEnd{}}, Transfer.PayEnd{}}

def destination(+observed: Native.Observation, staging: String, name: String) -> Native.Destination:
  Native.Observation{provider, identity, _, _, _, _, _, _, _, _, _} = observed
  Native.Destination{provider, Native.identity_container(identity), staging ++ "/" ++ name,
    destination_object()}

def spec(+observed: Native.Observation, destination: Native.Destination) -> Maybe<&2, Native.Spec>:
  Native.Observation{provider, _, _, _, _, _, _, _, _, _, _} = observed
  do Maybe<&2, Native.Spec>:
    +source : Native.Source = Native.Source{source_object(), observed}
    artifact : Backplane.ArtifactId <- Native.seal(source)
    return Native.Spec{source, destination, plan(Native.operation_code(provider)), artifact}

def running(+request: Negotiation.Request, code: Transfer.CodeId,
  pin_context: Negotiation.Context, +context: Negotiation.Context) -> Negotiation.ReservationStep:
  +opened = Negotiation.open(request)
  +pinned = Negotiation.Step.session(Negotiation.pin(opened,
    Negotiation.Session.revision(opened), code, pin_context))
  +challenged = Negotiation.Step.session(Negotiation.challenge(pinned,
    Negotiation.Session.revision(pinned), 1n, context))
  +sampled = Negotiation.Step.session(Negotiation.sample(challenged,
    Negotiation.Session.revision(challenged), 1n, context))
  +approved = Negotiation.Step.session(Negotiation.approve(sampled,
    Negotiation.Session.revision(sampled), context))
  +ledger = Ledger.empty(Ledger.Accounts{Ledger.Account{Reference.principal(), 0n}, Ledger.NoAccounts{}})
  Negotiation.reserve(approved, Negotiation.Session.revision(approved),
    Ledger.revision(ledger), 2n, context, ledger)

def current_registry(registry: Frontend.Registry, revoked: Bool) -> Frontend.Registry:
  match revoked:
    case True{}:
      Frontend.EmptyRegistry{}
    case False{}:
      registry

def descriptor(change: Frontend.Change, +session: Negotiation.Session,
  +ledger: Ledger.State, candidate: Core.Candidate, context: Backplane.Context,
  registry: Frontend.Registry, revoked: Bool) -> Maybe<&2, Native.Gate>:
  match change:
    case Frontend.Rejected{_}:
      None{}
    case Frontend.Changed{+frontend, id}:
      Some{Native.Gate{session, Negotiation.Session.revision(session), ledger,
        Ledger.revision(ledger), candidate, Frontend.Ref{Reference.caller(2), id},
        Frontend.revision(frontend),
        DataOS.Context{context, frontend, current_registry(registry, revoked)}}}

def finish(solved: Core.SolveResult, principals: Maybe<&2, Dlm.Snapshot>,
  request: Negotiation.Request, graph: Core.Graph, +public: Bool,
  artifact: Backplane.ArtifactId, +context: Negotiation.Context,
  reservation: Negotiation.ReservationStep, +registry: Frontend.Registry,
  revoked: Bool) -> Maybe<&2, Native.Gate>:
  match solved principals reservation:
    case Core.Solved{candidate, _} Some{principals}
      Negotiation.ReservationAdvanced{+reserved, +ledger}:
      session = Negotiation.Step.session(Negotiation.start(reserved,
        Negotiation.Session.revision(reserved), context, ledger))
      descriptor(Reference.open_descriptor(registry, 2), session, ledger, candidate,
        Backplane.Context{context, Reference.core_stamp(), principals,
          Backplane.Bindings{Backplane.Binding{request, graph, Reference.sink(public),
            Reference.label(), Reference.destination_label(public),
            Backplane.Storage{}, artifact}, Backplane.NoBindings{}}}, registry, revoked)
    case _ _ _:
      None{}

def gate(spec: Native.Spec, +public: Bool, revoked: Bool) -> Maybe<&2, Native.Gate>:
  Native.Spec{_, _, +plan, artifact} = spec
  Transfer.Plan{_, _, _, _, +code, _, _} = plan
  +request = Reference.request(plan)
  +context = Reference.negotiation(plan,
    transfer(code, public, 3n), 2)
  pin_context = Reference.negotiation(plan,
    transfer(code, public, 1n), 2)
  +graph = Reference.graph(policy(code))
  finish(Core.solve_cpu(graph, 0n), Dlm.prepare(1n, 2, Dlm.NoEdges{}), request, graph,
    public, artifact, context, running(request, code, pin_context, context),
    Reference.registry(plan, 2), revoked)

def authorize(+spec: Native.Spec, public: Bool, revoked: Bool) -> Maybe<&2, Native.Authorized>:
  do Maybe<&2, Native.Authorized>:
    gate : Native.Gate <- gate(spec, public, revoked)
    Native.authorize(spec, gate)
