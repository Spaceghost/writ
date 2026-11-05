import Base
import ./Guard.bend as Guard
import ./LAWS.bend as Laws
import ./HostBinding.bend as HostBinding
import ./Issuance.bend as Issuance

def Laws.failed_check_denies(before, after):
  match before:
    case Guard.End{}:
      {==}
    case Guard.Require{condition, rest}:
      match condition:
        case False{}:
          {==}
        case True{}:
          Laws.failed_check_denies(rest, after)

def Laws.denied_selects_original(A, proposal, original):
  {==}

def Laws.denied_ledger_preserves_state(proposal, original, reason):
  {==}

def Laws.binding_denied_preserves_state(state, reason):
  {==}

# Induction on n: `Nat.cmp(1n+p, 2n+p)` reduces to `Nat.cmp(p, 1n+p)`, so the
# step case is the hypothesis itself.
def Laws.nat_lt_successor(n):
  match n:
    case 0n:
      {==}
    case 1n+p:
      Laws.nat_lt_successor(p)

# Matching exposes the generation field, after which the goal is
# nat_lt_successor at that generation.
def Laws.generation_bump_monotone(object):
  match object:
    case HostBinding.Object{id, generation, owner, kind, derived_from, service}:
      Laws.nat_lt_successor(generation)

# Induction on n: `Nat.cmp(1n+p, 2n+p)` reduces to `Nat.cmp(p, 1n+p)`, so the
# step case is the hypothesis itself.
def Laws.nat_eq_successor_false(n):
  match n:
    case 0n:
      {==}
    case 1n+p:
      Laws.nat_eq_successor_false(p)

# Matching exposes the revision field, so `register` unfolds to
# `register_current(Nat.is_eq(revision, 1n+revision), ...)`. Rewriting that
# scrutinee to False{} with nat_eq_successor_false (reversed by Equal.sym)
# selects the `Rejected` branch, whose `accepted` is False{} by computation.
def Laws.issuance_stale_revision_rejects(state, from, request, now, token):
  match state:
    case Issuance.State{revision, next_id, live, directory, placements, approvals, grants, seen}:
      %Equal.sym(Bool, Nat.is_eq(revision, 1n+revision), False{}, Laws.nat_eq_successor_false(revision)) : {Issuance.Change.accepted(Issuance.register_current(_, Issuance.State{revision, next_id, live, directory, placements, approvals, grants, seen}, 1n+revision, from, request, now, token)) == False{} : Bool}
      {==}

# As issuance_stale_revision_rejects: after the rewrite `register_current`
# takes its False{} branch, `Rejected{state, StaleRevision{}}`, whose
# `Change.state` is the matched state by computation.
def Laws.issuance_stale_registration_keeps_state(state, from, request, now, token):
  match state:
    case Issuance.State{revision, next_id, live, directory, placements, approvals, grants, seen}:
      %Equal.sym(Bool, Nat.is_eq(revision, 1n+revision), False{}, Laws.nat_eq_successor_false(revision)) : {Issuance.Change.state(Issuance.register_current(_, Issuance.State{revision, next_id, live, directory, placements, approvals, grants, seen}, 1n+revision, from, request, now, token)) == Issuance.State{revision, next_id, live, directory, placements, approvals, grants, seen} : Issuance.State}
      {==}

# The same argument through `revoke_current`.
def Laws.issuance_stale_revocation_keeps_state(state, from, id):
  match state:
    case Issuance.State{revision, next_id, live, directory, placements, approvals, grants, seen}:
      %Equal.sym(Bool, Nat.is_eq(revision, 1n+revision), False{}, Laws.nat_eq_successor_false(revision)) : {Issuance.Change.state(Issuance.revoke_current(_, Issuance.State{revision, next_id, live, directory, placements, approvals, grants, seen}, 1n+revision, from, id)) == Issuance.State{revision, next_id, live, directory, placements, approvals, grants, seen} : Issuance.State}
      {==}

# Induction on u. Base: `Nat.add(0n, 1n+extra)` is `1n+extra`, and
# `Nat.cmp(1n+extra, 0n)` is GT. Step: `Nat.add(1n+p, 1n+extra)` is
# `1n+Nat.add(p, 1n+extra)`, so the comparison with `1n+p` reduces to the
# hypothesis at p.
def Laws.nat_le_add_successor_false(u, extra):
  match u:
    case 0n:
      {==}
    case 1n+p:
      Laws.nat_le_add_successor_false(p, extra)

# `derive` unfolds to `derive_found(find_grant(grants(state), parent_id), ...)`.
# The first rewrite (found, reversed) replaces that lookup by `Some{parent}`,
# so `derive_found` reduces to `derive_bounded(lifetime_within(Nat.add(v,
# 1n+extra), v), ...)` with v the parent's valid_until. The second rewrite
# (nat_le_add_successor_false, reversed) turns that scrutinee into False{},
# selecting `Rejected{state, _}`, whose `accepted` is False{} and whose
# `Change.state` is the supplied state by computation.
def Laws.derived_lifetime_extension_rejects(state, expected_revision, from, parent_id, parent, found, version, rights, extra, now, token):
  %Equal.sym(Maybe<&2, Issuance.Grant>, Issuance.find_grant(Issuance.grants(state), parent_id), Some{parent}, found) : {(Issuance.Change.accepted(Issuance.derive_found(_, state, expected_revision, from, parent_id, Issuance.Derivation{version, rights, Nat.add(Issuance.Grant.valid_until(parent), 1n+extra)}, now, token)), Issuance.Change.state(Issuance.derive_found(_, state, expected_revision, from, parent_id, Issuance.Derivation{version, rights, Nat.add(Issuance.Grant.valid_until(parent), 1n+extra)}, now, token))) == (False{}, state) : Bool & Issuance.State}
  %Equal.sym(Bool, Nat.is_le(Nat.add(Issuance.Grant.valid_until(parent), 1n+extra), Issuance.Grant.valid_until(parent)), False{}, Laws.nat_le_add_successor_false(Issuance.Grant.valid_until(parent), extra)) : {(Issuance.Change.accepted(Issuance.derive_bounded(_, parent, state, expected_revision, from, parent_id, Issuance.Derivation{version, rights, Nat.add(Issuance.Grant.valid_until(parent), 1n+extra)}, now, token)), Issuance.Change.state(Issuance.derive_bounded(_, parent, state, expected_revision, from, parent_id, Issuance.Derivation{version, rights, Nat.add(Issuance.Grant.valid_until(parent), 1n+extra)}, now, token))) == (False{}, state) : Bool & Issuance.State}
  {==}
