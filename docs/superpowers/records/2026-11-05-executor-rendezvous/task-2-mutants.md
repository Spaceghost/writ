# Task 2 mutants: origin approvals

Method: `scratchpad/executor-rendezvous-t2/mutate.py` (session scratchpad) copies every root `*.bend` of the worktree into `scratchpad/executor-rendezvous-t2/mutant/<id>/`, applies one textual replacement to `Rendezvous.bend` (the pattern must occur exactly once), runs `bend RendezvousTests.bend` there and records the first `FAIL:` line. The worktree itself is never mutated. Final sweep on the delivered tests (70 Rendezvous checks).

## First sweep (before the two added checks)

54 mutants; 51 killed, 3 survived:

| Mutant | Why it survived | Check added |
|---|---|---|
| H6 `approval_serial_seen` head only | every replayed serial was at the head of `seen` | "ER-006 101's serial 12, recorded behind its serial 13, denied Replay" |
| W7 `approval_id_exists` head only | the duplicate-id fixture held the duplicate directly behind the head | `duplicate_ids()` now puts id 2 between the two id-1 records; the MissingApproval check also asserts `Bool.not(R.valid(duplicate_ids()))` |
| W16 `approval_issued_by` None -> True | masked by the earlier `approval_present` gate | "ER-006 withdrawal helpers behind the MissingApproval gate: ..." calls the exported helpers directly (also kills W17, W18) |

## Final sweep

| Id | Mutation | Result | First killing check |
|---|---|---|---|
| A1 | gate revision_current | KILLED | ER-006 an approval validated at revision 0 against the state at revision 1 denied StaleRevision |
| A2 | gate version_supported | KILLED | ER-006 approval record versions 2 and 0 denied UnknownVersion |
| A3 | gate claim_matches | KILLED | ER-006 unauthenticated approver: from the write authority 102, an approval claiming object 10's authority 101 denied Unauthenticated |
| A4 | gate origin_placed | KILLED | ER-006 the inherited origin 30v6, listed by T.required_origins but placed nowhere in the issuer, denied WrongDomain |
| A5 | gate speaks_for_origin | KILLED | ER-006 the write authority 102 approving object 10 under its own identity denied NotAuthority |
| A6 | gate speaks_for_origin uses the claim | NOT BUILT | equivalent, see below |
| A7 | gate plan_is_request | KILLED | ER-006 an approval for a plan that differs from the request's in invocation (98, not 99) denied ScopeMismatch |
| A8 | gate unexpired | KILLED | ER-006 an approval submitted at its own valid_until 100 denied Expired |
| A9 | gate Replay | KILLED | ER-006 101 reusing serial 12 for a different approval (provider B, profile 2) denied Replay |
| A10 | unexpired is_lt -> is_le (shared helper) | KILLED | ER-001 A's offer at 150, when grant 3 (valid while now < 150) has expired, denied Expired |
| H1 | authority_in None -> True | KILLED | ER-006 origin_approved re-reads the issuer: false once 101 leaves the directory, once object 10 moves to read domain 9, or once object 10 is placed twice |
| H2 | authority_in Some -> True | KILLED | ER-006 the write authority 102 approving object 10 under its own identity denied NotAuthority |
| H3 | approval_serial_entry drop issuer clause | KILLED | ER-006 object 11's authority 104 may use serial 12 after 101 used it: replay is per issuer |
| H4 | approval_serial_entry drop serial clause | KILLED | ER-006 101's second approval, serial 13 for provider B at profile 2, is stored under id 2 beside id 1; seen is exactly (101, 13) then (101, 12) |
| H5 | approval_serial_entry offer arm -> issuer/serial match | KILLED | ER-006 an offer serial 12 recorded for 101 does not replay 101's approval serial 12: separate namespaces |
| H6 | approval_serial_seen head only | KILLED | ER-006 101's serial 12, recorded behind its serial 13, denied Replay |
| C1 | commit_approval keeps next_id | KILLED | ER-006 object 10's read authority 101 approves provider A at profile 1 for TF.plan(): stored unwithdrawn under id 1 at revision 1, (101, serial 12) seen |
| C2 | commit_approval stores withdrawn | KILLED | ER-006 object 10's read authority 101 approves provider A at profile 1 for TF.plan(): stored unwithdrawn under id 1 at revision 1, (101, serial 12) seen |
| C3 | commit_approval drops serial | KILLED | ER-006 object 10's read authority 101 approves provider A at profile 1 for TF.plan(): stored unwithdrawn under id 1 at revision 1, (101, serial 12) seen |
| C4 | commit_approval records offer namespace | KILLED | ER-006 object 10's read authority 101 approves provider A at profile 1 for TF.plan(): stored unwithdrawn under id 1 at revision 1, (101, serial 12) seen |
| C5 | commit_approval serial := profile | KILLED | ER-006 object 10's read authority 101 approves provider A at profile 1 for TF.plan(): stored unwithdrawn under id 1 at revision 1, (101, serial 12) seen |
| C6 | commit_approval keeps revision | KILLED | ER-006 object 10's read authority 101 approves provider A at profile 1 for TF.plan(): stored unwithdrawn under id 1 at revision 1, (101, serial 12) seen |
| W1 | withdraw gate revision_current | KILLED | ER-006 a withdrawal validated at revision 0 against the state at revision 1 denied StaleRevision |
| W2 | withdraw gate approval_present | KILLED | ER-006 withdrawal of an absent id 5, or of id 1 held by two records with id 2 between them (synthetic, not valid), denied MissingApproval |
| W3 | withdraw gate approval_issued_by | KILLED | ER-006 withdrawal of approval 1 by 103, not its issuer, denied Unauthenticated |
| W4 | withdraw gate approval_still_authority | KILLED | ER-006 withdrawal by 101 after the monitor removed it from the directory denied NotAuthority |
| W5 | withdraw gate not_yet_withdrawn | KILLED | ER-006 a second withdrawal of approval 1 denied Revoked: withdrawal is single use |
| W6 | first_approval ambiguous -> first | KILLED | ER-006 withdrawal of an absent id 5, or of id 1 held by two records with id 2 between them (synthetic, not valid), denied MissingApproval |
| W7 | approval_id_exists head only | KILLED | ER-006 withdrawal of an absent id 5, or of id 1 held by two records with id 2 between them (synthetic, not valid), denied MissingApproval |
| W8 | find_approval head only | KILLED | ER-006 withdrawing approval 1 leaves approval 2 unwithdrawn, and withdrawing 2 later keeps 1 withdrawn |
| W9 | approval_entry ignores id | KILLED | ER-006 withdrawing approval 1 leaves approval 2 unwithdrawn, and withdrawing 2 later keeps 1 withdrawn |
| W10 | mark_withdrawn clears earlier flags | KILLED | ER-006 withdrawing approval 1 leaves approval 2 unwithdrawn, and withdrawing 2 later keeps 1 withdrawn |
| W11 | mark_withdrawn marks every record | KILLED | ER-006 withdrawing approval 1 leaves approval 2 unwithdrawn, and withdrawing 2 later keeps 1 withdrawn |
| W12 | mark_withdrawn no-op | KILLED | ER-006 101 withdraws approval 1: the record stays in place marked withdrawn, its serial stays seen, revision 2 |
| W13 | withdraw_in head only | KILLED | ER-006 withdrawing approval 1 leaves approval 2 unwithdrawn, and withdrawing 2 later keeps 1 withdrawn |
| W14 | commit_withdrawal keeps revision | KILLED | ER-006 101 withdraws approval 1: the record stays in place marked withdrawn, its serial stays seen, revision 2 |
| W15 | commit_withdrawal drops seen | KILLED | ER-006 101 withdraws approval 1: the record stays in place marked withdrawn, its serial stays seen, revision 2 |
| W16 | approval_issued_by None -> True | KILLED | ER-006 withdrawal helpers behind the MissingApproval gate: a missing approval has no issuer, no authority and no unwithdrawn flag |
| W17 | approval_still_authority None -> True | KILLED | ER-006 withdrawal helpers behind the MissingApproval gate: a missing approval has no issuer, no authority and no unwithdrawn flag |
| W18 | not_yet_withdrawn None -> True | KILLED | ER-006 withdrawal helpers behind the MissingApproval gate: a missing approval has no issuer, no authority and no unwithdrawn flag |
| W19 | withdraw authority uses the stored issuer claim | NOT BUILT | equivalent, see below |
| A6b | gate speaks_for_origin uses the claim (+issuer so it builds) | SURVIVED | equivalent, see below |
| W19b | withdraw authority uses the stored issuer claim (+stored so it builds) | SURVIVED | equivalent, see below |
| V1 | approvals_valid ignores duplicates (valid) | KILLED | ER-006 withdrawal of an absent id 5, or of id 1 held by two records with id 2 between them (synthetic, not valid), denied MissingApproval |
| P1 | stored_covers drop withdrawn | KILLED | ER-006 origin_approved is false after withdrawal |
| P2 | stored_covers drop origin | KILLED | ER-006 origin_approved is false for another plan and for another origin (object 11) |
| P3 | stored_covers drop provider | KILLED | ER-006 origin_approved is false for provider B and for profile 2 when only A at profile 1 was approved |
| P4 | stored_covers drop profile | KILLED | ER-006 origin_approved is false for provider B and for profile 2 when only A at profile 1 was approved |
| P5 | stored_covers drop plan | KILLED | ER-006 origin_approved is false for another plan and for another origin (object 11) |
| P6 | stored_covers drop unexpired | KILLED | ER-006 origin_approved is false at now = valid_until 130 |
| P7 | stored_covers drop authority | KILLED | ER-006 origin_approved re-reads the issuer: false once 101 leaves the directory, once object 10 moves to read domain 9, or once object 10 is placed twice |
| P8 | stored_covers unexpired is_lt -> is_le | KILLED | ER-006 origin_approved is false at now = valid_until 130 |
| P9 | origin_approved head only | KILLED | ER-006 origin_approved: object 10 approved for A at profile 1 at 100 and 129, also with B's approval stored ahead of it, and for B at profile 2 |
| P10 | origin_approved empty -> True | KILLED | ER-006 origin_approved is false for provider B and for profile 2 when only A at profile 1 was approved |
| P11 | origins_all first only | KILLED | ER-006 two-source plan: approval of object 10 only leaves origins_approved false; approving object 11 too makes it true |
| P12 | origins_approved Missing -> True | KILLED | ER-006 origins_approved: true for TF.plan() with object 10 approved; false for a Missing lookup (also via a stale context) and for an empty one |
| P13 | origins_approved drop nonempty | KILLED | ER-006 origins_approved: true for TF.plan() with object 10 approved; false for a Missing lookup (also via a stale context) and for an empty one |
| P14 | origins_all empty -> False | KILLED | ER-006 origins_approved: true for TF.plan() with object 10 approved; false for a Missing lookup (also via a stale context) and for an empty one |

## Equivalent mutants (argument for the reviewer)

- A6 / A6b: the NotAuthority gate reads the approval's `issuer` claim instead of `from`. A6 does not build (`issuer` is linear and already consumed by `claim_matches`); A6b adds `+issuer` so it builds, and it survives. It is equivalent: `claim_matches(from, issuer)` is gate 3 of the same list, so whenever the authority gate is reached in the reason order or contributes to `Guard.all` acceptance, `issuer` equals `from` (`I.Principal.equal` compares the single `id` field); when they differ, gate 3 is the first failing gate and the reason is Unauthenticated either way. The delivered code reads `from`, so no approval's `issuer` decides authority.
- W19 / W19b: the withdrawal authority check reads the stored approval's issuer instead of `from`. W19 does not build (`stored` linear); W19b (`+stored`) survives. Equivalent for the same reason: `approval_issued_by` (gate 3) requires the stored issuer to equal `from` before the authority gate can matter. The delivered code reads `from`.

58 mutants in all. The other 54 (A1-A5, A7-A10, H1-H6, C1-C6, W1-W18, V1, P1-P14) are KILLED.
