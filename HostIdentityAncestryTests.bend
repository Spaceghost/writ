import Base
import ./HostIdentity.bend as I
import ./HostIdentityTests.bend as IT
import ./Test.bend as Test

# Synthetic tables only. The reference is the previous finite-fuel definition,
# retained here as an oracle for small values; it has no optimized stop.
def reference(fuel: Nat, +entries: I.Entries, +slot: Nat, +target: Nat) -> Bool:
  match fuel:
    case 0n: Nat.is_eq(slot, target)
    case 1n+rest:
      Nat.is_eq(slot, target) || reference(rest, entries, I.parent_of(entries, slot), target)

def entry(slot: Nat, parent: Nat) -> I.Entry:
  I.Entry{slot, 1n, IT.session_a(), IT.caller_a(), IT.handle_a(), IT.plan(),
    IT.root_rights(), IT.root_expires(), parent, True{}}

def graph(a: Nat, b: Nat, c: Nat) -> I.Entries:
  I.Entries{entry(0n, a), I.Entries{entry(1n, b), I.Entries{entry(2n, c), I.NoEntries{}}}}

def targets(+n: Nat, +fuel: Nat, +entries: I.Entries, +slot: Nat) -> Bool:
  match n:
    case 0n: IT.bool_equal(I.under(fuel, entries, slot, 0n), reference(fuel, entries, slot, 0n))
    case 1n+rest:
      IT.bool_equal(I.under(fuel, entries, slot, n), reference(fuel, entries, slot, n))
        && targets(rest, fuel, entries, slot)

def slots(+n: Nat, +fuel: Nat, +entries: I.Entries) -> Bool:
  match n:
    case 0n: targets(3n, fuel, entries, 0n)
    case 1n+rest: targets(3n, fuel, entries, n) && slots(rest, fuel, entries)

def fuels(+n: Nat, +entries: I.Entries) -> Bool:
  match n:
    case 0n: slots(3n, 0n, entries)
    case 1n+rest: slots(3n, n, entries) && fuels(rest, entries)

def parents_c(+n: Nat, +a: Nat, +b: Nat) -> Bool:
  match n:
    case 0n: fuels(6n, graph(a, b, 0n))
    case 1n+rest: fuels(6n, graph(a, b, n)) && parents_c(rest, a, b)

def parents_b(+n: Nat, +a: Nat) -> Bool:
  match n:
    case 0n: parents_c(3n, a, 0n)
    case 1n+rest: parents_c(3n, a, n) && parents_b(rest, a)

def parents_a(+n: Nat) -> Bool:
  match n:
    case 0n: parents_b(3n, 0n)
    case 1n+rest: parents_b(3n, n) && parents_a(rest)

def duplicate_graph() -> I.Entries:
  I.Entries{entry(0n, 1n), I.Entries{entry(0n, 2n), I.Entries{entry(1n, 2n), I.NoEntries{}}}}

def finite_equivalence() -> Bool:
  parents_a(3n) && fuels(6n, I.NoEntries{}) && fuels(6n, duplicate_graph())

# Explicit malformed cycles and slot-0 outgoing edge pin the semantic cases
# that an unconditional sentinel stop would get wrong.
def edge_cases() -> Bool:
  +zero_out = graph(1n, 2n, 2n)
  +cycle = graph(0n, 2n, 1n)
  I.under(0n, zero_out, 0n, 0n) && Bool.not(I.under(0n, zero_out, 0n, 1n))
    && I.under(1n, zero_out, 0n, 1n) && I.under(2n, zero_out, 0n, 2n)
    && I.under(1n, cycle, 1n, 2n) && Bool.not(I.under(7n, cycle, 1n, 3n))
    && I.under(7n, I.NoEntries{}, 2n, 0n)

# A valid sparse state may have a very large allocation watermark despite only
# a few entries. Retirement must still cascade and leave the unrelated root.
def sparse_retirement(+max: Nat) -> Bool:
  +chain = IT.chain()
  +sparse = IT.with_entries(chain, max, I.entries(chain))
  +retired = IT.retired_root()
  +expected = IT.with_entries(retired, max, I.entries(retired))
  +change = I.retire(sparse, I.revision(sparse), IT.root_slot())
  I.valid(sparse) && IT.accepted_with(change, IT.root_slot())
    && IT.state_equal(I.Change.state(change), expected)
    && I.valid(I.Change.state(change))

def high_fuel(+max: Nat) -> Bool:
  Bool.not(I.under(max, I.NoEntries{}, 0n, 2n)) && I.under(max, I.NoEntries{}, 0n, 0n)
    && Bool.not(I.under(max, graph(0n, 1n, 2n), 1n, 2n))
    && sparse_retirement(max)

def from_max(parsed: Maybe<&2, Nat>) -> Bool:
  match parsed:
    case Some{max}: high_fuel(max)
    case None{}: False{}

def main() -> IO(Unit):
  do IO<Unit>:
    Test.check(finite_equivalence(), "PH-004 ancestry: finite exhaustive graphs match the previous definition")
    Test.check(edge_cases(), "PH-004 ancestry: zero, missing, self and multi-node cycles preserve semantics")
    Test.check(from_max(Nat.read("281474976710655")), "PH-004 ancestry: maximum-fuel fixed points and sparse valid retirement terminate")
    IO.print("HostIdentityAncestry: 3 checks passed")
