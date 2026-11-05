# Task 3 review: HostPrimitives interface types, session binding, worker domains (tasks.md 1.3, first part)

Reviewer: task reviewer (security and proof). Reviewed range `faf9c6b..48d480b`
(commit 48d480b) on `lane/portable-host-contract`. Inputs read: task-3-brief.md,
task-3-report.md, the review package diff, the plan's Global Constraints, the
Task 2 review and re-review (the standard), HostIdentity.bend, HostWire.bend
(`Message`, `Message.ref`), LAWS.bend and PROOF.bend as changed, the PH-001,
PH-006, PH-007, PH-014 deltas, docs/PLATFORMS.md, and AGENTS.md.

Controller rulings accepted and not flagged: `Admitted` instead of `Done`; a
wrong-kind fact denied `WrongPhase`; the `admit_worker` signature. The three
required rulings the implementer has not applied yet are findings 1 to 3.

## Verdict 1, spec compliance: NEEDS_FIXES

What holds:
- Interface types. `Backend`, `Profile`, `TargetReport`, `RouteFact`, `Fact`,
  `Effect`, `Step`, `Error`, `Phase`, `Worker`, and `State` exist as the brief
  specifies (HostPrimitives.bend:123-206). The five family bits and six control
  bits are named helpers (:216-251). `Fact` carries only observations: no
  decision, commit result, plan, rights, or profile. `TargetReport` has no
  profile field. `Effect` is closed with one variant, so there is no native
  write, publish, or diagnostic effect. `Denied` has no effects field.
- Could a binding construct an `Admitted` step or an effect without going
  through a transition? Yes. Bend datatypes are public, so `P.Admitted{s,
  [P.DeliverInputs{w, slot}]}` type-checks anywhere. In this design that is
  unavoidable: the binding is native code outside Bend's type system. What
  prevents misuse is only that the binding executes effects taken from the
  `Step` value the monitor process returned. The header (:38-41) and the
  PH-001 traceability row record this as a reviewed-only section 2 obligation.
  I accept that as the right classification, and it is enough for the effect
  side. The profile is a different matter: see finding 4. It is a transition
  parameter that the same caller supplies, so the "structural" claim
  (:28-31) holds only if the caller is the monitor. That is also a
  reviewed-only obligation, and the module states it as a structural fact.
- Denials. Every brief-listed denial has a named check, and each check
  verifies the exact reason, full state equality (the identity table
  included), and empty effects (`denied`, HostPrimitivesTests.bend). I removed
  seven branches myself in a scratch copy. Each one was killed by a named
  check, and none by a compile error:
  - MissingControl forced true: `PH-006 address isolation missing alone denied MissingControl with no effect`
  - UnmediatedRoute forced true: `PH-006 one unmediated route among mediated ones denied UnmediatedRoute before any DeliverInputs`
  - UnisolatedAccelerator (isolation forced true): `PH-014 an accelerator profile not listing isolation, on a target without it, denied UnisolatedAccelerator and not downgraded`
  - QuotaExhausted forced true: `PH-007 a charge beyond the quota denied QuotaExhausted with the state unchanged and no effect`
  - public diagnostic accepted: `PH-007 a public diagnostic from a running worker denied DiagnosticSink`
  - native write accepted with an effect: `PH-001 a native write offer for an admitted worker denied FastPathUnavailable`
  - open_session family check forced true: `PH-001 open_session on a target without the session family denied UnsupportedFamily`
- Laws. `primitive_denied_preserves_state` (LAWS.bend:71-81) and
  `primitive_denied_emits_nothing` (:83-95) are genuine statements about the
  public accessors, quantified over every `State` and `Error`. The proofs are
  `def Laws.primitive_denied_preserves_state(state, reason): {==}` and
  `def Laws.primitive_denied_emits_nothing(state, reason): {==}`
  (PROOF.bend:47-51). They hold by reduction of `Step.state` and `Step.effects`
  on `Denied`, and neither has a hole. The rationale is in the module header
  (:99-107) and above each law, and says what each law does not assert. The
  laws are as weak as the brief asked: neither says anything about a
  transition. LAWS.bend and PROOF.bend change by additions only.
- Counts. `bend Tests.bend` in a scratch copy of the tree: exit 0, 989 lines
  start with `PASS`, `HostPrimitives: 52 checks passed`, and the last lines are:
  `Property: 324 checks passed; 320 graph cases, each checked against CPU and Bend parallel producers`
  and `ALL LIBRARY TESTS PASSED`. `bend PROOF.bend`: `ALL PROOFS CHECK` /
  `Use --verdict for mathematical validity.` LAWS.bend has 9 laws.
  `--verdict` was not run: `lean` is not on PATH.
- Touch list. The changed files are HostPrimitives.bend,
  HostPrimitivesTests.bend, LAWS.bend, PROOF.bend, Tests.bend (one import and
  one call, after HostIdentity), the traceability file, and the record
  directory. All are on the plan's touch list. tasks.md is untouched, so box
  1.3 is still open. No count pin changed. OpenSpec 1.16.0 strict validation:
  `Totals: 44 passed, 0 failed (44 items)`.

Why NEEDS_FIXES: the three required rulings (findings 1 to 3) are not
implemented. The plan's "re-resolve and recheck rights at use" and "preserves
`valid`" constraints are also not met (findings 5 and 6).

## Verdict 2, security and code quality: NEEDS_FIXES

No denial path emits an effect. I read every `Denied{...}` in the module. Each
one carries the parameter `state`, and only `a_routes` (:510-516) builds a
non-empty effect list. The non-public diagnostic and the accepted charge both
return `[]`. The probes below show that several caller-supplied values become
stored state without enough checks: the worker session, the profile, and the
quota limit. They also show that transitions accept states that HostIdentity
would call invalid.

I ran these probes in a scratch module, `Probe.bend`, which imports the test
fixtures. Each returned TRUE, meaning the gap exists:
- E1: a worker is admitted on the delegable client session with the client's root reference.
- E2: a second worker is admitted on the same input slot.
- E3: `Profile{405, 0, 0, Cpu}` is admitted on `TargetReport{0, 0}` with an empty inventory.
- E4: `use` with `W.Use{input_ref, operation_write, rights 7}` on the rights-4 entry resolves.
- E5: `use` given a `W.Delegate` message resolves.
- E6: `admit_worker` over an identity table that fails `I.valid` (a child widened to rights 7) is accepted and delivers inputs.
- E7: `charge` is accepted after the worker's input entry was retired.
- E8: `charge` is accepted on a state whose `next_worker` (50) does not exceed the worker id (81).

The five order checks, run as swap mutants (each mutant evaluates the later
step first). I also ran the two orders the report says are "pinned elsewhere":
- identity / inventory swapped: killed by `PH-006 order: the input reference precedes the inventory fact`
- inventory / families swapped: killed by `PH-006 order: the inventory fact precedes the families`
- accelerator / routes swapped: killed by `PH-014 order: accelerator isolation precedes the route inventory`
- charge phase / quota swapped: **SURVIVED**, 52 of 52 pass (finding 7)
- diagnostic phase / sink swapped: killed by `PH-007 order: the worker's phase precedes the diagnostic sink`
- families / controls swapped: killed by `PH-006 a report meeting only a lower profile denied for the admitted profile with the monitor profile unchanged`
- controls / accelerator swapped: killed by `PH-006 accelerator isolation missing alone denied MissingControl with no effect`

### Findings, by severity

1. Important (required ruling a). A worker session can be delegable, so a
   worker domain is not a confinement boundary for delegation (PH-007).
   HostPrimitives.bend:557-575 (`a_identity`, `a_gate`) and :583-586
   (`admit_worker`).
   - The only check on the presented `session` is that `HostIdentity.resolve`
     accepts the reference on it. Probe E1: the client session 301, which is
     bound delegable, presents its root reference (rights 6). Admission is
     accepted. The worker is recorded on 301, and `HostIdentity.delegate`
     from 301 then passes `d_delegable`.
   - Delegability itself comes from the target's `SessionEvidence.delegable`
     (:153, :437-438). So the same target that reports the worker's session
     also decides whether that session may delegate.
   - Fix:
     - In `a_identity`, look up the presenting session with
       `I.session_at(I.sessions(identity(state)), session)`. Deny unless it
       is `OneSession` with `I.session_delegable(...) == False{}`. Use a new
       closed-set reason, `DelegableSession{}`, or
       `Identity{I.NotDelegable{}}` if the controller prefers not to extend
       `Error`.
     - Add `PH-007 an admission on a delegable session denied ...` (the E1
       shape), with full state equality and no effect.
     - Add an integration check: after admission, `I.delegate` from
       `session_worker()` with the worker's input reference is denied
       `NotDelegable`.
     - If Task 4 or later adds a primitive-level delegate wrapper, it must
       also deny any source session that hosts a worker.
     - State the rule in the header's Authority paragraph and in the PH-007
       traceability row.
     - Controller question: should `delegable` stay a target-supplied fact
       at all? An alternative is for `open_session` to take it as a separate
       monitor parameter, as `Profile` is.

2. Important (required ruling b). More than one worker can be admitted per
   input slot. HostPrimitives.bend:503-516 (`commit_worker`, `a_routes`).
   - Probe E2: `admit_worker` on `admitted()` with the same `input_ref` is
     accepted. It records worker 82 on slot 22 and emits a second
     `DeliverInputs`. PLATFORMS.md:25 requires "a fixed confined reader".
   - Fix:
     - Add an implementation helper `slot_taken(workers, +slot) -> Bool`.
       It should be true for any worker on that slot whose phase is not
       `Reclaimed`, or for any phase at all if the controller wants slots
       to be one-shot. Make it a step between identity and inventory, which
       is where the resolved slot is known, and deny `SlotOccupied{}` (a
       new closed-set reason).
     - Add `PH-006 a second admission on an occupied input slot denied SlotOccupied with no DeliverInputs`,
       with full state equality, and an order check for where the step sits.
     - Update the admission-order table in the header and the traceability
       row.

3. Important (required ruling c). A profile that does not list the worker
   family admits protected work, and a profile requiring no controls admits
   with no confinement at all. HostPrimitives.bend:547-555 (`a_inventory`)
   and :538-545 (`a_families`).
   - Probe E3: `Profile{405, 0, 0, Cpu}` against `TargetReport{0, 0}` with
     `Inventory{[]}` is accepted and emits `DeliverInputs`.
   - Fix:
     - Before the families step, deny `MissingControl` unless
       `within(family_worker(), profile_families(profile))`.
     - Add a check: `PH-006 a profile not listing the worker family denied MissingControl with no effect`.
     - Add another check: `PH-006 a profile requiring no controls admits nothing`,
       using the E3 shape, denied `MissingControl` with full state equality.
     - Document the ruling in the header admission order and in the
       traceability. Optional, and the controller may prefer it: also require
       the profile to list `family_session()`, because a worker without a
       session family cannot have arrived through `open_session`.

4. Important. The profile and the quota limit are caller parameters, not
   monitor state, so "the target cannot select the profile" holds only if the
   monitor is the caller. HostPrimitives.bend:28-31 (header) and :577-586.
   - `admit_worker(state, rev, profile, quota_limit, report, inventory,
     session, ref, now)` pairs any profile and quota with any input
     reference. Nothing binds the profile to the entry's plan or to an
     admitted request recorded in `State`.
   - The header's edge direction (:57-59) says "native facts -> the family
     transitions here". If the binding drives `admit_worker`, it supplies
     the profile. That is the PH-001 alternate-policy route the types are
     meant to exclude. Together with finding 3 as it stands today, it is a
     confinement bypass.
   - Fix, either of these:
     - (a) Preferred. Make the admitted request monitor state. For example,
       a `requests` table keyed by entry slot, written only by a
       monitor-side transition (a monitor action, like
       `HostIdentity.retire`). `admit_worker` then looks up the profile and
       quota by the resolved slot, so it takes neither as a parameter.
     - (b) Keep the parameters, and rewrite the header bullet and the PH-001
       traceability row so that they do not call this structural. Record
       "the profile and quota passed to `admit_worker` are the monitor's
       admitted request, never a binding value" as a reviewed-only section 2
       obligation, next to the `Effect` one.
   - Either way, the report's structural point 2 should be corrected.

5. Important. `use` ignores the message's operation, rights, and tag.
   HostPrimitives.bend:465-479.
   - Probe E4: a `Use` asking `operation_write()` with rights 7 on the
     rights-4 input entry resolves. Probe E5: a `Delegate` message resolves
     as though it were a use.
   - The Global Constraints require rechecking rights at use. HostIdentity's
     `resolve` does not compare rights (it has no rights parameter), and
     `use` is the only place where the message's requested rights are
     available.
   - Fix:
     - Match the message. For `W.Use{ref, operation, rights, _}`, resolve,
       then deny unless
       `T.word_subset(rights, I.entry_rights(entry))`, and unless the
       operation's right bit is in `rights`. Name that mapping with a
       helper.
     - Any other tag is denied (`WrongPhase`), or routed to its own family
       transition.
     - This needs a result type that can carry a primitive reason, for
       example a `Use` result `Granted{entry, caller}` |
       `Refused{reason: Error}`. Alternatively, reuse
       `I.Unresolved{I.WidenedRights{}}` and document it.
     - Add checks: `PH-002 a Use requesting rights the entry lacks denied ...`;
       `PH-002 a Use for an operation outside its rights denied ...`; and
       `PH-001 use given a Delegate message denied ...`.

6. Important. HostPrimitives has no `valid`, and its transitions accept any
   hand-built state. HostPrimitives.bend:568-575, :643-649, :692-698.
   - The Global Constraints require that "every success ... preserves
     `valid`". HostIdentity's mutating transitions gate on `I.valid`, but
     `admit_worker` reaches the table only through `I.resolve`, which does
     not check `valid`.
   - Probe E6: a table with a widened child (rights 7 under a rights-6
     parent) fails `I.valid`, and `admit_worker` over it still accepts and
     delivers. Probe E8: a worker id at or above `next_worker` is accepted.
   - Fix:
     - Add a public `valid(State)`. It holds when `I.valid(identity)`
       holds, every worker id is nonzero, below `next_worker`, and unique,
       and, after finding 2, no two non-reclaimed workers share a slot.
     - Gate `admit_worker`, `charge`, `diagnostic`, and `open_session` on
       it, together with the revision, as HostIdentity's `current` does.
     - Add one `valid rejects ...` check per clause, plus an admission over
       the E6 table, denied with full state equality.
     - Add a check that every state the tests build by transitions
       satisfies `valid`.

7. Minor. The order check `PH-007 order: the worker's phase precedes its quota`
   does not pin the order. HostPrimitivesTests.bend:606-607 and :301-303.
   - `revoked()` has `quota_used` 0, and `excess_charge()` 301 is within the
     limit of 500, so the input fails only the phase step. The swap mutant
     survives with 52 of 52 checks passing.
   - The report's claim that "each input fails two steps" is therefore false
     for this check, and it was the only order check not killed.
   - Fix: build the revoked fixture with `used_after_first()` (200) as its
     use, or charge more than `quota_limit()`, so that both steps fail. Then
     rerun the swap mutant.

8. Minor. The runtime transitions do not re-resolve the worker's input entry.
   HostPrimitives.bend:651-657 (`charge`) and :700-705 (`diagnostic`).
   - Probe E7: after `I.retire` of slot 22, `charge` for worker 81 is still
     accepted. The Global Constraints say every transition re-resolves.
     Task 4's revocation family will move phases, but until then a worker
     whose input was revoked keeps charging.
   - Fix: get a controller ruling. Either re-check that the worker's slot is
     still live in the identity table (`I.live_at`, counted as `OneEntry`)
     and deny `Identity{I.Retired{}}`, with a check. Or record in the PH-007
     row and the header that runtime facts are gated by phase only, and
     that Task 4's revocation must move the worker out of `Running` in the
     same step that retires its entry.

9. Minor. `DeliverInputs{worker, slot}` names the slot without its
   incarnation or generation. HostPrimitives.bend:162-163 and :513-514.
   - Slots are reused after `restart`. A `DeliverInputs` effect that is
     delayed, replayed, or executed late would then name a different entry.
     The header's "at the revision it returned them" (:41) covers this only
     as prose.
   - Fix: carry the resolved entry's full identity in the effect, either the
     `W.Ref` (host, incarnation, slot, generation) or `slot` plus
     `generation` plus incarnation. Then extend `effect_equal` and the
     accepted checks.

10. Minor. `Prepared` is dead state. HostPrimitives.bend:165-172 and
    :382-388.
    - No transition produces `Prepared`, and admission is atomic. It
      records `Running` and emits `DeliverInputs` in one step, which is
      sound: there is no window between the two.
    - So `Prepared` is not a security gap today. It is untested, though. A
      mutant making `is_running(Prepared{})` true would survive, because
      the `WrongPhase` checks use only `Revoked`.
    - Fix: add `PH-007 a charge from a prepared worker denied WrongPhase`
      using a hand-built `Prepared` state, or remove `Prepared` until Task 4
      gives it a transition. The header (:165-166) should state which of the
      two applies.

11. Minor. The traceability records a promise this task did not keep.
    openspec/traceability/portable-host-contract.md:73.
    - The Task 2 PH-005 row says the Frontend/Transfer destination check is
      "re-run by HostPrimitives (Task 3)". Task 3 runs no plan check:
      `admit_worker` delivers inputs without any `Transfer`/`Frontend`
      admission. The PH-001 "Native transport accepts a request" row lists
      no check in which a failing plan prevents an effect.
    - Per the plan, the re-run belongs to Task 4's `publish` (via
      `DataOS.commit_from_capability`).
    - Fix: change "(Task 3)" to "(Task 4, `publish`)". In the PH-001
      admission row's coverage boundary, say that inputs are delivered to a
      confined worker without a plan recheck, and that the plan-failure part
      of the scenario is Task 4's publication check.

12. Nit. The comments, the grouping, and the fixtures.
    - Header grammar: "a `Admitted` step" (HostPrimitives.bend:21) should be
      "an `Admitted` step", and likewise at :41.
    - The two `Identity NotHolder` admission checks sit in
      `accelerator_checks` (HostPrimitivesTests.bend:497+). Move them to
      their own `identity_checks` group, or into `inventory_checks`.
    - The fixture header says "profile ids 399 to 404"
      (HostPrimitivesTests.bend:41), but only 399, 402, 403, and 404 exist,
      and 400 is `root_expires()`. List the ids exactly.
    - Route kinds 1 to 4 overlap rights 4 and the family and control bits.
      They are descriptive only and no decision reads them, but distinct
      values (for example 91 to 94) would follow the Task 1 and 2 standard.
    - The matches are total. Once Task 4 adds effects, the test's
      single-variant `effect_equal` will need a `_ _` arm.
    - Optional: a transition-level law would carry more weight than the
      accessor laws. For example: for every `s`, `r`, and `f`,
      `Step.effects(native_write_offered(s, r, f)) == []`. It is provable by
      case analysis on the gate and the fact.

## What I verified and ran

- Read all of HostPrimitives.bend and HostPrimitivesTests.bend, the LAWS,
  PROOF, Tests, and traceability diffs, and the relevant HostIdentity and
  HostWire definitions.
- In a scratch copy of the tree: `bend Tests.bend` exited 0 with 989 PASS
  lines, ending `ALL LIBRARY TESTS PASSED`. `bend PROOF.bend` printed
  `ALL PROOFS CHECK`.
- `openspec validate --all --strict --no-interactive` (1.16.0): 44 passed.
- I did not re-run the native build, and I did not run `--verdict`, because
  `lean` is not on PATH.
- Mutants: 7 removals, all killed. 7 order swaps: 6 killed, 1 survived. 8
  probes, E1 to E8, all confirming gaps.
- The scratch copies, `Probe.bend`, and the mutation runner live under the
  session scratchpad only. The worktree was not modified except for this
  file.
