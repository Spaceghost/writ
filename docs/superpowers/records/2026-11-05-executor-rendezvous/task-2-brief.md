### Task 2: Authenticated provider-scoped origin approvals (task 1.2, first half; ER-006 records, ER-002 inputs)

Implements the approval records behind "ER-006 Every origin approves the selected scope" and the origin-restriction input to "ER-002 Eligibility precedes ranking".

Add the public entry points:
- `submit_approval(state, expected_revision, from, approval, snapshot)`. Its gates: the revision is current; the version is 1; `claim_matches` (`Unauthenticated`); the origin placement exists (`WrongDomain`); `from` is the read authority for that placement's domain (`NotAuthority`); the approval plan equals the request plan (`ScopeMismatch`); `now < valid_until` (`Expired`); the serial is unseen (`Replay`).
- `withdraw_approval(state, expected_revision, from, approval_id)`. Only the recorded issuer may withdraw, and it must still be the directory authority. Withdrawal sets a never-cleared flag and keeps the serial.

Add the helpers `origin_approved(approvals, origin, provider, profile, plan, now)` and `origins_approved(lookup, ...)`, which walks `T.required_origins` (Missing or empty means False).

Tests (`approvals` section):
- Object 10's read authority approves provider A at profile 1: accepted.
- Unauthenticated approver: the approval claims object 10's authority while `from` is the write authority: `Unauthenticated`.
- The write authority approves object 10 under its own identity: `NotAuthority`.
- An unplaced inherited origin: `WrongDomain`.
- An approval for a plan that differs in invocation: `ScopeMismatch`.
- Expired at submission: `Expired`. A replayed serial: `Replay`.
- `origin_approved` is false:
  - for provider B and for profile 2 when only A at profile 1 was approved;
  - after withdrawal;
  - at `now` = `valid_until`.
- With a two-source plan, approval of object 10 only leaves `origins_approved` false. An inherited origin listed by `T.required_origins` but unapproved also leaves it false.
- Withdrawal by a non-issuer: `Unauthenticated`. Withdrawal by a former authority removed from the directory: `NotAuthority`. A stale revision: `StaleRevision`.

Estimate about 15 checks. Laws: none. No box checked (1.2 completes in Task 3). Mutation table.

Acceptance: green suite and proofs. Every approval check reads the issuer directory and placements from the supplied snapshot, and nothing reads an approval's `issuer` without comparing it to `from`.

