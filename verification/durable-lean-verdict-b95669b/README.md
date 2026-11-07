# BendTT verdict on combined preview b95669b

On exact isolated preview `b95669bd522ebae0b23664e26524fc10372cc779`, pinned
Bend 2.0.39 `bend PROOF.bend --verdict` exited 0 and printed `ALL PROOFS CHECK`.
The [command and observations](observations.txt), [reproduction script](run.sh.txt)
and separate raw stdout/stderr are retained. The tracked source manifest was
verified before the run, and the [124-file Bend source inventory](bend-source-sha256.txt)
and original manifest hash identify its inputs.

The command reused the isolated Lean 4.34.0-built BendTT executable whose
before/after SHA-256 is recorded as
`e365eba1741602bb45261aa0eb6bd2c6f5db885d4b9d4cd603a27bc3c5a9ed18`.
These hashes are observations, not process attestation. The separate
[kernel build and negative-control evidence](https://github.com/Spaceghost/writ/blob/7c431754d3c52f4dbca979c4823cd16a2a8e9a6e/verification/lean-verdict-be649f6/README.md)
records its unmodified BendTT source, official Lean release hash, compiler,
trusted dependencies and earlier startup failures. The Lean archive and Bend
wrapper/binary hashes for this run are also in [input-hashes.txt](input-hashes.txt).

This verdict covers the [36 named laws](law-names.txt) in the existing
`LAWS.bend`/`PROOF.bend` driver, not the whole system. The driver has no
durable-publication or handoff-specific law; this run does not prove their
transaction, sink, native isolation or recovery properties. The durable
plan's independent human security review and dependent task-order gates remain
open, as do real-host qualification and acceptance tasks. This record is not
a merge or an authorization to bypass those gates.
