# Task 4 report: sealing, publication with recovery, and revocation (tasks.md 1.3, second half)

Status: DONE_WITH_CONCERNS (one brief value adjusted to HostIdentity's actual
reason, and several interpretations; all listed under Concerns).
Implementer, lane `lane/portable-host-contract`.

## Delivered

- `HostPublication.bend` (new, 826 lines; pre-approved by the brief because
  `HostPrimitives.bend` was already 1267 lines). It imports `HostPrimitives`
  and holds families 3 to 5: `seal`; `publish`, `reconcile`; `revoke`,
  `restart`, `quiesce`, `reclaim`, `complete`. Its header gives authority,
  each family's order, the second-route argument, recovery, revocation order,
  host obligations, failure behavior, the law rationale, and the public
  entry points. Types defined here: `ArtifactFact`, `QuiescedFact`,
  `CompletionFact`, `PublishEffect` (`Publish{intent}`), `PublishResult`
  (`Published{state, commit, effects}` | `Refused{state, session, ledger,
  reason}`), and the helper record `Attempt`.
- `HostPrimitives.bend` (now 1520 lines), keeping one section per family:
  - types: `Sealed`/`Seals` and `Publication`/`Publications`; `State` gains
    `seals` and `publications` (written only by `seal` and `publish`);
    `Effect` gains `Reconcile{invocation, digest}`, `StopEffects{worker}`,
    and `Reclaim{worker}` (no publish, recall, or erase variant); `Error`
    gains `LiveWriter`, `NotSealed`, `Retargeted`, `ArtifactMismatch`,
    `CommitRejected`, `Replay`, `Substitution`, `Unrecorded`, `NotQuiesced`
    (with `Error.equal` arms);
  - `valid` gains two clauses: every sealed record names one worker and no
    worker is sealed twice; every invocation is recorded once;
  - family 1 gains `issue` (wraps `HostIdentity.mint`) and `delegate` (wraps
    `HostIdentity.delegate`), both gated, both `Identity{reason}` on a
    HostIdentity denial, no effect;
  - the family 3 to 5 section headers point to HostPublication; the header
    text is updated (families list, Effect bullet, authority, invariants,
    public entry points). The unused `Backplane` and `DataOS` imports moved
    to HostPublication.
- `HostPrimitivesTests.bend`: 99 new checks in nine new requirement groups
  (`wrapper_checks`, `seal_checks`, `publish_checks`, `commit_checks`,
  `reconcile_checks`, `teardown_checks`, `completion_checks`,
  `publication_gate_checks`, `publication_valid_checks`); 203 in all; summary
  line `HostPrimitives: 203 checks passed`. New imports: HostPublication,
  FacadeTests, BackplaneTests, NegotiationTests (fixtures reused by import),
  and Backplane, Ledger, Negotiation, DataOS.
- `LAWS.bend`, `PROOF.bend`: two laws and two `{==}` proofs, additions only.
- `openspec/traceability/portable-host-contract.md`: module-table row 1.3
  now names both modules and all four laws; a new section "Primitive
  interfaces, families 3 to 5" with PH-001, PH-008 (both scenarios), PH-009
  (both scenarios and replay), PH-010 (both scenarios), the family 1
  wrappers, the gate, and the laws; all 99 new names appear exactly once
  there. Four stale "Task 4" mentions in earlier rows now name
  `HostPublication.publish`/`revoke`.
- `tasks.md`: box 1.3 checked, citing both modules and both test groups;
  header line now says 1.1 to 1.3.
- `Tests.bend`: unchanged (the tests are in the existing HostPrimitives
  module). No count pin touched; no file outside the touch list.

## Family 3: sealing (PH-008)

`seal(state, rev, fact: ArtifactFact, now)`: gate (StaleRevision), exactly one
worker (UnknownWorker), `Running` (WrongPhase), the input re-resolved on the
worker's session at `now` (Identity), no earlier sealed record (WrongPhase),
zero CPU writers, writable mappings, and device writers (LiveWriter). It
records `Sealed{worker, object, version, digest}` exactly; no effect.
Checks:
  - `PH-008 a seal with zero writers records the exact object, version, and digest with no effect`
  - `PH-008 a seal with one CPU writer denied LiveWriter`
  - `PH-008 a read-only seal with one writable mapping left denied LiveWriter`
  - `PH-008 a seal with one device writer denied LiveWriter`
  - `PH-008 a seal for a worker never admitted denied UnknownWorker`
  - `PH-008 a seal from a revoked worker denied WrongPhase`
  - `PH-008 a seal after the worker's input was retired denied Identity Retired`
  - `PH-008 a second seal for a sealed worker denied WrongPhase and the record is not replaced`
  - `PH-008 order: the once-only seal precedes the writer counts`
  - `PH-008 order: the worker's phase precedes the writer counts`

## Family 4: publication (PH-001, PH-008, PH-009)

`publish(state, rev, worker, current, session, expected_session,
expected_ledger, ledger, candidate, context, expected_frontend)`, fixed order:
1. gate: StaleRevision;
2. a sealed record for the worker: NotSealed;
3. `current` names the sealed worker, object, version, and digest
   (Retargeted), then zero writers of all three kinds (LiveWriter);
4. the worker's input re-resolved through `HostIdentity.resolve` on its
   session at the DataOS context's negotiation time (Identity{reason}), then
   the worker `Running` (WrongPhase);
5. the negotiated plan's invocation not in `publications`: Replay;
6. `DataOS.commit_from_capability(session, ..., F.Ref{resolved owner, entry
   handle}, expected_frontend, context)`; `Rejected` gives CommitRejected
   with the input session and ledger;
7. `Committed`: the intent's `ArtifactId` must be the sealed digest, else
   ArtifactMismatch with the committed session and ledger discarded and the
   inputs returned.
Only then: `Publication{invocation, sealed digest}` recorded, revision +1,
`Published{state, Committed{...}, [Publish{intent}]}`.

Checks (accepted, current artifact, phase, clock):
  - `PH-009 a publication through DataOS.commit_from_capability emits exactly one Publish of the sealed digest and spends the ledger once`
  - `PH-009 a publication before any seal denied NotSealed`
  - `PH-009 another worker's sealed record does not seal this worker's publication: denied NotSealed`
  - `PH-008 a path retargeted to another object denied Retargeted`
  - `PH-008 a path retargeted to another version denied Retargeted`
  - `PH-008 a path retargeted to another digest denied Retargeted`
  - `PH-008 a current fact naming another worker denied Retargeted`
  - `PH-008 a writable mapping reappearing before publication denied LiveWriter`
  - `PH-008 order: the retarget check precedes the writer counts`
  - `PH-009 a publication for a worker not Running denied WrongPhase`
  - `PH-009 order: the writer counts precede the worker's phase`
  - `PH-009 a publication at the input's expiry on the DataOS context's clock denied Identity Expired`

Checks (commit, artifact, revocation before authorization, replay):
  - `PH-001 a publication whose capability registry was revoked denied CommitRejected with the session and ledger returned`
  - `PH-001 a publication at a stale frontend revision denied CommitRejected with the session and ledger returned`
  - `PH-001 a publication to a public label denied CommitRejected with the session and ledger returned`
  - `PH-009 a committed binding naming another artifact denied ArtifactMismatch with the session and ledger returned`
  - `PH-009 order: the commit precedes the artifact binding`
  - `PH-009 revocation of the input before authorization denies the publication Identity Retired`
  - `PH-009 revocation of the client's root before authorization denies the publication Identity Retired`
  - `PH-009 order: the current artifact precedes the re-resolution`
  - `PH-009 a second publication of the same invocation denied Replay with no second spend`
  - `PH-009 order: the replay check precedes the commit`
  - `PH-009 order: the re-resolution precedes the replay check`

`reconcile(state, rev, invocation, digest)`: gate, recorded invocation
(Unrecorded), equal digest (Substitution); emits
`Reconcile{recorded invocation, recorded digest}`, advances only the
revision, never commits or spends. Checks:
  - `PH-009 reconcile of a recorded invocation with its digest emits Reconcile with no commit and no spending`
  - `PH-009 reconcile with a different digest denied Substitution`
  - `PH-009 reconcile of an unrecorded invocation denied Unrecorded`
  - `PH-009 reconcile before any publication denied Unrecorded and authorizes nothing`
  - `PH-010 after revocation the recorded publication still reconciles to the same outcome`
  - `PH-010 revocation after publication leaves the record unchanged and emits only StopEffects, no recall`
  - `PH-009 after a restart the recorded publication still reconciles to the same outcome`

### Why the types exclude a second publication route

1. The publication effect is `HostPublication.Publish{intent}`, of type
   `PublishEffect`, which is not a `P.Effect`. Every other transition in all
   five families returns `P.Step`, whose effects are `+List<P.Effect>`, and
   `P.Effect` has no publish variant. So no other transition can return a
   publication at all; the type checker rejects it.
2. `PublishEffect` appears only inside `PublishResult.Published`, and
   `publish` is the only def returning `PublishResult`. Its single
   `Published` constructor site is step 7's accepting arm, and the `intent`
   there is the one bound from `DataOS.commit_from_capability`'s `Committed`
   result in step 6. No parameter of `publish` has type `B.WriteIntent` or
   `B.CommitResult`, so a caller cannot supply an intent or a commit result.
3. `Refused` has no effects field (law `publication_refused_emits_nothing`).
4. `Reconcile` carries no intent, and its fields are copied from the
   monitor's own record, so recovery cannot name a publication the record
   does not hold.
5. `native_write_offered` still has no accepting branch.
6. Remaining gap, reviewed-only (section 2), as for every effect: Bend
   datatypes are public, so a target could construct a `Publish` value
   itself; a target-constructed effect is not authorization.

## Family 5: revocation (PH-010)

- `revoke(state, rev, slot)`: gate; `HostIdentity.retire` on the slot's
  subtree (Identity{reason}); every `Running` worker whose input reference is
  not live at its host, incarnation, slot, and generation becomes `Revoked`,
  with one `StopEffects{worker}` each, in worker order.
- `restart(state, rev, successor)` (added; wraps `HostIdentity.restart`):
  bindings dropped, every `Running` worker `Revoked` with `StopEffects`;
  seals and publications kept.
- `quiesce(state, rev, QuiescedFact{worker, generation})`: gate, worker
  (UnknownWorker), `Revoked` (WrongPhase), generation = 1 + the input
  reference's generation (Identity{StaleGeneration}); phase `Quiesced`, no
  effect.
- `reclaim(state, rev, worker)`: gate, worker (UnknownWorker), `Quiesced`
  (NotQuiesced); phase `Reclaimed`, `[Reclaim{worker}]`.
- `complete(state, rev, CompletionFact{session, message}, now)`: gate, wire
  `Complete` (WrongPhase), resolution on the fact's session
  (Identity{reason}), one non-reclaimed worker on that entry (UnknownWorker),
  `Running` (WrongPhase); revision +1, no effect.

Checks (teardown):
  - `PH-010 revoke retires the input, moves its worker to Revoked, and emits StopEffects for it`
  - `PH-010 revoking the client's root revokes the worker on the delegated input`
  - `PH-010 revoking one input leaves a worker on another entry Running`
  - `PH-010 a later revocation does not stop an already revoked worker again`
  - `PH-010 a revocation stops every running worker whose input reference is not live at its host, incarnation, and generation`
  - `PH-010 a later revocation leaves a quiesced worker Quiesced`
  - `PH-010 quiescing one worker leaves another worker's phase unchanged`
  - `PH-010 revoke of a slot never allocated denied Identity Forged`
  - `PH-010 revoke of an already retired slot denied Identity Retired`
  - `PH-010 reclaim after revoke but before quiesce denied NotQuiesced`
  - `PH-010 reclaim of a running worker denied NotQuiesced`
  - `PH-010 quiesce naming the pre-revocation generation denied Identity StaleGeneration`
  - `PH-010 order: quiesce of a running worker denied WrongPhase before its generation`
  - `PH-010 quiesce of a worker never admitted denied UnknownWorker`
  - `PH-010 quiesce with the retired generation moves the worker to Quiesced with no effect`
  - `PH-010 the order revoke, quiesce, reclaim is accepted and reclaim emits only Reclaim`
  - `PH-010 reclaim of a worker never admitted denied UnknownWorker`
  - `PH-010 a second quiesce denied WrongPhase`
  - `PH-010 a second reclaim denied NotQuiesced`
  - `PH-010 restart drops the bindings, moves running workers to Revoked, and emits StopEffects`
  - `PH-010 restart to an incarnation not greater denied Identity StaleIncarnation`
  - `PH-010 a worker revoked by restart is quiesced and reclaimed in order`

Checks (stale completion):
  - `PH-010 a completion for the running worker's live input is accepted with no effect`
  - `PH-010 a completion after revoke with the old generation denied Identity Retired`
  - `PH-010 a completion after restart with the old incarnation denied Identity StaleIncarnation`
  - `PH-010 a completion fact carrying a Use message denied WrongPhase`
  - `PH-010 a completion for a revoked worker whose entry is still live denied WrongPhase`
  - `PH-010 a completion naming an entry no worker holds denied UnknownWorker`
  - `PH-010 a completion for an entry held only by a reclaimed worker denied UnknownWorker`
  - `PH-010 a completion for the worker's input on the client session denied Identity NotHolder`

## Family 1 wrappers, gate, and valid

  - `PH-001 issue commits HostIdentity.mint's table, advances the revision once, and emits nothing`
  - `PH-001 issue on an unbound session denied Identity UnknownSession`
  - `PH-005 delegate commits HostIdentity.delegate's table, advances the revision once, and emits nothing`
  - `PH-007 a delegation from the worker session through the primitive layer denied Identity NotDelegable`
  - `PH-008 seal at a stale revision denied StaleRevision`
  - `PH-009 publish at a stale revision denied StaleRevision`
  - `PH-009 reconcile at a stale revision denied StaleRevision`
  - `PH-010 revoke at a stale revision denied StaleRevision`
  - `PH-010 restart at a stale revision denied StaleRevision`
  - `PH-010 quiesce at a stale revision denied StaleRevision`
  - `PH-010 reclaim at a stale revision denied StaleRevision`
  - `PH-010 complete at a stale revision denied StaleRevision`
  - `PH-001 issue at a stale revision denied StaleRevision`
  - `PH-005 the primitive delegate at a stale revision denied StaleRevision`
  - `PH-001 states built by the family 1 and 3 to 5 transitions satisfy valid`
  - `PH-008 valid rejects a sealed record naming no worker`
  - `PH-008 valid rejects a worker sealed twice`
  - `PH-009 valid rejects an invocation recorded twice`
  - `PH-008 a seal on a state that is not valid denied StaleRevision`
  - `PH-009 a publication on a state that is not valid denied StaleRevision`
  - `PH-009 reconcile on a state that is not valid denied StaleRevision`
  - `PH-010 revoke on a state that is not valid denied StaleRevision`
  - `PH-010 restart on a state that is not valid denied StaleRevision`
  - `PH-010 quiesce on a state that is not valid denied StaleRevision`
  - `PH-010 reclaim on a state that is not valid denied StaleRevision`
  - `PH-010 complete on a state that is not valid denied StaleRevision`
  - `PH-001 issue on a state that is not valid denied StaleRevision`
  - `PH-005 the primitive delegate on a state that is not valid denied StaleRevision`
  - `PH-001 Error.equal distinguishes the publication and revocation reasons`

Every `P.Step` denial is checked with `denied`/`denied_identity` (reason,
full state equality, no effects). Every publication refusal is checked with
`refused_as`/`refused_identity_as` (reason, full state equality, the
supplied session's and ledger's revisions unchanged, no `Publish`).

Fixtures (synthetic monitor state, stated in the module header): the
publication chain is built only by primitive transitions (open_session as
client and as worker, `issue`, `delegate`, `admit_worker`, `seal`) on the
FacadeTests descriptor (subject 7, Frontend handle 2), with
`NF.running()`, `NF.held_ledger()`, `BF.candidate()`, `FF.context()`, the
FacadeTests revisions (session 6, ledger 1, frontend 2), and the
BackplaneTests artifact. It runs at time 100; the DataOS context's time is
110; the input expires at 150. Teardown and completion use the family 2 base
chain (`admitted()`), with the Task 3 hand-built `revoked()`, `retired()`,
`reclaimed_input()`, and `root_and_input()`. New hand-built states:
`sealed_revoked`, `other_sealed`, `mismatched_refs`, and three states that
fail `valid`.

## Removal map

Scratch harness (`mutate.py` in the session scratchpad): copy the root
`.bend` files, apply one exact one-site replacement inside one named def,
run `bend HostPrimitivesTests.bend`, record the first `FAIL:`. 119 mutants
over every new branch, reason, commit, effect, and gate, in HostPublication
and in the HostPrimitives additions.

First run (202 checks): 116 killed; three survived, the `input_live`
conjuncts on host, incarnation, and generation (equivalent on every state a
transition builds, since slots are never reused and restart empties the
table). I added the hand-built check
`PH-010 a revocation stops every running worker whose input reference is not live at its host, incarnation, and generation`, after which all three are killed.

Final run against all 203 checks: 119 of 119 killed by a named check, none by
a compile error.

| Mutant | First failing check |
| --- | --- |
| seal: gate dropped | `PH-008 seal at a stale revision denied StaleRevision` |
| seal: valid dropped | `PH-008 a seal on a state that is not valid denied StaleRevision` |
| seal: unknown-worker reason | `PH-008 a seal for a worker never admitted denied UnknownWorker` |
| seal: phase check dropped | `PH-008 a seal from a revoked worker denied WrongPhase` |
| seal: phase reason | `PH-008 a seal from a revoked worker denied WrongPhase` |
| seal: re-resolution skipped | `PH-008 a seal after the worker's input was retired denied Identity Retired` |
| seal: identity reason | `PH-008 a seal after the worker's input was retired denied Identity Retired` |
| seal: second seal accepted | `PH-008 a second seal for a sealed worker denied WrongPhase and the record is not replaced` |
| seal: writers check dropped | `PH-008 a seal with one CPU writer denied LiveWriter` |
| writers: cpu ignored | `PH-008 a seal with one CPU writer denied LiveWriter` |
| writers: mappings ignored | `PH-008 a read-only seal with one writable mapping left denied LiveWriter` |
| writers: devices ignored | `PH-008 a seal with one device writer denied LiveWriter` |
| seal: LiveWriter reason | `PH-008 a seal with one CPU writer denied LiveWriter` |
| seal: record not written | `PH-008 a seal with zero writers records the exact object, version, and digest with no effect` |
| seal: record fields swapped | `PH-008 a seal with zero writers records the exact object, version, and digest with no effect` |
| seal: revision not advanced | `PH-008 a seal with zero writers records the exact object, version, and digest with no effect` |
| publish: gate dropped | `PH-009 publish at a stale revision denied StaleRevision` |
| publish: valid dropped | `PH-009 a publication on a state that is not valid denied StaleRevision` |
| publish: gate reason | `PH-009 publish at a stale revision denied StaleRevision` |
| publish: NotSealed reason | `PH-009 a publication before any seal denied NotSealed` |
| publish: current check dropped | `PH-008 a path retargeted to another object denied Retargeted` |
| describes: worker ignored | `PH-008 a current fact naming another worker denied Retargeted` |
| describes: object ignored | `PH-008 a path retargeted to another object denied Retargeted` |
| describes: version ignored | `PH-008 a path retargeted to another version denied Retargeted` |
| describes: digest ignored | `PH-008 a path retargeted to another digest denied Retargeted` |
| publish: Retargeted reason | `PH-008 a path retargeted to another object denied Retargeted` |
| publish: writers dropped | `PH-008 a writable mapping reappearing before publication denied LiveWriter` |
| publish: LiveWriter reason | `PH-008 a writable mapping reappearing before publication denied LiveWriter` |
| publish: resolve at time 0 | `PH-009 a publication at the input's expiry on the DataOS context's clock denied Identity Expired` |
| publish: resolve on a fixed session | `PH-009 a publication through DataOS.commit_from_capability emits exactly one Publish of the sealed digest and spends the ledger once` |
| publish: identity reason | `PH-009 a publication at the input's expiry on the DataOS context's clock denied Identity Expired` |
| publish: phase dropped | `PH-009 a publication for a worker not Running denied WrongPhase` |
| publish: phase reason | `PH-009 a publication for a worker not Running denied WrongPhase` |
| publish: replay accepted | `PH-009 a second publication of the same invocation denied Replay with no second spend` |
| publish: Replay reason | `PH-009 a second publication of the same invocation denied Replay with no second spend` |
| publish: invocation constant | `PH-009 a publication through DataOS.commit_from_capability emits exactly one Publish of the sealed digest and spends the ledger once` |
| publish: time constant | `PH-009 a publication at the input's expiry on the DataOS context's clock denied Identity Expired` |
| publish: Frontend handle from the slot | `PH-009 a publication through DataOS.commit_from_capability emits exactly one Publish of the sealed digest and spends the ledger once` |
| publish: CommitRejected reason | `PH-001 a publication whose capability registry was revoked denied CommitRejected with the session and ledger returned` |
| publish: artifact check dropped | `PH-009 a committed binding naming another artifact denied ArtifactMismatch with the session and ledger returned` |
| publish: mismatch returns the committed session and ledger | `PH-009 a committed binding naming another artifact denied ArtifactMismatch with the session and ledger returned` |
| publish: ArtifactMismatch reason | `PH-009 a committed binding naming another artifact denied ArtifactMismatch with the session and ledger returned` |
| publish: record not written | `PH-009 a publication through DataOS.commit_from_capability emits exactly one Publish of the sealed digest and spends the ledger once` |
| publish: no effect | `PH-009 a publication through DataOS.commit_from_capability emits exactly one Publish of the sealed digest and spends the ledger once` |
| publish: two effects | `PH-009 a publication through DataOS.commit_from_capability emits exactly one Publish of the sealed digest and spends the ledger once` |
| publish: revision not advanced | `PH-009 a publication through DataOS.commit_from_capability emits exactly one Publish of the sealed digest and spends the ledger once` |
| reconcile: gate dropped | `PH-009 reconcile at a stale revision denied StaleRevision` |
| reconcile: valid dropped | `PH-009 reconcile on a state that is not valid denied StaleRevision` |
| reconcile: Unrecorded reason | `PH-009 reconcile of an unrecorded invocation denied Unrecorded` |
| reconcile: digest check dropped | `PH-009 reconcile with a different digest denied Substitution` |
| reconcile: Substitution reason | `PH-009 reconcile with a different digest denied Substitution` |
| reconcile: no effect | `PH-009 reconcile of a recorded invocation with its digest emits Reconcile with no commit and no spending` |
| reconcile: revision not advanced | `PH-009 reconcile of a recorded invocation with its digest emits Reconcile with no commit and no spending` |
| revoke: gate dropped | `PH-010 revoke at a stale revision denied StaleRevision` |
| revoke: valid dropped | `PH-010 revoke on a state that is not valid denied StaleRevision` |
| revoke: identity reason | `PH-010 revoke of a slot never allocated denied Identity Forged` |
| stops: every running worker | `PH-010 revoking one input leaves a worker on another entry Running` |
| stops: phase ignored | `PH-010 a later revocation does not stop an already revoked worker again` |
| revoke: wrong phase | `PH-010 revoke retires the input, moves its worker to Revoked, and emits StopEffects for it` |
| revoke: no StopEffects | `PH-010 revocation after publication leaves the record unchanged and emits only StopEffects, no recall` |
| revoke: workers not stopped | `PH-010 revoke retires the input, moves its worker to Revoked, and emits StopEffects for it` |
| revoke: revision not advanced | `PH-010 revoke retires the input, moves its worker to Revoked, and emits StopEffects for it` |
| input_live: host ignored | `PH-010 a revocation stops every running worker whose input reference is not live at its host, incarnation, and generation` |
| input_live: incarnation ignored | `PH-010 a revocation stops every running worker whose input reference is not live at its host, incarnation, and generation` |
| input_live: generation ignored | `PH-010 a revocation stops every running worker whose input reference is not live at its host, incarnation, and generation` |
| restart: gate dropped | `PH-010 restart at a stale revision denied StaleRevision` |
| restart: valid dropped | `PH-010 restart on a state that is not valid denied StaleRevision` |
| restart: identity reason | `PH-010 restart to an incarnation not greater denied Identity StaleIncarnation` |
| restart: bindings kept | `PH-009 after a restart the recorded publication still reconciles to the same outcome` |
| restart: workers not stopped | `PH-010 restart drops the bindings, moves running workers to Revoked, and emits StopEffects` |
| restart: publication records dropped | `PH-009 after a restart the recorded publication still reconciles to the same outcome` |
| restart: no StopEffects | `PH-010 restart drops the bindings, moves running workers to Revoked, and emits StopEffects` |
| quiesce: gate dropped | `PH-010 quiesce at a stale revision denied StaleRevision` |
| quiesce: valid dropped | `PH-010 quiesce on a state that is not valid denied StaleRevision` |
| quiesce: unknown-worker reason | `PH-010 quiesce of a worker never admitted denied UnknownWorker` |
| quiesce: phase dropped | `PH-010 order: quiesce of a running worker denied WrongPhase before its generation` |
| is_revoked: any phase | `PH-010 order: quiesce of a running worker denied WrongPhase before its generation` |
| quiesce: phase reason | `PH-010 order: quiesce of a running worker denied WrongPhase before its generation` |
| quiesce: generation dropped | `PH-010 quiesce naming the pre-revocation generation denied Identity StaleGeneration` |
| quiesce: pre-retirement generation | `PH-010 a later revocation leaves a quiesced worker Quiesced` |
| quiesce: generation reason | `PH-010 quiesce naming the pre-revocation generation denied Identity StaleGeneration` |
| quiesce: wrong phase | `PH-010 a later revocation leaves a quiesced worker Quiesced` |
| phased: every worker | `PH-010 quiescing one worker leaves another worker's phase unchanged` |
| reclaim: gate dropped | `PH-010 reclaim at a stale revision denied StaleRevision` |
| reclaim: valid dropped | `PH-010 reclaim on a state that is not valid denied StaleRevision` |
| reclaim: unknown-worker reason | `PH-010 reclaim of a worker never admitted denied UnknownWorker` |
| reclaim: phase dropped | `PH-010 reclaim after revoke but before quiesce denied NotQuiesced` |
| is_quiesced: any phase | `PH-010 reclaim after revoke but before quiesce denied NotQuiesced` |
| reclaim: NotQuiesced reason | `PH-010 reclaim after revoke but before quiesce denied NotQuiesced` |
| reclaim: no effect | `PH-010 the order revoke, quiesce, reclaim is accepted and reclaim emits only Reclaim` |
| reclaim: wrong phase | `PH-010 the order revoke, quiesce, reclaim is accepted and reclaim emits only Reclaim` |
| complete: gate dropped | `PH-010 complete at a stale revision denied StaleRevision` |
| complete: valid dropped | `PH-010 complete on a state that is not valid denied StaleRevision` |
| complete: message reason | `PH-010 a completion fact carrying a Use message denied WrongPhase` |
| complete: identity reason | `PH-010 a completion after revoke with the old generation denied Identity Retired` |
| complete: reclaimed workers counted | `PH-010 a completion for an entry held only by a reclaimed worker denied UnknownWorker` |
| complete: entry ignored | `PH-010 a completion naming an entry no worker holds denied UnknownWorker` |
| complete: unknown-worker reason | `PH-010 a completion naming an entry no worker holds denied UnknownWorker` |
| complete: phase dropped | `PH-010 a completion for a revoked worker whose entry is still live denied WrongPhase` |
| complete: phase reason | `PH-010 a completion for a revoked worker whose entry is still live denied WrongPhase` |
| complete: revision not advanced | `PH-010 a completion for the running worker's live input is accepted with no effect` |
| valid: seal clause dropped | `PH-008 valid rejects a sealed record naming no worker` |
| valid: publication clause dropped | `PH-009 valid rejects an invocation recorded twice` |
| valid seals: worker clause | `PH-008 valid rejects a sealed record naming no worker` |
| valid seals: once clause | `PH-008 valid rejects a worker sealed twice` |
| seal_at ignores the worker | `PH-009 another worker's sealed record does not seal this worker's publication: denied NotSealed` |
| publication_at ignores the invocation | `PH-009 reconcile of an unrecorded invocation denied Unrecorded` |
| valid publications: once clause | `PH-009 valid rejects an invocation recorded twice` |
| one_seal any | `PH-008 valid rejects a worker sealed twice` |
| one_publication any | `PH-009 valid rejects an invocation recorded twice` |
| issue/delegate: identity reason | `PH-001 issue on an unbound session denied Identity UnknownSession` |
| issue/delegate: table not committed | `PH-001 issue commits HostIdentity.mint's table, advances the revision once, and emits nothing` |
| issue: gate dropped | `PH-001 issue at a stale revision denied StaleRevision` |
| issue: valid dropped | `PH-001 issue on a state that is not valid denied StaleRevision` |
| delegate: gate dropped | `PH-005 the primitive delegate at a stale revision denied StaleRevision` |
| delegate: valid dropped | `PH-005 the primitive delegate on a state that is not valid denied StaleRevision` |
| delegate: time 0 | `PH-005 delegate commits HostIdentity.delegate's table, advances the revision once, and emits nothing` |
| Error.equal: Replay arm | `PH-009 a second publication of the same invocation denied Replay with no second spend` |
| Error.equal: NotQuiesced arm | `PH-010 reclaim after revoke but before quiesce denied NotQuiesced` |

Source-reviewed only, unreachable from a `valid` state and commented as
such: the `ManyWorkers` arms of `s_worker`, `q_worker`, `k_worker`,
`e_worker`; `p_sealed`'s `ManySeals` arm; `p_worker`'s non-`OneWorker` arm (a
sealed record names one worker); the `ManyPublications` arms of `p_fresh` and
`r_recorded`. Not run as a mutant, because equivalent:
`p_committed` returning DataOS's own Rejected session and ledger (DataOS
returns its inputs). Order checks are built so the input fails both steps;
each later step's own check shows that step alone produces the other reason.

## Laws, and how they were extended

- `primitive_denied_preserves_state` and `primitive_denied_emits_nothing`
  are unchanged and still cover every `P.Step` transition, which now
  includes `seal`, `reconcile`, `revoke`, `restart`, `quiesce`, `reclaim`,
  `complete`, `issue`, and `delegate`. `State` gained two fields and `Error`
  nine reasons; the accessors on `Denied` are unchanged, so both proofs are
  still `{==}`.
- `publish` returns `PublishResult`, which the existing laws do not cover,
  so the same two statements were added for it (additions only, rationale in
  the HostPublication header and above each law):
  - `publication_refused_preserves_state`:
    `{HostPublication.PublishResult.state(HostPublication.Refused{state, session, ledger, reason}) == state : HostPrimitives.State}`
  - `publication_refused_emits_nothing`:
    `{HostPublication.PublishResult.effects(HostPublication.Refused{state, session, ledger, reason}) == [] : List<&2, HostPublication.PublishEffect>}`
  - proofs `def Laws.publication_refused_preserves_state(state, session, ledger, reason): {==}` and the same for the second; no hole.
- Discrimination, in a scratch copy: making `PublishResult.state` return
  `P.advanced(state)` on `Refused` gave `SOME PROOFS FAIL` (expected
  `HostPrimitives.advanced(state)`, observed `state`); stating the effects law
  as `== [effect]` gave `SOME PROOFS FAIL` (expected `[]`, observed
  `[effect]`).
- They do not assert that the returned session and ledger are the inputs;
  `refused_as` checks that in every refusal.

## Verification

| | PASS lines |
| --- | --- |
| Before this task | 1041 |
| After this task | 1140 (782 plus 358 new checks = 1140; this task adds 99; HostPrimitives 203) |

- 0 of the 782 PASS lines in `verification/tests-js.txt` are missing; no
  PASS line is duplicated (a first run found one duplicate, see Concerns).
- `bend HostPrimitivesTests.bend`: 203 PASS, `HostPrimitives: 203 checks passed`.
- `bend Tests.bend` (JS): exit 0, 1140 PASS; last lines
  `Property: 324 checks passed; 320 graph cases, each checked against CPU and Bend parallel producers`
  and `ALL LIBRARY TESTS PASSED`.
- Native: `bend Tests.bend -o ../writ-build/portable-host-contract/tests-native && ../writ-build/portable-host-contract/tests-native +RTS --threads 4 --gpu off`:
  the build took 3m16s and exited 0; the run exited 0 with 1140 PASS and the
  same last two lines, and its PASS lines are identical, in order, to the JS
  run's. This is CPU execution, not a GPU test.
- `bend PROOF.bend`: `ALL PROOFS CHECK` / `Use --verdict for mathematical validity.`
- `bend PROOF.bend --verdict`: unavailable:
  `Error: BendTT infrastructure: the kernel did not build (lean: Executable not found in $PATH: "lean"); --verdict needs Lean v4.34.0 (elan toolchain leanprover/lean4:v4.34.0), or $BENDTT set to a built kernel`.
- `~/.bun/bin/bunx @fission-ai/openspec@1.16.0 validate --all --strict --no-interactive`:
  `Totals: 44 passed, 0 failed (44 items)`.
- No `@unsafe`, no holes, no mutual recursion (one helper pair I first wrote
  was rejected and replaced by a counted lookup).

## Rulings applied and concerns

1. Brief value adjusted. The brief expects revoke-then-publish to be denied
   `Identity{StaleGeneration}`. HostIdentity cannot produce that: `retire`
   keeps the entry but clears `live`, and `resolve` counts live entries at
   the slot before comparing generations, so a retired slot gives `Retired`
   (step 4) before step 5. Slots are never reused, so no live entry with
   another generation exists. The checks therefore expect `Identity{Retired}`
   for publish and for a completion after revoke. `StaleGeneration` is used
   where the brief names it as the quiesce reason.
2. `reconcile` takes `expected_revision` (the brief's signature omitted it),
   per the Global Constraints and the Task 3 standard; an accepted reconcile
   advances the revision once and changes nothing else.
3. `publish` has no `now` parameter in the brief; step 4 resolves at the
   DataOS context's negotiation time, the clock the commit reads. Checked by
   the Expired check and by the `attempt_now` mutant.
4. Step 4 also requires the worker `Running` (WrongPhase), after the
   re-resolution so revocation still reports the identity reason. This is
   an addition to the brief's list, pinned by two checks.
5. `seal` takes `now` and re-resolves; a second seal is denied WrongPhase
   (the record is never replaced). Both are additions.
6. Ruling interpretation: `mint` is wrapped as family 1 `issue`, the
   primitive that issues a root reference; `delegate` is wrapped as ruled.
   `restart` is also wrapped (revocation family), because the brief's
   "after restart" completion case needs a restarted state that satisfies
   `valid` (the old bindings name sessions the new incarnation may reuse,
   so a primitive restart must drop them). So every change to the identity
   table is now a primitive transition. A peer's wire `Release` is not yet
   a primitive transition.
7. The facts are separate record types, not `Fact` variants, so `seal`,
   `publish`, `quiesce`, and `complete` have no wrong-variant arm; `complete`
   still checks the wire message variant.
8. The retired generation for `quiesce` is derived (1 + the worker's input
   reference generation), equal to the table's entry generation after
   `retire` in every reachable state; after `restart` the entries are gone,
   so the same rule is used.
9. Pre-existing test lines: `State`'s arity changed, so 24 hand-built
   `P.State{...}` literals (some inside existing `Test.check` expressions)
   gain `, P.NoSeals{}, P.NoPublications{}`, `state_equal` compares the two
   new fields, and `effect_equal` gains arms. Stripping that inserted text
   and diffing against HEAD leaves only the header comments, the
   `state_equal` pattern, the `effect_equal` comment, and the summary line;
   the 104 earlier check names are unchanged and in order.
10. LAWS.bend and PROOF.bend changed in Task 4, which the Global
    Constraints reserve for Tasks 2 and 3; done under the controller ruling
    "extend their proofs", additions only, as two companion laws rather than
    edits.
11. A first full run found `PH-005 delegate at a stale revision denied
    StaleRevision` already used by HostIdentityTests; the two new delegate
    gate checks are named "the primitive delegate ...".
12. `complete` ignores `sequence` and `status` (no completion replay rule);
    an accepted completion only advances the revision.
13. HostPublication reuses HostPrimitives implementation helpers (`current`,
    `reresolve`, `worker_at`, ...) and HostIdentity's `live_at`; both
    headers name this.
14. `Published.commit` is typed `B.CommitResult`, so by type it could hold
    `Rejected`; its only constructor site builds `Committed`.
15. Sizes: HostPrimitives 1520 lines, HostPublication 826, tests 1775; 99
    checks against an estimate of about 32 (gates, valid clauses, orders, and
    the checks the mutation run needed).
