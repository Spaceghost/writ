# Issuer revision exhaustion: revocation boundary

An issuer has two already-submitted approvals and a registered paired grant.
With its revision at the pinned runtime's maximum `281474976710655` (`2^48−1`),
the recorded authority requests revocation of its own write approval at the
current revision. The synthetic [issuer state is structurally valid and the
revocation passes its existing gates](controls-bend.stdout), but the success
transition raises a Nat-range error on pinned Bend and generated Node instead
of returning a changed state. At one less than the maximum, the same revocation
succeeds and advances the revision to the maximum. A second eligible revocation
of the remaining source approval then raises the same error.

This is a confirmed **pure-model revocation availability failure**. It is not a
demonstrated unauthorized grant, use-after-revocation, native-host behavior,
or evidence that a host continues serving after an error. No issuer revision
repair, recovery protocol or host adapter is implemented by this record. The
documented runtime limit remains in force; it does not supply a successful
revocation or a checked error result at this boundary.

## Reproduction and scope

The [current-revision fixture](current.bend.txt) constructs a test issuer
state from `IssuanceTests.registered()` and substitutes the revision; the
[stale fixture](stale.bend.txt) supplies expected revision zero. In the
[recorded results](results.json), the eligible current request at the maximum
exits 1 with the Nat-range error on both backends. The equivalent request at
maximum minus one returns `CHANGED`; stale requests at either value return
`REJECTED`. All results are for the fixed synthetic principals and approvals in
the fixtures, not authenticated live identities.

The [controls](Controls.bend.txt) separately check that the terminal state is
valid, the current write revocation passes the existing gates, its grant is
current before revocation, and the penultimate revocation succeeds and makes
that grant not current. They also check that the different source approval
passes its revocation gates after that first transition. The [Bend](controls-bend.stdout)
and [Node](controls-node.stdout) outputs match; [both exited zero](controls-exit.json).
The [two-step fixture](TwoStep.bend.txt) starts from the synthetic penultimate
state, prints `CHANGED` for the write-approval revocation, and then attempts the
other approval at the now-terminal revision. Its retained Bend and Node
[stdout](two-step-bend.stdout) and [stderr](two-step-bend.stderr) match their
[Node stdout](two-step-node.stdout) and [stderr](two-step-node.stderr);
[both executions exited 1](controls-exit.json). The first revocation already
withdraws the paired grant in this fixture. The second failing call does not
demonstrate that this particular grant remains current or that any operation
was admitted after the first revocation.

The experiments were run before this record using the 60 copied tracked Bend
files in [this inventory](copied-bend-inputs.sha256), independently verified
against source `21bec595ddc421097757ee11bfc02bbe11d0f05e`, plus the retained
fixtures. The pinned Bend 2.0.39 executable SHA-256 was
`2ec160fa4486d33aff51e9eedcc294d6b531dc10c279c00b0c00685dae2045cd`.
[Scratch artifact hashes](scratch-artifact-sha256.txt) retain exact fixture
and generated Node identities; generated JavaScript remains outside the source
package. The result JSON's stdout and stderr were compared to every original
scratch output. These finite fixtures do not prove all backends, issuance
histories, or practical reachability from an empty issuer state.

## Authority, replay, and current use

The proposed [grant issuance contract](../../../../openspec/changes/add-authenticated-grant-issuance/specs/grant-issuance/spec.md)
requires authenticated source authority (GI-001), current revision-checked
registration (GI-005), and current use-time checks after revocation (GI-008).
The [Bend issuer](../../../../Issuance.bend) records an approval's issuer,
revoked flag and `consumed_by` history. On a successful authorized revocation,
it keeps the issuer/serial in `seen`, retains grant records and advances the
revision; `current` then withdraws grants citing that approval and their
descendants. It only marks the requested approval revoked after its exact
revision, principal, directory authority and existing-approval checks pass.

An exception is not evidence that these checks were bypassed or that the
successful transition occurred. A host must not acknowledge a failed revocation
as committed, infer that its cached projections became current, or treat the
exception as permission to continue an operation. Issuer records, principals,
directory, placements, clock and epochs are trusted monitor inputs; public
constructors do not authenticate them. The current proposal is a Bend model,
not a qualified host issuer, durable authority service or native revocation
mechanism. Per-use projections must be rebuilt from authenticated, current
monitor state; this fixture does not establish that host obligation.

## Design consequences, not a selected fix

The separately recorded [frontend revision analysis](../2026-11-07-frontend-revision-exhaustion/README.md)
distinguishes reserving future cleanup headroom from migrating an **already**
terminal state. The same distinction matters here: preserving headroom before
new issuer changes might leave room for authorized revocations, but cannot by
itself repair an existing authoritative state at the maximum. Denying a new
submission before exhaustion is a different question from guaranteeing that
each still-valid authority can withdraw its own approval. Any reserved-budget
design would need bounded, complete accounting for every currently unrevoked
approval and all other transitions, including an already-insufficient or
terminal legacy state. It cannot use an untrusted supplied count or silently
truncate a scan. This record does not establish that such a scheme is feasible
under all of the current issuer's resource and lifecycle requirements.

A versioned, multiword revision and a separately authenticated, atomic
migration are possible subjects for future review, not an implemented issuer
transition. A finite multiword value can also run out; it needs checked carry,
resource bounds and an exhaustion/recovery story. Migration would have to bind
the **exact current authoritative state**, fence delayed operations and old
snapshots, and preserve every approval's issuer, scope, expiry, revocation and
consumption status; the full `seen` replay history; grants and their exact
parent/citation relationships; subject, token, rights, epochs and placements;
and non-reused identifiers and allocation watermark. It must not let a caller
assert those authority facts, clear an old revocation, reactivate an ancestor,
or make stale grants current through a revision reset or unverified copy.
Monitor serialization, persistence and anti-rollback remain separate required
integration evidence, not consequences of choosing a wider field.

Before an implementation or contract amendment, review all mutation paths,
exhausted existing snapshots, concurrent approval revocation and grant
registration, serial replay, derived-grant withdrawal and use-time projection
rebuilding. Add independent Bend boundary and mutation cases, appropriate
backend/native checks and the documented Lean verdict, with host qualification
separate. Do not weaken existing authorization or replay laws merely to produce
a checked result. The board's frontend question concerns the frontend design;
an answer to it is not an issuer-specific migration decision or approval.
