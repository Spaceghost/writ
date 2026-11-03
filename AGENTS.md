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

## Specifications

Read openspec/README.md and the relevant baseline specifications before changing
behavior. Keep current contracts in openspec/specs/ and proposed behavior in
openspec/changes/. Update matching traceability with named tests or explicit
reviewed-only gaps. Do not mark proposed host adapters or acceptance scenarios
as implemented merely because their specifications validate.

Validate document changes with OpenSpec 1.16.0:
`openspec validate --all --strict --no-interactive`.
This is structural validation, separate from the Bend tests and proof checks.
