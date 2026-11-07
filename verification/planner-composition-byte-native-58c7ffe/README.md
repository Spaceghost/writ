# Optimized native CPU check at 58c7ffe

Pinned Bend 2.0.39 built the combined suite from exact source
`58c7ffe048aa37aa38b8b8b6d21c6e5f2cb9db2e` with `CC=clang-23`,
`BEND_NO_TELEMETRY=1`, `nice -n 15`, a 1,800-second timeout and output outside
the checkout. [Process inspection](observed-compiler.txt) captured clang 23
with `-O3`. The [build exit](build.exit) and [build log](build.log) are retained.

The resulting binary ran with `+RTS --threads 4 --gpu off`, exited
[0](run.exit), printed 2,261 PASS lines and the final success sentinel. Its
[stdout](run.stdout), SHA-256
`012c789f9761c050961adcdde8ef4f689e3d1d3096cb272c359d5d5ff30cdf9b`, matches
the preview Node output byte-for-byte; [stderr](run.stderr) is retained. The
native binary SHA-256 was
`9196607aad0fff20afa400372b58694647786984d096e796711128c7b22b0d81` and remains
outside the source tree. The 110-file [Bend inventory](../planner-composition-byte-preview/bend-inputs.sha256)
verified [before](inputs-before.log) and [after](inputs-after.log) the run.
Later preview commits changed evidence only. This is CPU evidence, not a GPU
run, authenticated planner integration, or protected-host qualification.
