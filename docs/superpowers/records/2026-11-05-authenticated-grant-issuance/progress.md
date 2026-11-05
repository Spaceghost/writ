# SDD ledger — plan: docs/superpowers/plans/2026-11-05-authenticated-grant-issuance.md
Branch: lane/authenticated-grant-issuance

Conflict scan: Issuance.bend/IssuanceTests.bend new; Transfer/Frontend/DataOS/Backplane untouched; Tests.bend gains one registration block; proofs are additions only. Cross-lane ruling: no count pins. Plan rulings accepted (single-use approvals; derived grant keeps subject and scope) and put to Spaceghost on q18 as a veto.
Task 1: dispatched implementer
Task 1: implementer DONE_WITH_CONCERNS (8bceb59): 806 checks (782+24), proofs unchanged. Rulings: the three stricter checks stand (they narrow, never widen); Stored.revoked as a Bool is acceptable because it can only remove authority — reviewer to confirm it is never read as a grant of authority; empty records for later tasks acceptable. Reviewer dispatched.
Task 1: review spec APPROVED, security NEEDS_FIXES (write-side denial branches not pinned by tests; ambiguous-placement test passes a first-match resolver). Fix round 1 dispatched: a failing test per removed denial branch.
