import Base
import ./Transfer.bend as Transfer

# Requests native GPU execution. Bend's native runtime may fall back to its CPU
# pool; the JS target is sequential. This function is not execution attestation.
# Balance independent requests of similar cost. Results are proposals: the
# monitor must rerun Transfer.admit for each original Plan against its live
# authoritative Context before final commit through the backplane.
def batch_gpu(xs: Transfer.Batch) -> Transfer.Decisions:
  Transfer.batch!(xs)
