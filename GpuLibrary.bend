import Base
import ./Core.bend as Core
import ./Gpu.bend as Gpu
import ./Dlm.bend as Dlm
import ./DlmGpu.bend as DlmGpu
import ./Transfer.bend as Transfer
import ./TransferGpu.bend as TransferGpu

# Optional parallel entry points, all authored in Bend 2. Native ! dispatch
# requests the device, with the documented Bend CPU fallback. The monitor
# rechecks candidates against authoritative host state before any effect.
def solve(graph: Core.Graph, rounds: Nat) -> Core.SolveResult:
  Gpu.solve_gpu(graph, rounds)

def label_batch(queries: Dlm.Batch, snapshot: Dlm.Snapshot) -> Dlm.Answers:
  DlmGpu.batch(queries, snapshot)

def transfer_batch(requests: Transfer.Batch) -> Transfer.Decisions:
  TransferGpu.batch_gpu(requests)
