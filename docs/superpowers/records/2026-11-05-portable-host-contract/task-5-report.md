# Task 5 report: shared conformance vectors (tasks.md 1.4)

Status: DONE_WITH_CONCERNS (one model gap found and not fixed because it is
outside the touch list; one over-determined denial; details under Concerns).
Implementer, lane `lane/portable-host-contract`.

## Delivered

- `HostConformanceVectors.bend` (new, 685 lines). Inputs and expected lines
  only: it runs no transition and has no `import ./Test.bend`. It holds the
  `Adapter` type and `adapter_a`/`adapter_b`; the `Logical` names with
  `slot_of`, `logical_of`, `logical_label`; the session evidence and roles,
  the configured profile, target reports, and route inventories; the raw
  little-endian wire bytes (`use_bytes`, `delegate_bytes`, `complete_bytes`,
  built by its own `le_bytes`, not by HostWire's encoder) and the named
  references (`ref_to`, `foreign_ref`, `successor_ref`); the artifact and
  quiescence facts; the fixture context (`fixture_*`: NegotiationTests
  session and ledger, BackplaneTests candidate, FacadeTests DataOS context);
  the two alternative negotiated sessions (`destination_session`,
  `input_session` and their ledgers); and every `expected_*` line with
  `expected_lines`.
- `HostConformanceTests.bend` (new, 1029 lines), registered in `Tests.bend`
  as `HostConformance` (one import, one call, after `HostPrimitives.main()`).
  33 checks, 27 `VECTOR` lines, summary
  `HostConformance: 33 checks passed, 27 vectors emitted`.
- `verification/portable-host-vectors.txt` (new, 27 lines).
- `openspec/traceability/portable-host-contract.md`: module-table row 1.4 and
  a section "Conformance vectors (task 1.4)" listing every vector id with its
  inputs, expected line suffix, and asserting check, plus a requirement table
  with coverage boundaries.
- `openspec/changes/add-portable-host-contract/tasks.md`: box 1.4 checked
  with citations; header line now says 1.1 to 1.4.
- No other file changed. No count pin, manifest, LAWS.bend, or PROOF.bend
  change.

## How a vector runs

Every vector starts from `HostIdentity.empty(host, incarnation)` and runs the
real transitions: `open_session` for each of five sessions, `issue` for each
root, `HostWire.decode_bytes` of the vector's raw bytes, then `use`,
`delegate` (fields taken from a decoded wire `Delegate`), `admit_worker` (with
the decoded `Message.ref`), `seal`, `publish`, and `revoke`, `reconcile`,
`restart`, `quiesce`, `reclaim`, `complete` as the vector requires. The slot
`revoke` names is the slot `use` resolved the decoded reference to. No vector
starts from a hand-built primitive or identity state (no `valid`-rejected
state was needed). Undecodable bytes would become the all-zero reference,
which names nothing; the check
`PH-012 every vector's raw bytes decode through HostWire.decode_bytes on both adapters`
shows that fallback is never taken.

Each vector check asserts, on both adapters: the outcome (reason, or the
accepted result: the state, effects, revision, record, intent); for every
denial, that the returned primitive state equals the input state
(`HostPrimitivesTests.state_equal`, identity table included) with no effect;
for every publication refusal, also that the returned Negotiation session has
the supplied session's revision and the returned ledger the supplied ledger's
revision and payer balance (`L.balance(_, 7)`), and no `Publish`. It then
requires both adapters' rendered lines to equal the expected line. The printed
line is adapter A's, rendered from its actual result.

Identity denials are asserted on `use` (read-only by type, so it has no state
to compare) and again on `admit_worker`, whose returned state is compared
with its input; the vector line names `admit_worker`.

## Vectors

| Vector | Requirement | Line suffix |
| --- | --- | --- |
| PH-009-1 | exact plan binding: baseline publish | `publish accepted invocation=99;input=input` |
| PH-005-1 | PH-005 "A transferred endpoint requests another bucket": session negotiated for destination E | `publish denied CommitRejected` |
| PH-005-2 | exact plan binding: changed input object | `publish denied CommitRejected` |
| PH-005-3 | PH-005: decoded Delegate root to proxy (rights 6) | `delegate accepted slot=proxy` |
| PH-005-4 | PH-005, retained provenance: proxy to worker (rights 4), plan copied unchanged | `delegate accepted slot=narrow` |
| PH-005-5 | exact plan binding, retained provenance: narrower delegated use publishes the same full intent | `publish accepted invocation=99;input=narrow` |
| PH-005-6 | PH-005 "A narrower proxy leaves an old handle alive" / revocation: root still live, all rights | `use accepted slot=root` |
| PH-002-1 | PH-002 "A client changes its claimed subject": claim subject 8 on the worker session | `use accepted slot=input` |
| PH-002-2 | PH-002: the same Use with no claim, same entry and caller | `use accepted slot=input` |
| PH-002-3 | PH-002: admission on the claiming Use, same full intent | `publish accepted invocation=99;input=input` |
| PH-002-4 | PH-002 "A delegated endpoint hides its new holder": transferred, no edge | `admit_worker denied Identity.TransferredEndpoint` |
| PH-002-5 | PH-002: inherited endpoint | `admit_worker denied Identity.InheritedEndpoint` |
| PH-003-1 | PH-003 "A guessed numeric handle": the client's root slot from the worker session | `admit_worker denied Identity.NotHolder` |
| PH-003-2 | PH-003 "A reference crosses hosts": the other adapter's host id | `admit_worker denied Identity.ForeignHost` |
| PH-010-1 | PH-009 "Revocation precedes authorization", first half: revoke the resolved input after seal | `revoke accepted slot=input;stopped=input` |
| PH-009-2 | PH-009 "Revocation precedes authorization": publish after it | `publish denied Identity.Retired` |
| PH-010-2 | PH-010: revoke the root after publication, record kept | `revoke accepted slot=root;stopped=input` |
| PH-010-3 | PH-009/PH-010: reconcile after revocation, same digest | `reconcile accepted invocation=99` |
| PH-010-4 | PH-010: quiesce at the retired generation | `quiesce accepted slot=input` |
| PH-010-5 | PH-010: reclaim | `reclaim accepted slot=input` |
| PH-010-6 | PH-010 "A device completes after teardown" | `complete denied Identity.Retired` |
| PH-009-3 | replay: second publish with the committed session and ledger | `publish denied Replay` |
| PH-004-1 | PH-004 "Handle reuse after restart": restart | `restart accepted incarnation=next;stopped=input` |
| PH-004-2 | PH-004: the reissued root has the old slot and generation | `use accepted slot=root` |
| PH-004-3 | PH-004: prior-incarnation reference to that slot | `admit_worker denied Identity.StaleIncarnation` |
| PH-009-4 | replay/recovery: reconcile with a substituted digest | `reconcile denied Substitution` |
| PH-012-1 | PH-012 "Two native adapters are compared" (decision part), PH-001 | `compare accepted vectors=26` |

Normalization: accepted lines name only model slots by logical name, the
incarnation as `next`/`current`, and invocations by number; never a host id,
incarnation number, session id, or native value.

## The two adapters and how they differ

| | Adapter A | Adapter B |
| --- | --- | --- |
| host, incarnation (restart to) | 51, 73 (74) | 52, 90 (91) |
| foreign host used by PH-003-2 | 52 | 51 |
| allocation order | mints an unrelated entry (Session handle 1, read) before the root, so root 2, input 3, proxy 4, narrow 5 | root 1, input 2, proxy 3, narrow 4 |
| target report | every family, every control (including accelerator isolation) | every family, exactly the profile's CPU controls |
| route inventory | four mediated routes (descriptor, handle, shared memory, service) | one mediated route (service) |

Both run the whole set. `logical_of` maps each adapter's slots to the same
names. `PH-012-1` asserts the two 26-line lists are equal to each other and to
`V.expected_lines()`. `PH-012 the two adapters differ in host, incarnation,
slot allocation, and target report` asserts the differences are real
(including that A's table really allocated one more slot than B's).

## Vector file hashes

| Capture | SHA-256 of the `^VECTOR PH-` lines |
| --- | --- |
| JS run 1 (`verification/portable-host-vectors.txt`) | `0ee8cb4878c4f7010b057f6aabb79dcff1f001cb5cb780570ffed6669d27037e` |
| JS run 2 | `0ee8cb4878c4f7010b057f6aabb79dcff1f001cb5cb780570ffed6669d27037e` (`cmp` identical) |
| native CPU run (`--threads 4 --gpu off`; not a GPU test) | `0ee8cb4878c4f7010b057f6aabb79dcff1f001cb5cb780570ffed6669d27037e` (`cmp` identical) |

Captured with `bend Tests.bend | grep '^VECTOR PH-'` and from the native
binary's output the same way; compared with `cmp`. The 41 HostBinding
`VECTOR GA-` lines in the same run are unchanged against
`verification/host-binding-vectors.txt` (`cmp`), on both backends.

## Checks (33)

Setup:
- `PH-012 the two adapters differ in host, incarnation, slot allocation, and target report`
- `PH-012 every vector's raw bytes decode through HostWire.decode_bytes on both adapters`
- `PH-005 the destination-E and changed-input sessions are Running at the baseline revisions with another plan`

Plan binding:
- `PH-009-1 the baseline delegated input publishes once through DataOS.commit_from_capability on both adapters`
- `PH-005-1 the delegated input used on a session negotiated for destination E is denied CommitRejected with the state, session, and ledger unchanged`
- `PH-005-2 a session negotiated for a changed input object is denied CommitRejected with the state, session, and ledger unchanged`
- `PH-005-3 a decoded Delegate narrows the root to the proxy session`
- `PH-005-4 the proxy delegates a narrower entry to the worker and the delegation copies the parent's plan unchanged`
- `PH-005-5 the narrower delegated use of the same plan publishes the same full intent as the baseline`
- `PH-005-6 after the narrower proxy the broader root still resolves live with all its rights`

Provenance:
- `PH-009 the accepted intent retains the source labels and origins (BackplaneTests.retained) on both adapters`
- `PH-005 the delegated path's intent label and full origin records equal the root path's`
- `PH-005 delegation copies the parent's plan unchanged`

Caller identity:
- `PH-002-1 a Use claiming subject B on the worker session resolves to the owner's caller`
- `PH-002-2 the same Use with no claim resolves to the same entry and caller`
- `PH-002-3 admission on the claiming Use publishes the same full intent as with no claim`
- `PH-002-4 a transferred endpoint with no delegation edge is denied TransferredEndpoint with the state unchanged`
- `PH-002-5 an inherited endpoint is denied InheritedEndpoint with the state unchanged`
- `PH-003-1 a slot guessed from another session is denied NotHolder with the state unchanged`
- `PH-003-2 a reference naming the other adapter's host is denied ForeignHost with the state unchanged`

Revocation:
- `PH-010-1 revoking the resolved input before authorization stops its worker`
- `PH-009-2 a publication after the revocation is denied Identity Retired with the state, session, and ledger unchanged`
- `PH-010-2 revoking the root after publication stops the worker and keeps the publication record`
- `PH-010-3 after revocation reconcile returns the same invocation and digest`
- `PH-010-4 the revoked worker is quiesced at the retired generation`
- `PH-010-5 the quiesced worker is reclaimed`
- `PH-010-6 a stale completion after teardown is denied Identity Retired with the state unchanged`

Replay:
- `PH-009-3 a second publication is denied Replay with the state, session, and ledger unchanged`
- `PH-004-1 restart moves to the next incarnation and stops the running worker`
- `PH-004-2 after restart the reissued root has the old slot and generation in the next incarnation`
- `PH-004-3 the prior-incarnation reference to that slot is denied StaleIncarnation with the state unchanged`
- `PH-009-4 reconcile with a substituted digest is denied Substitution with the state unchanged`

Two adapters:
- `PH-012-1 PH-001 adapters A and B give identical decisions and identical vector lines for every vector`

"Same full intent" compares the whole `WriteIntent`: plan, output policy
(schema, secrecy, untrusted, kinds, and every origin record including
approved codes and payment terms), label (policy trees), backend, and
artifact.

## Mutation exercise

There is no new denial branch in library code: this task adds no transition.
The new code with branches is the runner's decoding and delegation fallbacks
and the renderers; the adapters are data. Scratch harness
(`mutate5.py` in the session scratchpad: copy the root `.bend` files, apply one
exact one-site replacement, run `bend HostConformanceTests.bend`, record the
first `FAIL:`). 29 mutants: 25 killed by a named check, 3 equivalent, 1
survivor.

| Mutant | Result |
| --- | --- |
| library: replay accepted (`p_fresh`) | killed by `PH-009-3 ...` |
| library: publish identity reason replaced | killed by `PH-009-2 ...` |
| library: reconcile substitution accepted | killed by `PH-009-4 ...` |
| library: transferred endpoint accepted | killed by `PH-002-4 ...` |
| library: inherited endpoint accepted | killed by `PH-002-5 ...` |
| library: holder check dropped | killed by `PH-003-1 ...` |
| library: host check dropped | killed by `PH-003-2 ...` |
| library: incarnation check dropped | killed by `PH-004-3 ...` |
| library: revoke emits no StopEffects | killed by `PH-010-1 ...` |
| library: a publication refusal returns an advanced primitive state | killed by `PH-005-1 ...` |
| library: a publication refusal returns an empty ledger | killed by `PH-005-1 ...` |
| library: an admission identity denial returns an advanced state | killed by `PH-002-4 ...` |
| library: DataOS plan equality dropped (`commit_resolved`) | SURVIVED (see Concerns 2) |
| adapter: B also mints the unrelated entry first | killed by `PH-012 the two adapters differ ...` |
| adapter: B uses A's host id | killed by `PH-012 the two adapters differ ...` |
| adapter: A's foreign host is its own | killed by `PH-003-2 ...` |
| adapter: B's report lacks the quota control | killed by `PH-009-1 ...` |
| adapter: A's inventory leaves a route unmediated | killed by `PH-009-1 ...` |
| names: slot offset ignores the preface | killed by `PH-012 the two adapters differ ...` |
| names: input and proxy swapped | killed by `PH-009-1 ...` |
| bytes: little-endian order reversed | killed by `PH-012 every vector's raw bytes decode ...` |
| bytes: claim word dropped from a Use | killed by `PH-012 every vector's raw bytes decode ...` |
| chain: the preface never mints | killed by `PH-012 the two adapters differ ...` |
| chain: replay uses the fixture session and ledger | killed by `PH-009-3 ...` |
| expected: one expected line changed | killed by `PH-010-6 ...` |
| render: identity reason name swapped | killed by `PH-009-2 ...` |
| chain: undecodable bytes fall back to a valid Use | equivalent: every input decodes (setup check) |
| chain: delegation fallback replaced by a valid delegation | equivalent: every Delegate input decodes as a Delegate |
| chain: revoke-slot fallback names slot 1 | equivalent: both revoke vectors resolve their slot |

## Verification

| | PASS lines |
| --- | --- |
| Before this task | 1140 |
| After this task | 1173 (782 plus 391 new checks = 1173; this task adds 33) |

- No PASS line is duplicated; all 782 PASS lines of `verification/tests-js.txt`
  are present.
- `bend HostConformanceTests.bend`: 33 PASS, 27 VECTOR lines,
  `HostConformance: 33 checks passed, 27 vectors emitted`.
- `bend Tests.bend` (JS), twice: exit 0, 1173 PASS each; last lines
  `Property: 324 checks passed; 320 graph cases, each checked against CPU and Bend parallel producers`
  and `ALL LIBRARY TESTS PASSED`.
- Native: `bend Tests.bend -o ../writ-build/portable-host-contract/tests-native && ../writ-build/portable-host-contract/tests-native +RTS --threads 4 --gpu off`:
  the build took 5m03s and exited 0; the run exited 0 with 1173 PASS and the
  same last two lines, its PASS lines identical, in order, to the JS run's,
  and its `VECTOR PH-` lines `cmp`-identical to the JS capture. This is CPU
  execution, not a GPU test.
- `bend PROOF.bend`: `ALL PROOFS CHECK` / `Use --verdict for mathematical validity.`
- `bend PROOF.bend --verdict`: unavailable:
  `Error: BendTT infrastructure: the kernel did not build (lean: Executable not found in $PATH: "lean"); --verdict needs Lean v4.34.0 (elan toolchain leanprover/lean4:v4.34.0), or $BENDTT set to a built kernel`.
- `~/.bun/bin/bunx @fission-ai/openspec@1.16.0 validate --all --strict --no-interactive`:
  `Totals: 44 passed, 0 failed (44 items)`.
- No `@unsafe`, no holes, no array indexes, no mutual recursion.

## Concerns

1. Model gap (FIXED in fix round 1, below). Before the fix, the identity
   entry's `plan` was never compared at publication. `HostPublication.publish` passes
   `F.Ref{owner, entry handle}` to `DataOS.commit_from_capability`, which
   compares the Frontend handle's plan with the session's; `I.entry_plan` is
   read by no decision. A scratch probe confirmed it: a root issued with
   `destination_plan()` (destination E) on Frontend handle 2 (plan D),
   delegated, admitted, sealed, and published with the plan-D session gives
   `publish accepted invocation=99;input=input` (pre-fix tree). After fix
   round 1 the same probe's `issue` is denied PlanMismatch (vector PH-005-7),
   and the same table built by bypassing `issue` is refused PlanMismatch at
   publish (vector PH-005-8). So, before the fix, "delegation copies the
   parent's plan" (PH-005-4, and HostIdentity ruling (a)) is a property of a
   field no check reads, and an `issue` whose plan differs from its Frontend
   handle's plan is not detected. Suggested fix for the controller to rule on
   (it changes HostPublication or HostPrimitives.issue, Task 4 code): require
   `T.Plan.equal(I.entry_plan(entry), N.Session.plan(session))` at publish
   step 4 or 6 (a new reason, or `CommitRejected`), and/or check the plan
   against the Frontend handle at `issue`. I did not add a vector for the gap,
   so the vector file does not enshrine it.
2. PH-005-1 and PH-005-2 are over-determined. Dropping only DataOS's plan
   equality leaves both denied, because Backplane's binding lookup (keyed by
   the full request, plan included) and its negotiation checks also reject a
   session negotiated for another plan. The vectors fix the outcome
   (CommitRejected, everything unchanged), not which DataOS/Backplane check
   produced it. Isolating the plan-equality check would need a whole second
   Backplane context for plan E; I recorded the boundary in the traceability
   row instead.
3. Transitive test import. HostConformanceVectors has no `import ./Test.bend`,
   but it reuses (by import, per the fixture rule) NegotiationTests,
   BackplaneTests, and FacadeTests, which import Test.bend for their own
   `main`. A native port importing the vectors module compiles those defs;
   nothing calls them.
4. Added fixtures. No existing fixture negotiates a session for another plan,
   so the vectors module defines two synthetic transfer contexts (the
   TransferTests context re-issued for destination object 21, and for input
   object 11) and runs the NegotiationTests chain shape for each through the
   real Negotiation transitions. A setup check shows both reach Running at the
   baseline revisions.
5. Scope of "unchanged state". Every denial asserts primitive-state equality.
   Ledger revision, balance, and session revision are asserted where a
   transition takes them (every publication refusal); the other denying
   transitions take no session or ledger.
6. Vector order and ids: the brief listed "a narrower proxy does not report the
   parent revoked" under revocation; it is PH-005-6 (PH-005's second
   scenario). PH-004-2 is an accepted precondition vector (the reissued root
   has the old slot and generation), so PH-004-3 is the denial. The revoke
   lines name the requested slot's logical name and the actually stopped
   workers' input entries.
7. Native arity. The first native build failed `Error: an arity over 247` in
   `ph009_3_ok`; splitting the committed session and ledger into the named
   defs `replay_session` and `replay_ledger` (same expressions) fixed it.
8. Sizes: 685 and 1029 lines against an estimate of about 250 each (the
   alternative negotiated sessions, the full-intent equality, and one ok/line
   pair per vector); 33 checks against about 30; 27 lines against about 26.

## Fix round 1: exact plan binding at issue and at publish

Controller ruling on concern 1: the gap is real (PH-005, exact plan binding)
and this lane fixes it, although it touches Task 4's families.

Changes:
- `HostPrimitives.Error` gains `PlanMismatch` (with its `Error.equal` arm).
- `HostPrimitives.issue` now takes `frontend: F.State`, the monitor's own
  Frontend state (the record `DataOS.commit_from_capability` later re-resolves
  the handle in). Order: gate; plan binding (`m_plan`, `handle_carries`): the
  handle must exist in `frontend` (`F.find_handle`) and carry exactly the
  issued plan (`T.Plan.equal(F.handle_plan(handle), plan)`), else
  PlanMismatch; then HostIdentity's checks. A missing handle is also
  PlanMismatch (no handle carries the plan).
- `HostPublication.publish`: step 4 gains `p_plan` after the `Running` check:
  the identity entry's plan must equal the negotiated session's plan, else
  PlanMismatch (before the replay check and the commit, so nothing is spent).
  Step 7 gains `p_intent_plan` before the artifact check: the committed
  intent's plan (`intent_plan`) must equal the entry's plan, else
  PlanMismatch with the committed session and ledger discarded. The header's
  order table lists both.
- Laws: the new branches use `Denied{state, PlanMismatch{}}` and `refuse`,
  i.e. the existing `Denied` and `Refused` constructors, so
  `primitive_denied_preserves_state`, `primitive_denied_emits_nothing`,
  `publication_refused_preserves_state`, and
  `publication_refused_emits_nothing` cover them unchanged; LAWS.bend and
  PROOF.bend are not edited and `bend PROOF.bend` still reports
  `ALL PROOFS CHECK`.
- Delegation: `HostIdentity.delegate` already copies the parent's plan; the
  new vector PH-005-9 checks that a delegated child (root, proxy, narrow, all
  plan D) cannot publish another plan: denied PlanMismatch.

Tests:
- `HostPrimitivesTests.bend` (206 checks, +3): `issue_on` passes the
  FacadeTests descriptor (`pub_frontend`) and the stale-revision issue check
  passes it too; new checks
  `PH-005 issue for a plan other than its Frontend handle's plan denied PlanMismatch`,
  `PH-005 issue for a handle the monitor's Frontend state does not hold denied PlanMismatch`,
  `PH-005 order: issue's plan binding precedes HostIdentity's checks`.
- `HostConformanceTests.bend` (36 checks, +3; 30 lines): PH-005-1 and PH-005-2
  now expect `publish denied PlanMismatch` (the host layer refuses them before
  DataOS; their check names now say PlanMismatch instead of CommitRejected,
  the only two renamed PASS lines). New vectors:
  - PH-005-7 `issue denied PlanMismatch`: the client's root issued for
    destination E's plan on Frontend handle 2 (plan D), full path, state
    unchanged;
  - PH-005-8 `publish denied PlanMismatch`: HAND-BUILT and marked: the root
    minted for plan E on handle 2 by `HostIdentity.mint` directly (bypassing
    `issue`, as a monitor without the binding would), then the decoded
    Delegate, admission, and seal as real transitions; publish with the
    plan-D session is refused with state, session, and ledger unchanged (the
    check also asserts the chain reached a sealed Running worker);
  - PH-005-9 `publish denied PlanMismatch`: delegated child, plan-E session.
  - PH-012-1 now `compare accepted vectors=29`.
- The vectors module's unrelated entry for adapter A now names the
  descriptor's Session handle 1 (handle 5 does not exist in the Frontend
  state, so `issue` would now deny it); `fixture_frontend_state` added.

Mutation run (scratch `mutate_f1.py`: one-site mutant, run
HostPrimitivesTests then HostConformanceTests, first FAIL; and a scratch
program printing all of adapter A's lines, diffed against the vector file):

| Mutant | First failing check | Vector lines changed |
| --- | --- | --- |
| issue: plan binding dropped | `PH-005 issue for a plan other than its Frontend handle's plan denied PlanMismatch` | PH-005-7 becomes `issue accepted` |
| issue: `handle_carries` ignores the plan | same | PH-005-7 becomes `issue accepted` |
| issue: missing handle accepted | `PH-005 issue for a handle the monitor's Frontend state does not hold denied PlanMismatch` | none |
| issue: PlanMismatch reason replaced | `PH-005 issue for a plan other than its Frontend handle's plan denied PlanMismatch` | PH-005-7 becomes `denied WrongPhase` |
| publish: step 4 plan check dropped | `PH-005-1 ... denied PlanMismatch ...` | PH-005-1, PH-005-2, PH-005-9 become `denied CommitRejected` |
| publish: step 4 reason replaced | `PH-005-1 ... denied PlanMismatch ...` | PH-005-1, -2, -8, -9 become `denied CommitRejected` |
| publish: step 7 intent-plan check dropped | SURVIVED (equivalent while step 4 stands: DataOS commits the session's plan, which step 4 already equated with the entry's) | none |
| both new checks dropped (issue and step 4) | `PH-005 issue for a plan other than its Frontend handle's plan denied PlanMismatch` | PH-005-1, -2, -7, -9 change (PH-005-8 is still refused by step 7) |

Verification:
- `bend Tests.bend` (JS), twice: exit 0, 1179 PASS each (782 plus 397 new
  checks = 1179; fix round 1 adds 6), last line `ALL LIBRARY TESTS PASSED`,
  no duplicate PASS line; the only PASS lines of the previous run missing are
  the two renamed PH-005-1/PH-005-2 checks.
- `verification/portable-host-vectors.txt` regenerated, 30 lines, SHA-256
  `70efda962bf8ab487085ea2157b86217de0fb117e9d6ecfc5c59a7a18fb5e5b5`,
  `cmp`-identical across the two JS runs and the native run (`bend Tests.bend -o ...tests-native`, `+RTS --threads 4 --gpu off`: build exit 0, run 1179 PASS identical in order to JS, `ALL LIBRARY TESTS PASSED`; CPU execution, not a GPU test).
- `bend PROOF.bend`: `ALL PROOFS CHECK` / `Use --verdict for mathematical validity.`
- OpenSpec strict: `Totals: 44 passed, 0 failed (44 items)`.
- Traceability: the family 1 wrappers row names the issue plan binding and
  its three checks; the vectors table has PH-005-1/2 as PlanMismatch and rows
  for PH-005-7 to PH-005-9; the PH-005 requirement row is rewritten.

Remaining notes: `issue`'s signature changed (one new parameter), a Task 4
public interface; its only callers are this lane's test modules. The step 7
check is defense in depth, reachable only if step 4 were removed.
