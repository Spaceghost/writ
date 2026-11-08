import Base
import ../../HostBinding.bend as H
import ../../HostBindingTests.bend as T
import ../../Frontend.bend as F
import ../../Test.bend as Check

def choose_subject(yes: Bool, subject: Nat) -> Nat:
  match yes:
    case True{}: 8n
    case False{}: subject
def altered(handle: F.Handle) -> F.Handle:
  match handle:
    case F.Handle{+id, kind, subject, token, plan, rights, epoch, expires, closed}:
      F.Handle{id, kind, choose_subject(Nat.is_eq(id, 3n), subject), token, plan, rights, epoch, expires, closed}
def alter_handles(handles: F.Handles) -> F.Handles:
  match handles:
    case F.NoHandles{}: F.NoHandles{}
    case F.Handles{head, tail}: F.Handles{altered(head), alter_handles(tail)}
def alter_frontend(frontend: F.State) -> F.State:
  match frontend:
    case F.State{revision, next, handles}: F.State{revision, next, alter_handles(handles)}
def alter_state(state: H.State) -> H.State:
  match state:
    case H.State{revision, next_object, next_alias, objects, aliases, routes, quotas, delegations, bindings, frontend}:
      H.State{revision, next_object, next_alias, objects, aliases, routes, quotas, delegations, bindings, alter_frontend(frontend)}
def synthetic() -> H.State:
  alter_state(T.derived())
def outcome() -> H.Change:
  H.bind_close(synthetic(), 4n, 2n, T.reader(), T.reader_caller())
def next_state() -> H.State:
  H.Change.state(outcome())
def is_stale(resolved: H.Resolved) -> Bool:
  match resolved:
    case H.Unresolved{H.StaleGeneration{}}: True{}
    case _: False{}
def subject_is(found: Maybe<&2, F.Handle>, wanted: Nat) -> Bool:
  match found:
    case Some{F.Handle{_, _, subject, _, _, _, _, _, _}}: Nat.is_eq(subject, wanted)
    case _: False{}
def matches_caller(found: Maybe<&2, F.Handle>, id: Nat) -> Bool:
  match found:
    case None{}: False{}
    case Some{handle}: F.ref_matches(handle, F.Ref{T.reader_caller(), id})
def baseline_outcome() -> H.Change:
  H.bind_close(T.derived(), 4n, 2n, T.reader(), T.reader_caller())
def was_rejected(change: F.Change) -> Bool:
  match change:
    case F.Rejected{_}: True{}
    case _: False{}
def child_after_root(change: F.Change) -> Bool:
  match change:
    case F.Rejected{_}: False{}
    case F.Changed{+next, _}:
      was_rejected(F.close(next, F.revision(next), F.Ref{T.reader_caller(), 3n}))
def child_reject() -> Bool:
  child_after_root(F.close(H.frontend(synthetic()), F.revision(H.frontend(synthetic())), F.Ref{T.reader_caller(), 2n}))
def generation_increased(before: Maybe<&2, H.Object>, after: Maybe<&2, H.Object>) -> Bool:
  match before after:
    case Some{H.Object{_, old, _, _, _, _}} Some{H.Object{_, new, _, _, _, _}}: Nat.is_gt(new, old)
    case _ _: False{}
def main() -> IO(Unit):
  do IO<Unit>:
    Check.check(H.valid(T.derived()), "baseline public-transition fixture is structurally valid")
    Check.check(H.valid(synthetic()), "synthetic changed descendant subject remains structurally valid")
    Check.check(subject_is(T.frontend_handle(synthetic(), 2n), 7n), "root handle names caller subject seven")
    Check.check(subject_is(T.frontend_handle(synthetic(), 3n), 8n), "altered descendant names subject eight")
    Check.check(matches_caller(T.frontend_handle(synthetic(), 2n), 2n), "caller subject and token match root handle")
    Check.check(Bool.not(matches_caller(T.frontend_handle(synthetic(), 3n), 3n)), "caller subject and token do not match descendant")
    Check.check(H.Change.accepted(baseline_outcome()) && T.handle_closed(T.frontend_handle(H.Change.state(baseline_outcome()), 3n)), "unaltered descendant closes in positive control")
    Check.check(child_reject(), "same caller is rejected by descendant close after root close")
    Check.check(H.Change.accepted(outcome()), "binding close reports success despite descendant rejection")
    Check.check(T.handle_closed(T.frontend_handle(next_state(), 2n)), "direct handle closed")
    Check.check(Bool.not(T.handle_closed(T.frontend_handle(next_state(), 3n))), "descendant remains open")
    Check.check(generation_increased(H.find_object(H.objects(synthetic()), 2n), H.find_object(H.objects(next_state()), 2n)), "root object generation advanced")
    Check.check(generation_increased(H.find_object(H.objects(synthetic()), 3n), H.find_object(H.objects(next_state()), 3n)), "descendant object generation advanced")
    Check.check(H.delegated_alias_exists(H.delegations(synthetic()), 4n) && Bool.not(H.delegated_alias_exists(H.delegations(next_state()), 4n)), "descendant delegation was pruned")
    Check.check(is_stale(H.resolve(next_state(), 4n, T.worker())), "descendant alias has stale generation")
    Check.check(Nat.is_gt(T.reader_caps(next_state()), T.reader_caps(synthetic())), "reader quota refunded")
    return Unit{}
