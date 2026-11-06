# Task 1 review: Linux adapter, profile, and conformance replay

Reviewer (task reviewer, security), 2026-11-05. Commit under review: 60dc1fe
on `lane/linux-host` (package `.superpowers/sdd/2026-11-05-linux-host/review-710134f..60dc1fe.diff`;
its diff body matches `git diff 710134f 60dc1fe` with extra context lines).
Read: the brief, the report, the plan's Global Constraints and rulings,
AGENTS.md, docs/PLATFORMS.md, the add-linux-host spec delta (LH-001 to LH-010),
HostPrimitives/HostIdentity headers and the `open_session`/`use`/`admit_worker`
bodies, HostConformanceVectors' `Adapter`, both new Bend files in full,
INVENTORY.md, the traceability file, and the tasks.md diff.

## Verdict 1, spec compliance: NEEDS_FIXES

The only blocker is the controller ruling on box 1.1. Everything else matches
the brief and plan.

- **Box 1.1 is checked** (`openspec/changes/add-linux-host/tasks.md:7`, `- [x]`).
  The controller ruling says it stays unchecked until the native pins land.
  Fix: change it to `- [ ]` and keep the parenthetical, reworded to "Model half
  delivered: ...; the box is checked when Tasks 2 and 3 land the native pins".
  The header line (tasks.md:3) can stay as it is.

Verified compliant:
- Profile `linux-worker-v1` (LinuxHost.bend:155-189): id 1, `all_families()`,
  the five controls without accelerator isolation, `Cpu`, `quota_limit()` = 1024,
  the only entry in `profiles()`. The control-to-kernel mapping is the plan
  ruling's, word for word, in the header (66-86) and INVENTORY.md:62-68. No
  `Accelerator` profile is defined. The UnisolatedAccelerator check uses a
  table that exists only in the test and is labelled HYPOTHETICAL.
- Translator rejections: `StaleLaunch`/`PeerMismatch` (`launch_check`, 270-274,
  shared by Launch and Barrier); `UnknownFamily`/`UncreditedControl`
  (`report_of`, 317-322); `inventory_of` is total and drops descriptor numbers.
  Each rejection has a named check.
- I reran six of the 31 mutants on a scratch copy and all six were killed,
  each by the check the report names: M01 (StaleLaunch removed), M02
  (PeerMismatch removed), M04 (pid ignored), M06 (UnknownFamily removed), M07
  (UncreditedControl removed), M14 (barrier launch check skipped). The
  unmutated baseline gives 83 PASS.
- Two-channel dispatch (439-479) routes as the report says. Launch goes to
  `open_session` with `worker_role()`. Barrier goes to `admit_worker` on the
  frame's session. Usage goes to `charge`, Emission to `diagnostic`. A worker
  Use goes to read-only `P.use`, a worker Delegate goes to `P.delegate`, and
  Complete/Release are `Unrouted`.
- Replay: `grep '^LINUX VECTOR ' | cut -c7-` of my JS run is cmp-identical to
  `verification/portable-host-vectors.txt`. The on-disk SHA-256 is
  `37816dd7d768c21e730f780cbc98b66cadbba087c972d18e731b670219caf24f` (37 lines),
  the same hash the report gives. The `VECTOR PH-` and `VECTOR GA-` captures
  are still cmp-identical to their files.
- `Tests.bend`: one import and one call, both after `HostConformance`.
- `bend Tests.bend`: exit 0, 1511 PASS, 0 FAIL, `LinuxHost: 83 checks passed`,
  `ALL LIBRARY TESTS PASSED`. All 1428 prior PASS lines are present (`comm`
  against `verification/tests-js.txt`) and no PASS name is duplicated.
- `bend PROOF.bend`: `ALL PROOFS CHECK`, identical to `verification/proofs.txt`.
  `git diff master -- LAWS.bend PROOF.bend` is empty. I did not run `--verdict`
  (no Lean on the host; the report records the refusal).
- OpenSpec 1.16.0 strict: 44 passed, 0 failed.
- Changed files are exactly the touch list: the two Bend files,
  INVENTORY.md, the traceability file, tasks.md, Tests.bend, and the records.
  No count pin is touched; the `83` in `main` follows the existing per-module
  summary convention.
- Header effect statement: verified. Lines 121-125 say the types cannot stop
  Bend code from writing `Admitted`/`DeliverInputs`, that this module never
  does, and that the broker must execute only effects from a returned
  `Outcome` (obligation (a)). A grep of non-comment lines finds no
  `Admitted`, `DeliverInputs`, `Step{`, `Publish`, `StopEffects`, `Reclaim` or
  `Reconcile`. Every `Stepped{...}` (394, 411, 447, 449, 459) wraps a
  shared-transition call.
- A worker's own frame can never reach `admit_worker`: the only call is at
  line 411, which is reachable only from `on_broker`'s Barrier arm.
  `on_worker` reaches only `P.use`, `P.delegate`, or `Unrouted`, and
  `FromWorker` has no `LinuxFact` field.
- Landlock and `no_new_privs` are recorded as a gap (INVENTORY.md:76-79 and the
  LH-005 traceability row), as the controller ruled.

## Verdict 2, security and code quality: NEEDS_FIXES

No native fact becomes stored authority without passing a contract
transition. The caller is built from the launch record's subject and token,
never from a uid. The pid, uid, and start time are only compared, and
descriptor numbers are dropped. Every stored field still goes through
`open_session`, `admit_worker`, `charge`, or `diagnostic`. The three Important
findings are a missing binding, a test gap, and an incomplete trust
inventory. None of them lets a worker gain authority today, but each weakens
what the module claims to check.

### Important

**I1. A Barrier's fact is not bound to the session the Barrier names**
(LinuxHost.bend:443-445, 266-274; header 105-107).
- `launch_check` compares only fields inside the fact: its incarnation
  against the monitor's, and `peer` against `launch`. It never compares
  `subject`, `token`, or the credentials with the session it admits.
  `Barrier.fact.endpoint` is never read.
- The monitor records no launch credential at Launch, so at the Barrier both
  credentials are values the broker composed fresh. The PeerMismatch check
  there is a self-consistency check on the frame, not a check that the
  process at the barrier is the one launched on session `s`.
- My scratch probe passed:
  - A Barrier on worker session 2 carrying subject 99, the client's token, and
    a uid 2000 / pid 5555 credential pair **admits session 2 and emits
    `DeliverInputs`**.
  - A Barrier whose endpoint is `TransferredFrom{9}` also admits.
- The authority impact is bounded. The admitted worker is still session 2,
  with the entry session 2 holds, under the profile it was bound to. But the
  confinement facts being credited (LH-003) may belong to another process. A
  broker bug that mixes up two workers' barriers would be accepted silently,
  while the header's wording (line 267-268, "the fact is about a process this
  monitor incarnation launched") reads as a binding.

Fix:
1. Add a pure check on the Barrier path that looks up
   `I.session_at(I.sessions(P.identity(state)), session)`. Reject with a new
   adapter `Rejection` (`SessionMismatch`) when there is not exactly one
   session, or when `I.session_caller` differs from
   `F.Caller{fact.subject, fact.token}`. This is not a transition and not a
   contract `Error`, so no law changes.
2. Add a check that a Barrier with another subject or token is refused
   SessionMismatch with the state unchanged, and a mutant that kills it.
3. In the header and INVENTORY, state as a broker obligation for Task 2 that
   the barrier credential is the session's launch credential (the monitor
   stores none), and that `endpoint` is fixed at Launch and ignored at the
   Barrier.

**I2. StaleLaunch is never exercised against an advanced monitor incarnation**
(LinuxHost.bend:387-388; LinuxHostTests.bend:132-134).
- Every dispatch check runs at incarnation 1, so the monitor's live
  incarnation cannot be told apart from a constant. Two extra mutants of
  `current_incarnation` both **survive** (83/83 PASS):
  - returning `linux_incarnation()`;
  - returning `linux_worker_v1()`.
- The fixture values collide: incarnation 1 = profile id 1 = client session 1,
  and the stale incarnation 2 = worker session 2 = `linux_successor()`.
- The point of StaleLaunch is a launch record that survives a monitor restart
  (LH-002, and LH-008's "delayed result crosses a monitor restart"), and that
  case is untested.

Fix:
1. Add a check that advances the state through `H.restart(...,
   linux_successor())`. Then a Launch whose record carries
   `linux_incarnation()` must be Untranslated StaleLaunch with the state
   unchanged, and a Launch carrying the successor must open a session.
2. Pick a stale incarnation that equals no session or profile id (for
   example 5), or derive it from the post-restart state.
3. Add the two mutants above to the removal map.

**I3. INVENTORY.md does not list every fact the native side reports**
(hosts/linux/INVENTORY.md:28-46).
- Its list covers the launch record, the two credentials, the endpoint,
  families, controls, and the descriptor inventory. It omits broker frame
  fields the module already consumes:
  - `Barrier.session`, the broker's attribution of the barrier to a session;
  - `Barrier.request`, worker-originated bytes the broker relays as a bounded
    snapshot;
  - `Usage{worker, amount}`;
  - `Emission{worker, public}`;
  - `FromWorker.session`, the transport attribution.
- It also omits the facts the plan's Global Constraints say the broker will
  report but `LinuxFact` does not carry yet: the SO_PEERCRED gid, the launch
  record's session generation, each Landlock right, `no_new_privs`/privilege
  drop, and the stable handle a bounded request resolved to (Task 4).
- It states no host obligations: that the broker attributes each frame to the
  right session or worker, takes the snapshot once, and executes nothing on a
  `Checked` result.

Fix: add a "Facts the broker reports" table with these columns: fact, native
source, frame field, contract destination (or "compared only" / "dropped"),
and why it is not an authority fact. Give each not-yet-modelled fact a row
marked "Task 2/3/4". Add an obligations list that mirrors HostPrimitives'
section-2 host obligations.

### Minor

**m1. The request snapshot and the worker's own frame can diverge, and the
module does not say what follows** (header 88-100; LinuxHost.bend:405-413,
454-457).
- The monitor never sees both frames together. Admission follows the broker's
  snapshot only.
- The damage is bounded: only the snapshot's `ref` is used (operation, rights,
  and claim are discarded), and it must resolve on the Barrier's session.
  A divergent snapshot can therefore select only another entry that session
  already holds.
- The worker's own Use reaches only read-only `P.use`.

Fix: add two sentences to the header. First, the snapshot is the only request
admission reads, and a divergence admits at most an entry the session holds.
Second, a `Checked`/`Granted` result authorizes no broker action in
section 1; Task 4's resource lookup must act on the monitor's resolution, not
on worker bytes.

**m2. A replayed Launch opens a second worker session.** My probe confirms a
second identical `Launch{full_fact()}` gets revision +1 and a new session.
The adapter correctly implements no replay rule, but `LinuxFact` has no
session generation and nothing records the obligation. Fix: state in the
header and INVENTORY that the broker issues one Launch per launch-record
generation (Task 2), and add the generation field when Task 2 frames it.

**m3. The replay bypasses `dispatch`** (LinuxHostTests.bend:29-41, 213-215;
check names at 581 onward).
- The 37 vectors run HostConformanceTests' chains directly. Only the host id,
  the incarnation, `report_of(full_fact())`, and `inventory_of(full_fact())`
  are Linux. The launch check, Barrier routing, and channel split are not
  exercised by the vectors.
- So the replay could pass vectors that a misrouted dispatch would fail. The
  report says so (concern 5); the test header and check names do not.

Fix: add a sentence to the test header and to a traceability LH-010 row
saying "shared harness with the Linux fixture's identity, report, and
inventory; dispatch is covered by the dispatch checks, not the replay". Or
route at least the PH-005 admission vectors through `LH.dispatch`.

**m4. Requirement labels on two checks.** "LH-001 a broker Usage ..."
(LinuxHostTests.bend:548-549) is a quota or resource-profile check, LH-003 or
PH-007. "LH-004 a public worker emission ..." (550) is the public-observable
channel, LH-009, or PH-007's diagnostic ruling. Fix: relabel them.

**m5. `Credential` has no gid** (LinuxHost.bend:200-201). The plan lists the
SO_PEERCRED uid/gid/pid. Fix: add `gid` and compare it in `credential_equal`
with its own mutant-killing fixture, or record in the header why gid is not
compared.

**m6. Partial match in `checked_as`** (LinuxHostTests.bend:356-360). It
compares the granted entry's slot and caller, but not its generation or
reference. Fix: compare `P.entry_ref(...)`/`W.Ref.equal` with `input_ref()`,
or compare the generation as well.

What is good: the native-fact boundary is clean and well commented. The
caller comes only from the launch record. Every rejection runs no transition
and is asserted with full state equality and no effect. The fixtures are
distinct (four peers, each differing in one field after the M04 fix). The
claimed subject is checked on both channels. The removal map is honest,
including the survivor that was fixed.

## What I ran

All runs were in the worktree or in a scratch copy under the session
scratchpad (`scratchpad/linux-host-review/`). Nothing was written into the
tree except this file.
- `bend Tests.bend` (JS, 2.7 s): exit 0, 1511 PASS, 0 FAIL. Replay `cmp`
  identical, SHA-256 as above. PH/GA captures identical. No prior PASS line
  missing.
- `bend PROOF.bend`: `ALL PROOFS CHECK`, the same as `verification/proofs.txt`.
- `openspec validate --all --strict --no-interactive` (1.16.0): 44/44.
- Mutants (scratch copy, `bend hosts/linux/monitor/LinuxHostTests.bend`):
  baseline 83 PASS. M01, M02, M04, M06, M07, and M14 were each KILLED by the
  report's named check. Extra mutants X1 (`current_incarnation` returns
  `linux_worker_v1()`) and X2 (returns `linux_incarnation()`) SURVIVED; see I2.
- Probe (scratch `Probe.bend`), three cases, each passed:
  - a Barrier on session 2 with a foreign subject, token, and credential admits;
  - a Barrier with a transferred endpoint admits;
  - a replayed Launch opens a second session.
- Not run: the native backend build (`--gpu off` CPU run) and `--verdict` (no
  Lean). I am relying on the report's native result for those.
