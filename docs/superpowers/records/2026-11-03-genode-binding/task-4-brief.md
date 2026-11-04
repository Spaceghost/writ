### Task 4: Laws and proofs

Append to `LAWS.bend` two laws with a comment explaining what each does and does not cover:

- `binding_denied_preserves_state`: for any `State` `s` and any `Error` `r`, the state of `Rejected{s, r}` equals `s` (mirror the shape of `denied_ledger_preserves_state`; if your `Change` accessors make this trivially `{==}`, say so in the comment and keep it; it documents the contract).
- `generation_bump_monotone`: for any `Nat` `g`, `Nat.is_lt(g, 1n+g)` is `True{}` (or the equivalent statement over your bump helper if it is a named def).

Prove both in `PROOF.bend` as `def Laws.<name>(...)`. Run `bend PROOF.bend`; it must print `ALL PROOFS CHECK`. Try `bend PROOF.bend --verdict` once and record its output verbatim, including a failure to start the Lean kernel if that is what happens; do not claim a verdict that did not run.

Acceptance: `ALL PROOFS CHECK`; the `--verdict` attempt recorded honestly.

