import Base
import ./Guard.bend as Guard
import ./LAWS.bend as Laws
import ./HostBinding.bend as HostBinding
import ./Issuance.bend as Issuance
import ./HostIdentity.bend as HostIdentity
import ./HostPrimitives.bend as HostPrimitives
import ./HostPublication.bend as HostPublication
import ./Rendezvous.bend as Rendezvous

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

def Laws.identity_denied_preserves_state(state, reason):
  {==}

def Laws.primitive_denied_preserves_state(state, reason):
  {==}

def Laws.primitive_denied_emits_nothing(state, reason):
  {==}

def Laws.publication_refused_preserves_state(state, session, ledger, reason):
  {==}

def Laws.publication_refused_emits_nothing(state, session, ledger, reason):
  {==}

# Induction on n: `Nat.cmp(1n+p, 1n+p)` reduces to `Nat.cmp(p, p)`.
def Laws.nat_lt_irreflexive(n):
  match n:
    case 0n:
      {==}
    case 1n+p:
      Laws.nat_lt_irreflexive(p)

# Induction on n, as nat_lt_irreflexive.
def Laws.nat_eq_reflexive(n):
  match n:
    case 0n:
      {==}
    case 1n+p:
      Laws.nat_eq_reflexive(p)

# Matching exposes the quote q, provider id p and serial s, so the goal is
# `is_lt(q, q) || (is_eq(q, q) && (is_lt(p, p) || (is_eq(p, p) && is_lt(s, s))))`.
# Rewriting each comparison of a value with itself (the strict ones to False,
# the ties to True) reduces it to False by computation of `||` and `&&`.
def Laws.offer_order_irreflexive(a):
  match a:
    case Rendezvous.Offer{version, Rendezvous.OfferId{+p, +s}, provider, grant, plan, profile, +q, valid_until}:
      %Equal.sym(Bool, Nat.is_lt(q, q), False{}, Laws.nat_lt_irreflexive(q)) : {Bool.or(_, Bool.and(Nat.is_eq(q, q), Bool.or(Nat.is_lt(p, p), Bool.and(Nat.is_eq(p, p), Nat.is_lt(s, s))))) == False{} : Bool}
      %Equal.sym(Bool, Nat.is_eq(q, q), True{}, Laws.nat_eq_reflexive(q)) : {Bool.and(_, Bool.or(Nat.is_lt(p, p), Bool.and(Nat.is_eq(p, p), Nat.is_lt(s, s)))) == False{} : Bool}
      %Equal.sym(Bool, Nat.is_lt(p, p), False{}, Laws.nat_lt_irreflexive(p)) : {Bool.or(_, Bool.and(Nat.is_eq(p, p), Nat.is_lt(s, s))) == False{} : Bool}
      %Equal.sym(Bool, Nat.is_eq(p, p), True{}, Laws.nat_eq_reflexive(p)) : {Bool.and(_, Nat.is_lt(s, s)) == False{} : Bool}
      Laws.nat_lt_irreflexive(s)

# Induction on before_list. Base: the left side unfolds to
# `keep_if(eligible(o, state, snapshot), o, eligible_offers(rest, ..))`;
# rewriting the scrutinee with the hypothesis (reversed) selects the skip
# branch, which is the right side. Step: both sides unfold to
# `keep_if(eligible(head, ..), head, eligible_offers(append(tail, ..), ..))`
# and differ only in the inner list, which the induction hypothesis equates.
def Laws.rendezvous_ineligible_offer_dropped(before_list, o, rest, state, snapshot, ineligible):
  match before_list:
    case Rendezvous.NoOffers{}:
      %Equal.sym(Bool, Rendezvous.eligible(o, state, snapshot), False{}, ineligible) : {Rendezvous.keep_if(_, o, Rendezvous.eligible_offers(rest, state, snapshot)) == Rendezvous.eligible_offers(rest, state, snapshot) : Rendezvous.Offers}
      {==}
    case Rendezvous.Offers{head, tail}:
      %Laws.rendezvous_ineligible_offer_dropped(tail, o, rest, state, snapshot, ineligible) : {Rendezvous.keep_if(Rendezvous.eligible(head, state, snapshot), head, Rendezvous.eligible_offers(Rendezvous.Offers.append(tail, Rendezvous.Offers{o, rest}), state, snapshot)) == Rendezvous.keep_if(Rendezvous.eligible(head, state, snapshot), head, _) : Rendezvous.Offers}
      {==}

# As issuance_stale_registration_keeps_state: matching exposes the revision
# field, so `select` unfolds to `select_current(Nat.is_eq(revision,
# 1n+revision), ...)`. Rewriting that scrutinee to False{} with
# nat_eq_successor_false (reversed) selects `Rejected{state, StaleRevision{}}`,
# whose `accepted` is False{} and whose `Change.state` is the matched state.
def Laws.rendezvous_stale_selection_keeps_state(state, session, expected_session, n_context, snapshot):
  match state:
    case Rendezvous.State{revision, next_id, request, constraint, offers, approvals, selection, retired, evidence, dispatched, seen}:
      %Equal.sym(Bool, Nat.is_eq(revision, 1n+revision), False{}, Laws.nat_eq_successor_false(revision)) : {(Rendezvous.Change.accepted(Rendezvous.select_current(_, Rendezvous.State{revision, next_id, request, constraint, offers, approvals, selection, retired, evidence, dispatched, seen}, session, expected_session, n_context, snapshot)), Rendezvous.Change.state(Rendezvous.select_current(_, Rendezvous.State{revision, next_id, request, constraint, offers, approvals, selection, retired, evidence, dispatched, seen}, session, expected_session, n_context, snapshot))) == (False{}, Rendezvous.State{revision, next_id, request, constraint, offers, approvals, selection, retired, evidence, dispatched, seen}) : Bool & Rendezvous.State}
      {==}
