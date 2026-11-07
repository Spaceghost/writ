# Planner envelope local checks

The first reference-only codec slice is exercised by 60 synthetic tests; it
has no endpoint, registry resolution, authority decision, protected-input path,
or host qualification. See the change's [traceability](../openspec/changes/add-external-planner-adapters/traceability.md).

On 2026-11-06, the pinned Bend 2.0.39 runner and a separately generated Node
run each completed the integrated suite with 2,162 PASS lines and
`ALL LIBRARY TESTS PASSED`. Their stdout is byte-identical; the retained
[capture](planner-envelope-bend-node.log) has SHA-256
`4d3f40099aff932f09efd2a120e25d3404a368b43033050af1a6bbdbb88c696f`.
The [source inventory](planner-envelope-bend-source.sha256) records the authored
Bend inputs, including the driver and both codec files. Generated JavaScript and
binaries were kept outside the checkout. These outcomes do not establish host
confinement, protected-data delivery, or GPU execution.

`bend PROOF.bend --verdict` exited 0 and reported [ALL PROOFS CHECK](planner-envelope-verdict.log)
with `BENDTT=/tmp/writ-lean-434-isolated/kernel-audit/bendtt`,
`LEAN_STACK_SIZE_KB=4194304` and the Lean-built kernel SHA-256
`e365eba1741602bb45261aa0eb6bd2c6f5db885d4b9d4cd603a27bc3c5a9ed18`.
That hash matches the separately retained master kernel audit. The existing
`PROOF.bend`/`LAWS.bend` do not import or prove the new codec; this is a
regression check of those existing laws, not a codec correctness proof.
Strict OpenSpec validation reported 44 passed, 0 failed. Optimized native CPU
execution and independent exact-candidate review are pending; none of these
checks establishes a native host qualification.
