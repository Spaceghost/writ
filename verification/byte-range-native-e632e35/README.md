# Native CPU check at byte-range regression e632e35

At exact clean source `e632e35dc6108874677987c97b6bc050a141cdce`, pinned Bend 2.0.39 built the full suite with clang 23.1.1; process inspection recorded the `-O3` flag. The executable ran with `+RTS --threads 4 --gpu off`, exited zero, reported 2,226 PASS lines and ended in `ALL LIBRARY TESTS PASSED`. Its [output](run.stdout) is byte-identical to the Bend, Node and Nix JavaScript captures, SHA-256 `255cd9aa1660a4c9e2d697ed1773c5a341bbc3b402c909238e07c8377401b02e`.

[environment.txt](environment.txt) records the commands, statuses, compiler and executable hashes; [observed-compiler.txt](observed-compiler.txt) retains the observed compiler process. The [109-file Bend inventory](bend-source-sha256.txt) was checked before and after the run. The generated source and executable remain outside the repository. This is CPU evidence, not a GPU execution test, authenticated planner or protected-host qualification.
