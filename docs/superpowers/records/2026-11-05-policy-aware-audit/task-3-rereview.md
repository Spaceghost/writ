# Task 3 re-review: fix round 1 (e705619..be3dae4)

This is a scoped re-review of the findings in task-3-review.md. I read
`git diff e705619 be3dae4` and the "Fix round 1" section of
task-3-report.md. My scratch copies are in
`scratchpad/policy-aware-audit-review-t3/` (`base2/` and `own2/`).

Result: **ALL CLOSED.** I found no new defect.

| Finding | Status |
|---|---|
| I1 an early-denied event's stream is chosen by the caller's unchecked plan | CLOSED |
| I2 duplicate entries pinned only at the head of the table and for the first source (X2, X4) | CLOSED |
| I3 exact version match and the commit context influences unpinned (X7, X6) | CLOSED |
| M1 subject numbering assumption not stated | CLOSED |
| M2 residual one-bit table channel in the requester's own stream | CLOSED (stated as an observation for Task 4 and Task 6) |
| M3 channel note only in the report | CLOSED |

## I1: CLOSED

The code matches the prototype in the review: `streams_for` and the public
entry point `event_streams` (AuditEvent.bend, after `event_owners`).
- `event_streams` reads only the stored record's projected `scope` and
  authenticated `subject`. It reads no request field.
- The policy is unchanged, so `audit_outcome_never_lowers_policy` still
  holds as stated.
- `event_owners` is now listed as a helper. Its comment says it is not
  stream membership, and the entry-point list names `event_streams`.

Probe (`Probe.bend`, rerun on the fix tree):
- Mallory's Stale-denied plans that name Bob's object 11, and Bob's 11 with
  Alice's 12, are still `ScopeNotRead`.
- Their influence owners still include Bob, and Bob and Alice. That is
  expected: the policy narrows who may see the event.
- Their `event_streams` is exactly `Owned{mallory()}`.
- The ScopeRead Origin denial still joins Bob's stream.

Each `event_streams` mutant fails a named check:
- S1 (the ScopeNotRead arm returns every influence owner) and S2 (that arm
  uses subject 0) fail "AU-002 an early-denied (ScopeNotRead) event joins
  only the requester's stream, whatever objects the plan names".
- S3 (the ScopeRead arm returns the requester only) fails "AU-002 a
  ScopeRead denial joins every influence owner's stream".

The lane also has the check "an early-denied event from a subject of 2^32
joins only Top's stream".

## I2 and I3: CLOSED

I reapplied my own mutants to the fix tree with the same patches. Each one
now fails a new check, and the proofs still check under each:

| mutant | killed by |
|---|---|
| X2 | "AU-002 a duplicate label entry behind an unrelated head entry gives the maximal-restriction influence and no fixture sink" |
| X4 | "AU-002 a duplicated entry for the second source gives the maximal restriction at that source's position" |
| X6 | "AU-002 a commit event's influences are the plan's objects as data and control, the transfer context's policy objects, the binding and the requester, in that order" |
| X7 | "AU-002 a label entry for another version of the same object does not match: maximal restriction, no fixture sink" |

## Header and comments (M1 to M3): CLOSED

- The stream rule is stated beside the `ScopeNotRead{}` rule in the
  allowlist section. It is also in the "Event policy" paragraph, next to
  the `event_owners` versus `event_streams` distinction.
- The residual one-bit channel is in the header. It is marked fail-safe,
  with the reason it is kept, and it is carried to Task 4 and the Task 6
  gaps beside the timing channel.
- The subject numbering gap is stated in the header and in the
  `requester_influence` comment.

## Runs

- `bend Tests.bend` ends with `ALL LIBRARY TESTS PASSED`, exit 0. It prints
  1626 `^PASS(:| )` lines and 0 FAIL lines.
- `bend PROOF.bend` prints `ALL PROOFS CHECK`, exit 0. There are 23 laws.
- `git diff e705619 be3dae4 -- LAWS.bend PROOF.bend Tests.bend` is empty.
- The fix commit changes the touch list only: AuditEvent.bend,
  AuditTests.bend and the record directory.

## No new defect

- The non-comment code change is only `streams_for` and `event_streams`.
- The new fixtures are SYNTHETIC label tables and plans.
- The new checks take their events from `audited_admit` and
  `audited_commit`, not from hand-written events.
- The implementer committed task-3-review.md with the record directory,
  which is the plan's practice. It is not a defect.

Not run: `--verdict`, the native build and the GPU path (Task 6). This is a
JS/interpreter run only.
