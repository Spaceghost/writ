# Task 2 report: structural invariants in HostBinding `valid`

Status: DONE (commit c058ed5 on lane/binding-gaps, not pushed)

## Change (HostBinding.bend)
- Clause (a): `bindings_valid` also requires `Bool.not(bound_handle_exists(rest, handle))` (new helper).
  Comment: two objects on one handle would let a reference to either exercise one Writ grant under the
  other object's owner/kind/delegation records, and closing either closes both (close_doomed).
- Clause (b): new `mints_valid(objects, aliases, delegations)` in `valid`: every LIVE object (one with an alias
  at its current generation, `current_alias_exists`) has at most one uncopied alias. `single_minter` judges
  each alias by calling `minter` itself (on a one-alias list) and the tail by `minter` on the tail, so the
  invariant and the refund/close rule share one definition. New helper `minter_absent`.
- Why gated on liveness: destruction prunes the copies' delegation nodes and leaves their aliases stale, so
  a destroyed object's stale copies read as uncopied (shared_closed, chain_closed, ...). Refund gates on
  `current_alias_exists` and close resolves a current alias first, so neither consults `minter` for a
  destroyed object. All aliases of a live object count whatever their generation, because `minter` reads all.
  Mutation: dropping the liveness gate fails `GA-004 after close the owner's alias is stale` (valid rejects
  the reachable post-close state).
- `current_alias_exists`, `copied`, `choose_holder`, `minter` moved above `valid` (defs must precede use);
  their code is token-identical (checked mechanically), only `minter`'s comment extended. `valid`'s clause list
  updated. No law/PROOF change; no laws reference these defs.

## Fixtures fixed (violated clause (b) by construction)
- `generations_state` (GA-001): stale alias 2 had no node beside current alias 1 on live object 1. Now carries
  `generations_copy()` = node 1 -> 2 (reader, read), i.e. alias 2 is a stale copy. All GA-001 outcomes and
  vectors unchanged. The old shape is kept as `unrecorded_generations` and asserted invalid.
- `forged_holder` (GA-005): was `without_delegations(shared())`, leaving R's alias 2 and W's alias 3 both
  uncopied on object 2; `minter` would pick W (list head) for refund and close authority. Now also drops R's
  alias 2 (`with_aliases`), so W holds the only, unrecorded reference. GA-005-1 and the delegate-onward check
  unchanged (SubjectMismatch). The old shape is kept as `unrecorded_copy` and asserted invalid.
- New test helpers: `with_aliases`, `with_bindings`, `generations_copy`; forged `shared_handle` (opened() with
  object 2 bound to handle 1); transition `shared_session_close`.

## Tests added (11, all in ga008_checks)
rebuilding a committed binding table keeps the state valid (control); two objects bound to one Frontend handle
are rejected by valid; a transition on a shared-handle state is denied StaleRevision; two uncopied aliases for
one live object are rejected by valid; a close on a two-minter state is denied StaleRevision and refunds
nothing; a stale uncopied alias beside a current one on a live object is rejected by valid; a destroyed
object's stale copies without records stay valid; delegate, open, and minter close outputs satisfy valid
(attenuated_shared, current_open, retry, minter_close); derived and delegatee close and revoke outputs satisfy
valid; the three-level Session close and the three-level chain close satisfy valid; a three-level Session close
over a delegated copy satisfies valid and refunds all three objects (new sequence).
- Note: session_closed and chain_closed already had `valid` checks (GA-004/GA-011); the explicit check repeats
  them in GA-008, and the new shared_session_close adds a three-level close with a pruned copy.
- Count line 131 -> 142 checks, 41 vectors (142 `Test.check(`, 41 `vector(` in the file). No existing check
  name or assertion changed: PASS lines vs stored verification/tests-js.txt differ only by additions
  (5 from Task 1, 11 here). VECTOR lines equal stored host-binding-vectors.txt plus Task 1's GA-005-7.
- Mutation checks: against HEAD's HostBinding.bend, the handle test fails; with only clause (a) removed the
  handle test fails; with only `mints_valid` removed the two-minter test fails.

## Traceability
- GA-008 row: implementation cites `bound_handle_exists` / `mints_valid` / `single_minter` / `minter`, all 11
  new check names, coverage boundary explaining what each clause excludes, the live-only scope, that forged
  shapes are hand-built and preservation is shown on sequences not proved, and that this closes the parked
  structural-invariant item.
- GA-001 row: why alias 2 is now a recorded copy. GA-005 row: Task 1 deferred host-obligation clause appended
  verbatim, plus the forged_holder change. GA-009 row: 40 -> 41 vectors. Fixture-domain sentence split.
- PH-004 row untouched (still says no duplicate-id fixture; duplicate ids remain untested).

## Verification (final runs, after the last edit)
- `bend HostBinding.bend --check-only`, `bend HostBindingTests.bend --check-only`, `bend DataOS.bend --check-only`:
  ALL PROOFS CHECK.
- `bend Tests.bend` (JS): ALL LIBRARY TESTS PASSED, exit 0, 780 PASS, 41 VECTOR (was 769/41).
- Native: build to ../writ-build/binding-gaps/tests-native, run `+RTS --threads 4 --gpu off`: ALL LIBRARY
  TESTS PASSED, exit 0, 780 PASS, 41 VECTOR; VECTOR lines byte-identical to JS. CPU run, not a GPU test.
- `bend PROOF.bend`: ALL PROOFS CHECK. `--verdict` not run (no Lean toolchain on this host).
- OpenSpec 1.16.0 strict: 43 passed, 0 failed.

## Not done (Task 3 scope)
Stored runs, vectors file, VERIFICATION.md, environment.txt, manifest not regenerated (now 780/41).
