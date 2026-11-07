import Base
import ./Transfer.bend as T
import ./Frontend.bend as F
import ./FrontendRevisionV2.bend as R
import ./FrontendLegacyConversion.bend as C
import ./HostBinding.bend as H
import ./HostBindingSnapshot.bend as S
import ./Test.bend as Test

# Fixed synthetic records. They do not represent an authenticated host.
def plan() -> T.Plan:
  T.Plan{T.Stamp{10n, 20n, 30n}, 40n, T.OCons{T.ObjectVersion{50n, 51n}, T.OEnd{}},
    T.ObjectVersion{60n, 61n}, T.CodeId{1, 2, 3, 4, 5, 6, 7, 8}, T.Copy{}, 1}

def handle(id: Nat, kind: F.HandleKind, closed: Bool) -> F.Handle:
  F.Handle{id, kind, 7n, T.CodeId{11, 12, 13, 14, 15, 16, 17, 18}, plan(), 7, 30n, 10n, closed}

def handles() -> F.Handles:
  F.Handles{handle(1n, F.Mounted{}, False{}), F.Handles{handle(2n, F.Descriptor{}, False{}),
    F.Handles{handle(3n, F.Descriptor{}, True{}), F.NoHandles{}}}}

def frontend() -> F.State:
  F.State{C.max_nat(), 4n, handles()}

def many_sources(n: Nat) -> T.Objects:
  match n:
    case 0n: T.OEnd{}
    case 1n+rest: T.OCons{T.ObjectVersion{50n, 51n}, many_sources(rest)}

def long_source_handle() -> F.Handle:
  F.Handle{1n, F.Mounted{}, 7n, T.CodeId{11, 12, 13, 14, 15, 16, 17, 18},
    T.Plan{T.Stamp{10n, 20n, 30n}, 40n, many_sources(9n), T.ObjectVersion{60n, 61n},
      T.CodeId{1, 2, 3, 4, 5, 6, 7, 8}, T.Copy{}, 1}, 7, 30n, 10n, False{}}

def many_handles(+n: Nat) -> F.Handles:
  match n:
    case 0n: F.NoHandles{}
    case 1n+rest: F.Handles{handle(n, F.Descriptor{}, False{}), many_handles(rest)}

def converted_frontend() -> C.Candidate:
  C.Candidate{R.V2{65535, 4294967295}, 4n, handles()}

def objects() -> H.Objects:
  H.Objects{H.Object{1n, 5n, 7n, H.Session{}, 0n, 4n},
    H.Objects{H.Object{2n, 9n, 7n, H.Descriptor{}, 1n, 4n},
      H.Objects{H.Object{3n, 3n, 7n, H.Descriptor{}, 2n, 4n}, H.NoObjects{}}}}

def aliases() -> H.Aliases:
  H.Aliases{H.Alias{1n, 7n, 1n, 5n}, H.Aliases{H.Alias{2n, 8n, 1n, 5n},
    H.Aliases{H.Alias{3n, 8n, 2n, 9n}, H.Aliases{H.Alias{4n, 9n, 3n, 2n}, H.NoAliases{}}}}}

def routes() -> H.Routes:
  H.Routes{H.Route{1n, 7n, 4n, 7n}, H.Routes{H.Route{2n, 8n, 4n, 7n}, H.NoRoutes{}}}

def quotas() -> H.Quotas:
  H.Quotas{H.Quota{7n, 100n, 4n}, H.Quotas{H.Quota{8n, 80n, 3n}, H.NoQuotas{}}}

def delegations() -> H.Delegations:
  H.Delegations{H.Delegation{1n, 8n, 1, 2n}, H.Delegations{H.Delegation{2n, 8n, 1, 3n},
    H.Delegations{H.Delegation{3n, 9n, 1, 4n}, H.NoDelegations{}}}}

def bindings() -> H.Bindings:
  H.Bindings{H.Binding{1n, 1n}, H.Bindings{H.Binding{2n, 2n}, H.Bindings{H.Binding{3n, 3n}, H.NoBindings{}}}}

def original() -> H.State:
  H.State{18n, 4n, 5n, objects(), aliases(), routes(), quotas(), delegations(), bindings(), frontend()}

def original_frontend(state: H.State, new: F.State) -> H.State:
  match state:
    case H.State{a, b, c, d, e, f, g, h, i, _}: H.State{a, b, c, d, e, f, g, h, i, new}

def candidate() -> S.Candidate:
  S.Candidate{18n, 4n, 5n, objects(), aliases(), routes(), quotas(), delegations(), bindings(), converted_frontend()}

def exact(result: S.Comparison) -> Bool:
  match result:
    case S.ExactDescription{}: True{}
    case _: False{}

def mismatch(result: S.Comparison) -> Bool:
  match result:
    case S.Mismatch{}: True{}
    case _: False{}

def incomplete(result: S.Comparison) -> Bool:
  match result:
    case S.Incomplete{}: True{}
    case _: False{}

def candidate_revision(candidate: S.Candidate, new: Nat) -> S.Candidate:
  match candidate:
    case S.Candidate{a0, a1, a2, a3, a4, a5, a6, a7, a8, a9}: S.Candidate{new, a1, a2, a3, a4, a5, a6, a7, a8, a9}

def candidate_next_object(candidate: S.Candidate, new: Nat) -> S.Candidate:
  match candidate:
    case S.Candidate{a0, a1, a2, a3, a4, a5, a6, a7, a8, a9}: S.Candidate{a0, new, a2, a3, a4, a5, a6, a7, a8, a9}

def candidate_next_alias(candidate: S.Candidate, new: Nat) -> S.Candidate:
  match candidate:
    case S.Candidate{a0, a1, a2, a3, a4, a5, a6, a7, a8, a9}: S.Candidate{a0, a1, new, a3, a4, a5, a6, a7, a8, a9}

def candidate_objects(candidate: S.Candidate, new: H.Objects) -> S.Candidate:
  match candidate:
    case S.Candidate{a0, a1, a2, a3, a4, a5, a6, a7, a8, a9}: S.Candidate{a0, a1, a2, new, a4, a5, a6, a7, a8, a9}

def candidate_aliases(candidate: S.Candidate, new: H.Aliases) -> S.Candidate:
  match candidate:
    case S.Candidate{a0, a1, a2, a3, a4, a5, a6, a7, a8, a9}: S.Candidate{a0, a1, a2, a3, new, a5, a6, a7, a8, a9}

def candidate_routes(candidate: S.Candidate, new: H.Routes) -> S.Candidate:
  match candidate:
    case S.Candidate{a0, a1, a2, a3, a4, a5, a6, a7, a8, a9}: S.Candidate{a0, a1, a2, a3, a4, new, a6, a7, a8, a9}

def candidate_quotas(candidate: S.Candidate, new: H.Quotas) -> S.Candidate:
  match candidate:
    case S.Candidate{a0, a1, a2, a3, a4, a5, a6, a7, a8, a9}: S.Candidate{a0, a1, a2, a3, a4, a5, new, a7, a8, a9}

def candidate_delegations(candidate: S.Candidate, new: H.Delegations) -> S.Candidate:
  match candidate:
    case S.Candidate{a0, a1, a2, a3, a4, a5, a6, a7, a8, a9}: S.Candidate{a0, a1, a2, a3, a4, a5, a6, new, a8, a9}

def candidate_bindings(candidate: S.Candidate, new: H.Bindings) -> S.Candidate:
  match candidate:
    case S.Candidate{a0, a1, a2, a3, a4, a5, a6, a7, a8, a9}: S.Candidate{a0, a1, a2, a3, a4, a5, a6, a7, new, a9}

def candidate_frontend(candidate: S.Candidate, new: C.Candidate) -> S.Candidate:
  match candidate:
    case S.Candidate{a0, a1, a2, a3, a4, a5, a6, a7, a8, a9}: S.Candidate{a0, a1, a2, a3, a4, a5, a6, a7, a8, new}

def original_objects(state: H.State, new: H.Objects) -> H.State:
  match state:
    case H.State{a0, a1, a2, a3, a4, a5, a6, a7, a8, a9}: H.State{a0, a1, a2, new, a4, a5, a6, a7, a8, a9}

def original_aliases(state: H.State, new: H.Aliases) -> H.State:
  match state:
    case H.State{a0, a1, a2, a3, a4, a5, a6, a7, a8, a9}: H.State{a0, a1, a2, a3, new, a5, a6, a7, a8, a9}

def original_routes(state: H.State, new: H.Routes) -> H.State:
  match state:
    case H.State{a0, a1, a2, a3, a4, a5, a6, a7, a8, a9}: H.State{a0, a1, a2, a3, a4, new, a6, a7, a8, a9}

def original_quotas(state: H.State, new: H.Quotas) -> H.State:
  match state:
    case H.State{a0, a1, a2, a3, a4, a5, a6, a7, a8, a9}: H.State{a0, a1, a2, a3, a4, a5, new, a7, a8, a9}

def original_delegations(state: H.State, new: H.Delegations) -> H.State:
  match state:
    case H.State{a0, a1, a2, a3, a4, a5, a6, a7, a8, a9}: H.State{a0, a1, a2, a3, a4, a5, a6, new, a8, a9}

def original_bindings(state: H.State, new: H.Bindings) -> H.State:
  match state:
    case H.State{a0, a1, a2, a3, a4, a5, a6, a7, a8, a9}: H.State{a0, a1, a2, a3, a4, a5, a6, a7, new, a9}

def many_objects(n: Nat) -> H.Objects:
  match n:
    case 0n: H.NoObjects{}
    case 1n+rest: H.Objects{H.Object{1n, 5n, 7n, H.Session{}, 0n, 4n}, many_objects(rest)}

def changed_objects_on(items: H.Objects, item: H.Object) -> Bool:
  match items:
    case H.Objects{_, tail}: mismatch(S.check(original(), candidate_objects(candidate(), H.Objects{item, tail})))
    case _: False{}

def changed_objects(item: H.Object) -> Bool:
  changed_objects_on(objects(), item)

def many_aliases(n: Nat) -> H.Aliases:
  match n:
    case 0n: H.NoAliases{}
    case 1n+rest: H.Aliases{H.Alias{1n, 7n, 1n, 5n}, many_aliases(rest)}

def changed_aliases_on(items: H.Aliases, item: H.Alias) -> Bool:
  match items:
    case H.Aliases{_, tail}: mismatch(S.check(original(), candidate_aliases(candidate(), H.Aliases{item, tail})))
    case _: False{}

def changed_aliases(item: H.Alias) -> Bool:
  changed_aliases_on(aliases(), item)

def many_routes(n: Nat) -> H.Routes:
  match n:
    case 0n: H.NoRoutes{}
    case 1n+rest: H.Routes{H.Route{1n, 7n, 4n, 7n}, many_routes(rest)}

def changed_routes_on(items: H.Routes, item: H.Route) -> Bool:
  match items:
    case H.Routes{_, tail}: mismatch(S.check(original(), candidate_routes(candidate(), H.Routes{item, tail})))
    case _: False{}

def changed_routes(item: H.Route) -> Bool:
  changed_routes_on(routes(), item)

def many_quotas(n: Nat) -> H.Quotas:
  match n:
    case 0n: H.NoQuotas{}
    case 1n+rest: H.Quotas{H.Quota{7n, 100n, 4n}, many_quotas(rest)}

def changed_quotas_on(items: H.Quotas, item: H.Quota) -> Bool:
  match items:
    case H.Quotas{_, tail}: mismatch(S.check(original(), candidate_quotas(candidate(), H.Quotas{item, tail})))
    case _: False{}

def changed_quotas(item: H.Quota) -> Bool:
  changed_quotas_on(quotas(), item)

def many_delegations(n: Nat) -> H.Delegations:
  match n:
    case 0n: H.NoDelegations{}
    case 1n+rest: H.Delegations{H.Delegation{1n, 8n, 1, 2n}, many_delegations(rest)}

def changed_delegations_on(items: H.Delegations, item: H.Delegation) -> Bool:
  match items:
    case H.Delegations{_, tail}: mismatch(S.check(original(), candidate_delegations(candidate(), H.Delegations{item, tail})))
    case _: False{}

def changed_delegations(item: H.Delegation) -> Bool:
  changed_delegations_on(delegations(), item)

def many_bindings(n: Nat) -> H.Bindings:
  match n:
    case 0n: H.NoBindings{}
    case 1n+rest: H.Bindings{H.Binding{1n, 1n}, many_bindings(rest)}

def changed_bindings_on(items: H.Bindings, item: H.Binding) -> Bool:
  match items:
    case H.Bindings{_, tail}: mismatch(S.check(original(), candidate_bindings(candidate(), H.Bindings{item, tail})))
    case _: False{}

def changed_bindings(item: H.Binding) -> Bool:
  changed_bindings_on(bindings(), item)

def field_tests() -> IO(Unit):
  do IO<Unit>:
    Test.check(mismatch(S.check(original(), candidate_revision(candidate(), 19n))), "snapshot binding revision tamper")
    Test.check(mismatch(S.check(original(), candidate_next_object(candidate(), 5n))), "snapshot next object watermark tamper")
    Test.check(mismatch(S.check(original(), candidate_next_alias(candidate(), 6n))), "snapshot next alias watermark tamper")
    Test.check(changed_objects(H.Object{2n, 5n, 7n, H.Session{}, 0n, 4n}), "snapshot object id tamper")
    Test.check(changed_objects(H.Object{1n, 6n, 7n, H.Session{}, 0n, 4n}), "snapshot object generation tamper")
    Test.check(changed_objects(H.Object{1n, 5n, 8n, H.Session{}, 0n, 4n}), "snapshot object owner tamper")
    Test.check(changed_objects(H.Object{1n, 5n, 7n, H.Descriptor{}, 0n, 4n}), "snapshot object kind descriptor tamper")
    Test.check(changed_objects(H.Object{1n, 5n, 7n, H.ResultChannel{}, 0n, 4n}), "snapshot object kind result channel tamper")
    Test.check(changed_objects(H.Object{1n, 5n, 7n, H.Session{}, 1n, 4n}), "snapshot object derivation parent tamper")
    Test.check(changed_objects(H.Object{1n, 5n, 7n, H.Session{}, 0n, 5n}), "snapshot object service tamper")
    Test.check(changed_aliases(H.Alias{2n, 7n, 1n, 5n}), "snapshot alias id tamper")
    Test.check(changed_aliases(H.Alias{1n, 8n, 1n, 5n}), "snapshot alias holder tamper")
    Test.check(changed_aliases(H.Alias{1n, 7n, 2n, 5n}), "snapshot alias object tamper")
    Test.check(changed_aliases(H.Alias{1n, 7n, 1n, 6n}), "snapshot alias generation tamper")
    Test.check(changed_routes(H.Route{2n, 7n, 4n, 7n}), "snapshot route parent tamper")
    Test.check(changed_routes(H.Route{1n, 8n, 4n, 7n}), "snapshot route child tamper")
    Test.check(changed_routes(H.Route{1n, 7n, 5n, 7n}), "snapshot route service tamper")
    Test.check(changed_routes(H.Route{1n, 7n, 4n, 8n}), "snapshot route subject tamper")
    Test.check(changed_quotas(H.Quota{8n, 100n, 4n}), "snapshot quota domain tamper")
    Test.check(changed_quotas(H.Quota{7n, 101n, 4n}), "snapshot quota ram tamper")
    Test.check(changed_quotas(H.Quota{7n, 100n, 5n}), "snapshot quota caps tamper")
    Test.check(changed_delegations(H.Delegation{2n, 8n, 1, 2n}), "snapshot delegation source tamper")
    Test.check(changed_delegations(H.Delegation{1n, 9n, 1, 2n}), "snapshot delegation holder tamper")
    Test.check(changed_delegations(H.Delegation{1n, 8n, 2, 2n}), "snapshot delegation rights tamper")
    Test.check(changed_delegations(H.Delegation{1n, 8n, 1, 3n}), "snapshot delegation child tamper")
    Test.check(changed_bindings(H.Binding{2n, 1n}), "snapshot binding object tamper")
    Test.check(changed_bindings(H.Binding{1n, 2n}), "snapshot binding handle tamper")

def bounds_tests() -> IO(Unit):
  do IO<Unit>:
    Test.check(incomplete(S.compare_objects(many_objects(9n), H.NoObjects{}, 1000n)), "snapshot objects original over-cap unmatched tail")
    Test.check(incomplete(S.compare_objects(H.NoObjects{}, many_objects(9n), 1000n)), "snapshot objects candidate over-cap unmatched tail")
    Test.check(incomplete(S.compare_objects(many_objects(64n), many_objects(64n), 1000n)), "snapshot objects forged fuel remains capped")
    Test.check(incomplete(S.check(original_objects(original(), many_objects(9n)), candidate())), "snapshot objects oversized original incomplete")
    Test.check(incomplete(S.check(original(), candidate_objects(candidate(), many_objects(9n)))), "snapshot objects oversized candidate incomplete")
    Test.check(incomplete(S.compare_aliases(many_aliases(9n), H.NoAliases{}, 1000n)), "snapshot aliases original over-cap unmatched tail")
    Test.check(incomplete(S.compare_aliases(H.NoAliases{}, many_aliases(9n), 1000n)), "snapshot aliases candidate over-cap unmatched tail")
    Test.check(incomplete(S.compare_aliases(many_aliases(64n), many_aliases(64n), 1000n)), "snapshot aliases forged fuel remains capped")
    Test.check(incomplete(S.check(original_aliases(original(), many_aliases(9n)), candidate())), "snapshot aliases oversized original incomplete")
    Test.check(incomplete(S.check(original(), candidate_aliases(candidate(), many_aliases(9n)))), "snapshot aliases oversized candidate incomplete")
    Test.check(incomplete(S.compare_routes(many_routes(9n), H.NoRoutes{}, 1000n)), "snapshot routes original over-cap unmatched tail")
    Test.check(incomplete(S.compare_routes(H.NoRoutes{}, many_routes(9n), 1000n)), "snapshot routes candidate over-cap unmatched tail")
    Test.check(incomplete(S.compare_routes(many_routes(64n), many_routes(64n), 1000n)), "snapshot routes forged fuel remains capped")
    Test.check(incomplete(S.check(original_routes(original(), many_routes(9n)), candidate())), "snapshot routes oversized original incomplete")
    Test.check(incomplete(S.check(original(), candidate_routes(candidate(), many_routes(9n)))), "snapshot routes oversized candidate incomplete")
    Test.check(incomplete(S.compare_quotas(many_quotas(9n), H.NoQuotas{}, 1000n)), "snapshot quotas original over-cap unmatched tail")
    Test.check(incomplete(S.compare_quotas(H.NoQuotas{}, many_quotas(9n), 1000n)), "snapshot quotas candidate over-cap unmatched tail")
    Test.check(incomplete(S.compare_quotas(many_quotas(64n), many_quotas(64n), 1000n)), "snapshot quotas forged fuel remains capped")
    Test.check(incomplete(S.check(original_quotas(original(), many_quotas(9n)), candidate())), "snapshot quotas oversized original incomplete")
    Test.check(incomplete(S.check(original(), candidate_quotas(candidate(), many_quotas(9n)))), "snapshot quotas oversized candidate incomplete")
    Test.check(incomplete(S.compare_delegations(many_delegations(9n), H.NoDelegations{}, 1000n)), "snapshot delegations original over-cap unmatched tail")
    Test.check(incomplete(S.compare_delegations(H.NoDelegations{}, many_delegations(9n), 1000n)), "snapshot delegations candidate over-cap unmatched tail")
    Test.check(incomplete(S.compare_delegations(many_delegations(64n), many_delegations(64n), 1000n)), "snapshot delegations forged fuel remains capped")
    Test.check(incomplete(S.check(original_delegations(original(), many_delegations(9n)), candidate())), "snapshot delegations oversized original incomplete")
    Test.check(incomplete(S.check(original(), candidate_delegations(candidate(), many_delegations(9n)))), "snapshot delegations oversized candidate incomplete")
    Test.check(incomplete(S.compare_bindings(many_bindings(9n), H.NoBindings{}, 1000n)), "snapshot bindings original over-cap unmatched tail")
    Test.check(incomplete(S.compare_bindings(H.NoBindings{}, many_bindings(9n), 1000n)), "snapshot bindings candidate over-cap unmatched tail")
    Test.check(incomplete(S.compare_bindings(many_bindings(64n), many_bindings(64n), 1000n)), "snapshot bindings forged fuel remains capped")
    Test.check(incomplete(S.check(original_bindings(original(), many_bindings(9n)), candidate())), "snapshot bindings oversized original incomplete")
    Test.check(incomplete(S.check(original(), candidate_bindings(candidate(), many_bindings(9n)))), "snapshot bindings oversized candidate incomplete")
    Test.check(incomplete(S.check(original(), candidate_routes(candidate_revision(candidate(), 19n), many_routes(9n)))), "snapshot scalar mismatch cannot hide oversized later list")
    Test.check(incomplete(S.compare_objects(H.Objects{H.Object{9n, 5n, 7n, H.Session{}, 0n, 4n}, many_objects(8n)}, many_objects(9n), 8n)), "snapshot head mismatch cannot hide oversized tail")
    Test.check(incomplete(S.compare_objects(many_objects(1n), many_objects(9n), 8n)), "snapshot unequal lengths cannot hide oversized tail")

def duplicate_objects(items: H.Objects) -> H.Objects:
  match items:
    case H.NoObjects{}: H.NoObjects{}
    case H.Objects{+head, tail}: H.Objects{head, H.Objects{head, tail}}

def swap_objects_tail(head: H.Object, tail: H.Objects) -> H.Objects:
  match tail:
    case H.NoObjects{}: H.Objects{head, H.NoObjects{}}
    case H.Objects{second, rest}: H.Objects{second, H.Objects{head, rest}}

def swap_objects(items: H.Objects) -> H.Objects:
  match items:
    case H.NoObjects{}: H.NoObjects{}
    case H.Objects{head, tail}: swap_objects_tail(head, tail)

def duplicate_aliases(items: H.Aliases) -> H.Aliases:
  match items:
    case H.NoAliases{}: H.NoAliases{}
    case H.Aliases{+head, tail}: H.Aliases{head, H.Aliases{head, tail}}

def swap_aliases_tail(head: H.Alias, tail: H.Aliases) -> H.Aliases:
  match tail:
    case H.NoAliases{}: H.Aliases{head, H.NoAliases{}}
    case H.Aliases{second, rest}: H.Aliases{second, H.Aliases{head, rest}}

def swap_aliases(items: H.Aliases) -> H.Aliases:
  match items:
    case H.NoAliases{}: H.NoAliases{}
    case H.Aliases{head, tail}: swap_aliases_tail(head, tail)

def duplicate_routes(items: H.Routes) -> H.Routes:
  match items:
    case H.NoRoutes{}: H.NoRoutes{}
    case H.Routes{+head, tail}: H.Routes{head, H.Routes{head, tail}}

def swap_routes_tail(head: H.Route, tail: H.Routes) -> H.Routes:
  match tail:
    case H.NoRoutes{}: H.Routes{head, H.NoRoutes{}}
    case H.Routes{second, rest}: H.Routes{second, H.Routes{head, rest}}

def swap_routes(items: H.Routes) -> H.Routes:
  match items:
    case H.NoRoutes{}: H.NoRoutes{}
    case H.Routes{head, tail}: swap_routes_tail(head, tail)

def duplicate_quotas(items: H.Quotas) -> H.Quotas:
  match items:
    case H.NoQuotas{}: H.NoQuotas{}
    case H.Quotas{+head, tail}: H.Quotas{head, H.Quotas{head, tail}}

def swap_quotas_tail(head: H.Quota, tail: H.Quotas) -> H.Quotas:
  match tail:
    case H.NoQuotas{}: H.Quotas{head, H.NoQuotas{}}
    case H.Quotas{second, rest}: H.Quotas{second, H.Quotas{head, rest}}

def swap_quotas(items: H.Quotas) -> H.Quotas:
  match items:
    case H.NoQuotas{}: H.NoQuotas{}
    case H.Quotas{head, tail}: swap_quotas_tail(head, tail)

def duplicate_delegations(items: H.Delegations) -> H.Delegations:
  match items:
    case H.NoDelegations{}: H.NoDelegations{}
    case H.Delegations{+head, tail}: H.Delegations{head, H.Delegations{head, tail}}

def swap_delegations_tail(head: H.Delegation, tail: H.Delegations) -> H.Delegations:
  match tail:
    case H.NoDelegations{}: H.Delegations{head, H.NoDelegations{}}
    case H.Delegations{second, rest}: H.Delegations{second, H.Delegations{head, rest}}

def swap_delegations(items: H.Delegations) -> H.Delegations:
  match items:
    case H.NoDelegations{}: H.NoDelegations{}
    case H.Delegations{head, tail}: swap_delegations_tail(head, tail)

def duplicate_bindings(items: H.Bindings) -> H.Bindings:
  match items:
    case H.NoBindings{}: H.NoBindings{}
    case H.Bindings{+head, tail}: H.Bindings{head, H.Bindings{head, tail}}

def swap_bindings_tail(head: H.Binding, tail: H.Bindings) -> H.Bindings:
  match tail:
    case H.NoBindings{}: H.Bindings{head, H.NoBindings{}}
    case H.Bindings{second, rest}: H.Bindings{second, H.Bindings{head, rest}}

def swap_bindings(items: H.Bindings) -> H.Bindings:
  match items:
    case H.NoBindings{}: H.NoBindings{}
    case H.Bindings{head, tail}: swap_bindings_tail(head, tail)

def history_tests() -> IO(Unit):
  do IO<Unit>:
    Test.check(H.valid(original()), "snapshot nonempty original fixture is structurally valid")
    Test.check(mismatch(S.check(original(), candidate_objects(candidate(), duplicate_objects(objects())))), "snapshot duplicate objects record differs")
    Test.check(mismatch(S.check(original(), candidate_objects(candidate(), swap_objects(objects())))), "snapshot reordered objects history differs")
    Test.check(exact(S.compare_objects(many_objects(8n), many_objects(8n), 1000n)), "snapshot objects exact eight records fit")
    Test.check(mismatch(S.check(original(), candidate_aliases(candidate(), duplicate_aliases(aliases())))), "snapshot duplicate aliases record differs")
    Test.check(mismatch(S.check(original(), candidate_aliases(candidate(), swap_aliases(aliases())))), "snapshot reordered aliases history differs")
    Test.check(exact(S.compare_aliases(many_aliases(8n), many_aliases(8n), 1000n)), "snapshot aliases exact eight records fit")
    Test.check(mismatch(S.check(original(), candidate_routes(candidate(), duplicate_routes(routes())))), "snapshot duplicate routes record differs")
    Test.check(mismatch(S.check(original(), candidate_routes(candidate(), swap_routes(routes())))), "snapshot reordered routes history differs")
    Test.check(exact(S.compare_routes(many_routes(8n), many_routes(8n), 1000n)), "snapshot routes exact eight records fit")
    Test.check(mismatch(S.check(original(), candidate_quotas(candidate(), duplicate_quotas(quotas())))), "snapshot duplicate quotas record differs")
    Test.check(mismatch(S.check(original(), candidate_quotas(candidate(), swap_quotas(quotas())))), "snapshot reordered quotas history differs")
    Test.check(exact(S.compare_quotas(many_quotas(8n), many_quotas(8n), 1000n)), "snapshot quotas exact eight records fit")
    Test.check(mismatch(S.check(original(), candidate_delegations(candidate(), duplicate_delegations(delegations())))), "snapshot duplicate delegations record differs")
    Test.check(mismatch(S.check(original(), candidate_delegations(candidate(), swap_delegations(delegations())))), "snapshot reordered delegations history differs")
    Test.check(exact(S.compare_delegations(many_delegations(8n), many_delegations(8n), 1000n)), "snapshot delegations exact eight records fit")
    Test.check(mismatch(S.check(original(), candidate_bindings(candidate(), duplicate_bindings(bindings())))), "snapshot duplicate bindings record differs")
    Test.check(mismatch(S.check(original(), candidate_bindings(candidate(), swap_bindings(bindings())))), "snapshot reordered bindings history differs")
    Test.check(exact(S.compare_bindings(many_bindings(8n), many_bindings(8n), 1000n)), "snapshot bindings exact eight records fit")
    Test.check(exact(S.check(original(), candidate())), "snapshot valid history including stale and closed records preserved")
    Test.check(mismatch(S.check(original(), candidate_objects(candidate(), H.NoObjects{}))), "snapshot omitted object history differs")
    Test.check(mismatch(S.check(original(), candidate_aliases(candidate(), H.NoAliases{}))), "snapshot omitted alias history differs")
    Test.check(mismatch(S.check(original(), candidate_routes(candidate(), H.NoRoutes{}))), "snapshot omitted route history differs")
    Test.check(mismatch(S.check(original(), candidate_quotas(candidate(), H.NoQuotas{}))), "snapshot omitted quota history differs")
    Test.check(mismatch(S.check(original(), candidate_delegations(candidate(), H.NoDelegations{}))), "snapshot omitted delegation history differs")
    Test.check(mismatch(S.check(original(), candidate_bindings(candidate(), H.NoBindings{}))), "snapshot omitted binding history differs")
    Test.check(mismatch(S.check(original(), candidate_bindings(candidate(), H.Bindings{H.Binding{2n, 2n}, H.Bindings{H.Binding{1n, 1n}, H.Bindings{H.Binding{3n, 3n}, H.NoBindings{}}}}))), "snapshot reordered binding edge differs")
    Test.check(mismatch(S.check(original(), candidate_bindings(candidate(), H.Bindings{H.Binding{1n, 1n}, bindings()}))), "snapshot duplicate binding differs")
    Test.check(mismatch(S.check(original(), candidate_frontend(candidate(), C.Candidate{R.V2{65536, 4294967295}, 4n, handles()}))), "snapshot frontend high word mismatch propagates")
    Test.check(mismatch(S.check(original(), candidate_frontend(candidate(), C.Candidate{R.V2{65535, 4294967295}, 3n, handles()}))), "snapshot frontend watermark mismatch propagates")
    Test.check(incomplete(S.check(original_frontend(original(), F.State{C.max_nat(), 20n, many_handles(9n)}), candidate())), "snapshot oversized original frontend propagates incomplete")
    Test.check(incomplete(S.check(original(), candidate_frontend(candidate(), C.Candidate{R.V2{65535, 4294967295}, 20n, many_handles(9n)}))), "snapshot oversized candidate frontend propagates incomplete")
    Test.check(incomplete(S.check(original_frontend(original(), F.State{C.max_nat(), 4n, F.Handles{long_source_handle(), F.NoHandles{}}}), candidate())), "snapshot oversized original plan sources propagate incomplete")
    Test.check(incomplete(S.check(original(), candidate_frontend(candidate(), C.Candidate{R.V2{65535, 4294967295}, 4n, F.Handles{long_source_handle(), F.NoHandles{}}}))), "snapshot oversized candidate plan sources propagate incomplete")
    Test.check(mismatch(S.check(original_frontend(original(), F.State{C.max_nat(), 0n, F.NoHandles{}}), candidate_frontend(candidate(), C.Candidate{R.V2{65535, 4294967295}, 0n, F.NoHandles{}}))), "snapshot identical invalid original frontend is mismatch")
    Test.check(Bool.not(H.valid(original_bindings(original(), duplicate_bindings(bindings())))), "snapshot duplicate original binding fixture is invalid")
    Test.check(exact(S.check(original_bindings(original(), duplicate_bindings(bindings())), candidate_bindings(candidate(), duplicate_bindings(bindings())))), "snapshot identical invalid binding graph is description only")
    Test.check(mismatch(S.check(original(), candidate_aliases(candidate(), H.Aliases{H.Alias{1n, 7n, 1n, 5n}, H.Aliases{H.Alias{2n, 8n, 1n, 5n}, H.Aliases{H.Alias{3n, 8n, 2n, 9n}, H.Aliases{H.Alias{4n, 9n, 3n, 3n}, H.NoAliases{}}}}}))), "snapshot late stale alias generation differs")
    Test.check(mismatch(S.check(original(), candidate_bindings(candidate(), H.Bindings{H.Binding{1n, 1n}, H.Bindings{H.Binding{2n, 2n}, H.Bindings{H.Binding{3n, 2n}, H.NoBindings{}}}}))), "snapshot late closed handle binding differs")
    Test.check(mismatch(S.check(original(), candidate_objects(candidate(), H.Objects{H.Object{1n, 5n, 7n, H.Session{}, 0n, 4n}, H.Objects{H.Object{2n, 9n, 7n, H.Descriptor{}, 1n, 4n}, H.Objects{H.Object{3n, 3n, 7n, H.Descriptor{}, 1n, 4n}, H.NoObjects{}}}}))), "snapshot late transitive object parent differs")
    Test.check(mismatch(S.check(original(), candidate_delegations(candidate(), H.Delegations{H.Delegation{1n, 8n, 1, 2n}, H.Delegations{H.Delegation{2n, 8n, 1, 3n}, H.Delegations{H.Delegation{2n, 9n, 1, 4n}, H.NoDelegations{}}}}))), "snapshot late transitive delegation parent differs")
    Test.check(mismatch(S.check(original_objects(original(), swap_objects(objects())), candidate())), "snapshot original object ordering independently checked")
    Test.check(mismatch(S.check(original_aliases(original(), swap_aliases(aliases())), candidate())), "snapshot original alias ordering independently checked")
    Test.check(mismatch(S.check(original_routes(original(), swap_routes(routes())), candidate())), "snapshot original route ordering independently checked")
    Test.check(mismatch(S.check(original_quotas(original(), swap_quotas(quotas())), candidate())), "snapshot original quota ordering independently checked")
    Test.check(mismatch(S.check(original_delegations(original(), swap_delegations(delegations())), candidate())), "snapshot original delegation ordering independently checked")
    Test.check(mismatch(S.check(original_bindings(original(), swap_bindings(bindings())), candidate())), "snapshot original binding ordering independently checked")
    Test.check(exact(S.field(True{})), "snapshot forged helper result is descriptive only")
    Test.check(exact(S.combine(S.ExactDescription{}, S.ExactDescription{})), "snapshot forged combined result is descriptive only")
    Test.check(incomplete(S.combine(S.Mismatch{}, S.Incomplete{})), "snapshot incomplete dominates earlier mismatch")
    Test.check(exact(S.check(original_routes(original(), H.Routes{H.Route{1n, 1n, 1n, 1n}, H.NoRoutes{}}), candidate_routes(candidate(), H.Routes{H.Route{1n, 1n, 1n, 1n}, H.NoRoutes{}}))), "snapshot identical altered route is description only")

def main() -> IO(Unit):
  do IO<Unit>:
    field_tests()
    bounds_tests()
    history_tests()
