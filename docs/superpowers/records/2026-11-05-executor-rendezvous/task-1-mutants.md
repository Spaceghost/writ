# Task 1 mutants (submit_offer)

Each mutant was made in a scratch copy at `/mnt/MediaVolume/Media/src/github.com/spaceghost/writ-build/executor-rendezvous/mutant/` (outside the worktree; note this is `../../writ-build/` from the worktree, one level above the plan's `../writ-build/`), by applying one textual replacement to `Rendezvous.bend` and running `bend RendezvousTests.bend` there. "Killing test" is the first failing check. G rows are the 14 `offer_gates_found` gates, each with its condition replaced by `True{}`; H rows are helper, comparator and commit mutants.

| Mutant | Mutation | Result | Killing test |
|---|---|---|---|
| G1 | revision_current | KILLED | ER-001 B's offer validated at revision 0 against the state at revision 1 denied StaleRevision |
| G2 | version_supported | KILLED | ER-001 offer record version 2 denied UnknownVersion |
| G3 | claim_matches | KILLED | ER-001 unauthenticated provider: from B submitting an offer claiming provider A denied Unauthenticated |
| G4 | id_owned_by | KILLED | ER-008 from A submitting under OfferId{202, 1}, B's identity namespace, denied Unauthenticated |
| G5 | plan_is_request | KILLED | ER-001 an offer whose plan names destination 20v9 instead of the request's 20v8 denied ScopeMismatch |
| G6 | BelongsTo | KILLED | ER-001 provider C with no registered grant denied NoGrant |
| G7 | CoversPlan | KILLED | ER-001 scope narrower than the plan: A's grant 3 for the one-source plan behind an offer for the two-source request denied ScopeMismatch |
| G8 | IsCurrent | KILLED | ER-001 after object 10's read authority revokes the source approval behind grant 3, A's offer is denied Revoked |
| G9 | HoldsRights | KILLED | ER-001 provider D's current grant 9 with rights 1 does not cover read plus execute: denied RightsNotHeld |
| G10 | offer unexpired | KILLED | ER-001 an offer submitted at its own valid_until 100 denied Expired |
| G11 | Outlives | KILLED | ER-001 an offer valid until 160, past grant 3's 150, denied Expired |
| G12 | quote_named | KILLED | ER-001 an offer quoting 0 names no billing term: denied OverBudget |
| G13 | DuplicateOffer | KILLED | ER-008 a second identical record under OfferId{201, 1} denied DuplicateOffer |
| G14 | Replay | KILLED | ER-008 A's serial 1 already seen with no record stored under it (the shape a withdrawal leaves) denied Replay |
| H1 | grant_fault Expired branch to Revoked | KILLED | ER-001 A's offer at 150, when grant 3 (valid while now < 150) has expired, denied Expired |
| H2 | grant_fault StaleEpoch branch to Revoked | KILLED | ER-001 once the monitor installs authority epoch 5 in the issuer, A's grant scoped at epoch 3 is stale: denied StaleEpoch |
| H3 | grant_fault Revoked branch to Expired | KILLED | ER-001 after object 10's read authority revokes the source approval behind grant 3, A's offer is denied Revoked |
| H4 | unexpired is_lt to is_le | KILLED | ER-001 A's offer at 150, when grant 3 (valid while now < 150) has expired, denied Expired |
| H5 | Outlives is_le to is_lt | KILLED | ER-001 an offer valid until 150, exactly grant 3's own valid_until, is accepted |
| H6 | Outlives always true | KILLED | ER-001 an offer valid until 160, past grant 3's 150, denied Expired |
| H7 | rights_cover arguments swapped | KILLED | ER-001 provider D's current grant 9 with rights 1 does not cover read plus execute: denied RightsNotHeld |
| H8 | provider_rights 5 to 1 | KILLED | ER-001 provider D's current grant 9 with rights 1 does not cover read plus execute: denied RightsNotHeld |
| H9 | grant_subject_is always true | KILLED | ER-001 grant_backs: grant 3 backs A for TF.plan() and neither B nor the two-source plan |
| H10 | grant_plan_is always true | KILLED | ER-001 grant_backs: grant 3 backs A for TF.plan() and neither B nor the two-source plan |
| H11 | offer_exists ignores provider | KILLED | ER-001 same code different provider: B's offer with A's code, plan, profile and quote is stored as a second record |
| H12 | offer serial ignores provider | KILLED | ER-001 same code different provider: B's offer with A's code, plan, profile and quote is stored as a second record |
| H13 | grant_meets None true | KILLED | ER-001 provider C with no registered grant denied NoGrant |
| H14 | version_supported any | KILLED | ER-001 offer record version 2 denied UnknownVersion |
| H15 | commit keeps revision | KILLED | ER-001 provider A's offer backed by its current grant 3 is stored at revision 1 and (A, serial 1) is recorded as seen |
| H16 | commit drops serial | KILLED | ER-001 provider A's offer backed by its current grant 3 is stored at revision 1 and (A, serial 1) is recorded as seen |
| H17 | commit drops offer | KILLED | ER-001 provider A's offer backed by its current grant 3 is stored at revision 1 and (A, serial 1) is recorded as seen |
| H18 | offers_valid ownership dropped | KILLED | ER-008 valid: an offer whose identity names another provider, or a serial recorded twice, is not a valid state |
| H19 | serials_valid duplicate check dropped | KILLED | ER-008 valid: an offer whose identity names another provider, or a serial recorded twice, is not a valid state |
| H20 | id_owned_by always true | KILLED | ER-008 valid: an offer whose identity names another provider, or a serial recorded twice, is not a valid state |

Before the final sweep, two mutants survived and were killed by added checks: H5 (`Outlives` `is_le` to `is_lt`) by "ER-001 an offer valid until 150, exactly grant 3's own valid_until, is accepted", and H16 (commit drops the serial) by the strengthened acceptance check, which now asserts the exact `offers` list and the exact `seen` list `[OfferSerial{A, 1}]`.

Not in the table: recording the offer's `provider` claim instead of `from` in `commit_offer` does not type-check (the offer is affine and already stored), and it is equivalent by construction anyway, because the `claim_matches` gate makes the two equal before `commit_offer` runs.

Masking notes. G8 (`IsCurrent`) is killed by the Revoked check. The Expired-at-150 check alone would not kill it, because the offer-lifetime gate G10 would also deny Expired at 150. G6 (`BelongsTo`) is killed first by the no-grant check. The B-citing-A's-grant check also kills it by construction: with the gate removed, grant 3 passes every later gate for B. The run stops at the first failure, so that second kill is not shown in the table. No mutant survives, and none is claimed equivalent.

## Fix round 1

This round reruns the review's mutants N1 to N14 together with the original 34, after the six added checks. All 48 are KILLED (the sweep script is in `scratchpad/executor-rendezvous-t1/er_mutate.py`). I reran the original 34 too, and each is still killed by the same first check as in the table above.

| Mutant | Mutation | Result | Killing test |
|---|---|---|---|
| N1 | offer_equal drops version | KILLED | ER-008 offer_equal distinguishes every single-field change: version 2, grant 4, another code word, profile 2, quote 35, valid_until 139 |
| N2 | offer_equal drops grant | KILLED | ER-008 offer_equal distinguishes every single-field change: version 2, grant 4, another code word, profile 2, quote 35, valid_until 139 |
| N3 | offer_equal drops plan | KILLED | ER-008 offer_equal distinguishes every single-field change: version 2, grant 4, another code word, profile 2, quote 35, valid_until 139 |
| N4 | offer_equal drops profile | KILLED | ER-008 offer_equal distinguishes every single-field change: version 2, grant 4, another code word, profile 2, quote 35, valid_until 139 |
| N5 | offer_equal drops quote | KILLED | ER-008 offer_equal distinguishes every single-field change: version 2, grant 4, another code word, profile 2, quote 35, valid_until 139 |
| N6 | offer_equal drops valid_until | KILLED | ER-008 offer_equal distinguishes every single-field change: version 2, grant 4, another code word, profile 2, quote 35, valid_until 139 |
| N7 | OfferId.equal drops serial | KILLED | ER-008 a second A offer under OfferId{201, 7} is accepted beside OfferId{201, 1}, issues 7, and seen is exactly (A, 7) then (A, 1) |
| N8 | serial_entry drops serial | KILLED | ER-008 a second A offer under OfferId{201, 7} is accepted beside OfferId{201, 1}, issues 7, and seen is exactly (A, 7) then (A, 1) |
| N9 | commit records profile as serial | KILLED | ER-008 a second A offer under OfferId{201, 7} is accepted beside OfferId{201, 1}, issues 7, and seen is exactly (A, 7) then (A, 1) |
| N10 | Replay gate checks serial 1 | KILLED | ER-008 a second A offer under OfferId{201, 7} is accepted beside OfferId{201, 1}, issues 7, and seen is exactly (A, 7) then (A, 1) |
| N11 | id_owned_by compares serial to 1 | KILLED | ER-008 valid: an offer whose identity names another provider, or a serial recorded twice, is not a valid state |
| N12 | offer_exists compares provider only | KILLED | ER-008 a second A offer under OfferId{201, 7} is accepted beside OfferId{201, 1}, issues 7, and seen is exactly (A, 7) then (A, 1) |
| N13 | version is_eq to is_le | KILLED | ER-001 offer record version 0 denied UnknownVersion |
| N14 | serial_equal cross arm True | KILLED | ER-008 valid: A's offer serial 1 beside an approval serial 1 from the same principal is valid, the two namespaces being separate |

N14 is reachable as a structural question. `valid` is a public entry point over any supplied state, and the check uses a synthetic monitor state that holds both namespaces, so I did not record N14 as source-reviewed. N10 is killed first by the second-offer check, because with the Replay gate checking serial 1 A's serial-7 submission on `with_a()` is denied Replay. The new serial-7 Replay check also pins it.
