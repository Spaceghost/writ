# Native CPU check for planner N48 regression

At exact source `262a8d4d683c4c48711e734bd1358bc4b33a3993`, pinned Bend
2.0.39 built the full suite with clang 23.1.1; process inspection observed
the `-O3` compiler flag. The native executable run with `+RTS --threads 4
--gpu off` exited 0, reported 2,163 PASS lines and ended in `ALL LIBRARY TESTS
PASSED`. Its [output](run.stdout) is byte-identical to the Bend and Node
capture (SHA-256
`a2bdd3383323d06aa9bac21e698f30fe0c0aadbacae7c4ab8b04648e272dfa47`).

[environment.txt](environment.txt) records commands, exit codes, compiler and
binary hashes. The [107-file Bend inventory](bend-source-sha256.txt) was
verified against the clean source before and after the run. The executable and
generated source remain outside the repository. This is CPU evidence, not a
GPU test, authenticated planner integration or protected-host qualification.
