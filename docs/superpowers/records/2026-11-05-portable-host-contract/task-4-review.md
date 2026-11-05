# Task 4 review: sealing, publication with recovery, and revocation (9c06811..44d1619)

Reviewer: task reviewer (security and proof review). Scope: commit 44d1619 on
`lane/portable-host-contract`, i.e. `HostPublication.bend` (new), the
`HostPrimitives.bend` additions, `LAWS.bend`/`PROOF.bend` additions, the new
requirement groups in `HostPrimitivesTests.bend`, the traceability and
`tasks.md` edits. I read the brief, the report, the review package, the plan's
Global Constraints, the Task 3 review and re-review, HostIdentity (`retire`,
`doomed`, `restart`, `resolve`), `DataOS.commit_from_capability`,
`DataOS.commit_resolved`, `Backplane.checks`/`commit_output`, `Ledger.commit`,
and the PH-001 and PH-008 to PH-010 deltas. Controller rulings listed in the
dispatch are not flagged.

## Verdict 1, spec compliance: APPROVED

- Sealing (PH-008). `seal` (HostPublication.bend:310-391) requires a Running
  worker, a live re-resolution, no earlier seal, and zero CPU writers, zero
  writable mappings, and zero device writers (`writers_absent`, :310-314),
  else `LiveWriter`. One check per writer kind, each pinned (my mutant k,
  device writers ignored, is killed by `PH-008 a seal with one device writer
  denied LiveWriter`). Retargeting: `publish` step 3 (`describes`, :324-328)
  compares worker, object, version, and digest with the sealed record, then
  re-checks all three writer counts. Changed object, version, digest, and
  worker are each denied `Retargeted` by a named check. Independently of the
  native fact, step 7 requires the committed `WriteIntent.artifact` (taken by
  Backplane from the monitor's own binding) to equal the sealed digest
  (:446), so a retargeted path cannot be published under the sealed identity
  even if a binding misreports the object.
- Publication route (PH-001, PH-009). The only call of
  `D.commit_from_capability` is `p_commit` (:451-455). The `F.Ref` is
  `{resolved owner caller, I.entry_handle(entry)}` from `HostIdentity.resolve`
  on the worker's own session at the DataOS context's time, not from a
  request. The order is gate, sealed, current/writers, re-resolution/phase,
  replay, commit, artifact; the code matches the header table (:46-64)
  step for step. `PublishEffect` (:191-192) is not a `P.Effect`, every other
  transition returns `P.Step`, `PublishResult` is returned only by `publish`,
  and the single `Publish{intent}` construction is in `p_artifact`'s
  accepting arm (:434-435), with `intent` bound from the `B.Committed` that
  `commit_from_capability` returned (:445). No parameter of `publish` has
  type `WriteIntent` or `CommitResult`. I grepped: `Publish{` is constructed
  nowhere else in the tree's `.bend` sources outside tests. Ruling verified.
- Replay key. The key is `T.Plan.invocation(N.Session.plan(session))`
  (`attempt_invocation`, :414-415). That is exactly the invocation
  `Backplane.commit_output` spends in `Ledger.commit` (`Session.plan` is
  `Request.plan(Session.request)`), so the primitive record and the ledger's
  `committed` set key on the same value. A "fresh" replay cannot slip
  through. `publish` takes no sequence, so there is nothing to freshen. A
  different invocation means a different plan, and
  `DataOS.commit_resolved` requires the Frontend handle's plan (the worker's
  entry handle, monitor state) to equal the session's plan with
  `Plan.equal`, which compares the invocation (Transfer.bend:249-254). So
  one worker entry admits exactly one invocation, and a resubmission of it is
  stopped three times: `publications` (Replay, before the commit), the
  finished session (`N.ready` needs Running; `Session.finish` moves it to
  Committed), and `Ledger.commit` (`contains(committed, invocation)`). The
  first of these is pinned by `PH-009 a second publication of the same
  invocation denied Replay with no second spend` and the order check
  `PH-009 order: the replay check precedes the commit` (my mutant b, replay
  accepted, is killed).
- Recovery. `reconcile` (:545-576) emits `P.Reconcile` with both fields
  copied from the recorded `Publication`, after requiring a recorded
  invocation (`Unrecorded`) and an equal digest (`Substitution`). It never
  commits or spends. I tried to construct a publication the record does not
  hold: an unrecorded invocation gives `Unrecorded`; a recorded invocation
  with another digest gives `Substitution`; `P.Reconcile` carries no intent,
  and `P.Effect` has no publish variant, so a reconcile cannot release new
  bytes through the monitor. Swapping the emitted digest for the supplied one
  is an equivalent mutant (they are equal on the accepting path). I could not
  construct one. See finding 3 for what the record does not hold.
- Revocation (PH-010). `revoke` retires the subtree through
  `HostIdentity.retire` and moves only Running workers whose input is no
  longer live to `Revoked`, with one `StopEffects` each. `quiesce` needs
  `Revoked` (WrongPhase) and the retired generation
  (`Identity{StaleGeneration}`); `reclaim` needs `Quiesced` (NotQuiesced).
  Each out-of-order call is denied by a named check: reclaim after revoke
  before quiesce, reclaim of a running worker, quiesce of a running worker,
  a second quiesce, a second reclaim. A stale completion is denied by
  `resolve` on the fact's session: old generation after revoke gives
  `Retired` (ruling), old incarnation after restart gives `StaleIncarnation`,
  and a completion for a revoked worker whose entry is live gives
  `WrongPhase`.
- Removal checks. The implementer's map lists 119 of 119 killed. I wrote my
  own runner (scratchpad `mut.py`: copy the tree, one exact one-site
  replacement, run `bend HostPrimitivesTests.bend`, report the first `FAIL`)
  and ran 14 removals of my choosing; all 14 were killed by a named check,
  none by a compile error:

  | # | Removal (HostPublication.bend) | First failing check |
  | --- | --- | --- |
  | a | publish's Running check (`p_phase(True{}, ...)`) | `PH-009 a publication for a worker not Running denied WrongPhase` |
  | b | replay arm commits anyway | `PH-009 a second publication of the same invocation denied Replay with no second spend` |
  | c | ArtifactMismatch reported as CommitRejected | `PH-009 a committed binding naming another artifact denied ArtifactMismatch with the session and ledger returned` |
  | d | quiesce's Revoked check | `PH-010 order: quiesce of a running worker denied WrongPhase before its generation` |
  | e | reclaim accepts Revoked | `PH-010 reclaim after revoke but before quiesce denied NotQuiesced` |
  | f | complete accepts an Unresolved reference | `PH-010 a completion after revoke with the old generation denied Identity Retired` |
  | g | `stops` ignores the phase | `PH-010 a later revocation does not stop an already revoked worker again` |
  | h | revoke's StopEffects computed on the old table | `PH-010 revocation after publication leaves the record unchanged and emits only StopEffects, no recall` |
  | i | retired generation without the +1 | `PH-010 a later revocation leaves a quiesced worker Quiesced` |
  | j | reconcile's digest check | `PH-009 reconcile with a different digest denied Substitution` |
  | k | device writers ignored | `PH-008 a seal with one device writer denied LiveWriter` |
  | l | a second seal replaces the record | `PH-008 a second seal for a sealed worker denied WrongPhase and the record is not replaced` |
  | m | publish's artifact check | `PH-009 a committed binding naming another artifact denied ArtifactMismatch with the session and ledger returned` |
  | n | publish re-resolves at the seal time 100 rather than the context time | `PH-009 a publication at the input's expiry on the DataOS context's clock denied Identity Expired` |

- Laws. LAWS.bend: 11 laws, PROOF.bend: 11 proofs; the diff to both files
  contains no removed line (additions only). The two new laws are real
  statements about `PublishResult.state`/`effects` of a `Refused` value, for
  every state, session, ledger, and reason, proved by `{==}` with no hole.
  They fail when the code is broken: in a scratch copy, making
  `PublishResult.state` return `P.advanced(state)` on `Refused` makes
  `bend PROOF.bend` fail at `Laws.publication_refused_preserves_state`. The
  existing two primitive laws cover the seven new `P.Step` transitions by
  type. Their reach is the accessor contract only, as for the Task 3 laws
  and as the header and LAWS comments say; which inputs are refused is
  carried by the tests, not the laws.
- Suite and proofs (run by me, in the worktree):
  - `bend Tests.bend`: exit 0, 1140 `PASS` lines, 0 `FAIL`, no duplicated
    PASS line; last lines
    `Property: 324 checks passed; 320 graph cases, each checked against CPU and Bend parallel producers`
    and `ALL LIBRARY TESTS PASSED`.
  - `bend PROOF.bend`: `ALL PROOFS CHECK` / `Use --verdict for mathematical validity.`
    `--verdict` not run (no `lean` on PATH, as the report records).
  - Native: `bend Tests.bend -o <scratchpad>/tests-native` then
    `tests-native +RTS --threads 4 --gpu off`: exit 0, 1140 PASS, 0 FAIL,
    the same last two lines, and PASS lines identical, in order, to the JS
    run. This is CPU execution, not a GPU test.
  - `bunx @fission-ai/openspec@1.16.0 validate --all --strict --no-interactive`:
    `Totals: 44 passed, 0 failed (44 items)`.
- Scope. `git diff master -- '*.bend'` lists only HostIdentity,
  HostIdentityTests, HostPrimitives, HostPrimitivesTests, HostPublication,
  HostWire, HostWireTests, LAWS, PROOF, and Tests (this lane's files; master
  has moved by one docs-only commit). This task did not touch `Tests.bend`.
  No count pin changed; `HostPrimitives: 203 checks passed` is the required
  per-module summary line, not a pin.
- Traceability: 99 new check names, each present in the traceability file.
  One earlier citation was overwritten (finding 1).

## Verdict 2, security and code quality: APPROVED

Questions from the dispatch:

- Effects on a denial path: none. `P.Denied` and `Refused` have no effects
  field, and every `case False{}`/wildcard arm in HostPublication returns one
  of them.
- Mutation before the last check: none. Every commit helper
  (`commit_seal`, `commit_publication`, `commit_revoke`, `commit_restart`,
  `commit_phase`, `P.advanced`) is called only in the final accepting arm.
  `publish` evaluates `commit_from_capability` before step 7, but the result
  is a pure value, and on ArtifactMismatch `refuse` returns the attempt's
  original session and ledger (pinned by the mismatch check's revision
  comparison).
- `complete` ignoring `sequence` and `status`: a completion for another
  sequence is accepted the same as this one's, and the same completion is
  accepted again. In the model this cannot do harm: acceptance changes only
  the revision and emits nothing, so it cannot "mutate or publish a new
  invocation's resources". It does mean the monitor does not bind a
  completion to an outstanding operation. See finding 2.
- Derived retired generation: `1 + I.ref_generation(P.worker_input(worker))`.
  The worker input is monitor state, rebuilt from the resolved entry at
  admission. No transition writes it later, and the fact only supplies the
  value it is compared with. A caller cannot influence it. It equals the
  table's entry generation after `retire` (`doomed` adds one, once, and only
  to a live entry, so it is never applied twice). After `restart` there is no
  entry, and the rule is a convention; that case is accepted.
- The 24 extended state literals: with `, P.NoSeals{}, P.NoPublications{}`
  stripped, a diff against 9c06811 shows only the header comments, the
  `state_equal` pattern, the `effect_equal` comment, and the summary line.
  All 104 earlier names are unchanged and in order. The family 1 and 2
  transitions copy `seals` and `publications` through, and `state_equal` now
  also compares those two fields, so every earlier check tests what it
  tested and slightly more.
- Publish clock: `attempt_now` reads `N.Context.now` of the DataOS context's
  negotiation context. That is the same clock `Backplane.checks`
  (`hold_live`) and `Ledger.commit` read. The context is a monitor parameter
  of `publish`, never a wire field: HostWire has no Context variant, and
  PH-011's checks reject a serialized context. A target binding supplies only
  `ArtifactFact` to `publish`. I found no path where a caller sets it. The
  monitor's clock monotonicity between `seal`'s `now` and the context is the
  existing monitor obligation.
- Partial matches: every wildcard arm denies (NotSealed, UnknownWorker,
  Replay, Unrecorded, WrongPhase, or `False{}` in `live_generation`, which
  makes a revocation stop the worker). That is fail-closed. The
  unreachable `Many*` arms are commented.
- Fixtures: the values are distinct where it matters. The client and
  worker callers share subject 7, as delegation requires, but differ in
  token. A commit made with the worker's caller would miss the registry,
  whose capability is keyed by the client token. Objects are 701/702,
  versions 3/4, workers 80/81/82, slots 21/22/23, times 100/110/150, and the
  unknown invocation is 999. `stale_frontend_revision` and `expected_ledger`
  are both 1, but they feed different parameters.

### Findings (by severity)

No Critical or Important findings.

1. Minor (traceability). openspec/traceability/portable-host-contract.md:73,
   the HostIdentity PH-005 delegation row. Task 4 replaced its citation of
   HostIdentityTests' `PH-005 delegate at a stale revision denied
   StaleRevision` (HostIdentityTests.bend:798, still present and passing)
   with this task's `PH-005 the primitive delegate at a stale revision denied
   StaleRevision`. That name now appears twice (lines 73 and 137), and the
   HostIdentity check has no traceability entry. This looks like a side
   effect of the rename in report concern 11. Fix: restore
   `PH-005 delegate at a stale revision denied StaleRevision` on line 73 and
   keep the primitive name only on line 137.
2. Minor (documentation of a model gap). HostPublication.bend:116-122 and
   :819-825. `complete` ignores the wire `sequence` and `status`, and nothing
   records outstanding operations. An `Admitted` completion therefore says
   only that the reference is live on that session and its worker is
   Running. It does not say that this completion belongs to any operation,
   and a replayed or re-sequenced completion is accepted again. The header
   says acceptance emits nothing, but not that it authorizes nothing about a
   particular sequence or buffer. Fix: state in the header and above
   `complete` that sequence and status are not checked, that an accepted
   completion grants nothing (the binding must not deliver a completion's
   data into any buffer on the strength of `Admitted`), and that per-sequence
   completion matching is a host obligation or later work. Record it as
   reviewed-only in the PH-010 traceability row.
3. Minor (recovery record scope). HostPrimitives.bend:305 (`Publication`)
   and :248 (`Reconcile`); HostPublication.bend:89-95. The record holds only
   the invocation and digest, as the brief defines. The `WriteIntent` that
   was authorized (plan destination, output policy, label, backend) is
   returned in `Published.commit` for the monitor to persist, but the
   primitive state does not hold it, and `Reconcile` does not carry it. So
   when the binding finishes a reconciled publication, it takes the
   destination and label from its own durable log, and the monitor cannot
   tell whether the finish matches what was authorized. PH-009 asks only for
   "the same invocation" and no "new artifact substitution", and both hold,
   so this is not a spec breach. The host-obligation sentence (:128-133)
   covers the durable log. Fix (optional, or a controller ruling for a later
   task): record the committed `WriteIntent` (or its destination and label)
   in `Publication` and copy it into `Reconcile`. Otherwise, add to the
   header that the destination of a reconciled publication is the durable
   log's, a host obligation.
4. Nit. HostPublication.bend:199. `Published.commit` is typed
   `B.CommitResult`, so by type a `Published` could carry `Rejected`
   (report concern 14). Fix: store `session: N.Session, ledger: L.State`
   (and the intent is already in the effect) in `Published`, or document at
   the type that the only construction site builds `Committed`.
5. Nit. HostPublication.bend:695-696. `retired_generation` restates
   HostIdentity's retirement rule (`doomed`, HostIdentity.bend:978-981) as a
   bare `1n+`. Fix: export a named HostIdentity helper (for example
   `retired_generation_of(generation)`) that both `doomed` and `quiesce` use,
   so the two cannot drift.
6. Nit. The order differs between seal and publish. `seal` checks the phase
   before the re-resolution (:362-367), so a revoked worker gets
   `WrongPhase`. `publish` checks the re-resolution first (:480-486), so the
   same worker gets `Identity{reason}`. Both orders are documented and
   pinned, so this is harmless. Fix (optional): use one order, or say in the
   header why seal reports the phase first.

## What I did not do

- I did not run `bend PROOF.bend --verdict`; `lean` is not on PATH.
- No GPU run; the native run above is CPU execution (`--gpu off`).
- I did not probe a second negotiation session with another invocation for
  the same worker. That case rests on reading `DataOS.commit_resolved`
  (`Plan.equal`, including the invocation) and `Ledger.commit`.
- Scratch files (mutation runner, mutated copies, outputs) are in the session
  scratchpad only; nothing in the worktree changed except this file.
