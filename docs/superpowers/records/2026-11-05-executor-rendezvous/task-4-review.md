# Task 4 review: trial evidence, owner approvals and reader terms bound to the selection (00fecb4, review package b7900a3..00fecb4)

Reviewer: task reviewer (security and proofs). Read-only apart from this file. Scratch: session scratchpad `executor-rendezvous-review-t4/`. It holds:
- the runner `rmut.py` and its outputs `m1.out` to `m4.out`;
- `probe/Probe.bend`, the attack probes, run against 00fecb4 unchanged;
- `probeR1/`, the reselection probe run against mutant R1;
- `fix/`, a tree with the candidate fixes for S1 and S2 applied, plus its probe.

## Verdicts

1. Spec compliance: **APPROVED**.
   - Every brief item is implemented: `Evidence`, `submit_evidence` with its outermost `selected_provider_is` match and the gate order, `negotiation_context`, the `trials` section, the law, the mutation table and box 1.3.
   - Every evidence field is substituted from the passing fixture and denied with the exact reason: version, provider, offer, challenge, code and sample. So are the input scope (through the sample's plan) and the epoch (through the live stamp).
   - Evidence against no selection, an abandoned selection or a selection that is no longer current is denied, and the state is returned unchanged.
   - The projection is empty with no selection, and whenever `selection_current` fails.
   - The law is a real statement and its proof has no hole (details below).
   - P14, P18 and T10 are truly equivalent: I reran all three, all three survive, and the arguments hold.
   - Results: `bend Tests.bend` gives 1579 PASS, 0 FAIL and `ALL LIBRARY TESTS PASSED`. `bend PROOF.bend` gives `ALL PROOFS CHECK` with 23 laws. `bend Rendezvous.bend --check-only` gives `ALL PROOFS CHECK`.
   - LAWS and PROOF have additions only. Only touch-list files changed, Tests.bend is unchanged by this task, no count pin moved, and box 1.3 is checked with its citations.
2. Security and code quality: **NEEDS_FIXES**.
   - `submit_evidence` is sound. It stores nothing on any denial branch. Its outer match uses the authenticated `from` and never the claim (my mutant R2 is killed and fails PROOF). The stored provider is a claim already proved equal to `from` by `I.claim_matches`, which is `Principal.equal`.
   - The projection's three lists are correct for the current selection, but the guarantee the header and report claim does not hold end to end. A Negotiation session sampled under a retired selection keeps advancing (`N.approve`, `N.reserve`, `N.start`) on the next selection's projection (S1).
   - The sample projection is keyed on the selection id alone. A state that `valid` accepts can therefore project evidence that names another provider's offer (S2).
   - Keying on the offer instead of the selection survives the suite (S3).
   - The rest are minor.

## Findings (by severity)

### S1 (Important, security): a session sampled under a retired selection advances on the next selection's projection

Where:
- `Rendezvous.bend:138-147`, the header "Projection" paragraph: "so the unchanged `N.challenge`, `N.sample`, `N.approve`, `N.reserve` and `N.start` deny once a selection is abandoned...";
- `Rendezvous.bend:2026-2045`, the `negotiation_context` doc;
- `task-4-report.md:57`: "It cannot carry a stale selection...".

The probe is `probe/Probe.bend`, run on 00fecb4 unchanged:
1. Selection 3 picks A. `sampled_t()` (A's sample 31, challenge 21) reaches Sampled on A's projection.
2. `abandon`, then B is selected as selection 4 (`selected_b()`).
3. `N.approve(sampled_t(), 3n, proj_b(selected_b()))` is accepted. So are `N.reserve` (receipt 11) and `N.start` on the same projection.

So A's trial, under a retired selection, carries a Negotiation session up to Running for B. B was never sampled in that session.

Why the projection cannot catch it:
- `N.approve`, `N.reserve` and `N.start` re-check owners, budgets and the hold, but never the challenge or the sample.
- `N.Session` carries no provider or selection.
- `negotiation_context` does not take the session.

This is the ER-005 "Reusing another provider's sample" outcome at the Negotiation level, and the ER-007 substitution case.

The lists themselves are correct. Only a session that was already Sampled crosses over: a session still at Challenged with 21 is denied by `N.sample`, because 21 is not projected for selection 4.

Fix, verified in scratch (`fix/`: suite 151 checks, PROOF `ALL PROOFS CHECK`):
1. Add the exported helper `session_follows_selection(state, session)`. It holds when the session's request is exactly `request(state)` and `session_challenge(session)` is the challenge of evidence stored under the current selection's id. Write it through an inner `session_follows(selection, state, session)` defined before it; Bend rejects a match on `selection(state)` and a call to a def defined later.
   - Scratch results: it is False for `sampled_t()` and for its approved successor against B's evidenced state. It is True for `challenged_b()` there, and for `sampled_t()` against `evidenced()`. It is False before any evidence.
   - Add one check pinning these results.
2. Correct the header paragraph, the `negotiation_context` doc and the report. They should say that the projection does not bind a Negotiation session to the selection: a session that reached Sampled under a retired selection still passes `N.approve`, `N.reserve` and `N.start` on a later projection. Binding the session is the dispatch gate's job.
3. Controller: amend the Task 5 brief so that `dispatch` gates on `session_follows_selection` (reason `MissingEvidence` or `WrongTrial`). Add the test above: abandon, select B, B's evidence, then dispatch with A's session reaching Running. The probe already shows that session reaching Running.

### S2 (Important, defense in depth): the sample projection trusts the stored evidence's selection id alone

Where: `Rendezvous.bend:1903-1906` (`evidence_names`) and `Rendezvous.bend:2008-2016` (`selected_context`).

The probe uses `foreign()`: `selected_t()` with `StoredEvidence{3, ev_b(31, 21)}`. That record is under A's current selection id, but it names B's offer `{202, 5}` and B's provider claim. `R.valid(foreign())` is True, and `negotiation_context` projects sample 31.

Transitions cannot build this state, because `submit_evidence` binds offer and claim before it stores. But the plan says every projection revalidates "the selection's identity" at every call. The evidence record already holds the offer and claim to compare.

Fix, verified in scratch (`fix/`: 151 checks pass, and `foreign()` projects no sample):
- Pass the selected `Offer` down through `projected_samples`, `sample_named` and `evidence_named`.
- In `evidence_names`, also require `OfferId.equal(named_offer, Offer.id(offer)) && I.Principal.equal(provider, Offer.provider(offer))`. The existing direct call at `RendezvousTests.bend` (the "provider swaps code" check) then passes `offer_ta()`.
- Add a check with the `foreign()` fixture, which kills dropping either new conjunct.

### S3 (Important, test gap): keying the sample projection on the offer instead of the selection survives

My mutant R1 keys `evidence_names` on the evidence's offer serial against the selected offer's serial, instead of the selection id. It survives all 151 checks. The only re-selection test selects a different offer, B, so A's old evidence fails on the offer as well as on the selection id.

Fix, verified: add a check that re-selects the same offer.
- After `abandoned_t()`, `R.select(abandoned_t(), 7n, NT.pinned(), 1n, NT.context(106n), snapshot_with(issuer(), 106n))` is accepted and selects A's `{201, 4}` again, as selection 4.
- Its `negotiation_context` at 110 over `trial_raw()` carries no sample, although the retired selection 3's evidence names 31.
- This passes on 00fecb4 (`probe/`) and kills R1 (`probeR1/`).

### S4 (Minor): the challenge window relies on monotone monitor time, which is unstated

Where: `Rendezvous.bend:138-147` and `2026-2045`.

Challenges carry no provider or selection. The projection admits any challenge for the plan issued strictly after the current `selected_at`. That excludes every challenge from an earlier selection only if `Snapshot.now` at `select` is no earlier than every challenge already issued. Nothing records or checks this: `select` stores `Snapshot.now(snapshot)` as given.

With monotone time the window is sound. I checked the edges, including abandon and reselect at the same `now`, which strictness excludes. So the controller ruling (challenge window re-checked by Negotiation) is acceptable.

Fix: add one sentence to both docs stating that the host supplies non-decreasing monitor time across selections, and that challenge ids are not reused across selections (S1's binding relies on this too).

### S5 (Minor): one check name overclaims

Where: `RendezvousTests.bend:1546`.

"B submitting A's sample 31 and challenge 21 as its own" is denied at the session-challenge gate (B's session is at 26), not by any sample check. The second sub-case (A's 31 under 26) does reach `sample_found`.

Fix: rename the first part "B naming A's challenge 21 and sample 31 on its session challenged with 26".

### S6 (Nit): approval-order wording

Where:
- `RendezvousTests.bend:1185-1189`: "B by approval_tb() ... then A by approval_a() ..., so the first stored approval is A's";
- `task-4-report.md:69` and `156`: "B's approval is stored before A's" and "A's approval is stored first".

Both readings are true (`commit_approval` prepends), but they read as contradictory.

Fix: say "B's is submitted first, so A's record heads the stored list and `covering_until` meets it first".

## The law and its proof

- Statement (`LAWS.bend:291-314`): for every state, expected revision, `from`, evidence, session, context and snapshot, given `{selected_provider_is(state, from) == False}`, the pair (`accepted`, `state`) of `submit_evidence` equals `(False{}, state)`.
  - The hypothesis is satisfiable: no selection, or any other principal.
  - The law names a transition.
  - The rationale comment sits above it, and the module header's Laws paragraph lists it with the same limits.
- Proof (`PROOF.bend:175-181`): `%Equal.sym(Bool, selected_provider_is(state, from), False{}, wrong) : {... submit_evidence_by(_, ...) ...}` then `{==}`.
  - Per `bend guide`, `%e : P` with `e : {False == selected_provider_is(..)}` checks the goal against P with `_` set to `selected_provider_is(..)`. That is `submit_evidence`'s unfolding.
  - It then leaves P with `_` set to `False{}`, which reduces to `Rejected{state, NotSelected}`.
  - There is no `?` hole, no `unsafe` and no open claim.
- Not trivial:
  - O1 (outer match set to True), O3 (the False branch commits) and my R2 (outer match on the evidence's claim instead of `from`) all make PROOF.bend print SOME PROOFS FAIL.
  - O2 leaves the law true by design, and the suite kills it.

## Controller rulings verified

- Request gate, then stage gate: confirmed, both pinned (T2, T3).
- All three lists tied to currency: confirmed. P1 and P20 to P23 are killed.
- Challenge window re-checked by Negotiation: the projection cannot carry a challenge from a stale or abandoned selection, given monotone monitor time (S4).
  - Challenges at or before the current `selected_at` are excluded, strictly (P4 and H6 are killed).
  - With no current selection, the list is empty.
  - The session-level carry-over is separate: it is S1, not the challenge list.
- Replay lockout: confirmed fail-closed (T9 is killed). The liveness cost is as noted.
- Hand-built `Sampled` session in the two-source test: accepted.
  - `R.valid(two_selected())` and `R.valid(two_withdrawn())` are both True (probe).
  - The session (revision 3, pinned 100, challenge 21, request `two_request()`) is the shape `pin`, `challenge` and `sample` would leave. `N.approve` reads only revision, stage, liveness and owners.
  - The discriminating input is the projection: N.approve is accepted with both approvals and rejected after the withdrawal.

## What I ran

- Baseline on 00fecb4:
  - `bend Tests.bend`: 1579 lines matching `^PASS(:| )`, 0 FAIL, last line `ALL LIBRARY TESTS PASSED`, and `Rendezvous: 151 checks passed`.
  - `bend PROOF.bend`: `ALL PROOFS CHECK`. `grep -c '^law ' LAWS.bend` gives 23.
  - `bend Rendezvous.bend --check-only`: `ALL PROOFS CHECK`.
  - `--verdict` was not run.
- Diff checks:
  - `git diff master -- LAWS.bend PROOF.bend` has 0 removed lines.
  - `git diff --stat master` on Negotiation, Issuance, Transfer, Frontend, Backplane, DataOS, Ledger, Guard, HostIdentity, HostPrimitives, HostPublication, examples, hosts, contrib, writfs and utils is empty.
  - Tests.bend differs from master by 2 lines (Task 1) and is unchanged in b7900a3..00fecb4.
  - README.md, VERIFICATION.md, docs/INSTALL.md, verification/, utils/ and .github/ are unchanged.
  - The changed files are exactly the touch list plus the records.
  - The review package matches `git diff b7900a3 00fecb4` (it has extra context only).
- Mutants (scratch copies; the worktree was never mutated):

  | Id | Mutation | Result |
  |---|---|---|
  | T10 | (rerun) | SURVIVED, equivalent, accepted |
  | P14 | (rerun) | SURVIVED, equivalent, accepted |
  | P18 | (rerun) | SURVIVED, equivalent, accepted |
  | O1 | (rerun) | KILLED, PROOF FAIL |
  | O3 | (rerun) | KILLED, PROOF FAIL |
  | T6 | (rerun) | KILLED |
  | H6 | (rerun) | KILLED |
  | P8 | (rerun) | KILLED |
  | K1 | (rerun) | KILLED |
  | R1 | projection keyed on the offer, not the selection | SURVIVED (S3) |
  | R2 | outer match on the claim, not `from` | KILLED by "ER-005 field substitution ...", PROOF FAIL |

  The killing checks were the same ones the implementer's table records.
  - P14: the Outlives gate (`lifetime_within` is `Nat.is_le`) on the same `grant_for` record gives offer ≤ grant.
  - P18: `origins_approved` uses the same lookup over equal plans, the same approvals and the same `stored_covers` arguments.
  - T10: the outer match plus the leading `current_gates` NotSelected gate.
- The other mutants the brief asked about:
  - "A selection replaced between submission and projection" is pinned by P8 and the B-after-A check.
  - "Evidence stored before the provider match" is O3, which is killed and fails PROOF.
- Probes (`probe/Probe.bend`): the S1 carry-over through approve, reserve and start; the S2 `foreign()` state is valid and projected; reselected A projects no old sample; the two-source states are valid.
- Fix candidates (`fix/`): S1's helper and S2's projection conjuncts. The suite gives 151 checks passed, PROOF gives `ALL PROOFS CHECK`, and all four fix probes PASS.
- Fixtures:
  - The trial values are distinct per field: challenges 21 to 24, 26 and 29; samples 31 to 39; nonce words 1 to 6; times 103 to 118; lifetimes 113, 128, 130, 140, 150, 160, 170 and 180; quotes 38, 41 and 42.
  - The three records under sample id 31 are deliberate single-field variants.
  - The only collision I found is the one S3 exposes.
