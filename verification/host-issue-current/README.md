# Current Frontend scope at host root issuance

A monitor could previously issue a root for a closed or expired Frontend handle,
or after its registry grant was withdrawn, if its owner, plan, rights and lease
still matched the old handle record. `HostPrimitives.issue` now retains those
existing checks and identity denial order, then requires the monitor-supplied
Frontend revision, full handle scope, registry, epoch/time and paired Transfer
context to pass before minting. Mounted handles and attenuated rights remain
supported; no synthetic read, write or execute request is invented.

This intentionally narrows what root issuance admits. The shared read-only
`HostIdentity.mint_preflight` preserves the existing revision, session and
origin checks, and `mint` recomputes it; no caller-provided preflight result
can commit an entry. Stale authority at the maximum Nat slot or revision is
now denied before mint arithmetic. A healthy mint at exhausted Nat slot or
revision can still abort: no capacity denial or recovery behavior is claimed.
The unchanged denied-state/no-effect laws do not prove freshness or reasons.

A synthetic [Issuance-backed scenario](../../RendezvousTests.bend) retains the
same Frontend descriptor across a source approval revocation: the fresh pair
and both mixed fresh/stale projections deny, while both cached projections
still admit. The monitor must supply one authenticated current snapshot; the
issue check does not obtain or authenticate it, retain grant lineage, recheck a
later use, qualify a native host or replace original-graph/commit checks.

## Verification

- [Full Bend suite](tests-bend.txt) and [generated Node](tests-node.txt):
  2,915 `PASS:` lines and byte-identical output, also matched by the
  [full generated native CPU suite](tests-native.txt) compiled at `-O0` and run
  with one CPU thread and GPU disabled. The [16 focused checks](focused-bend.txt)
  also matched [Node](focused-node.txt) and [native CPU](focused-native.txt).
- The unchanged 92-check HostIdentity corpus produced byte-identical output on
  the [56a6efb base](identity-base.txt) and [candidate](identity-current.txt).
  The preflight-to-mint comparison in the focused checks shares the new
  implementation and is not an independent historical oracle.
- The focused suite exercises stale authority at maximum slot, identity
  revision and host revision. Its [healthy maximum-slot control](trap-control.bend.txt)
  actually overflows on [Bend](trap-bend.txt), [Node](trap-node.txt), and
  [native CPU](trap-native.txt), each exit 1. Before the shared preflight,
  [stale authority at maximum slot also overflowed](stale-max-before-preflight.txt);
  the [control source](stale-max-before-preflight.bend.txt) is retained.
- [Ordinary proof](proof.txt), [pinned Lean verdict](verdict.txt), and
  [OpenSpec 1.16.0 strict](openspec.txt) passed. The [false-kernel control](negative.txt)
  failed as expected. These are existing laws and structural validation.
- Existing native [callback-order](handoff-mock.txt) and [retirement](retire-mock.txt)
  mock tests passed; they did not mount FUSE or probe identity.

A public-entry header comment was added to `HostIdentity.bend` after full
suite generation began. The [comparison](comment-comparison.txt) preserves
both source hashes and proves all non-comment bytes, hence implementation
tokens, identical. Bend, Node and the Lean verdict were rerun on the delivered
source. [Native C generated](c-generation-comparison.txt) from the delivered
tree is byte-identical to the earlier C used for the native build. The first
post-comment verdict attempt [aborted](verdict-4g-failure.txt) with a 4 GiB
virtual-memory limit; the rerun with 16 GiB passed. [Tested](tested-bend-input-sha256.txt) and [delivered](delivered-bend-input-sha256.txt)
Bend input hashes identify the comment difference; the [tested HostIdentity source](HostIdentity-tested.bend.txt)
is retained so its hash can be checked. Commands and explicit limits
are in [build commands](build-commands.txt).
No GPU test, native identity, FUSE mount, VM or live authority bridge is claimed.
