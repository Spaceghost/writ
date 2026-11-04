# Task 2 report: reproducible library builds and flake checks

Status: DONE (no exclusions; minor notes below)

## Commits (branch lane/nix-flake, not pushed)
- 4a1b43b Build Writ test and example binaries and run checks in Nix
- 95adf01 Record Nix flake check and determinism evidence; document library builds

## Files
- nix/writ.nix (new): source filtering, packages, and checks; imported from flake.nix.
- flake.nix: imports nix/writ.nix; adds packages.tests-native, packages.examples-native,
  and merges writ.checks into checks. flake.lock unchanged (no new inputs).
- docs/INSTALL.md: Nix section extended (nix build .#tests-native, running it,
  nix build .#examples-native, nix flake check; what each check asserts; that these
  reproduce the recorded verification on the pinned toolchain; clang 23.1.3 vs the
  recorded clang 19.1.1; bundled JS runtime vs the recorded Node 24.22.1 run; CPU-only;
  flake check does not build examples-native).
- verification/nix-checks.txt, verification/nix-determinism.txt (new).

## Design
- Source: lib.fileset: fileFilter hasExt "bend" over the repo, minus contrib/, docs/,
  openspec/, verification/, scripts/, .superpowers/, nix/ (maybeMissing for absent dirs).
  Result: 29 root .bend files + 6 under examples/; no flake files. Builds compile from it.
  OpenSpec check uses a separate fileset of only openspec/.
- Each build/check: HOME=$(mktemp -d), BEND_NO_TELEMETRY=1, CC=<llvmPackages_latest clang>.
- packages: stdenvNoCC.mkDerivation running `bend <entry> -o $out/bin/<name>`;
  dontFixup (no strip/patchelf on generated binaries). tests-native -> bin/tests-native;
  examples-native -> bin/{example,flow,transfer,gpu-example}. Runtime references are only
  glibc and gcc libs (no bend/clang in the closure).
- checks:
  - tests-js: `bend Tests.bend` (bundled JS runner); exit status checked via PIPESTATUS;
    asserts last line == "ALL LIBRARY TESTS PASSED" and `grep -c '^PASS'` == 638.
  - tests-native: `${tests-native}/bin/tests-native +RTS --threads 4 --gpu off`; same assertion.
  - proofs: `bend PROOF.bend`; requires a line exactly "ALL PROOFS CHECK" (no --verdict).
  - openspec: `openspec validate --all --strict --no-interactive` in a copy of openspec/;
    fails on nonzero exit, any "✗" item line, or a missing "Totals: N passed, 0 failed".
  Each check stores its log as $out.
- Assertion negative test: the 638/final-line logic rejects the log with the final line
  removed and with one PASS line removed.

## Carried items from Task 1
- Wrapper and bend2/: no fix needed. The wrapper execs $out/bend/bin/bend by absolute
  path, so the binary resolves Base from the adjacent bend2/; Tests.bend, PROOF.bend and
  all examples compile and run in the sandbox.
- INSTALL clang statement: still 23.1.3 at the locked revision (confirmed from the
  sandbox process list: clang-wrapper-23.1.3).

## Observations
- Bend's native step is `$CC -std=c11 -O3 <tmp>.c -lpthread -lm -o <out>`; it adds
  -lpthread -lm itself. Nix cc-wrapper targets generic x86-64 with
  -source-date-epoch 315532800 (no -march=native), which helps reproducibility.
- GpuExample.bend compiled natively without CUDA and without error; no gpu-example.gpu
  was produced. The binary runs with --gpu off and prints its 5 PASS lines (CPU fallback;
  not a GPU test). All four example binaries exit 0 with expected PASS output.
- No network needed by the compiler or OpenSpec in the sandbox.

## Checks
- nix flake check -L (after nix store delete of every check output): all six checks ran
  and passed: bend-version, openspec-version, tests-js (638, final line), tests-native
  (638, final line), proofs (ALL PROOFS CHECK), openspec (Totals: 42 passed, 0 failed).
  Recorded in verification/nix-checks.txt.
- Determinism: tests-native built twice after nix store delete -> same path
  /nix/store/1zmbhfjm5g33agl3drhkb3gsa3gcsnlj-writ-tests-native, same
  nix hash path sha256-pr7V2E3aeNrwEP9xeJDKiz5dNRQGksiIsY+K+j2ShA4=; cmp of the binaries
  identical; `nix build --rebuild` also passed. examples-native `--rebuild` passed
  (sha256-z57/bd5quPYF2lFqWJjeJfgoUMBh7U8hco6TuFIFAqk=). Recorded in
  verification/nix-determinism.txt. Single host, single locked toolchain.
- Not run: bend PROOF.bend --verdict (Lean toolchain not in the flake); GPU execution.

## Notes / minor concerns
1. OpenSpec reports 42 items now vs 36 in verification/openspec-validation.txt; the
   openspec/ tree on this branch has more proposals than at that record. Not a failure.
2. nix flake check does not build packages.examples-native (only evaluates it); there is
   no check that runs the example binaries. Easy to add if wanted.
3. VERIFICATION.md and verification/source-sha256.txt were not updated (outside the
   allowed files); neither mentions the flake files or the new Nix evidence. AGENTS.md
   asks that the source manifest track the delivered tree, so a later task should align them.
4. The recorded flake-check run shows a "Git tree is dirty" warning because INSTALL and
   verification/ were uncommitted at that moment; they are outside every build source.
