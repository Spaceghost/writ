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

# A natural number plus a positive amount is never at most the original under
# `Nat.is_le`. Auxiliary arithmetic fact for derived_lifetime_extension_rejects
# (every lifetime strictly past `u` is `Nat.add(u, 1n+extra)` for some
# `extra`); it says nothing about Issuance by itself.
law nat_le_add_successor_false:
  for u: Nat
  for extra: Nat
  {Nat.is_le(Nat.add(u, 1n+extra), u) == False{} : Bool}

# GI-006, lifetime half: a derivation whose requested lifetime is strictly
# past its parent's never commits and returns exactly the supplied state, for
# every state, expected revision, principal, version, rights, time and token,
# whenever the parent id resolves in that state to the parent record whose
# lifetime it exceeds (`found`, the same lookup `derive` performs). So a
# derived grant can never extend its parent's expiry, by any amount, and the
# attempt stores no grant. The proof pins `derive`'s parent lookup and its
# outer `lifetime_within` match with its Rejected branch. It does not cover
# rights (U32 masks are not inductive; rights attenuation is tested, not
# proved), scope or subject (a Derivation cannot express either), the denial
# reason (a stale revision still reads StaleRevision), or the per-use
# re-check of the chain in `current`, which the tests show.
law derived_lifetime_extension_rejects:
  for state: Issuance.State
  for expected_revision: Nat
  for from: Issuance.Principal
  for parent_id: Nat
  for parent: Issuance.Grant
  for found: {Issuance.find_grant(Issuance.grants(state), parent_id) == Some{parent} : Maybe<&2, Issuance.Grant>}
  for version: Nat
  for rights: U32
  for extra: Nat
  for now: Nat
  for token: Transfer.CodeId
  {(Issuance.Change.accepted(Issuance.derive(state, expected_revision, from, parent_id, Issuance.Derivation{version, rights, Nat.add(Issuance.Grant.valid_until(parent), 1n+extra)}, now, token)), Issuance.Change.state(Issuance.derive(state, expected_revision, from, parent_id, Issuance.Derivation{version, rights, Nat.add(Issuance.Grant.valid_until(parent), 1n+extra)}, now, token))) == (False{}, state) : Bool & Issuance.State}
