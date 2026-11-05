# Task 1 re-review: fix round 1 (6bc0208..7678088)

Scoped re-review of the findings in task-1-review.md. Read:
`git diff 6bc0208 7678088`, the "fix round 1" section of task-1-report.md,
and Transfer.bend `admit`, `header`, `Sources.check`, `SourcePolicy.check`,
`OriginRule.check`, `PaymentRule.check`, `copy_check`, `destination_check`,
`WriteGrant.matches` and `scoped`.

Result: **ALL CLOSED.** No new defect.

| Finding | Status |
|---|---|
| I1 caller-written scope in early-denied admission events | CLOSED |
| I2 artifact is a content digest (comment and Task 3 obligation) | CLOSED |
| M1 distinct sentinels | CLOSED |
| M2 E1/E2/E5 obligation for Task 2 | CLOSED (recorded in the report for the Task 2 brief) |
| M3 unused `Guard` import | CLOSED |
| Nits (accessor marking, Diagnostic accessors) | CLOSED |

## I1: CLOSED

Structure:
- `EventRecord` now holds `scope: Scope`, where `ScopeNotRead{}` has no
  fields.
- `admission_scope` reads the plan only on `Admitted` or on a denial for which
  `denial_reads_scope` is True. It decides from the library's returned reason
  alone and re-runs no check.
- `scope_gate` defaults to `ScopeNotRead{}`, so it fails closed.

Boundary, derived from `T.admit`'s actual order (Transfer.bend:658-674 and
:742-749):
- `admit` is `Check.and(header, Check.and(Sources.check, Check.and(copy_check,
  destination_check)))`, and `Check.and` returns the first `Invalid`.
- `header` checks, in order: Stale, Source, Destination, Operation, Schema,
  Destination, and finally Write via `Writes.permit` and `scoped`. `scoped`
  requires the grant's invocation, exact ordered inputs, destination, code,
  kind and stamp (equal to live, which the Stale check equated with the
  plan's stamp) to match the plan.
- `Read` (:644), `Origin` (:620, :641) and `Payment` (:611) occur only inside
  `Sources.check` and its callees, which run only after `header` is `Valid`.
  At that point every scope field equals a monitor-installed write grant's
  scope.
- The reasons that can also occur late (Source, Stale, Schema, Destination)
  are classified as early. That withholds scope, which is conservative.
  `InvalidPolicy` occurs only late but is withheld by the controller's ruling,
  which also fails closed.
- So the True set {Read, Origin, Payment} is exactly the set of reasons that
  can only follow the write-grant match. It is derived, not guessed. The
  header's description of the order matches the code.

My own probe (scratch `Probe.bend`, outside the tree):
- I used a plan whose stamp, invocation, two sources, destination and code are
  all hidden words (3000000001 to 3000000018), and a second variant with the
  live stamp so that it gets past Stale.
- I ran six contexts: base, live set to the hidden stamp, base with the
  live-stamp plan, no write grants, no read grants and no sources.
- All six pass. Each event is early-denied, has `ScopeNotRead`, and contains
  no hidden word.
- As a sanity check, I applied the mutation "`scope_gate` False arm reads the
  plan". The probe then FAILs on its first case, so it is not vacuous.

The lane's own checks cover each early reason with a stuffed plan (Stale,
Source, Destination, Operation, Schema, Write). They also check that an
early-denied event is the same whatever the plan contains, and that a Read
denial records the vouched scope. The report's mutants S1 to S15 are killed.

Observation, not a defect: `denial_reads_scope` encodes Transfer's current
check order. If a future change to Transfer.bend moved a Read, Origin or
Payment check ahead of the write-grant match, the classification would go
stale silently. The header documents the dependency. A later Transfer change
should be reviewed against it.

## Header (finding 2): CLOSED

AuditEvent.bend:34-86 lists each field, what it is, and the check under which
it entered the event:
- `version`, `kind`, `phase`, `event_id` and `subject`;
- `scope`, with the admission order and the commit session-plan rule;
- `artifact`, flagged as a digest derived from the output's content;
- `outcome`, a closed constructor whose `Rejected` arm carries no reason.

It states that confidentiality is Task 3's job and names both obligations:
1. The requester's influence on every admission event, or fail closed.
2. The binding's source and destination labels on every commit event, never
   released below the output label.

The `artifact_of_commit` comment repeats point 2.

## Minor findings (3): CLOSED

- Sentinels now come in distinct ranges, and I checked the decimal values:
  payload 0xA0D17001-02, error text 03-04, credential 05-06, Diagnostic token
  0xA0D17101-08, caller and Ref token 0xA0D17201-08, plan words
  0xA0D17301-08. The absence check uses their union.
- The `Guard` import is removed (`grep -c Guard` gives 0).
- The `Diagnostic.*` accessors are removed (`grep -c 'Diagnostic[.]'` gives 0).
- The accessor block is marked as public entry points.

## Runs (4)

- `bend Tests.bend`: `ALL LIBRARY TESTS PASSED`, exit 0, 1488 `^PASS(:| )`
  lines, 0 FAIL lines.
- `bend AuditTests.bend` gives `Audit: 60 checks passed`.
- `bend PROOF.bend`: `ALL PROOFS CHECK`, exit 0. There are 21 laws.
  LAWS.bend, PROOF.bend and Tests.bend are unchanged since 6bc0208, and
  `git diff d7967c8 7678088` removes 0 lines from them.
- `bend AuditEvent.bend --check-only` exits 0.
- Grep counts: `T.admit(` gives 1, `commit_from_capability(` gives 1.
- Touched paths are the touch list plus the record directory. No count pin
  changed.
- The equivalent mutants still survive on 7678088: E1, E2 and E5 each give
  `Audit: 60 checks passed` and `ALL PROOFS CHECK`. The argument still holds:
  `scope` now sits inside a compared field, and version, kind and phase are
  still functions of the constant and of the outcome.

Not run: `--verdict`, the native build and the GPU path (Task 6). This is a
JS/interpreter run only.
