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

def Laws.issuance_denied_preserves_state(state, reason):
  {==}

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
def Laws.issuance_stale_revision_rejects(state, request, now, token):
  match state:
    case Issuance.State{revision, next_id, live, directory, placements, approvals, grants, seen}:
      %Equal.sym(Bool, Nat.is_eq(revision, 1n+revision), False{}, Laws.nat_eq_successor_false(revision)) : {Issuance.Change.accepted(Issuance.register_current(_, Issuance.State{revision, next_id, live, directory, placements, approvals, grants, seen}, 1n+revision, request, now, token)) == False{} : Bool}
      {==}
