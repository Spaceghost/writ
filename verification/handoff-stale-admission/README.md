# Synthetic stale-evidence admission regression

In the synthetic handoff model, `ready()` is at local revision 2. Admission
with otherwise-valid evidence from revision 1 now has a named regression:
the expected result is `Aborted` with `UntrustedFacts` and a retired revision
3 state. Matching that constructor also rules out the `Attempt` wrapper and
its `HostPrimitives.Step` in this case. A second check calls admission again
from the returned retired state and expects `WrongPhase`; the existing
revision-2 positive control still matches the exact admitted input effect.
No production model or law changed.

`Evidence.at` is a synthetic revision comparison. A trusted caller could
relabel old evidence, so these checks do not establish native remeasurement,
peer or OS identity, complete route mediation, atomic installation, final
commit, protected execution or host qualification.

## Focused mutation

On an isolated scratch checkout of `57706c9`, the
[admission-only patch](admission-mutant.patch) substitutes the current local
revision for `Evidence.at` only at the `same_binding` call in
`admission_revision`. It keeps all other evidence fields and the shared
`same_binding` implementation intact; handoff and observation checks are not
mutated. With the old focused suite, both [Bend](before-bend.log) and
[Node](before-node.log) exited 0 with 37 PASS lines, including the fresh
admission positive. With both new checks present, each exited 1 after 34 PASS
lines, and stderr names the new stale-admission failure
([Bend](after-bend.stderr), [Node](after-node.stderr)). `Test.check` stops at
that first failure, so this run does not execute the subsequent retry check.

To test that second check independently, the scratch-only
[retry-only patch](retry-only.patch) removes the first new assertion while
keeping the second and the same admission mutation. Bend and Node again exit
1 after 34 PASS lines; stderr names the retry assertion
([Bend](retry-only-bend.stderr), [Node](retry-only-node.stderr)). These are
selected-mutant controls, not a proof of complete coverage. The mutation and
retry-only patch were never applied to the delivered model and tests.

## Local verification

The base is `57706c973c2cc85dd7ab5e4e2bbc925af850cc3c` with the delivered
two test additions and count/documentation updates. The
[tracked Bend source inventory](bend-source-sha256.txt) has 110 entries.
The pinned Bend 2.0.39 binary SHA-256 is
`2ec160fa4486d33aff51e9eedcc294d6b531dc10c279c00b0c00685dae2045cd`;
Node is v26.10.0. `bend Tests.bend` and generated JavaScript run by Node both
exited 0 with 2,263 PASS lines and `ALL LIBRARY TESTS PASSED`. Their stdout was
identical to [suite.log](suite.log), SHA-256
`f417d996a69f6d893d85a04ecc6d6f119dfae4dfea785aacc31353551cf9262f`.
Generated JavaScript stayed outside the source tree.

`bend PROOF.bend --verdict` exited 0 and produced
[ALL PROOFS CHECK](proof-verdict.log), using the previously built Lean-backed
kernel SHA-256 `e365eba1741602bb45261aa0eb6bd2c6f5db885d4b9d4cd603a27bc3c5a9ed18`.
It checks the existing 37 laws; no law for HostHandoff is added or claimed.
The source inventory and kernel hash are observations taken after the run,
not process attestation. The native CPU build and any CI or Nix result are separate from
the above and must be recorded only if actually obtained.
