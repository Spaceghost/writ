# Task 1 report: authenticated issuer and subject records (task 1.1; GI-001, GI-004 records)

Status: DONE_WITH_CONCERNS (concerns are small and listed at the end; nothing is blocked).

## Files

- Created `Issuance.bend` (the issuer model) and `IssuanceTests.bend` (section `submission`, 24 checks).
- `Tests.bend`: one import (`./IssuanceTests.bend as Issuance`) and one `Issuance.main()` line, placed after `Facade.main()`.
- `openspec/changes/add-authenticated-grant-issuance/tasks.md`: box 1.1 checked, citing the test names.
- No count pin changed (README, INSTALL, nix, CI workflow, VERIFICATION.md untouched). `LAWS.bend`, `PROOF.bend`, `DataOS.bend` and every file on the plan's do-not-touch list are untouched.

## Records and helpers added (Issuance.bend)

Types:
- `Principal{id}`: the identity that the host's transport identity verification authenticated. It arrives only as the `from` parameter. Inside an approval it is only the `issuer` claim.
- `Authority` = `ReadAuthority{principal, domain: T.ReadDomain}` | `WriteAuthority{principal, domain: T.WriteDomain}`, listed in `Authorities`. These are separate namespaces.
- `Placement` = `SourceAt{object, domain: T.ReadDomain}` | `DestinationAt{object, domain: T.WriteDomain}`, listed in `Placements`.
- `Scope{plan: T.Plan, write_domain, subject}`.
- `SourceApproval{version, serial, issuer, source, domain, scope, rights, valid_until}` and `WriteApproval{version, serial, issuer, destination, domain, scope, rights, valid_until}`.
- `Approval` = `SourceEntry` | `WriteEntry`. `Stored{id, approval, consumed_by, revoked}` is in `Approvals`. Here `consumed_by` (0 = none) and `revoked` are bookkeeping that can only withdraw authority. They are set to 0/False on submission and are reserved for tasks 2 and 3.
- `Ids` and `Grant{id, token, scope, rights, valid_until, sources, write, parent}` in `Grants`. These are defined now so that `State` has its final shape. No transition creates a grant yet.
- `Serial{issuer, serial}` in `Serials`.
- `State{revision, next_id, live, directory, placements, approvals, grants, seen}`.
- `Error` (the closed set of 15 reasons from the plan) and `Change` (`Rejected{state, reason}` | `Changed{state, id}`).
- `Gates` (`Open` | `Gate{condition, reason, rest}`): one ordered list with two projections. `Gates.checks` gives a `Guard.Checks` for acceptance, and `Gates.reason` gives the first failing reason. Acceptance and reason therefore cannot drift apart, and `failed_check_denies` covers every gate.

Public entry points: `empty(live, directory, placements)`, `submit_source`, `submit_write`, `valid`, the `Change.accepted/state/reason/issued` accessors, and the state accessors.

Helpers (exported, not entry points):
- `claim_matches(from, issuer)` and `Principal.equal`.
- `is_read_authority` / `is_write_authority`, built on `read_entry` / `write_entry`. A read entry never matches a write query and the reverse.
- `source_domain` / `destination_domain` return `Maybe`. They give None when the object is unplaced, and also when it is placed twice in the same namespace (`first_read` / `first_write`, `source_placed` / `destination_placed`), so ambiguity denies instead of depending on order.
- `read_placed_in` / `write_placed_in`.
- `version_supported` (only 1n).
- `rights_valid` (delegates to `F.rights_valid`, i.e. within 7).
- `unexpired` (`now < valid_until`).
- `revision_current`.
- `manifest_contains`.
- `scope_wellformed`, which is the conjunction of `scope_manifest_named`, `scope_at_live` and `scope_subject_named`. `scope_fault` maps a failed `scope_wellformed` to StaleEpoch / SubjectMismatch / ScopeMismatch, in that order.
- `scope_equal` (Plan.equal plus write domain plus subject; for task 2, and used by the test-side equality).
- `serial_seen`.
- `commit_approval`.
- `approval_exists`, `grant_exists`, `allocated`, and the `*_valid` structural helpers.

Transitions:
- `submit_source` / `submit_write` first match on `revision_current`. This is the shape the planned Task 3 revision law needs. They then match on `Guard.all(source_checks | write_checks)`.
- Source denial order: StaleRevision, UnknownVersion, Unauthenticated, NotAuthority, WrongDomain, scope_fault (StaleEpoch / SubjectMismatch / ScopeMismatch), ScopeMismatch (source not in manifest), InvalidRights, Expired, Replay.
- Write order: the same up to scope_fault, then ScopeMismatch (destination is not the plan's destination version), ScopeMismatch (approval domain is not the scope's write domain), InvalidRights, Expired, Replay.
- On acceptance, the approval is stored under `next_id` (the change id), `(issuer, serial)` is recorded in `seen`, and `next_id` and the revision each advance once.

The module header documents the authority model, every trusted input (`from`, the monitor-installed state with its live stamp, directory and placements, `expected_revision` with atomic install, and `now`), that constructing a record authenticates nothing, the gate structure, the public entry points, and "Laws: none added".

## Tests (IssuanceTests.bend, section `submission`)

Every denial goes through `denied(change, input, reason)`, which checks `Error.equal` on the reason and a field-by-field `State.equal` against the supplied state. I sanity-checked `State.equal` in a scratch run: initial vs submitted is False, submitted vs both is False, and both vs both is True. The scratch file was deleted.

| Check name | Outcome |
|---|---|
| GI-001 synthetic directory and placements form a valid empty issuer state | valid |
| GI-001 source approval from its read authority is accepted as id 1 and advances the revision once | accepted, id 1, rev 1 |
| GI-001 forged source issuer: the write-domain-6 principal submitting a source approval for object 10 under its own identity denied NotAuthority | NotAuthority |
| GI-001 approval naming the true source authority as issuer but submitted by the write principal denied Unauthenticated | Unauthenticated |
| GI-001 read-domain-9 authority approving object 10 placed in read domain 5 denied WrongDomain | WrongDomain |
| GI-001 source authority submitting a destination-write approval denied NotAuthority | NotAuthority |
| GI-001 write-domain-5 authority does not control read domain 5: denied NotAuthority | NotAuthority |
| GI-001 read-domain-5 authority does not control write domain 5: denied NotAuthority | NotAuthority |
| GI-001 principal absent from the directory denied NotAuthority | NotAuthority |
| GI-001 object placed in two read domains resolves to none and is denied WrongDomain | WrongDomain (added) |
| GI-001 an object placed twice in one namespace is not a valid state | valid false (added) |
| GI-001 destination-write approval from its write authority is accepted as id 2 | accepted, id 2, rev 2 |
| GI-001 submitting both approvals registers no grant for the plan | grants empty, none for TF.plan() |
| GI-001 state after both submissions is structurally valid | valid |
| GI-001 source approval record version 2 denied UnknownVersion | UnknownVersion |
| GI-001 submission validated at revision 0 against state at revision 1 denied StaleRevision | StaleRevision |
| GI-001 source approval with rights 8 denied InvalidRights | InvalidRights |
| GI-001 source approval for an object outside the scope manifest denied ScopeMismatch | ScopeMismatch |
| GI-001 source approval whose scope stamp is not the live stamp denied StaleEpoch | StaleEpoch |
| GI-004 source approval naming subject 0 denied SubjectMismatch | SubjectMismatch |
| GI-001 source approval submitted at its valid_until denied Expired | Expired (added) |
| GI-001 repeated (issuer, serial) denied Replay | Replay |
| GI-001 write approval for destination version 9 when the plan names version 8 denied ScopeMismatch | ScopeMismatch |
| GI-001 write approval for write domain 6 under a scope naming write domain 9 denied ScopeMismatch | ScopeMismatch (added) |

The fixtures are commented as synthetic authority records. The principals are 101 to 106. The read authorities are for domains 5, 9 and 7, and the write authorities are for domains 6 and 5. The placements are 10v4 in RD5, 11v4 in RD7, and 20v8 and 20v9 in WD6. The live stamp is TF.stamp().

## Verification (Bend 2.0.39, this tree)

- `bend Issuance.bend --check-only`: `ALL PROOFS CHECK` / `Use --verdict for mathematical validity.`
- `bend Tests.bend` (exit 0). Last lines:
  ```
  Issuance: 24 checks passed
  Property: 324 checks passed; 320 graph cases, each checked against CPU and Bend parallel producers
  ALL LIBRARY TESTS PASSED
  ```
  PASS count: 806 (753 `PASS:` + 53 `PASS `), i.e. 782 + 24 new checks = 806.
- `bend PROOF.bend`: `ALL PROOFS CHECK` / `Use --verdict for mathematical validity.` The six laws are unchanged and `LAWS.bend` / `PROOF.bend` have no diff. `--verdict` was not attempted: the plan defers it to Task 7.
- No native (`-o`) run and no GPU run; the plan defers these to Task 7. This was a JS-checker run only.

## Concerns

1. I added three checks that the brief did not list. Each is stricter than the brief, and none weakens anything.
   - `submit_write` also requires the approval's `domain` to equal the scope's `write_domain` (ScopeMismatch). Task 2's "write approval issued under domain 6 while the request scope says 9" test stays constructible, because the approval and its own scope both say 6.
   - Placements that put the same object version twice in one namespace resolve to no domain (WrongDomain), and `valid` rejects them.
   - An Expired test at `now == valid_until`, because the transition implements that check.
   These changes take the count to 24 rather than the brief's estimate of about 16, so the total is 806 rather than about 798.
2. `Stored.revoked` is a Bool. It only withdraws authority (False grants nothing, and every use re-checks the directory), so I read it as allowed under "no Bool that asserts authentication, ownership or authority". The controller may prefer a dedicated two-constructor type.
3. Transitions do not gate on `valid(state)`. Each gate is recomputed directly from the state, and ambiguous placements deny locally. `valid` is exposed as a separate structural check, as the brief asks.
4. `Grant`, `Ids`, `Stored.consumed_by` and `Stored.revoked` are defined now but no transition in this task populates them. I defined them so that `State` and the test-side equality have their final shape and later tasks need no constructor churn.
