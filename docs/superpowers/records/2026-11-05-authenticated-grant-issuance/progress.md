# SDD ledger — plan: docs/superpowers/plans/2026-11-05-authenticated-grant-issuance.md
Branch: lane/authenticated-grant-issuance

Conflict scan: Issuance.bend/IssuanceTests.bend new; Transfer/Frontend/DataOS/Backplane untouched; Tests.bend gains one registration block; proofs are additions only. Cross-lane ruling: no count pins. Plan rulings accepted (single-use approvals; derived grant keeps subject and scope) and put to Spaceghost on q18 as a veto.
Task 1: dispatched implementer
Task 1: implementer DONE_WITH_CONCERNS (8bceb59): 806 checks (782+24), proofs unchanged. Rulings: the three stricter checks stand (they narrow, never widen); Stored.revoked as a Bool is acceptable because it can only remove authority — reviewer to confirm it is never read as a grant of authority; empty records for later tasks acceptable. Reviewer dispatched.
Task 1: review spec APPROVED, security NEEDS_FIXES (write-side denial branches not pinned by tests; ambiguous-placement test passes a first-match resolver). Fix round 1 dispatched: a failing test per removed denial branch.
Task 1: fix round 1 done (23270ac): 821 checks; 29 of 31 denial-branch removals now fail a test (the two outer revision matches are duplicated by the inner gate, kept for the Task 3 law); replay identity is the authenticated principal. Scoped re-review dispatched.
Task 1: complete (re-review ALL CLOSED; 821 checks).
Task 2: dispatched implementer
Task 2: implementer DONE_WITH_CONCERNS (b4629ca): 872 checks (+51), 55 of 60 mutants caught, the 5 survivors equivalent. Rulings: the stricter gates stand (all narrow); the grant scope copied from the request only after equality with every cited approval is acceptable if the reviewer confirms the equality gates are complete; no explicit id>0 gate acceptable given no transition issues id 0 (reviewer to confirm). Reviewer dispatched.
Task 2: review spec APPROVED, security NEEDS_FIXES (three mutants survive: write-domain comparison in scope_equal, consuming uncited approvals, dropping earlier grants). Fix round 1 dispatched.
Task 2: fix round 1 verified by the controller (tests only, three mutants now killed, 875 checks); complete.
Task 3: dispatched implementer
Task 3: implementer DONE_WITH_CONCERNS (4cf2f6a): 928 checks (+53), 9 laws (3 added, additions only), 59 of 63 mutants killed, 4 equivalent. Rulings: current walking the parent chain ahead of Task 4 is accepted (Task 4 builds derive on it and must require a child to cite no approvals); stricter per-use rechecks stand; the definition move is acceptable if the reviewer confirms conditions are unchanged. Reviewer dispatched.
Task 3: review spec APPROVED, security NEEDS_FIXES (a later revoke could un-revoke earlier ones untested; issuance_denied_preserves_state is trivially true). Ruling: a trivially true law is a proof hole, so it is replaced by the reviewer's two real proofs (11 laws), never kept with reworded prose. Fix round 1 dispatched.
