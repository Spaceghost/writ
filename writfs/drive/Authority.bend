import Base
import ../../Core.bend as C
import ../../Dlm.bend as D
import ../../Transfer.bend as T
import ../../Negotiation.bend as N
import ../../Ledger.bend as L
import ../../Frontend.bend as F
import ../../Backplane.bend as B
import ../../DataOS.bend as OS
import ../../contrib/rclone/bend/Authority.bend as R

# Standing authority for the authenticated local workspace owner. This is a
# managed-copy profile, not an external owner issuer or desktop confinement.
# The native broker supplies its current catalog, sealed snapshot and enabled
# connections. UI requests name objects; they never supply these contexts.
type Verdict is Data:
  Refused{reason: String}
  Allowed{intent: B.WriteIntent}

def bits(value: U32) -> T.Bits64:
  T.Bits64{value, 0}

def secrecy(policy: T.OutputPolicy) -> U32:
  T.OutputPolicy{_, T.Bits64{lo, _}, _, _, _} = policy
  lo

def label(public: Bool) -> D.Label:
  R.destination_label(public)

def imported(+object: T.ObjectVersion, +restrictions: U32) -> T.OutputPolicy:
  T.OutputPolicy{C.bytes_type(), bits(restrictions), R.untrusted(), R.copy_kind(),
    T.RCons{T.OriginRule{object, bits(restrictions), R.untrusted(), R.copy_kind(),
      T.CCons{R.copy_code(), T.CEnd{}}, T.Free{}}, T.REnd{}}}

# Tightening never discards any inherited rule. The added restriction is also
# bound to an origin record, so a later copy cannot erase it by changing names.
def tighten(policy: T.OutputPolicy, object: T.ObjectVersion, +restrictions: U32) -> T.OutputPolicy:
  match policy:
    case T.OutputPolicy{schema, +old, untrusted, kinds, origins}:
      T.OutputPolicy{schema, T.Bits64.join(old, bits(restrictions)), untrusted, kinds,
        T.RCons{T.OriginRule{object, bits(restrictions), R.untrusted(), R.copy_kind(),
          T.CCons{R.copy_code(), T.CEnd{}}, T.Free{}}, origins}}

def append_origins(left: T.Origins, right: T.Origins) -> T.Origins:
  match left:
    case T.REnd{}: right
    case T.RCons{origin, rest}: T.RCons{origin, append_origins(rest, right)}

# A restoration combines the historical source and the current destination.
# Neither record can waive the other's restrictions or provenance.
def combine(left: T.OutputPolicy, right: T.OutputPolicy) -> T.OutputPolicy:
  T.OutputPolicy{schema, secrecy, untrusted, kinds, origins} = left
  T.OutputPolicy{_, other_secrecy, other_untrusted, other_kinds, other_origins} = right
  T.OutputPolicy{schema, T.Bits64.join(secrecy, other_secrecy),
    T.Bits64.join(untrusted, other_untrusted), U32.and(kinds, other_kinds),
    append_origins(origins, other_origins)}

def transfer(+source: T.ObjectVersion, policy: T.OutputPolicy,
    +destination: T.ObjectVersion, clearance: U32, +invocation: U32, time: Nat) -> T.Context:
  +scope = R.scope(source, destination, invocation)
  T.Context{R.stamp(), time,
    T.SCons{T.OutputPolicy.as_source(policy, source, T.ReadDomain{1n}, 1n), T.SEnd{}},
    T.DestinationPolicy{destination, T.WriteDomain{2n}, 1n, C.bytes_type(),
      bits(clearance), R.untrusted(), R.copy_kind()},
    T.ApprovedOperation{R.copy_code(), T.Copy{}, 1n,
      T.TCons{C.bytes_type(), T.TEnd{}}, C.bytes_type()},
    T.ReadCons{T.ReadGrant{source, T.ReadDomain{1n}, scope}, T.ReadEnd{}},
    T.WriteCons{T.WriteGrant{destination, T.WriteDomain{2n}, scope}, T.WriteEnd{}}, T.PayEnd{}}

def sink(clearance: U32) -> C.Sink:
  C.Sink{1, C.Bits64{clearance, 0}, R.core_bits(R.untrusted()),
    C.Bits64.join(C.read_effect(), C.write_effect()), C.write_effect()}

def committed(result: B.CommitResult) -> Verdict:
  match result:
    case B.Rejected{_, _}: Refused{"AUTHORITY_CHANGED"}
    case B.Committed{_, _, intent}: Allowed{intent}

def descriptor(change: F.Change, +session: N.Session, +ledger: L.State,
    candidate: C.Candidate, context: B.Context, registry: F.Registry,
    invocation: U32) -> Verdict:
  match change:
    case F.Rejected{_}: Refused{"AUTHORITY_CHANGED"}
    case F.Changed{+frontend, id}:
      committed(OS.commit_from_capability(session, N.Session.revision(session),
        L.revision(ledger), ledger, candidate, F.Ref{R.caller(invocation), id},
        F.revision(frontend), OS.Context{context, frontend, registry}))

def finish(solved: C.SolveResult, principals: Maybe<&2, D.Snapshot>,
    +request: N.Request, graph: C.Graph, source_label: D.Label,
    +clearance: U32, artifact: B.ArtifactId, +context: N.Context,
    reservation: N.ReservationStep, +registry: F.Registry,
    +invocation: U32, current: F.Registry) -> Verdict:
  match solved principals reservation:
    case C.Solved{candidate, _} Some{principals} N.ReservationAdvanced{+reserved, +ledger}:
      +session = N.Step.session(N.start(reserved, N.Session.revision(reserved), context, ledger))
      descriptor(R.open_descriptor(registry, invocation), session, ledger, candidate,
        B.Context{context, R.core_stamp(), principals,
          B.Bindings{B.Binding{request, graph, sink(clearance), source_label,
            label(U32.is_eq(clearance, 0)), B.Storage{}, artifact}, B.NoBindings{}}},
        current, invocation)
    case _ _ _: Refused{"AUTHORITY_CHANGED"}

def current_registry(active: Bool, plan: T.Plan, invocation: U32) -> F.Registry:
  match active:
    case True{}: R.registry(plan, invocation)
    case False{}: F.EmptyRegistry{}

def reason(denial: T.Denial) -> String:
  match denial:
    case T.Destination{}: "DESTINATION_POLICY"
    case T.Origin{}: "ORIGIN_RESTRICTION"
    case T.Stale{}: "AUTHORITY_CHANGED"
    case T.Read{}: "READ_NOT_ALLOWED"
    case T.Write{}: "WRITE_NOT_ALLOWED"
    case T.Payment{}: "PAYMENT_REQUIRED"
    case _: "INVALID_AUTHORITY"

def admitted(decision: T.Decision, +source: T.ObjectVersion, +policy: T.OutputPolicy,
    +destination: T.ObjectVersion, +clearance: U32, +invocation: U32,
    artifact: B.ArtifactId, active: Bool) -> Verdict:
  match decision:
    case T.Denied{denial}: Refused{reason(denial)}
    case T.Admitted{_}:
      +plan = R.plan(source, destination, invocation)
      +request = R.request(plan)
      +context = R.negotiation(plan, transfer(source, policy, destination, clearance, invocation, 3n), invocation)
      pin_context = R.negotiation(plan, transfer(source, policy, destination, clearance, invocation, 1n), invocation)
      +graph = R.graph(policy)
      finish(C.solve_cpu(graph, 0n), D.prepare(1n, 2, D.NoEdges{}), request, graph,
        label(U32.is_eq(secrecy(policy), 0)), clearance, artifact, context,
        R.running(request, pin_context, context, invocation), R.registry(plan, invocation),
        invocation, current_registry(active, plan, invocation))

# Admission can provide a closed library reason. The final commit independently
# rechecks the live registry; rejection there is reported without re-running it
# to invent a more specific reason.
def authorize(+source: T.ObjectVersion, +policy: T.OutputPolicy,
    +destination: T.ObjectVersion, +clearance: U32, +invocation: U32,
    artifact: B.ArtifactId, active: Bool) -> Verdict:
  admitted(T.admit(R.plan(source, destination, invocation),
    transfer(source, policy, destination, clearance, invocation, 3n)),
    source, policy, destination, clearance, invocation, artifact, active)

def allowed(verdict: Verdict) -> Bool:
  match verdict:
    case Allowed{_}: True{}
    case _: False{}

def output(verdict: Verdict) -> Maybe<&2, T.OutputPolicy>:
  match verdict:
    case Allowed{B.WriteIntent{_, policy, _, _, _}}: Some{policy}
    case _: None{}
