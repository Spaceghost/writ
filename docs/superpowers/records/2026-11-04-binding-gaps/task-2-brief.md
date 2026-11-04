### Task 2: Structural invariants `valid` was trusting reachable states for

Add two clauses to `valid`: (a) every `Binding.handle` is unique across bindings (no two objects bound to one Frontend handle); (b) every object has at most one non-copy (minted) alias, which the refund rule assumes. Confirm every existing fixture still passes `valid` (fix fixtures only if they violated the new clauses by construction; say which). Add tests: a hand-built state with two bindings on one handle is rejected by `valid`; a hand-built state with two minted aliases for one object is rejected; every transition's success output still passes `valid` on the existing scenario sequences (reuse the `valid` checks already in the suite; add one for the three-level close). Update the GA-008 row.

Acceptance: `valid` rejects both forged shapes; suite green on both backends.

