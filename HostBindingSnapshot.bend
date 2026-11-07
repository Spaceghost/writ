import Base
import ./FrontendLegacyConversion.bend as C
import ./HostBinding.bend as H

# Exact description only: no structural validity, authenticated state, caller,
# migration installation, replay fence, cleanup or host qualification claim.
# `check` is the intended entry. Every exported helper is descriptive, not an
# admission gate; direct calls with forged intermediate results prove nothing.
# Each of the six original and candidate binding lists is limited to eight
# constructors; the existing frontend checker has its own eight-handle and
# eight-source limits. Over-cap input is Incomplete, not an invalid snapshot.
type Candidate is Data:
  Candidate{revision: Nat, next_object: Nat, next_alias: Nat, objects: H.Objects,
    aliases: H.Aliases, routes: H.Routes, quotas: H.Quotas, delegations: H.Delegations,
    bindings: H.Bindings, frontend: C.Candidate}

type Comparison is Data:
  ExactDescription{}
  Mismatch{}
  Incomplete{}

def combine(a: Comparison, b: Comparison) -> Comparison:
  match a b:
    case Incomplete{} _: Incomplete{}
    case _ Incomplete{}: Incomplete{}
    case Mismatch{} _: Mismatch{}
    case _ Mismatch{}: Mismatch{}
    case ExactDescription{} ExactDescription{}: ExactDescription{}

def field(ok: Bool) -> Comparison:
  match ok:
    case True{}: ExactDescription{}
    case False{}: Mismatch{}

def same_kind(a: H.ObjectKind, b: H.ObjectKind) -> Bool:
  match a b:
    case H.Session{} H.Session{}: True{}
    case H.Descriptor{} H.Descriptor{}: True{}
    case H.ResultChannel{} H.ResultChannel{}: True{}
    case _ _: False{}

def same_object(a: H.Object, b: H.Object) -> Bool:
  match a b:
    case H.Object{a0, a1, a2, a3, a4, a5} H.Object{b0, b1, b2, b3, b4, b5}:
      Nat.is_eq(a0, b0) &&
        Nat.is_eq(a1, b1) &&
        Nat.is_eq(a2, b2) &&
        same_kind(a3, b3) &&
        Nat.is_eq(a4, b4) &&
        Nat.is_eq(a5, b5)

# Continue the surviving tail after a length mismatch, so a late over-cap
# constructor wins over Mismatch. Even forged excessive fuel is clamped.
def compare_objects(a: H.Objects, b: H.Objects, fuel: Nat) -> Comparison:
  match a b fuel:
    case H.NoObjects{} H.NoObjects{} _: ExactDescription{}
    case H.Objects{_, _} _ 0n: Incomplete{}
    case H.NoObjects{} H.Objects{_, _} 0n: Incomplete{}
    case H.Objects{ah, at} H.Objects{bh, bt} 1n+rest:
      combine(field(same_object(ah, bh)), compare_objects(at, bt, Nat.min(rest, 7n)))
    case H.Objects{_, at} H.NoObjects{} 1n+rest:
      combine(Mismatch{}, compare_objects(at, H.NoObjects{}, Nat.min(rest, 7n)))
    case H.NoObjects{} H.Objects{_, bt} 1n+rest:
      combine(Mismatch{}, compare_objects(H.NoObjects{}, bt, Nat.min(rest, 7n)))

def same_alias(a: H.Alias, b: H.Alias) -> Bool:
  match a b:
    case H.Alias{a0, a1, a2, a3} H.Alias{b0, b1, b2, b3}:
      Nat.is_eq(a0, b0) &&
        Nat.is_eq(a1, b1) &&
        Nat.is_eq(a2, b2) &&
        Nat.is_eq(a3, b3)

# Continue the surviving tail after a length mismatch, so a late over-cap
# constructor wins over Mismatch. Even forged excessive fuel is clamped.
def compare_aliases(a: H.Aliases, b: H.Aliases, fuel: Nat) -> Comparison:
  match a b fuel:
    case H.NoAliases{} H.NoAliases{} _: ExactDescription{}
    case H.Aliases{_, _} _ 0n: Incomplete{}
    case H.NoAliases{} H.Aliases{_, _} 0n: Incomplete{}
    case H.Aliases{ah, at} H.Aliases{bh, bt} 1n+rest:
      combine(field(same_alias(ah, bh)), compare_aliases(at, bt, Nat.min(rest, 7n)))
    case H.Aliases{_, at} H.NoAliases{} 1n+rest:
      combine(Mismatch{}, compare_aliases(at, H.NoAliases{}, Nat.min(rest, 7n)))
    case H.NoAliases{} H.Aliases{_, bt} 1n+rest:
      combine(Mismatch{}, compare_aliases(H.NoAliases{}, bt, Nat.min(rest, 7n)))

def same_route(a: H.Route, b: H.Route) -> Bool:
  match a b:
    case H.Route{a0, a1, a2, a3} H.Route{b0, b1, b2, b3}:
      Nat.is_eq(a0, b0) &&
        Nat.is_eq(a1, b1) &&
        Nat.is_eq(a2, b2) &&
        Nat.is_eq(a3, b3)

# Continue the surviving tail after a length mismatch, so a late over-cap
# constructor wins over Mismatch. Even forged excessive fuel is clamped.
def compare_routes(a: H.Routes, b: H.Routes, fuel: Nat) -> Comparison:
  match a b fuel:
    case H.NoRoutes{} H.NoRoutes{} _: ExactDescription{}
    case H.Routes{_, _} _ 0n: Incomplete{}
    case H.NoRoutes{} H.Routes{_, _} 0n: Incomplete{}
    case H.Routes{ah, at} H.Routes{bh, bt} 1n+rest:
      combine(field(same_route(ah, bh)), compare_routes(at, bt, Nat.min(rest, 7n)))
    case H.Routes{_, at} H.NoRoutes{} 1n+rest:
      combine(Mismatch{}, compare_routes(at, H.NoRoutes{}, Nat.min(rest, 7n)))
    case H.NoRoutes{} H.Routes{_, bt} 1n+rest:
      combine(Mismatch{}, compare_routes(H.NoRoutes{}, bt, Nat.min(rest, 7n)))

def same_quota(a: H.Quota, b: H.Quota) -> Bool:
  match a b:
    case H.Quota{a0, a1, a2} H.Quota{b0, b1, b2}:
      Nat.is_eq(a0, b0) &&
        Nat.is_eq(a1, b1) &&
        Nat.is_eq(a2, b2)

# Continue the surviving tail after a length mismatch, so a late over-cap
# constructor wins over Mismatch. Even forged excessive fuel is clamped.
def compare_quotas(a: H.Quotas, b: H.Quotas, fuel: Nat) -> Comparison:
  match a b fuel:
    case H.NoQuotas{} H.NoQuotas{} _: ExactDescription{}
    case H.Quotas{_, _} _ 0n: Incomplete{}
    case H.NoQuotas{} H.Quotas{_, _} 0n: Incomplete{}
    case H.Quotas{ah, at} H.Quotas{bh, bt} 1n+rest:
      combine(field(same_quota(ah, bh)), compare_quotas(at, bt, Nat.min(rest, 7n)))
    case H.Quotas{_, at} H.NoQuotas{} 1n+rest:
      combine(Mismatch{}, compare_quotas(at, H.NoQuotas{}, Nat.min(rest, 7n)))
    case H.NoQuotas{} H.Quotas{_, bt} 1n+rest:
      combine(Mismatch{}, compare_quotas(H.NoQuotas{}, bt, Nat.min(rest, 7n)))

def same_delegation(a: H.Delegation, b: H.Delegation) -> Bool:
  match a b:
    case H.Delegation{a0, a1, a2, a3} H.Delegation{b0, b1, b2, b3}:
      Nat.is_eq(a0, b0) &&
        Nat.is_eq(a1, b1) &&
        U32.is_eq(a2, b2) &&
        Nat.is_eq(a3, b3)

# Continue the surviving tail after a length mismatch, so a late over-cap
# constructor wins over Mismatch. Even forged excessive fuel is clamped.
def compare_delegations(a: H.Delegations, b: H.Delegations, fuel: Nat) -> Comparison:
  match a b fuel:
    case H.NoDelegations{} H.NoDelegations{} _: ExactDescription{}
    case H.Delegations{_, _} _ 0n: Incomplete{}
    case H.NoDelegations{} H.Delegations{_, _} 0n: Incomplete{}
    case H.Delegations{ah, at} H.Delegations{bh, bt} 1n+rest:
      combine(field(same_delegation(ah, bh)), compare_delegations(at, bt, Nat.min(rest, 7n)))
    case H.Delegations{_, at} H.NoDelegations{} 1n+rest:
      combine(Mismatch{}, compare_delegations(at, H.NoDelegations{}, Nat.min(rest, 7n)))
    case H.NoDelegations{} H.Delegations{_, bt} 1n+rest:
      combine(Mismatch{}, compare_delegations(H.NoDelegations{}, bt, Nat.min(rest, 7n)))

def same_binding(a: H.Binding, b: H.Binding) -> Bool:
  match a b:
    case H.Binding{a0, a1} H.Binding{b0, b1}:
      Nat.is_eq(a0, b0) &&
        Nat.is_eq(a1, b1)

# Continue the surviving tail after a length mismatch, so a late over-cap
# constructor wins over Mismatch. Even forged excessive fuel is clamped.
def compare_bindings(a: H.Bindings, b: H.Bindings, fuel: Nat) -> Comparison:
  match a b fuel:
    case H.NoBindings{} H.NoBindings{} _: ExactDescription{}
    case H.Bindings{_, _} _ 0n: Incomplete{}
    case H.NoBindings{} H.Bindings{_, _} 0n: Incomplete{}
    case H.Bindings{ah, at} H.Bindings{bh, bt} 1n+rest:
      combine(field(same_binding(ah, bh)), compare_bindings(at, bt, Nat.min(rest, 7n)))
    case H.Bindings{_, at} H.NoBindings{} 1n+rest:
      combine(Mismatch{}, compare_bindings(at, H.NoBindings{}, Nat.min(rest, 7n)))
    case H.NoBindings{} H.Bindings{_, bt} 1n+rest:
      combine(Mismatch{}, compare_bindings(H.NoBindings{}, bt, Nat.min(rest, 7n)))

def frontend_result(result: C.Check) -> Comparison:
  match result:
    case C.Exact{}: ExactDescription{}
    case C.Mismatch{}: Mismatch{}
    case C.Incomplete{}: Incomplete{}

# Each comparator independently visits both complete lists, even after a
# mismatch; Incomplete dominates Mismatch. No producer work list, supplied
# count or digest selects original records. C.check compares the frontend from
# its own original, within its separately documented profile; it can report
# Mismatch for an invalid original frontend even if the descriptions agree.
# ExactDescription never states that the whole HostBinding graph is valid.
def check(original: H.State, candidate: Candidate) -> Comparison:
  match original candidate:
    case H.State{ar, ano, ana, ao, aa, at, aq, ad, ab, af}
         Candidate{br, bno, bna, bo, ba, bt, bq, bd, bb, bf}:
      combine(field(Nat.is_eq(ar, br) && Nat.is_eq(ano, bno) && Nat.is_eq(ana, bna)),
        combine(compare_objects(ao, bo, 8n),
        combine(compare_aliases(aa, ba, 8n),
        combine(compare_routes(at, bt, 8n),
        combine(compare_quotas(aq, bq, 8n),
        combine(compare_delegations(ad, bd, 8n),
        combine(compare_bindings(ab, bb, 8n), frontend_result(C.check(af, bf)))))))))
