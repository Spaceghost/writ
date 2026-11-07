# Planner order and binding regression: integrated local checks

The isolated merge `1e901043144550b50992ba0560f7e38d0a49c30e` combines the
planner word-order tests from `4983595` with the duplicate-ID tests from
`da1ac17`. It preserves both test files and their separate evidence; the
earlier 2,271-check planner CPU result and 2,273-check binding CPU result
remain attributed to their original source inputs.

At the exact merge checkout, pinned Bend 2.0.39 and generated JavaScript run
by Node v26.10.0 each exited 0 with 2,281 PASS lines and
`ALL LIBRARY TESTS PASSED`. The retained [Bend](bend.log) and [Node](node.log)
stdout files were byte-identical,
SHA-256 `b03250033ffabd8297d21375614e7e356a866548a2f0a23512178fc5adeb1248`;
the [Bend](bend.exit) and [Node](node.exit) exit files each contain 0.
The generated JavaScript SHA-256 was
`8dc29ce7896330d55b332e4281e1d7ed8d06dcfd7c0ba519a2846f386f31bc4c`
and the file stayed outside the checkout. Build output and both stderr files
were empty.

`bend PROOF.bend --verdict` [exited 0](verdict.exit) and produced
[ALL PROOFS CHECK](verdict.log) using the previously built Lean-backed kernel
SHA-256 `e365eba1741602bb45261aa0eb6bd2c6f5db885d4b9d4cd603a27bc3c5a9ed18`.
It checks the existing 37 laws; it adds no planner-order or duplicate-ID proof.
The [110 tracked Bend input hashes](bend-inputs.sha256) were recorded before
the runs and verified afterward. These local observations are not process
attestation.

The native CPU build started from the clean `1e90104` checkout with
`CC=clang-23`, `nice -n 15` and a 1,800-second timeout. Only evidence and
documentation files were added or edited while it compiled; all 110 Bend
inputs matched the pre-run inventory after completion.
[Process inspection](compiler-observed.txt) showed `-O3`; the
[build](native-build.exit) exited 0 with an empty [build log](native-build.log).
Bend's automatic post-build `--gpu-build` generated a device artifact outside
the checkout; it was not a GPU test. The executable ran with
`+RTS --threads 4 --gpu off`, [exited 0](native.exit), and its
[2,281-check stdout](native.log) was byte-identical to the Bend and Node
outputs. [Run stderr](native.stderr) was empty. The executable SHA-256
observed afterward was
`b57cf12ec8d9b0b648063ea61fdab0e3015665468f9c7b5c6efe8932ac9712bb`;
the binary and device artifact remain outside the source tree. The source and
binary observations are not process attestation.

No new CI or Nix execution is claimed here. These are synthetic model checks,
not evidence of planner authentication, a native identity boundary, GPU
execution, protected-host qualification or durable review completion.
