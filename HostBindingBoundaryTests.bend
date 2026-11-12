import Base
import ./HostBinding.bend as H
import ./HostBindingTests.bend as HT
import ./Frontend.bend as F
import ./Test.bend as Test

# Synthetic states and callers do not authenticate an actual host or principal.
def with_ids(state: H.State, object: Nat, alias: Nat) -> H.State:
  match state:
    case H.State{rev, _, _, objects, aliases, routes, quotas, delegations, bindings, frontend}:
      H.State{rev, object, alias, objects, aliases, routes, quotas, delegations, bindings, frontend}

def with_object(state: H.State, value: Nat) -> H.State:
  match state:
    case H.State{rev, _, alias, objects, aliases, routes, quotas, delegations, bindings, frontend}:
      H.State{rev, value, alias, objects, aliases, routes, quotas, delegations, bindings, frontend}

def with_alias(state: H.State, value: Nat) -> H.State:
  match state:
    case H.State{rev, object, _, objects, aliases, routes, quotas, delegations, bindings, frontend}:
      H.State{rev, object, value, objects, aliases, routes, quotas, delegations, bindings, frontend}

def mount(state: H.State, revision: Nat) -> H.Change:
  H.bind_mount(state, revision, HT.reader_route(), HT.reader_caller(), HT.registry(), HT.all_rights(), HT.live())

def open(state: H.State, revision: Nat) -> H.Change:
  H.bind_open(state, revision, 1n, HT.reader(), HT.reader_caller(), HT.registry(), HT.all_rights(), HT.live())

def attenuate(state: H.State, revision: Nat) -> H.Change:
  H.bind_attenuate(state, revision, 2n, HT.reader(), HT.reader_caller(), HT.registry(), HT.read(), HT.live())

def delegate(state: H.State, revision: Nat) -> H.Change:
  H.delegate(state, revision, 2n, HT.reader(), HT.worker(), HT.read())

def close(state: H.State) -> H.Change:
  H.bind_close(state, 2n, 2n, HT.reader(), HT.reader_caller())

def revoke(state: H.State) -> H.Change:
  H.revoke(state, 2n, HT.reader())

def applied(change: H.Change, expected: H.State, id: Nat) -> Bool:
  match change:
    case H.Rejected{_, _}: False{}
    case H.Changed{+state, actual}: Nat.is_eq(actual, id) && HT.State.equal(state, expected) && H.valid(state)

# Expected fixtures name every changed graph field and the complete untouched
# original tail. Frontend states use independently exercised normal fixtures.
def expected_mint(+old: H.State, rev: Nat, next_object: Nat, next_alias: Nat,
    +object: Nat, +alias: Nat, kind: H.ObjectKind, parent: Nat, handle: Nat,
    quota: Nat, frontend: F.State) -> H.State:
  H.State{rev, next_object, next_alias,
    H.Objects{H.Object{object, 0n, HT.subject(), kind, parent, HT.service()}, H.objects(old)},
    H.Aliases{H.Alias{alias, HT.reader(), object, 0n}, H.aliases(old)}, H.routes(old), HT.quotas(quota),
    H.delegations(old), H.Bindings{H.Binding{object, handle}, H.bindings(old)}, frontend}

def expected_delegate(+last: Nat, max: Nat) -> H.State:
  H.State{3n, 3n, max, H.objects(HT.opened()),
    H.Aliases{H.Alias{last, HT.worker(), 2n, 0n}, H.aliases(HT.opened())},
    H.routes(HT.opened()), HT.quotas(3n),
    H.Delegations{H.Delegation{2n, HT.worker(), HT.read(), last}, H.NoDelegations{}},
    H.bindings(HT.opened()), H.frontend(HT.opened())}

def object_final_mount(+max: Nat) -> Bool:
  +last = Nat.sub(max, 1n)
  applied(mount(with_object(HT.initial(), last), 0n),
    expected_mint(HT.initial(), 1n, max, 2n, last, 1n, H.Session{}, 0n, 1n, 4n, H.frontend(HT.mounted())), 1n)

def alias_final_mount(+max: Nat) -> Bool:
  +last = Nat.sub(max, 1n)
  applied(mount(with_alias(HT.initial(), last), 0n),
    expected_mint(HT.initial(), 1n, 2n, max, 1n, last, H.Session{}, 0n, 1n, 4n, H.frontend(HT.mounted())), last)

def object_final_open(+max: Nat) -> Bool:
  +last = Nat.sub(max, 1n)
  applied(open(with_object(HT.mounted(), last), 1n),
    expected_mint(HT.mounted(), 2n, max, 3n, last, 2n, H.Descriptor{}, 1n, 2n, 3n, H.frontend(HT.opened())), 2n)

def alias_final_open(+max: Nat) -> Bool:
  +last = Nat.sub(max, 1n)
  applied(open(with_alias(HT.mounted(), last), 1n),
    expected_mint(HT.mounted(), 2n, 3n, max, 2n, last, H.Descriptor{}, 1n, 2n, 3n, H.frontend(HT.opened())), last)

def object_final_attenuate(+max: Nat) -> Bool:
  +last = Nat.sub(max, 1n)
  applied(attenuate(with_object(HT.opened(), last), 2n),
    expected_mint(HT.opened(), 3n, max, 4n, last, 3n, H.Descriptor{}, 2n, 3n, 2n, H.frontend(HT.attenuated())), 3n)

def alias_final_attenuate(+max: Nat) -> Bool:
  +last = Nat.sub(max, 1n)
  applied(attenuate(with_alias(HT.opened(), last), 2n),
    expected_mint(HT.opened(), 3n, 4n, max, 3n, last, H.Descriptor{}, 2n, 3n, 2n, H.frontend(HT.attenuated())), last)

def alias_final_delegate(+max: Nat) -> Bool:
  +last = Nat.sub(max, 1n)
  applied(delegate(with_alias(HT.opened(), last), 2n), expected_delegate(last, max), last)

def exhausted_mount(+max: Nat) -> Bool:
  +a = with_object(HT.initial(), max)
  +b = with_alias(HT.initial(), max)
  +c = with_ids(HT.initial(), max, max)
  HT.denied(mount(a, 0n), a, H.IdExhausted{}) && HT.denied(mount(b, 0n), b, H.IdExhausted{}) &&
    HT.denied(mount(c, 0n), c, H.IdExhausted{})

def exhausted_open(+max: Nat) -> Bool:
  +a = with_object(HT.mounted(), max)
  +b = with_alias(HT.mounted(), max)
  HT.denied(open(a, 1n), a, H.IdExhausted{}) && HT.denied(open(b, 1n), b, H.IdExhausted{})

def exhausted_attenuate(+max: Nat) -> Bool:
  +a = with_object(HT.opened(), max)
  +b = with_alias(HT.opened(), max)
  HT.denied(attenuate(a, 2n), a, H.IdExhausted{}) && HT.denied(attenuate(b, 2n), b, H.IdExhausted{})

def exhausted_delegate(+max: Nat) -> Bool:
  +s = with_alias(HT.opened(), max)
  HT.denied(delegate(s, 2n), s, H.IdExhausted{})

def stale_first(+max: Nat) -> Bool:
  +a = with_ids(HT.initial(), max, max)
  +b = with_ids(HT.mounted(), max, max)
  +c = with_ids(HT.opened(), max, max)
  HT.denied(mount(a, 1n), a, H.StaleRevision{}) && HT.denied(open(b, 0n), b, H.StaleRevision{}) &&
    HT.denied(attenuate(c, 1n), c, H.StaleRevision{}) && HT.denied(delegate(c, 1n), c, H.StaleRevision{})

def mount_route_first(+max: Nat) -> Bool:
  +s = with_ids(HT.initial(), max, max)
  HT.denied(H.bind_mount(s, 0n, HT.reader_other_route(), HT.caller(HT.other_subject()), HT.registry(), HT.all_rights(), HT.live()), s, H.RouteMismatch{})

def mount_quota_first(+max: Nat) -> Bool:
  +s = with_ids(HT.start(0n), max, max)
  HT.denied(mount(s, 0n), s, H.QuotaExhausted{})

def mount_frontend_first(+max: Nat) -> Bool:
  +s = with_ids(HT.initial(), max, max)
  HT.denied(H.bind_mount(s, 0n, HT.reader_route(), HT.reader_caller(), F.EmptyRegistry{}, HT.all_rights(), HT.live()), s, H.FrontendRejected{})

def derive_prior_gates(+max: Nat) -> Bool:
  +s = with_ids(HT.mounted(), max, max)
  +q = HT.with_quotas(s, HT.quotas(0n))
  HT.denied(H.bind_open(s, 1n, 99n, HT.reader(), HT.reader_caller(), HT.registry(), HT.read(), HT.live()), s, H.UnknownAlias{}) &&
    HT.denied(H.bind_open(s, 1n, 1n, HT.reader(), HT.reader_caller(), HT.registry(), HT.unknown_right(), HT.live()), s, H.WidenedRights{}) &&
    HT.denied(open(q, 1n), q, H.QuotaExhausted{})

def derive_frontend_first(+max: Nat) -> Bool:
  +opened = with_ids(HT.opened(), max, max)
  +mounted = with_ids(HT.mounted(), max, max)
  HT.denied(H.bind_open(opened, 2n, 2n, HT.reader(), HT.reader_caller(), HT.registry(), HT.read(), HT.live()), opened, H.FrontendRejected{}) &&
    HT.denied(H.bind_attenuate(mounted, 1n, 1n, HT.reader(), HT.reader_caller(), HT.registry(), HT.read(), HT.live()), mounted, H.FrontendRejected{}) &&
    HT.denied(H.bind_open(mounted, 1n, 1n, HT.reader(), HT.caller(HT.other_subject()), HT.registry(), HT.read(), HT.live()), mounted, H.FrontendRejected{})

def delegate_prior_gates(+max: Nat) -> Bool:
  +s = with_ids(HT.opened(), max, max)
  +different = HT.with_routes(s, HT.stranger_routes())
  HT.denied(H.delegate(s, 2n, 99n, HT.reader(), HT.worker(), HT.read()), s, H.UnknownAlias{}) &&
    HT.denied(H.delegate(s, 2n, 2n, HT.reader(), HT.worker(), HT.unknown_right()), s, H.WidenedRights{}) &&
    HT.denied(H.delegate(different, 2n, 2n, HT.reader(), HT.stranger(), HT.read()), different, H.SubjectMismatch{})

def stale_generation_first(+max: Nat) -> Bool:
  +s = with_ids(HT.generations(), max, max)
  HT.denied(H.bind_open(s, 1n, 2n, HT.reader(), HT.reader_caller(), HT.registry(), HT.read(), HT.live()), s, H.StaleGeneration{}) &&
    HT.denied(H.delegate(s, 1n, 2n, HT.reader(), HT.worker(), HT.read()), s, H.StaleGeneration{})

def original_graph_first(+max: Nat) -> Bool:
  +s = with_ids(HT.shared_handle(), max, max)
  Bool.not(H.valid(s)) && HT.denied(H.bind_open(s, 2n, 1n, HT.reader(), HT.reader_caller(), HT.registry(), HT.read(), HT.live()), s, H.StaleRevision{})

def object_max_delegate(+max: Nat) -> Bool:
  applied(delegate(with_object(HT.opened(), max), 2n), with_object(HT.shared(), max), 3n)

def close_both(+max: Nat) -> Bool:
  +s = with_ids(HT.opened(), max, max)
  +expected = with_ids(H.Change.state(close(HT.opened())), max, max)
  applied(close(s), expected, 2n)

def revoke_both(+max: Nat) -> Bool:
  +s = with_ids(HT.opened(), max, max)
  +expected = with_ids(H.Change.state(revoke(HT.opened())), max, max)
  applied(revoke(s), expected, HT.reader())

def resolution_both(+max: Nat) -> Bool:
  +s = with_ids(HT.opened(), max, max)
  H.valid(s) && HT.rights_are(H.resolve(s, 2n, HT.reader()), HT.all_rights())

def delegated_graph(+max: Nat) -> Bool:
  +s = H.Change.state(delegate(with_object(HT.opened(), max), 2n))
  H.valid(s) && HT.rights_are(H.resolve(s, 3n, HT.worker()), HT.read()) &&
    applied(H.revoke(s, 3n, HT.worker()), with_object(HT.delegatee_revoked(), max), HT.worker())

def run(+max: Nat) -> IO(Unit):
  do IO<Unit>:
    Test.check(H.Error.equal(H.IdExhausted{}, H.IdExhausted{}) && Bool.not(H.Error.equal(H.IdExhausted{}, H.QuotaExhausted{})), "host binding exhaustion reason is distinct")
    Test.check(object_final_mount(max), "host binding last object mount preserves full state")
    Test.check(alias_final_mount(max), "host binding last alias mount preserves full state")
    Test.check(object_final_open(max), "host binding last object open preserves full state")
    Test.check(alias_final_open(max), "host binding last alias open preserves full state")
    Test.check(object_final_attenuate(max), "host binding last object attenuation preserves full state")
    Test.check(alias_final_attenuate(max), "host binding last alias attenuation preserves full state")
    Test.check(alias_final_delegate(max), "host binding last alias delegation preserves full state")
    Test.check(exhausted_mount(max), "host binding exhausted object or alias rejects mount unchanged")
    HT.vector("GA-008-4", "bind_mount", HT.alias_outcome(mount(with_object(HT.initial(), max), 0n)))
    Test.check(exhausted_open(max), "host binding exhausted object or alias rejects open unchanged")
    Test.check(exhausted_attenuate(max), "host binding exhausted object or alias rejects attenuation unchanged")
    Test.check(exhausted_delegate(max), "host binding exhausted alias rejects delegation unchanged")
    Test.check(stale_first(max), "host binding stale revision precedes exhaustion")
    Test.check(mount_route_first(max), "host binding mount route denial precedes exhaustion")
    Test.check(mount_quota_first(max), "host binding mount quota denial precedes exhaustion")
    Test.check(mount_frontend_first(max), "host binding mount frontend denial precedes exhaustion")
    Test.check(derive_prior_gates(max), "host binding derive identity rights and quota precede exhaustion")
    Test.check(derive_frontend_first(max), "host binding derive frontend denial precedes exhaustion")
    Test.check(delegate_prior_gates(max), "host binding delegation identity and rights precede exhaustion")
    Test.check(stale_generation_first(max), "host binding stale generation precedes exhaustion")
    Test.check(original_graph_first(max), "host binding original graph validation precedes exhaustion")
    Test.check(object_max_delegate(max), "host binding object exhaustion does not deny delegation")
    Test.check(close_both(max), "host binding exhausted allocators preserve exact owner close")
    Test.check(revoke_both(max), "host binding exhausted allocators preserve exact revocation")
    Test.check(resolution_both(max), "host binding exhausted allocators preserve existing resolution")
    Test.check(delegated_graph(max), "host binding object exhaustion preserves delegation graph and revocation")
    IO.print("Host binding allocation boundary: 26 checks passed")

def parsed(value: Maybe<&2, Nat>) -> IO(Unit):
  match value:
    case None{}: IO.die(Unit, 1, "FAIL: host binding maximum parse")
    case Some{max}: run(max)

def main() -> IO(Unit):
  parsed(Nat.read("281474976710655"))
