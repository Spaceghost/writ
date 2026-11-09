import Base
import ./HostPrimitives.bend as P
import ./HostPrimitivesTests.bend as PT
import ./HostIdentity.bend as I
import ./HostIdentityTests.bend as IT
import ./HostIssueCurrentTests.bend as C
import ./Frontend.bend as F
import ./FacadeTests.bend as FF
import ./Transfer.bend as T
import ./TransferTests.bend as TF
import ./HostWire.bend as W
import ./Test.bend as Test

# All owner/session/registry records are synthetic. The result is model data.
def typed(+host: P.State, revision: Nat, session: Nat, +front: F.State, front_revision: Nat,
    registry: F.Registry, context: T.Context, handle: Nat, plan: T.Plan, rights: U32, expires: Nat) -> P.IssueResult:
  P.issue_result(host, revision, session, front, front_revision, registry, context, handle, plan, rights, expires)

def current(+host: P.State) -> P.IssueResult:
  typed(host, P.revision(host), PT.session_client(), C.frontend(), F.revision(C.frontend()),
    C.registry(), TF.context(), PT.pub_handle(), TF.plan(), PT.root_rights(), PT.pub_root_expires())

def equivalent(a: P.Step, b: P.Step) -> Bool:
  match a b:
    case P.Admitted{as, ae} P.Admitted{bs, be}:
      PT.state_equal(as, bs) && PT.effects_equal(ae, be)
    case P.Denied{as, ar} P.Denied{bs, br}:
      PT.state_equal(as, bs) && P.Error.equal(ar, br)
    case _ _: False{}

def denial(+result: P.IssueResult, +legacy: P.Step, +host: P.State, +reason: P.Error) -> Bool:
  match result:
    case P.Issued{_, _}: False{}
    case P.IssueDenied{state, got}:
      P.Error.equal(got, reason) && PT.state_equal(state, host)
        && PT.denied(P.IssueResult.step(result), host, reason)
        && equivalent(P.IssueResult.step(result), legacy)

def slot_entry(found: Maybe<&2, I.Entry>, +slot: Nat) -> Bool:
  match found:
    case None{}: False{}
    case Some{+entry}:
      Nat.is_eq(I.entry_slot(entry), slot) && Nat.is_eq(I.entry_holder(entry), PT.session_client())
        && IT.caller_equal(I.entry_owner(entry), PT.pub_caller())
        && Nat.is_eq(I.entry_handle(entry), PT.pub_handle()) && T.Plan.equal(I.entry_plan(entry), TF.plan())
        && U32.is_eq(I.entry_rights(entry), PT.root_rights()) && Nat.is_eq(I.entry_expires(entry), PT.pub_root_expires())

def exact(+result: P.IssueResult, change: I.Change, +before: P.State) -> Bool:
  match result change:
    case P.Issued{+after, slot} I.Accepted{identity, got}:
      Nat.is_eq(slot, got) && Nat.is_gt(slot, PT.root_slot())
        && PT.state_equal(after, P.with_identity(before, identity))
        && slot_entry(I.entry_lookup(I.entries(P.identity(after)), slot), slot)
        && PT.silent(P.IssueResult.step(result))
    case _ _: False{}

def direct_nonfirst() -> Bool:
  +before = PT.pub_issued()
  +result = current(before)
  +identity = P.identity(before)
  exact(result, I.mint(identity, I.revision(identity), PT.session_client(), PT.pub_handle(), TF.plan(),
      PT.root_rights(), PT.pub_root_expires()), before)
    && equivalent(P.IssueResult.step(result), P.issue(before, P.revision(before), PT.session_client(),
      C.frontend(), F.revision(C.frontend()), C.registry(), TF.context(), PT.pub_handle(), TF.plan(),
      PT.root_rights(), PT.pub_root_expires()))

# This fixture's second slot is the small, wire-representable value 22; no
# general Nat-to-U32 representability is implied by the typed result.
def use_and_delegate(result: P.IssueResult) -> Bool:
  match result:
    case P.IssueDenied{_, _}: False{}
    case P.Issued{+host, +slot}:
      Nat.is_eq(slot, 22n)
        && PT.granted_as(P.use(host, P.revision(host), PT.session_client(),
          PT.use_of(PT.ref_at(slot), W.operation_execute(), PT.input_rights()), PT.pub_now()), PT.pub_caller())
        && Bool.not(Maybe.is_some(&2, P.Error, P.Step.reason(P.delegate(host, P.revision(host), PT.session_client(),
          PT.ref_at(slot), PT.session_worker(), PT.input_rights(), PT.input_lifetime(), PT.pub_now()))))

def parity(+host: P.State, +revision: Nat, +session: Nat, +front: F.State, +front_revision: Nat,
    +registry: F.Registry, +context: T.Context, +handle: Nat, +plan: T.Plan, +rights: U32, +expires: Nat,
    expected: P.Error) -> Bool:
  denial(typed(host, revision, session, front, front_revision, registry, context, handle, plan, rights, expires),
    P.issue(host, revision, session, front, front_revision, registry, context, handle, plan, rights, expires), host, expected)

def prior_denials() -> Bool:
  +host = C.state()
  +front = C.frontend()
  +ctx = TF.context()
  +exp = PT.pub_root_expires()
  parity(host, 1n+P.revision(host), PT.session_client(), front, 0n, F.EmptyRegistry{}, ctx, PT.pub_handle(), TF.plan(), 7, exp, P.StaleRevision{})
    && parity(host, P.revision(host), PT.session_client(), front, 0n, F.EmptyRegistry{}, ctx, PT.pub_handle(), PT.other_plan(), 7, exp, P.PlanMismatch{})
    && parity(host, P.revision(host), PT.session_worker(), front, 0n, F.EmptyRegistry{}, ctx, PT.pub_handle(), TF.plan(), 7, exp, P.OwnerMismatch{})
    && parity(host, P.revision(host), PT.session_client(), FF.descriptor(PT.pub_subject(), 1), 0n, F.EmptyRegistry{}, ctx, PT.pub_handle(), TF.plan(), 7, exp, P.RightsNotHeld{})
    && parity(host, P.revision(host), PT.session_client(), front, 0n, F.EmptyRegistry{}, ctx, PT.pub_handle(), TF.plan(), 7, 1n+exp, P.LeaseExceeded{})
    && parity(host, P.revision(host), PT.session_unknown(), front, 0n, F.EmptyRegistry{}, ctx, PT.pub_handle(), TF.plan(), 7, exp, P.Identity{I.UnknownSession{}})

def authority_denials() -> Bool:
  +host = C.state()
  +front = C.frontend()
  +ctx = TF.context()
  +exp = PT.pub_root_expires()
  parity(host, P.revision(host), PT.session_client(), front, 0n, C.registry(), ctx, PT.pub_handle(), TF.plan(), 7, exp, P.AuthorityUnavailable{})
    && parity(host, P.revision(host), PT.session_client(), front, F.revision(front), F.EmptyRegistry{}, ctx, PT.pub_handle(), TF.plan(), 7, exp, P.AuthorityUnavailable{})
    && parity(host, P.revision(host), PT.session_client(), front, F.revision(front), C.registry(), TF.with_reads(ctx, T.ReadEnd{}), PT.pub_handle(), TF.plan(), 7, exp, P.AuthorityUnavailable{})
    && parity(host, P.revision(host), PT.session_client(), front, F.revision(front), C.registry(), TF.with_writes(ctx, T.WriteEnd{}), PT.pub_handle(), TF.plan(), 7, exp, P.AuthorityUnavailable{})
    && parity(host, P.revision(host), PT.session_client(), front, F.revision(front), C.duplicate(), ctx, PT.pub_handle(), TF.plan(), 7, exp, P.AuthorityUnavailable{})
    && parity(host, P.revision(host), PT.session_client(), front, F.revision(front), C.malformed(), ctx, PT.pub_handle(), TF.plan(), 7, exp, P.AuthorityUnavailable{})
    && parity(host, P.revision(host), PT.session_client(), front, F.revision(front), C.reduced(), ctx, PT.pub_handle(), TF.plan(), 7, exp, P.AuthorityUnavailable{})
    && parity(host, P.revision(host), PT.session_client(), front, F.revision(front), C.swapped_plan(), ctx, PT.pub_handle(), TF.plan(), 7, exp, P.AuthorityUnavailable{})
    && parity(host, P.revision(host), PT.session_client(), front, F.revision(front), C.expired(), ctx, PT.pub_handle(), TF.plan(), 7, exp, P.AuthorityUnavailable{})
    && parity(host, P.revision(host), PT.session_client(), front, F.revision(front), C.registry(), TF.with_live(ctx, T.Stamp{1n, 2n, 4n}), PT.pub_handle(), TF.plan(), 7, exp, P.AuthorityUnavailable{})
    && parity(host, P.revision(host), PT.session_client(), C.closed(), F.revision(C.closed()), C.registry(), ctx, PT.pub_handle(), TF.plan(), 7, exp, P.AuthorityUnavailable{})

def endpoint_denied(+host: P.State, reason: I.Error) -> Bool:
  parity(host, P.revision(host), PT.session_client(), C.frontend(), 0n, F.EmptyRegistry{}, TF.context(),
    PT.pub_handle(), TF.plan(), 7, PT.pub_root_expires(), P.Identity{reason})

def terminal_one(+host: P.State) -> Bool:
  parity(host, P.revision(host), PT.session_client(), C.frontend(), F.revision(C.frontend()), F.EmptyRegistry{}, TF.context(),
    PT.pub_handle(), TF.plan(), 7, PT.pub_root_expires(), P.AuthorityUnavailable{})

def terminal_value(+maximum: Nat) -> Bool:
  terminal_one(C.max_slot_state(C.state(), maximum))
    && terminal_one(C.max_identity_revision(C.state(), maximum))
    && terminal_one(C.max_host_revision(C.state(), maximum))

def terminal(maximum: Maybe<&2, Nat>) -> Bool:
  match maximum:
    case Some{value}: terminal_value(value)
    case None{}: False{}

def main() -> IO(Unit):
  do IO<Unit>:
    Test.check(direct_nonfirst(), "PH-issue-result exact nonfirst slot and state match direct mint")
    Test.check(use_and_delegate(current(PT.pub_issued())), "PH-issue-result returned bounded slot resolves and delegates")
    Test.check(prior_denials(), "PH-issue-result prior denials match legacy projection")
    Test.check(authority_denials(), "PH-issue-result current authority denials match legacy projection")
    Test.check(endpoint_denied(C.with_origin(C.state(), I.Inherited{PT.session_worker()}), I.InheritedEndpoint{}) && endpoint_denied(C.with_origin(C.state(), I.Transferred{PT.session_worker()}), I.TransferredEndpoint{}), "PH-issue-result inherited and transferred denials match legacy")
    Test.check(terminal(Nat.read("281474976710655")), "PH-issue-result stale authority skips terminal mint")
    IO.print("HostIssueResult: 6 checks passed")
