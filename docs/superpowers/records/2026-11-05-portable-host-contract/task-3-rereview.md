# Task 3 re-review: fix rounds 1 and 2 (0f4f53c, 1a9a5ca)

Reviewer: task reviewer. Scope: `git diff 48d480b 1a9a5ca` and the "Fix round 1"
and "Fix round 2" sections of task-3-report.md, checked against the twelve
findings in task-3-review.md and the controller's rulings. I re-ran my probes
against a scratch copy of the tree at 1a9a5ca (`Probe2.bend`, which imports
the test fixtures, plus the swap-mutant runner). Both live in the session
scratchpad only.

Result: ALL CLOSED. I found no new defect in the fix rounds. Two non-blocking
notes are at the end.

## Findings

| # | Finding | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Delegable worker session | CLOSED | `a_session`/`a_delegable` (HostPrimitives.bend:1051-1070) read the delegability stored in the identity table. Probe: an admission on the delegable client session 301 with `root_ref` is denied `DelegableSession`. `valid` requires every bound session to be non-delegable (:733-743). |
| 2 | Two workers on one slot | CLOSED | `a_slot` with `occupied` (:636-643, :1011-1018), plus the `occupants` clause in `valid` (:655-664). Probe: a second admission on `admitted()` is denied `SlotOccupied`. |
| 3 | Profile without the worker family, or with no controls | CLOSED | `protects` (:945-947) and `a_protected`. Probes: the session bound under the no-controls profile, on `TargetReport{0, 0}` with `Inventory{[]}`, is denied `MissingControl`. The no-worker-family profile is also denied `MissingControl`. |
| 4 | Caller-supplied profile | CLOSED | `admit_worker` (:1099) has no profile or quota parameter. The profile comes from `State.bindings`, which only `open_session` writes, under a `WorkerRole`, through `State.profiles`, which only `empty` fixes. Probes: a session bound under the accelerator profile, on a CPU-only report, is denied `MissingControl`. A non-delegable session with no binding is denied `UnknownProfile`. |
| 5 | `use` ignores rights, operation, and message type | CLOSED | `u_message`/`u_resolved`/`u_rights`/`u_operation` (:875-921). Probes: `Use` rights 7 on the rights-4 input gives `RightsNotHeld`; a write within the held rights 4 gives `OperationNotPermitted`; a `Delegate` message gives `WrongPhase`. |
| 6 | No `valid` gate | CLOSED | `valid` and `current` (:745-755) gate every transition, `use` included. Probes: a table whose child outlives its parent (999 > 400) fails `valid`, and admission over it is denied `StaleRevision`. A charge on a state with `next_worker` 50 below worker 81 is denied `StaleRevision`. My original E6 table (a child widened to rights 7) is no longer invalid, because the root now has rights 7. So I rebuilt the probe; the suite itself uses HostIdentityTests' `widened_child`. |
| 7 | Phase/quota order check did not pin the order | CLOSED | `revoked()` now has used 200. The swap mutant (quota checked before phase) is killed by `PH-007 order: the worker's phase precedes its quota` (99 of 104 checks pass). |
| 8 | No re-resolution at runtime | CLOSED | `reresolve` in `c_live`/`g_live`. Probe: a charge after the input was retired is denied `Identity{Retired}`. |
| 9 | `DeliverInputs` names only the slot | CLOSED | `DeliverInputs{worker, input: W.Ref}`, with the reference rebuilt by `entry_ref` from the table's host, incarnation, slot, and generation (:951-954). |
| 10 | Dead `Prepared` phase | CLOSED | Kept and documented, and `PH-007 a charge from a prepared worker denied WrongPhase` now covers it. |
| 11 | Traceability promised a Task 3 plan recheck | CLOSED | The PH-005 row now names Task 4 `publish`. The PH-001 boundary says inputs are delivered without a plan recheck, and the header (:118-120) says the same. |
| 12 | Nits | CLOSED | "an `Admitted`", the `identity_checks` group, exact profile ids, route kinds 91 to 94, and the `effect_equal` note. The optional transition-level law was declined under the Global Constraints. That is acceptable. |

## Round-2 paths

- **A target reporting delegable=true for a worker.** `o_worker` (:800-809)
  passes `False{}` to `bind_session` whatever the evidence says. Probe: open
  the worker with `claiming_worker_evidence()` (delegable=true), delegate
  the input to it, then call `I.delegate` from the worker session. It is
  denied `NotDelegable`, and the opened state satisfies `valid`. A mutant
  that binds worker sessions delegable is killed by
  `PH-006 an admission with every control established records the worker Running and delivers only its input reference`.
  For a `ClientRole` session the evidence flag can only narrow: it is passed
  as given, so false stays false, and a client cannot become a worker.
  CLOSED.
- **A later request switching profiles.** No transition after `open_session`
  has a profile field, and `bindings` is written only by
  `with_worker_session`. A mutant that makes `a_bound` ignore the binding
  (it always looks up profile 402) is killed by the first admission check.
  The suite's two-worker-sessions check covers a lookup keyed on the wrong
  session. CLOSED.

## Monitor-supplied inputs

The remaining per-request decision input is `Role` at `open_session`. It is
stated as reviewed-only host obligation (b) in the header (:53-56) and in
the PH-001 traceability row. The other monitor-supplied values are not
decisions. They are the configured profile table given to `empty`
(configuration, which the header names as monitor state), monitor time
`now`, `expected_revision`, and the transport-identified session (an
existing obligation). CLOSED.

## Runs

- `bend Tests.bend` (scratch copy at 1a9a5ca): exit 0. 1041 lines start with
  `PASS`, `HostPrimitives: 104 checks passed`, and the run ends with
  `Property: 324 checks passed; 320 graph cases, each checked against CPU and Bend parallel producers`
  and `ALL LIBRARY TESTS PASSED`.
- `bend PROOF.bend`: `ALL PROOFS CHECK` / `Use --verdict for mathematical validity.`
  LAWS.bend and PROOF.bend are unchanged since 48d480b. `Step`, `Denied`,
  `Step.state`, and `Step.effects` are unchanged, so both laws still state
  the same accessor facts over the extended `State` and `Error`, with
  hole-free `{==}` proofs. `--verdict` was not run, because `lean` is not on
  PATH.
- Traceability: all 104 check names appear exactly once in the
  primitive-interfaces section, and it cites no extra names.
- OpenSpec 1.16.0, strict: `Totals: 44 passed, 0 failed (44 items)`.
- No `@unsafe` and no holes in the diff. The touch list is respected: only
  HostPrimitives.bend, HostPrimitivesTests.bend, the traceability file, and
  the record directory changed.

## Non-blocking notes (no fix required for Task 3)

- HostPrimitives has no transition that wraps `HostIdentity.mint`,
  `delegate`, or `retire`. The tests build primitive states by placing a
  table edited by HostIdentity into a hand-built `P.State` (`base_under`,
  `retired`). In a deployment, those monitor actions would change the
  identity table outside the primitive revision. Task 4's revocation family
  should wrap `retire`, and the controller may want a ruling on whether
  `mint` and `delegate` also need primitive wrappers.
- `a_session`'s non-`OneSession` arm, `a_bound`'s `ManyBindings` arm, and
  `a_profile`'s non-`OneProfile` arm are unreachable from a valid state.
  They are commented, so they are source-reviewed rather than tested. That
  is acceptable.
