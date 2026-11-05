# Task 4 review: owner-scoped queries, current grants and response sinks

Reviewer: task reviewer (information flow and proofs). Range reviewed:
85f8c3f..6cfb953 on `lane/policy-aware-audit`.

Inputs read:
- task-4-brief.md, task-4-report.md and mutants/task-4.tsv.
- The review package diff.
- The plan's Global Constraints and shared design (the controller rulings).
- The Task 1 to 3 reviews and re-reviews, including the carried stream item.
- AuditQuery.bend in full.
- From AuditEvent.bend: `Sink`, `Recorded`, `releasable`,
  `influences_flow`, `principal_equal`, `owners_contain`, `event_owners`,
  `streams_for`, `event_streams` and `requester_checked`.
- The query section of AuditTests.bend.
- LAWS.bend and PROOF.bend as changed.
- The AU-003, AU-008 and AU-009 spec deltas.
- tasks.md and AGENTS.md.

## Verdicts

1. Spec compliance: **APPROVED**. All nine gates are present, in the stated
   order, and each reads only the authenticated `from`, the trusted `now` or
   monitor state. There is one public refusal value. Pages are built from the
   visible view only. All three laws are complete and non-trivial. Every gate
   has a single-failure check, the carried stream item is met, the suite and
   proofs are green at the expected counts, and only the touch-list files
   changed.
2. Information flow and code quality: **APPROVED**. None of my channel probes
   found a leak. I record three minor items and three advisories below. None
   of them blocks.

## Findings, by severity

No Critical or Important findings.

### Minor

**M1. The version gate's lower boundary is not pinned.** Location:
AuditQuery.bend:586-587; the only version check is AuditTests.bend:2593.

- My mutant X2 changes `Nat.is_eq(version, query_format_version())` to
  `Nat.is_le(...)`, which accepts version 0. It compiles and survives both
  `bend AuditTests.bend` and `bend PROOF.bend`.
- The tests only use version 2 (above the supported version). The lane
  already pins the equivalent boundaries elsewhere: E1 for inclusive expiry,
  and L1 to L3 for the limit.
- Impact is small. A version-0 query is still answered under every other
  gate, so it does not widen what a caller can see. It is still a weakened
  gate condition that no check notices.
- Fix: in `distinct_reasons`, extend the UnknownVersion check to cover
  version 0 as well, using `refused_at(..., AQ.Query{0n, alice(), None{},
  AQ.max_page(), 100n}, 1n, AQ.UnknownVersion{})`.

**M2. The header misstates which absences fail which dependent gates.**
Location: AuditQuery.bend:65-66, "no sink or no grant makes gates 4 to 6 and
9 false".

- No grant makes gates 4 to 6 false. No sink makes gate 9 false.
- No sink does not falsify gates 4 to 6. Grant 107 names unregistered sink 9
  and is found, so gates 4 to 6 hold.
- No grant does not falsify gate 9.
- The report states this correctly, and Task 6 copies the header into
  docs/AUDIT.md, so the header should match.
- Fix: replace the clause with "(no grant makes gates 4 to 6 false; no
  registered sink makes gate 9 false)".

**M3. A grant cannot be re-issued after it is revoked.** Location:
AuditQuery.bend:417 (`find_read_grant` is ambiguous on any second match)
together with :734-735 (revoked records are kept).

- My probe installs revoked grant 101 next to a fresh grant 108 for the same
  reader, owner and sink. The query is refused at `NoGrant`, because the
  lookup is ambiguous.
- This fails closed, so it is not a confidentiality problem. However, once a
  grant is revoked, the same reader, owner and sink can never read again in
  that epoch. The module does not say so.
- Fix: document this in the header's grants paragraph. Name the remedies: a
  new epoch, or a monitor that prunes revoked records. Then add a check that
  pins the behaviour.
- Do not resolve this by having `find_read_grant` skip revoked grants. That
  is my mutant X7, which removes gate 4's meaning: the gate name changes to
  `NoGrant`, and the GrantRevoked check catches it.

### Advisory (no change required)

**A1. Should a cursor also bind the revision? Ruling: binding the epoch is
sufficient.** Location: AuditQuery.bend:190-191 and :594-602.

The response is a function of three things: the current visible view
(`view(state, owner, sink, event_log(state))`), the public inputs (limit,
work, `from`, owner, epoch), and the caller-chosen offset. A cursor is
forgeable public data, so any field bound into it is a consistency check,
not a confidentiality control.

- A grant revoked between r and r+1 fails at gate 4 for every cursor, and a
  query at r is stale (the law).
- An event that becomes hidden between r and r+1 leaves the view. In this
  model, nothing within an epoch makes a visible event hidden:
  - `revoke_read` changes only grants;
  - visibility reads only the snapshot, the epoch, the sink and the record.
- Even if a monitor reinstalled a relabelled state under the same epoch, an
  old offset would only shift the continuation within the caller's current
  view. Any difference the caller sees is a difference between two views it
  was authorised to see. Re-querying from offset 0 recovers the same
  information.
- The offset never encodes the position of a hidden event. This follows from
  `audit_invisible_event_unobservable` and the structural point verified
  below. My probes show that a cursor from revision r, after an unrelated
  revocation and with hidden events added, continues exactly as over the
  hidden-free log.
- Binding the revision would only force every page sequence to restart after
  any state change.

A related point, consistency only: the cursor does not bind the sink. An
offset from a sink-3 view can be replayed against the reader's sink-1 view.
The sink-1 response then echoes a caller-supplied number, plus visible
counts. The monitor discloses nothing new, because the caller already held
that offset. If the plan is revisited, binding `sink_id` would make
continuations well-defined across sinks.

**A2. Law 1 is stated over `view` (accepted ruling, structure verified).**

- `event_log` is read once, at AuditQuery.bend:582, inside `query_page`,
  which passes it directly to `view`.
- Gate 9 (:619) and `answer` (:674) both go through `query_page` with
  identical arguments.
- `page`, `page_response` and `next_cursor` see only `Views` and `Paged`.
- `visible` reads only `snapshot(state)` and `epoch(state)`.

So `respond` reads the log only through `view`.

My mutant X1 shows why this check matters. X1 makes `next_cursor`'s
presence depend on the raw log length. It passes `bend PROOF.bend`, because
it bypasses `view`, and is caught only by the tests (it fails "an
Alice-stream query omits Bob-only events ...").

If Task 6 has room, consider a `respond`-level form: for constructor states
that differ only in a hidden insertion into the log, `respond` is equal. It
is not required by the ruling.

**A3. Owner `Top` is "nobody's stream" by convention only.** Location:
AuditEvent.bend:974-975, as consumed by AuditQuery `in_stream`.

- AuditQuery accepts a grant naming any owner, including `D.Top{}`.
- My probe installed such a grant through sink 4. It saw nothing, because
  every Top-stream event carries the maximal-restriction influence.
- So releasability holds the line, and no gate is needed.
- Optional: a sentence in the header noting this would make the
  "nobody's stream" claim self-contained.

## Verification of the brief's items

### Gates and authority

- The nine gates appear in the stated order (`query_gate_list`, :606-620).
- `respond` matches on the revision first (:699-700, :684-690), then on
  `Guard.all(query_gates(..))` (:677-682).
- The grant comes from `find_read_grant(grants(state), from, owner,
  sink_id)`. `from` is a separate parameter, and `Query` has no reader,
  authority, sort, total or count field (:194-195).
- Sinks are re-resolved by id from `sinks(state)`, both at gate 2 and in
  `answer`. Both reads are of the same pure state value, so a sink cannot be
  substituted between the check and the response. Q4 and P7 confirm this.
- Gates 7 to 9 read request fields (cursor, limit, work), but only as
  quantities checked against monitor state. None is treated as authority.

### The refusal

- `PublicDenial` has one constructor, `Unavailable{}`.
- `Refused{category}` carries no reason, and `Gate` never appears in a
  `Response`.
- The term of `audit_refusal_is_constant` gives exactly
  `Refused{Unavailable{}}` for any failing gate list.
- `audit_stale_query_refused` covers the successor revision.
- My mutant X5 adds a second constructor for staleness. It fails at the law
  and at the stale check.
- My mutant X4 (stale gives an empty page) fails at the law and at the
  stale check.

### Laws and proofs

- 26 laws, three of them new. LAWS.bend and PROOF.bend changed by additions
  only (zero removed lines).
- Each law has its rationale above it and in the module header's "Laws"
  paragraph. The proofs are complete, with no holes.
- `nat_eq_successor_false` is reused, not restated.

### Mutants rerun

All were rerun in scratch copies under
`scratchpad/policy-aware-audit-review-t4/mut/`.

The brief's mutants and the stream probe:
- V4 (placeholder filter): killed by a test, and fails at
  `Laws.audit_invisible_event_unobservable`.
- R3 (revoked gives `Page{[], None}`): killed by "...r+1 is refused and
  first_failed_gate names GrantRevoked", and fails at
  `Laws.audit_refusal_is_constant`.
- V3 (the Mallory stream probe): killed by "AU-008 Mallory's early-denied
  request naming Alice's objects ...".

The six claimed equivalents, E4, E5, E6, K4, P6 and P7, all survive both the
tests and the proofs. I checked each argument against the code:
- E4 to E6 use the same `+grant` binding that gate 3 tests, so their None
  arm is reached only after gate 3 has failed.
- K4: `found_unrevoked(None)` is False, so the rejection is unchanged.
- P6: `answer` calls `query_page` with exactly gate 9's arguments, so it
  always sees `Built`.
- P7: `query_page` reaches its None arm only when gate 2 has already failed.

All six are truly equivalent.

My own mutants:

| id | mutation | result |
|---|---|---|
| X1 | cursor presence from the raw log length | killed by tests only |
| X2 | version gate uses `<=` | SURVIVED (M1) |
| X3 | limit upper bound exclusive | killed |
| X4 | stale revision gives an empty page | killed, and fails at the stale law |
| X5 | second denial constructor for stale | killed, and fails at the stale law |
| X6 | revoke matches on reader, not id | killed |
| X7 | lookup skips revoked grants | killed, through the gate name |
| X8 | work charges the raw log length | killed by "hidden events consume no work" |
| X9 | cursor reader not compared | killed |

### Channel probes

The probe file is `scratchpad/policy-aware-audit-review-t4/probe/Probe.bend`.
All ten probes pass:
- A hidden event between two visible ones changes neither the next cursor
  nor the exact work threshold. Limit 1 with work 1 equals the hidden-free
  run, and offset 1 needs work 2 either way.
- A forged cursor past the view gives `Page{[], None}`, both with and
  without hidden events.
- Probing with forged offsets and varying work reveals only the length of
  the visible view.
- A revocation between two pages is refused, as stale and at gate 4.
- A cursor from revision r continues correctly at r+1.
- Bob's early-denied request naming Alice's objects is absent from Alice's
  stream.
- Owner Top and owner Bottom are refused for Alice's reader.
- Version 0 is refused by the actual code. M1 is about the survivor, not
  current behaviour.
- A re-grant after revocation is refused (M3).
- A Top grant sees nothing (A3).

Fixtures are distinct where it matters:
- readers 30 to 34;
- owners Named 0 to 2;
- sinks 1 to 4 and 9;
- grants 101 to 107.

The numeric collisions (Bob's id 1 and sink 1; epoch 3 and sink 3) involve
different types or different positions that no plausible mutant confuses.

### Header and stated gaps

- The timing channel is stated accurately. The view walks the whole log, in
  fact twice: once for gate 9 and once in `answer`.
- The one-bit label-table channel inside the requester's own stream is
  stated accurately and matches Task 3.

### Scope and records

- Tests.bend is unchanged. Task 1's single import (:16) and call (:35) sit
  next to the audit registration.
- The changed files are within the touch list: AuditQuery.bend,
  AuditTests.bend, LAWS.bend, PROOF.bend, tasks.md (box 1.3 only, citing
  files, laws and check names) and the records.
- No count pin changed.
- The greps for `T.admit(`, `commit_from_capability(`, `Backplane.commit`,
  `D.meet`, `unsafe`, holes and array indexing all give 0.

## Commands run

Environment: `export PATH="$HOME/.local/share/writ-toolchains/bend-2.0.39/bend/bin:$PATH"; export BEND_NO_TELEMETRY=1`.

| command | result |
|---|---|
| `bend AuditQuery.bend --check-only` | `ALL PROOFS CHECK`, exit 0 |
| `bend AuditTests.bend` | `Audit: 248 checks passed`, exit 0 |
| `bend Tests.bend` | `ALL LIBRARY TESTS PASSED`, exit 0; 1676 `^PASS(:| )` lines, 0 FAIL |
| `bend PROOF.bend` | `ALL PROOFS CHECK`, exit 0 |
| `grep -c "^law " LAWS.bend` | 26 |
| `git diff 85f8c3f 6cfb953 -- LAWS.bend PROOF.bend Tests.bend` | additions only |
| `openspec validate --all --strict --no-interactive` (1.16.0) | 44 passed, 0 failed |

The mutant runner is
`scratchpad/policy-aware-audit-review-t4/run.py`, and its results are in
`results.tsv` and `results2.tsv` beside it.

Not run: `--verdict`, the native build and the GPU path. This is a
JS/interpreter run only, as for the implementer.
