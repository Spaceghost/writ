# Task 4 report: HostBinding laws and proofs

Status: DONE
Commit: f367256 "State and prove HostBinding denial and generation-bump laws" (lane/genode-binding, not pushed)
Files changed: LAWS.bend, PROOF.bend only. HostBinding.bend untouched.

## Laws added (LAWS.bend, imports ./HostBinding.bend as HostBinding)
1. `binding_denied_preserves_state`: for state: HostBinding.State, reason: HostBinding.Error,
   `{HostBinding.Change.state(HostBinding.Rejected{state, reason}) == state : HostBinding.State}`.
   Mirrors denied_ledger_preserves_state. Trivially `{==}` by the accessor; the comment says it
   documents the denial contract and does NOT assert any transition chose the denial path, the
   reason is correct, or an accepted change is valid.
2. `nat_lt_successor` (auxiliary, new): for n: Nat, `{Nat.is_lt(n, 1n+n) == True{} : Bool}`.
   Comment says it is an arithmetic helper and says nothing about HostBinding alone.
3. `generation_bump_monotone`: stated over the named helper `HostBinding.bumped` (exists in
   HostBinding.bend, used by `destroy`):
   for object: HostBinding.Object,
   `{Nat.is_lt(HostBinding.object_generation(object), HostBinding.object_generation(HostBinding.bumped(True{}, object))) == True{} : Bool}`.
   Comment: covers the bump helper only; not that destroy/bind_close/revoke select the right
   objects, nor that generations are never reset elsewhere.

Rationale: these are new laws; no existing law changed or weakened.

## Proofs (PROOF.bend, imports HostBinding)
- binding_denied_preserves_state: `{==}`.
- nat_lt_successor: induction on n; base `{==}`; step returns the hypothesis directly, since
  `Nat.cmp(1n+p, 2n+p)` reduces to `Nat.cmp(p, 1n+p)` (no rewrite needed).
- generation_bump_monotone: match the Object, then `Laws.nat_lt_successor(generation)`.
- No `?TODO`, no `@unsafe`. Sanity check: substituting `nat_lt_successor(id)` for `(generation)`
  made the checker fail at Laws.generation_bump_monotone, so the law is genuinely checked; reverted.

## Verification
- `bend PROOF.bend`: ALL PROOFS CHECK (6 laws).
- `bend PROOF.bend --verdict` (verbatim, exit 1):
  `Error: BendTT infrastructure: the kernel did not build (lean: Executable not found in $PATH: "lean"); --verdict needs Lean v4.34.0 (elan toolchain leanprover/lean4:v4.34.0), or $BENDTT set to a built kernel`
  No Lean-kernel verdict was obtained.
- `bend Tests.bend`: ALL LIBRARY TESTS PASSED (exit 0, no FAIL lines).
- `bend DataOS.bend --check-only`: exit 0.

## Concerns
- Law 2 is stated over `bumped` (named helper), plus an extra auxiliary law `nat_lt_successor`
  rather than a private helper def; it adds one law to the gate.
- `bumped` is not labelled "Exported helper" in HostBinding.bend's comments; the law now depends
  on its name. Left untouched per the brief.
- --verdict unavailable (no Lean 4.34.0 on PATH).
