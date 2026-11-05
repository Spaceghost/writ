import Base
import ./Guard.bend as Guard
import ./LAWS.bend as Laws
import ./HostBinding.bend as HostBinding
import ./HostIdentity.bend as HostIdentity
import ./HostPrimitives.bend as HostPrimitives
import ./HostPublication.bend as HostPublication

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
