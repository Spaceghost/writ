# Durable preview with planner boundary and comparator regressions

A planner description can be compared with an already selected plan in the
same experimental tree as the synthetic durable-publication and handoff models.
The comparison does not resolve authority or enable an endpoint; the durable
model does not implement a durable host service. Durable acceptance tasks and
independent human security review remain open.

This isolated merge combines durable/handoff/planner preview
`373d271be643a5b330265353cd92a0fb070be2b3` with master
`45df241e69dba4b964325aa975aac5749b66135a`. Every test import and invocation
from both parents is retained. The planner codec and comparator source/test
files are unchanged from the master parent; durable-model Bend files are
unchanged from the preview parent. Existing platform, native, mutation, Lean
recipe and failure evidence remains attributed to its original source.

On 2026-11-06, pinned Bend 2.0.39 and generated JavaScript under Node each
passed **2,444 checks** and printed `ALL LIBRARY TESTS PASSED`. Their stdout
is byte-identical, SHA-256
`fc22f84ecae8af226c0e88b94c5dac9ff6d15b53420dbfeccdc8b40814238e6c`.
The [capture](../../../../verification/durable-planner-current-bend-node.log)
and [Bend input hashes](../../../../verification/durable-planner-current-bend-source.sha256)
identify these inputs. Generated code stayed outside the checkout.

`bend PROOF.bend --verdict` exited 0 and reported
[ALL PROOFS CHECK](../../../../verification/durable-planner-current-verdict.log)
using the audited Lean-built BendTT kernel SHA-256
`e365eba1741602bb45261aa0eb6bd2c6f5db885d4b9d4cd603a27bc3c5a9ed18`.
This checks the existing 36 laws; it does not prove the new comparator,
durable publication or a native handoff. Strict OpenSpec validation reported
44 passed, 0 failed; it is structural, not acceptance evidence.

The Nix JavaScript check at exact source `25e70622c06b053ba1b8691da2fb6af6f5c73b4a`
also passed 2,444 checks with the same output hash. Its derivation was
`/nix/store/xmikj236v06l557zw72prcj053gfd26y-writ-tests-js.drv`, and its
output was `/nix/store/6xpisrvpa1j9msmpsi8lwz711d0izbv5-writ-tests-js`.
This is not a full Nix flake check or Nix native result. The Genode count pin
is updated to 2,444; no native CPU, GPU or platform CI result is claimed for
this combined source. The
[previous durable/handoff/planner record](planner-integration-preview.md) and
[planner regression records](../../../../verification/planner-comparator-ci-c5a02c7/README.md)
retain their separate exact-source observations. A prior Genode missing-clock
warning and Linux protected-setup refusal before input remain recorded. No
result establishes planner authentication, protected-host qualification or
durable recovery.
