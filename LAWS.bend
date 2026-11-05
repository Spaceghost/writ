import Base
import ./Guard.bend as Guard
import ./Ledger.bend as Ledger
import ./HostBinding.bend as HostBinding
import ./Issuance.bend as Issuance
import ./Transfer.bend as Transfer

# This theorem covers a failed check at ANY position in the commit guard.
# It does not assert that the caller has supplied authentic registry state.
law failed_check_denies:
  for before: Guard.Checks
  for after: Guard.Checks
  {Guard.all(Guard.append(before, Guard.Require{False{}, after})) == False{} : Bool}

# A denied guard selects the unchanged state, regardless of the proposal.
law denied_selects_original:
  for -A: Type
  for proposal: A
  for original: A
  {Guard.choose(A, False{}, proposal, original) == original : A}

law denied_ledger_preserves_state:
  for proposal: Ledger.State
  for original: Ledger.State
  for reason: Ledger.Error
  {Ledger.state(Ledger.result(False{}, proposal, original, reason)) == original : Ledger.State}

# A rejected host-binding change carries the supplied state unchanged, for any
# state and any closed-type reason. This holds by computation of the
# `Change.state` accessor; it is stated to fix the contract every HostBinding
# transition's denial path relies on (deny by returning `Rejected{state, r}`
# with the caller's own state). It does not assert that any transition chose
# the denial path, that the reason is the right one, or that an accepted
# change is valid; those are covered by HostBindingTests.
law binding_denied_preserves_state:
  for state: HostBinding.State
  for reason: HostBinding.Error
  {HostBinding.Change.state(HostBinding.Rejected{state, reason}) == state : HostBinding.State}

# Every natural number is strictly below its successor under `Nat.is_lt`.
# Auxiliary arithmetic fact for generation_bump_monotone; it says nothing about
# HostBinding by itself.
law nat_lt_successor:
  for n: Nat
  {Nat.is_lt(n, 1n+n) == True{} : Bool}

# Destroying an object (`HostBinding.bumped` with a true decision) leaves its
# generation strictly greater than before. This contributes to staleness: an
# alias recorded at the old generation no longer equals the bumped one. The
# full guarantee (such an alias never again matches) also needs that no
# transition ever lowers a generation, which is not stated here. Nor is the
# non-destroy branch (`bumped(False{}, o) == o`) stated, and the law does not
# assert that `destroy`, `bind_close`, or `revoke` select the right objects.
law generation_bump_monotone:
  for object: HostBinding.Object
  {Nat.is_lt(HostBinding.object_generation(object),
     HostBinding.object_generation(HostBinding.bumped(True{}, object))) == True{} : Bool}

# No natural number equals its successor under `Nat.is_eq`. Auxiliary
# arithmetic fact for the three issuance stale-revision laws; it says nothing about
# Issuance by itself.
law nat_eq_successor_false:
  for n: Nat
  {Nat.is_eq(n, 1n+n) == False{} : Bool}

# A registration whose expected revision is one past the state's revision
# never commits, for every state, request, time and token. This is the GI-005
# race: a registration validated at revision r cannot commit after any
# transition has moved the state to r+1. It relies on `register` matching on
# `revision_current` before any other gate. It covers the successor revision
# only (other stale revisions are denied by the same gate and shown by
# IssuanceTests), says nothing about the denial reason, and does not claim
# that the host installs accepted states atomically or serializes installs
# (AB-006).
law issuance_stale_revision_rejects:
  for state: Issuance.State
  for request: Issuance.Request
  for now: Nat
  for token: Transfer.CodeId
  {Issuance.Change.accepted(Issuance.register(state, 1n+Issuance.revision(state), request, now, token)) == False{} : Bool}

# A registration whose expected revision is one past the state's revision
# returns exactly the supplied state, for every request, time and token. So a
# registration raced by any transition that moved the state exposes no new
# state: no grant is stored and no approval consumed. The proof pins
# `register`'s outer `revision_current` match and that its Rejected branch
# carries the caller's state. It covers the successor revision only; state
# preservation on every other denial is tested (IssuanceTests' `denied`,
# with full state equality), not proved here.
law issuance_stale_registration_keeps_state:
  for state: Issuance.State
  for request: Issuance.Request
  for now: Nat
  for token: Transfer.CodeId
  {Issuance.Change.state(Issuance.register(state, 1n+Issuance.revision(state), request, now, token)) == state : Issuance.State}

# The same for revocation: a revocation whose expected revision is one past
# the state's returns exactly the supplied state, for every principal and
# approval id, so a raced revocation changes no flag and advances no
# revision. The proof pins `revoke`'s outer revision match and its Rejected
# branch. Successor revision only; other denials are tested, not proved. It
# does not claim the host serializes installs (AB-006).
law issuance_stale_revocation_keeps_state:
  for state: Issuance.State
  for from: Issuance.Principal
  for id: Nat
  {Issuance.Change.state(Issuance.revoke(state, 1n+Issuance.revision(state), from, id)) == state : Issuance.State}
