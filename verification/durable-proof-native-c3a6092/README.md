# Optimized native CPU check at c3a6092

Pinned Bend 2.0.39 built the combined suite from exact source
`c3a6092f5553f3e83fa1dd1107acefda62616349` with `CC=clang-23`,
`BEND_NO_TELEMETRY=1`, `nice -n 15`, a 1,800-second timeout and output outside
the checkout. [Process inspection](observed-compiler.txt) captured clang 23
with `-O3`. The [build exit](build.exit) and [build log](build.log) are retained.

The binary ran with `+RTS --threads 4 --gpu off`, exited [0](run.exit), printed
2,481 PASS lines and the final success sentinel. Its [stdout](run.stdout),
SHA-256 `ea79527eb3cc6ec94909c3f60a10c34d75c6c49b2728372e83ea6fc5f9f58e23`,
matches the preview Node output byte-for-byte; [stderr](run.stderr) is
retained. The native binary SHA-256 was
`2c7e2e5ad6aad3a5660ebcc5a1127533e35d890365ad06001568b2e93ba21ae4` and remains
outside the source tree. The 129-file [Bend inventory](../durable-proof-current-preview/bend-inputs.sha256)
verified [before](inputs-before.log) and [after](inputs-after.log) the run.
Later preview commits changed evidence only. This is CPU evidence, not a GPU
run, durable host service, authenticated planner integration, or protected-host
qualification. Durable tasks and independent human security review remain open.
