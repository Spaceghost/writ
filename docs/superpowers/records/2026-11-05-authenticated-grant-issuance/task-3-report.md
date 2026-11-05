# Task 3 report: revision-checked registration and revocation (task 1.3; GI-005)

Status: DONE_WITH_CONCERNS. The concerns are the check count and one scope decision about derived grants; nothing is blocked.

## Files

- `Issuance.bend`:
  - New `Revocation (GI-005)` section with `revoke`, a public entry point.
  - New `Usability (GI-005)` section with `current`, a public entry point. It adds `Grant` accessors, `Grant.equal` and `Ids.equal`.
  - `grants_valid` and `valid` moved to a closing `Structural validity` section, because the new backing clause needs `find_stored`, which Bend resolves in order. `valid` gains the `grant_backed` clause.
  - Header: `from` on revocation, the usability paragraph, `revoke`/`current` in the public entry points, and the "Laws" paragraph naming the three laws and their rationale.
  - Comment updates on `Stored`, `Change` and `register`.
  - No Task 1 or Task 2 gate, order or reason changed. `register` keeps the outer `revision_current` match from Task 2.
- `IssuanceTests.bend`: revision fixtures (commented as synthetic) and a `revision()` section of 53 checks. `main` calls `submission()`, `registration()` and `revision()`, and prints `Issuance: 146 checks passed`.
- `LAWS.bend` and `PROOF.bend`: two imports and three laws with proofs, all additions. `git diff master -- LAWS.bend PROOF.bend` shows no removed line.
- `openspec/changes/add-authenticated-grant-issuance/tasks.md`: box 1.3 checked, with the test names cited.
- `Tests.bend`, the count pins and every do-not-touch file are unchanged.

## `revoke(state, expected_revision, from: Principal, approval_id)`

`revoke` first matches on `revision_current` (`revoke_current`). It then matches on `Guard.all(revoke_checks(...))`, and the reason is `Gates.reason` over the same `revoke_gates` list, as in the other transitions. Every lookup goes through Task 2's `find_stored`, so an absent or ambiguous id never resolves to a record.

| # | Check | Reason |
|---|---|---|
| 1 | `revision_current` | StaleRevision |
| 2 | `stored_present`: the id names exactly one stored approval | MissingApproval |
| 3 | `issued_by`: `from` equals the approval's recorded issuer (`claim_matches`) | Unauthenticated |
| 4 | `held_by_authority`: the current directory names `from` the authority for the approval's domain in its own namespace (`approval_authority`: read for a source approval, write for a write approval) | NotAuthority |
| 5 | `not_yet_revoked` | Revoked |

The recorded issuer was bound to the authenticated submitter at submission, so gate 3 means only that principal may revoke. A consumed approval may be revoked, because that is how a registered grant is withdrawn. Placements are not consulted, since revocation only removes authority. Revoking twice is denied (Revoked) rather than advancing the revision for no change; the brief does not ask for this, and it only adds a denial.

On acceptance, `commit_revocation`:
- sets `revoked` on that approval only (`revoke_in`/`mark_revoked`);
- keeps `consumed_by`, `seen`, `grants` and `next_id`;
- advances the revision once;
- returns the revoked approval's id as the change id.

Every denial returns the supplied state.

## `current(state, grant, now) -> Bool`

The grant argument is an untrusted claim. `current` calls `current_within(fuel = grants(state), parent, found, state, grant, now)`, where `parent` is the grant's parent id and `found` is that id's `find_grant` lookup. Both call sites compute these from the grant being checked; this is needed because Bend forbids matching on a computed value. The fuel loses one grant per step, so the walk is structural, and a cycle runs out of fuel and denies.

- `own_checks` (every grant):
  1. `registered_as`: `find_grant(grants, id)` resolves to exactly one record, and it is `Grant.equal`, in every field, to the supplied grant.
  2. `scope_wellformed(scope, live)`: the stamp is live, the subject is named and the manifest is nonempty.
  3. `now < valid_until`.
- `root_checks` (parent 0), each re-derived from this state through Task 2's `Requirement` machinery against `grant_request(grant)`:
  1-2. write / sources `consumed_by` = this grant's id;
  3. `ids_distinct`;
  4-5. write / sources unrevoked;
  6-7. write / sources issuer still the directory authority;
  8-9. write / sources still placed;
  10. `sources_cover_manifest`;
  11. write destination = plan destination;
  12. write domain = scope write domain;
  13-14. write / sources `scope_equal`;
  15-16. write / sources `rights_within`;
  17-18. write / sources `now < approval.valid_until`.
- A derived grant (parent > 0) needs all of the following:
  - the parent is found exactly;
  - `own_checks` holds;
  - `derived_checks` holds: `scope_equal` with the parent, `rights_within` the parent's, and `lifetime_within` the parent's;
  - the parent is `current_within` in turn.

  A missing or ambiguous parent, or exhausted fuel, denies.

`current` does not check whether the grant's lifetime is within each approval's. At use, that only matters through expiry, and gates 17-18 test expiry directly, as the brief asks. Both `own_checks` and `root_checks` are `Guard.Checks` lists, so `failed_check_denies` covers them.

`valid(state)` now also requires `grant_backed` of each grant:
- For a root grant, its write approval and every source approval exist and are consumed by exactly that grant.
- For a derived grant, its parent is a grant registered before it (later in the newest-first list), so no chain is circular.

A grant copied into `empty(...)` fails `allocated`. A grant copied into a state whose approvals do not back it fails `grant_backed`.

## Denial cases and their checks (section `revision`)

Every denial uses `denied`, which compares with `Error.equal` and full `State.equal` against the input. The revision is therefore unchanged on every denial.

- The race at revision 7 → 8:
  - "GI-005 approvals 1 and 2 are valid for registration at revision 7" (seven public submissions);
  - "GI-005 the source authority revokes approval 1, moving the state to revision 8";
  - "GI-005 revocation during issuance: registration validated at revision 7 against state at revision 8 denied StaleRevision";
  - "GI-005 the raced registration exposes no grant for the plan and no current grant";
  - "GI-005 registration revalidated at revision 8 against the revoked approval denied Revoked".
- A grant withdrawn by revocation:
  - "GI-005 the registered grant is current at registration time";
  - "GI-005 the registered grant is not current after its source approval is revoked", and the same "... after its write approval is revoked".
- Revocation commit:
  - "GI-005 revocation advances the revision once, keeps the approval's consumption, the grant record and the seen serials, and leaves a valid state";
  - "GI-005 revoking approval 1 leaves approval 2 unrevoked".
- `revoke` denials:
  - "GI-005 revocation of source approval 1 by the write authority, not its issuer, denied Unauthenticated";
  - "GI-005 revocation by the source issuer after the monitor removed it from the directory denied NotAuthority", and the same for "the write issuer";
  - "GI-005 revocation validated at revision 2 against state at revision 3 denied StaleRevision";
  - "GI-005 the revocation check list alone is false at a stale revision";
  - "GI-005 revocation of an approval id that does not exist denied MissingApproval";
  - "GI-005 revoking an already revoked approval denied Revoked".
- Replay:
  - "GI-005 replay: a second registration citing the consumed approvals denied Replay";
  - "GI-005 replay: re-submitting a revoked approval's serial denied Replay".
- Copies:
  - "GI-005 the grant copied into a fresh empty state is not valid and not current";
  - "GI-005 the grant in a state that lacks its approvals is not valid and not current";
  - "GI-005 the grant copied into a state whose approvals are unconsumed is not valid and not current";
  - "GI-005 the grant whose write approval is consumed by another grant is not valid and not current", and the same for "its source approval".
- Epoch advance:
  - "GI-005 after the monitor advances the authority epoch the old grant is not current";
  - "GI-005 after the epoch advance a registration with the old scope denied StaleEpoch".
- Other `current` branches:
  - "GI-005 the grant is current before its valid_until and not at it";
  - "GI-005 a grant record with the registered id but another token is not current";
  - "GI-005 a grant id registered twice resolves to no grant and is not current";
  - directory removal, for the source and the write authority;
  - placement moves, for the source and the destination;
  - "GI-005 the synthetic backing state reproduces the registered grant as current";
  - "GI-005 a grant citing one source approval for two manifest entries is not current";
  - "GI-005 a two-source grant is current, and its record with the source ids reordered is not";
  - stored write approval naming destination 20v9;
  - stored write approval for write domain 6 whose scope names write domain 9;
  - write-side and source-side scope that differs in invocation;
  - rights 7 over the source approval's 3, and over the write approval's 3;
  - a grant outliving its write approval, and its source approval, checked at that approval's valid_until.
- Derived (a synthetic grant 4 of grant 3; `derive` arrives in Task 4):
  - "GI-005 a synthetic derived grant of the registered grant is current and valid";
  - "GI-005 revoking the parent's source approval makes the derived grant not current";
  - "... whose parent does not exist is not current and not valid";
  - "... that is its own parent is not current and not valid";
  - "... with rights 7 over its parent's 3 is not current";
  - "... outliving its parent is not current";
  - "... whose scope differs from its parent's is not current";
  - "... is current before its own valid_until and not at it while its parent still is";
  - "GI-005 a derived grant record that the state never registered is not current".

## Removal map

The harness is `/tmp/claude-1000/-mnt-MediaVolume-Media-src-github-com-spaceghost-writ/55038343-2e0b-4235-a6a8-7c68c6dd1f50/scratchpad/scripts/mutate4.py`. It runs on a scratch copy in `scratchpad/mut4` and runs `bend IssuanceTests.bend` once per mutant. A gate mutant replaces one condition with `True{}`.

| Removed branch | First failing check |
|---|---|
| revoke gate 1 StaleRevision | GI-005 the revocation check list alone is false at a stale revision |
| revoke gate 2 MissingApproval | GI-005 revocation of an approval id that does not exist denied MissingApproval |
| revoke gate 3 Unauthenticated | GI-005 revocation of source approval 1 by the write authority, not its issuer, denied Unauthenticated |
| revoke gate 4 NotAuthority | GI-005 revocation by the source issuer after the monitor removed it from the directory denied NotAuthority |
| revoke gate 5 Revoked | GI-005 revoking an already revoked approval denied Revoked |
| revoke outer revision match only | SURVIVED (equivalent: gate 1 denies the same input with the same reason and state) |
| revoke outer match AND gate 1 | GI-005 revocation validated at revision 2 against state at revision 3 denied StaleRevision |
| revoke denial carries committed state | GI-005 revocation of source approval 1 by the write authority, not its issuer, denied Unauthenticated |
| revoke outer branch carries committed state | GI-005 revocation validated at revision 2 against state at revision 3 denied StaleRevision |
| mark_revoked revokes every approval | GI-005 revoking approval 1 leaves approval 2 unrevoked |
| mark_revoked never revokes | GI-005 registration revalidated at revision 8 against the revoked approval denied Revoked |
| mark_revoked clears consumed_by | GI-005 revocation advances the revision once, keeps the approval's consumption, ... |
| commit_revocation: revision not advanced | GI-005 the source authority revokes approval 1, moving the state to revision 8 |
| commit_revocation: next_id advanced | GI-005 revocation advances the revision once, ... |
| commit_revocation: seen dropped | GI-005 revocation advances the revision once, ... |
| commit_revocation: grants dropped | GI-005 revocation advances the revision once, ... |
| commit_revocation: change id 0 | GI-005 the source authority revokes approval 1, moving the state to revision 8 |
| issued_by None arm <- True | SURVIVED (equivalent: gate 2 denies every None first) |
| held_by_authority None arm <- True | SURVIVED (equivalent, same reason) |
| not_yet_revoked None arm <- True | SURVIVED (equivalent, same reason) |
| approval_authority source arm <- True | GI-005 revocation by the source issuer after the monitor removed it from the directory denied NotAuthority |
| approval_authority write arm <- True | GI-005 revocation by the write issuer after the monitor removed it from the directory denied NotAuthority |
| own 1 registered_as | GI-005 a grant record with the registered id but another token is not current |
| own 2 scope_wellformed at live | GI-005 after the monitor advances the authority epoch the old grant is not current |
| own 3 unexpired grant | GI-005 the grant is current before its valid_until and not at it |
| root 1 write consumed by grant | GI-005 the grant whose write approval is consumed by another grant is not valid and not current |
| root 2 sources consumed by grant | GI-005 the grant whose source approval is consumed by another grant is not valid and not current |
| root 3 ids_distinct | GI-005 a grant citing one source approval for two manifest entries is not current |
| root 4 write Unrevoked | GI-005 the registered grant is not current after its write approval is revoked |
| root 5 sources Unrevoked | GI-005 the registered grant is not current after its source approval is revoked |
| root 6 write StillAuthority | GI-005 the grant is not current after the monitor removes its write authority from the directory |
| root 7 sources StillAuthority | GI-005 the grant is not current after the monitor removes its source authority from the directory |
| root 8 write StillPlaced | GI-005 the grant is not current after its destination moves to write domain 5 |
| root 9 sources StillPlaced | GI-005 the grant is not current after its source object moves to read domain 9 |
| root 10 sources_cover_manifest | GI-005 a two-source grant is current, and its record with the source ids reordered is not |
| root 11 write DestinationIsPlans | GI-005 a grant whose stored write approval names destination 20v9 under a plan naming 20v8 is not current |
| root 12 write DomainIsScopes | GI-005 a grant whose stored write approval for write domain 6 names write domain 9 in its scope is not current |
| root 13 write SameScope | GI-005 a grant whose write approval's scope differs in invocation is not current |
| root 14 sources SameScope | GI-005 a grant whose source approval's scope differs in invocation is not current |
| root 15 write RightsCover | GI-005 a grant with rights 7 over its write approval's 3 is not current |
| root 16 sources RightsCover | GI-005 a grant with rights 7 over its source approval's 3 is not current |
| root 17 write StillUnexpired | GI-005 a grant outliving its write approval is not current at the write approval's valid_until |
| root 18 sources StillUnexpired | GI-005 a grant outliving its source approval is not current at the source approval's valid_until |
| derived 1 scope_equal | GI-005 a derived grant whose scope differs from its parent's is not current |
| derived 2 rights_within | GI-005 a derived grant with rights 7 over its parent's 3 is not current |
| derived 3 lifetime_within | GI-005 a derived grant outliving its parent is not current |
| current_within fuel exhausted <- True | GI-005 the raced registration exposes no grant for the plan and no current grant |
| current_within missing parent <- True | GI-005 a derived grant whose parent does not exist is not current and not valid |
| current_within root arm <- True | GI-005 the registered grant is not current after its source approval is revoked |
| current_within ancestor not walked | GI-005 revoking the parent's source approval makes the derived grant not current |
| current_within derived own checks dropped | GI-005 a derived grant is current before its own valid_until and not at it while its parent still is (survived the first run; killed after the two checks were added) |
| registered_as None arm <- True | GI-005 a grant id registered twice resolves to no grant and is not current |
| Grant.equal ignores token | GI-005 a grant record with the registered id but another token is not current |
| first_grant: first match wins | GI-005 a grant id registered twice resolves to no grant and is not current |
| find_grant: ambiguity ignored | GI-005 a grant id registered twice resolves to no grant and is not current |
| consumed_by_grant None arm <- True | GI-005 the grant in a state that lacks its approvals is not valid and not current |
| consumed_by_grant ignores grant id | GI-005 the grant whose write approval is consumed by another grant is not valid and not current |
| grant_backed root arm <- True | GI-005 the grant in a state that lacks its approvals is not valid and not current |
| grant_backed root write side dropped | GI-005 the grant whose write approval is consumed by another grant is not valid and not current |
| grant_backed root source side dropped | GI-005 the grant whose source approval is consumed by another grant is not valid and not current |
| grant_backed derived arm <- True | GI-005 a derived grant whose parent does not exist is not current and not valid |
| grants_valid drops grant_backed | GI-005 the grant in a state that lacks its approvals is not valid and not current |
| grant_request rights 0 | GI-005 a grant with rights 7 over its source approval's 3 is not current |

The total is 63 mutants: 59 killed and 4 equivalent. The first run killed 58, and the derived own-checks survivor was closed by "... is current before its own valid_until and not at it while its parent still is" and "... a derived grant record that the state never registered is not current". Every denial gate of `revoke` and every conjunct of `current` is pinned.

Separately, I applied Task 2's surviving "register outer revision match only" mutant (`register_current(True{}, ...)`). `bend PROOF.bend` now fails on it (`SOME PROOFS FAIL`, at `issuance_stale_revision_rejects`), so the new law pins the outer match that the tests could not.

## Laws (nine in `LAWS.bend`: six unchanged plus three)

- **`issuance_denied_preserves_state`**: `Issuance.Change.state(Issuance.Rejected{state, reason}) == state`.
  - Rationale: it fixes the denial contract that every issuance transition relies on, so a denied or raced registration exposes no new state.
  - Proof: `{==}`, by computation.
  - It does not prove that any transition chose the denial; the tests show that.
- **`nat_eq_successor_false`**: `Nat.is_eq(n, 1n+n) == False{}`.
  - It is auxiliary and says nothing about issuance.
  - Proof: induction like `nat_lt_successor`. The base case is `{==}`, and the step is the hypothesis, because `Nat.cmp(1n+p, 2n+p)` reduces to `Nat.cmp(p, 1n+p)`.
- **`issuance_stale_revision_rejects`**: for all `state`, `request`, `now` and `token`, `Issuance.Change.accepted(Issuance.register(state, 1n+Issuance.revision(state), request, now, token)) == False{}`.
  - Rationale: this is the GI-005 race. A registration validated at revision r cannot commit after any transition has moved the state.
  - Proof:
    1. Match `state` to expose `revision`.
    2. `register` then unfolds to `register_current(Nat.is_eq(revision, 1n+revision), ...)`.
    3. Rewrite that scrutinee with `Equal.sym(..., nat_eq_successor_false(revision))`.
    4. The `False{}` branch is `Rejected`, and `{==}` closes the goal.
  - Coverage: the successor revision only.
  - Not claimed: the denial reason, and the host's atomic, serialized install (AB-006).

All three proofs are complete. There are no holes and no `unsafe` definitions. The rationale appears in the comment above each law and in the `Issuance.bend` header. Earlier, in a scratch copy, I checked that the gate is real: changing the expected `False{}` to `True{}`, or replacing the induction step with `{==}`, both print `SOME PROOFS FAIL`.

## Verification (Bend 2.0.39, this tree)

- `bend Issuance.bend --check-only`: `ALL PROOFS CHECK` / `Use --verdict for mathematical validity.`
- `bend Tests.bend` (exit 0, 0 FAIL). Last lines:
  ```
  Issuance: 146 checks passed
  ...
  PASS: equality-conflict oracle, topology 63
  Property: 324 checks passed; 320 graph cases, each checked against CPU and Bend parallel producers
  ALL LIBRARY TESTS PASSED
  ```
  The PASS count is 928 (875 `PASS:` + 53 `PASS `), which is 782 + 146 new checks (875 after Task 2, plus 53).
- `bend PROOF.bend` (exit 0): `ALL PROOFS CHECK` / `Use --verdict for mathematical validity.` There are 9 laws.
- `git diff master -- LAWS.bend PROOF.bend` has no `-` lines.
- `bend PROOF.bend --verdict` was not run to a result. It stops with "the kernel did not build (lean: Executable not found in $PATH)", so the documented Lean kernel is not available here. There was no native build and no GPU test; this was a JS-checker run only. No count pin was touched.

## Concerns

1. **Count.** There are 53 checks against the estimate of about 14, so the totals are 146 Issuance checks and 928 overall, not about 830. `current` re-derives about 24 conditions. Under the removal standard each needs a test that fails when it is removed, and most write-side and source-side pairs need one-sided synthetic fixtures.
2. **The derived-grant arm is implemented ahead of Task 4.** The brief's `current` requires every ancestor to be current, so `current_within` already walks the parent chain and applies the attenuation checks:
   - same scope, rights within the parent's and lifetime within the parent's;
   - fuel-bounded, with cycles denied;
   - in `valid`, a derived grant's parent must be registered before it.

   The tests use a synthetic grant 4, because `derive` does not exist yet. Task 4 adds `derive` and may want the derived arm to also require that a child cites no approvals. That is not checked now; citations on a derived grant are ignored and confer nothing.
3. **Stricter than the brief.** None of these widens anything.
   - Revoking an already revoked approval is denied (Revoked).
   - `current` also revalidates the following, beyond the brief's list:
     - placements;
     - manifest coverage;
     - distinct ids;
     - the write approval's destination and domain;
     - exact scope;
     - rights.

     This follows the plan's rule that projections revalidate placements and exact scope at every use. Approval and grant lifetimes are revalidated as expiry only.
4. **Moving `grants_valid` and `valid` to the end of `Issuance.bend`** is a code move that Bend's in-order resolution requires. Their earlier conjuncts are unchanged.
5. **The `--verdict` kernel check was not available** (no Lean toolchain).
