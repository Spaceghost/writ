# Descriptive frontend revision V2 primitive

The [standalone Bend primitive](../../FrontendRevisionV2.bend) compares tagged
two-U32 V2 revisions without packing them into a bounded Nat and computes a
checked successor. For example, V2 `(high=0, low=4294967295)` advances to
`(1, 0)`; the all-maximum pair refuses unchanged. A V1 or unsupported tag is
incomparable, including when a V1 value matches the V2 pair numerically.
The `Unsupported` constructor models an unrecognized variant; its numeric
field does not define a wire tag or a decoding rule.

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
both backends. The direct-high probe uses `mutant-terminal.patch` and the
direct-low probe uses `mutant-carry.patch`. These are selected synthetic
controls, not an exhaustive proof.
The [generated Node inspection](node-inspection.txt) records branch placement
and the exact generated artifact hash; generated JS remains outside the tree.

The full root suite produced 2,508 checks on [Bend](bend.log) and generated
[Node](node.log), byte-identical SHA-256
`3bfdde31e0cf16bb0de70efce57983a392106d90d3671e537a180fec91eb9c69`.
The existing [Lean-kernel verdict](proof-verdict.log) reports `ALL PROOFS CHECK`;
it verifies existing laws, not a new revision or migration law. The separate
synthetic [allocator](allocator.log) and owned-temp [pair handoff](handoff.log)
checks passed; they do not exercise a native frontend or authenticate a host.

Offline [Nix evaluation](nix-eval.txt) produced the `tests-js` derivation with
the 2,508-PASS gate; all 92 filtered Bend inputs match the
[recorded inventory](nix-filtered-inputs.sha256) and working tree. This is
evaluation and source comparison only: the derivation was not built and no
flake check was run.

The [Bend input inventory](bend-inputs.sha256) identifies the exact frozen
source files for these runs. Pinned Bend 2.0.39 had SHA-256
`2ec160fa4486d33aff51e9eedcc294d6b531dc10c279c00b0c00685dae2045cd`; the
Lean-backed kernel had SHA-256
`e365eba1741602bb45261aa0eb6bd2c6f5db885d4b9d4cd603a27bc3c5a9ed18`.
The optimized [native CPU run](native.log) passed the same 2,508 checks with
`+RTS --threads 1 --gpu off -RTS`, byte-identical to Bend and Node. Build and
run both exited zero; [build stdout](native-build.log), [build stderr](native-build.stderr)
and [run stderr](native.stderr) are empty. The build began before source
candidate `e8f8f99`; all 128 Bend source hashes in the frozen inventory matched
before and after the run and match that candidate. An `-O3` compiler process was
[observed](native-clang-observation.txt); this is not process attestation. Bend
also invoked its automatic `--gpu-build` subprocess during compilation; it is
not evidence of a GPU execution test. Generated JS and native binaries remain
outside the source tree. No GPU test or native-host qualification is claimed.
The proof and logs do not establish durable state, monitor identity or migration.
