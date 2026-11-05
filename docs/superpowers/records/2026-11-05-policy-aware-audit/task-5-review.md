# Task 5 review: policy-gated exports, metrics and alerts

Reviewer: task reviewer (information flow and proofs). Range reviewed:
47fd15a..45d5e99 on `lane/policy-aware-audit`.

Inputs read:
- task-5-brief.md, task-5-report.md and mutants/task-5.tsv.
- The review package diff.
- The plan's Global Constraints, including the controller rulings: a metric
  is a visible-only count and never a total; export grants are installed by
  the monitor, and who approves them is a recorded gap.
- The Task 1 to 4 reviews and re-reviews.
- AuditExport.bend in full.
- From AuditQuery.bend: `find_sink`, `sink_id_of`, `in_stream`, `visible`,
  `view_of`, `view`, `Gate` and `Gates`.
- The export section of AuditTests.bend.
- LAWS.bend and PROOF.bend as changed.
- The AU-007 spec delta.
- tasks.md and AGENTS.md.

Controller rulings applied, not flagged:
- the `Emission` constructor name;
- reuse of `AQ.Gate`;
- gates 3 and 4 overlap the outer checks and are pinned through
  `first_failed_gate`;
- Events sends the whole visible view;
- an empty Events batch is one wordless emission.

## Verdicts

1. Spec compliance: **NEEDS_FIXES**. One item blocks: I1.
   - The brief requires the view restriction to be pinned by a check that
     fails when it is removed. The plan's mutation standard requires every
     survivor to get a check. Half of the view restriction, the
     owner-stream filter, can be removed and every check still passes.
   - Everything else complies:
     - the four-name grant comes from monitor state for the authenticated
       `from`;
     - every channel is computed from the visible view only;
     - every denial is exactly `Withheld{}`;
     - both laws are real, hole-free, and broken by the brief's T1 mutant;
     - the five equivalent mutants hold up when rerun;
     - Q1 is killed;
     - the counts are 1711 and 28;
     - only touch-list files changed;
     - box 1.4 is checked with evidence.
2. Information flow and code quality: **NEEDS_FIXES**.
   - I1 is an information-flow regression gap. The code is correct, but
     nothing stops a change that makes an export grant for one owner emit
     other owners' events.
   - M1 is an inaccurate gap statement in the header.
   - None of my channel probes found a leak in the delivered code.

## Findings, by severity

### Important

**I1. The owner-stream half of the export view is not pinned. An export
that drops it leaks other owners' events and passes every check.**

Location:
- AuditExport.bend:461-462 (`export_view` relies on `AQ.view`, and through
  it on `AQ.in_stream`);
- the tests that should catch the mutant: AuditTests.bend:2933-2940 and the
  rest of `content_gated`.

What happens:
- My mutant R4 replaces the export view with "every logged event releasable
  to the sink", dropping the stream filter and keeping `releasable`.
- Result: `Audit` passes 283 of 283 and the proofs check.
- The implementer's V1, V9 and V10 do not cover it. V1 drops both filters.
  V9 swaps the owner. V10 drops only `releasable`.
- Why it survives: the hidden events in the export tests sit behind sink 1.
  Bob's event, subject 7's commit and Mallory's early denial are all
  non-releasable to sink 1 anyway. The check "Bob's own event, a commit by
  subject 7 and Mallory's early denial change no Events word" therefore
  never exercises the stream filter, although its name suggests it does.

The probe shows a real leak under R4 (scratch Probe.bend). Alice's exporter
60 is given Alice's grants for sink 4 on all three channels. Mallory's early
denial (`h_mallory`) is releasable to sink 4 but belongs to Mallory's stream.

| check | delivered code | R4 |
|---|---|---|
| Events over [v_admitted, h_mallory] equals Events over [v_admitted] | true | **false**: Mallory's event is emitted under Alice's grant |
| Metric with Mallory, Bob and commit events equals Metric without them | true | **false** |
| Alert with them equals Alert without them | true | **false** |

That is an export grant for owner Alice disclosing another owner's stream.
The grant's owner name is defeated even though `releasable` still holds.
Task 4 pinned the same property for queries in "AU-008 Mallory's
early-denied request naming Alice's objects is releasable to sink 4 yet
absent from Alice's stream" (AuditTests.bend:2413). The export side has no
counterpart.

Fix: add one check in `content_gated`.
- Install Alice's grants for sink 4 (exporter 60, one per channel, new ids
  such as 207 to 209). Alternatively use `x_only` per channel.
- Assert that the Events, Metric (rule AdmissionDenied) and Alert
  transmissions over `[v_admitted(), h_mallory()]` each equal those over
  `[v_admitted()]`.
- Assert also that the Events export is `Sent` and that `h_mallory` is
  `AE.releasable` to `sink_all()`, so the check is not vacuous.
- Name the check, for example: "AU-007 an event releasable to the export
  sink but outside the grant owner's stream (Mallory's early denial through
  sink 4) changes no Events, Metric or Alert word".
- Add R4 to the mutation table as killed by it.

### Minor

**M1. The header's re-grant remedy "until the epoch advances" is false.**

Location: AuditExport.bend:53-56.
- `grant_names` (:271-275) does not read the epoch. A revoked record
  therefore keeps matching its four names in every later epoch.
- Probe P4b: revoked grant 201 (epoch 3) plus a re-installed grant 207
  (epoch 4), with the state at epoch 4. The export is still withheld at
  `NoGrant`, because the lookup is ambiguous.
- This fails closed, so it is not a confidentiality problem. The stated
  remedy is wrong, though, and Task 6 will copy it into docs/AUDIT.md. The
  same wording entered the Task 4 review as a remedy, and AuditQuery's
  lookup behaves the same way.
- Fix: say that a re-installed grant with the same four names is ambiguous
  and refused until the monitor prunes the revoked record, in every epoch.
  An epoch advance alone does not help, because the lookup does not read
  the epoch. Optionally pin it with a check that asserts P4a and P4b.
  Carry the correction to Task 6 for AuditQuery's documentation as well.

**M2. The header does not say who receives a `Sent` Transmission.**

Location: AuditExport.bend:7-12 and :124-127.
- `transmit` is called for the exporter `from`. `Sent` holds the full
  sink-releasable words, and the export query state holds no read grant.
- If a host returned the Transmission to the exporter process instead of
  only to the sink binding, the exporter would read the owner's
  sink-cleared view with no read grant of its own.
- The model's statement "the emissions the monitor may hand to that one
  sink" implies the correct reading, but it does not state the host
  obligation.
- Fix: add one sentence to the trusted-inputs or "authenticates nothing"
  paragraph. A host delivers a `Sent` transmission's effects only to the
  named sink's binding. The exporter learns at most whether it was sent,
  and that bit depends only on the grant, the gates and the visible view.
  Copy the sentence into the Task 6 host obligations.

**M3. The header names the wrong `export_view` parameter.**

Location: AuditExport.bend:84. The header writes
`export_view(state, request, sink)`, but the def at :461 is
`export_view(state, owner, sink)`. Fix: write `owner`.

**M4. Forward reference to docs/AUDIT.md.**

Location: AuditExport.bend:110. The header says "(docs/AUDIT.md says so)",
but the file does not exist until Task 6. AuditEvent.bend:208 uses the
form "Task 6 copies these into docs/AUDIT.md". Fix: write "(Task 6's
docs/AUDIT.md says so)", or adopt AuditEvent's wording.

### Advisory (no change required)

**A1. The first law states "no effects", not "Withheld".** My mutant R2 (the
None arm returns `Sent{[]}`) satisfies `audit_ungranted_export_emits_nothing`
and is caught only by the tests' exact `Withheld{}` comparison. The brief
specifies `effects == []`, and that is "emits nothing", so the law matches
the brief. If you want the law to also pin "no distinguishable outcome on
denial", stating `transmit(...) == Withheld{}` would need the same proof.
The same applies to the revoked law.

**A2. Mutant scratch location.** The plan says mutants go under
`../writ-build/policy-aware-audit/mutants/`. They were placed in the session
scratchpad instead. The controller handed me the scratchpad table, so I
treat this as accepted.

## What I verified

Grant provenance (no request field is trusted):
- `transmit` (:611-612) looks the grant up with
  `find_export_grant(grants(state), from, request)`.
- `grants(state)` is monitor state.
- `from` is the separate authenticated parameter.
- `ExportRequest` has only version, owner, channel, sink_id and rule; no
  exporter, grant id, authority, total or clearance field.
- `grant_names` (:271-275) compares all four names exactly:
  `Nat.is_eq(exporter, from)`, `principal_equal(owner)`, `Nat.is_eq(sink,
  sink_id)` and `Channel.equal` (the tag compare).
- An ambiguous match is None (:277-305).

Sink consistency:
- The grant's sink equals `sink_id`.
- `find_sink(sinks, sink_id)` returns a sink only for a unique id match.
- Each emission is addressed to `sink_id_of` of that sink, so the grant's
  sink, the visibility sink and the emission address are the same sink.
- Probe P3: exporter 62's sink-3 grant used for sinks 1 and 4 is withheld.
- Mutant R7 (a constant emission address) is killed.

Channel content uses the visible view only:
- `content_at` (:558-564) passes `export_view(state, owner, sink)`, which is
  `AQ.view` over the log, to `channel_content`.
- `channel_content`, `views_words`, `metric_count`, `metric_words` and
  `alert_emissions` read only that `Views` value, the rule and the sink id.
- There is no other route from `AQ.event_log` to an emission. My grep finds
  `event_log` only at :462.
- No path counts the stored log or computes a total.
- The 2^32 metric bound and the `view_encodable` failure both depend only
  on the visible view, so neither the Withheld/Sent distinction nor the
  count can depend on a hidden event.
- `releasable` is applied through `AQ.visible`. Every emitted word is a
  view encoding of a visible event or a count of visible events.

Denials:
- `Transmission` has two constructors, and `Withheld{}` has no field.
- Every denial arm (:575-601, :549-564) returns exactly `Withheld{}`.
- There is no default channel or sink.
- Revocation always advances the revision (:670), and nothing is cached.

Laws:
- `audit_ungranted_export_emits_nothing` is a real implication. Its
  hypothesis is on the same lookup `transmit` performs.
- `audit_revoked_export_emits_nothing` takes two hypotheses.
- The proofs are one and two `Equal.sym` rewrites followed by `{==}`. They
  have no holes, no `unsafe` and no admitted terms.
- Both rationales are in LAWS.bend and in the module header (:140-153).
- LAWS.bend and PROOF.bend are additions only: one import each plus the
  appended laws.

My channel probes, all negative on the delivered code (scratch Probe.bend):

| probe | what it shows |
|---|---|
| P1b-d | a hidden event outside the owner's stream changes no Events, Metric or Alert result (positive only under R4) |
| P2a-c | an Alert grant used for Metric, an Events grant used for Alert, and a Metric grant used for Alert are each withheld |
| P3 | a grant for sink 3 used for sinks 1 and 4 is withheld |
| P4a-c | a re-grant after revocation is ambiguous and withheld at NoGrant, at the same and at the next epoch |
| P5 | a transmission after revocation at r+1 is withheld |
| P6 | a hidden denial between two visible ones leaves the alert count and order unchanged |
| P7 | a Top-owner grant does not answer for Alice |

The existing checks cover:
- the metric with three visible and two hidden events, over sink 1 (the
  value is 3);
- the alert presence and emission count with hidden denials.

Fixtures are distinct:
- exporters 60 to 63;
- readers 30 to 34;
- owners 0 to 2;
- sinks 1 to 4 and 9;
- grant ids 201 to 206;
- export revision 7 against query revision 5.

The partial-match checks each differ from grant 201 in exactly one name:
- exporter 63;
- owner Bob;
- sink 2;
- the Metric-only state for the channel.

Naming and comments: the public entry points are marked, and the
implementation helpers are listed. The gaps are stated:
- re-grant (with the error in M1);
- approval of export grants;
- timing and the label-table bit.

Tests.bend: it already holds the single `import ./AuditTests.bend as Audit`
and the `Audit.main()` call from Task 1. It is unchanged, and `export()` is
registered inside `AuditTests.main` next to the other audit sections, with
all seven groups called. "Audit: 283 checks passed" is the module's own
literal (the repository convention). No count pin changed.

Touch list: the commit changes AuditExport.bend (new), AuditTests.bend,
LAWS.bend, PROOF.bend, tasks.md (box 1.4 only) and the record directory.
The two deletions are the replaced version-check line and the count
literal. Box 1.4 cites AuditExport.bend, both laws, LAWS.bend, PROOF.bend
and named AuditTests checks.

## What I ran

Environment: Bend 2.0.39 with `BEND_NO_TELEMETRY=1`, on the JS/interpreter
path. I did not run `--verdict`, native or GPU checks.

Scratch: `/tmp/claude-1000/-mnt-MediaVolume-Media-src-github-com-spaceghost-writ/55038343-2e0b-4235-a6a8-7c68c6dd1f50/scratchpad/policy-aware-audit-review-t5/`
(mut.py, mut.tsv, mut2.tsv, Probe.bend, tests.txt, proof.txt).

| command | result |
|---|---|
| `bend Tests.bend` | `ALL LIBRARY TESTS PASSED`, exit 0; 1711 `^PASS(:\| )` lines, 0 FAIL; `Audit: 283 checks passed`; 35 AU-007 checks, all distinct names |
| `bend PROOF.bend` | `ALL PROOFS CHECK`, exit 0; `grep -c "^law " LAWS.bend` = 28 |
| `grep` for `unsafe`, `?TODO`, `T.admit(`, `commit_from_capability(`, `Backplane.commit`, `D.meet` in AuditExport.bend | 0 code hits (one comment hit for "IO"); no array indexing |

My own mutation batch (`mut.py`) copies the worktree's `.bend` files, applies
each mutant, and runs `bend AuditTests.bend` and `bend PROOF.bend`.

Equivalent mutants rerun. Each survives the tests and the proofs, and the
implementer's arguments hold:

| mutant | why it is equivalent |
|---|---|
| E4, E5, E6 | `found_*` accepting None is unreachable: `transmit` returns at the lookup None arm, and `first_failed_gate` stops at gate 3 |
| K4 | `found_unrevoked(None)` is False, so the presence gate is redundant |
| T9 | `content_at` None is reachable only when gate 2 already failed on the same `find_sink` call |

Killed mutants rerun:

| mutant | result |
|---|---|
| T1 (the brief's default-sink mutant) | fails the empty-state check and `Laws.audit_ungranted_export_emits_nothing` |
| T2, T4 | survive the tests; fail `Laws.audit_revoked_export_emits_nothing` |
| N4 | killed by the another-channel check |
| A1 | killed by the ambiguous-grants check |
| V8 (a total over the stored log) | killed by the 3-visible / 2-hidden metric check |
| Q1 (AuditQuery `<=`) | killed by "AU-008 an unknown query format version is refused (UnknownVersion)" |

My own mutants:

| mutant | result |
|---|---|
| R1: the None arm defers to the gates | survives the tests (gate 3 withholds); fails `Laws.audit_ungranted_export_emits_nothing`, so the law pins the arm |
| R2: the None arm returns `Sent{[]}` | killed by the empty-state check; the law holds (A1) |
| R3: Alert over the raw log | killed by the hidden-denial alert check |
| R4: the export view drops the owner-stream filter | **SURVIVED**, proofs check (I1) |
| R5: Metric over the owner's stream without `releasable` | killed by the metric check |
| R6: `revoke_export` does not advance the revision | killed |
| R7: a constant emission address | killed by the sink-3 check |
| R8: the metric is never withheld at 2^32 | killed |
