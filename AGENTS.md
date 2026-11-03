# Working on Writ

Use the pinned Bend 2.0.39 toolchain unless deliberately migrating and revalidating.
Read `bend guide` and `bend guide shaders` before changing language or parallel code.

All authored implementation, tests, examples, and proofs stay in Bend 2. Generated
backend C/JavaScript and native binaries belong outside the source package.

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

## Specifications

Read openspec/README.md and the relevant baseline specifications before changing
behavior. Keep current contracts in openspec/specs/ and proposed behavior in
openspec/changes/. Update matching traceability with named tests or explicit
reviewed-only gaps. Do not mark proposed host adapters or acceptance scenarios
as implemented merely because their specifications validate.

Validate document changes with OpenSpec 1.16.0:
`openspec validate --all --strict --no-interactive`.
This is structural validation, separate from the Bend tests and proof checks.
