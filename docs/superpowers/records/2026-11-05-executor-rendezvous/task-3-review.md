# Task 3 review: eligibility before ranking and deterministic selection (86c8dc4, review package 31f2492..86c8dc4)

Reviewer: task reviewer (security and proofs). Read-only apart from this file. Scratch: session scratchpad `executor-rendezvous-review-t3/`. It holds the runner `mutate.py`, the mutant list `mutants.py`, one tree per mutant under `mutant/<id>/`, the probes `probe/Probe.bend`, and `FixProbe.bend`, which holds the candidate fix checks.

## Verdicts

1. Spec compliance: **APPROVED**.
   - Every brief item is implemented.
   - The twelve eligibility gates run in order and each is pinned. I reran six of them and all six were killed.
   - The comparator is the strict lexicographic order on (quote, provider id, serial). The irreflexivity law covers it, and so do the identity-only tests.
   - The any-position drop law really is any-position. It is proved by induction on `before_list`, and the step rewrites under `keep_if`. The head-only fallback was not needed.
   - Stale selection, conflict refusal and single-use `abandon` and `withdraw_offer` all behave as specified, each with its named denial.
   - S8 and F2 are truly equivalent: I reran both and both survive, for the reasons argued.
   - Results: `bend Tests.bend` 1543 PASS, `bend PROOF.bend` 22 laws `ALL PROOFS CHECK`. LAWS and PROOF have additions only. Only touch-list files changed, and no count pin moved.
2. Security and code quality: **NEEDS_FIXES**.
   - I found no way to select an ineligible offer.
   - The selection's provider identity always equals the authenticated grant's subject.
   - No denial branch mutates state, and the quote is applied as a ceiling everywhere.
   - Two fixture collisions let commit-field mutants survive: Q1 and Q2. They are the same class as Task 1 F1 and Task 2 F2. Both fixes are one check each and are verified in scratch.
   - The rest are minor: comments made stale by this task, two overlong comment lines, and one argument-level mutant to record as equivalent.

## Findings (by severity)

### Q1 (Important, fixture collision): the recorded ranking profile is indistinguishable from the selected offer's profile

`Rendezvous.bend:1393` (`commit_selection`, field `ranking_profile()`) and `RendezvousTests.bend:1020` (the selection-record check).

Every selection the suite inspects is of a profile-1 offer, and `ranking_profile()` is also 1. My mutant R11 survives the whole suite. It records `Offer.profile(offer)` as the ranking profile, which needs `case Some{+offer}` to compile. Task 1.4 will invalidate on a ranking-profile change, so a later reader of this field would get a value that only coincides with the right one.

Fix, verified in scratch:
- Add a check that selects a profile-2 offer and asserts the full record with ranking 1.
- Use the constraint {1, 2} state `approved_a12()` with A's offer `{201, 2}` at profile 2 and quote 35.
- Expect `Selection{3, that offer, NT.request(), I.live(issuer()), 100, 1}`.

It passes on 86c8dc4 and kills R11.

### Q2 (Important, fixture collision): `retired` on an unrelated withdrawal is only tested at its initial value 0

`Rendezvous.bend:1521` (`commit_offer_withdrawal`, the keep branch `retired`) and `RendezvousTests.bend:1148` ("B withdrawing its unselected offer keeps A's selection and retires nothing").

The keep-branch test starts from `selected_ab()`, where `retired` is 0. My mutant R13 replaces the kept `retired` with `0n`: an unrelated withdrawal then wipes the record of an earlier retirement. It survives.

Fix, verified in scratch: add a check that withdraws B's `{202, 1}` from `Change.state(reselect_change())` at revision 7, where `retired` is 3, and asserts that it is accepted with `retired` 3. It passes on 86c8dc4 and kills R13.

### Q3 (Minor): comments this task made stale

- `Rendezvous.bend:891`: "(eligibility, a later task)". Eligibility now exists; name `eligibility_gates` instead.
- `Rendezvous.bend:1120-1121`: "Exported implementation helper for eligibility; a later task calls it with the snapshot's issuer and `now`". `eligibility_gates_found` now calls it through `origins_approved`; say so.
- `RendezvousTests.bend:176`: "(withdrawal is a later task)". `withdraw_offer` exists now; say that `withdrawn_a()` is the synthetic shape `withdraw_offer` leaves.

### Q4 (Nit): two overlong comment lines

- `Rendezvous.bend:944` (117 columns, the `submit_approval` doc, which Task 3 edited).
- `RendezvousTests.bend:14` (110 columns, header).

At 31f2492 no comment line exceeded 100 columns. Rewrap both.

### Q5 (Minor, record only): the IsCurrent gate's `now` argument is not independently pinned

`Rendezvous.bend:1199`. My mutant R2 evaluates `I.current` at time 0 instead of `Snapshot.now(snapshot)`, and it survives. I accept it as equivalent on issuer states built through Issuance's entry points:
- Gate 8 (offer unexpired at `now`) and gate 9 (offer `valid_until` <= grant `valid_until`) already imply that the grant is unexpired at `now`.
- Registration requires the request lifetime within each cited approval's lifetime (`Issuance.bend:1028`, `:1062`).
- Derivation requires the child's lifetime within the parent's (`:1625`, `:1749`).

So every time-dependent conjunct of `I.current` is implied. The revocation, epoch, directory and placement conjuncts do not depend on time, and E6 and the StaleEpoch check pin them.

Fix: add R2 to `task-3-mutants.md` as an argued equivalent, with this reasoning. No code change.

### Accepted, not findings

- R10 (`better` prefers the later record unless `before(a, b)`) is equivalent. On a list that `offers_unambiguous` admits, only identical records tie. `offer_order_irreflexive` is the law that excludes the `<=` comparator variant that would matter.
- R12 (ranking recorded as `record_version()`) survives because the plan fixes both constants at 1. F4 pins the value.

## Spec compliance: what I checked

- **Eligibility gates.** These are `eligibility_gates_found`, `Rendezvous.bend:1190-1209`. In order:
  1. version (UnknownVersion)
  2. identity owned by the claim (Unauthenticated)
  3. offer plan is the request plan (ScopeMismatch)
  4. grant BelongsTo (NoGrant)
  5. CoversPlan (ScopeMismatch)
  6. IsCurrent (`found_fault`: Expired, StaleEpoch or Revoked)
  7. HoldsRights (RightsNotHeld)
  8. offer unexpired (Expired)
  9. Outlives (Expired)
  10. `quote_admitted`, positive and `is_le` the ceiling (OverBudget)
  11. `profile_admitted` (Constraint)
  12. `origins_approved` over `T.required_origins(request plan, snapshot transfer)` (MissingApproval)

  Each gate has a mutant-killing check in the table. I reran six, all KILLED:
  - E4 by the NoGrant check;
  - E5 by the narrower-grant check;
  - E6 by the revoked-after-submission check;
  - E10b by the boundary-42 check;
  - E11 by the constraint check;
  - E12 by the cheapest-violates-origin check.

  E18 (`keep_if` keeps on False) is also KILLED, and it makes PROOF fail.
- **Ranking.**
  - `rank_before` is `lt(q) || (eq(q) && (lt(p) || (eq(p) && lt(s))))`.
  - The `offer_order_irreflexive` proof (`PROOF.bend`) matches the offer and rewrites `lt(q,q)`, `eq(q,q)`, `lt(p,p)` and `eq(p,p)` through `Equal.sym` of the two helper laws. It closes with `nat_lt_irreflexive(s)`. Both helpers are used. Each is a genuine induction over `Nat`, not an `x == x` statement.
  - Two identity-only tests cover the order:
    - "offers equal in every field but OfferId are ranked by identity alone ... before is false both ways only for the same identity";
    - "a lower provider id beats a lower serial".
  - The quote-level test is "a lower quote beats a lower provider id".
- **Any position.** `rendezvous_ineligible_offer_dropped` quantifies over `before_list`, `o`, `rest`, `state` and `snapshot`, with hypothesis `eligible(o, ..) == False`. The conclusion is about `eligible_offers(append(before_list, Offers{o, rest}))`. The proof is by induction on `before_list`:
  - The base case rewrites the `keep_if` scrutinee with the reversed hypothesis.
  - The step case rewrites the inner list with the induction hypothesis under `keep_if(eligible(head), head, _)`.

  It is not a head-only statement.
- **Stale selection.** `rendezvous_stale_selection_keeps_state` rewrites `Nat.is_eq(revision, 1+revision)` with `nat_eq_successor_false` inside `select_current`. My R9 makes the stale branch return a modified state, and it is KILLED by the StaleRevision check and makes PROOF fail. So the law really pins both the outer match and the "Rejected carries the caller's state" part.
- **Conflict refusal.** The `offers_unambiguous` gate is ConflictingOffer, checked with the conflicting pair split or adjacent. Identical duplicates select normally. Two selections cannot both commit: the second sees AlreadySelected, and a select at an old revision gets StaleRevision with the state unchanged. My R8 (the gate-failure branch returns a modified state) is KILLED.
- **Single use.**
  - `abandon`: a second call gets NotSelected, and a stale one gets StaleRevision.
  - `withdraw_offer`:
    - a second withdrawal, or one of a never-stored id, gets Revoked (controller ruling);
    - a withdrawal by another principal gets Unauthenticated;
    - a stale one gets StaleRevision.
  - Each denial goes through `denied` (exact `Error.equal`, full `State.equal`).
- **S8.** Unreachable: `select_checked` reaches `commit_selection` only when the last gate holds (nonempty `eligible_offers`), and `best` of a nonempty list is `Some`. S5 is still pinned by the direct `select_checks` assertion.
- **F2.** Equivalent: on acceptance some offer passed gate 12, so `origins_approved` is Found and nonempty, and each `stored_covers` requires `T.Stamp.equal(T.Plan.stamp(request plan), I.live(issuer))`. Gates 5 and 6 also force the grant scope plan to be the request plan at the live stamp. My F2 (`T.Plan.stamp(N.Request.plan(request))`) survives.
- **Counts and touch list.**
  - Suite and proofs: `bend Tests.bend` exits 0, 0 FAIL, `ALL LIBRARY TESTS PASSED`, 1543 PASS (1490 `PASS:` plus 53 `PASS `). `bend PROOF.bend` prints `ALL PROOFS CHECK`; there are 22 `law`s and 22 `Laws.` defs. `git diff master -- LAWS.bend PROOF.bend` removes 0 lines.
  - Touch list: `git diff --stat 31f2492 86c8dc4` lists only `LAWS.bend`, `PROOF.bend`, `Rendezvous.bend`, `RendezvousTests.bend`, `tasks.md` and the records. `Tests.bend` and every count pin are untouched.
- **Spec scenarios.** ER-002, ER-003 (both scenarios) and ER-008 each have a named test, and `tasks.md` box 1.2 cites them.

## Security: what I tried

Probes are in scratch `probe/Probe.bend`, run on the delivered tree. All PASS:
- When the only offer quotes 43 against the ceiling 42, the result is NoEligibleOffer and the state is unchanged.
- A (lower id) at 43 against B at 42: B is selected, so a lower identity cannot carry an over-ceiling quote.
- A and B both at exactly 42: A is selected by identity, so the ceiling is inclusive and never exact.
- After withdrawal, A resubmitting serial 1 with different content (quote 35) is denied Replay.
- Lifetime boundaries for an offer until 140, its grant until 150 and its approvals until 130: the offer is selected at 129 and denied NoEligibleOffer at 130, 140 and 150.
- An issuer epoch advance gives NoEligibleOffer.
- A monitor-installed offer under B's identity with A's claim is never selected.

My own mutants, beyond the reruns:

| Id | Mutation | Result |
|---|---|---|
| R1 | offer `unexpired` at time 0 (stale `now`) | KILLED (expired-offer check) |
| R2 | `I.current` evaluated at time 0 | SURVIVED, equivalent (Q5) |
| R3 | ceiling applied as exact (`is_eq`) | KILLED |
| R4 | ceiling applied as a floor | KILLED |
| R5 | `select` ranks `offers(state)`, not `eligible_offers` | KILLED |
| R6 | conflict test blind to content | KILLED |
| R7 | `withdraw_offer` ownership gate -> True | KILLED |
| R8 | select gate-failure branch returns a modified state | KILLED |
| R9 | select stale branch returns a modified state | KILLED, PROOF FAIL |
| R10 | `better` prefers the later record on ties | SURVIVED, equivalent |
| R11 | ranking recorded as the offer's profile | SURVIVED (Q1) |
| R12 | ranking recorded as `record_version()` | SURVIVED, same constant by plan |
| R13 | unrelated withdrawal resets `retired` to 0 | SURVIVED (Q2) |

Other points:
- **Provider identity.** The selection stores the complete offer, including its provider claim. Eligibility requires two things:
  - `id_owned_by(id, provider)`;
  - grant BelongsTo, `I.speaks_for_subject(provider, scope)`, which compares the principal id.

  `I.Principal` is `Principal{id}`, so the stored claim equals the authenticated grant's subject on every accepting path. The ranking key's provider part is `OfferId.provider`, which gate 2 makes equal to it. No offer field confers authority.
- **Stale state and the gate-commit window.** `select` evaluates the gates and the ranking against the same `state` and `snapshot` in one pure call, so no grant can expire between gate and commit. Later use must revalidate the selection; that is the plan's per-use projection obligation, for Tasks 4 and 5.
- **Denial branches.** Every `Rejected` carries the supplied `state`; the unreachable S8 arm is included.
- **Partial matches.** None. `commit_selection` handles None, and `retired_id` handles NoSelection.
- **Laws in the header.** Each of the five has a rationale in `LAWS.bend` and in the `Rendezvous.bend` header "Laws" paragraph; the two helpers get one shared sentence there.
- **Forward note, not a finding.** `withdraw_offer` and `abandon` do not inspect `evidence` or `dispatched`. Task 1.4 and the dispatch task must deny evidence or dispatch for a retired selection id.

## Commands run

Environment: `export PATH="$HOME/.local/share/writ-toolchains/bend-2.0.39/bend/bin:$PATH"; export BEND_NO_TELEMETRY=1`, worktree at 86c8dc4.

- `bend Rendezvous.bend --check-only`: `ALL PROOFS CHECK`
- `bend RendezvousTests.bend`: `Rendezvous: 115 checks passed`
- `bend Tests.bend`: exit 0, `ALL LIBRARY TESTS PASSED`, 1543 PASS
- `bend PROOF.bend`: exit 0, `ALL PROOFS CHECK` / `Use --verdict for mathematical validity.`

Not run: `--verdict`, native, JS, GPU and OpenSpec (Task 8).
