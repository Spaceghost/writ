# SDD ledger — plan: docs/superpowers/plans/2026-11-05-portable-host-contract.md
Branch: lane/portable-host-contract

Conflict scan: HostWire/HostIdentity/HostPrimitives/HostConformance* new; Tasks 3 and 4 both edit HostPrimitives.bend (sequential, same lane); Task 6 records. Cross-lane ruling: no count pins. Plan ruling accepted: delegation never changes the effective subject (PH-005); put to Spaceghost on q18 as a veto.
Task 1: dispatched implementer
Task 1: implementer DONE_WITH_CONCERNS (c277f80): 841 checks (782+59), proofs unchanged, strict 44. Rulings: ClaimedSubject{untrusted} wrapper accepted; extra check-order tests accepted; byte-step order documented in the header is the plan ruling; BadLength ambiguity acceptable as a source-reviewed row; file size acceptable. Reviewer dispatched.
Task 1: review spec APPROVED, quality NEEDS_FIXES (two PH-004 checks pass on Malformed; fixture reuse; two short inputs untested; op code as rights; comment). Fix round 1 dispatched.
Task 1: fix round 1 verified by the controller (845 checks; PH-004 checks now require two successful decodes that differ; HostWire.bend change is comment-only); complete.
Task 2: dispatched implementer
Correction: the HostWire.bend fix-round change is not comment-only; the 10-word cap is now derived as header_words() + width_use() (the duplicate-constant nit), same value; accepted.
Task 2: implementer DONE_WITH_CONCERNS (5374ade): 921 checks (+76), one new law, 55 mutants all caught. Rulings: slots are never reused within an incarnation, so a retired reference denies Retired (no ABA) and StaleGeneration is tested on a live slot — accepted, mint does not reuse slots; the stricter valid/bind_session/mint rules stand; inherited/transferred origins denied at the origin step after the holder step is accepted; source-reviewed Ambiguous branches acceptable. Reviewer dispatched.
Task 2: review spec APPROVED, security NEEDS_FIXES. Ruling: a reference's holder is the session the monitor bound it to (token and subject together), not the subject alone; a different session of the same subject is NotHolder; delegation targets a session, the child's holder is that session, the subject never changes (PH-005). Reason: otherwise every session of a subject holds ambient authority over the others' references, the transfer PH-004 forbids. Costs a stricter model than the brief's wording if wrong. Fix round 1 dispatched with the four minor items.
Task 2: fix round 1 done (d0b4c4d): holder is the session; 937 checks (+16); 69 mutants all caught. Scoped re-review dispatched.
Task 2: complete (re-review ALL CLOSED; 937 checks).
Task 3: dispatched implementer
