# Task 6 report: the library corpus with the device on and off

Status: DONE

Evidence: verification/gpu-corpus.txt (build, runs, the inline gate record, Result, Limits), plus the two captures verification/gpu-corpus-on.txt and verification/gpu-corpus-off.txt. No `.bend` file was changed. The count pin and verification/tests-native.txt were not touched.

## Build
- Built from the worktree root at lane commit 98db68bf, with every `.bend` source clean. Output went to a new directory, ../writ-build/physical-gpu/task6/, so the earlier binaries stay as recorded.
- `bend Tests.bend -o .../task6/tests-gpu.c` emitted C with `#define BANGS   1` (line 3971), sha256 b50856fb...0602.
- `bend Tests.bend -o .../task6/tests-gpu` produced:
  - the binary, sha256 53eeea2b...afdf1, 15153384 bytes;
  - `tests-gpu.gpu` beside it, sha256 40b1305c...47f9, 885648 bytes. Its cubin is sm=89, toolkit 13.4, with kernels bend_dev and window_dev.
- The binary imports cuInit, cuLaunchKernel and nvrtc*, and links libcuda.so.1 and libnvrtc.so.13.
- The build took 93.6 s under load.
- The only bang is Gpu.sweep's `run_tree!`, reached through Gpu.solve_gpu from CoreTests.bend and PropertyTests.bend.

## Runs
| Run | Options | Exit | PASS / FAIL | Final line | stdout sha256 | Launches | Gate |
|---|---|---|---|---|---|---|---|
| off capture | `+RTS --threads 4 --gpu off` | 0 | 782 / 0 | ALL LIBRARY TESTS PASSED | fc3a08aa...16ff | not observed (supplementary sanitizer run: 0, no CUDA API instrumented, sanitizer exit 255) | n/a (CPU) |
| on capture | `+RTS --threads 4 --gpu on` | 0 | 782 / 0 | ALL LIBRARY TESTS PASSED | fc3a08aa...16ff | not observed in this run | n/a |
| observe.sh plain pass | `+RTS --gpu on -RTS` (32 threads) | 0 | 782 / 0 | same | fc3a08aa...16ff | (paired) | PASS |
| observe.sh observed pass | same, under compute-sanitizer | 0 | 782 / 0 | same | fc3a08aa...16ff | 4915 bend_dev, all attributed to tests-gpu | PASS |
| supplementary sanitizer | `+RTS --threads 4 --gpu on -RTS` | 0 | (stdout cmp-equal to on capture) | same | fc3a08aa...16ff | 4915 bend_dev | not a gate record |

- `check-record.sh record.txt` exits 0 (`gate: PASS`), and `--count-launches` recounts 4915.
- The sanitizer log ends `ERROR SUMMARY: 4915 errors`, which is one per filtered launch, as in Tasks 3 to 5. It has no truncation.
- No other kernel was launched.
- The heap was not exhausted, so the `--gpu 16GB` rerun did not apply.
- Wall times are indicative only, at load 18.6 to 23.9:
  - off: 74 ms;
  - on: 2112 ms;
  - plain pass: 2082 ms;
  - under the sanitizer: 3021 ms and 3297 ms.

## Three diffs
- on against off: `diff` exit 0, `cmp` exit 0, empty.
- on against verification/tests-native.txt: `diff` exit 0, `cmp` exit 0, empty.
- off against verification/tests-native.txt: `diff` exit 0, `cmp` exit 0, empty.

All three files have sha256 fc3a08aa33059b67fc9602d20496f6d40ad7950e5dd32bada6fc37c6062916ff. That equality is byte identity confirmed by cmp, not a digest argument. No line differs, so there is no difference finding.

## The two sentences, kept apart
1. Library correctness: the corpus printed 782 PASS and 0 FAIL with the device on and with it off. Both captures are byte-identical to each other and to the committed reference.
2. GPU claim: 4915 `bend_dev` launches were observed, so the solver bang in the corpus executed on the device. This is GPU evidence only for Gpu.sweep's `run_tree!`. It is not evidence for the label or transfer paths, which have no bang in the corpus binary.

## Not exercised
- Per-test attribution of launches. The launches are attributed to the single bang site only, and the mapping of launches to sweeps was not established.
- `--gpu <size>`, the default (no +RTS) mode, and runs with CUDA_VISIBLE_DEVICES set.
- The JS backend, proofs and `--verdict` (Lean is absent).
- A host/device time split (no nsys).

## Concerns
- observe.sh accepts only `--gpu MODE`. The gate record pair therefore ran with 32 threads, not the captures' `--threads 4`. I covered the exact capture options with a supplementary compute-sanitizer run (4915 launches, identical stdout), but that run is not a gate record. The `--gpu on --threads 4` capture itself was not individually observed.
- The brief's output path `../writ-build/physical-gpu/tests-gpu` became `.../task6/tests-gpu`, per the controller's new-directory ruling.
- One recorded grep used a wrong pattern and matched nothing. It is kept in the transcript with a note, and the next commands give the correct counts.
