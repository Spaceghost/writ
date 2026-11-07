# Native CPU check for current durable/planner preview

At exact source `25e70622c06b053ba1b8691da2fb6af6f5c73b4a`, pinned Bend
2.0.39 built the suite with `CC=/usr/bin/clang` and the resulting executable ran with
`+RTS --threads 4 --gpu off`. The captured [run output](run.log) contains
2,444 PASS lines and `ALL LIBRARY TESTS PASSED`; its SHA-256
`fc22f84ecae8af226c0e88b94c5dac9ff6d15b53420dbfeccdc8b40814238e6c`
matches the Bend/Node/Nix JavaScript output byte-for-byte. The build and run
were joined by `&&`; the observed outer shell exited 0. Their individual exit
codes were not separately captured. The [combined build log](build.log) is
empty. After the run `/usr/bin/clang` reported version 23.1.1; its exact
optimisation flag was not independently recorded.

[observation.txt](observation.txt) records the commands and observed hashes.
The [128-file Bend inventory](bend-source-sha256.txt) was verified after the
run against the clean exact-source worktree. The executable hash was observed
after the run, not continuously monitored. Generated source and executable
were kept outside the checkout. This is CPU evidence, not a GPU test,
protected-host qualification, durable recovery or independent human review.
