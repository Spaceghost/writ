### Task 3: Compile and execute each path on the device (1.3)

Requirement IDs: GV-002 "Validate all three native calculation paths", and GV-001 "Require observed physical execution".

Write `scripts/gpu-validation/Solver.bend`, `Labels.bend` and `Transfers.bend`. Each calls exactly one `GpuLibrary` entry (`solve`, `label_batch`, `transfer_batch`) behind an `IO` step, with mode `run SIZE`. `SIZE` is the leaf count, rounded to a power of two, built from `examples/Scenario.bend` facts replicated with distinct indices: a chain-and-fan graph for the solver, and alternating allow and deny queries or requests for the batches. Each probe then:

- computes the CPU reference in the same program (`Core.solve_cpu`, `Dlm.batch` without `!`, `Transfer.batch` without `!`) on the same immutable inputs;
- compares the complete result;
- runs the independent check: `Core.verify` on the original graph and stamp, `Dlm.verify_batch` on the original queries, and `Transfer.admit` per original plan against its `Context`.

Build each one, with its own `.gpu`, in `../writ-build/physical-gpu/`. Record `BANGS` (expected 1 per probe) and the cubin check as in Task 1. Run each through `observe.sh` at SIZE 16 and 16384, plus one plain run sized to last at least 10 s for the samplers. Also run `GpuExample.bend` (all three together, `BANGS 3`) once through the observer, to show the launch count when the paths run in one process.

Write `verification/gpu-paths.txt` with one section per path and one for the combined run. If a path shows zero `bend_dev` launches under `--gpu on`, record that the bang ran on the CPU pool, and you may try exactly one probe-side restructuring: moving the `IO` boundary so that no host fork precedes the bang. Record both attempts. If it still shows zero launches, the path stays unvalidated and the report says so; library source is not touched.

Acceptance: each of the three paths has its own build evidence, at least one observer-counted `bend_dev` launch, a passing correctness line against the CPU reference and the independent check, and a gate PASS record. Alternatively, the file states which path could not be attributed and why. The "complete three-path" sentence appears only if all three pass, and it is scoped to this exact configuration (device UUID, driver, Bend, CUDA, `.gpu` hashes).

