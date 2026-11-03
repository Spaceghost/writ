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
# Keep these computations on immutable snapshots; parallel scheduling does not
# give their results authority or make snapshot epochs current at commit.

# Produce a proposed assignment; Core.verify checks the original graph without
# trusting the solver's prepared predecessor lists or its convergence claim.
def solve(graph: Core.Graph, rounds: Nat) -> Core.SolveResult:
  Gpu.solve_gpu(graph, rounds)

# Evaluate independent label queries. Dlm.verify_batch replays the same request
# tree against the monitor's snapshot, including answer shape and denied leaves.
def label_batch(queries: Dlm.Batch, snapshot: Dlm.Snapshot) -> Dlm.Answers:
  DlmGpu.batch(queries, snapshot)

# Batch exact paired transfers. Final admission is replayed from live context
# through DataOS.commit_from_capability; a batch result cannot bypass that gate.
def transfer_batch(requests: Transfer.Batch) -> Transfer.Decisions:
  TransferGpu.batch_gpu(requests)
