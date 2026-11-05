# Task 3 report: primitive interfaces, session binding, and worker domains (tasks.md 1.3, first part)

Status: DONE_WITH_CONCERNS (one forced rename and some interpretations, all
listed under Concerns). Implementer, lane `lane/portable-host-contract`.

## Delivered

- `HostPrimitives.bend` (new, 735 lines, most of them header and comments).
  It imports `Base`, `HostWire`, `HostIdentity`, `Frontend`, `Transfer`,
  `Backplane`, and `DataOS`. `Backplane` and `DataOS` are imported for Task
  4's publication family and are unused here; the header says so.
  - The header lists the five families. It says the target binding supplies
    only `Fact` values and executes only the `Effect` values in an
    `Admitted` step that a transition returned, and that a target-constructed
    `Effect` is not authorization. That last point is a reviewed-only host
    obligation for section 2.
  - It also gives authority, edge direction, the admission order, the worker
    runtime rulings, failure behavior, and both law rationales.
  - It has one section per family. Families 3 to 5 have empty section
    headers, ready for Task 4.
- `HostPrimitivesTests.bend` (new, 627 lines, 52 checks). It is registered
  as `HostPrimitives`. The header marks every fixture as SYNTHETIC MONITOR
  STATE. The summary line is `HostPrimitives: 52 checks passed`.
- `Tests.bend`: one import (`import ./HostPrimitivesTests.bend as HostPrimitives`)
  and one call (`HostPrimitives.main()`), each directly after the
  HostIdentity line. Nothing else changed.
- `LAWS.bend`: one import and two laws with rationales. Additions only.
- `PROOF.bend`: one import and two `{==}` proofs. Additions only.
- `openspec/traceability/portable-host-contract.md`: a 1.3 row in the module
  table and a new section, "Primitive interfaces, families 1 and 2", with
  PH-001, PH-002, PH-006, PH-007, PH-014, and law rows. It lists all 52 check
  names exactly once. Native route removal or mediation, real quotas, and
  device isolation are marked as host obligations.
- `tasks.md` is not touched: box 1.3 stays unchecked until Task 4.
- No count pin was touched, and no file outside the touch list changed.

## Interface types, and why they exclude an alternate path (PH-001)

| Type | Shape | Owner |
| --- | --- | --- |
| `Backend` | `Cpu{}` or `Accelerator{}` | monitor (inside `Profile`) |
| `Profile` | `{id: Nat, required_families: U32, required_controls: U32, backend: Backend}` | monitor: the admitted request, passed as its own parameter |
| `TargetReport` | `{supported_families: U32, established_controls: U32}` | target's native facts; no profile field |
| `RouteFact` | `{kind: U32, mediated: Bool}` | target; one entry of the complete inventory |
| `Fact` | `SessionEvidence{caller, origin, delegable}`, `Inventory{routes}`, `ResourceRequest{worker, amount}`, `Diagnostic{worker, public}`, `NativeWriteOffered{worker}` | target observations |
| `Effect` | `DeliverInputs{worker, slot}` (Task 4 adds the rest) | produced only by an admitted transition |
| `Step` | `Admitted{state, effects: +List<Effect>}` or `Denied{state, reason}` | output of every mutating transition |
| `Error` | `Identity{HostIdentity.Error}`, `UnsupportedFamily`, `MissingControl`, `UnmediatedRoute`, `UnisolatedAccelerator`, `QuotaExhausted`, `DiagnosticSink`, `FastPathUnavailable`, `UnknownWorker`, `WrongPhase`, `StaleRevision` | closed |
| `Phase` | `Prepared`, `Running`, `Revoked`, `Quiesced`, `Reclaimed` | monitor |
| `Worker` | `{id, session, slot, profile, phase, quota_limit: Nat, quota_used: Nat}` | monitor |
| `State` | `{revision, identity: HostIdentity.State, workers, next_worker}` | monitor |

The structural argument. Each point holds from the type definitions, not
from a comment:
1. No transition has a function-typed, template, decision, commit-result,
   plan, rights, or profile parameter that the target fills. The only
   target-filled parameters are `Fact`, `TargetReport`, `+List<RouteFact>`
   (inside `Inventory`), the transport's session id, and a decoded
   `HostWire.Message`. None of their fields is a decision; each is an
   identity, a count, a native-support bit set, or a Boolean. A binding
   therefore has nothing to put a policy into.
2. `Profile` is a separate monitor parameter of `admit_worker`.
   `TargetReport` has no profile field, so a target cannot name, select, or
   downgrade the profile. Its facts are only compared against the profile.
3. `Effect` is closed, with one variant here. There is no native write,
   publish, or diagnostic effect. `native_write_offered` has no accepting
   branch, so the fast publication route has no value to return. Task 4's
   publication effect is to carry a `DataOS.commit_from_capability` result.
4. `Denied` has no effects field. Effects exist only in `Admitted`, and the
   law `primitive_denied_emits_nothing` states it about the transition's
   output.
5. Remaining gap: Bend datatypes are public, so a target can construct an
   `Effect` itself. The header and the traceability record this as a
   reviewed-only section 2 obligation: a target-constructed `Effect` is not
   authorization, and the binding must execute only effects from an
   `Admitted` step this monitor returned.

## Family 1: session binding

- `open_session(state, rev, report, fact)`:
  - order: revision (`StaleRevision`), then `family_session()` in
    `report.supported_families` (`UnsupportedFamily`), then a
    `SessionEvidence` fact (`WrongPhase`), then
    `HostIdentity.bind_session`. A HostIdentity rejection becomes
    `Identity{reason}`.
  - On acceptance it commits the new identity table, advances the revision
    once, and emits no effect.
- `use(state, rev, session, message, now)`:
  - It is read-only and returns a `HostIdentity.Resolution`.
  - It resolves `W.Message.ref(message)` through `HostIdentity.resolve`
    only. The claimed subject is never read. A stale revision gives
    `Unresolved{StaleRevision}`.
- Checks:
  - `PH-002 open_session binds the evidence's caller through HostIdentity with no effect`
  - `PH-001 open_session on a target without the session family denied UnsupportedFamily`
  - `PH-002 open_session with evidence inherited from an unbound session denied Identity UnknownSession`
  - `PH-001 open_session given a fact other than SessionEvidence denied WrongPhase`
  - `PH-002 a Use claiming another subject on the client's session resolves to the client's caller`
  - `PH-002 the worker's Use of its input resolves to the owner's caller, not the worker session's`
  - `PH-001 Error.equal compares the HostIdentity reason inside Identity`
  - the two stale-revision checks below.

## Family 2: worker domains

`admit_worker(state, rev, profile, quota_limit, report, inventory, session, ref, now)`.
The order below is first-failure.

| Step | Condition | Reason |
| --- | --- | --- |
| 0 | revision | `StaleRevision` |
| 1 | `ref` resolves on `session` through `HostIdentity.resolve` | `Identity{reason}` |
| 2 | the fact is an `Inventory` | `WrongPhase` |
| 3 | `required_families` within `supported_families` | `UnsupportedFamily` |
| 4 | `required_controls` within `established_controls` | `MissingControl` |
| 5 | an `Accelerator` backend has `control_accelerator_isolation()` established, whether or not the profile lists it | `UnisolatedAccelerator` |
| 6 | every inventory route is mediated | `UnmediatedRoute` |
| commit | records `Worker{next_worker, session, resolved slot, profile, Running, quota_limit, 0}`, advances `revision` and `next_worker` once each, and returns exactly `[DeliverInputs{worker, slot}]` | |

Plaintext delivery is therefore the last step of an accepted admission.
There is no downgrade: a CPU admission is a separate request whose profile
says `Cpu`, and the worker records that profile.

The runtime transitions:
- `charge(state, rev, ResourceRequest{worker, amount})`. Order: revision,
  then the fact variant (`WrongPhase`), then exactly one worker with that id
  (`UnknownWorker`, counted, so a duplicated id is also `UnknownWorker`),
  then `Running` (`WrongPhase`), then
  `quota_used + amount <= quota_limit` (`QuotaExhausted`). Acceptance
  changes only `quota_used` and the revision, and emits no effect.
- `diagnostic(state, rev, Diagnostic{worker, public})`. Order: revision,
  then the fact variant, the worker, and `Running`. A public emission is
  then denied `DiagnosticSink`. A non-public one is accepted with no effect:
  the revision advances and nothing else changes.
- `native_write_offered(state, rev, NativeWriteOffered{worker})`. Order:
  revision, then the fact variant. It is always `FastPathUnavailable`.

Checks, by group:
- Accepted:
  - `PH-006 an admission with every control established records the worker Running and delivers only its input slot`
  - `PH-014 a CPU admission without accelerator isolation records backend Cpu`
  - `PH-006 the lower report meets the lower profile when that profile is the admitted one`
  - `PH-014 the same accelerator profile is admitted once isolation is established`
- Missing control, each bit missing alone: six checks named
  `PH-006 <control> missing alone denied MissingControl with no effect`, for
  address isolation, no ambient network, output mediation, the quota
  control, no inherited routes, and accelerator isolation.
- Target report:
  - `PH-006 a report without the publication family denied UnsupportedFamily with the monitor profile unchanged`
  - `PH-006 a report meeting only a lower profile denied for the admitted profile with the monitor profile unchanged`
  - `PH-006 a report with every family but only the lower profile's controls denied MissingControl`
- Inventory:
  - `PH-006 one unmediated route among mediated ones denied UnmediatedRoute before any DeliverInputs`
  - `PH-006 an unmediated first route denied UnmediatedRoute`
  - `PH-006 an admission given a fact other than an Inventory denied WrongPhase`
- Identity:
  - `PH-006 an admission presenting an input reference the worker session does not hold denied Identity NotHolder`
  - `PH-006 an admission presenting the worker's input reference on the client session denied Identity NotHolder`
- Accelerator:
  - `PH-014 an accelerator profile not listing isolation, on a target without it, denied UnisolatedAccelerator and not downgraded`
- Quota:
  - `PH-007 a charge within the quota adds only to quota_used and emits nothing`
  - `PH-007 a charge reaching exactly the quota limit is accepted`
  - `PH-007 a charge beyond the quota denied QuotaExhausted with the state unchanged and no effect`
  - `PH-007 after exhaustion the worker's phase and its input entry's rights are unchanged`
  - `PH-007 a charge for a worker never admitted denied UnknownWorker`
  - `PH-007 a charge naming a duplicated worker id denied UnknownWorker`
  - `PH-007 a charge from a revoked worker denied WrongPhase`
  - `PH-007 a charge given a fact other than a ResourceRequest denied WrongPhase`
- Diagnostics:
  - `PH-007 a public diagnostic from a running worker denied DiagnosticSink`
  - `PH-007 a non-public diagnostic is accepted with no effect`
  - `PH-007 a diagnostic from a worker never admitted denied UnknownWorker`
  - `PH-007 a diagnostic from a revoked worker denied WrongPhase`
  - `PH-007 a diagnostic given a fact other than a Diagnostic denied WrongPhase`
- Fast path:
  - `PH-001 a native write offer for an admitted worker denied FastPathUnavailable`
  - `PH-001 a native write offer given another fact denied WrongPhase`
- Stale revision, one check for each transition:
  - `PH-001 open_session at a stale revision denied StaleRevision`
  - `PH-001 use at a stale revision denied StaleRevision`
  - `PH-006 admit_worker at a stale revision denied StaleRevision`
  - `PH-007 charge at a stale revision denied StaleRevision`
  - `PH-007 diagnostic at a stale revision denied StaleRevision`
  - `PH-001 native_write_offered at a stale revision denied StaleRevision`
- Order:
  - `PH-006 order: the input reference precedes the inventory fact`
  - `PH-006 order: the inventory fact precedes the families`
  - `PH-014 order: accelerator isolation precedes the route inventory`
  - `PH-007 order: the worker's phase precedes its quota`
  - `PH-007 order: the worker's phase precedes the diagnostic sink`
  - Two more orders are pinned elsewhere. "Families before controls" is
    pinned by the lower-report check. "Controls before accelerator" is
    pinned by the accelerator-isolation missing-control check.

Every denial uses `denied`: the exact reason, full state equality with the
input (the identity table compared through `HostIdentityTests`' equality
helpers), and empty effects. Identity reasons are compared directly with
`HostIdentity.Error.equal`.

Fixtures have distinct values per field:
- host 51, incarnation 73;
- subjects 31 to 33;
- sessions 300 to 302, with 309 never bound;
- slots 21 and 22, handle 61, rights 6 and 4;
- times 120, 170, and 400;
- profile ids 399 to 404;
- worker 81, with 89 never admitted;
- quota 500, with charges 200, 300, and 301.

The identity table is built by HostIdentity transitions (bind, bind, mint,
delegate) from a seeded supervisor session. The worker session is
non-delegable and has the client's subject with another token. The plan and
tokens are reused from `TransferTests`. The equality helpers are reused from
`HostIdentityTests`, by import.

## Removal map

I copied the tree into a scratch directory. There I applied 40 mutants to
`HostPrimitives.bend`, one at a time, each an exact one-site replacement,
and ran `bend HostPrimitivesTests.bend`. Each mutant does one of these:
removes a denial branch (forces its condition true or makes it accept),
swaps its reason, weakens a comparison, turns the counted worker lookup into
first-match, or breaks a commit.

The first run, against the 45-check version, left two survivors:
- The worker session hard-coded in the admission's resolve. I closed it with
  `PH-006 an admission presenting the worker's input reference on the client session denied Identity NotHolder`.
- `Error.equal` ignoring the reason inside `Identity`. I closed it with
  `PH-001 Error.equal compares the HostIdentity reason inside Identity`, and
  `denied_identity` now compares the inner reason directly.

I then added the five order checks. In the final run against all 52 checks,
every one of the 40 mutants was killed by a named check. None was killed by
a compile error.

| Mutant | First failing check |
| --- | --- |
| open_session revision | `PH-001 open_session at a stale revision denied StaleRevision` |
| open_session family | `PH-001 open_session on a target without the session family denied UnsupportedFamily` |
| open_session fact variant accepted | `PH-001 open_session given a fact other than SessionEvidence denied WrongPhase` |
| open_session identity denial accepted | `PH-002 open_session with evidence inherited from an unbound session denied Identity UnknownSession` |
| use revision | `PH-001 use at a stale revision denied StaleRevision` |
| admit revision | `PH-006 admit_worker at a stale revision denied StaleRevision` |
| admit identity reason swapped | `PH-006 an admission presenting an input reference the worker session does not hold denied Identity NotHolder` |
| admit resolves on a fixed session | `PH-006 an admission presenting the worker's input reference on the client session denied Identity NotHolder` |
| admit inventory variant accepted | `PH-006 an admission given a fact other than an Inventory denied WrongPhase` |
| admit families | `PH-006 a report without the publication family denied UnsupportedFamily with the monitor profile unchanged` |
| admit controls | `PH-006 address isolation missing alone denied MissingControl with no effect` |
| accelerator isolation always true | `PH-014 an accelerator profile not listing isolation, on a target without it, denied UnisolatedAccelerator and not downgraded` |
| accelerator step skipped | same |
| admit routes | `PH-006 one unmediated route among mediated ones denied UnmediatedRoute before any DeliverInputs` |
| routes: head only | same |
| routes: tail only | same |
| admission emits nothing | `PH-006 an admission with every control established records the worker Running and delivers only its input slot` |
| unmediated route accepted with DeliverInputs | `PH-006 one unmediated route among mediated ones denied UnmediatedRoute before any DeliverInputs` |
| next_worker not advanced | `PH-006 an admission with every control established records the worker Running and delivers only its input slot` |
| charge revision | `PH-007 charge at a stale revision denied StaleRevision` |
| charge fact-variant reason | `PH-007 a charge given a fact other than a ResourceRequest denied WrongPhase` |
| charge unknown-worker reason | `PH-007 a charge for a worker never admitted denied UnknownWorker` |
| worker lookup first-match | `PH-007 a charge naming a duplicated worker id denied UnknownWorker` |
| charge phase | `PH-007 a charge from a revoked worker denied WrongPhase` |
| charge quota | `PH-007 a charge beyond the quota denied QuotaExhausted with the state unchanged and no effect` |
| quota `<=` made `<` | `PH-007 a charge reaching exactly the quota limit is accepted` |
| quota ignores prior use | `PH-007 a charge beyond the quota denied QuotaExhausted with the state unchanged and no effect` |
| charge does not record use | `PH-007 a charge within the quota adds only to quota_used and emits nothing` |
| charge changes phase | same |
| diagnostic revision | `PH-007 diagnostic at a stale revision denied StaleRevision` |
| diagnostic fact-variant reason | `PH-007 a diagnostic given a fact other than a Diagnostic denied WrongPhase` |
| diagnostic unknown worker accepted | `PH-007 a diagnostic from a worker never admitted denied UnknownWorker` |
| diagnostic phase | `PH-007 a diagnostic from a revoked worker denied WrongPhase` |
| public diagnostic accepted | `PH-007 a public diagnostic from a running worker denied DiagnosticSink` |
| non-public diagnostic denied | `PH-007 a non-public diagnostic is accepted with no effect` |
| native write revision | `PH-001 native_write_offered at a stale revision denied StaleRevision` |
| native write accepted | `PH-001 a native write offer for an admitted worker denied FastPathUnavailable` |
| native write variant reason | `PH-001 a native write offer given another fact denied WrongPhase` |
| `is_running` true for any phase | `PH-007 a charge from a revoked worker denied WrongPhase` |
| `Error.equal` ignores the Identity reason | `PH-001 Error.equal compares the HostIdentity reason inside Identity` |

The order checks were not run as swap mutants; they pin the order by
construction (each input fails two steps).

## Laws

- `primitive_denied_preserves_state`:
  `{HostPrimitives.Step.state(HostPrimitives.Denied{state, reason}) == state : HostPrimitives.State}`.
- `primitive_denied_emits_nothing`:
  `{HostPrimitives.Step.effects(HostPrimitives.Denied{state, reason}) == [] : List<&2, HostPrimitives.Effect>}`.

Rationale, in the module header and above each law in `LAWS.bend`:
- Both laws hold by computation of the accessors, for every state and every
  reason.
- They fix the contract that every denial path relies on: a denial hands
  back the caller's own state and yields no effect for a target to execute.
  So an effect exists only on an admitted transition.
- The second law is a statement about the transition's output, `Step.effects`,
  which is the list the binding executes. It is not a comment.
- Neither law asserts which transitions deny, that a reason is correct, or
  that an admitted step's effects are correct; the named checks do. That a
  binding executes only effects this monitor returned is a host obligation.

The proofs are `def Laws.primitive_denied_preserves_state(state, reason): {==}`
and `def Laws.primitive_denied_emits_nothing(state, reason): {==}`, with no
hole.

I checked that both laws discriminate, in a scratch copy:
- Stating the effects law as `== [DeliverInputs{1n, 1n}]` made
  `bend PROOF.bend` print `SOME PROOFS FAIL` (expected `[]`).
- Making `Step.effects` of `Denied` return a non-empty list also failed.

## Verification

Counts:

| | PASS lines |
| --- | --- |
| Before this task | 937 (782 + 63 + 92) |
| After this task | 989 (782 plus 207 new checks = 989; this task adds 52) |

- 0 of the 782 PASS lines in `verification/tests-js.txt` are missing.
- No PASS line is duplicated.

Commands and results:
- `bend Tests.bend` (JS): exit 0, 989 PASS. The last lines are
  `Property: 324 checks passed; 320 graph cases, each checked against CPU and Bend parallel producers`
  and `ALL LIBRARY TESTS PASSED`.
- Native:
  `bend Tests.bend -o ../writ-build/portable-host-contract/tests-native && ../writ-build/portable-host-contract/tests-native +RTS --threads 4 --gpu off`.
  The build took 8m49s and exited 0; the run exited 0 with 989 PASS and the
  same last two lines. Its PASS lines are identical, in order, to the JS
  run's. This is CPU execution, not a GPU test.
- `bend HostPrimitivesTests.bend` standalone: 52 PASS, then
  `HostPrimitives: 52 checks passed`.
- `bend PROOF.bend`: `ALL PROOFS CHECK` / `Use --verdict for mathematical validity.`
- `bend PROOF.bend --verdict`: not available. It printed `Error: BendTT infrastructure: the kernel did not build (lean: Executable not found in $PATH: "lean"); --verdict needs Lean v4.34.0 (elan toolchain leanprover/lean4:v4.34.0), or $BENDTT set to a built kernel`.
- `~/.bun/bin/bunx @fission-ai/openspec@1.16.0 validate --all --strict --no-interactive`:
  `Totals: 44 passed, 0 failed (44 items)`.

## Rulings applied and concerns

1. Forced rename: `Done` became `Admitted`. Base already declares a
   constructor `Done{value}`, and Bend rejected `Step.Done` as a duplicate
   declaration. So `Step` is `Admitted{state, effects}` | `Denied{state, reason}`.
   The shape and meaning are unchanged. I chose the word because the ruling
   says an effect is emitted only on an admitted transition.
2. Transitions take a `Fact` value, not unpacked fields, so the binding's
   input is visibly the observation type. A fact of the wrong variant is
   denied `WrongPhase`, read as "not the observation this step of the
   protocol consumes". The closed `Error` set has no closer reason. Each
   such branch has a named check.
3. Admission takes the worker's input reference and its native session, and
   stores the slot and session that `HostIdentity.resolve` accepted. The
   stored worker facts are then monitor-derived, not caller values; a
   resolution failure is `Identity{reason}`. The brief did not fix this
   signature. The other stored values are `profile` and `quota_limit` (the
   monitor's admitted request), the monitor-allocated worker id, and the
   accumulated `quota_used`, which only grows within the limit.
4. "A report claiming a lower profile id": `TargetReport` has no profile
   field, so a target can make that claim only as facts that satisfy a
   lower profile. The test uses such a report:
   - it is accepted when the lower profile is the admitted one;
   - it is denied (`UnsupportedFamily`) for the admitted profile;
   - full state equality shows that the monitor profile is unchanged.
5. Runtime facts require a `Running` worker. Workers are admitted directly
   into `Running`, so `Prepared` is unused in this task; Task 4's
   revocation family will use the other phases. The `WrongPhase` checks use
   hand-built `Revoked` states.
6. Not checked, and possibly for Task 4 or a controller ruling:
   - whether the worker session is non-delegable;
   - whether two workers may be admitted on one input slot;
   - whether a profile must list `family_worker()`.
   Profiles are monitor-owned, so a profile requiring no controls admits
   without confinement; that is policy and is not decided here.
7. `HostPrimitives.bend` is 735 lines, against an estimate of about 300.
   The difference is the header and per-step helpers in the HostIdentity
   style. Tests have 52 checks, against an estimate of about 28; the extra
   checks are wrong-variant, unknown-worker, phase, order, and boundary
   checks needed to pin every branch.
8. The `use` stale-revision result reuses `HostIdentity.StaleRevision`,
   because `use` returns a `HostIdentity.Resolution`.

## Fix round 1

Inputs: task-3-review.md (12 findings, both verdicts NEEDS_FIXES) and the
controller's rulings for findings 1 to 3, 4, 5, 6, and 7. Every finding is
applied. Files changed: HostPrimitives.bend, HostPrimitivesTests.bend, and
the traceability file. HostIdentity.bend is not changed: its existing
`NotDelegable` denial is the delegation check that ruling 1 needs (see
finding 1). LAWS.bend, PROOF.bend, and Tests.bend are unchanged in this
round. HostPrimitivesTests now has 91 checks (52 before).

### Model changes

- The configured profile table is monitor state. `State` is now
  `{revision, identity, profiles: Profiles, workers, next_worker}`. The type
  `Configured{profile, quota_limit}` pairs each profile with its quota.
  `empty(identity, profiles)` fixes the table, and no transition writes it.
  `admit_worker(state, rev, profile_id, report, inventory, session, ref, now)`
  resolves the id in that table (a counted lookup). No request field carries
  controls, families, a backend, or a quota.
- `valid(State)` is public:
  - `HostIdentity.valid` holds for the identity table;
  - each profile id is configured once;
  - each worker id is nonzero, below `next_worker`, and unique;
  - no two unreclaimed workers share an input entry (same host,
    incarnation, and slot).

  Every transition, `use` included, gates on revision and `valid` together
  (`current`). A state failing `valid` is denied `StaleRevision`, the
  HostIdentity pattern.
- `Worker.slot` is replaced by `Worker.input: W.Ref`, and `DeliverInputs` is
  now `{worker, input: W.Ref}`. The reference is rebuilt from monitor state
  by `entry_ref`: host, current incarnation, the entry's slot, and its
  generation.
- `charge` and `diagnostic` take `now`. They re-resolve the worker's input
  on its own session after the phase step.
- `use` returns `UseResult` (`Granted{entry, caller}` | `Refused{reason}`).
- `Error` gains five reasons: `UnknownProfile`, `DelegableSession`,
  `SlotOccupied`, `RightsNotHeld`, and `OperationNotPermitted`.
- New named constants: `no_controls()` and `no_right()` (both 0), and
  `right_read()` 1, `right_write()` 2, `right_execute()` 4.
  `operation_right` maps each wire operation to its right bit.
- Admission order: gate, profile (UnknownProfile), protected profile
  (MissingControl), identity, non-delegable session (DelegableSession), free
  slot (SlotOccupied), inventory fact, families, controls, accelerator,
  routes, commit.
- Use order: gate, then the message must be a `Use` (WrongPhase), identity,
  held rights (RightsNotHeld), and operation (OperationNotPermitted).
- Runtime order: gate, fact, worker, phase, re-resolution, then the quota or
  the sink.

### Finding-by-finding closure

1. CLOSED (ruling 1a). `a_delegable` denies an admission whose presenting
   session is bound delegable, with `DelegableSession`. The session lookup's
   non-`OneSession` arm is unreachable after the resolve step and is
   commented as such. Delegation from a worker session is denied by
   HostIdentity's existing `d_delegable`. An admitted worker's session is
   always non-delegable, so no HostIdentity change was needed.
   - Checks:
     - `PH-007 an admission on a delegable session denied DelegableSession with no effect` (the E1 shape);
     - `PH-007 after admission a delegation from the worker session denied NotDelegable`;
     - `PH-007 order: the delegable session precedes the occupied slot`.
   - Header Authority paragraph and PH-007 traceability row updated. That
     `SessionEvidence.delegable` is reported truthfully stays a section 2
     host obligation (see concern R1).
2. CLOSED (ruling 1b). At most one unreclaimed worker per input entry. Step
   5 (`occupied`) and a `valid` clause enforce it.
   - Checks:
     - `PH-006 a second admission on an occupied input slot denied SlotOccupied with no DeliverInputs` (E2);
     - `PH-006 an input held by a running worker listed after a reclaimed one denied SlotOccupied`;
     - `PH-006 a worker on another slot does not block admission on the input`;
     - `PH-006 an input whose earlier worker was reclaimed admits a new worker`;
     - `PH-006 valid rejects two unreclaimed workers on one input`;
     - `PH-006 order: the occupied slot precedes the inventory fact`.
3. CLOSED (ruling 1c). `protects` requires the profile to list
   `family_worker()` and to require at least one control; otherwise the
   admission is denied MissingControl.
   - Checks:
     - `PH-006 a profile not listing the worker family denied MissingControl with no effect`;
     - `PH-006 a profile requiring no controls admits nothing` (E3: profile 406 against `TargetReport{0, 0}` and `Inventory{[]}`);
     - `PH-006 order: the protected-profile check precedes the input reference`.
4. CLOSED (ruling 2, option a). The profile and its quota are monitor state,
   as described above. The caller names an id only; an unknown id is
   denied.
   - Checks:
     - `PH-001 an admission naming a profile id the monitor has not configured denied UnknownProfile`;
     - `PH-001 order: the profile id precedes the input reference`;
     - `PH-001 valid rejects a profile id configured twice`.
   - The header's structural bullet and the PH-001 row are rewritten. The
     remaining point is a reviewed-only host obligation: which configured
     profile id a request names comes from the admitted request (see
     concern R2).
   - The original report's structural point 2 is superseded by this
     paragraph.
5. CLOSED (ruling 3). `use` accepts only a wire `Use`. It requires the
   requested rights to be within the entry's rights, and the operation's
   right to be within the requested rights. An operation outside the
   wire's set maps to `no_right()` and is refused.
   - Checks:
     - `PH-002 a Use requesting rights the entry lacks denied RightsNotHeld` (E4 shape);
     - `PH-002 a Use for a write outside its requested rights denied OperationNotPermitted`;
     - `PH-002 a Use for a read outside its requested rights denied OperationNotPermitted`;
     - `PH-002 a Use naming an operation outside the wire's set denied OperationNotPermitted`;
     - `PH-002 a read and a write within the root's rights are granted`;
     - `PH-001 use given a Delegate message denied WrongPhase` (E5);
     - `PH-002 a Use of the worker's input on the client session denied Identity NotHolder`;
     - `PH-002 order: the held rights precede the operation`.
   - Fixture change: the root's rights are now 7 (read, write, execute), so
     that a granted read exists.
6. CLOSED (ruling 4). The `valid` gate is described above, with one
   `valid rejects ...` check per clause:
   - `PH-001 valid rejects a state whose identity table is not valid`
     (HostIdentityTests' `widened_child`, the E6 table);
   - `... worker id 0`;
   - `... a worker id not below next_worker` (E8);
   - `... two workers under one id`;
   - `... two unreclaimed workers on one input`;
   - `... a profile id configured twice`.

   `PH-001 states built by the transitions satisfy valid` covers base,
   admitted, charged, retired, after a diagnostic, after open_session, and
   reclaimed-and-running. One gate check per transition on an invalid state:
   - `PH-006 an admission over an identity table that is not valid denied StaleRevision`;
   - `PH-001 open_session on a state that is not valid denied StaleRevision`;
   - `PH-001 use on a state that is not valid denied StaleRevision`;
   - `PH-007 a charge on a state that is not valid denied StaleRevision`;
   - `PH-007 a diagnostic on a state that is not valid denied StaleRevision`;
   - `PH-001 a native write offer on a state that is not valid denied StaleRevision`.

   The duplicate-worker case is now rejected by `valid`. So the earlier
   check `PH-007 a charge naming a duplicated worker id denied UnknownWorker`
   is replaced by the valid and gate checks, and the counted lookup's
   `ManyWorkers` arm is unreachable after the gate (commented).
7. CLOSED (ruling 5). The order is pinned by a test, not dropped. `revoked()`
   now has `quota_used` 200, so a 301 charge fails both the phase step and
   the quota step. The swap mutant ("charge phase/quota swapped") is now
   killed by `PH-007 order: the worker's phase precedes its quota`. Two new
   order checks were added for the new re-resolution step:
   - `PH-007 order: the input's re-resolution precedes the quota`;
   - `PH-007 order: the input's re-resolution precedes the diagnostic sink`.
8. CLOSED (first option). `charge` and `diagnostic` re-resolve the worker's
   input through `HostIdentity.resolve` on the worker's session at `now`.
   An unresolved input is `Identity{reason}`.
   - Checks:
     - `PH-007 a charge after the worker's input was retired denied Identity Retired` (E7);
     - `PH-007 a diagnostic after the worker's input was retired denied Identity Retired`;
     - `PH-007 a charge at the input's expiry denied Identity Expired`.
9. CLOSED. `DeliverInputs{worker, input: W.Ref}` carries the full entry
   reference, rebuilt from the table. `effect_equal` compares it, and every
   accepted check compares `[DeliverInputs{81, input_ref()}]`. Mutants that
   zero the generation or the whole reference are killed.
10. CLOSED (kept, tested). `Prepared` is kept for Task 4, and the header
    says no transition here produces it.
    - Check: `PH-007 a charge from a prepared worker denied WrongPhase`.
    - The `is_running` mutant is killed.
11. CLOSED. The PH-005 row now says the destination recheck is
    "re-run by HostPrimitives (Task 4, `publish`, via `DataOS.commit_from_capability`)".
    The PH-001 admission row's coverage boundary now says inputs are
    delivered to a confined worker without a plan recheck, and that the
    plan-failure part is Task 4's publication check. The header says the
    same.
12. CLOSED.
    - Grammar: "an `Admitted` step" in both places.
    - The `Identity NotHolder` admission checks moved to a new
      `identity_checks` group.
    - The fixture header lists the exact profile ids (399, 402, 403, 404,
      405, 406, and 408 never configured).
    - Route kinds are now 91 to 94.
    - `effect_equal` carries a comment that each Task 4 variant needs its
      own arm. A `_ _` arm on a one-constructor match would be an
      unreachable pattern.
    - The optional transition-level law was not added: the Global
      Constraints allow new laws only where the task says so (see concern
      R4).

### Removal map, round 1

I applied 74 mutants in a scratch copy, one at a time, to every changed or
new branch, together with the earlier branches that were rewritten. They
include swap mutants for the use rights/operation order, the delegable/slot
order, and the charge phase/quota order. The first run killed 71. Three
survived:
- "use: rights/operation swapped". The order check's input did not fail
  both steps. It now uses a read with requested rights 6.
- "occupied: head only". I added the running-after-reclaimed check.
- "same_entry: slot ignored". I added the check that a worker on another
  slot does not block admission on the input.

In the final run against 91 checks, all 74 mutants were killed by named
checks, none by a compile error.

Source-reviewed only, because these arms are unreachable after the gate or
the resolve step:
- the non-`OneSession` arm of `a_session`;
- the `ManyWorkers` arms of `c_worker` and `g_worker`;
- the `ManyProfiles` arm of `a_profile`.

`entry_ref` against the presented reference is an equivalent mutant,
because resolve accepts only a reference equal to the entry's identity.

| Mutant | First failing check |
| --- | --- |
| gate: valid dropped | `PH-006 an admission over an identity table that is not valid denied StaleRevision` |
| gate: revision dropped | `PH-001 open_session at a stale revision denied StaleRevision` |
| valid: identity clause | `PH-001 valid rejects a state whose identity table is not valid` |
| valid: profile clause | `PH-001 valid rejects a profile id configured twice` |
| valid: worker id nonzero | `PH-001 valid rejects worker id 0` |
| valid: worker id below next | `PH-001 valid rejects a worker id not below next_worker` |
| valid: worker id unique | `PH-001 valid rejects two workers under one id` |
| valid: one unreclaimed worker per input | `PH-006 valid rejects two unreclaimed workers on one input` |
| valid: reclaimed exemption dropped | `PH-006 an input whose earlier worker was reclaimed admits a new worker` |
| open_session family | `PH-001 open_session on a target without the session family denied UnsupportedFamily` |
| open_session fact variant | `PH-001 open_session given a fact other than SessionEvidence denied WrongPhase` |
| open_session identity denial accepted | `PH-002 open_session with evidence inherited from an unbound session denied Identity UnknownSession` |
| use: message type | `PH-001 use given a Delegate message denied WrongPhase` |
| use: identity reason | `PH-002 a Use of the worker's input on the client session denied Identity NotHolder` |
| use: held rights | `PH-002 a Use requesting rights the entry lacks denied RightsNotHeld` |
| use: operation | `PH-002 a Use for a write outside its requested rights denied OperationNotPermitted` |
| use: rights/operation swapped | `PH-002 order: the held rights precede the operation` |
| op: unknown operation zero check | `PH-002 a Use naming an operation outside the wire's set denied OperationNotPermitted` |
| op: read arm | `PH-002 a read and a write within the root's rights are granted` |
| op: read arm absent | `PH-002 a read and a write within the root's rights are granted` |
| op: write arm | `PH-002 a read and a write within the root's rights are granted` |
| op: execute arm absent | `PH-002 a Use claiming another subject on the client's session resolves to the client's caller` |
| admit: profile lookup accepts unknown | `PH-001 an admission naming a profile id the monitor has not configured denied UnknownProfile` |
| admit: protected forced | `PH-006 a profile not listing the worker family denied MissingControl with no effect` |
| protects: worker family dropped | `PH-006 a profile not listing the worker family denied MissingControl with no effect` |
| protects: controls dropped | `PH-006 a profile requiring no controls admits nothing` |
| admit identity reason | `PH-006 an admission presenting an input reference the worker session does not hold denied Identity NotHolder` |
| admit resolves on fixed session | `PH-006 an admission presenting the worker's input reference on the client session denied Identity NotHolder` |
| admit: delegable allowed | `PH-007 an admission on a delegable session denied DelegableSession with no effect` |
| admit: slot check dropped | `PH-006 a second admission on an occupied input slot denied SlotOccupied with no DeliverInputs` |
| occupied: reclaimed exemption dropped | `PH-006 an input whose earlier worker was reclaimed admits a new worker` |
| occupied: head only | `PH-006 an input held by a running worker listed after a reclaimed one denied SlotOccupied` |
| same_entry: slot ignored | `PH-006 a worker on another slot does not block admission on the input` |
| delegable/slot swapped | `PH-007 order: the delegable session precedes the occupied slot` |
| admit inventory variant | `PH-006 an admission given a fact other than an Inventory denied WrongPhase` |
| admit families | `PH-006 a report without the publication family denied UnsupportedFamily with the monitor profile unchanged` |
| admit controls | `PH-006 address isolation missing alone denied MissingControl with no effect` |
| admit accelerator | `PH-014 an accelerator profile not listing isolation, on a target without it, denied UnisolatedAccelerator and not downgraded` |
| admit routes | `PH-006 one unmediated route among mediated ones denied UnmediatedRoute before any DeliverInputs` |
| routes head only | `PH-006 one unmediated route among mediated ones denied UnmediatedRoute before any DeliverInputs` |
| routes tail only | `PH-006 one unmediated route among mediated ones denied UnmediatedRoute before any DeliverInputs` |
| admit emits nothing | `PH-006 an admission with every control established records the worker Running and delivers only its input reference` |
| admit effect names presented ref slot only (generation 0) | `PH-006 an admission with every control established records the worker Running and delivers only its input reference` |
| entry_ref generation dropped | `PH-006 an admission with every control established records the worker Running and delivers only its input reference` |
| admit quota from elsewhere | `PH-006 an admission with every control established records the worker Running and delivers only its input reference` |
| admit does not advance next_worker | `PH-006 an admission with every control established records the worker Running and delivers only its input reference` |
| charge fact variant reason | `PH-007 a charge given a fact other than a ResourceRequest denied WrongPhase` |
| charge unknown worker reason | `PH-007 a charge for a worker never admitted denied UnknownWorker` |
| charge phase | `PH-007 a charge from a revoked worker denied WrongPhase` |
| charge phase/quota swapped | `PH-007 order: the worker's phase precedes its quota` |
| charge re-resolve dropped | `PH-007 a charge after the worker's input was retired denied Identity Retired` |
| charge quota | `PH-007 a charge beyond the quota denied QuotaExhausted with the state unchanged and no effect` |
| charge quota strict | `PH-007 a charge reaching exactly the quota limit is accepted` |
| charge ignores used | `PH-007 a charge beyond the quota denied QuotaExhausted with the state unchanged and no effect` |
| charge does not record use | `PH-007 a charge within the quota adds only to quota_used and emits nothing` |
| charge changes phase | `PH-007 a charge within the quota adds only to quota_used and emits nothing` |
| reresolve on another session | `PH-007 a charge within the quota adds only to quota_used and emits nothing` |
| reresolve at time 0 | `PH-007 a charge at the input's expiry denied Identity Expired` |
| diagnostic fact variant reason | `PH-007 a diagnostic given a fact other than a Diagnostic denied WrongPhase` |
| diagnostic unknown worker reason | `PH-007 a diagnostic from a worker never admitted denied UnknownWorker` |
| diagnostic phase | `PH-007 a diagnostic from a revoked worker denied WrongPhase` |
| diagnostic re-resolve dropped | `PH-007 a diagnostic after the worker's input was retired denied Identity Retired` |
| diagnostic public accepted | `PH-007 a public diagnostic from a running worker denied DiagnosticSink` |
| diagnostic non-public denied | `PH-007 a non-public diagnostic is accepted with no effect` |
| native write accepted | `PH-001 a native write offer for an admitted worker denied FastPathUnavailable` |
| native write variant reason | `PH-001 a native write offer given another fact denied WrongPhase` |
| native write gate dropped | `PH-001 native_write_offered at a stale revision denied StaleRevision` |
| open_session gate dropped | `PH-001 open_session at a stale revision denied StaleRevision` |
| use gate dropped | `PH-001 use at a stale revision denied StaleRevision` |
| admit gate dropped | `PH-006 admit_worker at a stale revision denied StaleRevision` |
| charge gate dropped | `PH-007 charge at a stale revision denied StaleRevision` |
| diagnostic gate dropped | `PH-007 diagnostic at a stale revision denied StaleRevision` |
| is_running any phase | `PH-007 a charge from a revoked worker denied WrongPhase` |
| Error.equal identity ignores inner | `PH-001 Error.equal compares the HostIdentity reason inside Identity` |

### Laws after the fixes

Neither law needed restating. Both are statements about the public
accessors on `Denied`, quantified over every `State` and `Error`. The `valid`
gate adds denial paths but does not change those accessors. `State` gained a
field, and both proofs are still `{==}`. `bend PROOF.bend` prints
`ALL PROOFS CHECK`.

### Verification after the fixes

| | PASS lines |
| --- | --- |
| Before this round | 989 (782 + 207) |
| After this round | 1028 (782 plus 246 new checks = 1028; HostPrimitives 91, up from 52) |

- 0 of the 782 PASS lines in `verification/tests-js.txt` are missing.
- No PASS line is duplicated.

Commands and results:
- `bend Tests.bend` (JS): exit 0, 1028 PASS. The last lines are
  `Property: 324 checks passed; 320 graph cases, each checked against CPU and Bend parallel producers`
  and `ALL LIBRARY TESTS PASSED`.
- Native: `bend Tests.bend -o ../writ-build/portable-host-contract/tests-native && ../writ-build/portable-host-contract/tests-native +RTS --threads 4 --gpu off`: the build and the run both exited 0, with 1028 PASS and the same last two lines. Its PASS lines are identical, in order, to the JS run's. This is CPU execution, not a GPU test.
- `bend HostPrimitivesTests.bend`: 91 PASS, then `HostPrimitives: 91 checks passed`.
- `bend PROOF.bend`: `ALL PROOFS CHECK` / `Use --verdict for mathematical validity.`
- `--verdict`: still unavailable (`lean` is not on PATH).
- OpenSpec 1.16.0, strict: `Totals: 44 passed, 0 failed (44 items)`.

### Remaining concerns, round 1

- R1. `SessionEvidence.delegable` is still a target-reported fact, and the
  admission's non-delegable rule relies on it. The review asked whether
  `open_session` should instead take delegability as a monitor parameter.
  No ruling was given, so I left it target-reported and recorded it as a
  section 2 obligation.
- R2. A request names a configured profile id, under ruling 2. A binding
  that controls the id could name a weaker profile that is still
  configured, and every configured profile still passes the protected
  checks. Binding the id to the admitted request is a reviewed-only host
  obligation.
- R3. Slot occupancy counts only workers that are not `Reclaimed`, and it
  compares host, incarnation, and slot. Whether a slot should instead be
  one-shot is left to Task 4's revocation family.
- R4. The optional transition-level law
  (`Step.effects(native_write_offered(...)) == []`) is provable through the
  helper `n_gate`, but I did not add it, because a new law needs the task
  to call for it.
- R5. `HostPrimitives.bend` is now 1108 lines and the tests 919 lines.
