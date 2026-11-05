# Task 5 re-review: fix round 1 (`4ac8041..d28af20`)

Reviewer: task reviewer, scoped re-review (read-only except this file). Range: `git diff 4ac8041 d28af20` and the "Fix round 1" section of task-5-report.md.

**Result: ALL CLOSED. No new defect found.**

## Findings

| Finding | Status |
|---|---|
| I-1 the transfer projections carry no subject | CLOSED (structural fix) |
| M-1 the projection-`now` consequence | CLOSED |
| M-2 the registry layer's denial not isolated | CLOSED |
| M-3 derived child: reads and writes unpinned | CLOSED |
| M-4 policy inputs and same-record placement domains | CLOSED |
| Nits (`grant_registered` name, the long document line) | CLOSED |

### I-1

**The fix.** `reads`/`writes`/`registry(state, from, now)` gate every record on `usable_by(state, grant, from, now)`, which is `speaks_for_subject(from, Grant.scope(grant)) && current(state, grant, now)`.
- `speaks_for_subject` is exact `Nat.is_eq` (`Issuance.bend:1682-1683`).
- So a grant is projected only for its own subject, and the currency filter is unchanged.

**My probe, rerun** on a fresh `git archive d28af20`. Harnesses: `scratchpad/t5rev/harness/mut2.py`, `mut3.py` and `mut4.py`; output in `mut2.out`, `mut3.out` and `mut4.out`.
- *A different principal gets empty lists.*
  - "GI-008 subject-scoped projections: subject 7's current grant 3 projects nothing for principal 8, principal 6 or principal 0" passes.
  - The `usable_by` mutant with the subject conjunct dropped is KILLED by it.
  - The `reads_of`, `writes_of` and `registry_of` mutants that use `current` alone are each KILLED by it.
- *A bare `Transfer.admit` with another principal's projection admits nothing.*
  - "... on a path that runs T.admit without Frontend's caller check, principal 8 gets no admission from subject 7's grant" runs the unchanged `T.admit` on `TF.context()`, with principal 8's projected lists.
  - It asserts a `Write` denial.
  - With the previous check removed (Test.check stops at the first failure), mutants that drop the subject from all three gates, from reads+writes, or from writes alone are each KILLED by this bare-admit check.
  - The registry-only and reads-only mutants are KILLED by the two-subject exact-equality check.
- *Each principal sees only its own grant.* "... with grants for subjects 7 and 8 on one plan, each principal's projections hold exactly its own grant" pins both principals' three lists exactly.
- *The registry layer alone denies another subject.* "the registry layer alone denies another subject: subject 6 presenting grant 3's token on subject 7's descriptor gets no plan" is also present.

**Where the principal comes from at the tested call sites.**
- In `FacadeTests.bend` it is the literal fixture `I.Principal{7n}`. That is the same identity as the Ref's caller `F.Caller{7n, IF.token()}`, and the comment marks the issuer state SYNTHETIC.
- In `IssuanceTests.bend` it is `subject_principal()`, `principal8()` or a literal.
- At no call site is it read out of a request, approval, `Ref` or other caller-supplied record. So no tested path turns a caller claim into the projection principal.
- On a real host it is a trusted input. The header (`Issuance.bend:39-50`) and the document both say it is the transport-verified identity, the same one presented as `F.Caller.subject`.

### M-1

The live stamp and `now` section now says:
- expiry and epoch are re-checked at use (`Transfer.scoped`, `Frontend.capability_current`), so an earlier projection `now` cannot by itself admit an expired grant;
- a later `now` only drops grants;
- revocation, directory and placement changes are enforced only by rebuilding.

The per-use section names those three as the danger of a cached list.

### M-2

"GI-008 partial staleness: ..." pairs:
- a rebuilt (empty) registry with stale transfer lists;
- a stale registry with rebuilt lists.

Each pairing gives `None`. Verified in isolation (`mut4.py`): with only this check left in `integration()`, it passes unmutated. Against the `registry_of` gate with the currency conjunct removed, it FAILS. So the registry layer's denial is now pinned at use, not only structurally.

### M-3

The derived check now pins `reads` and `writes` exactly. The child's entries carry `TF.scope_for(TF.plan(), write6(), 120n)` and come ahead of grant 3's entries.

### M-4

The per-use section says:
- the projections replace only `T.Context`'s grant fields;
- the live stamp, `now`, the policies, the operation and the payments stay host-supplied Transfer inputs;
- the placements and the policy domains must come from the same monitor record, and a divergence denies.

### Nits

- `grant_capabilities` replaces `grant_registered`. `git grep` at d28af20 finds no remaining `grant_registered` and no old two-argument `reads(state, now)`, `writes(state, now)` or `registry(state, now)` outside the record directories.
- The long line is rewrapped, and no `Issuance.bend` comment line exceeds 100 columns.

## (3) The "The subject of a use" section

The section covers:
- **The hazard.** Transfer's grants carry no subject. Only `capability_current`, reached through `F.checked_plan` and `commit_from_capability`, compares a use with a caller. It names `DataOS.admit`, `Backplane.commit` and Negotiation as bare `T.admit` paths.
- **The rule.** The projections are subject-scoped. The principal must be the caller of this use and the same identity as `F.Caller.subject`.
- **The failure mode.** Lists built for, or reused with, the wrong principal hand that subject's grants to someone else. Frontend still refuses on its path, but nothing does on a bare path.
- **The checks.** It cites them by name.

No sentence claims a host guarantee.

## (4) Verification (Bend 2.0.39, fresh `git archive d28af20`)

- **`bend Tests.bend`:** rc 0, 985 `PASS` lines, 0 FAIL. The summary lines are `Transfer: 53`, `Frontend: 70`, `Facade: 12` and `Issuance: 201 checks passed`. Last lines:
  ```
  Property: 324 checks passed; 320 graph cases, each checked against CPU and Bend parallel producers
  ALL LIBRARY TESTS PASSED
  ```
- **`bend PROOF.bend`:** rc 0, 12 laws, unchanged. Last lines:
  ```
  ALL PROOFS CHECK
  Use --verdict for mathematical validity.
  ```
- **Use-time modules unchanged:** `git diff --stat c5afd1e d28af20 -- Transfer.bend Frontend.bend DataOS.bend Tests.bend LAWS.bend PROOF.bend Backplane.bend Negotiation.bend` is empty.
- **Limits:** `--verdict` was not run (no kernel toolchain). This was a CPU run only, and I make no GPU claim.
