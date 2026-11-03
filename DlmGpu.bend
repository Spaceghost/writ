import Base
import ./Dlm.bend as Dlm

# GPU entry point is deliberately separate from the host replay API.
# Bend's ! may execute on its CPU pool when no GPU is available. This function
# reports no device claim; callers must separately observe backend selection.
# Balance queries of similar cost; each answer is a proposal. Before admission,
# call Dlm.verify_batch with the original queries and a current authenticated
# snapshot. Verification replays checks; it does not create capabilities.
def batch(queries: Dlm.Batch, snapshot: Dlm.Snapshot) -> Dlm.Answers:
  Dlm.batch!(queries, snapshot)
