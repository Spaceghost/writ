# Linux monitor revocation action

A running modeled Linux worker may hold a descendant of a retired entry. The
trusted monitor can now call `LinuxHost.revoke(state, revision, slot)`, retain
the returned state, and carry the exact `StopEffects` returned by the existing
`HostPublication.revoke` transition to its effect handler. The slot selects an
entry; it does not authorize the caller. This in-process action adds no worker
or broker wire command and does not authenticate the party requesting it.

The [six new synthetic checks](focused-node.txt) cover retiring the worker's
input, retiring its ancestor while an unrelated root remains live, no stop for
an unused input, stale-revision precedence over a forged slot, repeated
retirement, and a later framed Barrier denial. They check the public
`Outcome.effects` accessor, worker phase, session credential retention, and
unchanged state/no effects on denial. Launch facts are synthetic.

## Verification

- [Bend 2.0.39 full suite](tests-bend.txt): 2,881 `PASS:` lines and
  `ALL LIBRARY TESTS PASSED`.
- The focused driver ran as [generated Node](focused-node.txt) and as an
  [optimized native CPU executable](focused-native.txt), with byte-identical
  output and 22 checks on each. The native run used one CPU thread with the GPU
  disabled; no GPU execution is claimed. [Build commands and statuses](build-commands.txt)
  accompany the empty [Node build output](js-build.txt) and
  [native build output](native-build.txt).
- Existing laws passed the [ordinary proof check](proof.txt) and the
  [BendTT kernel verdict](verdict.txt), with kernel
  SHA-256 `e365eba1741602bb45261aa0eb6bd2c6f5db885d4b9d4cd603a27bc3c5a9ed18`.
  No new law is claimed.
- [OpenSpec 1.16.0 strict validation](openspec.txt) passed 45 items; it is
  structural validation. An initial optimized native build was deliberately
  stopped with exit 143 after review strengthened the test source; the final
  build and runs above used that corrected source.

The owning monitor must authenticate and authorize revocation and serialize the
state/effect handoff. `Issuance.revoke` is not mapped to an identity slot, and
no native process is stopped by this model. The existing FUSE canary does not
use this action. No native identity probe, FUSE mount, VM, crash recovery,
protected-host qualification or authenticated live-authority bridge was run or
established.
