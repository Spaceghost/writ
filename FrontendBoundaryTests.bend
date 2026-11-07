import Base
import ./Frontend.bend as F
import ./FrontendTests.bend as FT
import ./HostBinding.bend as H
import ./HostBindingTests.bend as BT
import ./TransferTests.bend as TF
import ./Test.bend as Test

# Synthetic records model a monitor-supplied state, not authenticated authority.
def with_next(state: F.State, next: Nat) -> F.State:
  match state:
    case F.State{rev, _, handles}: F.State{rev, next, handles}

def with_frontend(state: H.State, frontend: F.State) -> H.State:
  match state:
    case H.State{rev, obj, alias, objects, aliases, routes, quotas, delegations, bindings, _}:
      H.State{rev, obj, alias, objects, aliases, routes, quotas, delegations, bindings, frontend}

def binding_next(+state: H.State, next: Nat) -> H.State:
  with_frontend(state, with_next(H.frontend(state), next))

def rejected(answer: F.Change, old: F.State) -> Bool:
  match answer:
    case F.Rejected{state}: BT.frontend_equal(state, old)
    case F.Changed{_, _}: False{}

def next(state: F.State) -> Nat:
  match state:
    case F.State{_, id, _}: id

def allocated(answer: F.Change, expected_id: Nat, expected_revision: Nat, expected_next: Nat) -> Bool:
  match answer:
    case F.Rejected{_}: False{}
    case F.Changed{+state, id}:
      Nat.is_eq(id, expected_id) && Nat.is_eq(F.revision(state), expected_revision) &&
      Nat.is_eq(next(state), expected_next) && F.valid(state)

def expected_handle(id: Nat, kind: F.HandleKind, closed: Bool) -> F.Handle:
  F.Handle{id, kind, 7n, FT.token(), TF.plan(), 7, 3n, 180n, closed}

def handle_is(found: Maybe<&2, F.Handle>, expected: F.Handle) -> Bool:
  match found:
    case None{}: False{}
    case Some{actual}: BT.handle_equal(actual, expected)

def issued_handle_is(answer: F.Change, expected: F.Handle) -> Bool:
  match answer:
    case F.Rejected{_}: False{}
    case F.Changed{state, id}:
      handle_is(F.find_handle(F.handles(state), id), expected)

def expected_closed(max: Nat) -> F.State:
  F.State{3n, max, F.Handles{expected_handle(2n, F.Descriptor{}, True{}),
    F.Handles{expected_handle(1n, F.Mounted{}, False{}), F.NoHandles{}}}}

def expected_mount(last: Nat, max: Nat) -> F.State:
  F.State{1n, max, F.Handles{expected_handle(last, F.Mounted{}, False{}), F.NoHandles{}}}

def expected_open(last: Nat, max: Nat) -> F.State:
  F.State{2n, max, F.Handles{expected_handle(last, F.Descriptor{}, False{}),
    F.Handles{expected_handle(1n, F.Mounted{}, False{}), F.NoHandles{}}}}

def expected_dup(last: Nat, max: Nat) -> F.State:
  F.State{3n, max, F.Handles{expected_handle(last, F.Descriptor{}, False{}),
    F.Handles{expected_handle(2n, F.Descriptor{}, False{}),
    F.Handles{expected_handle(1n, F.Mounted{}, False{}), F.NoHandles{}}}}}

def applied_state_is(answer: F.Change, expected: F.State) -> Bool:
  match answer:
    case F.Rejected{_}: False{}
    case F.Changed{actual, _}: BT.frontend_equal(actual, expected)

def mounted() -> F.State:
  F.state(F.mount(F.empty(), FT.registry(7), 0n, FT.caller(7n), 7, FT.live()))

def opened() -> F.State:
  F.state(F.open(mounted(), FT.registry(7), 1n, FT.ref(1n), 7, FT.live()))

def is_stale(found: H.Resolved) -> Bool:
  match found:
    case H.Unresolved{H.StaleGeneration{}}: True{}
    case _: False{}

def boundary(+max: Nat) -> IO(Unit):
  +last = Nat.sub(max, 1n)
  +empty_last = with_next(F.empty(), last)
  +mount_last = with_next(mounted(), last)
  +descriptor_last = with_next(opened(), last)
  +empty_max = with_next(F.empty(), max)
  +mount_max = with_next(mounted(), max)
  +descriptor_max = with_next(opened(), max)
  +binding_empty = binding_next(BT.initial(), max)
  +binding_mount = binding_next(BT.mounted(), max)
  +binding_open = binding_next(BT.opened(), max)
  +binding_last = binding_next(BT.mounted(), last)
  +closed = F.close(descriptor_max, 2n, FT.ref(2n))
  +binding_closed = H.Change.state(H.bind_close(binding_open, 2n, 2n, BT.reader(), BT.reader_caller()))
  do IO<Unit>:
    Test.check(Nat.is_gt(max, last) && F.valid(descriptor_max), "frontend maximum next is valid")
    Test.check(allocated(F.mount(empty_last, FT.registry(7), 0n, FT.caller(7n), 7, FT.live()), last, 1n, max), "frontend final mount allocates max minus one")
    Test.check(allocated(F.open(mount_last, FT.registry(7), 1n, FT.ref(1n), 7, FT.live()), last, 2n, max), "frontend final open allocates max minus one")
    Test.check(allocated(F.dup(descriptor_last, FT.registry(7), 2n, FT.ref(2n), FT.live()), last, 3n, max), "frontend final duplicate allocates max minus one")
    Test.check(issued_handle_is(F.mount(empty_last, FT.registry(7), 0n, FT.caller(7n), 7, FT.live()), expected_handle(last, F.Mounted{}, False{})), "frontend final mount preserves exact scope")
    Test.check(issued_handle_is(F.open(mount_last, FT.registry(7), 1n, FT.ref(1n), 7, FT.live()), expected_handle(last, F.Descriptor{}, False{})), "frontend final open preserves exact scope")
    Test.check(issued_handle_is(F.dup(descriptor_last, FT.registry(7), 2n, FT.ref(2n), FT.live()), expected_handle(last, F.Descriptor{}, False{})), "frontend final duplicate preserves exact scope")
    Test.check(applied_state_is(F.mount(empty_last, FT.registry(7), 0n, FT.caller(7n), 7, FT.live()), expected_mount(last, max)), "frontend final mount preserves complete state")
    Test.check(applied_state_is(F.open(mount_last, FT.registry(7), 1n, FT.ref(1n), 7, FT.live()), expected_open(last, max)), "frontend final open preserves complete state")
    Test.check(applied_state_is(F.dup(descriptor_last, FT.registry(7), 2n, FT.ref(2n), FT.live()), expected_dup(last, max)), "frontend final duplicate preserves complete state")
    Test.check(rejected(F.mount(empty_max, FT.registry(7), 0n, FT.caller(7n), 7, FT.live()), empty_max), "frontend exhausted mount rejects unchanged")
    Test.check(rejected(F.open(mount_max, FT.registry(7), 1n, FT.ref(1n), 7, FT.live()), mount_max), "frontend exhausted open rejects unchanged")
    Test.check(rejected(F.dup(descriptor_max, FT.registry(7), 2n, FT.ref(2n), FT.live()), descriptor_max), "frontend exhausted duplicate rejects unchanged")
    Test.check(rejected(F.mount(empty_max, FT.registry(7), 1n, FT.caller(7n), 7, FT.live()), empty_max), "frontend exhausted stale mount rejects unchanged")
    Test.check(rejected(F.open(mount_max, FT.registry(7), 0n, FT.ref(1n), 7, FT.live()), mount_max), "frontend exhausted stale open rejects unchanged")
    Test.check(rejected(F.dup(descriptor_max, FT.registry(7), 1n, FT.ref(2n), FT.live()), descriptor_max), "frontend exhausted stale duplicate rejects unchanged")
    Test.check(FT.plan_is(FT.resolve(descriptor_max, FT.registry(7), 2n, FT.ref(2n), F.Read{}), TF.plan()), "frontend exhausted allocator preserves descriptor read")
    Test.check(FT.no_plan(FT.resolve(descriptor_max, FT.registry(7), 1n, FT.ref(2n), F.Read{})), "frontend exhausted allocator preserves stale read denial")
    Test.check(F.accepted(F.attenuate(descriptor_max, FT.registry(7), 2n, FT.ref(2n), 1, FT.live())), "frontend exhausted allocator preserves attenuation")
    Test.check(F.accepted(closed) && Nat.is_eq(next(F.state(closed)), max) && Nat.is_eq(F.revision(F.state(closed)), 3n), "frontend exhausted allocator permits owner close")
    Test.check(BT.frontend_equal(F.state(closed), expected_closed(max)), "frontend exhausted close preserves exact other handle")
    Test.check(FT.no_plan(FT.resolve(descriptor_max, F.EmptyRegistry{}, 2n, FT.ref(2n), F.Read{})) && F.accepted(F.close(descriptor_max, 2n, FT.ref(2n))), "frontend exhausted owner closes after capability revocation")
    Test.check(FT.no_plan(F.checked_plan(descriptor_max, FT.registry(7), 2n, FT.ref(2n), F.Read{}, TF.with_now(TF.context(), 180n))) && F.accepted(F.close(descriptor_max, 2n, FT.ref(2n))), "frontend exhausted owner closes after capability expiry")
    Test.check(FT.no_plan(FT.resolve(F.state(closed), FT.registry(7), 3n, FT.ref(2n), F.Read{})), "frontend close at exhaustion leaves tombstone")
    Test.check(rejected(F.close(descriptor_max, 2n, F.Ref{FT.caller(8n), 2n}), descriptor_max), "frontend exhausted allocator preserves other-owner close denial")
    Test.check(H.valid(binding_empty) && H.valid(binding_mount) && H.valid(binding_open), "binding exhausted frontend fixtures remain valid")
    Test.check(BT.denied(H.bind_mount(binding_empty, 0n, BT.reader_route(), BT.reader_caller(), BT.registry(), BT.all_rights(), BT.live()), binding_empty, H.FrontendRejected{}), "binding exhausted frontend mount rejects unchanged")
    Test.check(BT.denied(H.bind_open(binding_mount, 1n, 1n, BT.reader(), BT.reader_caller(), BT.registry(), BT.all_rights(), BT.live()), binding_mount, H.FrontendRejected{}), "binding exhausted frontend open rejects unchanged")
    Test.check(BT.denied(H.bind_attenuate(binding_open, 2n, 2n, BT.reader(), BT.reader_caller(), BT.registry(), BT.read(), BT.live()), binding_open, H.FrontendRejected{}), "binding exhausted frontend duplication rejects unchanged")
    Test.check(H.Change.accepted(H.bind_open(binding_last, 1n, 1n, BT.reader(), BT.reader_caller(), BT.registry(), BT.all_rights(), BT.live())), "binding final frontend allocation succeeds")
    Test.check(H.Change.accepted(H.bind_close(binding_open, 2n, 2n, BT.reader(), BT.reader_caller())), "binding exhausted frontend permits owner cleanup")
    Test.check(BT.handle_closed(BT.frontend_handle(binding_closed, 2n)) &&
      is_stale(H.resolve(binding_closed, 2n, BT.reader())) && H.valid(binding_closed) &&
      Nat.is_eq(BT.reader_caps(binding_closed), 1n+BT.reader_caps(binding_open)),
      "binding exhausted cleanup tombstones handle, stales alias and refunds slot")
    IO.print("Frontend allocation boundary: 32 checks passed")

def parsed(value: Maybe<&2, Nat>) -> IO(Unit):
  match value:
    case None{}: IO.die(Unit, 1, "FAIL: frontend maximum parse")
    case Some{max}: boundary(max)

def main() -> IO(Unit):
  parsed(Nat.read("281474976710655"))
