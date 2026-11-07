import Base
import ./Frontend.bend as F
import ./FrontendRevisionV2.bend as R

# Descriptive arithmetic over supplied records only. The monitor must still
# authenticate the complete current state, caller, version and resource budget;
# no result here permits a mutation, proves a cleanup or installs a migration.
# `inspect` is the intended entry. All other exported names are implementation
# helpers, not authority or admission gates. This synthetic profile inspects at
# most eight original handles; a larger list is incomplete, not invalid.
type Count is Data:
  Counted{open: U32}
  CountIncomplete{}

type Assessment is Data:
  Measured{open: U32, active_capacity: Bool, allocation_capacity: Bool,
    attenuation_capacity: Bool, close_capacity: Bool, retirement_capacity: Bool}
  Incomplete{}
  UnsupportedRevision{}

# Literal cases prevent wrap even if an exported helper is called directly
# with a forged count. Counts outside the fixed profile are incomplete.
def keep_count(open: U32) -> Count:
  match open:
    case 0: Counted{0}
    case 1: Counted{1}
    case 2: Counted{2}
    case 3: Counted{3}
    case 4: Counted{4}
    case 5: Counted{5}
    case 6: Counted{6}
    case 7: Counted{7}
    case 8: Counted{8}
    case _: CountIncomplete{}

def one_more(open: U32) -> Count:
  match open:
    case 0: Counted{1}
    case 1: Counted{2}
    case 2: Counted{3}
    case 3: Counted{4}
    case 4: Counted{5}
    case 5: Counted{6}
    case 6: Counted{7}
    case 7: Counted{8}
    case _: CountIncomplete{}

def count_step(closed: Bool, rest: Count) -> Count:
  match closed rest:
    case _ CountIncomplete{}: CountIncomplete{}
    case True{} Counted{open}: keep_count(open)
    case False{} Counted{open}: one_more(open)

# The scan consumes at most cap+1 original constructors, even when an exported
# helper is called with excessive fuel. Only the closed flag affects counting:
# an expired or revoked open handle still needs its reserved cleanup.
def scan(handles: F.Handles, fuel: Nat) -> Count:
  match handles fuel:
    case F.NoHandles{} _: Counted{0}
    case F.Handles{_, _} 0n: CountIncomplete{}
    case F.Handles{F.Handle{_, _, _, _, _, _, _, _, closed}, tail} 1n+rest:
      count_step(closed, scan(tail, Nat.min(rest, 7n)))

# D = (2^64-1) - R is the word-wise bitwise complement of the two words of R.
# required is a U32, so a nonzero high word of D always suffices. This helper
# does no addition, subtraction, narrowing, or caller-supplied guard selection.
def enough(remaining_high: U32, remaining_low: U32, required: U32) -> Bool:
  U32.is_ne(remaining_high, 0) || U32.is_ge(remaining_low, required)

def active_cost(open: U32) -> U32:
  U32.add(U32.and(open, 15), 1)

def attenuation_cost(open: U32) -> U32:
  U32.add(U32.and(open, 15), 2)

def allocation_cost(open: U32) -> U32:
  U32.add(U32.and(open, 15), 3)

def capacity(+open: U32, +remaining_high: U32, +remaining_low: U32) -> Assessment:
  # Mask before addition even on direct forged helper calls; an out-of-range
  # count makes every capacity flag false. No caller selects thresholds.
  +bounded_open = U32.and(open, 15)
  +within = U32.is_eq(open, bounded_open) && U32.is_le(bounded_open, 8)
  +base = within && enough(remaining_high, remaining_low, active_cost(open))
  Measured{open, base, within && enough(remaining_high, remaining_low, allocation_cost(open)),
    within && enough(remaining_high, remaining_low, attenuation_cost(open)),
    base && U32.is_ne(open, 0), base && U32.is_eq(open, 0)}

# Direct calls with counts outside 0..8 cannot synthesize a measurement.
def with_count(+remaining_high: U32, +remaining_low: U32, open: U32) -> Assessment:
  match open:
    case 0: capacity(0, remaining_high, remaining_low)
    case 1: capacity(1, remaining_high, remaining_low)
    case 2: capacity(2, remaining_high, remaining_low)
    case 3: capacity(3, remaining_high, remaining_low)
    case 4: capacity(4, remaining_high, remaining_low)
    case 5: capacity(5, remaining_high, remaining_low)
    case 6: capacity(6, remaining_high, remaining_low)
    case 7: capacity(7, remaining_high, remaining_low)
    case 8: capacity(8, remaining_high, remaining_low)
    case _: Incomplete{}

def with_scan(high: U32, low: U32, count: Count) -> Assessment:
  match count:
    case CountIncomplete{}: Incomplete{}
    case Counted{open}: with_count(U32.not(high), U32.not(low), open)

# `inspect` recomputes the count from the supplied original list. The returned
# capacity flags describe only the arithmetic; they never establish identity,
# current authority, valid handles, a real resource guarantee or acceptance.
# A false close flag means the complete active cleanup-and-retirement reserve
# is not established; an individual mathematical successor may still exist.
def inspect(revision: R.Revision, handles: F.Handles) -> Assessment:
  match revision:
    case R.V2{high, low}: with_scan(high, low, scan(handles, 8n))
    case _: UnsupportedRevision{}
