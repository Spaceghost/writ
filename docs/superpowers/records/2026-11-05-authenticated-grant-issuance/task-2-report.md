# Task 2 report: exact paired-scope registration (task 1.2; GI-002, GI-003, GI-004)

Status: DONE_WITH_CONCERNS (the concerns are about the check count and some small design choices; nothing is blocked).

## Files

- `Issuance.bend`: added the `Registration` section at the end of the module, after `valid`. It has to come after `approval_exists`, because Bend resolves definitions in order. I also updated the header: the trusted `token` input, the "registration has no `from`" paragraph, and `register` added to the public entry points. The `Grant` and `Change` comments were updated too. No Task 1 gate, order or reason changed.
- `IssuanceTests.bend`: registration fixtures (commented as synthetic) and a `registration()` section of 51 checks. `main` calls `submission()` and then `registration()`, and prints `Issuance: 90 checks passed`.
- `openspec/changes/add-authenticated-grant-issuance/tasks.md`: box 1.2 checked, with the test names cited.
- `Tests.bend`, `LAWS.bend`, `PROOF.bend`, the count pins and every do-not-touch file are unchanged (`git diff 8b09ed1 -- LAWS.bend PROOF.bend Tests.bend` is empty).

## What `register` is

`register(state, expected_revision, request: Request, now, token)` is a public entry point. `Request{version, scope, sources: Ids, write: Nat, rights, valid_until}` carries no requester identity. Authority comes only from the cited stored approvals. Each was admitted earlier from its authenticated issuer, and each is revalidated here against the state being committed.

Its shape matches the submissions:
1. `register` matches on `revision_current` first (`register_current`). This is the shape the Task 3 law `issuance_stale_revision_rejects` needs.
2. It then matches on `Guard.all(register_checks(...))`.
3. `register_checks` is `Gates.checks(register_gates(...))`, and the denial reason is `Gates.reason` over the same list, so the law `failed_check_denies` covers every gate.

The per-approval checks use one `Requirement` enum (`Present`, `Unconsumed`, `Unrevoked`, `StillAuthority`, `StillPlaced`, `DestinationIsPlans`, `DomainIsScopes`, `SameSubject`, `SameScope`, `RightsCover`, `StillUnexpired`, `LifetimeCovers`). Each one has its own arm in `source_requirement` and `write_requirement`. They are asked through:
- `sources_meet`, a walk over the cited source ids;
- `write_cited_meets`, for the one write id.

The lookups fail closed:
- `find_stored` resolves a missing id to None, and also an id stored twice (`first_stored`, the same rule as for ambiguous placements).
- A record of the wrong kind meets no requirement.
- The write-only requirements fail closed when asked of a source approval.

### Gate order, and why

| # | Check | Reason |
|---|---|---|
| 1 | `revision_current` | StaleRevision |
| 2 | `version_supported(request.version)` | UnknownVersion |
| 3 | write id names exactly one stored write approval | MissingApproval |
| 4 | each source id names exactly one stored source approval | MissingApproval |
| 5 | `sources_named_for_manifest`: no fewer ids than manifest entries | MissingApproval |
| 6 | `ids_distinct(sources)` | Replay |
| 7 / 8 | write / sources `unconsumed` | Replay |
| 9 / 10 | write / sources unrevoked | Revoked |
| 11 / 12 | write / sources issuer still the directory authority for the approval's domain (`is_write_authority` / `is_read_authority` on the current directory) | NotAuthority |
| 13 / 14 | write / sources object still placed in the approval's domain (current placements) | WrongDomain |
| 15 | `scope_wellformed(request.scope, live)` (stamp is live, subject named, manifest nonempty) | `scope_fault` (StaleEpoch / SubjectMismatch / ScopeMismatch) |
| 16 | `sources_cover_manifest`: walks the manifest and the ids together, with no index; the approval at each position approves exactly that entry, and the two lists end together | ScopeMismatch |
| 17 | write destination = request plan's destination | ScopeMismatch |
| 18 | write domain = request scope's write domain | ScopeMismatch |
| 19 / 20 | write / sources scope subject = request subject | SubjectMismatch |
| 21 / 22 | write / sources `scope_equal(approval.scope, request.scope)` | ScopeMismatch |
| 23 | `rights_valid(request.rights)` | InvalidRights |
| 24 / 25 | write / sources `rights_within(request.rights, approval.rights)` | Widened |
| 26 / 27 | write / sources `now < approval.valid_until` | Expired |
| 28 | `now < request.valid_until` | Expired |
| 29 / 30 | write / sources `lifetime_within(request.valid_until, approval.valid_until)` (`Nat.is_le`) | Widened |
| 31 | `token_fresh` (no registered grant holds the token) | DuplicateToken |

Why this order:
- The race comes first (GI-005 needs it outermost), then the format.
- Next come existence, single use and revocation, because withdrawn authority should deny before anything is compared.
- Authority revalidation against this state's directory and placements comes next. This follows Task 1's identity-before-content order.
- Then the exact scope binding. The subject gates come before the whole-scope gates, so a scope that differs only in the subject reports SubjectMismatch rather than ScopeMismatch.
- Then the bounds.
- The monitor-supplied token is last.
- Each requirement is asked of the write approval and of the sources in separate gates, so every denial can be traced to one gate.
- An approval's expiry (26-27) comes before the request's own expiry and lifetime (28-30). Two reasons: an expired approval then reads as Expired, and gates 26-27 are not implied by 28-30. In the other order, `now < request.valid_until <= approval.valid_until` would make them unreachable.
- Gate 6 is needed because consumption is checked against the state before the commit. Without it, one single-use approval could back two manifest entries of one grant.

On acceptance (`commit_grant`), `register`:
- stores `Grant{next_id, token, request.scope, rights, valid_until, sources, write, 0n}`;
- marks every cited approval `consumed_by = grant id` (`consume`);
- advances `next_id` and the revision once each, and leaves `seen` unchanged;
- returns the grant id as the change id.

The stored scope is the request's. Gates 19-22 made it exactly equal, in every plan field, the write domain and the subject, to every cited approval's scope. The subject is therefore the one the authorities approved. Every denial returns the supplied state.

## Tests (section `registration`, 51 checks)

Every denial goes through `denied` (`Error.equal` plus full `State.equal` against the input).

States are built in two ways:
- Through the public entry points (`pair`, `two_state`, `two_plus_state`, `fresh_pair`). Every denial test on such a state expects a reason other than MissingApproval, so a fixture submission that was itself denied would show up.
- As synthetic monitor states (`with_directory`, `with_placements`, `with_live`, `with_revoked`, `with_approvals`, `stored_pair`). These are labeled as monitor-installed states that no submission produces. They show that registration revalidates stored records instead of trusting them.

Brief cases, each with its check name:
- One-source accepted: "GI-002 one-source paired registration is accepted as grant 3 and advances the revision once", plus "GI-004 the registered grant binds the approved scope and subject 7, the cited ids, the requested rights and lifetime, and no parent" and "GI-002 registration consumes both cited approvals for grant 3, records no serial, and leaves a valid state".
- Two sources (10 in read domain 5 and 11 in read domain 7, from distinct authorities):
  - "GI-003 two-source plan from read domains 5 and 7 is accepted with both source approvals in manifest order"
  - "... with the source approvals reordered denied ScopeMismatch"
  - "... citing no approval for object 11 denied MissingApproval"
  - "... citing a third source approval beyond the manifest denied ScopeMismatch"
- No write cited, or a nonexistent write id: "GI-002 missing destination approval: no write approval cited denied MissingApproval" and "GI-002 missing destination approval: cited write approval id does not exist denied MissingApproval".
- Wrong write domain (submitted for 6, request scope 9): "GI-003 write approval issued for write domain 6 under a request scope naming write domain 9 denied ScopeMismatch".
- Redirect: "GI-003 redirecting an existing read: source approval for 10 to 20v8 with a write approval for 20v9, under the read's scope, denied ScopeMismatch" and "GI-003 redirecting an existing read: the same pair under the redirected write's scope denied ScopeMismatch".
- Expanded manifest: "GI-003 expanded manifest: write approval whose scope adds source 11 denied ScopeMismatch".
- A difference only in invocation, in the eighth code word, or in kind: "GI-003 approvals differing only in invocation denied ScopeMismatch", "GI-003 approvals differing only in the eighth code word denied ScopeMismatch" and "GI-003 approvals differing only in operation kind denied ScopeMismatch".
- Recipient substitution: "GI-004 recipient substitution: approvals for subject 7 and a request for subject 8 denied SubjectMismatch". The request for subject 7 is the accepted case above.
- Rights 7 over the source's 3: "GI-003 requested rights 7 exceeding the source approval's 3 denied Widened". The write approval in this fixture has rights 7, so only the source gate can deny.
- Duplicate token: "GI-002 registration with a token a registered grant holds denied DuplicateToken".
- Version 2: "GI-002 registration request version 2 denied UnknownVersion".
- Authority removed by the monitor: "GI-001 source authority removed from the directory between submission and registration denied NotAuthority".

Added to pin branches (the removal map shows which gate each one pins):
- write-side and kind checks: "GI-002 a source approval cited as the write approval denied MissingApproval", "GI-003 cited source approval id does not exist denied MissingApproval", "GI-003 the write approval cited as a source approval denied MissingApproval" and "GI-003 an approval id stored twice resolves to no approval and is denied MissingApproval";
- the synthetic revalidation pair: "GI-003 stored write approval for write domain 6 whose own scope names write domain 9 is revalidated and denied ScopeMismatch" and "GI-003 stored write approval for destination 20v9 under a plan naming 20v8 is revalidated and denied ScopeMismatch";
- "GI-003 source approval differing from the request scope only in invocation denied ScopeMismatch";
- the one-sided subject checks: "GI-004 write approval for subject 8 paired with a source approval and request for subject 7 denied SubjectMismatch" and "GI-004 source approval for subject 8 paired with a write approval and request for subject 7 denied SubjectMismatch";
- rights: "GI-003 requested rights 7 exceeding the write approval's 3 denied Widened" and "GI-003 requested rights 8 denied InvalidRights";
- expiry: "GI-002 registration at the write approval's valid_until denied Expired", "GI-002 registration at the source approval's valid_until denied Expired" and "GI-002 requested valid_until equal to now denied Expired";
- lifetime: "GI-002 requested lifetime beyond the write approval's denied Widened" and "GI-002 requested lifetime beyond the source approval's denied Widened";
- boundary acceptance: "GI-002 requested valid_until equal to both approvals' valid_until is accepted" and "GI-003 requested rights 1, a strict subset of both approvals' 3, are accepted";
- consumption and tokens: "GI-002 a fresh approval pair registers a second grant with a fresh token", "GI-002 a consumed source approval cited by a second registration denied Replay", "GI-002 a consumed write approval cited by a second registration denied Replay" and "GI-003 one source approval cited for two manifest entries denied Replay";
- revocation: "GI-002 a revoked write approval denied Revoked" and "GI-002 a revoked source approval denied Revoked";
- monitor changes: "GI-001 write authority removed from the directory between submission and registration denied NotAuthority", "GI-001 source object moved to read domain 9 between submission and registration denied WrongDomain", "GI-001 destination moved to write domain 5 between submission and registration denied WrongDomain" and "GI-003 registration after the monitor advanced the authority epoch denied StaleEpoch";
- revision: "GI-002 registration validated at revision 1 against state at revision 2 denied StaleRevision" and "GI-002 the registration check list alone is false at a stale revision".

## Removal map

The harness is `/tmp/claude-1000/-mnt-MediaVolume-Media-src-github-com-spaceghost-writ/55038343-2e0b-4235-a6a8-7c68c6dd1f50/scratchpad/scripts/mutate2.py`. It ran on a scratch copy of the tree in `/tmp/claude-1000/-mnt-MediaVolume-Media-src-github-com-spaceghost-writ/55038343-2e0b-4235-a6a8-7c68c6dd1f50/scratchpad/mut2`, outside the worktree. Each mutant:
- either replaces one `register_gates` condition with `True{}`, or changes one helper arm or commit field;
- then runs `bend IssuanceTests.bend`.

KILLED rows name the first failing check. Two boundary mutants were run after the two acceptance checks were added: `lifetime_within` made strict (`Nat.is_lt`), and `rights_within` made equality. Both were then killed, by "GI-002 requested valid_until equal to both approvals' valid_until is accepted" and "GI-003 requested rights 1, a strict subset of both approvals' 3, are accepted" respectively. The strict-lifetime mutant had survived the first run, below.

| Removed branch | First failing check |
|---|---|
| gate  1 StaleRevision{}: revision_current(state, expected_revision) | GI-002 the registration check list alone is false at a stale revision |
| gate  2 UnknownVersion{}: version_supported(version) | GI-002 registration request version 2 denied UnknownVersion |
| gate  3 MissingApproval{}: write_cited_meets(Present{}, state, request, now) | GI-002 missing destination approval: no write approval cited denied MissingApproval |
| gate  4 MissingApproval{}: sources_meet(Present{}, sources, state, request, now) | GI-003 cited source approval id does not exist denied MissingApproval |
| gate  5 MissingApproval{}: sources_named_for_manifest(T.Plan.sources(Scope.plan(scope)), sources) | GI-003 two-source plan citing no approval for object 11 denied MissingApproval |
| gate  6 Replay{}: ids_distinct(sources) | GI-003 one source approval cited for two manifest entries denied Replay |
| gate  7 Replay{}: write_cited_meets(Unconsumed{}, state, request, now) | GI-002 a consumed write approval cited by a second registration denied Replay |
| gate  8 Replay{}: sources_meet(Unconsumed{}, sources, state, request, now) | GI-002 a consumed source approval cited by a second registration denied Replay |
| gate  9 Revoked{}: write_cited_meets(Unrevoked{}, state, request, now) | GI-002 a revoked write approval denied Revoked |
| gate 10 Revoked{}: sources_meet(Unrevoked{}, sources, state, request, now) | GI-002 a revoked source approval denied Revoked |
| gate 11 NotAuthority{}: write_cited_meets(StillAuthority{}, state, request, now) | GI-001 write authority removed from the directory between submission and registration denied NotAuthority |
| gate 12 NotAuthority{}: sources_meet(StillAuthority{}, sources, state, request, now) | GI-001 source authority removed from the directory between submission and registration denied NotAuthority |
| gate 13 WrongDomain{}: write_cited_meets(StillPlaced{}, state, request, now) | GI-001 destination moved to write domain 5 between submission and registration denied WrongDomain |
| gate 14 WrongDomain{}: sources_meet(StillPlaced{}, sources, state, request, now) | GI-001 source object moved to read domain 9 between submission and registration denied WrongDomain |
| gate 15 scope_fault(scope, live(state)): scope_wellformed(scope, live(state)) | GI-003 registration after the monitor advanced the authority epoch denied StaleEpoch |
| gate 16 ScopeMismatch{}: sources_cover_manifest(approvals(state), T.Plan.sources(Scope.plan(sco | GI-003 two-source plan with the source approvals reordered denied ScopeMismatch |
| gate 17 ScopeMismatch{}: write_cited_meets(DestinationIsPlans{}, state, request, now) | GI-003 stored write approval for destination 20v9 under a plan naming 20v8 is revalidated and denied ScopeMismatch |
| gate 18 ScopeMismatch{}: write_cited_meets(DomainIsScopes{}, state, request, now) | GI-003 stored write approval for write domain 6 whose own scope names write domain 9 is revalidated and denied ScopeMismatch |
| gate 19 SubjectMismatch{}: write_cited_meets(SameSubject{}, state, request, now) | GI-004 write approval for subject 8 paired with a source approval and request for subject 7 denied SubjectMismatch |
| gate 20 SubjectMismatch{}: sources_meet(SameSubject{}, sources, state, request, now) | GI-004 source approval for subject 8 paired with a write approval and request for subject 7 denied SubjectMismatch |
| gate 21 ScopeMismatch{}: write_cited_meets(SameScope{}, state, request, now) | GI-003 expanded manifest: write approval whose scope adds source 11 denied ScopeMismatch |
| gate 22 ScopeMismatch{}: sources_meet(SameScope{}, sources, state, request, now) | GI-003 redirecting an existing read: the same pair under the redirected write's scope denied ScopeMismatch |
| gate 23 InvalidRights{}: rights_valid(rights) | GI-003 requested rights 8 denied InvalidRights |
| gate 24 Widened{}: write_cited_meets(RightsCover{}, state, request, now) | GI-003 requested rights 7 exceeding the write approval's 3 denied Widened |
| gate 25 Widened{}: sources_meet(RightsCover{}, sources, state, request, now) | GI-003 requested rights 7 exceeding the source approval's 3 denied Widened |
| gate 26 Expired{}: write_cited_meets(StillUnexpired{}, state, request, now) | GI-002 registration at the write approval's valid_until denied Expired |
| gate 27 Expired{}: sources_meet(StillUnexpired{}, sources, state, request, now) | GI-002 registration at the source approval's valid_until denied Expired |
| gate 28 Expired{}: unexpired(now, valid_until) | GI-002 requested valid_until equal to now denied Expired |
| gate 29 Widened{}: write_cited_meets(LifetimeCovers{}, state, request, now) | GI-002 requested lifetime beyond the write approval's denied Widened |
| gate 30 Widened{}: sources_meet(LifetimeCovers{}, sources, state, request, now) | GI-002 requested lifetime beyond the source approval's denied Widened |
| gate 31 DuplicateToken{}: token_fresh(grants(state), token) | GI-002 registration with a token a registered grant holds denied DuplicateToken |
| register outer revision match only | SURVIVED (equivalent, see below) |
| register outer revision match AND gate 1 | GI-002 registration validated at revision 1 against state at revision 2 denied StaleRevision |
| register outer revision branch returns a committed state | GI-002 registration validated at revision 1 against state at revision 2 denied StaleRevision |
| register denial carries committed state | GI-003 two-source plan with the source approvals reordered denied ScopeMismatch |
| first_stored: first match wins | GI-003 an approval id stored twice resolves to no approval and is denied MissingApproval |
| sources_cover_manifest (OEnd, Ids) arm <- True | GI-003 two-source plan citing a third source approval beyond the manifest denied ScopeMismatch |
| sources_cover_manifest (OCons, NoIds) arm <- True | SURVIVED (equivalent, see below) |
| cited_source_is: WriteEntry arm <- True | SURVIVED (equivalent, see below) |
| source_meets: WriteEntry arm <- True | GI-003 the write approval cited as a source approval denied MissingApproval |
| write_meets: SourceEntry arm <- True | GI-002 a source approval cited as the write approval denied MissingApproval |
| source_meets: None arm <- True | GI-003 cited source approval id does not exist denied MissingApproval |
| write_meets: None arm <- True | GI-002 missing destination approval: no write approval cited denied MissingApproval |
| source_requirement DestinationIsPlans <- True (never asked) | SURVIVED (equivalent, see below) |
| source_requirement DomainIsScopes <- True (never asked) | SURVIVED (equivalent, see below) |
| ids_distinct body <- True | GI-003 one source approval cited for two manifest entries denied Replay |
| unconsumed <- True | GI-002 a consumed source approval cited by a second registration denied Replay |
| rights_within <- True | GI-003 requested rights 7 exceeding the source approval's 3 denied Widened |
| lifetime_within <- True | GI-002 requested lifetime beyond the write approval's denied Widened |
| lifetime_within strict (is_lt) | SURVIVED (equivalent, see below) |
| token_fresh <- True | GI-002 registration with a token a registered grant holds denied DuplicateToken |
| consume_stored never marks | GI-002 registration consumes both cited approvals for grant 3, records no serial, and leaves a valid state |
| consume: write id not marked | GI-002 registration consumes both cited approvals for grant 3, records no serial, and leaves a valid state |
| consume: source ids not marked | GI-002 registration consumes both cited approvals for grant 3, records no serial, and leaves a valid state |
| commit_grant: parent 1 | GI-004 the registered grant binds the approved scope and subject 7, the cited ids, the requested rights and lifetime, and no parent |
| commit_grant: revision not advanced | GI-002 one-source paired registration is accepted as grant 3 and advances the revision once |
| commit_grant: next_id not advanced | GI-002 one-source paired registration is accepted as grant 3 and advances the revision once |
| find_stored: ambiguity ignored | GI-003 an approval id stored twice resolves to no approval and is denied MissingApproval |

The result is 59 mutants in the first run plus 1 in the rerun, so 60 in total. The strict-lifetime survivor was closed by the new boundary check, which leaves 5 survivors. Each one is equivalent, so no black-box test can kill it:
- **Outer revision match only.** Gate 1 denies the same input with the same reason and state. This is the same accepted case as Task 1's two survivors. The outer match is kept for the Task 3 law. The inner gate is pinned by "the registration check list alone is false at a stale revision", and the combined removal is killed.
- **`sources_cover_manifest` (OCons, NoIds) arm.** Gate 5 denies every request with fewer ids than manifest entries before gate 16 runs.
- **`cited_source_is` WriteEntry arm.** Gate 4 denies a write-kind record cited as a source before gate 16 runs.
- **The `source_requirement` arms for `DestinationIsPlans` and `DomainIsScopes`.** These requirements are only ever asked of the write approval, and the source arms fail closed as defense in depth.

All denial gates (1-31) are killed by a test with the exact reason.

## Verification (Bend 2.0.39, this tree)

- `bend Issuance.bend --check-only`: `ALL PROOFS CHECK` / `Use --verdict for mathematical validity.`
- `bend Tests.bend` (exit 0, 0 FAIL). Last lines:
  ```
  Issuance: 90 checks passed
  ...
  Property: 324 checks passed; 320 graph cases, each checked against CPU and Bend parallel producers
  ALL LIBRARY TESTS PASSED
  ```
  The PASS count is 872 (819 `PASS:` + 53 `PASS `), that is, 782 + 90 new checks = 872 (821 after Task 1, plus 51).
- `bend PROOF.bend` (exit 0): `ALL PROOFS CHECK` / `Use --verdict for mathematical validity.` The six laws are unchanged, and `LAWS.bend`/`PROOF.bend` have no diff.
- I did not run `--verdict`, a native build or a GPU test; the plan defers these to Task 7. This was a JS-checker run only.
- No count pin was touched (the cross-lane ruling).

## Concerns

1. **Count.** There are 51 checks against the brief's estimate of about 18, so the totals are 90 Issuance checks and 872 overall, not about 816. All 31 gates are separate so that each denial can be traced to one gate, and the removal standard requires a test that pins each one. Many of the write-side and source-side pairs need one-sided fixtures for that, because a test where both sides fail does not kill the removal of one side's gate.
2. **Stricter than the brief, in the same way as Task 1.** None of these widens anything.
   - Gate 6 (`ids_distinct`, Replay).
   - The ambiguous-id rule in `find_stored`: an id stored twice resolves to no approval, MissingApproval.
   - Separate expiry gates for each cited approval, ordered before the request's lifetime gates so they are reachable.
   - The exact reasons for missing and reordered ids. The brief allows either one: fewer ids than manifest entries gives MissingApproval, and reordered, substituted or extra ids give ScopeMismatch.
3. **The stored grant takes its scope from the request, not from an approval.** Gates 19-22 make the two exactly equal, so this is the authorities' scope and subject. Copying from the write record instead would need a Maybe lookup with an unreachable arm on the commit path.
4. **Id 0 never cites a record because `empty` starts `next_id` at 1.** No separate `id > 0` gate exists. A synthetic state that stored a record under id 0 could be cited as the write approval, but every other gate would still revalidate it.
5. **The Revoked and moved-placement tests use synthetic states.** `revoke` arrives in Task 3. `with_revoked` stands in for it and sets only the flag that Task 3's `revoke` will set.
