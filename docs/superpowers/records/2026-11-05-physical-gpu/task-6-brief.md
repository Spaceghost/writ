### Task 6: The 782 corpus with the device on and off

Requirement IDs: GV-003 "Match reference decisions and verifier outcomes" (library-wide), and GV-001 "Require observed physical execution" (attributing what the corpus ran on the device).

Build `bend Tests.bend -o ../writ-build/physical-gpu/tests-gpu`, with CUDA detected. Record the `BANGS` line of the emitted C. The corpus reaches the solver bang through `CoreTests` and `PropertyTests`; label and transfer batches in the corpus are host-side calls without `!`. Also record the binary and `.gpu` hashes. Then run, each under `timeout 600` with heartbeats:

- `tests-gpu +RTS --threads 4 --gpu off > verification/gpu-corpus-off.txt`;
- `tests-gpu +RTS --threads 4 --gpu on > verification/gpu-corpus-on.txt`;
- `--gpu on` once more under the observer, recording the `bend_dev` launch count. Bound it at 600 s; if it times out, record that and give the plain run's result alone.

For each capture, record the PASS count (`grep -cE '^PASS[: ]'`), the final line, and the stdout sha256. Diff on against off, and each of them against the committed 782 reference: sha256 `fc3a08aa33059b67fc9602d20496f6d40ad7950e5dd32bada6fc37c6062916ff`, `verification/tests-native.txt`. If the default device heap is exhausted (`corpus reservation failed`, or a fault), record it verbatim, rerun with `--gpu 16GB`, and keep both results.

Write `verification/gpu-corpus.txt` with two separate result sentences:

1. Library correctness: the count and diffs.
2. GPU claim: "N `bend_dev` launches observed; the solver bang in the corpus executed on the device". If N is 0, write "the corpus ran under `--gpu on` but no device dispatch was observed; this is not a device corpus run".

Any differing line is a finding, with the diff shown.

Acceptance: both captures are committed, counts and hashes are recorded, three diffs are shown, the launch count or timeout is recorded, and the two claims are stated separately.

