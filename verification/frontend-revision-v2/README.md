# Descriptive frontend revision V2 primitive

The [standalone Bend primitive](../../FrontendRevisionV2.bend) compares tagged
two-U32 V2 revisions without packing them into a bounded Nat and computes a
checked successor. For example, V2 `(high=0, low=4294967295)` advances to
`(1, 0)`; the all-maximum pair refuses unchanged. A V1 or unsupported tag is
incomparable, including when a V1 value matches the V2 pair numerically.

These are caller-constructible descriptive values. The `current` argument is
not authenticated monitor state; equality does not authorize a transition.
`advance_if_current` is a pure convenience wrapper, not a host entry point or
a concurrency guard. The exported helpers, including `advance_matching`,
are implementation details and confer no authority. The arithmetic helpers
`carry` and `advance_low` independently test their own inputs before addition,
even when called directly. This module is not imported by `Frontend`,
`HostBinding` or `DataOS`; it neither migrates V1 state nor closes a handle.
The proposed [FR-001 contract](../../openspec/changes/add-versioned-frontend-revision/specs/frontend-revision-v2/spec.md)
and all authenticated migration, reserve, cleanup, rollback and host
qualification remain open. The [confirmed V1 owner-close failure](../../docs/superpowers/records/2026-11-07-frontend-revision-exhaustion/README.md)
is not fixed by this primitive.

The 36 synthetic [focused checks](../../FrontendRevisionV2Tests.bend) cover
equal, lower and greater words including bit 31; cross-tag, legacy and
unsupported refusal; zero and ordinary advancement; both word boundaries,
carry, last representable successor and terminal refusal; stale/future pair
refusal; and direct arithmetic-helper boundaries. [Bend](focused-bend.log)
and generated [Node](focused-node.log) produced byte-identical output
SHA-256 `a49f47ac06d54964b02b076e218b7bc649bea05be728719da8c63c793385bf2a`.
Two separate synthetic [terminal stale/tag controls](terminal-stale-probe.bend.txt)
passed on [Bend](terminal-stale-bend.log) and [Node](terminal-stale-node.log).
Those two controls are not included in the root-suite count.

The [six targeted mutation controls](mutants.log) use the retained `mutant-*.patch`
files and individual Bend/Node logs. They remove cross-tag refusal, high-word
comparison, low-word comparison, carry, terminal refusal, or stale checking;
each fails its named check on both backends. The two separately retained
`direct-*-probe.bend.txt` and `direct-*-*.log` controls call the arithmetic
helpers directly with a bypassed maximum-word guard; each mutation fails on
both backends. These are selected synthetic controls, not an exhaustive proof.
The [generated Node inspection](node-inspection.txt) records branch placement
and the exact generated artifact hash; generated JS remains outside the tree.

The full root suite produced 2,508 checks on [Bend](bend.log) and generated
[Node](node.log), byte-identical SHA-256
`3bfdde31e0cf16bb0de70efce57983a392106d90d3671e537a180fec91eb9c69`.
The existing [Lean-kernel verdict](proof-verdict.log) reports `ALL PROOFS CHECK`;
it verifies existing laws, not a new revision or migration law. The separate
synthetic [allocator](allocator.log) and owned-temp [pair handoff](handoff.log)
checks passed; they do not exercise a native frontend or authenticate a host.

The [Bend input inventory](bend-inputs.sha256) identifies the exact frozen
source files for these runs. Pinned Bend 2.0.39 had SHA-256
`2ec160fa4486d33aff51e9eedcc294d6b531dc10c279c00b0c00685dae2045cd`; the
Lean-backed kernel had SHA-256
`e365eba1741602bb45261aa0eb6bd2c6f5db885d4b9d4cd603a27bc3c5a9ed18`.
Optimized native CPU build and run are currently pending. No GPU execution or
native-host qualification is claimed. The proof and logs do not attest to the
operating process or establish durable state, a monitor identity or a migration.
