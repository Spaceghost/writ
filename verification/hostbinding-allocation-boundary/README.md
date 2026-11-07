# Host-binding object and alias allocation exhaustion

At the pinned Nat maximum, an otherwise eligible `bind_mount`, `bind_open` or
`bind_attenuate` previously attempted to increment an exhausted object or alias
counter and raised a range error; delegation did the same for an exhausted
alias counter. The counters must remain strictly above every allocated ID, so
maximum minus one is the final allocatable ID. The fix adds `IdExhausted` to
the closed model error type. It rejects the supplied host state unchanged when
the relevant counter lacks a successor, after all earlier gates have passed.
This retains monotonic IDs and unchanged denial; it does not relax route,
subject, rights, quota, frontend, graph, cleanup or revocation obligations.

Mount/open/attenuate check **both** native-model counters only after the
frontend transition would succeed, so a prior `FrontendRejected` remains the
reported reason and no tentative frontend change escapes on exhaustion.
Delegation checks **only** the alias counter after its existing resolution,
target and rights gates; an exhausted object counter does not prevent it.
Neither counter is added to `valid`, `resolve`, owner close or revocation.
These are pure synthetic model records, not authenticated host facts or
native capabilities. The separate frontend revision, binding revision and
object-generation exhaustion issues are not repaired by this change.

The [26 focused checks](focused.log) cover full expected states and IDs at the
last available object/alias values for mount, open, attenuation and delegation;
both exhausted counters; stale and multi-fault denial precedence; provisional
frontend rollback; original graph validity; and resolution, delegation graph,
owner close and revocation when allocation is exhausted. The existing
`HostBindingTests.State.equal` compares every field, including the embedded
frontend. These are finite synthetic controls, not a proof for all states or a
host replay. The complete [42 GA vectors](vectors.txt) include the new
`GA-008-4` exhausted-object mount; the original 41 match the historical
[vector file](../host-binding-vectors.txt) byte-for-byte. GA-009 host replay
for the new vector is not performed.

The [original results](original-results.json) and retained `original-*.bend.txt`
fixtures show the defect across both counters and every affected transition,
plus stale, close, revoke and delegation-with-object-exhausted controls. The
[nine original controls on Bend](original-controls-bend.log) and
[Node](original-controls-node.log) match and both exited zero. All 62 files in
the [original input inventory](original-bend-inputs.sha256) match base commit
`70f05b25eb92581c2f95993151e20ad6b4d71509`; [original generated JS hashes](original-generated-js.sha256)
are retained while generated programs remain outside the source tree. No test
here establishes that a fabricated terminal counter state is authenticated or
practically reachable from an empty host binding.

Independent review supplied five mutation patches and their exact raw outputs;
the retained zero-context patches reconstruct byte-identical mutant sources:
removing each mint-object, mint-alias or delegation-alias guard causes an
out-of-range failure, while leaking the provisional frontend state on either
mount or derive is caught by an unchanged-state assertion. All ten Bend/Node
mutant runs exited nonzero; [eight outcomes](independent-mutant-results.json)
and [two derive-leak outcomes](independent-derive-leak-results.json) identify
their output hashes. Selected mutant checks are not exhaustive proofs or a
Lean verdict about these cases.

The complete suite passed **2,498 checks** on pinned [Bend](bend.log) and
generated [Node](node.log), byte-identical SHA-256
`38d6a2ea0a8b06c594deef5b69ffb1034bb6c0cfc9344fa15a7c0e61e4aa45f0`.
The existing 37-law [Lean-kernel verdict](proof.log) reports `ALL PROOFS CHECK`;
no law was changed and this does not prove the new allocation guards. The
[125-file Bend input inventory](bend-inputs.sha256) identifies the tested
source bytes. Pinned Bend and audited BendTT executable SHA-256 values were
respectively `2ec160fa4486d33aff51e9eedcc294d6b531dc10c279c00b0c00685dae2045cd`
and `e365eba1741602bb45261aa0eb6bd2c6f5db885d4b9d4cd603a27bc3c5a9ed18`.
Focused and full-root C generation succeeded, but generated C and JavaScript
stay outside the checkout.

Offline Nix evaluation produced [this derivation](nix-eval.txt), whose
[description](nix-derivation.json) pins the 2,498-check gate. All 89 filtered
Bend source files match the [recorded hashes](nix-filtered-inputs.sha256) and
the tested worktree. This is **not** a derivation build, execution of that
gate, a full flake check, or a Nix native run.

The separate synthetic [allocator check](allocator.log) passed 24 checks under
ASan/UBSan; the owned-temporary [capture-to-Bend/Node handoff](handoff.log)
also passed. Neither runs a native host-binding service. The optimized full
native CPU build is still pending and no native result is claimed yet. No GPU
test, Linux identity probe, native confinement, protected-host qualification or
durable recovery is claimed.
