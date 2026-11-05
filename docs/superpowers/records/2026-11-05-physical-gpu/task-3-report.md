# Task 3 report: each native path compiled and executed on the device

Status: DONE_WITH_CONCERNS. All three paths are validated on the device. The concerns are the SIZE 16 gate failures and the limits of the evidence; see the end.

Files added (touch list only):
- `scripts/gpu-validation/Solver.bend` (sha256 a2ee82bbc3f2f37b8cdf2b8c4ce96bd2071a45374406078174ff67635880b602)
- `scripts/gpu-validation/Labels.bend` (sha256 e1b080fb07a397316dc89cdd232a889fd92972b3b41ca8f288c6d62e2f238a45)
- `scripts/gpu-validation/Transfers.bend` (sha256 f7073cb453b524a1d9b1ffc08f71b620f32e0e78877cb80aa8a596d6b56df974)
- `verification/gpu-paths.txt`: the evidence. It has every command, its output and exit status, and all record pairs inline.

No other `.bend` file changed. observe.sh and check-record.sh are unchanged (efd08afb..., 7d4df17b...). There is no manifest change and no push. Build outputs are in `../writ-build/physical-gpu/` and runs in `../writ-build/physical-gpu/runs/task3/`.

## Probes
Each probe calls exactly one GpuLibrary entry from a pure def, behind an `IO.now()` step, as `run SIZE [ROUNDS]`. The inputs are SYNTHETIC replicas of the `examples/Scenario.bend` facts, with distinct indices:
- **Solver.bend**: `GPU.solve(graph, 0n)`. The graph has SIZE nodes in groups of four: a report node; a chain report -> b+1 -> b+2 and a fan b+1 -> b+3, as both flow and calls edges; and an equality b+2 == b+3. The least solution takes 3 Jacobi sweeps.
- **Labels.bend**: `GPU.label_batch`. Leaf i is chosen by i mod 4: allow (internal to internal), deny (internal to public), allow (public to public), deny (stale epoch).
- **Transfers.bend**: `GPU.transfer_batch`. Leaf i has invocation 1000+i in its plan and in both grant scopes. Leaf i mod 4 gives admit, deny Read (no read grant), admit, deny Write (no write grant).

All device rounds come first, then an IO step, then the CPU reference without `!` (`Core.solve_cpu`, `Dlm.batch`, `Transfer.batch`) on the same immutable inputs. Every device result is then checked three ways:
1. Field by field against the CPU reference. Transfer exports no Decision equality, so the probe has its own equality helpers covering every field.
2. Against an expected outcome per leaf, so that a CPU and device result that are wrong in the same way still fail.
3. Against the independent check on the original inputs: `Core.verify(original graph, candidate, Scenario.core_stamp())`, `Dlm.verify_batch(original queries, snapshot, answers)`, and `Transfer.admit` per original plan against its Context, walked over the original request tree.

The solver probe also has a denied control: Core.verify must refuse the unsolved seed assignment with InvalidCandidate.

The output is one PASS/FAIL line per check, and any FAIL exits 1. stdout says nothing about the device. With at most 16 leaves the probe prints the full last device result, so the `--gpu off` stdout diff compares every field at SIZE 16. At the larger sizes the diff compares counts and a digest. The digest covers every field for the solver and labels. For transfers it covers only the shape, the denial codes, the ticket invocation, the output schema, labels and kinds, and each origin's object, version, labels and kinds. It omits the plan's stamp, sources, destination, code, kind and output_type, and the origins' codes and payment terms. Transfers.bend's header wrongly says the hash covers every field; that is a known defect, left unedited so the records stay bound to its hash. `ROUNDS` goes beyond the brief's `run SIZE`. It only repeats the device call, and it is used only to make the label and transfer runs last at least 10 s.

## Build (all exit 0, stderr empty)
| Probe | BANGS | binary sha256 | .gpu sha256 | cubin |
|---|---|---|---|---|
| solver | 1 | 156185e3...5bad | 164461c1...0b67 | sm=89, `window_dev`, `bend_dev` |
| labels | 1 | 527d2d99...28f8 | c09ae05a...5339 | sm=89, `window_dev`, `bend_dev` |
| transfers | 1 | f3e81192...c7c3 | fddac93a...f09c | sm=89, `window_dev`, `bend_dev` |
| gpu-example (GpuExample.bend) | 3 | 27c86175...177e | be0ee70c...d005 | sm=89, `window_dev`, `bend_dev` |

`nm -D` shows cuInit, cuLaunchKernel and the nvrtc imports, and `ldd` resolves libcuda.so.1 and libnvrtc.so.13 for all four. Unreachable bang sites are dropped: each probe imports all of GpuLibrary, and its emitted C still has `BANGS 1`.

## Observed runs (observe.sh, `--gpu on`, CUDA_VISIBLE_DEVICES unset)
| Path | Run | bend_dev launches | Plain wall | compute_app_seen | pmon max SM | Correctness | Gate |
|---|---|---|---|---|---|---|---|
| solver | run 16 | 15 | 0.50 s | no (0 of 2 polls) | - | PASS 7 | FAIL (compute_app_seen) |
| solver | run 16384 | 15 | 30.8 s | yes 123/125 | 6 (2 of 28 rows) | PASS 7 | PASS |
| labels | run 16 | 5 | 0.25 s | no (0 of 1) | - | PASS 6 | FAIL (compute_app_seen) |
| labels | run 16384 | 5 | 0.48 s | yes 1/2 | - | PASS 6 | PASS |
| labels | run 16384 1200 | 6000 | 15.0 s | yes 63/64 | 34 (3 of 14) | PASS 6 | PASS |
| transfers | run 16 | 5 | 0.49 s | no (0 of 2) | - | PASS 6 | FAIL (compute_app_seen) |
| transfers | run 16384 | 5 | 0.70 s | yes 2/3 | - | PASS 6 | PASS |
| transfers | run 16384 200 | 1000 | 29.6 s | yes 99/101 | 32 (1 of 25) | PASS 6 | PASS |
| combined (gpu-example) | no args | 20 | 0.48 s | yes 1/2 | - | PASS 5 | PASS |

- **Solver**: 15 launches is 3 sweeps x 5 launches per bang. Every Core.solve_with sweep reached the device, including sweeps 2 and 3, which follow host work inside the same pure solve. The first sweep is the only one behind an IO boundary. The brief's fallback restructuring was therefore not needed for any path.
- **Combined run**: 20 launches in four groups of five. The host backtraces do not name the bang site, so per-path attribution in that run is an inference (2 solver sweeps on the two-node Scenario graph, plus one label bang and one transfer bang), not an observation.
- **Re-check**: check-record.sh on the stored records returns 0 for the six PASS pairs and 1 for the three SIZE 16 pairs.
- **Wall times**: load average was 18.88 to 63.49, and the display shared the GPU. The device was slower than the CPU here (solver 16384: 30.8 s with `--gpu on`, 19.9 s for the `--gpu off` comparison run). That is not a performance measurement.

## CPU comparison and verifier
- Every device result equals the in-process CPU reference in every pass, every round and every run: the probes' own field-by-field equality, plus the digest.
- Every `--gpu off` run's stdout is byte-identical to the matching `--gpu on` plain-pass stdout. That covers 9 runs, and at SIZE 16 it includes the full per-leaf result.
- The plain and observed stdout are identical in every pair.
- Independent check:
  - Core.verify approves every device candidate on the original graph and Scenario stamp, and denies the seed control.
  - Dlm.verify_batch accepts every device answer tree.
  - Transfer.admit per original plan equals every device decision.
- Expected outcomes at 16384:
  - solver: Solved, 3 sweeps, every summary node carrying secrecy 1, untrusted 2 and the read effect;
  - labels: 8192 allowed, 8192 denied;
  - transfers: 8192 admitted, 4096 Denied{Read}, 4096 Denied{Write}.
- No difference between a device result and a CPU result was found.

## Per path
- Graph solver: validated on the device with 15 bend_dev launches (run 16384, gate PASS).
- Label batch: validated on the device with 5 launches (run 16384, gate PASS) and 6000 launches (1200 rounds, gate PASS).
- Transfer batch: validated on the device with 5 launches (run 16384, gate PASS) and 1000 launches (200 rounds, gate PASS).

The "complete three-path" sentence in gpu-paths.txt is scoped to device GPU-0188dad3-4d11-4254-3a0d-50e3808bf464, driver 615.71.09, bend 2.0.39, CUDA/NVRTC 13.4.92 and the four .gpu hashes above.

## Not exercised
- SolveFailed outcomes on the device (TypeConflict, IterationLimit, InvalidGraph).
- Other graph shapes, adversarial or large-policy inputs, and sizes other than 16 and 16384.
- Hidden-device, default-mode and `--gpu <size>` controls for these probes (Task 2 ran them for bang).
- Device memory checking (all kernels excluded), Nsight (absent), and per-launch attribution inside the combined run.
- `bend Tests.bend` and `bend PROOF.bend`: no library, law or proof source changed.

## Concerns
1. The three SIZE 16 pairs fail the gate, verbatim `compute_app_seen: probe pid '...' never listed by --query-compute-apps`. Their observed passes still show launches (15, 5, 5) and correct results. The plain pass, at 0.25 to 0.5 s, ends before a 200 ms nvidia-smi poll lists the pid. I did not re-run them. At small sizes the gate cannot pass on this host unless the poll gets faster or the workload runs longer (ROUNDS). The controller may want that recorded as a gate property for later tasks.
2. The cross-process `--gpu off` comparison checks every field only at SIZE 16. At 16384 it compares counts plus a 32-bit digest. The in-process comparison checks every field at every size.
3. The independent checks run in the same process and use the library's own evaluators. They are a logical replay, not a separate protection domain.
4. The probes were uncommitted when the evidence was captured, so every record's lane_commit is 16bf000 with "uncommitted: ?? ...". Their hashes in the records equal the committed files.
5. The label and transfer probes have no case where the verifier rejects a wrong answer (deferred to Task 5's injected faults), and their replays are the same computation as the CPU-reference comparison.
6. pmon samples are sparse (1 to 3 numeric rows per long run). They meet the gate's rule of at least one SM sample above 0, but only just.

## Fix round 1
Review: task-3-review.md. The central claim holds; the fixes are text only, with no rerun and no probe change.
1. Transfer digest: gpu-paths.txt (Probes paragraph and Limits) and this report now state exactly which fields the transfer digest covers and which it omits, and that the solver and label digests cover every field. Limits adds that a full-field transfer digest is left for Task 4's parity cases. The stale Transfers.bend header comment is recorded as a known defect. The probe is unchanged (sha256 f7073cb4...), so the records stay bound.
2. Limits adds that the label and transfer probes have no case where the verifier rejects a wrong answer, so an always-true replay would pass them. This is deferred to Task 5's injected faults. Limits also notes that the batch replays are the same computation as the CPU-reference comparison.
3. Limits adds the pre-commit capture (lane_commit 16bf000, probes uncommitted, source hashes equal to the committed files). The Harness paragraph now names the source of each exit status: the plain record's `exit_status` is the probe's, the observed record's is compute-sanitizer's, and the `[exit status]` after observe.sh is the gate verdict.

Nothing was rerun. The commit also carries the controller's task-3-review.md and progress.md, which are in the record directory staged by `git add -A`.
