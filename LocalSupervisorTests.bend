import Base
import ./Core.bend as C
import ./Dlm.bend as D
import ./Backplane.bend as B
import ./DataOS.bend as OS
import ./Frontend.bend as F
import ./Issuance.bend as I
import ./Ledger.bend as L
import ./LedgerBoundaryTests.bend as LB
import ./Negotiation.bend as N
import ./AuditTests.bend as AT
import ./HostBindingTests.bend as HB
import ./Transfer.bend as T
import ./Test.bend as Test
import ./writfs/MountAuthority.bend as A
import ./contrib/rclone/bend/Authority.bend as R

# Synthetic records only: these fixtures do not authenticate an operator,
# supervisor, worker, local process or host. This exercises the same canary
# authority helper and DataOS commit, not Mount.dispatch or native effects.

def source_authority() -> I.Principal:
  I.Principal{101n}

def destination_authority() -> I.Principal:
  I.Principal{102n}

def subject() -> I.Principal:
  I.Principal{R.principal()}

def scope() -> I.Scope:
  I.Scope{A.plan(), T.WriteDomain{2n}, R.principal()}

def empty() -> I.State:
  I.empty(R.stamp(), I.Authorities{I.ReadAuthority{source_authority(), T.ReadDomain{1n}},
      I.Authorities{I.WriteAuthority{destination_authority(), T.WriteDomain{2n}}, I.NoAuthorities{}}},
    I.Placements{I.SourceAt{A.source(), T.ReadDomain{1n}},
      I.Placements{I.DestinationAt{A.destination(), T.WriteDomain{2n}}, I.NoPlacements{}}})

def source() -> I.Change:
  I.submit_source(empty(), 0n, source_authority(),
    I.SourceApproval{1n, 1n, source_authority(), A.source(), T.ReadDomain{1n}, scope(), 7, 4n}, 1n)

def destination() -> I.Change:
  I.submit_write(I.Change.state(source()), 1n, destination_authority(),
    I.WriteApproval{1n, 1n, destination_authority(), A.destination(), T.WriteDomain{2n}, scope(), 7, 4n}, 1n)

def registration() -> I.Change:
  I.register(I.Change.state(destination()), 2n, subject(), I.Request{1n, scope(),
    I.Ids{1n, I.NoIds{}}, 2n, 7, 4n}, 1n, R.internal_token(1))

def projected_base(base: T.Context, +issuer: I.State, +now: Nat) -> T.Context:
  match base:
    case T.Context{live, _, sources, destination, operation, _, _, payments}:
      T.Context{live, now, sources, destination, operation, I.reads(issuer, subject(), now),
        I.writes(issuer, subject(), now), payments}

def projected(+issuer: I.State, +now: Nat) -> T.Context:
  projected_base(R.transfer(A.source(), R.imported_policy(A.source()), A.destination(), False{}, 1, now), issuer, now)

def registry(+issuer: I.State, +now: Nat) -> F.Registry:
  I.registry(issuer, subject(), now)

def artifact() -> B.ArtifactId:
  B.ArtifactId{T.CodeId{3128432319, 2399260650, 1094795486, 1571693091,
    2953011619, 2518121116, 3021012833, 4060091821}}

def retained(grant: A.Grant) -> Bool:
  match grant:
    case A.NoGrant{}:
      False{}
    case A.Granted{B.Committed{session, _, B.WriteIntent{plan,
      T.OutputPolicy{_, T.Bits64{1, 0}, T.Bits64{2, 0}, +kinds,
        T.RCons{T.OriginRule{origin, T.Bits64{1, 0}, T.Bits64{2, 0}, origin_kinds,
          T.CCons{code, T.CEnd{}}, T.Free{}}, T.REnd{}}}, _, B.Storage{}, actual}}, _, _}:
      N.Session.is(session, N.Committed{}) && T.Plan.equal(plan, A.plan())
        && T.ObjectVersion.equal(origin, A.source()) && T.CodeId.equal(code, R.copy_code())
        && U32.is_eq(kinds, R.copy_kind()) && U32.is_eq(origin_kinds, kinds)
        && B.ArtifactId.equal(actual, artifact())
    case _:
      False{}

def plan_is(found: Maybe<&2, T.Plan>) -> Bool:
  match found:
    case Some{plan}: T.Plan.equal(plan, A.plan())
    case None{}: False{}

def use_plan(+frontend: F.State, ref: F.Ref, capabilities: F.Registry, context: T.Context) -> Maybe<&2, T.Plan>:
  F.checked_plan(frontend, capabilities, F.revision(frontend), ref, F.Read{}, context)

def retry_result(result: B.CommitResult, session: N.Session, ledger: L.State) -> Bool:
  match result:
    case B.Rejected{after_session, after_ledger}:
      AT.session_equal(after_session, session) && LB.same(after_ledger, ledger)
    case B.Committed{_, _, _}:
      False{}

def retry(+session: N.Session, +ledger: L.State, +frontend: F.State, ref: F.Ref,
    +candidate: C.Candidate, backplane: B.Context, capabilities: F.Registry) -> Bool:
  retry_result(OS.commit_from_capability(session, N.Session.revision(session), L.revision(ledger), ledger,
    candidate, ref, F.revision(frontend), OS.Context{backplane, frontend, capabilities}), session, ledger)

def ref_equal(a: F.Ref, b: F.Ref) -> Bool:
  match a b:
    case F.Ref{F.Caller{asub, atoken}, aid} F.Ref{F.Caller{bsub, btoken}, bid}:
      Nat.is_eq(asub, bsub) && T.CodeId.equal(atoken, btoken) && Nat.is_eq(aid, bid)

def no_grant(grant: A.Grant) -> Bool:
  match grant:
    case A.NoGrant{}: True{}
    case _: False{}

def rejected_inputs(+change: F.Change, +session: N.Session, +ledger: L.State,
    +candidate: C.Candidate, +backplane: B.Context) -> Bool:
  no_grant(A.descriptor(F.Rejected{F.state(change)}, session, ledger, candidate, backplane, F.EmptyRegistry{}))
    && no_grant(A.descriptor(change, session, ledger, candidate, backplane, F.EmptyRegistry{}))

def after_commit(+grant: A.Grant, +issuer: I.State, +frontend: F.State, +ref: F.Ref,
    +cached_registry: F.Registry, +cached_transfer: T.Context, +backplane: B.Context,
    +candidate: C.Candidate, authority: I.Principal, approval: Nat) -> Bool:
  match grant:
    case A.NoGrant{}: False{}
    case A.Granted{B.Committed{+session, +ledger, _}, +retained_frontend, +retained_ref}:
      +revoked = I.revoke(issuer, I.revision(issuer), authority, approval)
      +current = I.Change.state(revoked)
      +fresh_registry = registry(current, 3n)
      +fresh_transfer = projected(current, 3n)
      retained(grant) && HB.frontend_equal(retained_frontend, frontend) && ref_equal(retained_ref, ref)
        && I.Change.accepted(revoked)
        && plan_is(use_plan(retained_frontend, retained_ref, cached_registry, cached_transfer))
        && Maybe.is_none(&2, T.Plan, use_plan(retained_frontend, retained_ref, fresh_registry, fresh_transfer))
        && Maybe.is_none(&2, T.Plan, use_plan(retained_frontend, retained_ref, cached_registry, fresh_transfer))
        && Maybe.is_none(&2, T.Plan, use_plan(retained_frontend, retained_ref, fresh_registry, cached_transfer))
        && retry(session, ledger, retained_frontend, retained_ref, candidate, backplane, cached_registry)
    case _:
      False{}

# This exact Frontend.Changed is the argument to the same descriptor helper
# used by the public canary. The accepted frontend/ref are reused afterward.
def descriptor(+change: F.Change, +issuer: I.State, +cached_registry: F.Registry,
    +transfer: T.Context, +backplane: B.Context, +candidate: C.Candidate,
    +session: N.Session, +ledger: L.State, authority: I.Principal, approval: Nat, expected: Nat) -> Bool:
  match change:
    case F.Rejected{_}: False{}
    case F.Changed{+frontend, +id}:
      Nat.is_eq(id, expected) && rejected_inputs(change, session, ledger, candidate, backplane)
        && after_commit(A.descriptor(change, session, ledger, candidate, backplane, cached_registry),
        issuer, frontend, F.Ref{R.caller(1), id}, cached_registry, transfer, backplane,
        candidate, authority, approval)

def duplicate_descriptor(change: F.Change, registry: F.Registry) -> F.Change:
  match change:
    case F.Rejected{state}: F.Rejected{state}
    case F.Changed{+state, id}:
      F.dup(state, registry, F.revision(state), F.Ref{R.caller(1), id}, R.live())

def selected_descriptor(+registry: F.Registry, extra: Bool) -> F.Change:
  f = Bool.pick(Unit -> F.Change, extra,
    x => duplicate_descriptor(R.open_descriptor(registry, 1), registry),
    x => R.open_descriptor(registry, 1))
  f(Unit{})

def expected_id(extra: Bool) -> Nat:
  Bool.pick(Nat, extra, 3n, 2n)

def run_prepared(solved: C.SolveResult, principals: Maybe<&2, D.Snapshot>,
    reservation: N.ReservationStep, +issuer: I.State, +negotiation: N.Context,
    +graph: C.Graph, +request: N.Request, +transfer: T.Context, authority: I.Principal,
    approval: Nat, +extra: Bool) -> Bool:
  match solved principals reservation:
    case C.Solved{+candidate, _} Some{principals} N.ReservationAdvanced{+reserved, +ledger}:
      +session = N.Step.session(N.start(reserved, N.Session.revision(reserved), negotiation, ledger))
      +cached_registry = registry(issuer, 3n)
      +backplane = {B.Context{negotiation, R.core_stamp(), principals,
        B.Bindings{B.Binding{request, graph, R.sink(False{}), R.label(), R.destination_label(False{}),
          B.Storage{}, artifact()}, B.NoBindings{}}} : B.Context}
      descriptor(selected_descriptor(cached_registry, extra), issuer, cached_registry, transfer,
        backplane, candidate, session, ledger, authority, approval, expected_id(extra))
    case _ _ _: False{}

def lifecycle_with(authority: I.Principal, approval: Nat, extra: Bool) -> Bool:
  +issuer = I.Change.state(registration())
  +plan = A.plan()
  +request = R.request(plan)
  +graph = R.graph(R.imported_policy(A.source()))
  +pin_context = R.negotiation(plan, projected(issuer, 1n), 1)
  +transfer = projected(issuer, 3n)
  +negotiation = R.negotiation(plan, transfer, 1)
  I.Change.accepted(source()) && I.Change.accepted(destination()) && I.Change.accepted(registration())
    && run_prepared(C.solve_cpu(graph, 0n), D.prepare(1n, 2, D.NoEdges{}),
      R.running(request, pin_context, negotiation, 1), issuer, negotiation, graph, request,
      transfer, authority, approval, extra)

def lifecycle(authority: I.Principal, approval: Nat) -> Bool:
  lifecycle_with(authority, approval, False{})

def main() -> IO(Unit):
  do IO<Unit>:
    Test.check(lifecycle(source_authority(), 1n), "local Copy model source revoke after commit: fresh use denies, cached use stays stale, retry preserves session and ledger")
    Test.check(lifecycle(destination_authority(), 2n), "local Copy model destination revoke after commit: fresh use denies, cached use stays stale, retry preserves session and ledger")
    Test.check(lifecycle_with(source_authority(), 1n, True{}), "local Copy commit retains exact nonfirst frontend descriptor and denies rejected inputs")
    IO.print("LocalSupervisor: 3 checks passed")
