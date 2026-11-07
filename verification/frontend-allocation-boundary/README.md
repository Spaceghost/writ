# Frontend handle allocation exhaustion

At the maximum supported Nat value, a valid frontend's `next` counter could
previously make mount, open or duplicate overflow while constructing its
successor instead of rejecting unchanged. The counter must remain strictly
greater than every allocated ID, including tombstones, so max−1 is the last
allocatable ID. Rejecting new allocations at max preserves CF-004; wrapping,
reusing an identifier or weakening validity would not. See the
[frontend contract](../../openspec/specs/capability-frontend/spec.md) and
[traceability](../../openspec/traceability/capability-frontend.md).

The guard is limited to allocating mount/open/dup. At terminal `next` with
revision headroom, existing descriptor resolution, attenuation and authenticated
owner close remain available. Synthetic HostBinding checks also verify that
allocation refusal leaves its entire state unchanged, and that owner close
records a tombstone, stales the alias and refunds its slot. The separate
frontend *revision* maximum remains unresolved: close can still overflow at
terminal revision, so these tests do not establish CF-012 at that boundary.
Public records are not authenticated host state and this model does not itself
provide a descriptor, mount or protected-host boundary.

The [32 focused checks](../../FrontendBoundaryTests.bend) cover last-ID
allocation with exact scope and complete state, max-ID refusals and stale
controls for all three entry points, read and stale-read behavior, attenuation,
close after revocation and expiry, and HostBinding propagation. The complete
2,413-check root suite passed on pinned [Bend](bend.log) and generated
[Node](node.log) with identical output SHA-256
`f81c3a25ba677b8d006635528790ed6efbdfdcc3c139f645d94f68b7adf41909`.
The [existing-law Lean verdict](proof.log) passed; no law was changed or added,
and this is not a general proof of the new boundary cases. The
[122-source inventory](bend-inputs.sha256) records the exact Bend input bytes.
The pinned Bend executable and Lean kernel hashes were
`2ec160fa4486d33aff51e9eedcc294d6b531dc10c279c00b0c00685dae2045cd` and
`e365eba1741602bb45261aa0eb6bd2c6f5db885d4b9d4cd603a27bc3c5a9ed18`.

With original `85a1577` Frontend source and the new tests, both
[Bend](baseline-bend.log) and [Node](baseline-node.log) report overflow on the
first exhausted allocation after passing the last-ID controls. Six independent
zero-context mutation patches and corresponding Bend/Node logs are retained:
removing the mount, open or dup allocation guard each causes Nat overflow;
adding the allocation guard to validity, shared authorization or close fails
respectively the max-state validity, preserved read or owner-close assertion.
All twelve mutant executions exited nonzero. These are selected synthetic
controls, not exhaustive proofs or Lean-kernel rejections. Generated JS and
native binaries stay outside the source tree.

The separate [allocator test](allocator.log) passed 24 checks with ASan/UBSan,
and the [owned-temp pair handoff test](handoff.log) passed its synthetic
capture-to-Bend/Node controls. Neither exercises a frontend native host. The
native CPU build began before the source commit; its result is recorded in a
later evidence follow-up. No GPU, Linux identity, broker, launcher, protected
host or durable recovery claim is made.
