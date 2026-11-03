import Base
import ./Transfer.bend as Transfer

# Requests native GPU execution. Bend's native runtime may fall back to its CPU
# pool; the JS target is sequential. This function is not execution attestation.
def batch_gpu(xs: Transfer.Batch) -> Transfer.Decisions:
  Transfer.batch!(xs)
