import Base
import ../../../Core.bend as Core
import ../../../Dlm.bend as Dlm
import ../../../Transfer.bend as Transfer
import ../../../Negotiation.bend as Negotiation
import ../../../Ledger.bend as Ledger
import ../../../Frontend.bend as Frontend
import ../../../Backplane.bend as Backplane
import ../../../DataOS.bend as DataOS

# FIXED LOCAL REFERENCE PROFILE. The authenticated host supplies object versions
# from Model, not caller policy or registry fields. This is a single principal,
# no-charge Copy service. The same process owns the object table, approved code,
# approvals, descriptor registry, and deterministic copy validation. The short
# logical clock is local to one serialized transaction; it makes no wall-clock,
# external owner-approval, payment, revocation-feed, or durable-storage claim.
# These internal constructors are not authentication APIs.
def stamp() -> Transfer.Stamp:
  Transfer.Stamp{1n, 1n, 1n}

def core_stamp() -> Core.Stamp:
  Core.Stamp{Core.Bits64{1, 0}, Core.Bits64{1, 0}, Core.Bits64{1, 0}}

def principal() -> Nat:
  1n

def copy_code() -> Transfer.CodeId:
  # Registered in-process operation identity, not a digest or credential.
  Transfer.CodeId{1465010516, 1, 0, 0, 0, 0, 0, 0}

def copy_kind() -> U32:
  Transfer.OpKind.bit(Transfer.Copy{})

def secrecy() -> Transfer.Bits64:
  Transfer.Bits64{1, 0}

def untrusted() -> Transfer.Bits64:
  Transfer.Bits64{2, 0}

def imported_policy(+object: Transfer.ObjectVersion) -> Transfer.OutputPolicy:
  Transfer.OutputPolicy{Core.bytes_type(), secrecy(), untrusted(), copy_kind(),
    Transfer.RCons{Transfer.OriginRule{object, secrecy(), untrusted(), copy_kind(),
      Transfer.CCons{copy_code(), Transfer.CEnd{}}, Transfer.Free{}}, Transfer.REnd{}}}

def clearance(public: Bool) -> Transfer.Bits64:
  match public:
    case True{}:
      Transfer.Bits64.zero()
    case False{}:
      secrecy()

def core_bits(bits: Transfer.Bits64) -> Core.Bits64:
  match bits:
    case Transfer.Bits64{lo, hi}:
      Core.Bits64{lo, hi}

def policy_secrecy(policy: Transfer.OutputPolicy) -> Transfer.Bits64:
  match policy:
    case Transfer.OutputPolicy{_, secrecy, _, _, _}:
      secrecy

def policy_untrusted(policy: Transfer.OutputPolicy) -> Transfer.Bits64:
  match policy:
    case Transfer.OutputPolicy{_, _, untrusted, _, _}:
      untrusted

def label() -> Dlm.Label:
  Dlm.Label{Dlm.Rule{Dlm.Named{0}, Dlm.Named{1}},
    Dlm.Rule{Dlm.Bottom{}, Dlm.Bottom{}}}

def destination_label(public: Bool) -> Dlm.Label:
  match public:
    case True{}:
      Dlm.Label{Dlm.Rule{Dlm.Bottom{}, Dlm.Bottom{}},
        Dlm.Rule{Dlm.Bottom{}, Dlm.Bottom{}}}
    case False{}:
      label()

def plan(source: Transfer.ObjectVersion, destination: Transfer.ObjectVersion,
    invocation: U32) -> Transfer.Plan:
  Transfer.Plan{stamp(), U32.to_nat(invocation), Transfer.OCons{source, Transfer.OEnd{}},
    destination, copy_code(), Transfer.Copy{}, Core.bytes_type()}

def scope(+source: Transfer.ObjectVersion, +destination: Transfer.ObjectVersion,
    invocation: U32) -> Transfer.GrantScope:
  Transfer.GrantScope{U32.to_nat(invocation), Transfer.OCons{source, Transfer.OEnd{}},
    destination, Transfer.WriteDomain{2n}, copy_code(), Transfer.Copy{}, stamp(), 4n}

def transfer(+source: Transfer.ObjectVersion, policy: Transfer.OutputPolicy,
    +destination: Transfer.ObjectVersion, public: Bool, +invocation: U32,
    time: Nat) -> Transfer.Context:
  +grant_scope = scope(source, destination, invocation)
  Transfer.Context{stamp(), time,
    Transfer.SCons{Transfer.OutputPolicy.as_source(policy, source,
      Transfer.ReadDomain{1n}, 1n), Transfer.SEnd{}},
    Transfer.DestinationPolicy{destination, Transfer.WriteDomain{2n}, 1n,
      Core.bytes_type(), clearance(public), untrusted(), copy_kind()},
    Transfer.ApprovedOperation{copy_code(), Transfer.Copy{}, 1n,
      Transfer.TCons{Core.bytes_type(), Transfer.TEnd{}}, Core.bytes_type()},
    Transfer.ReadCons{Transfer.ReadGrant{source, Transfer.ReadDomain{1n}, grant_scope},
      Transfer.ReadEnd{}},
    Transfer.WriteCons{Transfer.WriteGrant{destination, Transfer.WriteDomain{2n}, grant_scope},
      Transfer.WriteEnd{}}, Transfer.PayEnd{}}

def approvals(origins: Transfer.Objects, +plan: Transfer.Plan) -> Negotiation.Approvals:
  match origins:
    case Transfer.OEnd{}:
      Negotiation.NoApprovals{}
    case Transfer.OCons{origin, rest}:
      Negotiation.Approvals{Negotiation.Approval{origin, plan, 4n}, approvals(rest, plan)}

def resolved_approvals(found: Transfer.OriginLookup, plan: Transfer.Plan) -> Negotiation.Approvals:
  match found:
    case Transfer.Missing{}:
      Negotiation.NoApprovals{}
    case Transfer.Found{origins}:
      approvals(origins, plan)

def request(plan: Transfer.Plan) -> Negotiation.Request:
  Negotiation.Request{plan, principal(), 1n, 0n, 4n}

def nonce(invocation: U32) -> Transfer.CodeId:
  # Local transaction discriminator; no network challenge authentication claim.
  Transfer.CodeId{1465010516, 2, invocation, 0, 0, 0, 0, 0}

def negotiation(+plan: Transfer.Plan, +context: Transfer.Context,
    +invocation: U32) -> Negotiation.Context:
  Negotiation.Context{context,
    resolved_approvals(Transfer.required_origins(plan, context), plan),
    Negotiation.Challenges{Negotiation.Challenge{1n, plan, nonce(invocation), 2n, 4n},
      Negotiation.NoChallenges{}},
    Negotiation.Samples{Negotiation.Sample{1n, plan, 1n, nonce(invocation), True{}, 4n},
      Negotiation.NoSamples{}},
    Negotiation.Budgets{Negotiation.Budget{U32.to_nat(invocation), plan,
      principal(), 1n, 0n, 4n}, Negotiation.NoBudgets{}}}

def graph(+policy: Transfer.OutputPolicy) -> Core.Graph:
  Core.Graph{core_stamp(),
    [Core.State{Core.bytes_type(), core_bits(policy_secrecy(policy)),
      core_bits(policy_untrusted(policy)), Core.read_effect()}, Core.State.typed(Core.bytes_type())],
    [Core.Edge{0, 1}], [], [Core.Edge{0, 1}]}

def sink(public: Bool) -> Core.Sink:
  Core.Sink{1, core_bits(clearance(public)), core_bits(untrusted()),
    Core.Bits64.join(Core.read_effect(), Core.write_effect()), Core.write_effect()}

def internal_token(invocation: U32) -> Transfer.CodeId:
  # In-process descriptor identity. It never replaces the host bearer token.
  Transfer.CodeId{1465010516, 3, invocation, 0, 0, 0, 0, 0}

def caller(invocation: U32) -> Frontend.Caller:
  Frontend.Caller{principal(), internal_token(invocation)}

def registry(plan: Transfer.Plan, invocation: U32) -> Frontend.Registry:
  Frontend.Registered{Frontend.Capability{internal_token(invocation), principal(), plan,
    Frontend.request_rights(Frontend.Execute{}), 1n, 4n}, Frontend.EmptyRegistry{}}

def live() -> Frontend.Live:
  Frontend.Live{1n, 3n}

def open_mount(change: Frontend.Change, registry: Frontend.Registry,
    invocation: U32) -> Frontend.Change:
  match change:
    case Frontend.Rejected{state}:
      Frontend.Rejected{state}
    case Frontend.Changed{+state, id}:
      Frontend.open(state, registry, Frontend.revision(state),
        Frontend.Ref{caller(invocation), id}, Frontend.request_rights(Frontend.Execute{}), live())

def open_descriptor(+registry: Frontend.Registry, +invocation: U32) -> Frontend.Change:
  +empty = Frontend.empty()
  open_mount(Frontend.mount(empty, registry, Frontend.revision(empty), caller(invocation),
    Frontend.request_rights(Frontend.Execute{}), live()), registry, invocation)

def running(+request: Negotiation.Request, pin_context: Negotiation.Context,
    +context: Negotiation.Context, invocation: U32) -> Negotiation.ReservationStep:
  +opened = Negotiation.open(request)
  +pinned = Negotiation.Step.session(Negotiation.pin(opened,
    Negotiation.Session.revision(opened), copy_code(), pin_context))
  +challenged = Negotiation.Step.session(Negotiation.challenge(pinned,
    Negotiation.Session.revision(pinned), 1n, context))
  +sampled = Negotiation.Step.session(Negotiation.sample(challenged,
    Negotiation.Session.revision(challenged), 1n, context))
  +approved = Negotiation.Step.session(Negotiation.approve(sampled,
    Negotiation.Session.revision(sampled), context))
  +ledger = Ledger.empty(Ledger.Accounts{Ledger.Account{principal(), 0n}, Ledger.NoAccounts{}})
  Negotiation.reserve(approved, Negotiation.Session.revision(approved), Ledger.revision(ledger),
    U32.to_nat(invocation), context, ledger)

def intent(result: Backplane.CommitResult) -> Maybe<&2, Backplane.WriteIntent>:
  match result:
    case Backplane.Rejected{_, _}:
      None{}
    case Backplane.Committed{_, _, intent}:
      Some{intent}

def commit_descriptor(change: Frontend.Change, +session: Negotiation.Session,
    +ledger: Ledger.State, candidate: Core.Candidate, context: Backplane.Context,
    registry: Frontend.Registry, invocation: U32) -> Maybe<&2, Backplane.WriteIntent>:
  match change:
    case Frontend.Rejected{_}:
      None{}
    case Frontend.Changed{+frontend, id}:
      intent(DataOS.commit_from_capability(session, Negotiation.Session.revision(session),
        Ledger.revision(ledger), ledger, candidate, Frontend.Ref{caller(invocation), id},
        Frontend.revision(frontend), DataOS.Context{context, frontend, registry}))

def finish(solved: Core.SolveResult, principals: Maybe<&2, Dlm.Snapshot>,
    +request: Negotiation.Request, +graph: Core.Graph, +public: Bool,
    artifact: Backplane.ArtifactId, +context: Negotiation.Context,
    reservation: Negotiation.ReservationStep, +registry: Frontend.Registry,
    +invocation: U32, current_registry: Frontend.Registry) -> Maybe<&2, Backplane.WriteIntent>:
  match solved principals reservation:
    case Core.Solved{candidate, _} Some{principals}
      Negotiation.ReservationAdvanced{+reserved, +ledger}:
      +session = Negotiation.Step.session(Negotiation.start(reserved,
        Negotiation.Session.revision(reserved), context, ledger))
      commit_descriptor(open_descriptor(registry, invocation), session, ledger, candidate,
        Backplane.Context{context, core_stamp(), principals,
          Backplane.Bindings{Backplane.Binding{request, graph, sink(public), label(),
            destination_label(public), Backplane.Storage{}, artifact}, Backplane.NoBindings{}}},
        current_registry, invocation)
    case _ _ _:
      None{}

# This testable internal entry point admits a current registry only from the
# service, so adversarial tests can prove revocation is checked at final commit.
def copy_with_registry(+source: Transfer.ObjectVersion, +policy: Transfer.OutputPolicy,
    +destination: Transfer.ObjectVersion, +public: Bool, +invocation: U32,
    artifact: Backplane.ArtifactId, current_registry: Frontend.Registry) -> Maybe<&2, Backplane.WriteIntent>:
  +plan = plan(source, destination, invocation)
  +request = request(plan)
  +context = negotiation(plan, transfer(source, policy, destination, public, invocation, 3n), invocation)
  +pin_context = negotiation(plan, transfer(source, policy, destination, public, invocation, 1n), invocation)
  +graph = graph(policy)
  finish(Core.solve_cpu(graph, 0n), Dlm.prepare(1n, 2, Dlm.NoEdges{}), request, graph,
    public, artifact, context, running(request, pin_context, context, invocation),
    registry(plan, invocation), invocation, current_registry)

def authorize_copy(+source: Transfer.ObjectVersion, policy: Transfer.OutputPolicy,
    +destination: Transfer.ObjectVersion, public: Bool, +invocation: U32,
    artifact: Backplane.ArtifactId) -> Maybe<&2, Backplane.WriteIntent>:
  copy_with_registry(source, policy, destination, public, invocation, artifact,
    registry(plan(source, destination, invocation), invocation))
