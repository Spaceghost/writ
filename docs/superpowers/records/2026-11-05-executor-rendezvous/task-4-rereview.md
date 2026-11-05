# Task 4 re-review: fix round 1 (f460ad5 on 00fecb4)

Reviewer: task reviewer (security and proofs). This is a scoped re-review of findings S1 to S6 in `task-4-review.md`. Read-only apart from this file.

Scratch, in the session scratchpad `executor-rendezvous-review-t4/`:
- `rr/Probe.bend`: the original probes, rerun on f460ad5;
- `rmut2.py`: the mutant runner;
- `n1.out` to `n3.out`: the mutant results.

## Verdict: ALL CLOSED

| Finding | Status | Evidence |
|---|---|---|
| S1 session carry-over | CLOSED (Task 4 scope); the dispatch gate is carried to Task 5 | See S1 below. |
| S2 foreign evidence | CLOSED | See S2 below. |
| S3 offer-keyed projection | CLOSED | My RR1 (projection keyed on the offer and claim, with the selection id removed) is killed by the new same-offer reselection check. The probe "reselected A projects no old sample" also passes. |
| S4 time and id assumptions | CLOSED | Both are stated in the header "Projection" paragraph and in the `negotiation_context` doc. `session_follows_selection`'s doc repeats the no-reuse assumption. |
| S5 check name | CLOSED | The name at `RendezvousTests.bend` `trial_reuse` now reads "B naming A's challenge 21 and sample 31 on its session challenged with 26 ...". |
| S6 approval-order wording | CLOSED | The fixture comment and report lines 69 and 156 now read "submitted first, so A's heads the stored list". |

### S1: what was rerun

- The original probe: A's session is sampled under selection 3, then `abandon`, then B is selected and stores its evidence.
  - `N.approve`, `N.reserve` and `N.start` on B's projection are still accepted.
  - This is expected and now documented. The projection cannot see the session, and Negotiation is unchanged. The new check pins this.
- `session_follows_selection` is False for:
  - that stale session, once it reaches Running (probe "RR stale Running session not bound to selection 4");
  - its approved successor;
  - before evidence;
  - with no selection;
  - a quote-41 session.
- It is True for B's session, and for A's session under selection 3.
- Header, `negotiation_context` doc and report are corrected.
- Mutants:
  - The implementer's B1 to B5.
  - My RR2 (`session_follows_selection` set to True) is KILLED.
  - My RR3 (`challenge_evidenced` matches any selection id) is KILLED.

### S2: what was rerun

`evidence_names` now requires the selected offer's id and provider claim. `valid` rejects mismatching evidence under the current selection id (`evidence_binds`).

- My `foreign()` state (B's offer and claim under id 3) is now invalid and projects no sample.
- The new check covers `foreign_offer()` and `foreign_provider()`, each differing in one field.
- Mutants:
  - RR4 (`valid` passes NoSelection to `evidence_valid`) is KILLED.
  - RR5 (drop both new conjuncts) is KILLED.
  - RR6 (drop the provider conjunct) is KILLED.

## Carried to Task 5 (item 5)

The report's "Carried to Task 5" is clear enough to brief: the gate, the predicate, the scenario and the expected denial are all named.

Two points the brief should settle:
1. Pick one reason. I recommend `WrongTrial`, so it is distinct from the existing `MissingEvidence` gate.
2. Place the gate after the `MissingEvidence` gate. Then a selection with no evidence still reports `MissingEvidence`, and evidence for another trial reports `WrongTrial`.

## Runs (item 6)

- `bend Tests.bend`: 1582 PASS, 0 FAIL, `ALL LIBRARY TESTS PASSED`, and `Rendezvous: 154 checks passed`.
- `bend PROOF.bend`: `ALL PROOFS CHECK`. LAWS.bend has 23 laws.
- `git diff --stat 00fecb4 f460ad5 -- LAWS.bend PROOF.bend Tests.bend Negotiation.bend` is empty.
- Only `Rendezvous.bend`, `RendezvousTests.bend` and the records changed. `task-4-review.md` was committed as part of the records.

## New defects

- Nit: `RendezvousTests.bend:1191`, the fixture comment rewrapped in this round, is 103 columns, the only comment line over 100 in either file. Rewrap it when next touched. It does not block.
