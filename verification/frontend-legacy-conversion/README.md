# Bounded synthetic legacy frontend conversion

For a synthetic V1 state at revision `2^48−1`, a frontend with an open handle
currently cannot advance that revision to close it. This reference slice copies
the supplied legacy handle descriptions and watermark into a candidate tagged
V2 revision `(65535, 4294967295)` and separately checks that candidate against
the original. It does **not** authenticate state, migrate an authoritative
frontend, close a handle, install a version fence or perform host effects.
The [legacy failure](../../docs/superpowers/records/2026-11-07-frontend-revision-exhaustion/README.md)
and the proposed [frontend V2 contract](../../openspec/changes/add-versioned-frontend-revision/specs/frontend-revision-v2/spec.md)
remain open.

[`FrontendLegacyConversion.bend`](../../FrontendLegacyConversion.bend) exposes
`build` and `check` as intended descriptive entries. It accepts a fixed
synthetic profile of at most eight handles and eight ordered source objects in
each handle's plan. More produces `BuildIncomplete` or `Incomplete`, not a
claim that an authoritative old state is invalid. The producer retains the
immutable original handle list; the separate checker reads both supplied
lists, not a producer work list, count, or digest. Public `Built` and `Exact`
constructors, and exported implementation helpers accepting Boolean staging
values, cannot authenticate inputs or commit a migration. The only scoped
structural comparison entry is `check`.

The checker verifies the original bounded structural conditions, exact V1 Nat
revision mapping, watermark, list order and complete handle fields including
kind, subject, all token words, plan stamp, invocation, ordered source object
versions, destination, all code words, operation, output type, rights, epoch,
expiry and tombstone. The producer uses bounded division/modulo by 2^32; the
checker independently reconstructs the Nat from candidate words. It masks the
high word before multiplication so direct calls and eager Node evaluation
cannot overflow, and rejects any discarded high bits. Each newly introduced
list traversal clamps even caller-supplied fuel to at most eight elements.
Original-handle, original-plan, candidate-handle and candidate-plan bounds are
staged before the full comparison. The local bounded structural conditions and
plan comparison use existing scalar helpers; their 8/8 fixture comparisons to
`Frontend.valid` and `Transfer.Plan.equal` are tests, not a proof of general
equivalence or an additional authoritative frontend validator.

The [126 focused Bend checks](../../FrontendLegacyConversionTests.bend) cover
separately constructed accepted candidates, manual producer destructuring,
zero/word-boundary/maximum revision mapping, high-mask collision, changed
watermark, each handle field and all token/code words, plan fields and ordered
sources, missing/reordered/duplicated handles, altered tombstones, valid and
invalid originals, exact caps and late over-cap inputs on both sides, and
direct forged-stage or excess-fuel calls. [Bend](focused-bend.log) and generated
[Node](focused-node.log) outputs are byte-identical, SHA-256
`eaf297e7a63fcd5802a1612d2f3717c601740ec513be6572af63994d2b99ab38`.

The [13 targeted mutation pairs](mutants/summary.json) use the retained patches
and Bend/Node output; patches apply with `git apply --unidiff-zero`. They exercise producer high and low mapping, high-mask
collision, watermark, closed flag, token, code and source preservation,
original-state validity and four independent fuel clamps. Each modified case
exited nonzero with its named test failure on both backends; this is bounded
mutation evidence, not a proof of all fields or runtime behavior. The generated
Node inspection record is [here](node-inspection.txt); generated artifacts stay
outside the source tree.

The full root suite passed **2,634 checks** on [Bend](root-bend.log) and
[Node](root-node.log), byte-identical SHA-256
`b33e9ff22c85a0fc8b63d2539d20f224a80c5dcfe08c15a14ee5e88870285320`.
The existing [Lean kernel verdict](proof-verdict.log) says `ALL PROOFS CHECK`;
it covers existing laws and does not prove the new conversion. The exact
[130-file Bend input inventory](bend-inputs.sha256) was recorded before the
native build. The optimized [native CPU run](native.log) passed the same 2,634
checks using `+RTS --threads 4 --gpu off -RTS` and matched Bend and Node
byte-for-byte. The build and run exited zero; [build stdout](native-build.log),
[build stderr](native-build.stderr) and [run stderr](native.stderr) were empty.
The build began on the uncommitted tested source before `7f7ef20`; all 130
inventoried Bend inputs matched before and after the run and match this tree.
This is CPU execution, not a physical GPU test.

Separate synthetic native checks passed: 24 allocator invariants under
ASan/UBSan ([output](allocator.log), [stderr](allocator.stderr)) and the
owned-temp capture-to-Bend/Node [handoff](handoff.log) ([stderr](handoff.stderr)).
They do not exercise a native frontend or authenticate a host. No authenticated
binding comparison, durable recovery or host qualification is claimed.

Offline [Nix evaluation](nix-eval.txt) produced the `tests-js` derivation with
the 2,634-PASS gate. All 94 filtered Bend files, including both conversion
files, match the [input inventory](nix-filtered-inputs.sha256) and working tree.
This is evaluation and source comparison only: the derivation was not built and
no flake check ran.

The later merge includes the independently landed ZFS CI diagnostic change to
`.github/workflows/writfs-native.yml`; that workflow change was not exercised by
the local Bend/Node runs or the native CPU build. All 130 inventoried
Bend inputs remain unchanged, and the [separate CI record](../master-ci-0c619ad/README.md)
retains the ZFS workflow's own result.

Pinned Bend 2.0.39 SHA-256 was
`2ec160fa4486d33aff51e9eedcc294d6b531dc10c279c00b0c00685dae2045cd`;
the Lean-backed BendTT binary SHA-256 was
`e365eba1741602bb45261aa0eb6bd2c6f5db885d4b9d4cd603a27bc3c5a9ed18`.
The new source/test SHA-256 values are:

```text
a1180db5ffb76cb3aa192f4c85946486accee020dd6b32f13effe3d62f1895dd  FrontendLegacyConversion.bend
1e3a82fc1e36a0c144e5a411fffe7e3ee7f7fef15a8345af8590128be6b9504f  FrontendLegacyConversionTests.bend
ee081d6dab2963d2e599181fb3952068e548c7cddf59783e781f01a4a1b006c9  Tests.bend
```

The standalone revision primitive task 1.1 is complete; all other frontend
migration, binding and host-acceptance tasks remain unchecked.
Oversized, untraversable or unauthenticated legacy states still need an
independent authenticated recovery and resource design; this 8/8 test profile
must not silently relabel them invalid or discharge owner cleanup.
