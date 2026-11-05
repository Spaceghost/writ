# Final whole-branch review: lane/portable-host-contract

Reviewer: final whole-branch reviewer (read-only except this file). Tree: `cd25c29`
(merge base with master `d56325b`). Inputs: `final-diff.diff`, the four modules
read in full, `LAWS.bend` and `PROOF.bend` diffed against the merge base, the
tests and vector file by section, the plan, the change (proposal, design,
spec, tasks), `docs/PLATFORMS.md`, the traceability file, `VERIFICATION.md`,
and every task report, review, and re-review in this directory.

**Assessment: Needs fixes before merge**

Two Important findings (I-1, I-2) must be fixed in the fix round. Both are
small. Nothing found weakens an existing law, adds a proof hole, or opens a
second route that releases output. The rest of the branch holds up under the
attack scenarios below: every one of (a) to (g) was denied or detected as the
contract requires, apart from the destination gap in (e), which is I-2.

## Findings, by severity

### I-1 (Important, must fix) `issue` binds the plan to the Frontend handle, but not the owner, the rights, or the expiry

`HostPrimitives.bend:1128-1175` (`handle_carries`, `m_plan`, `issue`). The
Task 5 fix made `issue` check that the handle exists in `frontend` and
carries exactly `plan`. The other authority fields of the new entry are still
stored without any check against that handle:

- the owner, which `HostIdentity.mint` copies from the session's caller
  (subject and token), is never compared with the handle's `subject` and
  `token`;
- `rights` is stored as given. It is never bounded by the handle's `rights`,
  yet `use` checks requested rights against exactly this value
  (`RightsNotHeld`), and every delegated child is bounded by it;
- `expires` is unbounded, with no tie to the handle's lease or epoch.

My probes (scratch `Probes.bend`, on adapter A's fixtures) gave these results:
- P1: `issue` on the worker session (subject 7, `TF.other_code()` token) for
  handle 2 (subject 7, FacadeTests token) was **accepted**.
- P1b: `issue` with rights 7 on a handle opened with rights 1
  (`FF.descriptor(7n, 1)`) was **accepted**.
- P1c: `use` on the token-mismatched root was **Granted**, with rights 7.

Publication still refuses such an entry: `DataOS.commit_from_capability`
re-resolves `F.Ref{owner, handle}` through `Frontend.checked_plan`. But
`admit_worker` on that root would emit `DeliverInputs`, which hands protected
input to a worker whose effective caller does not own the handle, and `use`
reports authority that the handle does not hold. The header (lines
1157-1172) says the plan check is defense in depth. Leaving the owner and the
rights unbound in the same check is inconsistent with the PH-005 plan-binding
fix and with the AGENTS.md rule against caller-controlled authority facts. It
is also the one place where the field trace in section "Authority-field
trace" finds a stored value that no check bounds.

Fix: in the issue gate, look up the session (`I.session_at`) and the handle
together. Require all of the following:
- `F.Handle.subject == caller_subject(session caller)`;
- `T.CodeId.equal(handle token, caller token)`;
- `T.word_subset(rights, F.handle_rights(handle))`;
- and, if the handle exposes a lease, `expires` no later than it.

Deny with one new closed reason (for example `HandleMismatch`), or with
`RightsNotHeld` for the rights clause. Add checks to HostPrimitivesTests,
vectors (PH-005-12 token mismatch, PH-005-13 widened rights), and mutants for
each clause. Update the issue comment and the PH-005 traceability row. The
vector file and its hash change, so re-record them. This changes behavior
but no law.

### I-2 (Important, must fix) Recovery does not bind the destination: a reconciled publication's destination comes from the binding's own log

`HostPrimitives.bend:236-248` (`Reconcile{invocation, digest}`, and the
sentence "so it can only repeat a recorded publication"),
`HostPrimitives.bend:305` (`Publication{invocation, digest}`), and
`HostPublication.bend:93-99, 612` (`reconcile`, and "So it can only repeat a
publication the record already holds").

Scenario (e) below: after a publication, `reconcile(invocation, digest)` is
**accepted** after the client's root was revoked, and again after a restart.
Both times it emits `Reconcile` with only the invocation and the digest. The
committed intent's output policy, label, and backend (where and under which
policy the bytes go) are not in the record and not in the effect. A binding
that "finishes or confirms" the publication therefore takes the destination
from its own durable log. That log is binding-controlled state, which makes
the destination a caller-controlled authority fact on the path that
completes a release. A corrupted or retargeted log (the PH-008 retarget
case, applied to the destination) is not detected. The two header sentences
claim more than the model gives: the record pins the artifact, but not the
publication. Task 6 records this in the traceability (PH-009 row) as
reviewed-only, but the module headers still make the stronger claim.

Fix, preferred (keeps structural exclusion (a): no `P.Effect` carries an
intent):
1. Store the committed `B.WriteIntent` (or at least its `output`, `label`,
   and `backend`) in `P.Publication` at `p_artifact`.
2. Give `reconcile` the binding's logged intent as one more fact, and deny
   `Substitution` unless it equals the recorded one field for field.
3. Keep `Reconcile{invocation, digest}` as the only effect.

That way the binding may finish only the exact intent the monitor recorded.
Add checks and a vector for a retargeted destination at reconcile, and add a
mutant for each compared field.

Minimum, if the controller keeps the Task 4 ruling: correct both sentences,
which is the Task 4 header note already planned for the fix round. Name the
missing destination binding as a host obligation in the HostPublication
header and the HostPrimitives `Effect` comment, and against task 2.3. With
this minimum, I-2 is closed only as a documented gap, not as a defense.

### M-1 (Minor) "One worker per input" holds per identity slot, not per input

`HostPrimitives.bend:77` and `:749-756` (`occupied`), and `VERIFICATION.md:38`
("one reader per input"). `same_entry` compares host, incarnation, and slot,
so two child entries delegated from one root are two "inputs". Probe P2: the
client delegates its root to the worker session twice, and both workers are
**admitted**, on both adapters, over the same handle and plan. So the same
input can have two concurrent confined readers. Publication still allows only
one of them through (the second gets `Replay` on the shared invocation).

Fix: either make occupancy compare the input's root slot or Frontend handle
(walk `parent_of` to the root; the entry's handle is already copied), or
change the wording to "one worker per identity entry" in the header, the
VERIFICATION row, and the Task 3 ruling text, and record that the PLATFORMS
"fixed confined reader" is per entry.

### M-2 (Minor) The five new laws are definitional

`LAWS.bend:68-131`, `PROOF.bend:45-58`. Each law holds by computation of an
accessor on a constructor (`Step.state(Denied{s, r}) == s`, and so on). None
of them says anything about a transition. The plan prescribed them, they
follow the `binding_denied_preserves_state` precedent, and each rationale says
plainly what it does not assert, so this is not a weakening. Under the
"tautology is a finding" standard, though, they add no guarantee beyond the
types.

Stronger laws are feasible here. In scratch I proved, with `ALL PROOFS CHECK`
and a negative control that fails (the same proof at the current revision is
rejected):
- `publish_stale_revision_emits_nothing`:
  `PublishResult.effects(publish(state, 1n+P.revision(state), ...)) == []`
  for every argument;
- `admit_stale_revision_keeps_state`:
  `Step.state(admit_worker(state, 1n+P.revision(state), ...)) == state`.

Both follow the master `issuance_stale_*` proofs: match the state, then
rewrite with `nat_eq_successor_false` inside the `_ && P.valid(...)` gate
argument. They need `nat_eq_successor_false`, which arrives with master.

Optional: add these two laws after the merge, each with a rationale.

### M-3 (Minor) The monitor clock is an unstated trust input

`now` is a parameter of `resolve`, `use`, `delegate`, `admit_worker`,
`charge`, `diagnostic`, `seal`, and `complete`, and each module calls it
"monitor time". Nothing requires it to be monotone. A clock that moves
backwards revives an expired entry for every check except `publish`, which
reads the DataOS context's clock.

Fix (comment and traceability only): list "the monitor's clock is trusted and
monotone" with the host obligations in the HostIdentity and HostPrimitives
headers.

### M-4 (Minor, already in traceability) `complete` ignores `sequence` and `status`

`HostPublication.bend:815-863`. An accepted completion is a no-op that only
advances the revision, and replays are accepted while the worker is
`Running`. In scenario (d), a completion was still accepted after
publication. Task 6 documents this in the PH-010 row. The planned header note
covers the rest.

### M-5 (Minor) No session close or unbind transition

HostIdentity has no way to end a session. Sessions persist until `restart`.
Ids are never reused within an incarnation (`1 + max_session`), so this
cannot cause id reuse. But a native session that ended stays "bound", and
"session retired" (scenarios (b) and (c)) has no model counterpart: only
entry retirement and restart exist.

Fix: record this as reviewed-only in the PH-002 and PH-010 rows, and as a
section 2 or later item.

### M-6 (Minor) The client-session delegable flag comes from the target

`HostPrimitives.bend:1002-1008`. For `ClientRole` the evidence's `delegable`
flag is used as given, so a hostile target can make every client session
delegable. `Role` cannot express a monitor-decided non-delegable client
session, which design.md's "a proxy endpoint alone is not nondelegable" may
need. The impact is bounded: delegation still requires the same subject and
narrower rights and lifetime.

Fix: `ClientRole{delegable: Bool}`, combined with the evidence flag by AND.

### M-7 (Minor) `quiesce` after `restart`

`HostPublication.bend:732-741`. A worker revoked by `restart` must be
quiesced with "retired generation" = input generation + 1, although restart
advances no generation. `quiesce` also never compares incarnations. This is
harmless, but document it beside `retired_generation`.

### M-8 (Minor, carried from the Task 6 review) design.md does not state the implemented rulings

design.md does not state the implemented rulings (holder is the session,
monitor-owned profiles, roles, and delegability, one worker per entry,
non-delegable workers, single publication route, plan binding at issue and
publish). Add one short paragraph under the section 1 sentence.

## Scenario outcomes (a) to (g)

The scenario code is scratch (`Scenarios.bend`, `Probes.bend` in my session
scratchpad, on a copy of this tree), built on the HostConformanceTests chain
helpers. Every scenario ran on both adapters. Each "denied" result also
asserted full primitive-state equality with the input (`PT.state_equal`).

| | Scenario | Outcome |
| --- | --- | --- |
| a | Restart, then the client is re-bound (it reuses id 1) and presents its pre-restart root reference; a new session reusing the old worker's id 2 presents the old input reference | `use` denied `Identity.StaleIncarnation`; reused id 2 with the old input denied `StaleIncarnation`; admission with the old input denied `StaleIncarnation`; a pre-restart completion on the reused id denied `StaleIncarnation`; `charge` of the pre-restart worker (now `Revoked`) denied `WrongPhase`; the old reference with the new incarnation guessed, on another session of the same subject, denied `NotHolder`; the re-issued root resolves for its new holder. **Pass.** |
| b | Worker admitted, its input retired (`revoke`), then a completion with the old generation | Old generation denied `Identity.Retired`; the guessed retired generation (2) denied `Retired`; a completion through the client's live root denied `UnknownWorker`; after restart (the session table dropped) denied `StaleIncarnation`. HostIdentity has no "session retired" transition (M-5). **Pass.** |
| c | Two-deep chain root(client) -> proxy(session 3) -> narrow(worker session); the middle is revoked before the leaf resolves | `revoke(proxy)` returns exactly one `StopEffects` for the leaf worker; the leaf and the middle resolve `Retired`; the root still resolves; the leaf's completion is denied `Retired`; the leaf worker re-delegating denied `NotDelegable`. **Pass.** |
| d | Publication replayed for the same invocation, with the original session and with the post-commit session and ledger at the advanced expected revisions | Both refused `Replay`, returning the supplied state, session, and ledger. A completion with an arbitrary sequence is still accepted, as a no-op (M-4). **Pass.** |
| e | Recovery with a recorded publication after its destination authority changed (root revoked; restart) | `reconcile` is **accepted** in both cases with `Reconcile{invocation, digest}` and no destination; another digest denied `Substitution`. **Gap: I-2.** |
| f | Two adapters, one of which reports a target lacking the worker family (or a control, or one unmediated route) | Mutating adapter B's report to families 29 (worker bit cleared), or controls without `no_inherited_routes`, or its route to `mediated: False`, kills `HostConformanceTests` at `PH-009-1 ... on both adapters`; dropping the worker family on both adapters also fails (the expected lines are fixed). In the code, B's admission is `UnsupportedFamily` (step 8). The profile is monitor configuration: no report field can add or remove a profile. **Pass (divergence is detected).** |
| g | Wire message with a correct declared length whose body carries context words | `[1,1,7, 7,4242,99,6, 1,7,7]` decodes to a plain `Use` description and resolves to `ForeignHost`; a `Use` naming subject 99 in its claim resolves with the owner's caller (subject 7); the correct reference plus the owner's subject, presented on another session, denied `NotHolder`; one smuggled trailing word is `TooLong` past the cap, and `BadLength` on a Release. No message field can carry a Context, Ledger, Binding, plan, or caller. **Pass.** |

## Section 1: laws and contribution rules

- `git diff d56325b -- LAWS.bend PROOF.bend`: additions only, with 0 removed
  lines. LAWS gains four imports and five laws; PROOF gains three imports and
  five `{==}` proofs. No existing law or proof changed.
- Every new law has a rationale above it and the same text in its module's
  header (HostIdentity:120-126, HostPrimitives:156-165, HostPublication:138-152).
  All are definitional (M-2). None is a vacuous implication, and none states
  more than it proves.
- No `unsafe`, no `%` cast or rewrite, no proof hole, and no list indexing in
  the four modules or the vectors. Every lookup is a counted match
  (`*_at`/`count_*`), and the unreachable `Many*` branches deny.
- PH-001, what a hostile adapter can do:
  1. Construct `P.Effect` or `H.Publish` values, since Bend types are public.
     This is reviewed-only; the binding must execute only effects the monitor
     returned.
  2. Report false facts: `TargetReport`, `Inventory`, `ArtifactFact` writer
     counts and object, `QuiescedFact`, `CompletionFact.session`,
     `SessionEvidence` (caller, origin, delegable). Each is compared with
     monitor state and only gates, except that the evidence caller is taken
     as authenticated and the client delegable flag passes through (M-6).
  3. Supply the inputs the monitor is trusted to pass correctly: `Role`,
     `frontend`, `now`, and `publish`'s session, ledger, candidate, and
     context.

  What it cannot do: name a profile, controls, families, a quota, a plan, a
  commit result, or a `WriteIntent` (no parameter has those types), or obtain
  a `Publish` from any transition other than `publish` step 7 after
  `DataOS.commit_from_capability`. `native_write_offered` has no accepting
  branch. The only gaps are I-2 (the reconcile destination) and items 1 and 3
  above, which are stated as host obligations.
- Revalidation at use: `use`, `admit_worker`, `charge`, `diagnostic`, `seal`,
  `publish`, and `complete` re-resolve the identity entry, so holder,
  incarnation, generation, and expiry are checked at every use. `publish`
  also rechecks the plan (entry = session = intent), replay, and the
  Frontend capability, epoch, rights, and reader through DataOS. Admission
  does not recheck the Frontend handle (an explicit plan ruling: inputs go to
  a confined worker, and the recheck is at publication). The identity table
  has no link from a Frontend close or revocation to `retire` (open item).

### Authority-field trace

Every field of every request and fact type, and where it is checked:

- **`W.Use`**: the ref goes through `resolve`; `rights` must be a subset of
  the entry's rights; `operation` must map to a right within the requested
  rights; `claimed_subject` is never read.
- **`W.Delegate`**: the ref goes through `resolve`; `rights` must be a subset
  of the parent's; `lifetime` is capped by the parent's expiry; the target
  must be bound and have the same subject.
- **`W.Complete`**: the ref goes through `resolve`. `sequence` and `status`
  are never read (M-4).
- **`SessionEvidence`**: `caller` is stored as authenticated (host
  obligation); `origin` must name a bound session; `delegable` may narrow a
  ClientRole session and passes through otherwise (M-6).
- **`Role`**: a monitor input. The profile id must be configured.
- **`TargetReport`, `Inventory`**: compared with the bound profile; nothing
  is stored.
- **`ResourceRequest`**: `worker` is looked up and its input re-resolved;
  `amount` is bounded by the quota limit, and only the accepted amount is
  stored.
- **`Diagnostic`**: `public` gates only.
- **`ArtifactFact`**: `object`, `version`, and `digest` are stored at
  `seal`. Later facts are compared with them, and the digest is compared
  with the committed `ArtifactId` at publish. The writer counts gate.
- **`QuiescedFact`**: `generation` is compared with the input generation
  + 1.
- **`CompletionFact.session`**: a transport fact, checked through `resolve`.
- **`reconcile(invocation, digest)`**: compared with the record.
- **`issue(frontend, handle, plan, rights, expires)`**: `plan` is compared
  with the handle. `rights` and `expires` are **stored unchecked**, and the
  owner is not compared with the handle (I-1).
- **`publish`**: every input is a monitor record, checked by DataOS.

## Section 3: cross-task consistency

- The rules (holder is the session; monitor-owned profiles, roles, and
  delegability; one worker per slot; non-delegable workers; slots never
  reused; single publication route; plan binding at issue and publish;
  revoke, then quiesce, then reclaim) agree across:
  - the module headers;
  - the traceability tables and requirement summary;
  - tasks.md box notes 1.1 to 1.4;
  - the VERIFICATION rows;
  - the PLATFORMS sentence.

  There are three exceptions. "One reader per input" (VERIFICATION:38)
  overstates the per-slot rule (M-1). The two "can only repeat" sentences
  overstate recovery (I-2). design.md states none of the rulings (M-8).
- Stale strings, grepped across the tree outside the records:
  - "about 350 lines" and "three new laws" appear only in the plan document
    (historical; acceptable).
  - "subject alone" appears only in HostIdentity:33, in the correct form
    ("not the subject alone").
  - "Done{" matches only `writfs/Host.bend`, which is unrelated.
  - "caller supplies the profile" has no match.
  - The intermediate counts 1173, 1179, 1140, `70efda96`, "27 vector", and
    "30 vector" appear nowhere outside the records.
- The planned Task 4 header notes (`complete` ignores `sequence` and
  `status`; the recovery record has no destination) are not yet in
  `HostPublication.bend`. The fix round plans to add them; with I-2 they
  become a code fix or a corrected claim.

## Section 4: records

- Removal-map spot checks: I reran three mutants from each of two maps, each
  as a one-site replacement in a scratch copy. All six were killed:
  - Task 2, "resolve holder" (forced true): killed by `PH-003 another session
    presenting A's slot and generation denied NotHolder`, as mapped.
  - Task 2, "delegate subject": killed by `PH-005 delegation to another
    subject's session denied SubjectChanged`, as mapped.
  - Task 2, "retire no cascade": killed, but first by `PH-004 retire advances
    the generation and clears live` (through `I.valid` of a live child under
    a retired parent), not the mapped `retiring the parent retires the
    child`. This is consistent with the report's note that earlier checks
    may now fail first.
  - Task 4, "publish: replay accepted": killed by `PH-009 a second
    publication of the same invocation denied Replay with no second spend`,
    as mapped.
  - Task 4, "describes: digest ignored": killed by `PH-008 a path retargeted
    to another digest denied Retargeted`, as mapped.
  - Task 4, "reconcile: digest check dropped": killed by `PH-009 reconcile
    with a different digest denied Substitution`, as mapped.
- Fresh runs on this tree:
  - `bend Tests.bend` (embedded runtime): exit 0, 1182 PASS, 0 FAIL. The
    output is byte-identical to `verification/tests-js.txt`.
  - Native CPU (`-o`, then `+RTS --threads 4 --gpu off`): exit 0,
    byte-identical to `verification/tests-native.txt` (SHA-256 `120108e0…`
    for both).
  - The `VECTOR PH-` lines (33) are `cmp`-identical to
    `verification/portable-host-vectors.txt`, SHA-256
    `fb85d405c08e9ad46727ffe0d69bf9f7d5cc241281226d8c1740a4a9f094d30d`, on
    both backends.
  - `bend PROOF.bend`: `ALL PROOFS CHECK`, 11 laws.
  - OpenSpec 1.16.0 strict: 44 passed, 0 failed.
- Claims:
  - Task 6's VERIFICATION and traceability text claims no Lean verdict (it
    records the `--verdict` refusal), no GPU evidence (it says CPU with
    `--gpu off`, not a GPU test), and no Genode CI run at the new count (the
    report says it was not executed).
  - Per-module counts are 63 + 92 + 206 + 39 = 400; I checked them against
    the summaries in the fresh output.
  - I found no claim that the tests do not back, other than the two overclaims
    under I-2 and M-1.

## Section 5: merge readiness

Must fix before merge:
1. I-1: bind owner (subject and token), rights, and expiry at `issue` to the
   Frontend handle, with checks, vectors, and mutants. Re-record the vector
   file and its hash.
2. I-2: bind the recovery destination (the preferred fix), or at minimum
   correct the two "can only repeat" sentences and name the gap in both
   headers and against 2.3.
3. The fix-round items already planned:
   - merge master, resolving LAWS.bend, PROOF.bend, and VERIFICATION.md by
     keeping both sides (no shared law; imports are a union);
   - refresh `verification/openspec-validation.txt` (stale at 37 items on
     this base; 44 live) and append `verification/kernel-verdict.txt`;
   - add the Task 4 header notes as comments.

Then the controller re-pins the counts from the task-6-report table. Merged:
1414 plus the checks I-1 and I-2 add; 17 laws, or 19 if the M-2 laws are
added. After that the controller regenerates `verification/source-sha256.txt`
and recaptures the 1414-plus captures on the merged tree.

Optional (fix round or follow-up): M-1 (occupancy per root or handle, or
reworded), M-2 (two transition-level stale-revision laws, proved in scratch),
M-3 (clock obligation), M-5 (session close as reviewed-only), M-6
(`ClientRole{delegable}`), M-7 (quiesce comment), M-8 (design.md rulings
paragraph), and the two historical 1014 mentions the Task 6 review noted.

## What remains open for the change after this branch (section 2)

- 2.1: native feature and profile negotiation that denies protected work when
  a required native control is absent. The model compares only reported
  controls.
- 2.2: native adversarial probes connected to each target's effect inventory:
  - routes removed or mediated before delivery;
  - quota and output-channel enforcement;
  - fast-path unavailability;
  - message framing and `Malformed` handling;
  - authenticated session evidence, including inheritance and transfer
    reporting;
  - the trusted `Role`, `frontend`, and clock inputs.
- 2.3: mutable-alias elimination, current authority, and durable publication
  under revocation, crash, and stale asynchronous completion races:
  - DMA/IO quiescence before `QuiescedFact`;
  - durable record, session, and ledger together;
  - per-sequence completion matching (M-4);
  - the reconcile destination, if I-2 is closed only in documentation.
- 2.4: per-target runtime, kernel, driver, and configuration evidence, with
  GPU isolation evidence for PH-014. There is no GPU run, and the CPU run is
  not a GPU test.
- 2.5: traceability only for evidence actually obtained.
- Wiring not yet done:
  - HostBinding as a producer of HostIdentity session evidence;
  - the Genode channel's move to the HostWire schema;
  - a link from Frontend handle close or revocation to `HostIdentity.retire`;
  - session close (M-5).
- Not qualified: PH-012 (decision half only), PH-013 (no model check), and
  the native part of PH-014. There is no Lean `--verdict` for any of the five
  laws.
