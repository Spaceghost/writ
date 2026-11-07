# Rendezvous approval and selection ID exhaustion

At the maximum supported Nat, an otherwise eligible origin-approval submission
or selection previously attempted to increment `next_id` beyond its range and
aborted instead of rejecting unchanged. The shared counter must remain strictly
above every allocated approval and selection ID, so max−1 is the final
allocatable ID. The final ordered gate now rejects an otherwise eligible
allocation at max with `IdExhausted`; earlier failure reasons retain their
existing order. This adds a constructor to the public model error type and its
equality operation. Refusing an unrepresentable successor preserves monotonic
allocation and unchanged denial rather than weakening a law. See the
[rendezvous contract](../../openspec/specs/executor-rendezvous/spec.md),
[traceability](../../openspec/traceability/executor-rendezvous.md) and
[model API](../../docs/EXECUTOR-RENDEZVOUS.md).

ID exhaustion does not invalidate existing records or enter offer submission,
withdrawal, current-selection or abandonment checks. The [24 synthetic tests](../../RendezvousBoundaryTests.bend)
compare complete independently expected final-allocation states, unchanged
exhausted/stale and multi-fault denials, check lists and nonallocating behavior.
The host must still authenticate principals, supply current state and time,
serialize installs and persist state. Terminal **revision** exhaustion is
separate and unresolved; these tests use revision headroom and do not claim to
repair it. Test assertions are split into named helpers to respect the native
backend's 247-word function-arity limit.

The 2,472-check root suite passed on pinned [Bend](bend.log) and generated
[Node](node.log) with identical output SHA-256
`249ab6deda8e904a60f064597ad367aaf77c354aadc9261ecc6e3cf1bffa6181`.
The [existing-law Lean verdict](proof.log) passed; no law was changed or added,
and this is not a general proof of these boundary cases. The [124-file current
Bend input inventory](bend-inputs.sha256) records the tested source bytes. Bend
and Node were repeated after a final comment correction and matched the retained
logs. The native build began before that correction and the source commit, with
[its own inventory](bend-inputs-native.sha256); only `Rendezvous.bend` differs.
The [comment diff](comment-diff.patch.txt) reconstructs the old comment text,
and the [comparison](comment-comparison.txt) records that removing whole lines
whose first non-whitespace character is `#` leaves the remaining source lines
byte-identical. This applies only to this specific full-line-comment change; it
is not a general-purpose Bend lexer or process attestation. Pinned Bend and
Lean kernel executable hashes were respectively
`2ec160fa4486d33aff51e9eedcc294d6b531dc10c279c00b0c00685dae2045cd` and
`e365eba1741602bb45261aa0eb6bd2c6f5db885d4b9d4cd603a27bc3c5a9ed18`.

With original `a3b7ad3` Rendezvous source and the new tests, both
[Bend](baseline-bend.log) and [Node](baseline-node.log) pass the final-ID
controls and then abort on the first exhausted approval submission. For that
baseline only, the test's new-constructor equality check was replaced by a
true control and `IdExhausted` references were replaced with an existing error
constructor so the old source compiles; the crashing transition is unchanged.
Six independent zero-context mutation patches and corresponding Bend/Node logs
are retained. Removing either allocation gate causes Nat overflow; adding that
gate to offer submission, either withdrawal, or current-selection checking
fails the corresponding preserved-operation assertion. All twelve mutant runs
exited nonzero. These are selected synthetic controls, not exhaustive proofs or
Lean-kernel rejections. The comment diff is a separate reverse-applicable patch,
not a mutant.

The separate [allocator test](allocator.log) passed 24 checks with ASan/UBSan,
and the [owned-temp pair handoff test](handoff.log) passed synthetic
capture-to-Bend/Node controls. Neither exercises a native rendezvous host.
The [optimized native CPU suite](native.log) passed all 2,472 checks with
`+RTS --threads 1 --gpu off -RTS`, byte-identical to Bend/Node. Build and run
both exited 0; [build stdout](native-build.log), [build stderr](native-build.stderr)
and [run stderr](native.stderr) are empty. The build began before source commit
`c79e34a`, with the pre-comment inventory and comparison described above; the
current 124 Bend input hashes still match after the run. A compiler command with
`-O3` was [observed](native-clang-observation.txt), not process attestation.
Generated JS and native binaries stay outside the source tree. No GPU test,
Linux identity, broker, launcher, protected-host or durable recovery
qualification is claimed.
