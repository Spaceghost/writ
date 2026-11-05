# SDD ledger — plan: docs/superpowers/plans/2026-11-05-policy-aware-audit.md
Branch: lane/policy-aware-audit

Conflict scan: six tasks; AuditEvent.bend (Tasks 1-3), AuditQuery.bend (Task 4), AuditExport.bend (Task 5) are separate modules; Task 6 records. Section 2 waits for durable publication. Rulings: monitor-installed grants recorded as a gap; metrics are visible-only counts. Cross-lane: no count pins; one Tests.bend registration block.
Task 1: dispatched implementer
Task 1: implementer DONE_WITH_CONCERNS (6bc0208): 1477 checks (+49), 21 laws (+4), 65 of 68 mutants killed, 3 equivalent. Rulings: EventRecord/EventKind renames stand (Base has Event; Kind is a keyword); the restated commit law (the event equals the event built from the same facade result for any token and no diagnostic) is accepted if the reviewer confirms it is a real statement and the brief's form was false; the extra LAWS imports are acceptable as additions. Reviewer dispatched.
Task 1: review spec APPROVED, security NEEDS_FIXES (caller-written scope fields reach denied-admission events on early denials: a channel; the artifact field is a digest of sealed content; header overclaim). Ruling: an early-denial event carries a "scope not read" marker and no scope fields, structurally; the requester label on admission events and the binding labels on commit events go to Task 3. Fix round 1 dispatched.
