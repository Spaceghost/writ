# Task 5 review: shared conformance vectors, with fix round 1 (60296fe..3e32c78)

Reviewer: task reviewer (security review). Scope: c5c003c (vectors) and
3e32c78 (fix round 1: exact plan binding at `issue` and `publish`). I read
the brief, the report and its fix-round section, the full
`HostConformanceVectors.bend`, the `HostPrimitives.bend` and
`HostPublication.bend` changes, all of `HostConformanceTests.bend`, the
`HostPrimitivesTests.bend` changes, the `Tests.bend`, `tasks.md`, and
traceability diffs, the plan's Global Constraints, the Task 4 review, PH-005
in the spec delta, the four laws in `LAWS.bend`/`PROOF.bend`,
`HostIdentity` resolve/retire, and `DataOS.commit_from_capability`.
Controller rulings were not flagged; the two I was asked to verify are
verified below.

## Verdict 1, spec compliance: APPROVED

- Every vector the brief lists exists and passes. Exact plan binding: PH-009-1
  (baseline), PH-005-1 (destination E), PH-005-2 (changed input), PH-005-5
  (narrower delegated use, same full intent). Retained provenance: the three
  provenance checks (`BackplaneTests.retained`, delegated label/origins equal
  to the root path's, delegation copies the plan). Caller identity: PH-002-1
  to PH-002-3 (claim B, same entry, caller, and full intent), PH-002-4
  (transferred), PH-002-5 (inherited), PH-003-1 (guessed slot), PH-003-2
  (foreign host). Revocation: PH-010-1/PH-009-2, PH-010-2/PH-010-3, PH-010-6,
  PH-005-6. Replay: PH-009-3, PH-004-3, PH-009-4. Fix round: PH-005-7 to
  PH-005-9. Each line names its requirement id.
- Full path: every chain starts at `HostIdentity.empty`, opens sessions,
  issues roots through `P.issue`, decodes raw little-endian bytes built
  independently of HostWire's encoder (`le_bytes`) through
  `HostWire.decode_bytes`, and runs `use`, `delegate` (fields from the
  decoded Delegate), `admit_worker` (decoded ref), `seal`, `publish`,
  `revoke`, `reconcile`, `restart`, `quiesce`, `reclaim`, `complete`. The
  only hand-built state is PH-005-8 (`bypassed_root`,
  HostConformanceTests.bend:688-698), marked HAND-BUILT in code and in
  traceability. The setup check shows no decode fallback is taken.
- Denials assert unchanged state: `PT.denied` (state equality, identity
  table included) for every Step denial, and `refused_unchanged`
  (HostConformanceTests.bend:537-546: state equality, session revision,
  ledger revision, payer balance, no Publish) for every publication refusal.
  Transitions that take no session or ledger have nothing more to compare.
- Two adapters: A and B are two data parameterizations (host 51/52,
  incarnation 73/90, A mints an unrelated entry first, full vs exact control
  report, four vs one mediated route) of one runner. The differences are
  real and asserted (`adapters_differ`, including the extra allocated slot),
  and they matter for normalization (host id, incarnation, slot offset) and
  for admission (different reports and inventories both admit). They are not
  two adapter implementations; the traceability PH-001 row says so ("Two
  synthetic adapters of the same Bend interfaces"), which matches the plan
  ruling. PH-012-1 asserts A's 29 lines equal B's and `V.expected_lines()`.
- Vector file: `verification/portable-host-vectors.txt`, 30 lines, SHA-256
  `70efda962bf8ab487085ea2157b86217de0fb117e9d6ecfc5c59a7a18fb5e5b5` on disk.
  My own JS run and my own fresh native build/run both produce `cmp`-identical
  `VECTOR PH-` lines with that hash; the implementer's f1-js-1, f1-js-2,
  f1-native captures hash the same. The 41 `VECTOR GA-` lines are
  `cmp`-identical to `verification/host-binding-vectors.txt` on both backends.
- `Tests.bend`: one import and one call (+2 lines). Touch list: only the Task 5
  files plus, under the fix-round ruling, `HostPrimitives.bend`,
  `HostPublication.bend`, `HostPrimitivesTests.bend`. Records, tasks.md box
  1.4 and header, traceability. No count pin, manifest, LAWS, or PROOF change.
- Controller ruling checks: (a) my probe (scratch `Probe.bend`) issuing the
  client's root for `destination_plan()` on the real plan-D Frontend handle 2
  gives `Denied PlanMismatch`, state equal to the input, effects `[]`.
  (b) `P.issue` is called only by `HostPrimitivesTests.bend` (1214, 1725) and
  `HostConformanceTests.bend` (91, 679); nothing under `hosts/`, `contrib/`,
  `examples/`, `utils/` calls it.

## Verdict 2, security and code quality: NEEDS_FIXES

Two conformance-strength gaps (a weaker implementation passes the whole
vector set), both cheap to close. Neither is exploitable in the current Bend
code, because other suites or the publish-side binding catch them, but the
vector set is what native targets replay, and it should pin the claims it
makes.

### Important

1. The issue-side "exact" plan binding is pinned only for a changed
   destination. HostConformanceTests.bend:677-686 (PH-005-7) and
   HostPrimitivesTests.bend:1487-1488 both use a plan that differs in its
   destination. My mutant M4, `handle_carries` comparing only
   `T.Plan.destination` (HostPrimitives.bend:1131), survives
   HostPrimitivesTests and HostConformanceTests with all 30 lines unchanged.
   Publication still refuses such an entry (step 4 against the session,
   DataOS against the handle), so this is not an exploit today, but the
   fix round's stated rule ("carry exactly the issued plan") has no test.
   Fix: add vector PH-005-10 `issue denied PlanMismatch` issuing the root
   for `V.input_plan()` (changed input object, same destination and
   invocation) on handle 2, with `PT.denied` against `with_sessions(a)`;
   add its expected line and list entry in HostConformanceVectors.bend
   (:623-698) and a traceability row. Optionally one more for a changed
   code id.
2. PH-003-1 does not distinguish session holding from caller identity.
   The guessing session is the worker, whose caller differs from the owner
   in its code (`TF.other_code()`). My mutant M1, `r_holder` also accepting
   a session whose caller equals the entry owner (HostIdentity.bend:709-710),
   passes every conformance vector; it is killed only by HostIdentityTests
   ("another session of the same subject and token ...") and
   HostPrimitivesTests (PH-006). A native binding that keys sessions by
   caller token (merging two sessions of the same subject and token) would
   therefore pass the replay set. Fix: add PH-003-3 `admit_worker denied
   Identity.NotHolder`: the proxy session (session 3, same subject and token
   as the client, Authenticated, delegable) presents the client's root
   reference, asserted with `identity_denied(a, V.session_proxy(), use_of(a,
   V.Root{}, V.claim_none()), I.NotHolder{})`.

### Minor

3. Missing-handle case has no vector. My mutant M7 (`handle_carries` accepts
   `None`, HostPrimitives.bend:1132-1133) is killed by HostPrimitivesTests
   ("issue for a handle the monitor's Frontend state does not hold") but
   changes no vector line. It is not a gap in the Bend model. For the replay
   set, add it with fix 1 (PH-005-11, `issue` on an unopened handle, e.g.
   handle 3 of `fixture_frontend_state`), or record in the traceability
   PH-005 row that this case is a HostPrimitivesTests-only check.
4. `issue`'s Frontend state is caller-supplied, unrevisioned, and not tied to
   the Frontend state publication later uses. My probe passes a Frontend
   state whose handle 2 carries plan E: `issue` admits the plan-E root; the
   chain seals; publish then refuses it (`CommitRejected` on the plan-E
   session, DataOS against the real handle; `PlanMismatch` on the plan-D
   session, step 4). So the binding of record is publish step 4 plus DataOS,
   and the issue check is defense in depth that is only as good as the
   Frontend state the monitor passes. The comment "never a target value"
   (HostPrimitives.bend:1160-1161) states an obligation nothing enforces.
   Fix: say so in `issue`'s comment and the traceability PH-005 row ("the
   issue check trusts the monitor's Frontend state; publication re-binds
   independently"), or take an `expected_frontend` revision as
   `commit_from_capability` does.
5. Stale header: HostConformanceTests.bend:31-32 still says "No vector starts
   from a hand-built state." Fix: "No vector starts from a hand-built state
   except PH-005-8, marked HAND-BUILT", as the traceability file already says.
6. PH-005-8 claims its hand-built state "is `valid`"
   (HostConformanceTests.bend:691) but does not check it. Fix: add
   `P.valid(bypassed_root(a))` to `bypass_reached` (:708-710).
7. Session ids are identical across adapters (both bind 1 to 5 in the same
   order), and the Delegate target words are the fixed constants
   `V.session_*`. The comparison therefore does not show independence from
   session-id allocation. Optional: have one adapter bind an unrelated
   session first and derive the session ids per adapter, as `slot_of` does
   for slots.

### Judged acceptable

- Survivor S1 (step 7 `p_intent_plan` dropped): equivalent while step 4
  stands. DataOS commits the negotiated session's plan, and step 4 has
  already equated it with the entry's. Kept as defense in depth, documented
  in the header and traceability. Its "committed session and ledger
  discarded" arm is unreachable and so untested; `refuse` takes the
  attempt's supplied session and ledger, which I confirmed by reading.
- Laws: the four laws are accessor laws (`Step.state(Denied{s, r}) == s`,
  etc.) and do not show that a branch returns its input. I read the new
  branches: `m_plan`'s `Denied{state, PlanMismatch{}}` uses the unchanged
  input state; `p_plan` and `p_intent_plan` call `refuse(state, attempt, _)`
  with the input state and the attempt's supplied session and ledger. The
  laws therefore cover them, and PH-005-7 (`PT.denied`) and PH-005-1/2/8/9
  (`refused_unchanged`) test it. M8 (the issue denial returns the minted
  state) is killed by PH-005-7.
- Over-determined PH-005-1/2 and hand-built PH-005-8: per ruling.
- Partial matches at publish are pinned: M3 (step 4 compares invocation only)
  is killed by PH-005-1, and M5 (destination only) by PH-005-2.
- Naming: the vector ids, logical labels, and check names are clear;
  synthetic state is marked in both headers; the vectors module imports no
  `Test` itself (transitive import through reused fixtures, report concern 3).

## What I ran

Toolchain Bend 2.0.39, `BEND_NO_TELEMETRY=1`.

- `bend Tests.bend` (JS): exit 0, 1179 PASS, no duplicates, every PASS line
  of `verification/tests-js.txt` present; last lines
  `Property: 324 checks passed; 320 graph cases, each checked against CPU and Bend parallel producers`
  / `ALL LIBRARY TESTS PASSED`.
- Native: fresh `bend Tests.bend -o <scratch>/tests-native` (build exit 0),
  run with `+RTS --threads 4 --gpu off`: exit 0, 1179 PASS identical in
  order to JS, same last lines. CPU execution, not a GPU test.
- `bend PROOF.bend`: `ALL PROOFS CHECK` / `Use --verdict for mathematical validity.`
  (`--verdict` not attempted; the Lean kernel is not installed, as the report
  records.)
- OpenSpec 1.16.0 strict: `Totals: 44 passed, 0 failed (44 items)`.
- Hashes: as in Verdict 1.
- Mutants (scratch harness: copy the root `.bend` files, one exact one-site
  replacement, run HostPrimitivesTests and/or HostConformanceTests, record
  the first FAIL):

| Mutant | Result |
| --- | --- |
| K1 issue plan binding dropped | killed: HostPrimitivesTests `PH-005 issue for a plan other than ...`; HostConformance `PH-005-7` |
| K2 publish step 4 dropped | killed: `PH-005-1` |
| K3 replay accepted (`p_fresh`) | killed: `PH-009-3` |
| K4 holder check dropped | killed: `PH-003-1` |
| S1 step 7 intent-plan dropped | survives both suites (equivalent, see above) |
| M1 holder accepted on caller equality | survives HostConformance; killed by HostIdentityTests and HostPrimitivesTests (finding 2) |
| M2 retire only the named entry, no subtree | killed: `PH-010-2` |
| M3 step 4 invocation-only match | killed: `PH-005-1` |
| M4 issue destination-only match | survives HostPrimitivesTests and HostConformance (finding 1) |
| M5 step 4 destination-only match | killed: `PH-005-2` |
| M6 complete accepts an unresolved identity | killed: `PH-010-6` |
| M7 issue accepts a missing handle | killed by HostPrimitivesTests only; no vector (finding 3) |
| M8 issue denial returns the minted state | killed: `PH-005-7` |

- Probe (scratch `Probe.bend`): ruling check (a) above, and the
  forged-Frontend case of finding 4.
