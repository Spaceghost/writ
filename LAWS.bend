import Base
import ./Guard.bend as Guard
import ./Ledger.bend as Ledger

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
