# Task 5 re-review: fix round 1

Reviewer: task reviewer (information flow and proofs). The scope is the fix
commit 607fd05 on top of 45d5e99. I read `git diff 45d5e99 607fd05` and the
"Fix round 1" section of task-5-report.md.

## Result: ALL CLOSED

| finding | status | evidence |
|---|---|---|
| I1: owner-stream filter not pinned | CLOSED | new check and new law; my filter-removal mutants are killed (below) |
| M1: re-grant remedy wrong | CLOSED | header :54-57 corrected; new check passes |
| M2: who receives `Sent` | CLOSED | host-obligation sentence at :130-134 |
| M3: `export_view` parameter | CLOSED | header :85 now reads `export_view(state, owner, sink)` |
| M4: forward reference to docs/AUDIT.md | CLOSED | header :112 now says "Task 6's docs/AUDIT.md" |
| A1, A2 (advisory) | no action required | the implementer's rationale for keeping `effects == []` is acceptable |

## I1 in detail

### The check

AuditTests.bend `content_gated`, check "AU-007 an event releasable to the
export sink but outside the grant owner's stream (Mallory's early denial
through sink 4) changes no Events, Metric or Alert word".

The check is not vacuous. It asserts:
- that `h_mallory` is releasable to `sink_all()`;
- that `h_mallory` is not in Alice's stream;
- exact `Sent` results on all three channels;
- equality with the log without `h_mallory`.

### The law `audit_export_outside_stream_unobservable`

Statement (LAWS.bend:498-507): for every state, owner, sink, `before`,
`after` and `e` with `in_stream(owner, e) == False`, inserting `e` at any
position leaves `export_log_view` unchanged.

This is an observable formulation: the view, and therefore every channel's
input, is insensitive to an event outside the owner's stream. It is not a
restatement of the filter. It quantifies over arbitrary logs and positions,
and the releasability of `e` is unconstrained.

The proof (PROOF.bend:225-237) is hole-free:
- The helper `audit_outside_stream_invisible` rewrites `visible`'s first
  conjunct using the hypothesis, then finishes with `{==}`.
- The law is then the existing `audit_invisible_event_unobservable` at
  `query(state)`.
- There is no `unsafe`, `?` or admitted term.

The stated limit is accurate: the law does not claim that `transmit` reads
the log only through `export_log_view`. The structure supports that claim:
- `export_view` calls `export_log_view` on `event_log`;
- `content_at` uses `export_view`;
- `event_log` appears in no other place in the module.

My bypass mutant R4b is caught by the check.

### Mutant reruns

My mutant script (mut.py) was rerun against the fix tree.

| mutant | change | result |
|---|---|---|
| R4a | `export_log_view` keeps every releasable event, with no stream test | killed by the new check; also fails at `Laws.audit_export_outside_stream_unobservable` |
| R4b | `export_view` bypasses the helper with a releasable-only filter | killed by the new check; proofs check, as expected, since the law is over the helper |

## M1 in detail

The header at AuditExport.bend:54-57 now says that the refusal holds in
every epoch until the monitor prunes the revoked record, and that an epoch
advance alone does not lift it.

The new check passes: "AU-007 a re-installed grant beside its revoked
record is ambiguous and withheld (NoGrant), at the same epoch and after an
epoch advance". It uses grant 210 at epoch 3 and grant 211 at epoch 4, each
beside revoked grant 201. The check pins a NoGrant result, which can only
come from the ambiguous lookup.

The Task 6 carry for AuditQuery is recorded.

## Gates

| item | result |
|---|---|
| `bend Tests.bend` | `ALL LIBRARY TESTS PASSED`, exit 0; 1713 `^PASS(:\| )` lines, 0 FAIL; `Audit: 285 checks passed`; both new checks PASS |
| `bend PROOF.bend` | `ALL PROOFS CHECK`, exit 0; `grep -c "^law " LAWS.bend` = 29 |
| LAWS.bend, PROOF.bend, Tests.bend | `git diff 45d5e99 607fd05` removes 0 lines; additions only |
| E4, E5, E6, K4, T9 | rerun on the fix tree: each still survives both tests and proofs; the equivalence arguments are unchanged |
| T1 | still fails the empty-state check and `Laws.audit_ungranted_export_emits_nothing` |
| my 15 channel probes (Probe.bend) | all still pass on the fix tree |

## New defects

None.
- `export_log_view` is listed among the implementation helpers.
- tasks.md box 1.4 cites the third law and the new check.
- The proof helper in PROOF.bend is marked as a helper, not a law.
- The fix commit also contains the round-0 review file task-5-review.md.
  That is a records file, and I note it only for traceability.

## Not run

`--verdict`, the native build and the GPU path. This was a JS/interpreter
run only.

Scratch: `/tmp/claude-1000/-mnt-MediaVolume-Media-src-github-com-spaceghost-writ/55038343-2e0b-4235-a6a8-7c68c6dd1f50/scratchpad/policy-aware-audit-review-t5/`
(mut3.tsv, mut4.tsv, tests-fix1.txt, proof-fix1.txt, probe-fix1/).
