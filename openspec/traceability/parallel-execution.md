# Parallel Execution Traceability

Baseline: [parallel-execution/spec.md](../specs/parallel-execution/spec.md).

The current evidence verifies graph producer behavior and CPU-executed examples.
It does not validate GPU hardware, device compilation, scheduling performance,
or isolation from a malicious driver/runtime.

| Requirement | Implementation | Evidence and coverage |
| --- | --- | --- |
| PX-001 | [GpuLibrary.bend](../../GpuLibrary.bend): `solve`, `label_batch`, `transfer_batch`; [Gpu.bend](../../Gpu.bend), [DlmGpu.bend](../../DlmGpu.bend), [TransferGpu.bend](../../TransferGpu.bend) | **Code-generation evidence:** [verification/gpu-codegen.txt](../../verification/gpu-codegen.txt) records `#define BANGS 3` from [GpuExample.bend](../../GpuExample.bend). Each wrapper issues a native device request; this is not a device execution measurement. |
| PX-002 | [Gpu.bend](../../Gpu.bend): `solve_gpu`, `sweep`, `run_tree`; [Core.bend](../../Core.bend): `solve_cpu` | **Tested:** [CoreTests.bend](../../CoreTests.bend), "Bend parallel producer matches sequential producer", "parallel producer preserves type conflict", "parallel cycle agrees with CPU", "parallel propagation retains high bits". [PropertyTests.bend](../../PropertyTests.bend) checks both producers against an independent expected result for 320 four-node cases. |
| PX-003 | [Gpu.bend](../../Gpu.bend): `make_tree`, `make_leaf`, `flatten` | **Tested:** the five-node fixture in `CoreTests`, "Bend parallel producer matches sequential producer", checks exact node order/count; "empty parallel graph needs no dispatch" covers the empty case. **Reviewed:** absent padding becomes `NoOutput` and `flatten` preserves left-to-right node order. |
| PX-004 | [Dlm.bend](../../Dlm.bend): `batch`; [Transfer.bend](../../Transfer.bend): `batch`, `Decisions.all_accepted` | **Tested:** [DlmTests.bend](../../DlmTests.bend), "parallel batch agrees with four independent semantic outcomes"; [TransferTests.bend](../../TransferTests.bend), "parallel batch admission", "parallel batch retains denial". **Reviewed:** empty-branch structure is handled explicitly in both batch functions; it has no dedicated named scenario check. |
| PX-005 | [Dlm.bend](../../Dlm.bend): `verify_batch`, `answers_equal`, `batch` | **Tested:** `DlmTests`, "complete CPU replay accepts correct batch results", "complete CPU replay rejects fabricated allows", "complete CPU replay rejects truncated result shape". Replay recomputes the full policy semantics; unlike the graph verifier, it is not a different policy algorithm. |
| PX-006 | [Gpu.bend](../../Gpu.bend): `solve_gpu`; [Core.bend](../../Core.bend): `solve_with`, `solve_loop`, `solve_finish`, `verify` | **Tested:** `CoreTests`, "parallel producer receives only validated graph", "parallel budget fails closed". **Reviewed:** convergence routes through the same independent original-graph verifier outside the device call. |
| PX-007 | [GpuLibrary.bend](../../GpuLibrary.bend), [Dlm.bend](../../Dlm.bend), [Transfer.bend](../../Transfer.bend): pure result signatures and calculation bodies | **Reviewed contract:** the entry points return candidates/answers/decisions and have no ledger mutation or output IO path. The batch-admission checks do not test a physical release adapter. [DESIGN.md](../../DESIGN.md) requires live revalidation and authoritative host commit. |
| PX-008 | [GpuExample.bend](../../GpuExample.bend); API result types; module comments | **Execution evidence:** [verification/gpu-example-native.txt](../../verification/gpu-example-native.txt), [verification/gpu-example-js.txt](../../verification/gpu-example-js.txt), and [verification/environment.txt](../../verification/environment.txt). The native example used CPU fallback; full native tests disabled GPU execution. **Reviewed disclosure:** no returned type contains a hardware attestation. |

## Performance and trust limits

The current graph producer uses balanced fork/join work and scans the original
edge lists per destination. Preparation is sequential; every destination reads
the same immutable prior assignment. Adjacency indexing and workload tuning are
future optimizations. The shared runtime/heap remains part of the trusted stack;
algorithmic verification is not a protected memory boundary.
