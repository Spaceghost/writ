import Base
import ./Guard.bend as Guard
import ./Ledger.bend as Ledger
import ./HostBinding.bend as HostBinding
import ./HostIdentity.bend as HostIdentity
import ./HostPrimitives.bend as HostPrimitives

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

# A rejected host-identity change carries the supplied state unchanged, for
# any state and any closed-type reason. This holds by computation of the
# `Change.state` accessor; it is stated to fix the contract every HostIdentity
# transition's denial path relies on (deny by returning `Rejected{state, r}`
# with the caller's own state). It does not assert that any transition chose
# the denial path, that the reason is the right one, or that an accepted
# change is valid; those are covered by HostIdentityTests.
law identity_denied_preserves_state:
  for state: HostIdentity.State
  for reason: HostIdentity.Error
  {HostIdentity.Change.state(HostIdentity.Rejected{state, reason}) == state : HostIdentity.State}

# A denied host-primitive step carries the supplied state unchanged, for any
# state and any closed-type reason. This holds by computation of the
# `Step.state` accessor; it is stated to fix the contract every HostPrimitives
# transition's denial path relies on (deny by returning `Denied{state, r}`
# with the caller's own state). It does not assert that any transition chose
# the denial path, that the reason is the right one, or that an admitted
# step is correct; those are covered by HostPrimitivesTests.
law primitive_denied_preserves_state:
  for state: HostPrimitives.State
  for reason: HostPrimitives.Error
  {HostPrimitives.Step.state(HostPrimitives.Denied{state, reason}) == state : HostPrimitives.State}

# A denied host-primitive step yields no effect, for any state and any
# closed-type reason: the effects a target binding may execute are exactly
# `Step.effects` of the transition's output, and for a denial that list is
# empty, so an effect exists only on an admitted transition. This holds by
# computation of the `Step.effects` accessor (`Denied` has no effects field).
# It does not assert which transitions deny, that a reason is the right one,
# or that an admitted step's effects are correct; HostPrimitivesTests covers
# those. That a binding executes only effects this monitor returned is a
# host obligation.
law primitive_denied_emits_nothing:
  for state: HostPrimitives.State
  for reason: HostPrimitives.Error
  {HostPrimitives.Step.effects(HostPrimitives.Denied{state, reason}) == [] : List<&2, HostPrimitives.Effect>}
