# Task 1 report: provider and offer records (task 1.1; ER-001, ER-008 record half)

Status: DONE_WITH_CONCERNS (see Concerns). Branch `lane/executor-rendezvous`, based on master 78449c9 (the lane commit ea8144a adds only records).

## Files

- Created `Rendezvous.bend` (module) and `RendezvousTests.bend` (section `offers`).
- Edited `Tests.bend`: one import line, `import ./RendezvousTests.bend as Rendezvous`, placed after the Issuance import, and one call, `Rendezvous.main()`, placed after `Issuance.main()`.
- Edited `openspec/changes/add-executor-rendezvous/tasks.md`: checked box 1.1, citing the test names, and updated the preface line.
- Records: this report, `task-1-mutants.md` and `activity.log`.
- `LAWS.bend` and `PROOF.bend` are untouched (`git diff master -- LAWS.bend PROOF.bend` is empty). No count pin was touched.

## Records and types (Rendezvous.bend)

- `OfferId{provider, serial}`: the provider-scoped identity. The `provider` part is a claim and must equal `from.id`.
- `Offer{version, id, provider: I.Principal, grant, plan, profile, quote, valid_until}`: an immutable offer. `provider` is a claim. `grant` only names the Issuance grant id to look up.
- `Offers`, `Profiles` (the execution constraint) and `Snapshot{issuer: I.State, transfer: T.Context, now}`: the trusted read-only inputs.
- `State{revision, next_id, request: N.Request, constraint, offers, approvals, selection, retired, evidence, dispatched, seen}`: the full shared-design state.
- Types for later tasks, defined now so that `State` is complete. No transition uses them yet:
  - `OriginApproval`, plus `StoredApproval{id, approval, withdrawn}` and `Approvals`;
  - `Selection` (`NoSelection{}` or `Selection{id, offer, request, stamp, selected_at, ranking}`);
  - `Evidence`, plus `StoredEvidence{selection, evidence}` and `Evidences`;
  - `Dispatch{selection, worker_session}` and `Dispatches`.

  The plan does not give the shapes of `StoredApproval`, `StoredEvidence` and the `Dispatches` list. These are my choices, and later tasks may adjust them.
- `Serial` has two constructors, `OfferSerial{provider: I.Principal, serial}` and `ApprovalSerial{issuer, serial}`. Offer serials and approval serials are separate namespaces, so A's offer serial 1 never collides with an approval serial 1 from the same principal. The principal stored is always the authenticated `from`.
- `Error`: the plan's closed set of 25 reasons. `Change`: `Rejected{state, reason}` or `Changed{state, id}`.

## Helpers and their purpose

- Public:
  - `open(request, constraint)`: the empty rendezvous; id 0 is never allocated.
  - `valid(state)`: structural only. Every allocated id (stored approvals, selection, retired, evidence and dispatch selection ids) is below `next_id`, approval ids are unique, no serial is recorded twice, and every offer's `id.provider` equals its provider claim's id.
  - `Error.equal`, `Change.accepted/state/reason/issued`, and the state, snapshot and record accessors.
- Policy bits:
  - `record_version()` = 1;
  - `provider_rights()` = 5 (read 1 plus execute 4);
  - `version_supported`, `revision_current`, `unexpired` (exclusive expiry).
- Identity:
  - `OfferId.equal`;
  - `offer_equal`, which compares all eight fields;
  - `id_owned_by(id, from)`;
  - `plan_is_request(plan, state)`, using `T.Plan.equal`.
- Grant:
  - `grant_for(issuer, id)`, which calls `I.find_grant`, so an absent or ambiguous id gives None;
  - `grant_subject_is` (via `I.speaks_for_subject`), `grant_plan_is`, and `grant_backs(grant, provider, plan)`, which combines the two (a named predicate kept for eligibility in Task 3);
  - `rights_cover(grant)` (`T.word_subset(provider_rights(), rights)`);
  - `grant_fault(issuer, grant, now)`, which gives Expired when now ≥ valid_until, StaleEpoch when the scope stamp is not the issuer's live stamp, and Revoked otherwise;
  - `GrantRequirement` (`BelongsTo`, `CoversPlan`, `IsCurrent`, `HoldsRights`, `Outlives`) with `grant_requirement` and `grant_meets`. A missing grant meets no requirement;
  - `found_fault`.
- Record uniqueness:
  - `quote_named`;
  - `offer_exists(offers, id)`, which matches any content;
  - `serial_entry` and `offer_serial_seen`.
- Gate machinery: `Gates`, `Gates.checks`, `Gates.reason` and `first_reason`, following the Issuance pattern so that `failed_check_denies` applies. Also `offer_gates_found`, `offer_gates`, `offer_checks`, `commit_offer` and `submit_offer_checked`.

## What `submit_offer(state, expected_revision, from, offer, snapshot)` checks, in order

All gates are one ordered `Gates` list. Acceptance is `Guard.all` over it, and the reason is the first failing gate.

| # | Gate (condition) | Reason | Why here |
|---|---|---|---|
| 1 | `revision_current` | StaleRevision | The race comes first. |
| 2 | `version_supported` | UnknownVersion | An unknown format is never interpreted. |
| 3 | `I.claim_matches(from, offer.provider)` | Unauthenticated | The provider claim must be the authenticated principal. |
| 4 | `id_owned_by(offer.id, from)` | Unauthenticated | Identities are provider-scoped, so nobody can occupy a competitor's identity (ER-008). |
| 5 | `plan_is_request(offer.plan, state)` | ScopeMismatch | The rendezvous never widens, narrows or recodes the plan. |
| 6 | grant `BelongsTo` from (present and subject is `from`) | NoGrant | Authority is only the provider's own registered grant. A missing or ambiguous grant, or another subject's grant, is no grant. |
| 7 | grant `CoversPlan` (scope plan is the request plan) | ScopeMismatch | A grant for any other plan does not cover this execution. |
| 8 | grant `IsCurrent` (`I.current` in the snapshot issuer at `now`) | `found_fault`: Expired / StaleEpoch / Revoked | Currency is re-derived, never cached. |
| 9 | grant `HoldsRights` (`rights_cover`) | RightsNotHeld | The grant must cover read plus execute. |
| 10 | `now < offer.valid_until` | Expired | The offer's own lifetime. |
| 11 | grant `Outlives` (offer `valid_until` ≤ grant's) | Expired | An offer cannot outlast its authority. |
| 12 | `quote_named` (quote > 0) | OverBudget | See Concerns. |
| 13 | no record under `offer.id` | DuplicateOffer | At most one record per id, whatever its content. |
| 14 | `(from, serial)` unseen | Replay | Serials are never reused, even after a withdrawal. |

There is no outer revision match. No law pins one, and the revision gate is the first gate, so an outer match would only add an equivalent mutant. On acceptance, `commit_offer` stores the offer unedited, prepends `OfferSerial{from, serial}` to `seen` (the authenticated principal, not the claim) and advances the revision once. `next_id` is unchanged, because an offer's identity is its `OfferId`. The change id is the serial. The budget ceiling, the constraint and origin approvals are not checked here, per the plan ruling: they are eligibility conditions for Task 3.

The header documents every trusted input used so far: `from`, the snapshot's issuer state, transfer context and `now`, and `expected_revision`.

## Denial cases and their checks (section `offers`)

| Denial | Check name |
|---|---|
| Unauthenticated (claim) | "ER-001 unauthenticated provider: from B submitting an offer claiming provider A denied Unauthenticated" (the id is `{202,1}`, so only the claim fails) |
| Unauthenticated (identity) | "ER-008 from A submitting under OfferId{202, 1}, B's identity namespace, denied Unauthenticated" |
| NoGrant (none) | "ER-001 provider C with no registered grant denied NoGrant" |
| NoGrant (other subject) | "ER-001 provider B citing A's grant 3, whose subject is not B, denied NoGrant" |
| ScopeMismatch (grant plan) | "ER-001 scope narrower than the plan: A's grant 3 for the one-source plan behind an offer for the two-source request denied ScopeMismatch" |
| ScopeMismatch (offer plan) | "... an offer whose plan drops object 11 from the two-source request's manifest ...", "... names destination 20v9 instead of the request's 20v8 ...", "... differs from the request's in one code word ..." |
| Revoked | "ER-001 after object 10's read authority revokes the source approval behind grant 3, A's offer is denied Revoked" (via `I.revoke`) |
| Expired (grant) | "ER-001 A's offer at 150, when grant 3 (valid while now < 150) has expired, denied Expired" |
| StaleEpoch | "ER-001 once the monitor installs authority epoch 5 in the issuer, A's grant scoped at epoch 3 is stale: denied StaleEpoch" (synthetic monitor state) |
| RightsNotHeld | "ER-001 provider D's current grant 9 with rights 1 does not cover read plus execute: denied RightsNotHeld" |
| Expired (outlives grant) | "ER-001 an offer valid until 160, past grant 3's 150, denied Expired" |
| Expired (offer itself) | "ER-001 an offer submitted at its own valid_until 100 denied Expired" |
| OverBudget (zero quote) | "ER-001 an offer quoting 0 names no billing term: denied OverBudget" |
| DuplicateOffer | "ER-008 a second identical record under OfferId{201, 1} denied DuplicateOffer" and "... quoting 35 instead of 40 denied DuplicateOffer" |
| Replay | "ER-008 A's serial 1 already seen with no record stored under it (the shape a withdrawal leaves) denied Replay" (synthetic monitor state; the real withdraw-then-resubmit test lands with `withdraw_offer` in Task 3) |
| UnknownVersion | "ER-001 offer record version 2 denied UnknownVersion" |
| StaleRevision | "ER-001 B's offer validated at revision 0 against the state at revision 1 denied StaleRevision" |

Each denial goes through `denied`, which checks the exact `Error.equal` reason and a test-side `State.equal` over all 11 fields.

The accepting checks are:
- "ER-001 open: ...";
- "ER-001 synthetic issuer: grants 3 (A), 6 (B) and 9 (D) are registered through Issuance and current at 100";
- "ER-001 grant_backs: ...";
- "ER-001 provider A's offer ... is stored at revision 1 and (A, serial 1) is recorded as seen";
- "ER-001 an offer valid until 150, exactly grant 3's own valid_until, is accepted";
- "ER-001 same code different provider: B's offer ... is stored as a second record";
- "ER-001 same code different provider: the two offers share a code identity but are not equal records and have distinct identities";
- "ER-008 valid: an offer whose identity names another provider, or a serial recorded twice, is not a valid state".

Every provider grant is built from `IT.initial()` through `I.submit_source`, `I.submit_write` and `I.register`, with `from` = the provider. The grants are A = 201 (grant 3, rights 5), B = 202 (grant 6, rights 5) and D = 204 (grant 9, rights 1), each until 150. C = 203 holds no grant.

## Removal map

There are 14 gate mutants and 20 helper mutants (34 in all), and all are killed. The full table is in `task-1-mutants.md`. The gates:

| Gate removed (`True{}`) | First killing check |
|---|---|
| revision_current | "ER-001 B's offer validated at revision 0 ... denied StaleRevision" |
| version_supported | "ER-001 offer record version 2 denied UnknownVersion" |
| claim_matches | "ER-001 unauthenticated provider: from B submitting an offer claiming provider A ..." |
| id_owned_by | "ER-008 from A submitting under OfferId{202, 1} ..." |
| plan_is_request | "ER-001 an offer whose plan names destination 20v9 ..." |
| BelongsTo | "ER-001 provider C with no registered grant denied NoGrant" |
| CoversPlan | "ER-001 scope narrower than the plan: ..." |
| IsCurrent | "ER-001 after object 10's read authority revokes ... denied Revoked" |
| HoldsRights | "ER-001 provider D's current grant 9 with rights 1 ..." |
| offer unexpired | "ER-001 an offer submitted at its own valid_until 100 denied Expired" |
| Outlives | "ER-001 an offer valid until 160, past grant 3's 150, denied Expired" |
| quote_named | "ER-001 an offer quoting 0 ... denied OverBudget" |
| DuplicateOffer | "ER-008 a second identical record under OfferId{201, 1} denied DuplicateOffer" |
| Replay | "ER-008 A's serial 1 already seen with no record stored under it ... denied Replay" |

Two mutants survived the first sweep. Both were killed by checks I added:
- `Outlives` with ≤ changed to <, killed by the boundary acceptance at 150;
- the commit dropping the serial, killed by an exact `seen` assertion in the acceptance check.

## Verification

`export PATH="$HOME/.local/share/writ-toolchains/bend-2.0.39/bend/bin:$PATH"; export BEND_NO_TELEMETRY=1`

- `bend Rendezvous.bend --check-only` ends with `ALL PROOFS CHECK` / `Use --verdict for mathematical validity.`
- `bend RendezvousTests.bend` ends with `Rendezvous: 28 checks passed`.
- `bend Tests.bend` ends with `Property: 324 checks passed; ...` / `ALL LIBRARY TESTS PASSED`. The PASS total, counting `PASS:` and `PASS ` lines together, is **1456**. That is 1428 at master 78449c9 plus 28 new checks.
- `bend PROOF.bend` ends with `ALL PROOFS CHECK` / `Use --verdict for mathematical validity.` The 17 laws are unchanged, and `git diff master -- LAWS.bend PROOF.bend` is empty.
- `openspec validate add-executor-rendezvous --strict --no-interactive` reports `Change 'add-executor-rendezvous' is valid`. This is structural only.
- I did not attempt `--verdict`, native or JS runs (those belong to Task 8), or any GPU run.

## Concerns

1. **Zero-quote reason.** The brief requires "the quote is > 0" but names no reason, and the closed set has none that fits. I used `OverBudget` and documented it at `quote_named` as "a quote outside the admitted range (positive, up to the ceiling)". The controller may prefer `ScopeMismatch` or a new constructor. Adding a constructor would change the plan's closed set, so I did not.
2. **Change id for an offer.** This is the serial, not an allocated id, because offers have no numeric id and do not consume `next_id`. The full identity is the `OfferId`, whose provider is `from`.
3. **Type shapes for later tasks.** `StoredApproval{id, approval, withdrawn}`, `StoredEvidence{selection, evidence}` and `Dispatch{selection, worker_session}` are my choices. The `Serial` split into `OfferSerial` and `ApprovalSerial` is also mine, and it keeps the two serial namespaces apart.
4. **Values reused across fields.** The verbatim brief values put 1 in three places: record version 1, serial 1 (`OfferId{202, 1}`) and profile 1 (from Task 2). The other fields use distinct values: grant ids 3, 6 and 9, quote 40, offer `valid_until` 140, grant `valid_until` 150, and now 100.
5. **The Replay gate uses a synthetic monitor state.** Withdrawal does not exist yet, so the Replay check uses a state with A's serial seen and no record stored. Task 3 should add the real withdraw-then-resubmit check.
6. **Shared scratchpad collision.** The session scratchpad is shared with the parallel policy-aware-audit lane. That lane overwrote my first `scratchpad/mutate.py`, and my next sweep invocation ran their script by mistake. Their script only reads their worktree and writes under `writ-lanes/writ-build/policy-aware-audit/mutants/task-1`. My shell redirect also overwrote `scratchpad/mutants.txt` with a partial copy of their run's output, and the run was cut off ("Terminated"). Their worktree was not modified by me, as far as `git status` shows. If they read `scratchpad/mutants.txt` or that mutants directory, they should regenerate it. I moved my files to `scratchpad/executor-rendezvous-t1/` and reran my sweep from there.
7. **Mutant directory path.** My mutant copy is at `spaceghost/writ-build/executor-rendezvous/mutant/`. That is `../../writ-build` from the worktree, one level above the plan's `../writ-build`. It is outside the worktree either way.

## Fix round 1

Source: `task-1-review.md`, findings F1 to F5, with both verdicts NEEDS_FIXES. The fixtures put 1 in version, serial and profile, and no provider submitted a second offer, so nine comparator and serial mutants survived.

Changes:
- **F1:**
  - Added "ER-008 a second A offer under OfferId{201, 7} is accepted beside OfferId{201, 1}, issues 7, and seen is exactly (A, 7) then (A, 1)". The fixture is `offer_a7()`, and serial is the only field carrying 7.
  - Added "ER-008 A's serial 7 already seen with no record stored under it: an offer under OfferId{201, 7} denied Replay" (synthetic monitor state `withdrawn_a7()`).
- **F2:** added "ER-008 offer_equal distinguishes every single-field change: version 2, grant 4, another code word, profile 2, quote 35, valid_until 139". It also asserts self-equality. This strengthens every `denied` state-unchanged assertion, which goes through `offer_equal`.
- **F3:** added "ER-001 offer record version 0 denied UnknownVersion".
- **F4:** added "ER-008 valid: A's offer serial 1 beside an approval serial 1 from the same principal is valid, the two namespaces being separate" (synthetic monitor state `both_namespaces()`). This kills N14, so N14 is not recorded as source-reviewed. The `serials_valid` comment now states the namespace consequence.
- **F5 (hardening):**
  - The `grant_for` comment now states that BelongsTo plus IsCurrent is exactly `I.usable_by(issuer, grant, from, now)`, the `I.registry` filter, and that eligibility must keep both.
  - Added "ER-001 projection agreement: grant 3 behind A's accepted offer passes I.usable_by for A, the filter of I.registry, and not for B".
- **Zero-quote ruling:** the reviewer kept `OverBudget`. Following their suggestion, the `quote_named` comment now says "out of the admitted quote range". Concern 1 is resolved.
- **F6:** a note only, so there was no change.

Mutation: the review's N1 to N14 plus my original 34 make 48, and all are KILLED. The table is in `task-1-mutants.md`, section "Fix round 1".

Verification:
- `bend Rendezvous.bend --check-only` ends with `ALL PROOFS CHECK` / `Use --verdict for mathematical validity.`
- `bend RendezvousTests.bend` ends with `Rendezvous: 34 checks passed`.
- `bend Tests.bend` ends with `ALL LIBRARY TESTS PASSED`. The PASS total (the `PASS:` and `PASS ` forms together) is **1462**, which is 1428 at master 78449c9 plus 34 new checks. The run had 0 FAIL lines.
- `bend PROOF.bend` ends with `ALL PROOFS CHECK` / `Use --verdict for mathematical validity.` The 17 laws are unchanged, and `git diff master -- LAWS.bend PROOF.bend` is empty.
- `openspec validate add-executor-rendezvous --strict --no-interactive` reports `Change 'add-executor-rendezvous' is valid`.

Remaining concerns from the first round: 2 (the change id is the serial), 3 (type shapes for later tasks), 5 (the Task 3 withdraw-then-resubmit test is still owed), 6 (the scratchpad collision, now avoided by keeping every file under `scratchpad/executor-rendezvous-t1/`) and 7 (the mutant directory path). Concern 4 (values reused across fields) is resolved for serial by the serial-7 checks, and for version and profile by the version-0 and single-field `offer_equal` checks.
