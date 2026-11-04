### Task 2: Reproducible library builds and checks

Add to `flake.nix`:

- `packages.x86_64-linux.tests-native`: a derivation that runs `bend Tests.bend -o $out/bin/tests-native` with `CC` set to the shell's clang, from the repository source filtered to the `.bend` files and the directories they import (use `lib.cleanSource` or `lib.fileset`; exclude `contrib/`, `docs/`, `openspec/`, `verification/`, and `.superpowers/`). Set `HOME` to a writable temporary directory inside the build because the Bend compiler may write a cache.
- `packages.x86_64-linux.examples-native`: the same for `Example.bend`, `examples/Flow.bend`, `examples/Transfer.bend`, and `GpuExample.bend`, each as a binary under `$out/bin/`.
- `checks.x86_64-linux.tests-js`: runs `bend Tests.bend` on the bundled JavaScript runner and fails unless the output ends with `ALL LIBRARY TESTS PASSED` and contains 638 lines beginning with `PASS`.
- `checks.x86_64-linux.tests-native`: runs the `tests-native` binary with `+RTS --threads 4 --gpu off` and applies the same assertion.
- `checks.x86_64-linux.proofs`: runs `bend PROOF.bend` and fails unless it prints `ALL PROOFS CHECK`.
- `checks.x86_64-linux.openspec`: runs `openspec validate --all --strict --no-interactive` over the `openspec/` directory and fails on any failure line.

Run `nix flake check` and record the output in `verification/nix-checks.txt`. Produce the determinism evidence in `verification/nix-determinism.txt` as the constraints describe. If any check cannot pass inside the sandbox for a reason you can name (for example the compiler needs network access), record the exact error, mark that check as excluded with the reason in a comment in `flake.nix`, and report DONE_WITH_CONCERNS.

Extend the "Nix" section of `docs/INSTALL.md` with `nix build .#tests-native` and `nix flake check`, and state that these reproduce the recorded verification on the pinned toolchain.

Acceptance: `nix flake check` passes or every exclusion is recorded with its error; `nix build .#tests-native` twice yields identical hashes recorded in the evidence file; INSTALL section extended.
