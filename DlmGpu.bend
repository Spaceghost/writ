import Base
import ./Dlm.bend as Dlm

# GPU entry point is deliberately separate from the serial verification API.
# Bend's ! may execute on its CPU pool when no GPU is available. This function
# reports no device claim; callers must separately observe backend selection.
def batch(queries: Dlm.Batch, snapshot: Dlm.Snapshot) -> Dlm.Answers:
  Dlm.batch!(queries, snapshot)
