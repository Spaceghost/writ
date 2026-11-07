# Native CPU check at comparator regression c5a02c7

At exact source `c5a02c7f3027ea45af7a9737fa2e9ed0801195ec`, pinned Bend 2.0.39 built the full suite with clang 23.1.1; process inspection recorded the `-O3` compiler flag. The binary ran with `+RTS --threads 4 --gpu off`, exited zero, reported 2,224 PASS lines, and ended in `ALL LIBRARY TESTS PASSED`. Its [output](run.stdout) is byte-identical to the Bend and Node output, SHA-256 `88a8143b694304655307af8dc5d24700ab4d6a7830e74da9c999f5cf360e142a`.

[environment.txt](environment.txt) records the commands, exit codes, compiler and binary hashes; [observed-compiler.txt](observed-compiler.txt) preserves the observed compiler process. The 109-file [Bend input inventory](bend-source-sha256.txt) was checked during the build and after the run; the tree remained clean. The generated source and executable remain outside the repository. This is CPU evidence, not a GPU test, planner authentication, or protected-host qualification.
