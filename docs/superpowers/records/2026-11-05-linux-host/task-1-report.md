# Task 1 report: Linux adapter, profile, and conformance replay

Implementer, 2026-11-05. Branch `lane/linux-host`, worktree
`../writ-lanes/linux-host`, from master f970496 (+ records commit 710134f).

## Files

- New `hosts/linux/monitor/LinuxHost.bend` (479 lines): imports `Base`,
  `HostWire`, `HostIdentity`, `HostPrimitives`, `HostPublication`, `Frontend`,
  `Transfer` only.
- New `hosts/linux/monitor/LinuxHostTests.bend` (657 lines), registered in
  `Tests.bend` as `LinuxHost` (one import after `HostConformanceTests`, one
  `LinuxHost.main()` call after `HostConformance.main()`; a two-line diff).
- New `hosts/linux/INVENTORY.md`, `openspec/traceability/linux-host.md`.
- Edited `openspec/changes/add-linux-host/tasks.md`: header line, box 1.1.
- Not touched: every shared contract module and its tests, `LAWS.bend`,
  `PROOF.bend`, `contrib/`, `hosts/genode/`, `hosts/unikraft/`,
  `docs/PLATFORMS.md`, and every count pin. `git diff master -- LAWS.bend
  PROOF.bend` is empty.

## Module sections (LinuxHost.bend)

1. Header: adapter glue for the direct Linux target; supplies only
   `Fact`/`TargetReport`/`RouteFact`/`SessionEvidence` values and executes only
   effects of an `Admitted` step; decides nothing, adds no transition, no
   `Error`, no law; no native fact is an authority fact. Documents the
   translators and their rejections, the profile and the control-to-kernel
   mapping, the two channels, the dispatch table, effects and ordering, and
   failure behavior.
2. Host identity and profile table: `linux_host()` = 60 (distinct from the
   adapters' 51 and 52), `linux_incarnation()` = 1, `linux_worker_v1()` = 1,
   `profile_name()` = "linux-worker-v1", `required_controls()`,
   `linux_controls()` (what a report may carry; equal to the required set
   today), `quota_limit()` = 1024, `linux_worker_profile()`, `profiles()`,
   `worker_role()` (`WorkerRole{linux_worker_v1()}`, a monitor decision),
   `initial()` = `P.empty(I.empty(linux_host(), linux_incarnation()), profiles())`.
3. Native facts: `Credential{uid, pid, start}`, `Endpoint`
   (`Launched`/`InheritedFrom`/`TransferredFrom`), `LinuxRoute{descriptor,
   kind, mediated}`, `LinuxFact{subject, token, incarnation, launch, peer,
   endpoint, families, controls, routes}`, `Rejection`, `EvidenceResult`,
   `ReportResult`.
4. Translators (below).
5. Channels and outcomes: `BrokerFrame` (`Launch`, `Barrier`, `Usage`,
   `Emission`), `Input` (`FromBroker`, `FromWorker`), `Outcome` (`Stepped`,
   `Checked`, `Untranslated`, `Undecoded`, `Unrouted`), `Outcome.state`,
   `Outcome.effects`.
6. Dispatch, broker channel and worker channel; `dispatch`.

## Profile `linux-worker-v1`

`P.Profile{1, P.all_families(), address_isolation | no_ambient_network |
output_mediation | quota | no_inherited_routes, P.Cpu{}}` with quota 1024, the
only entry of `profiles()`. The control-to-kernel mapping is the plan
ruling's, verbatim, in the header and in `hosts/linux/INVENTORY.md`. No
`Accelerator` profile is offered; `report_of` refuses the accelerator
isolation bit, and the check `LH-001 under a hypothetical accelerator profile
the Linux report is denied UnisolatedAccelerator by the shared path ...`
shows the shared path refuses the Linux report under a (test-only,
HYPOTHETICAL) accelerator table.

## Translators

| Translator | Produces | Rejects (check names) |
| --- | --- | --- |
| `launch_check(fact, incarnation)` (shared by Launch and Barrier) | `None` or a `Rejection` | `StaleLaunch` when the launch record's incarnation is not the monitor's (`LH-002 session_evidence_of rejects a launch record from another monitor incarnation StaleLaunch`, `LH-002 a Launch with another incarnation's launch record is refused StaleLaunch ...`, `LH-002 a Barrier with another incarnation's launch record is refused StaleLaunch ...`); `PeerMismatch` when the peer credential differs from the launch record's in uid, pid, or start time (`LH-002 session_evidence_of rejects a parent-created socketpair peer PeerMismatch`, `... a reused pid with another start time PeerMismatch`, `... a peer under another uid PeerMismatch`, `... an endpoint held by another pid PeerMismatch`, `LH-002 a Launch from a socketpair parent is refused PeerMismatch ...`, `LH-002 a Barrier from a reused pid is refused PeerMismatch ...`) |
| `session_evidence_of(fact, incarnation)` | `SessionEvidence{Caller{launch subject, launch token}, origin_of(endpoint), False}` | the launch check's two reasons. Accepted shape: `LH-002 session_evidence_of gives the launch record's subject and token, Authenticated, non-delegable`; `LH-007 session_evidence_of reports an inherited or transferred endpoint as Inherited or Transferred from that session` |
| `report_of(fact)` | `TargetReport{families, controls}`, bits copied | `UnknownFamily` for a bit outside `all_families()` (`LH-001 report_of rejects a family bit outside all_families UnknownFamily`, `LH-001 a Launch reporting an unknown family bit is refused UnknownFamily ...`); `UncreditedControl` for a bit outside `linux_controls()` (`LH-001 report_of rejects an accelerator isolation bit ...`, `LH-001 report_of rejects an unnamed control bit UncreditedControl`, `LH-001 a Launch crediting accelerator isolation is refused UncreditedControl ...`, `LH-001 a Barrier crediting an unnamed control is refused UncreditedControl ...`). Accepted shape: `LH-001 report_of copies the binding's families and established controls exactly` |
| `inventory_of(fact)` | `Inventory{[RouteFact{kind, mediated}...]}`, descriptor numbers dropped | total, no rejection (`LH-004 inventory_of gives one route per descriptor in order with its kind and mediation and no descriptor number`) |

No translator produces a `Context`, `Binding`, plan, rights grant, profile,
or a caller from a uid. The caller is the launch record's subject and token;
the uid/pid/start are only compared.

## Dispatch, and why facts come only from the broker channel

`Input` has two constructors. `FromBroker{frame}` is the trusted broker
channel; `FromWorker{session, bytes}` is the untrusted worker channel (the
session is the one the broker's transport identified). `FromWorker` has no
`LinuxFact` field, so a worker cannot supply a fact by construction; its
bytes reach only `W.decode_bytes`, which yields descriptions, never
authority. The broker is the trusted supervisor of the PLATFORMS.md topology,
so it alone reports facts.

- `Launch{fact}` -> `session_evidence_of` and `report_of`, then
  `P.open_session(..., worker_role())`.
- `Barrier{session, fact, request}` -> `launch_check`, `report_of`,
  `inventory_of`, `W.decode_bytes(request)`; a `Use`'s reference goes to
  `P.admit_worker` on `session` (claimed subject discarded by the pattern).
  The request is the broker's bounded, immutable snapshot of the worker's
  bytes (LH-006); admission therefore happens only when the broker reports
  the barrier, with the confinement facts of that moment (LH-003).
- `Usage{worker, amount}` -> `P.charge`; `Emission{worker, public}` ->
  `P.diagnostic`.
- `FromWorker` -> `Use` -> `P.use` (read-only, `Checked`), `Delegate` ->
  `P.delegate` from the transport session; `Complete`/`Release` are
  `Unrouted` (their HostPublication transitions are section 2).

Rejected facts, undecodable bytes, and unrouted frames run no transition and
return the supplied state. The monitor retains `Outcome.state` before the
broker performs `Outcome.effects` (PROTOCOL.md); check `LH-003 the state
retained before DeliverInputs records the worker Running ...`.

Effect construction. `P.Effect` is closed with no publish variant and no
`Outcome` constructor holds an `H.PublishEffect`, so the types forbid the
adapter handing the broker a publication effect. The types do NOT forbid Bend
code from writing an `Admitted` step or a `DeliverInputs` value (Bend
constructors are public, HostPrimitives host obligation (a)); LinuxHost.bend
constructs no `P.Step` and no `P.Effect` (grep of non-comment lines for
`Admitted`, `DeliverInputs{`, `Publish` is empty), and the header says so
rather than claiming a type guarantee.

## Vector replay

The Linux adapter fixture is `V.Adapter{linux_host(), linux_incarnation(),
2, V.host_a() (foreign), prefaced False, report_of(full_fact()),
inventory_of(full_fact())}`; `full_fact()` is a broker-shaped fact (launch
credential matched, every family, exactly the profile's controls, three
mediated descriptors: result channel, broker socket, SCM_RIGHTS input). The
replay reuses HostConformanceTests' per-adapter chains and renderers
(`CT.ph*_ok`, `CT.ph*_line`, `CT.lines_for`) unchanged. 36 checks assert each
vector's outcome assertion on the Linux adapter and its line equal to the
expected line; one asserts the Linux line list equals `V.expected_lines()`
and adapters A's and B's; one asserts the Linux compare line equals
`expected_ph012_1`. The 37 lines are printed with prefix `LINUX ` so the
existing `grep '^VECTOR PH-'` capture is unchanged.

    grep '^LINUX VECTOR ' tests-js.txt | cut -c7- | cmp - verification/portable-host-vectors.txt   # identical
    sha256  37816dd7d768c21e730f780cbc98b66cadbba087c972d18e731b670219caf24f  (37 lines; same as the file)

Also `grep '^VECTOR PH-'` and `grep '^VECTOR GA-'` of the suite output are
still cmp-identical to `portable-host-vectors.txt` and `host-binding-vectors.txt`.

## Removal map (mutation pass)

Scratch copy under `../writ-build/linux-host/mut/` (root modules symlinked,
the two Linux files copied), one mutant of LinuxHost.bend at a time, run
`bend hosts/linux/monitor/LinuxHostTests.bend`. Baseline passes. 31 mutants,
31 killed. The first run had one survivor, M04 (pid ignored by
`credential_equal`): every PeerMismatch fixture also differed in another
field. Fixed by adding `other_pid_credential` and the check `LH-002
session_evidence_of rejects an endpoint held by another pid PeerMismatch`;
rerun kills it. The first failing check per mutant:

    BASELINE rc 0 LinuxHost: 83 checks passed
    M01 launch_check StaleLaunch removed KILLED by FAIL: LH-002 session_evidence_of rejects a launch record from another monitor incarnation StaleLaunch
    M02 launch_check PeerMismatch removed KILLED by FAIL: LH-002 session_evidence_of rejects a parent-created socketpair peer PeerMismatch
    M03 credential_equal ignores uid KILLED by FAIL: LH-002 session_evidence_of rejects a peer under another uid PeerMismatch
    M04 credential_equal ignores pid KILLED by FAIL: LH-002 session_evidence_of rejects an endpoint held by another pid PeerMismatch
    M05 credential_equal ignores start time KILLED by FAIL: LH-002 session_evidence_of rejects a reused pid with another start time PeerMismatch
    M06 report_of UnknownFamily removed KILLED by FAIL: LH-001 report_of rejects a family bit outside all_families UnknownFamily
    M07 report_of UncreditedControl removed KILLED by FAIL: LH-001 report_of rejects an accelerator isolation bit the Linux broker cannot credit UncreditedControl
    M08 linux_controls admits accelerator isolation KILLED by FAIL: LH-001 report_of rejects an accelerator isolation bit the Linux broker cannot credit UncreditedControl
    M09 evidence delegable True KILLED by FAIL: LH-002 session_evidence_of gives the launch record's subject and token, Authenticated, non-delegable
    M10 origin_of Inherited as Authenticated KILLED by FAIL: LH-007 session_evidence_of reports an inherited or transferred endpoint as Inherited or Transferred from that session
    M11 origin_of Transferred as Authenticated KILLED by FAIL: LH-007 session_evidence_of reports an inherited or transferred endpoint as Inherited or Transferred from that session
    M12 launch_report NoReport opens anyway KILLED by FAIL: LH-001 a Launch reporting an unknown family bit is refused UnknownFamily with the state unchanged and no effect
    M13 launch_with NoEvidence not refused KILLED by FAIL: LH-002 a Launch from a socketpair parent is refused PeerMismatch before any transition with the state unchanged and no effect
    M14 barrier_with launch check skipped KILLED by FAIL: LH-002 a Barrier with another incarnation's launch record is refused StaleLaunch with the state unchanged and no effect
    M15 barrier_report NoReport proceeds KILLED by FAIL: LH-001 a Barrier crediting an unnamed control is refused UncreditedControl with the state unchanged and no effect
    M16 barrier_request Malformed unrouted KILLED by FAIL: LH-006 a Barrier whose request snapshot is not a whole frame is Undecoded with the state unchanged and no effect
    M17 barrier_use admits a Delegate's ref KILLED by FAIL: LH-006 a Barrier whose request is not a Use admits nothing: Unrouted with the state unchanged and no effect
    M18 worker Delegate unrouted KILLED by FAIL: LH-007 a worker Delegate from the worker session is denied NotDelegable with the state unchanged and no effect
    M19 worker Complete/Release routed to use KILLED by FAIL: LH-006 a worker Complete or Release runs no transition in section 1: Unrouted with the state unchanged and no effect
    M20 on_worker Malformed unrouted KILLED by FAIL: LH-006 worker bytes that are not a whole frame are Undecoded with the state unchanged and no effect
    M21 Usage not charged KILLED by FAIL: LH-001 a broker Usage within quota_limit is charged once with no effect
    M22 Emission not routed to diagnostic KILLED by FAIL: LH-004 a public worker emission is denied DiagnosticSink with the state unchanged; a confined one is admitted with no effect
    M23 Outcome.effects drops admitted effects KILLED by FAIL: LH-001 LH-003 a barrier report with every required control admits once and its only effect, in the step and in Outcome.effects, is one DeliverInputs naming the worker's input
    M24 required_controls drops quota KILLED by FAIL: LH-001 initial() is a valid empty state on the Linux host and incarnation whose only configured profile is linux-worker-v1: every family, every control but accelerator isolation, Cpu, quota_limit
    M25 profile backend Accelerator KILLED by FAIL: LH-001 initial() is a valid empty state on the Linux host and incarnation whose only configured profile is linux-worker-v1: every family, every control but accelerator isolation, Cpu, quota_limit
    M26 worker_role names another profile KILLED by FAIL: LH-005 a barrier report without control_address_isolation is denied MissingControl with the state unchanged and no effect
    M27 inventory_of marks every route mediated KILLED by FAIL: LH-004 a barrier inventory with an unmediated inherited descriptor is denied UnmediatedRoute with the state unchanged and no effect
    M28 Launch opens as a delegable client KILLED by FAIL: LH-005 a barrier report without control_address_isolation is denied MissingControl with the state unchanged and no effect
    M29 Barrier checks the launch record against incarnation 0 KILLED by FAIL: LH-005 a barrier report without control_address_isolation is denied MissingControl with the state unchanged and no effect
    M30 profile requires no family_revocation KILLED by FAIL: LH-001 initial() is a valid empty state on the Linux host and incarnation whose only configured profile is linux-worker-v1: every family, every control but accelerator isolation, Cpu, quota_limit
    M31 Launch checks the launch record against incarnation 0 KILLED by FAIL: LH-005 a barrier report without control_address_isolation is denied MissingControl with the state unchanged and no effect

## Suite and proof

Count before: 1428. After: 1428 plus 83 new checks = 1511. Every one of the
1428 prior PASS lines is still present (sorted `comm` against
`verification/tests-js.txt`: none missing); no duplicate PASS names.

- JS: `bend Tests.bend`, twice, exit 0, outputs byte-identical; 1511 PASS,
  0 FAIL. Last lines:
  `LinuxHost: 83 checks passed` (in place), and at the end
  `Property: 324 checks passed; ...` then `ALL LIBRARY TESTS PASSED`.
- Native: `bend Tests.bend -o ../writ-build/linux-host/tests-native` (exit 0,
  real 4m21s), then `../writ-build/linux-host/tests-native +RTS --threads 4
  --gpu off` (exit 0, real 0.172s): 1511 PASS, same last lines, output
  `cmp`-identical to the JS run (SHA-256
  `ca697ffa011253e11bdf99b06c78100607da2a04f22aa603d2d3c88a7b2b3fa6`); its
  `LINUX VECTOR` and `VECTOR PH-` lines are each `cmp`-identical to
  `portable-host-vectors.txt`. This is CPU execution with `--gpu off`, not a
  GPU test.
- `bend PROOF.bend`: exit 0, `ALL PROOFS CHECK` / `Use --verdict for
  mathematical validity.`, same as `verification/proofs.txt`.
- `bend PROOF.bend --verdict`: not available: `Error: BendTT infrastructure:
  the kernel did not build (lean: Executable not found in $PATH: "lean");
  --verdict needs Lean v4.34.0 (elan toolchain leanprover/lean4:v4.34.0), or
  $BENDTT set to a built kernel`.
- `git diff master -- LAWS.bend PROOF.bend`: empty.
- OpenSpec 1.16.0 `validate --all --strict --no-interactive`: 44 passed,
  0 failed.

## Concerns

1. Landlock is not in the ruled control mapping. LH-005 names Landlock
   rights, but the plan's mapping (used verbatim) credits no control with a
   Landlock right or with `no_new_privs`/privilege drop. The model half holds
   (no report short of the five controls admits), but Task 3 must decide which
   control a Landlock right is credited under. Recorded as a reviewed-only gap
   in the traceability row and in INVENTORY.md.
2. Box 1.1 is checked per the brief, but its text includes native pins
   (runtime, kernel, Landlock ABI) that are Tasks 2 and 3. The box carries a
   parenthetical saying only the model half is done; the controller may
   prefer to leave it unchecked until Task 3.
3. Design choices beyond the brief's letter, for review: admission is the
   broker's `Barrier` frame (carrying the worker's request snapshot), not a
   bare worker frame, because `admit_worker` needs broker facts and the
   module stores none; worker `Use` frames go to read-only `P.use`; `Usage`
   and `Emission` broker frames route to `charge` and `diagnostic` (the plan
   ruling lists them); `Complete`/`Release` are `Unrouted` until section 2.
   The translators add two identity consistency refusals (StaleLaunch,
   PeerMismatch) and two vocabulary refusals (UnknownFamily,
   UncreditedControl); none is a contract `Error` and none changes state.
4. The replay imports `HostConformanceTests.bend` (a test module, unchanged)
   to reuse its chains rather than duplicating ~1000 lines; it also imports
   `HostPrimitivesTests`/`HostIdentityTests` for state and origin equality.
5. The Linux replay runs the shared transitions through the vector harness
   with the Linux identity and the translated report and inventory; it does
   not route the vectors through `dispatch` (the dispatch has its own checks).
   It is model evidence only; no native broker exists.
