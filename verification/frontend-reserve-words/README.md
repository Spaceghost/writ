# Synthetic wide-word reserve arithmetic

For a supplied open count of one and four remaining revision successors, the
ordinary allocation threshold is met but the two-step binding attenuation
threshold is not. Five successors meet both. This reference computes the
representable costs O+1 through O+4 with checked two-word successors, then
compares them to the wordwise complement of the supplied revision. A cost
overflow is distinct from a representable cost that exceeds the distance.

The supplied count is descriptive data. This code does not count original
handles, establish state validity or identity, authenticate any request,
perform a frontend or binding mutation, install a migration, reserve host
resources or qualify a host. Exported helper results, including a forged
ordering passed to `compare_order`, are not admission gates. Task 1.2,
task 2.6 and the proposed acceptance scenarios remain open.

The 25 focused checks include an independent 221-case small-Nat oracle, all
four word-carry thresholds, opposing high-word dominance cases, terminal word
overflow, shortage versus overflow, unsupported revisions and direct forged
helper stages. Bend and Node outputs match (SHA-256
`363e91a0277316c036ab6fa47f384f98c03aab47646e79031e484a1767c56019`).
The ten retained mutation patches change each complement, each threshold,
ordering cases and refusal propagation; each failed a named assertion on both
backends. Their raw stdout, stderr and exits are in [mutants](mutants/).

The full 2,698-check Bend and Node outputs match (SHA-256
`4fe3c82d49752a0f1bb1278e3765dce111808c5463667f0366ec1fcd1d99b825`).
The 134-source [input inventory](bend-inputs.sha256) includes source
`a988eda1afd4df2899d60aada764f8cf93f38437946b15d6459a850e6a7d11db`,
test `598c5617189072522cb38d89690bb9118f5682161e2581562ffddb9e1aa96cf5`
and root driver `d7c4f5459a961407fabeadba19ef42d8e9c1e09c80e3da8e88cb4a5809271c4a`.
The focused C-generation check succeeded. Generated code remains outside the
source package; [Node inspection](node-inspection.txt) records its staging.

The first `bend PROOF.bend --verdict` attempt exited 1 because `lean` was not
in PATH, so it did not produce a verdict. A separately retained reproduction
records the same [exit](proof-no-lean-reproduction.exit),
[stdout](proof-no-lean-reproduction.stdout) and
[stderr](proof-no-lean-reproduction.stderr). The successful
[existing proof verdict](proof.log) used Bend 2.0.39 executable SHA-256
`2ec160fa4486d33aff51e9eedcc294d6b531dc10c279c00b0c00685dae2045cd`
and the previously built Lean-backed kernel selected via `BENDTT`, SHA-256
`e365eba1741602bb45261aa0eb6bd2c6f5db885d4b9d4cd603a27bc3c5a9ed18`.
The [successful stderr](proof.stderr) is empty. The existing laws do not prove
this new arithmetic reference. Native CPU evidence will be recorded separately.
