# Locality conjunction: synthetic reference slice

The isolated working tree based on `886071954a491c556d50b4ff6741ee746b4f23d6`
adds a Bend-only reference predicate and 37 named synthetic checks. The exact
[112 Bend input hashes](bend-inputs.sha256) were captured before testing. This
record is written before the candidate commit: it identifies test inputs, not a
claim that the tests ran at a later commit. The captured hashes are observations,
not process attestation.

`bend Tests.bend` and generated JavaScript run with Node v26.10.0 both exited 0
and produced 2,318 PASS lines and `ALL LIBRARY TESTS PASSED`. Their retained
[Bend](bend.log) and [Node](node.log) stdout files are byte-identical with
SHA-256 `e87d601d12b49d85bc45d20f2b59ca1d7ece694cc1828b7f21d4713be3f9ad50`;
[exit codes](bend.exit) and [Node exit](node.exit) are retained. Generated JS,
SHA-256 `b9eeb71b3458b639762b02a238f9eb3945f4844307525e21a66b451e609e154f`,
remains outside the checkout. The 37 focused cases also pass independently on
both backends, with 90-second timeouts and 10,000-element over-cap fixtures;
the fixture construction itself is not a transport or allocation bound.

`bend PROOF.bend --verdict` [exited 0](verdict.exit) with
[ALL PROOFS CHECK](verdict.log). It used the existing Lean-backed kernel
SHA-256 `e365eba1741602bb45261aa0eb6bd2c6f5db885d4b9d4cd603a27bc3c5a9ed18`.
This checks the existing 37 laws; no locality law or proof is added.

The optimized native CPU build started before source commit `3e21484`, using
`CC=clang-23`, `nice -n 15`, and a 1,800-second build timeout. The recorded
112 Bend inputs were checked before the build and again after the run, and match
that commit; the commit itself was created while the build ran. The captured
[compiler process](compiler-observed.txt) included `-O3`. The build
[exited 0](native-build.exit) with an empty [build log](native-build.log). An
earlier preliminary compile was deliberately stopped before these final tests
and is not used as evidence.

The resulting executable ran with `+RTS --threads 4 --gpu off`,
[exited 0](native.exit), and its [2,318-check stdout](native.log) is byte-identical
to the Bend and Node output above. [Stderr](native.stderr) was empty, and the
post-run [input check](native-input-check.exit) exited 0. The observed executable
SHA-256 is `a774d7afea0dde50a1facdc58f8428e5429e5fa95e779ffe1d25ba5d1bd55cca`;
it and the generated device artifact remain outside the checkout. Generating
that artifact is not GPU execution. The source and process observations are
not process attestation.

Three temporary, isolated one-change mutations were run against the same focused
suite under Bend 2.0.39 and Node with 90-second timeouts. Each exited 1 on both
backends, while the unmodified suite passed:

| Mutation | Patch | Named failure (Bend / Node) |
| --- | --- | --- |
| Drop each current rule from the conjunction | [patch](mutant-conj.patch) | [`disjoint_singletons`](mutant-conj-bend.log) / [Node](mutant-conj-node.log) |
| Accept word lists at cap plus one | [patch](mutant-cap.patch) | [`candidate_cap_before_missing_requirements`](mutant-cap-bend.log) / [Node](mutant-cap-node.log) |
| Validate only the first rule | [patch](mutant-late.patch) | [`late_missing_after_empty_rule`](mutant-late-bend.log) / [Node](mutant-late-node.log) |

All six explicit mutant exit files are retained alongside their output. These
are targeted test sensitivity controls, not an exhaustive mutation analysis.
The positive overlap and unrestricted cases independently show the reference
function is not merely returning no match.

The predicate accepts caller-constructed descriptions, not authenticated
requirements, complete dependency inventories or host facts. Match existence is
limited to the supplied candidate list and supplies no offer, authority, host
qualification, admission, commit or effect. Diagnostic result variants would
need separate disclosure authorization in any future integration. All locality
acceptance tasks remain open; no new CI, Nix build or GPU test is claimed.
