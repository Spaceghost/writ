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

Independent review of the final source and evidence commit was interrupted by
an automatic security filter without a specific action or reason. The exact
final commit review is incomplete; the earlier focused-test and mutation
observations above remain separately scoped.

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
also passed. Neither runs a native host-binding service. The [full native CPU
suite](native.log) passed 2,498 checks with `+RTS --threads 1 --gpu off -RTS`;
its output is byte-identical to Bend and Node. Build and run exited zero, with
empty retained [build stdout](native-build.log), [build stderr](native-build.stderr)
and [run stderr](native.stderr). The native build began before source commit
`a4d8bd0`; the 125 inventoried Bend input files match both before and after it.
The final independent review remains incomplete as noted above. No GPU test,
Linux identity probe, native confinement, protected-host qualification or
durable recovery is claimed.

## Combined with master `2ad65eeb`

The three commits above were cherry-picked onto master `2ad65eeb` without
source conflicts: `HostBinding.bend` is identical on the base and that master.
Master's later session-allocation and delegation capacity guards live in
`HostIdentity.bend` and `HostPrimitives.bend` and do not touch these counters.
They use the same convention: existing authority and revision denials first,
then a capacity denial that returns the supplied state before any increment.
The earlier per-file count pins were superseded by the shared
[reviewed count](../../utils/verification/core-check-count.txt), now **3098**
after reviewing the 26 added check names. The [command record](master-2ad65eeb/commands.txt)
gives exact invocations and tool hashes.

The [complete Bend suite](master-2ad65eeb/bend.log) passed 3,098 checks. No
earlier check name is missing from the 3,072-check master reference, and only
the 26 boundary names, the GA-008-4 vector and its summary were added.
[`PROOF.bend`](master-2ad65eeb/proof.txt) and the Lean-built BendTT
[verdict](master-2ad65eeb/verdict.txt) report `ALL PROOFS CHECK`, with the
`/bin/false` [negative control](master-2ad65eeb/verdict-negative.txt) failing as
required; no law changed, and the verdict does not prove the new guards. Strict
[OpenSpec validation](master-2ad65eeb/openspec.txt) passed 45 items and is
structural only. The full [native CPU suite](master-2ad65eeb/native.log)
(`clang -O0 -static`, `+RTS --threads 1 --gpu off`) built and ran with exit
zero and empty stderr; its output is byte-identical to Bend. No GPU test is
claimed. On the host QuickJS replica of the Genode prelude, the
[new lines](master-2ad65eeb/qjs-new-checks.txt) add about 13 ms; that is not a
Genode run.

## Independent review of the final source

A fresh read-only review of the final `HostBinding.bend` diff and
`HostBindingBoundaryTests.bend` on the combined tree found no correctness
defect. The successor bound is the pinned maximum `2^48 - 1`, so the last
allocatable ID is maximum minus one and the counter may end at the maximum.
Mint paths test both counters, because `commit_mint` increments both;
delegation tests only the alias counter, because `commit_delegate` increments
only that one. Each guard sits after the existing gates, so the documented
denial orders hold. Each denial returns the supplied state, discarding the
provisional Frontend state, and the commit branch is never evaluated. `valid`,
`resolve`, close and revocation are not gated on capacity, and no existing
check was removed or weakened. The tests compare complete states, including the
embedded Frontend.

Findings that were not defects: the GA-008 traceability row did not name the
new checks or GA-008-4, and it has now been updated. The suite tests the
`to_holder` SubjectMismatch case at exhaustion but not the `from_holder`
unauthorized one. Attenuation's pre-Frontend gates are covered only through
the shared `derive_checked` path used by `bind_open`. The unguarded
`1n+revision` in `commit_mint` and `commit_delegate`, object generation and
Frontend revision remain the separate gaps stated above. This review replaces
the interrupted one but is not a mutation run or proof; the earlier
interruption remains recorded above.
