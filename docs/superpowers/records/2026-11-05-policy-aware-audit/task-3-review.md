# Task 3 review: event policy from authoritative data and control influences

Reviewer: task reviewer (information flow and proofs). Range reviewed:
8650a7c..e705619 on `lane/policy-aware-audit`.

Inputs read:
- task-3-brief.md, task-3-report.md and mutants/task-3.tsv.
- The review package diff.
- The plan's Global Constraints and shared design.
- task-1-review.md, task-1-rereview.md and task-2-review.md.
- AuditEvent.bend and AuditTests.bend as they stand.
- From Dlm.bend: `Label`, `join`, `flows`, `maximal_restriction` and `fixture`.
- From Transfer.bend: `ObjectVersion.equal`. From Backplane.bend:
  `binding_find` and the `WriteIntent` label at :247. From DataOS.bend:
  `commit_from_capability`.
- LAWS.bend and PROOF.bend as changed, and AGENTS.md.

## Verdicts

1. Spec compliance: **NEEDS_FIXES**. Four influence-derivation mutants
   survive (I2, I3). The brief's acceptance line says "every
   influence-derivation mutant is killed", and the fail-closed duplicate rule
   is pinned only where the duplicate sits at the head of the table.
2. Information flow and code quality: **NEEDS_FIXES**. The required
   stream-membership finding (I1) is confirmed by a probe. There are also
   the I2 and I3 test gaps and three minor items.

## Findings, by severity

### Important

**I1 (required, controller ruling). For an early-denied admission, the
object names in the caller's unchecked plan decide which owners' streams the
event joins.** Locations: AuditEvent.bend:851-856 (`admission_policy` always
includes `decision_influences(labels, plan)`), :944-945 (`event_owners`) and
:342 and :943 (the comments saying that `event_owners` is stream membership).

- Confirmed. In my probe, Mallory (subject 2) submits a Stale-denied plan
  that names Bob's object 11, under `AuditTests.bob_labels()`. The event is
  `DeniedFor{Stale}` with `ScopeNotRead{}`, and `event_owners` of its policy
  contains Bob.
- A plan that names 11 and 12 under `shared_labels()` puts Mallory's
  early-denied event in both Bob's and Alice's streams.
- So any caller can place an event in any owner's stream by naming that
  owner's objects in a plan that no grant ever vouched for. Visibility is
  still narrowed by the requester influence, but stream membership is not.
  Under the design's stream model that is caller control over another
  owner's stream (noise, and an input to Task 4's stream walk).

Fix. Keep the policy as it is: it is outcome-independent, the law
`audit_outcome_never_lowers_policy` stands, and the extra plan-object
influences only narrow visibility. Separate stream membership from the
influence list:

1. Add this to AuditEvent.bend after `event_owners`. I prototyped it in a
   scratch copy: it compiles, `bend AuditTests.bend` still gives 191 checks
   and `bend PROOF.bend` gives `ALL PROOFS CHECK`.

   ```
   # Stream membership by scope. An admission event with `ScopeNotRead{}` was
   # denied before any monitor grant vouched for the plan, so the objects the
   # caller named must not choose which owners' streams it joins: it joins the
   # requester's own stream only (owner Top when the subject cannot name a DLM
   # principal, which is nobody's stream). Its policy is unchanged and still
   # carries every influence, so visibility is never widened. Every other event
   # joins the stream of each owner among its influences.
   def streams_for(scope: Scope, +subject: Nat, policy: EventPolicy) -> Owners:
     match scope:
       case ScopeNotRead{}:
         Owned{Influence.owner(requester_influence(subject)), NoOwners{}}
       case ScopeRead{_, _, _, _, _, _}:
         event_owners(EventPolicy.influences(policy))

   # Public entry point. The owners whose streams a stored event belongs to,
   # from the record's own projected scope and authenticated subject.
   def event_streams(r: Recorded) -> Owners:
     match r:
       case Recorded{event, policy}:
         match event:
           case EventRecord{_, _, _, subject, _, scope, _, _}:
             streams_for(scope, subject, policy)
   ```

   It reads only the stored record: the projected scope (from the library's
   decision) and the authenticated subject. It reads no request field.
2. Make `event_streams` the public entry point for stream membership.
   - Move `event_owners` to the helper list in the header (:204-220).
   - Reword the comments at :342 and :943 so that `event_owners` is "the
     distinct owners among the influences". `event_streams` is the stream
     rule.
   - Add a sentence to the header's "Event policy" paragraph (:78-108).
   - Note in the report that this refines the plan's "Streams and ownership"
     ruling for ScopeNotRead events. Task 4 must use `event_streams`.
3. Add checks in `event_policy`, each pinned by a mutant:
   - "AU-002 an early-denied (ScopeNotRead) event joins only the requester's
     stream, whatever objects the plan names". Use Mallory's Stale plan
     naming 11 and 12: `event_streams` is exactly `Owned{mallory()}`.
   - "AU-002 a ScopeRead denial joins every influence owner's stream". Use
     the Origin denial of `bob_audited`: `event_streams` equals
     `event_owners` of its influences and contains Bob.
   - "AU-002 an early-denied event from a subject of 2^32 joins only Top's
     stream".
   - Mutants to kill: the ScopeNotRead arm returns `event_owners(...)`; the
     ScopeNotRead arm uses subject 0; the ScopeRead arm returns the
     requester only.

**I2. Duplicate label entries fail closed only when the first matching entry
is at the head of the table, or for the first source.** Locations:
AuditEvent.bend:667-686 (`lookup_step`/`label_lookup`, which are correct)
and AuditTests.bend:1871-1875 (`duplicated()` and `conflicting()` both put
the duplicate at the table head, and `bob_plan` has one source).

The code is correct, but the brief's rule "a duplicate entry yields maximal
restriction" is not pinned. Two of my mutants survive with `Audit: 191
checks passed` and `ALL PROOFS CHECK`:
- X2: `label_lookup` detects a second match only when the head matches.
  Otherwise it takes the first later match.
- X4: `objects_influences` applies the ambiguity check to the first source
  only. Every later source takes the first match.

Under either mutant, a table that names Bob's object twice behind some other
entry, or a duplicated second source, gives an owner's ordinary label in
place of the maximal restriction.

Fix. Add two checks to `table_fail_closed`, and kill X2 and X4 in the
mutation table:
- (a) A table `Labelled{dest 20 (Alice), Labelled{11 (Bob), Labelled{11
  (Bob), NoLabels}}}`, with the duplicate behind an unrelated head: the
  event has `maximal_data()`, has no `data_of(bob())`, and is releasable to
  no fixture sink.
- (b) `shared_plan()` with `shared_labels()` plus a second, identical entry
  for Alice's object 12 (the second source): the influences hold the maximal
  restriction at the second source's position. Use `source_influences`
  equal to `[data_of(bob()), maximal_data()]`.

**I3. Exact version matching and the commit context influences are
unpinned.** Two more of my mutants survive with 191 checks and
`ALL PROOFS CHECK`.

X7, at AuditEvent.bend:681-686: the lookup compares the object id only and
ignores the version. Every fixture table uses distinct ids, so the mutant is
invisible. It fails open:
- A label table holding only version 3 of object 11 would supply version 3's
  label (possibly a lower one) for a plan that names version 4.
- The correct result is the maximal restriction, because version 4 is
  missing.

Fix: add the check "AU-002 a label entry for another version of the same
object does not match". Use a table with only `ObjectVersion{11, 3}` (Bob's
label) and `bob_plan()` (version 4). The source influence is
`maximal_data()`, and the event is releasable to no fixture sink.

X6, at AuditEvent.bend:871: `commit_policy` drops
`context_influences(labels, transfer)`. This is one of the accepted extra
influences. The mutation standard still requires every influence on the
list to be pinned, and on the admission side the same influence is pinned
(P17, P18 and P20).

Fix: add a commit check. The simplest form compares the exact
`commit_policy_of(FT.context(), 7n)` influence list with `influences_eq`, in
list order. Alternatively, label the transfer context's source policy object
with a third owner, and require that owner as a control influence of the
commit event.

### Minor

**M1. The subject-numbering assumption is not stated in the module.**
Location: AuditEvent.bend:755-776 (`requester_label`, `requester_checked`,
`requester_influence`).

The report records the gap (concern 2), and the controller has accepted it
as a Task 6 gap. The code comment covers wrap and unregistered subjects
only. It does not say that `Named{subject}` assumes frontend subjects are
numbered the way DLM principals are.

Fix: add one sentence to the `requester_influence` comment and to the
header's "Event policy" paragraph: "Assumes the monitor numbers frontend
subjects as DLM named principals; no subject-to-principal mapping exists
yet (recorded gap for Task 6)."

**M2. In the requester's own stream, the visibility of an early-denied event
still depends on the label-table entries for objects the caller named.**

Probe: the context's objects and object 50 are labelled Mallory-readable,
and object 60 has no entry. Mallory's Stale-denied plan naming 50 is
releasable to her sink 7, and the one naming 60 is not. Each request
therefore gives the requester one bit of the table: whether a named object
carries a label her sink satisfies.

This is fail-safe, never widening, and low-value. It cannot be removed
without making the policy outcome-dependent, which would conflict with
`audit_outcome_never_lowers_policy`.

Fix (comment only): state it next to the I1 stream rule, and carry it as a
named observation into the Task 4 brief and the Task 6 traceability gaps,
next to the timing channel.

**M3. The module does not record the "channel note" from report concern 7.**
After I1 the note becomes the M2 text. Put it in the header rather than
only in the report.

### Checked and found sound (no finding)

- **No label is lowered.**
  - `grep` finds no `meet`, `Meet`, `public_untrusted`, subtraction or
    clear in AuditEvent.bend.
  - The only `Bits64` operations are `join`, `zero` (as the unit of a join)
    and `subset`.
  - The fail-closed cases all use `maximal_influence`, which is owner
    `Top{}` and `D.maximal_restriction()`.
  - No public entry point takes an `Influences` argument from a caller.
    `Influences.cons` and `Influences.append` are used only inside
    derivations.
- **Each owner is a separate entry.** `objects_influences` emits one element
  per manifest entry. `binding_influence` joins only the binding's own two
  labels (the WriteIntent label, Backplane.bend:247). Checks pin that there
  is no merged label and that both owners stay.
- **Fixtures** give Alice, Bob and Mallory distinct labels
  (`owner_label(p)`). The requester label has the same shape as the owner
  label, which is correct.

## Verdict 1: spec compliance (detail)

Each influence in the brief, traced to its source. All are read at event
time inside the wrapper call.

| influence (brief) | code | source | request field? |
|---|---|---|---|
| requester's label | `requester_influence(caller_subject(caller))` and `requester_influence(OS.subject(ref))` | frontend-authenticated subject (controller ruling: 4th argument) | no; the token is never read |
| every source's policy | `source_influences` and the control copies in `decision_influences` | monitor label table, by the plan's object names | object names come from the plan. For an admitted, Read, Origin or Payment event they are write-grant-vouched. For an early denial they are not: see I1 for streams and M2 |
| destination's label | `destination_influence` and its control copy | label table | as above |
| binding's labels | `binding_part(B.binding_find(bindings, N.Session.request(session)), owner)` | facade context bindings and the monitor-owned negotiated session | no |
| label table entries | `label_lookup`, which walks the whole table | monitor `labels` | no |
| extras (accepted) | `context_influences`, origin bits in `sources_secrecy` and `sources_untrusted`, the requester on commit | authoritative `T.Context` | no |
| secrecy and untrusted | `context_secrecy` and `context_untrusted` | `T.Context.sources` | no |

- Neither `admission_policy` nor `commit_policy` takes the decision or the
  result. `audited_admit` and `audited_commit` build the policy without
  branching on the outcome. This is pinned by the law and by the check "a
  rejected commit has the accepted commit's policy".
- Fail-closed cases:
  - missing entry: P10, rerun, killed;
  - duplicate entry: P13, rerun, killed (head position only; see I2);
  - conflicting entry, empty table, subject 2^32, unregistered subject and
    no binding: P28, rerun, killed;
  - epoch: each has a named check.
- Laws: there are 23 (`grep -c '^law ' LAWS.bend`).
  - `audit_failed_influence_withholds` is a real statement. Its hypothesis
    is the failed flow of `i`, and its conclusion covers any
    `before ++ i :: after`. The proof is by induction on `before`, with
    `Equal.sym` rewrites and the typed helper `audit_bool_and_false_right`
    (two `{==}` cases). It has no hole and no `unsafe`.
  - `audit_outcome_never_lowers_policy` quantifies plan, context, labels,
    subject, token, diagnostic and event id, so it holds for every decision.
    The proof is `{==}`, and it is not trivial: W1 breaks it, rerun, failing
    at `Laws.audit_outcome_never_lowers_policy`. So does my X3 (requester
    dropped on denial).
  - Both rationales are above each law in LAWS.bend and in the module
    header's "Laws" paragraph (AuditEvent.bend:239-252).
- Task 1 obligations:
  1. The requester label is on every admission event. Check: "Mallory's
     denied request is withheld from ... sink 3 ... released to sink 4".
     P21 (rerun) and my X3 are killed.
  2. The binding labels are on every commit event, never below the output
     label: `D.join(source_label, destination_label)` equals the
     WriteIntent label, plus the transfer context's bit sets. P25 and P28
     were rerun and are killed. The release check uses the
     eight-principal SYNTHETIC snapshot.
- `Tests.bend` is not in 8650a7c..e705619. Against master it has only the
  two added lines from Task 1.
- LAWS.bend and PROOF.bend changes are additions only: master..e705619 shows
  150 lines added and 0 removed in LAWS.bend, and 53 added and 0 removed in
  PROOF.bend.
- Touch list: the task range changes AuditEvent.bend, AuditTests.bend,
  LAWS.bend, PROOF.bend, tasks.md (box 1.2 only) and the record directory.
  No count pin changed.
- Gaps against the brief: I2, I3 and I1's stream rule.

## Verdict 2: information flow and code quality (detail)

My own mutants (scratch copies under
`scratchpad/policy-aware-audit-review-t3/own/`):

| id | mutation | result |
|---|---|---|
| X1 | `influences_flow` skips the last element | killed: "Mallory's denied request is withheld from ... sink 3"; law fails at `Laws.audit_failed_influence_withholds` |
| X2 | duplicate detected only when the head entry matches | **survives** (191 checks, proofs check), I2 |
| X3 | requester influence omitted on a denial | killed: the Mallory check; law fails at `Laws.audit_outcome_never_lowers_policy` |
| X4 | duplicate detected only for the first source | **survives**, I2 |
| X5 | identical duplicates tolerated (ambiguous only when the owners differ) | killed: "two identical label entries ..." |
| X6 | `commit_policy` drops `context_influences` | **survives**, I3 |
| X7 | lookup ignores the version (partial match) | **survives**, I3 |

Code quality:
- Helpers are named. Fail-closed arms are explicit. Comments explain edge
  direction and failure behavior.
- `releasable` states that it is a release-policy check, not a grant.
- The `Data` to `DataEdge` rename is explained.
- The typed helper proof stays a helper (controller ruling).

## What I ran (Bend 2.0.39, `BEND_NO_TELEMETRY=1`)

- `bend Tests.bend` ends with `ALL LIBRARY TESTS PASSED`, exit 0. It prints
  1619 `^PASS(:| )` lines and 0 FAIL lines.
- `bend PROOF.bend` prints `ALL PROOFS CHECK`, exit 0, with 23 laws.
- `bend AuditEvent.bend --check-only` exits 0.
- I reran eight of the implementer's 64 mutants from mutants/task-3: P10,
  P13, P21, P25, P28, R1, R2 and W1. Before each run I confirmed that its
  AuditTests.bend, LAWS.bend and PROOF.bend equal the tree's and diffed its
  AuditEvent.bend.
  - All eight are killed by the reported check.
  - R1, R2 and W1 also fail the reported law.
- My mutants X1 to X7 are in the table above.
- I wrote and ran a probe (`Probe.bend`, in scratch only) for I1 and M2,
  and prototyped the I1 fix in a scratch copy:
  - The probe confirms the leak on the unfixed tree.
  - On the fix copy, both Mallory events give `event_streams` exactly
    `Owned{mallory()}`, and the Origin (ScopeRead) denial still joins Bob's
    stream.
  - On the fix copy, `bend AuditTests.bend` gives 191 and `bend PROOF.bend`
    gives `ALL PROOFS CHECK`.
- Not run: `--verdict`, the native build, the GPU path and OpenSpec
  validation (Task 6). This is a JS/interpreter run only.
