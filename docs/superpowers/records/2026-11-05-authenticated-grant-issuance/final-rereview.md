# Final re-review: authenticated-grant-issuance, final fix round

Assessment: **Ready to merge**.

Scope: `git diff 5fe21c8 7568225` and the "final fix round" section of task-7-report.md, checked against the findings in final-review.md. The controller ruled Option A for I-1.

## Findings

| Finding | Status | Evidence |
| --- | --- | --- |
| I-1 any caller could call `register` and burn an approval pair | CLOSED | See "I-1" below. |
| M-1 rights do not reach `Transfer.admit` | CLOSED | GRANT-ISSUANCE.md has a "Rights reach Frontend only" paragraph. It says a bare `T.admit` path admits a current grant's plan whatever its rights, including rights 0. It names the hazard (a grant with narrower rights still admits the whole plan there) and the host obligation (route rights-limited use through Frontend). |
| M-2 monotone clock | CLOSED | Precondition 4 and "The live stamp and `now`" now require a trusted, monotone clock (`now` never decreases). The GI-007 reviewed-only gap gives the hazard with its example: a grant expired at 150 is current again at 149. |
| M-3 no grant-level revocation | CLOSED (listed as open) | GRANT-ISSUANCE.md and the traceability "Model details" both say: "Open in the model: there is no grant-level revocation ...". |
| M-4 stale "projection (task 1.5)" comment | CLOSED | `register` doc now reads "the projections `reads`, `writes` and `registry` admit only the authenticated principal's current grants". |
| M-5 OpenSpec count 37 to 44 | CLOSED | verification/grant-issuance.txt: "The committed openspec-validation.txt at the merge base was stale (37 items); 44 is the full count of this tree ...", followed by the seven items. |

### I-1

- **Code.** `register(state, expected_revision, from, request, now, token)` now takes `from`. The gate `Gate{speaks_for_subject(from, scope), SubjectMismatch{}, ...}` is third in `register_gates`, after StaleRevision and UnknownVersion and before any approval is read. `register_current`, `register_checked` and `register_checks` all take `from`. `speaks_for_subject` moved above its first use, with its body unchanged.
- **Scenario (g) rerun on the real entry points** (scratch copy of 7568225; my own checks, all PASS):
  - Principal 8 registers subject 7's pair with rights 0 until 101. It is denied SubjectMismatch, the returned state equals the input (`IF.denied`), and approvals 1 and 2 both still have `consumed_by` 0.
  - The write authority registering for subject 7 is denied SubjectMismatch.
  - Subject 7 then registers the same pair on that returned state, and `T.admit` admits `TF.plan()` on the rebuilt projections.
- **Caller-gate mutants, both killed** (run with `bend IssuanceTests.bend`):
  - Gate replaced by `True{}`: the first FAIL is "GI-004 principal 8, neither an authority nor subject 7, registering subject 7's pair with rights 0 until 101 denied SubjectMismatch, both approvals unconsumed".
  - Gate weakened to accept any caller except principal 8: the first FAIL is "GI-004 the source authority or the write authority registering subject 7's request denied SubjectMismatch".
  - `bend PROOF.bend` still checks under both mutants. That is expected, because the laws depend only on the outer revision match.

## Laws

- `issuance_stale_revision_rejects` and `issuance_stale_registration_keeps_state` now quantify `for from: Issuance.Principal` and pass `from` to `register`.
- They are still real statements:
  - Each holds for every `from`, the subject included, so the new caller gate cannot be what denies.
  - Each still depends on `register`'s outer `revision_current` match and on its Rejected branch carrying the input state.
- The proof terms change only by threading `from` through to `register_current(_, ..., 1n+revision, from, request, now, token)`. The rewrite is the same `%Equal.sym(... nat_eq_successor_false(revision))` followed by `{==}`.
- The terms contain no holes. The `_` is the rewrite-motive position.

## Checks run

- `bend Tests.bend`:
  - result: 1014 PASS (`^PASS[: ]`), 0 FAIL, last line ALL LIBRARY TESTS PASSED;
  - the output is byte-identical to verification/tests-js.txt, which in turn equals tests-native.txt.
- `bend PROOF.bend`: ALL PROOFS CHECK, 12 laws.
  - No `--verdict` was run and there is no Lean on PATH; nothing on the branch claims a kernel verdict.
- OpenSpec 1.16.0 `validate --all --strict --no-interactive`: Totals: 44 passed, 0 failed.
- `git diff master..7568225 -- LAWS.bend PROOF.bend`: 0 removed lines, so additions only against master.
- `git diff --stat master..7568225` over DataOS, Transfer, Frontend, Backplane, Negotiation and Guard is empty: the use-time modules and the facade are unchanged.

## New defects

None of security relevance.

Nit (optional): two comment lines added to Issuance.bend run past 100 columns, against the Task 3 M-3 line-length standard:
- the `register_gates` denial-order comment ("... then the cited approvals' existence, single use and revocation");
- the `register` doc ("version 1, `from` is the request scope's subject, every cited approval is present, ...").

Reflowing them does not block the merge.

## At merge (controller)

- Update the tasks.md opening sentence.
- Re-pin the counts to 1014 (782 + 230 + 2), or to whatever the merged tree prints.
- Regenerate `verification/source-sha256.txt` on master.
