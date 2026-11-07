# Issuance approval and grant ID exhaustion

At the maximum supported Nat, an otherwise eligible source/write submission,
registration or derivation previously attempted to increment `next_id` beyond
its range and aborted instead of rejecting unchanged. The shared counter must
stay strictly above every allocated approval and grant ID, so max−1 is the
last allocatable ID. The final ordered gate now rejects an otherwise eligible
allocation at max with `IdExhausted`; earlier failure reasons retain their
existing order. This adds a constructor to the public model error type and its
equality operation. Refusing an unrepresentable successor preserves monotonic
allocation and unchanged denial rather than weakening a law. See the proposed
[issuance contract](../../openspec/changes/add-authenticated-grant-issuance/specs/grant-issuance/spec.md),
[traceability](../../openspec/traceability/grant-issuance.md) and
[model API](../../docs/GRANT-ISSUANCE.md).

ID exhaustion does not invalidate existing records or enter current-grant,
projection or revocation checks. The [35 synthetic tests](../../IssuanceBoundaryTests.bend)
compare the full independent expected state after each last allocation, exact
unchanged denials at max, stale and multi-fault denial precedence, the check
lists, use of current projected grants and authenticated revocation. The host
still must authenticate identity, supply current state and time, rebuild
projections, serialize installs and persist state. Terminal **revision**
exhaustion is a separate unresolved defect, including for revocation; these
tests use revision headroom and do not claim to repair it.

The 2,448-check root suite passed on pinned [Bend](bend.log) and generated
[Node](node.log) with identical output SHA-256
`7bd212f679c4e4eb7554c7970abaf912090b8773a82be45f48ba4c7276348573`.
The [existing-law Lean verdict](proof.log) passed; no law was changed or added,
and this is not a general proof of these boundary cases. The [123-file Bend
input inventory](bend-inputs.sha256) records the tested source bytes. Pinned Bend
and Lean kernel executable hashes were respectively
`2ec160fa4486d33aff51e9eedcc294d6b531dc10c279c00b0c00685dae2045cd` and
`e365eba1741602bb45261aa0eb6bd2c6f5db885d4b9d4cd603a27bc3c5a9ed18`.

With original `21bec59` Issuance source and the new tests, both
[Bend](baseline-bend.log) and [Node](baseline-node.log) pass the final-ID
controls and then abort on the first exhausted source submission. For that
baseline only, the test's new-constructor equality check was replaced by a
true control and `IdExhausted` references were replaced with an existing error
constructor so the old source compiles; the crashing transition is unchanged.
Six independent zero-context mutation patches and corresponding Bend/Node logs
are retained. Removing each of the four allocation gates causes overflow;
adding the gate to `current` or revocation fails the current-grant or authorized
revocation test. All twelve mutant executions exited nonzero. These are selected
synthetic controls, not exhaustive proofs or Lean-kernel rejections.

The separate [allocator test](allocator.log) passed 24 checks with ASan/UBSan,
and the [owned-temp pair handoff test](handoff.log) passed synthetic
capture-to-Bend/Node controls. Neither exercises a native issuance host. At this
checkpoint the [optimized native CPU suite](native.log) passed all 2,448 checks
with `+RTS --threads 1 --gpu off -RTS`, byte-identical to Bend/Node. Build and
run both exited 0; [build stdout](native-build.log), [build stderr](native-build.stderr)
and [run stderr](native.stderr) are empty. The build began before source commit
`b918f49`, and all 123 inventoried Bend inputs match that commit and the
post-run tree. An `-O3` compiler command was [observed](native-clang-observation.txt),
not process attestation. The compiler also automatically launched a
`tests-native +RTS --gpu-build` build subprocess; this is not a GPU test.
Generated JS and native binaries stay outside the source tree. No GPU execution
result, Linux identity, broker, launcher, protected-host or durable recovery
qualification is claimed.
