# Independent planner wire-order controls

A planner proposal with two ordered sources must encode the first source before
the second; a separately supplied frame must decode to that same order. The
same requirement applies to multiple evidence references. Eight new synthetic
checks use independently written word frames and typed proposals: each of
source and evidence order is tested in both directions, with separate encode
and decode assertions. Distinct reversed-order fixtures also reject a codec
that sorts the entries. These fixtures are word frames; existing tests cover
byte assembly and endian behavior separately, and neither set proves every
possible frame.

This is a reference-only codec test. It does not authenticate a planner,
resolve a manifest or evidence reference, add an endpoint, make an admission
or release decision, or complete the open planner tasks. No production codec,
policy or law changed.

## Selected paired mutations

Two isolated scratch checkouts of `ff8aa2e` were altered independently. The
[source-order patch](source/mutant.patch) reverses sources before serialization
and reverses them again after parsing; the [evidence-order patch](evidence/mutant.patch)
does the analogous transformation for evidence. Both are deliberately paired
mutants: a round trip can hide their wrong external ordering. They modify only
`PlannerEnvelope.bend`, are not present in the delivered implementation, and
apply with `git apply --unidiff-zero`.

With the old focused tests, each mutant exited 0 and passed all 62 checks on
[Bend](source/before-bend.log) and [Node](source/before-node.log) for the
source mutation, and [Bend](evidence/before-bend.log) and
[Node](evidence/before-node.log) for the evidence mutation. The four logs are
byte-identical. With the new test helpers copied into the same scratch trees,
each of the eight new checks was exercised individually by the corresponding
small `*.probe.bend.txt` runner in its directory. Each runner exited 1 on both
Bend and generated Node; the 16 exact outcomes are in
[mutant-results.txt](mutant-results.txt), with the individual logs beside the
runner. This is evidence against two selected paired mutations, not exhaustive
mutation coverage or a proof of the codec.

## Local verification

On the `ff8aa2e` base with these test/count/documentation changes, pinned
Bend 2.0.39 SHA-256
`2ec160fa4486d33aff51e9eedcc294d6b531dc10c279c00b0c00685dae2045cd`
and generated JavaScript run by Node v26.10.0 each ran the
[focused 70-check suite](focused.log) successfully with identical stdout,
SHA-256 `e204047cd97e9b319ced2a8f50d94efa8828ecd266b4e30a374a363a44eb4c68`.
`bend Tests.bend` and generated JavaScript run by Node each exited 0 with 2,271 PASS lines
and `ALL LIBRARY TESTS PASSED`. Their stdout was byte-identical to
[suite.log](suite.log), SHA-256
`0c680fb1bb12c5692e05250e642d0cf611ae87f6fc34caf508db58c2a41914bf`.
The [110 tracked Bend input hashes](bend-inputs.sha256) were recorded after
the Bend/Node/proof runs and before the native build; they match commit
`4983595` and still matched afterward. These runs and the native build began
before that commit; the hashes are observations, not process attestation. Generated
JavaScript stayed outside the checkout.

`bend PROOF.bend --verdict` exited 0 with [ALL PROOFS CHECK](proof-verdict.log),
using the previously built Lean-backed kernel SHA-256
`e365eba1741602bb45261aa0eb6bd2c6f5db885d4b9d4cd603a27bc3c5a9ed18`.
It checks the existing 37 laws and adds no planner-order proof. Strict
OpenSpec validation is structural, not proof of host behavior.

The same isolated Bend inputs built with `CC=clang-23`, `nice -n 15` and a
1,800-second timeout; [process inspection](compiler-observed.txt) showed `-O3`.
The [build](build.exit) exited 0 with an empty [build log](build.log). Bend's
automatic post-build `--gpu-build` generated its device artifact outside the
checkout; it was not a GPU test. The resulting executable ran with
`+RTS --threads 4 --gpu off`, [exited 0](run.exit), and produced
[2,271 PASS lines](run.log), byte-identical to `suite.log`; [run stderr](run.stderr)
was empty. The executable's SHA-256 observed after the run was
`1764a1875fb91a62e273863e55ec84f730a061cd2ee444ea08f92016dcf50c46`.
The executable and generated device artifact remain outside the source tree;
this CPU run does not qualify a GPU or host. CI and Nix results remain
separate and are not claimed here.
