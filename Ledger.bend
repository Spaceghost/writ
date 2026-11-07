import Base

# Pure authoritative ledger model. The hosting monitor serializes transitions
# and persists the returned state before exposing their external effects.
# Nat counters and amounts do not wrap. Terminal revisions and refunds outside
# the supported Nat range are denied unchanged. No monetary or signature API is implied.
# Public state values are not authenticated account balances. expected_revision
# must match the monitor's current ledger, and the host must install an accepted
# result atomically. Replaying a stale snapshot cannot be prevented by pure data.
# Successful operations advance revision once; rejected operations retain old.
type Ids is Data:
  NoIds{}
  Id{id: Nat, rest: Ids}

type Account is Data:
  Account{principal: Nat, available: Nat}

type Accounts is Data:
  NoAccounts{}
  Accounts{head: Account, rest: Accounts}

type Hold is Data:
  Hold{receipt: Nat, invocation: Nat, payer: Nat, units: Nat, valid_until: Nat}

type Holds is Data:
  NoHolds{}
  Holds{head: Hold, rest: Holds}

type State is Data:
  State{revision: Nat, accounts: Accounts, holds: Holds, seen_receipts: Ids,
    committed_invocations: Ids}

# The present transition API returns AdmissionDenied for any failed gate.
# The other variants are vocabulary, not promised diagnostic classifications.
type Error is Data:
  StaleRevision{}
  InvalidAccount{}
  InsufficientFunds{}
  Replay{}
  MissingHold{}
  ScopeMismatch{}
  Expired{}
  NotExpired{}
  InvalidState{}
  AdmissionDenied{}

type Outcome is Data:
  Applied{state: State}
  Rejected{state: State, reason: Error}

type FoundAccount is Data:
  AccountFound{account: Account}
  AccountMissing{}

type FoundHold is Data:
  HoldFound{hold: Hold}
  HoldMissing{}

def contains(ids: Ids, +wanted: Nat) -> Bool:
  match ids:
    case NoIds{}:
      False{}
    case Id{id, rest}:
      Nat.is_eq(id, wanted) || contains(rest, wanted)

def account_find.select(found: Bool, account: Account, otherwise: FoundAccount) -> FoundAccount:
  match found:
    case True{}:
      AccountFound{account}
    case False{}:
      otherwise

# Structural recursion stays in the first argument; search results are data.
def account_find(accounts: Accounts, +wanted: Nat) -> FoundAccount:
  match accounts:
    case NoAccounts{}:
      AccountMissing{}
    case Accounts{Account{+principal, available}, rest}:
      account_find.select(Nat.is_eq(principal, wanted), Account{principal, available},
        account_find(rest, wanted))

def account_present(found: FoundAccount) -> Bool:
  match found:
    case AccountFound{_}:
      True{}
    case AccountMissing{}:
      False{}

def account_amount(found: FoundAccount) -> Nat:
  match found:
    case AccountFound{Account{_, available}}:
      available
    case AccountMissing{}:
      0n

def account_set.head(same: Bool, old: Account, wanted: Nat, amount: Nat) -> Account:
  match same:
    case True{}:
      Account{wanted, amount}
    case False{}:
      old

def account_set(accounts: Accounts, +wanted: Nat, +amount: Nat) -> Accounts:
  match accounts:
    case NoAccounts{}:
      NoAccounts{}
    case Accounts{Account{+principal, available}, rest}:
      Accounts{account_set.head(Nat.is_eq(principal, wanted),
        Account{principal, available}, wanted, amount), account_set(rest, wanted, amount)}

def accounts_valid(accounts: Accounts) -> Bool:
  match accounts:
    case NoAccounts{}:
      True{}
    case Accounts{Account{principal, _}, +rest}:
      Bool.not(account_present(account_find(rest, principal))) && accounts_valid(rest)

def hold_find.select(found: Bool, hold: Hold, otherwise: FoundHold) -> FoundHold:
  match found:
    case True{}:
      HoldFound{hold}
    case False{}:
      otherwise

def hold_find(holds: Holds, +receipt: Nat) -> FoundHold:
  match holds:
    case NoHolds{}:
      HoldMissing{}
    case Holds{Hold{+id, invocation, payer, units, until}, rest}:
      hold_find.select(Nat.is_eq(id, receipt), Hold{id, invocation, payer, units, until},
        hold_find(rest, receipt))

def hold_present(found: FoundHold) -> Bool:
  match found:
    case HoldFound{_}:
      True{}
    case HoldMissing{}:
      False{}

def invocation_held(holds: Holds, +invocation: Nat) -> Bool:
  match holds:
    case NoHolds{}:
      False{}
    case Holds{Hold{_, id, _, _, _}, rest}:
      Nat.is_eq(id, invocation) || invocation_held(rest, invocation)

def hold_remove.head(same: Bool, head: Hold, rest: Holds) -> Holds:
  match same:
    case True{}:
      rest
    case False{}:
      Holds{head, rest}

def hold_remove(holds: Holds, +receipt: Nat) -> Holds:
  match holds:
    case NoHolds{}:
      NoHolds{}
    case Holds{Hold{+id, invocation, payer, units, until}, rest}:
      hold_remove.head(Nat.is_eq(id, receipt), Hold{id, invocation, payer, units, until},
        hold_remove(rest, receipt))

def ids_valid(ids: Ids) -> Bool:
  match ids:
    case NoIds{}:
      True{}
    case Id{id, +rest}:
      Bool.not(contains(rest, id)) && ids_valid(rest)

def holds_valid(holds: Holds, +accounts: Accounts, +seen: Ids, +committed: Ids) -> Bool:
  match holds:
    case NoHolds{}:
      True{}
    case Holds{Hold{+receipt, +invocation, payer, _, _}, +rest}:
      Bool.not(hold_present(hold_find(rest, receipt))) &&
      Bool.not(invocation_held(rest, invocation)) &&
      account_present(account_find(accounts, payer)) && contains(seen, receipt) &&
      Bool.not(contains(committed, invocation)) && holds_valid(rest, accounts, seen, committed)

# Require unique accounts and replay IDs, one hold per receipt/invocation,
# a real payer for every hold, and no live hold for a committed invocation.
def valid(state: State) -> Bool:
  match state:
    case State{_, +accounts, holds, +seen, +committed}:
      accounts_valid(accounts) && ids_valid(seen) && ids_valid(committed) &&
      holds_valid(holds, accounts, seen, committed)

# next is provisional pure data; arithmetic used to construct it must be bounded
# even on rejection because backends may eagerly evaluate function arguments.
def result(allowed: Bool, next: State, old: State, reason: Error) -> Outcome:
  match allowed:
    case True{}:
      Applied{next}
    case False{}:
      Rejected{old, reason}

def accepted(answer: Outcome) -> Bool:
  match answer:
    case Applied{_}:
      True{}
    case Rejected{_, _}:
      False{}

def state(answer: Outcome) -> State:
  match answer:
    case Applied{value}:
      value
    case Rejected{value, _}:
      value

def revision(state: State) -> Nat:
  match state:
    case State{rev, _, _, _, _}:
      rev

def balance(state: State, principal: Nat) -> Nat:
  match state:
    case State{_, accounts, _, _, _}:
      account_amount(account_find(accounts, principal))

def empty(accounts: Accounts) -> State:
  State{0n, accounts, NoHolds{}, NoIds{}, NoIds{}}

# The pinned runtime supports Nat up to 2^48 - 1. The guarded wrappers return
# bounded provisional numbers, not authority. Exported .allowed implementation
# steps require the Boolean from the matching guard and supported Nat inputs.
def max_nat() -> Nat:
  Nat.add(Nat.mul(65536n, 4294967295n), 65535n)

def has_successor(rev: Nat) -> Bool:
  Nat.is_lt(rev, max_nat())

def bounded_successor.allowed(ok: Bool, rev: Nat) -> Nat:
  match ok:
    case True{}: 1n+rev
    case False{}: rev

def bounded_successor(+rev: Nat) -> Nat:
  bounded_successor.allowed(has_successor(rev), rev)

def add_fits(a: Nat, b: Nat) -> Bool:
  Nat.is_le(b, Nat.sub(max_nat(), a))

def bounded_add.allowed(ok: Bool, a: Nat, b: Nat) -> Nat:
  match ok:
    case True{}: Nat.add(a, b)
    case False{}: a

def bounded_add(+a: Nat, +b: Nat) -> Nat:
  bounded_add.allowed(add_fits(a, b), a, b)

# Receipt IDs are never recycled, including after cancellation. A reservation
# immediately removes the amount from the payer's available balance.
# It remains a hold, not a payment capture; now must be strictly before expiry.
# For example, reserving 30 from 100 leaves 70 available until commit or refund.
def reserve(+old: State, expected_revision: Nat, +hold: Hold, now: Nat) -> Outcome:
  match old hold:
    case State{+rev, +accounts, +holds, +seen, +committed}
      Hold{+receipt, +invocation, +payer, +units, until}:
      +found = account_find(accounts, payer)
      +amount = account_amount(found)
      ok = has_successor(rev) && valid(old) && Nat.is_eq(rev, expected_revision) &&
        account_present(found) && Nat.is_ge(amount, units) && Nat.is_lt(now, until) &&
        Bool.not(contains(seen, receipt)) && Bool.not(contains(committed, invocation)) &&
        Bool.not(invocation_held(holds, invocation))
      next = {State{bounded_successor(rev), account_set(accounts, payer, Nat.sub(amount, units)),
        Holds{hold, holds}, Id{receipt, seen}, committed} : State}
      result(ok, next, old, AdmissionDenied{})

def hold_matches(found: FoundHold, invocation: Nat, payer: Nat, units: Nat, now: Nat) -> Bool:
  match found:
    case HoldMissing{}:
      False{}
    case HoldFound{Hold{_, actual_invocation, actual_payer, actual_units, until}}:
      Nat.is_eq(actual_invocation, invocation) && Nat.is_eq(actual_payer, payer) &&
      Nat.is_eq(actual_units, units) && Nat.is_lt(now, until)

# Receipt, invocation, payer, and amount are rechecked at the single commit.
# The entire exact hold is consumed and invocation recorded against replay;
# available funds were already reduced at reserve, so there is no second debit.
# Partial captures and incremental sample charges are not implemented here.
def commit(+old: State, expected_revision: Nat, +receipt: Nat, +invocation: Nat,
  payer: Nat, units: Nat, now: Nat) -> Outcome:
  match old:
    case State{+rev, accounts, +holds, seen, +committed}:
      ok = has_successor(rev) && valid(old) && Nat.is_eq(rev, expected_revision) &&
        Bool.not(contains(committed, invocation)) &&
        hold_matches(hold_find(holds, receipt), invocation, payer, units, now)
      next = {State{bounded_successor(rev), accounts, hold_remove(holds, receipt), seen,
        Id{invocation, committed}} : State}
      result(ok, next, old, AdmissionDenied{})

def refund_fits(found: FoundHold, accounts: Accounts) -> Bool:
  match found:
    case HoldMissing{}:
      False{}
    case HoldFound{Hold{_, _, payer, units, _}}:
      add_fits(account_amount(account_find(accounts, payer)), units)

# This helper constructs a bounded provisional account list; the public
# transitions separately check the entire gate and refund_fits before applying.
def refund(found: FoundHold, +accounts: Accounts) -> Accounts:
  match found:
    case HoldMissing{}:
      accounts
    case HoldFound{Hold{_, _, +payer, units, _}}:
      account_set(accounts, payer, bounded_add(account_amount(account_find(accounts, payer)), units))

# Cancel a still-live exact hold and refund its full amount. The receipt stays
# in seen_receipts, so even a refunded receipt cannot be reserved again.
def cancel(+old: State, expected_revision: Nat, +receipt: Nat, +invocation: Nat,
  +payer: Nat, +units: Nat, now: Nat) -> Outcome:
  match old:
    case State{+rev, accounts, +holds, seen, committed}:
      +found = hold_find(holds, receipt)
      ok = has_successor(rev) && valid(old) && Nat.is_eq(rev, expected_revision) &&
        hold_matches(found, invocation, payer, units, now) && refund_fits(found, accounts)
      next = {State{bounded_successor(rev), refund(found, accounts), hold_remove(holds, receipt),
        seen, committed} : State}
      result(ok, next, old, AdmissionDenied{})

def hold_expired(found: FoundHold, now: Nat) -> Bool:
  match found:
    case HoldMissing{}:
      False{}
    case HoldFound{Hold{_, _, _, _, until}}:
      Nat.is_ge(now, until)

# At now >= valid_until, expiry replaces cancellation as the refund path.
# Removing the hold prevents a second refund while retaining its replay marker.
def expire(+old: State, expected_revision: Nat, +receipt: Nat, +now: Nat) -> Outcome:
  match old:
    case State{+rev, accounts, +holds, seen, committed}:
      +found = hold_find(holds, receipt)
      ok = has_successor(rev) && valid(old) && Nat.is_eq(rev, expected_revision) && hold_expired(found, now) && refund_fits(found, accounts)
      next = {State{bounded_successor(rev), refund(found, accounts), hold_remove(holds, receipt),
        seen, committed} : State}
      result(ok, next, old, AdmissionDenied{})
