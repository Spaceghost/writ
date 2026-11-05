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
