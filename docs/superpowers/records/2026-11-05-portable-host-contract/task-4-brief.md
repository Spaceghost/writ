### Task 4: Artifact exchange, publication, and revocation families (tasks.md 1.3, second half)

Requirements: PH-001 "One policy implementation across hosts" ("Native transport accepts a request": a failed commit check means no effect); PH-008 "Artifact sealing excludes all writers" ("A read-only mapping retains a writable alias", "A path is retargeted"); PH-009 "Publication observes one current authority boundary" ("Revocation precedes authorization", "Crash recovery repeats a publication attempt"); PH-010 "Revocation includes quiescence and stale completion rejection" ("A device completes after teardown", "A reader already copied plaintext").

Extend `HostPrimitives.bend`.

- Facts: `ArtifactFact{worker, object: Nat, version: Nat, digest: T.CodeId, cpu_writers: Nat, writable_mappings: Nat, device_writers: Nat}`, `QuiescedFact{worker, generation}`, `CompletionFact{session, message}` (a decoded `HostWire.Complete`).
- Effects: `Publish{intent: B.WriteIntent}`, `Reconcile{invocation, digest}`, `StopEffects{worker}`, `Reclaim{worker}`. Plan ruling: there is no recall or erase effect. Revocation stops future effects only, and the module header says it does not erase earlier copies (PH-010's second scenario is reviewed-only beyond that).
- State additions: `sealed` (worker → object, version, digest) and `publications` (invocation → digest), both monitor-owned.
- Family 3: `seal` requires a Running worker and zero writers of all three kinds, or it denies `LiveWriter`. It records the exact object, version, and digest.
- Family 4: `publish(state, expected_revision, worker, current: ArtifactFact, session, expected_session, expected_ledger, ledger, candidate, context: DataOS.Context, expected_frontend)`. It returns `Published{state, commit, effects}` | `Refused{state, session, ledger, reason}`; plan ruling: a separate result type, because publication must also hand back the negotiation session and ledger. The order is fixed. (1) Revision. (2) A sealed record exists (`NotSealed`). (3) `current` equals the sealed object, version, and digest, with zero writers (`Retargeted` or `LiveWriter`). (4) The worker's slot is re-resolved through `HostIdentity.resolve` (`Identity{...}`, so revocation before this point denies). (5) The invocation is not already in `publications` (`Replay`). (6) `DataOS.commit_from_capability` is called with `F.Ref{resolved caller, entry handle}`; `Rejected` gives `CommitRejected` and returns the input session and ledger. (7) `Committed`: the intent's `ArtifactId` must equal the sealed digest (`ArtifactMismatch`), and on mismatch the committed session and ledger are discarded and the inputs returned. Only after all seven does it record the publication and emit one `Publish{intent}`.
- `reconcile(state, invocation, digest)`: for a recorded invocation with an equal digest, it emits `Reconcile` with no commit and no spending. A different digest is denied `Substitution`; an unrecorded invocation is denied `Unrecorded`. Plan ruling: reconcile never authorizes; it only repeats a recorded outcome.
- Family 5: `revoke(state, expected_revision, slot)` calls `HostIdentity.retire` on the subtree, moves affected workers to `Revoked`, and emits `StopEffects` for each. `quiesce` takes a `QuiescedFact` whose generation matches the retired generation (otherwise `StaleGeneration`), and the phase becomes `Quiesced`. `reclaim` before `Quiesced` is denied `NotQuiesced`. `complete` resolves the completion's reference: an old generation or incarnation is denied, and so is a completion for a non-Running worker.
- New `Error` constructors: `LiveWriter`, `NotSealed`, `Retargeted`, `ArtifactMismatch`, `CommitRejected`, `Replay`, `Substitution`, `Unrecorded`, `NotQuiesced`. Extending a closed set is not a law change, and the Task 3 laws hold for every reason.

The tests, appended to `HostPrimitivesTests.bend` as new requirement groups, must cover these cases.
- Seal: denied with one CPU writer, with one writable mapping, and with one device writer (one check each); accepted with zero.
- Retarget: a changed object, a changed version, and a changed digest are each denied `Retargeted`.
- Accepted publish: it uses `FacadeTests`-style fixtures, emits exactly one `Publish` whose intent artifact equals the sealed digest, and its ledger spends once.
- Commit denials: a denied commit (wrong plan, revoked registry, or stale frontend revision; at least two) emits no effect and leaves the ledger and session revisions unchanged.
- Artifact mismatch: a binding whose artifact differs from the sealed digest is denied, with the inputs returned.
- Revocation before authorization: revoke, then publish, is denied `Identity{StaleGeneration}`.
- Replay: a second publish of the same invocation is denied `Replay`, with no second spend.
- Reconcile: equal digest gives `Reconcile` with no spending; a different digest gives `Substitution`; an unknown invocation gives `Unrecorded`.
- Teardown: reclaim before quiesce is denied; quiesce with the wrong generation is denied; the order revoke, quiesce, reclaim is accepted.
- Stale completion: a completion after revoke with the old generation is denied, and so is one after `restart` with the old incarnation.
- Revocation after publish: the publication record and its reconcile outcome are unchanged, and no recall effect exists.
- Unchanged state: full state equality on every denial.

Estimate: about 32 checks; about 300 more lines of module and 300 of tests. If `HostPrimitives.bend` would pass about 700 lines, move families 3 to 5 into `HostPublication.bend` (importing `HostPrimitives`) and report it. That file is pre-approved for the touch list. Add the PH-008 to PH-010 rows. Native alias elimination, DMA/IO quiescence, and the durable-publication protocol are host obligations. Check box 1.3, citing both test groups.

Acceptance: every case is a named check; publication has no path except step (6); no existing check changed; the suite is green on both backends; proofs pass.

