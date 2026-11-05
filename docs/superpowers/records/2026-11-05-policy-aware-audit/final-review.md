# Final whole-branch review: policy-aware-audit (section 1)

Branch `lane/policy-aware-audit` at `0d886cb`, merge base `d7967c8`. I reviewed
the whole-branch diff, the three modules in full, LAWS.bend and PROOF.bend in
full, the tests, docs/AUDIT.md, the traceability, the evidence, the task boxes
and every task record. Task 6 is under its own task review, which also covers
the token equivalence of the native-arity layout. I did not repeat that check.

**Assessment: Needs fixes before merge.**

The model is sound. No law is weakened, no proof has a hole, and none of the
seven attack scenarios got a hidden fact out through a page, a cursor, a work
charge or an emission. Two blocking findings remain, and both are in the
contract the branch publishes. (1) Nothing says that the wrapper's return
value, which holds the event and a policy listing other owners' labels, must
stay inside the monitor. (2) The traceability says, without any test behind
it, that the wrappers are the only producers of a stored event. Both fixes are
a few sentences of documentation. Neither needs a code change.

## Findings, by severity

### B1 (blocking, medium-high). The wrapper's return value is a second route out, and no obligation closes it

- Where: `AuditEvent.bend:997-1029` (`audited_admit` and `audited_commit`
  return `AuditedAdmission{decision, event, recorded}` and
  `AuditedCommit{result, event, recorded}`); `docs/AUDIT.md:69-70` and
  `docs/AUDIT.md:389-396` (host obligations);
  `openspec/traceability/policy-aware-audit.md:39-40` (AU-001 and AU-002
  rows).
- Problem: `recorded.policy` lists `Influence{owner, label, edge}` for every
  object the plan names. It does the same for every source and destination
  policy object of the authoritative context, which the requester did not
  name. It also carries the context's secrecy and untrusted bit sets. On
  commit it adds the resolved binding's joined label. The `event` holds a
  reason, and on commit an artifact digest. The documented first host
  obligation is to "call `audited_admit` and `audited_commit` in place of the
  bare library calls". A host that does that literally and hands the wrapper
  result back to the requester (the natural reading of "in place of") gives
  her far more than her own decision: it is a label-table oracle. She can name
  any object version, even under a stale stamp, and read back its owner and
  label, plus the context's other policy objects. That is much more than the
  documented one bit per request, and it bypasses the stream rule,
  `releasable` and every query gate. The present obligation, "send nothing
  derived from the log outside `respond` and `transmit`", does not cover it,
  because the record is not yet in the log.
- Fix (documentation only):
  - Add a host obligation to `docs/AUDIT.md` "The host also has these
    obligations". The text: the host returns only `AuditedAdmission.decision`
    or `AuditedCommit.result` to the caller. The `event` and the `recorded`
    record go only to the monitor's log. They are never returned, logged
    elsewhere or sent to any party except through `respond` or `transmit`.
  - Say the same in the `audited_admit` and `audited_commit` doc comments and
    in the AuditEvent header ("Trusted inputs" or a new "Outputs" bullet).
  - Add it as a reviewed-only host obligation in the AU-001 and AU-002
    traceability rows.
  - Reword `docs/AUDIT.md:69-70` so that "returns the projected event and its
    policy" is read as returning them to the monitor.

### B2 (blocking, medium). The claim "the wrappers are the only producers of a stored event" has no test behind it, and a forged record is visible

- Where: `openspec/traceability/policy-aware-audit.md:51`;
  `AuditQuery.bend:188-189` ("each the record ... one AuditEvent wrapper
  returned"); `docs/AUDIT.md:385` (the event-log row);
  `AuditEvent.bend:125-130` (the "authenticates nothing" paragraph does not
  draw the log consequence).
- Problem: `AE.Recorded`, `AE.EventPolicy` and `AQ.Stored.cons` are public
  constructors. The model's log is whatever the monitor installs. Scenario (g)
  below decodes a genuine `ScopeNotRead{}` event, wraps it with a hand-built
  empty policy and places it in the log. The result: a Bob-only sink with a
  grant on Alice's stream sees an event that the genuine record keeps from
  that sink. The wrappers are the only producers the model provides. They are
  not the only possible producers, and the tests only ever store wrapper
  output, so they cannot show exclusivity. The encoding also carries no
  policy, so no decoded event can be re-labelled from the wire.
- Fix (documentation only):
  - Reword traceability line 51: "The wrappers are the only producers of a
    stored event that the model provides. The log is monitor-installed state,
    and `Recorded` is a public constructor, so a host must store only the
    `recorded` value a wrapper returned in the same invocation. A decoded
    event carries no policy and must never be re-logged."
  - Add the same as the precondition in the `docs/AUDIT.md:385` row and as a
    host obligation.
  - Change `AuditQuery.bend:188-189` to say "expected to be" (a precondition)
    rather than stating it as a fact.
  - Carry "the wire format has no policy, so durable storage must persist or
    re-derive the policy recorded at decision time" to section 2 (task 2.3) as
    an open item.

### N1 (should fix; not blocking). Query responses and the time between authorization and delivery

- Where: `docs/AUDIT.md:389-396`; `AuditQuery.bend:7-16`.
- Problem: there are two gaps.
  - The delivery-to-sink obligation is stated for `Transmission` only. A
    `Page` is releasable to the sink's label, and the reader's grant names
    that sink. Nothing checks that `from` may read data at that label. So a
    host must also deliver a `Page` only through the resolved sink's binding.
  - Both `respond` and `transmit` authorize at the call. A host that keeps a
    `Page` or `Sent` value and delivers it after a revocation is installed
    releases it after revocation. That is AU-003 "Query grant is revoked" and
    AU-007 "Export authority is revoked", at the host. The `expected_revision`
    check does not help here: the caller supplies it, and it is checked only
    at the call.
- Fix: add two obligations. (1) Deliver a `Page` only through the resolved
  sink's binding. (2) Deliver a `Page` or `Sent` value within the same
  serialized step as the call that produced it, and never after a later state
  is installed (AB-006). Add both to the AU-003 and AU-007 traceability
  reviewed-only cells.

### N2 (optional, low). `first_failed_gate` is a protected diagnostic

- Where: `AuditQuery.bend:575-580`, `AuditExport.bend:402-406`,
  `docs/AUDIT.md:276-277`.
- Problem: it separates GrantRevoked, NoGrant and the other gate causes,
  which the one public refusal exists to hide. The documents say it is "for
  monitor diagnostics", but a monitor diagnostic log is exactly the
  ungoverned fallback that AU-007 forbids.
- Fix: one sentence. Its output is protected monitor state, and it is never
  written to any log, response or emission.

### N3 (optional, low). Stale task-relative wording in the module headers

- Where: `AuditEvent.bend:108`, `:117`, `:208`, `:785`;
  `AuditQuery.bend:116`; `AuditExport.bend:112`, `:120`, `:130`.
- Problem: these lines say "carried to the Task 6 gaps", "recorded gap for
  Task 6", "Task 6 copies these into docs/AUDIT.md" and "carried to Task 6".
  Task 6 is done and docs/AUDIT.md holds them now.
- Fix: replace each with "recorded in docs/AUDIT.md (Residual channels /
  Ownership and label rules)".
- Status: none of the stale strings the brief listed ("Task 1.5", "about 16
  checks", 1477, 1488, 1576, 1619, 1626, 1676, 1711, "Task 3 obligation", "a
  later task") occurs in any delivered file.

### N4 (optional, cosmetic). Duplicated native-arity comment blocks in AuditTests.bend

- Where: `AuditTests.bend:493` and `:501`, `:545` and `:553`, `:2213` and
  `:2221`.
- Problem: each block appears twice in a row. These are comments only, and
  Task 6's review owns the layout.
- Fix: delete one copy of each.

### N5 (optional, low). Open question 3 reads as if withholding were an option

- Where: `docs/AUDIT.md:469-471`.
- Problem: the question asks whether a metric "that a hidden event would
  affect" should be withheld. The ruling, eleven lines above, says
  withholding would reveal that hidden events exist.
- Fix: add "(withholding would itself reveal hidden events, see the ruling
  above)" so that an operator does not read it as a safe alternative.

## Security laws and contribution rules (review item 1)

- **Additions only.** Running `git diff d7967c8 -- LAWS.bend PROOF.bend
  Tests.bend` shows no removed line. Before the change: 17 laws (master still
  has 17). After: 29.
- **The 12 new laws.** I read every statement and every proof term. None is a
  tautology. Every hypothesis can be satisfied. Each statement depends on
  module structure that a compiling mutant can break:
  - `audit_stale_query_refused` depends on the outer revision match;
  - `audit_ungranted_export_emits_nothing` and
    `audit_revoked_export_emits_nothing` depend on the lookup and revocation
    matches. My rerun of T2 survives all 285 checks and fails only at the
    revoked law;
  - `audit_failed_influence_withholds` fails under R2;
  - `audit_outcome_never_lowers_policy` fails under W1, W3 and W7.
- **Proof terms.** These are `{==}` by computation,
  `%Equal.sym` rewrites of the hypothesis, structural induction on `before`
  (`audit_failed_influence_withholds`, `audit_invisible_event_unobservable`),
  and reuse (`audit_export_outside_stream_unobservable` reuses the invisible
  law through a helper). The two helpers (`audit_bool_and_false_right`,
  `audit_outside_stream_invisible`) are documented as helpers, not laws.
- **Rationale and safety.** Every law has a rationale with limits in its own
  LAWS.bend comment and again in its module header. No unsafe definition,
  hole or unchecked index occurs: a grep of the three modules finds no
  `unsafe`, `get`, `at` or `nth`.
- **Caller-supplied fields.** I traced every field of every request type
  (`Plan` through `audited_admit`, `Ref` and session through
  `audited_commit`, `Query`, `Cursor`, `sink_id`, `ExportRequest`).
  - The subject is the authenticated `Caller.subject` or `OS.subject(ref)`.
    The token and diagnostic are never read (laws).
  - Scope fields reach an event only under `ScopeRead`: after the write grant
    matched, or from the negotiated session on commit.
  - Plan objects reach the policy only as extra restrictions (monotone). They
    choose stream membership only under `ScopeRead`.
  - `owner`, `sink_id` and `channel` must match a monitor grant. A cursor
    must match `from`, the owner and the live epoch, and its offset only skips
    the caller's own view.
  - `limit` and `work` are gated. `rule` is a closed `EventKind`.
  - `expected_revision` is compared with the installed revision.
- **Routes that return words or records** (the release-route list):
  - `audited_admit` and `audited_commit` return to the monitor (B1).
  - `respond` returns a `Page` only after the revision check and all nine
    gates (current grant, sink), built from `view`, which is the stream rule
    plus `releasable`.
  - `transmit` returns `Sent` only after the lookup, revocation, revision and
    six gates, built from `export_view`, which is the same `view`.
  - `encode`, `decode` and `view_encode` are boundaries: they hold no policy
    and grant nothing.
  - `first_failed_gate` (twice) is a diagnostic (N2).
  - The accessors read records the caller already holds.
  - No other function reads the log.
- **Untouched modules.** `git diff --name-only d7967c8` lists only the three
  new modules, AuditTests.bend, LAWS.bend, PROOF.bend, Tests.bend (two lines),
  docs/AUDIT.md, tasks.md, the traceability, the evidence and the records.
  Transfer, DataOS, Backplane, Frontend, Dlm and Guard are byte-unchanged.
- **No label is lowered.** A grep of the three modules for `meet`, `.sub(`,
  `Nat.sub`, `declass` and `public_untrusted` finds nothing outside comments.
  The only label built is the requester's own (`AuditEvent.bend:787`), which
  is an added influence. The fail-closed paths use `D.maximal_restriction()`.

## Attack scenarios (review item 2)

Scenarios (a) to (g), plus a read re-grant check, are in
`/tmp/claude-1000/-mnt-MediaVolume-Media-src-github-com-spaceghost-writ/55038343-2e0b-4235-a6a8-7c68c6dd1f50/scratchpad/policy-aware-audit-final/tree/Scenarios.bend`. That file is a
copy of the tree plus the scenario file. It reuses AuditTests' synthetic
fixtures, and every stored event comes from a wrapper except the deliberate
forgery in (g). Result: 22 PASS.

- **(a) Many early denials naming a victim's objects, then a query of the
  requester's own stream.** Mallory sends three Stale-denied requests naming
  Bob's objects 11 and 20 (Bob-labelled table).
  - Bob's page through sink 2, and through sink 4 (which could receive
    Mallory's events), equals the page for a log without them. The victim's
    count and order are unchanged, and nothing about the victim's policy
    reaches a page: `View` has no policy field.
  - Mallory's own sink-7 page is empty. Through sink 4 she sees her three
    denials, with `ScopeNotRead{}` and her own subject only.
  - The documented one-bit label-table channel is confirmed. The same request
    is visible to sink 7 when the named objects carry Mallory's label, and
    hidden when they carry Bob's.
  - Outcome: no leak beyond the stated bit. B1 is the exception: if a host
    returned the wrapper record to Mallory, she would get far more.
- **(b) A reader with grants for two owners' streams.** Reader 36 holds
  Alice's and Bob's streams through sink 3.
  - Both pages are identical with a hidden event (an unregistered-subject
    commit, a Mallory early denial naming Bob's objects, or a Mallory early
    denial naming Alice's) at positions 0, 2 or 4.
  - The mixed event appears in both pages. It orders visible events
    relative to each other, all of which this sink may see, and nothing else.
  - Cursors bind the owner, so no cursor can cross streams.
  - Outcome: the relative timing of hidden events is not revealed.
- **(c) An export grant revoked between building the visible set and
  emitting.** The model has no gap between the two: `transmit` computes the
  view and the emissions in one call from one state. `Sent` at revision r
  becomes, after `revoke_export`, withheld both at r (stale) and at r+1
  (revoked). The separate Metric grant still sends, so revocation is
  per-channel and exact.
  - The real window is at the host, which may keep the earlier `Sent` value
    and deliver it later. No obligation says not to (N1).
- **(d) A metric before and after a hidden event that the same sink may not
  see.** Alice's sink-1 metric, for both the AdmissionDenied and the
  AdmissionAdmitted rules, is unchanged by Bob's event, Mallory's events
  (one of them releasable to sink 4) and a mixed event in her own stream.
  - My mutant V8 (the metric counts the raw stored log) is killed.
  - Outcome: no leak.
- **(e) An alert rule over a field absent under `ScopeNotRead{}`.** No such
  rule can exist: `rule` is a closed `AE.EventKind`, so no predicate can name
  a scope field.
  - An AdmissionDenied alert over a visible `ScopeNotRead{}` event fires once,
    with the view encoding whose scope fields have length 0. It equals the
    test-side oracle.
  - Early denials outside the stream fire nothing, and the result is
    `Sent{[]}`, the same as an empty log.
  - Outcome: no partial or erroneous encoding, and no leak.
- **(f) A commit whose binding label is above the requester's.** Mallory's
  label is on the binding, subject 7 commits, and the snapshot has eight
  principals.
  - The requester's own sink 10 and the objects-plus-requester sink 8 both
    get empty pages.
  - Sink 9, which satisfies every influence, gets the event in Alice's stream
    and in the requester's.
  - Mallory, whose label the binding carries, has no stream holding the
    event: the binding influence is owned by the destination's owner. Her
    label only restricts.
  - Outcome: only a sink that satisfies the requester's, the objects' and the
    binding's labels can read the event. This is documented in docs/AUDIT.md
    ("Ownership and label rules").
- **(g) A decoded record re-entering the log.** `decode(encode(e))` returns
  the event. The view encoding is rejected by `decode` (an existing check).
  Wrapped in a hand-built `Recorded` with an empty policy, the decoded
  `ScopeNotRead{}` event is visible to Bob-only sink 2 in Alice's stream,
  while the genuine record is not. The model cannot tell the two apart.
  - Outcome: this is a monitor-integrity precondition, not a caller route.
    Section 1 has no append API. But it is stated as a fact (B2), and the
    wire format carries no policy (an open item for section 2).
- **Extra: re-granting a read grant after revocation.** A revoked grant 101
  beside a re-installed grant 108 with the same three names is refused
  `NoGrant` at epoch 3 and at epoch 4. This matches the AuditQuery header and
  docs/AUDIT.md. The traceability correctly records the read-grant case as
  reviewed-only: the suite has no check for it, while the export case is
  pinned.

## Mutants (review item 4)

The removal-map spot check uses scratch copies in
`/tmp/claude-1000/-mnt-MediaVolume-Media-src-github-com-spaceghost-writ/55038343-2e0b-4235-a6a8-7c68c6dd1f50/scratchpad/policy-aware-audit-final/mut/<id>/`, each run with
`bend AuditTests.bend` and `bend PROOF.bend`:

| Task | id | mutation | outcome | matches the map |
| --- | --- | --- | --- | --- |
| 3 | P21 | `admission_policy` drops the requester | killed: "AU-002 Mallory's denied request is withheld from the Alice-and-Bob sink 3, ..."; proofs check | yes |
| 3 | R2 | `influences_flow` checks only the head | killed: "AU-002 the Origin denial event is withheld from Bob-only sink 2 ..."; fails at `Laws.audit_failed_influence_withholds` | yes |
| 3 | P10 | a missing label becomes public (`Bottom`, `public_untrusted`) | killed: "AU-002 an unlabelled source gives the maximal-restriction influence ..." | yes |
| 5 | V8 | the metric counts every stored event (a total) | killed: "AU-007 an event releasable to the export sink but outside the grant owner's stream ... changes no Events, Metric or Alert word" | killed. The first failing check is a fix-round check that runs before the one the map names; the map notes this kind of shift |
| 5 | N4 | the grant's channel is not compared | killed: "AU-007 a grant for another channel does not answer: ..." | yes |
| 5 | T2 | the revoked arm falls through to the content | survives all 285 checks; fails at `Laws.audit_revoked_export_emits_nothing` | yes, as the map states |

My own whole-branch mutants, all killed:

- XA: the `ScopeNotRead` stream joins the influence owners (the Task 3 fix
  undone). Killed by "AU-002 an early-denied (ScopeNotRead) event joins only
  the requester's stream ...".
- XB: the work gate also charges the raw log length. Killed by "AU-009 hidden
  events consume no work ...".
- XC: the cursor ignores the epoch. Killed by "AU-008 a cursor from an older
  epoch is refused".
- XE: `in_stream` uses the influence owners. Killed by "AU-008 Mallory's
  early-denied request naming Alice's objects ... equals the one for an empty
  log".
- XH: the commit policy drops the context influences. Killed by "AU-002 a
  commit event's influences are ... in that order".

## Cross-task consistency (review item 3)

The module headers, docs/AUDIT.md, the traceability rows, the evidence file
and the four task boxes agree on every rule:

- the `ScopeNotRead{}` rule, including the InvalidPolicy ruling and "a reason
  that can occur both early and late is treated as early";
- the stream rule, with Top's stream for subjects that cannot name a
  principal;
- the requester's label on every admission event, and the binding's joined
  labels plus the requester on commit;
- monitor-installed grants as a recorded gap;
- metrics as visible-only counts, never totals;
- the owner-stream export law;
- re-granting after revocation refused, and not lifted by an epoch advance;
- the subject-numbering gap;
- the timing, scheduling, traffic and one-bit label-table channels;
- the exporter's bit.

The only stale wording left is N3.

For the evidence, every quoted test name in the traceability (94), in
docs/AUDIT.md (7) and in tasks.md (53) is an exact PASS label in my run. No
PASS label occurs twice.

## What I verified and how

- `bend PROOF.bend`: `ALL PROOFS CHECK`.
- `bend PROOF.bend --verdict` was not available (no `lean` or `elan` on
  PATH), so nothing is kernel verified. The evidence file says so.
- `bend Tests.bend` on the embedded runtime passed: 1713 PASS lines,
  `Audit: 285 checks passed`, and the per-module totals sum to 1713. I did
  not rebuild the native binary. The evidence records a native CPU run with
  `--gpu off` and calls it explicitly not a GPU test.
- `openspec validate --all --strict --no-interactive` (1.16.0): 44 passed,
  0 failed.
- `git merge-tree` of the branch into the current master (`f970496`, which
  changed only plan and question records since the merge base): clean.
- No delivered sentence claims a Lean verdict, a GPU run, a host run or a
  durable store. Each mention says not run, not implemented or section 2.

## Merge readiness (review item 5)

Must fix before merge:

- B1: the obligation that only the decision or result leaves the monitor,
  and that the event and record go only to the log. It goes in docs/AUDIT.md
  host obligations, the two wrapper doc comments or the AuditEvent header,
  and the AU-001 and AU-002 traceability rows.
- B2: reword traceability line 51 and `AuditQuery.bend:188-189` as a
  precondition. Add the log-integrity obligation, including "a decoded event
  is never re-logged", to docs/AUDIT.md.

Both are comment and document edits, so the implementation tokens are
unchanged. Following AGENTS.md, compare tokens with `0d886cb` and rerun the
tests, the proofs and OpenSpec.

Optional:

- N1, the Page delivery and same-step delivery obligations (strongly
  recommended);
- N2, `first_failed_gate` output treated as protected;
- N3, the stale Task references;
- N4, the duplicated comments;
- N5, the open-question wording.

The controller then re-pins counts from the task-6-report table, regenerates
the manifest, and merges master. If executor-rendezvous lands first, the
LAWS.bend, PROOF.bend, Tests.bend and VERIFICATION.md conflicts are resolved
by keeping both lanes' additions. All audit additions are appended blocks and
one import or call line each. The laws total and the suite total in
verification/policy-aware-audit.txt then need the combined numbers.

## Open for the change after this branch

- Section 2 (AU-004, AU-005 append half, AU-006, AU-009 queue): durable
  required audit atomic with publication, denial-append failure, verifiable
  history with trusted-head reconciliation, and the required-event queue.
  Durable storage must persist the policy recorded at decision time, or
  re-derive it from authenticated monitor state; the v1 wire format has none
  (B2). Only wrapper output may be appended.
- Grant issuance for read and export grants: who approves them (open
  question 2).
- The subject-to-DLM-principal mapping.
- The timing, scheduling and traffic channels, and the one-bit label-table
  channel (stated, not closed).
- Every host obligation, including those added by B1, B2 and N1, plus native
  host evidence per profile.
- Section 3 integration evidence with crash injection.
- A Lean `--verdict` run once the kernel toolchain is available.
