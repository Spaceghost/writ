import Base
import ./FrontendRevisionV2.bend as R

# Arithmetic descriptions, not state admission, handle counts or authority.
# The monitor must establish the complete original open-handle count, current
# instance and bounded resources independently. This module does not perform
# a mutation, migration, cleanup or release. `assess` is the intended entry;
# exported helpers including `compare_order` and `compare_cost` are not
# admission gates. For example, a caller can forge Equal directly.
type Threshold is Data:
  Sufficient{}
  Insufficient{}
  CostOverflow{}

type Assessment is Data:
  Measured{active: Threshold, attenuation: Threshold, allocation: Threshold,
    binding_attenuation: Threshold}
  UnsupportedRevision{}

# Each intermediate is matched before another successor is attempted. A
# caller-forged Advanced containing a non-V2 or maximum pair is still refused
# by R.advance; no Boolean or ordering supplied by a caller establishes safety.
def next_cost(previous: R.Advance) -> R.Advance:
  match previous:
    case R.Advanced{revision}: R.advance(revision)
    case R.Refused{revision}: R.Refused{revision}

def compare_order(order: R.Ordering) -> Threshold:
  match order:
    case R.Equal{}: Sufficient{}
    case R.Greater{}: Sufficient{}
    case _: Insufficient{}

def compare_cost(distance: R.Revision, cost: R.Advance) -> Threshold:
  match cost:
    case R.Refused{_}: CostOverflow{}
    case R.Advanced{revision}: compare_order(R.compare(distance, revision))

# Remaining distance is the wordwise complement of current revision. Four
# successively checked increments represent O+1 through O+4; overflow is
# reported separately from a representable threshold that exceeds distance.
def measure(high: U32, low: U32, open_high: U32, open_low: U32) -> Assessment:
  +distance : R.Revision = R.V2{U32.not(high), U32.not(low)}
  +one = R.advance(R.V2{open_high, open_low})
  +two = next_cost(one)
  +three = next_cost(two)
  +four = next_cost(three)
  Measured{compare_cost(distance, one), compare_cost(distance, two),
    compare_cost(distance, three), compare_cost(distance, four)}

def assess(revision: R.Revision, open_high: U32, open_low: U32) -> Assessment:
  match revision:
    case R.V2{high, low}: measure(high, low, open_high, open_low)
    case _: UnsupportedRevision{}
