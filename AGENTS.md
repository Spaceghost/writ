# Working on Writ

Use the pinned Bend 2.0.39 toolchain unless deliberately migrating and revalidating.
Read `bend guide` and `bend guide shaders` before changing language or parallel code.

Author policy, state machines, examples, tests, and proofs in Bend 2. The two
user-approved native boundary exceptions below are narrowly scoped. Generated
backend C/JavaScript and native binaries belong outside the source package.

The user-approved exception is `contrib/rclone/go/`: keep only the Go interface
adapter required by rclone and its transport checks there. Policy, authority,
protocol semantics, and reference-service behavior remain in Bend under the
same contribution. Do not introduce a root Go module or a core dependency on it.

The user also approved `contrib/native-hosts/` for native filesystem and host
bindings: C/C++ OS ABI, resource/handle lifetimes, necessary pinned Bend runtime
ports, a small JavaScript invocation/I/O harness, and native packaging or probes
that Bend cannot express. Keep an explicit source and trust inventory. Windows,
Linux, and Genode bindings may translate native facts and perform admitted effects;
they must not implement policy, grants, label decisions, accounting, replay rules,
or alternate release decisions. The authoritative state and decisions stay in Bend.
No root Go module or additional policy engine is permitted. This source exception
does not waive native acceptance tests or establish production host qualification.

Run `bend Tests.bend`, native tests, and `bend PROOF.bend` after meaningful security
changes. Use `--verdict` when the documented Lean kernel toolchain is available.
Report proof and GPU verification limits accurately; a CPU fallback is not a GPU test.

Do not add unsafe definitions, proof holes, unchecked array indexes, alternate
release routes, automatic declassification, or caller-controlled authority facts.
Keep original-graph verification independent of solver work lists. Revalidate
capabilities, epochs, inherited restrictions, budgets, and exact scope at commit.

Changes to a security law require an explicit rationale. Preserve the stated
invariants; do not weaken a law merely to make a changed implementation pass.

## Code and examples

Keep modules focused and use named helpers for policy bits, identities, and
scenario facts. Comments should explain authority, invariants, edge direction,
and failure behavior rather than restating expressions. Document public entry
points and distinguish them from exported implementation helpers.

Examples belong in `examples/`; root entry points may delegate to them. Keep
them independent of `*Tests.bend` and `Test.bend`. Mark synthetic authority records
clearly, exercise both permitted and denied outcomes, and exit nonzero when an
expected outcome changes. Keep commands, explanations, and captured outputs in
sync. Do not present example record construction as an authenticated issuer.

When a cleanup is intended to change comments only, compare the implementation
tokens with the previous revision as well as running the appropriate checks.
Keep the source manifest and verification record aligned with the delivered tree.

## Host platforms

Read docs/PLATFORMS.md before changing native boundaries. Genode is the capability
reference; direct Linux, native Windows, and a future kernel using Drift are
separate targets. Preserve one Bend policy/verification implementation. A native
capability, descriptor, handle, or driver token is not a portable credential, and
bearer possession alone does not establish the original caller's identity.

Keep host qualification distinct from library tests. Require real confinement,
delegation, revocation, artifact, and recovery evidence for each claimed profile.
WSL is Linux execution evidence. Drift supplies drivers, not the future kernel's
authority boundary. An unimplemented runtime port or missing native control must
not be hidden by a successful model test or CPU fallback.

## Specifications

Read openspec/README.md and the relevant baseline specifications before changing
behavior. Keep current contracts in openspec/specs/ and proposed behavior in
openspec/changes/. Update matching traceability with named tests or explicit
reviewed-only gaps. Do not mark proposed host adapters or acceptance scenarios
as implemented merely because their specifications validate.

Validate document changes with OpenSpec 1.16.0:
`openspec validate --all --strict --no-interactive`.
This is structural validation, separate from the Bend tests and proof checks.

Lead new feature documentation with a concrete example and the current gap.
Link each acceptance claim to its exact contract and evidence; preserve failed
and incomplete outcomes. Use docs/FEATURES.md for the reader's path and
openspec/FEATURE-ACCEPTANCE.md for cross-feature qualification. Do not introduce
a new documentation framework merely to publish a specification.

The proposed controlled-disclosure profile is not implemented. Keep ordinary v1
derivation monotone. A future release view must retain original policy/provenance
and a separately authenticated effective-policy transition; never clear labels
or strip a release chain to fit a legacy record. Confidentiality authority cannot
waive integrity, payment, operation, or sink-effect obligations.

## Development tooling under `utils/`

`utils/board/` (a Bun and Datastar dev board that reads specs, explainer
pages, and lane worktrees read-only) and `utils/nix/` with the root
`flake.nix` (the pinned toolchain, reproducible builds, and checks) are
development tooling, not Writ implementation. The core never depends on
them, they make no authority or verification claim, and the contribution
rules above still apply to anything they touch. Keep them out of the
library's source set and the test suite.
