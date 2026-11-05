# Task 5 re-review: fix round 2 (3e32c78..1a00268)

Scope: the findings of `task-5-review.md` only. I read `git diff 3e32c78
1a00268` and the "Fix round 2" section of `task-5-report.md`, and reran the
mutants, the suites, and the vector capture on 1a00268 myself.

## Findings

| # | Finding | Status | Evidence |
| --- | --- | --- | --- |
| 1 (Important) | Issue-side plan binding pinned only for a changed destination | CLOSED | PH-005-10 (HostConformanceTests.bend `issue_input`/`ph005_10_*`) issues `V.input_plan()` on handle 2, checked with `PT.denied` against the pre-issue state. My mutant M4 (`handle_carries` compares only `T.Plan.destination`) now fails `PH-005-10 a root issued for a plan with a changed input object ...`, and every one of the 10 earlier lines is unchanged. |
| 2 (Important) | PH-003-1 did not separate session holding from caller identity | CLOSED | PH-003-3 has the proxy session (same subject and token as the client) present the client's root, asserted with `identity_denied(..., I.NotHolder{})` on both `use` and `admit_worker`. My mutant M1 (the holder test *also* accepts caller equality, which is the report's M1b) first fails at `PH-003-3 ...`, with all 19 earlier lines unchanged. The variant that *replaces* the holder test with caller equality (M1r) first fails at `PH-009-1`, as the report says. My harness stops at the first FAIL, so I did not confirm the report's claim that M1r's PH-003-3 line also changes. M1r is killed either way. |
| 3 (Minor) | Missing-handle case had no vector | CLOSED | PH-005-11 issues on `V.unopened_handle()` (3), which the descriptor never opened. Mutant M7 (`None` accepted) now fails `PH-005-11 ...`. |
| 4 (Minor) | `issue`'s Frontend state is trusted but the comment said it was enforced | CLOSED | The `issue` comment (HostPrimitives.bend:1157-1172) now says nothing enforces it: the check trusts the monitor's Frontend state (a host obligation) and is defense in depth, and publication re-binds independently (step 4, then DataOS). The traceability PH-005 row says the same. The HostPrimitives.bend diff has no non-comment line (I checked by filtering the diff). |
| 5 (Minor) | Stale "no hand-built state" header | CLOSED | The header now names PH-005-8 as the HAND-BUILT exception. |
| 6 (Minor) | PH-005-8's `valid` claim was not asserted | CLOSED | `bypass_reached` now also asserts `P.valid(bypassed_root(a))`. |
| 7 (Minor, optional) | Session ids are identical across adapters | Declined; reason sound | Session ids are monitor-assigned and never appear in a vector line. The adapters already differ in host, incarnation, slot offset, report, and inventory. Varying session ids would test fixture plumbing, not a decision. I accept this. The comparison's documented limits stand. |

## New defects

None found. The fix round adds three vectors (PH-005-10, PH-005-11, PH-003-3),
their expected lines, list entries, and traceability rows. PH-012-1 now reads
`compare accepted vectors=32`, and the summary reads
`HostConformance: 39 checks passed, 33 vectors emitted`. One note: commit
1a00268 also committed `task-5-review.md`. That was the controller's
choice, not a defect.

## What I ran (on 1a00268)

- `bend Tests.bend` (JS): exit 0, 1182 PASS, no duplicates, none of the
  previous run's PASS lines missing. Last lines:
  `Property: 324 checks passed; 320 graph cases, each checked against CPU and Bend parallel producers`
  and `ALL LIBRARY TESTS PASSED`.
- Fresh native build (`bend Tests.bend -o <scratch>/tests-native2`, exit 0),
  run with `+RTS --threads 4 --gpu off`: exit 0, 1182 PASS in the same order
  as JS, same last lines. This was CPU execution, not a GPU test.
- `VECTOR PH-` lines: SHA-256
  `fb85d405c08e9ad46727ffe0d69bf9f7d5cc241281226d8c1740a4a9f094d30d` from
  both the JS and the native run. Both are `cmp`-identical to
  `verification/portable-host-vectors.txt`, which has the same hash on disk.
- `bend PROOF.bend`: `ALL PROOFS CHECK` / `Use --verdict for mathematical validity.`
- Mutants M1, M1r, M4, and M7 were run on a scratch copy against
  HostConformanceTests.bend, with the results above.
