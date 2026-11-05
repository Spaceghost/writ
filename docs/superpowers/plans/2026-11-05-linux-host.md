# Plan: Native Linux host, section 1 (runtime and authority boundary)

Spec: `openspec/changes/add-linux-host/` (requirements LH-001 to LH-010 in
`specs/linux-host/spec.md`; this plan builds section 1, tasks 1.1 to 1.4
"Runtime and authority boundary"; section 2, "Release and evidence", tasks 2.1
to 2.4, is a later plan). Read first: `AGENTS.md` (the approved
`contrib/native-hosts/` exception: C/C++ OS ABI, resource/handle lifetimes, a
small harness; Linux bindings translate native facts and perform admitted
effects but implement no policy, grants, labels, accounting, replay rules, or
release decisions; the authoritative state stays in Bend; no root Go module;
host qualification distinct from library tests; a native descriptor is not a
portable credential), `docs/PLATFORMS.md` ("The shared host contract" and the
"Direct Linux" row), `docs/HOST-PLATFORMS.md` ("Linux: construct a closed
worker environment"), `openspec/README.md`, the change (`proposal.md`,
`design.md`, `specs/linux-host/spec.md`, `tasks.md`), the shared host contract
this consumes (`HostWire.bend`, `HostIdentity.bend`, `HostPrimitives.bend`,
`HostPublication.bend`, `HostConformanceVectors.bend`, and their tests;
`verification/portable-host-vectors.txt` with its 37 lines;
`openspec/changes/add-portable-host-contract/` design and tasks, whose section
2 asks for the native adversarial probes, mutable-alias elimination under
revocation and crash, and per-target evidence this lane supplies for one
target), the existing Linux native work
(`contrib/native-hosts/linux/`, `contrib/native-hosts/AGENTS.md`,
`contrib/native-hosts/PROTOCOL.md`, `contrib/native-hosts/VERIFICATION.md`, the
FUSE canary's `writfs.c`/`worker.c`/`policy_pipe.c`/`crash_probe.c` and
`verification/README.md`, `.github/workflows/writfs-linux-native.yml`),
`hosts/genode/INVENTORY.md` and `hosts/unikraft/INVENTORY.md` (the trust
inventory shape), and `Tests.bend` (how test modules register; the corpus is
1428, the count pins are live, so any new check means a re-pin at merge).

The gap. The portable host contract exists as one shared Bend model
(`HostWire`, `HostIdentity`, `HostPrimitives`, `HostPublication`,
`HostConformanceVectors`), tested on two synthetic adapters A and B. No target
binds it. The only Linux native code is the FUSE mounted-view canary
(`contrib/native-hosts/linux/`), which is the bounded `native-host-canary-mounts`
slice: one immutable public object over private pipes, not the general
protected-worker broker the Linux host contract describes. There is no Linux
monitor that drives the shared `HostPrimitives` transitions, no authenticated
worker session over a Unix socket with `SO_PEERCRED`, no scoped descriptor
delivery by `SCM_RIGHTS`, and no per-control evidence that each required kernel
control is load-bearing. Section 1 adds the Linux adapter (a third conforming
adapter in Bend), the native broker and confined worker that establish the
authority boundary, and the executed per-control evidence. It adds no release
path: sealing, the common Bend commit gate, durable publication, revocation and
quiescence, the full egress-channel matrix, GPU separation, and the per-target
runtime qualification record are section 2.

## Global Constraints

- Lane `lane/linux-host`, worktree `../writ-lanes/linux-host`, created from
  master. Environment:
  `export PATH="$HOME/.local/share/writ-toolchains/bend-2.0.39/bend/bin:$PATH"; export BEND_NO_TELEMETRY=1`.
  Native C builds use `clang-19` (or the pinned `gcc` the CI lane records);
  generated JavaScript/C and binaries go to `../writ-build/linux-host/`, never
  into the checkout (`contrib/native-hosts/linux/Makefile` already refuses an
  `OUT` inside the source tree).
- Touch only these paths.
  - New Bend under `hosts/linux/`: `hosts/linux/monitor/LinuxHost.bend` (the
    adapter: Linux host/incarnation and profile constants, the fact-translation
    helpers, and the monitor dispatch that drives the shared `HostPrimitives`
    transitions over a trusted-broker-fact channel and an untrusted worker
    `HostWire` channel); `hosts/linux/monitor/LinuxHostTests.bend` (model tests
    plus a replay of the 37 conformance vectors through a Linux adapter
    fixture; registered in `Tests.bend`); `hosts/linux/INVENTORY.md` (the
    Linux host trust inventory, in the shape of `hosts/genode/INVENTORY.md`).
  - New C under `contrib/native-hosts/linux/`: `broker.c`, `broker.h` (the
    Unix-domain broker: `SO_PEERCRED` session authentication matched to the
    trusted launch record, the launch/session/incarnation/generation binding
    reported to the Bend monitor, `SCM_RIGHTS` scoped descriptor delivery, the
    bounded request snapshot and monitor-owned handle resolution, and the two
    private channels to the generated Bend monitor); `launch.c`, `launch.h`
    (the confinement prelude: credentials and user/mount/net/IPC/PID/UTS
    namespaces, privilege removal, `no_new_privs`, the architecture-checked
    seccomp allowlist, the Landlock ABI probe with every required right, the
    resource/lifetime limits and parent-death, and the inherited-descriptor
    allowlist); `broker_probe.c` (the control-matrix and identity harness).
  - New verification evidence in the shape of the existing native record
    (`contrib/native-hosts/linux/verification/run-41776660115/`):
    `contrib/native-hosts/linux/verification/broker-v1/` holding
    `environment.log`, `source-and-build-sha256.txt`, `native-build.log`,
    `controls.log` (per-control denied-without/admitted-with), `identity.log`
    (session authentication cases), `escape.log` (descriptor/egress attempts),
    and a `README.md` pinning the exact kernel, libraries, source hashes and
    outcomes; plus `contrib/native-hosts/linux/verification/README.md` updated
    with a broker-v1 section that keeps the canary section unchanged.
  - New `openspec/traceability/linux-host.md`.
  - Edited: `Tests.bend` (one import and one call group, below the existing
    `HostConformance` registration); `contrib/native-hosts/linux/README.md`
    (one new "Broker profile" section and its source/trust inventory rows, the
    canary section left intact); `contrib/native-hosts/linux/Makefile` (new
    build targets only); `.github/workflows/writfs-linux-native.yml` (one added
    job or step that builds the broker and runs `broker_probe`, uploading its
    logs, the existing canary steps unchanged);
    `openspec/changes/add-linux-host/tasks.md` (check boxes 1.1 to 1.4 and the
    header line).
  - Nothing else. In particular do not modify any shared contract module
    (`HostWire`, `HostIdentity`, `HostPrimitives`, `HostPublication`,
    `HostConformanceVectors`, their tests), any `Core`/`Transfer`/`Dlm`/
    `Ledger`/`Negotiation`/`Frontend`/`Backplane`/`DataOS` module, `LAWS.bend`,
    `PROOF.bend`, the FUSE canary C sources, `writfs/`, `hosts/genode/`,
    `hosts/unikraft/`, `docs/PLATFORMS.md`, or any count pin. If a task appears
    to need one of these, stop and report BLOCKED.
- Plan ruling (module placement): the Linux adapter lives under `hosts/linux/`,
  parallel to `hosts/genode/` and `hosts/unikraft/`, not at the repository
  root. The root modules are the target-neutral contract; `hosts/<target>/` is
  the code that depends on it. `LinuxHost.bend` imports the contract and never
  the reverse; it imports nothing under `contrib/` and defines no new
  transition, so it is a binding, not a second policy engine.
- Plan ruling (the adapter adds no policy and no law): `LinuxHost.bend` only
  (a) names the Linux host id, incarnation, and the versioned profile table as
  constants, (b) translates a broker-reported native fact into a
  `HostPrimitives.Fact`, `TargetReport`, `RouteFact`, or `SessionEvidence`
  value, and (c) sequences the shared transitions (`open_session`, `issue`,
  `use`, `delegate`, `admit_worker`, `charge`, `diagnostic`) over its two input
  channels. Every decision stays in the imported transitions. No new
  `HostIdentity`/`HostPrimitives` case, no new `Error`, no new law. So
  `LAWS.bend` and `PROOF.bend` are untouched and `bend PROOF.bend` must print
  the same result as on master.
- Plan ruling (two input channels; facts come only from the trusted broker):
  the Linux monitor consumes two framed channels. The untrusted worker channel
  carries only `HostWire` byte frames (`Use`, `Delegate`, `Complete`,
  `Release`), decoded by `HostWire.decode_bytes`, which yield descriptions and
  never authority. The trusted broker channel carries native facts: the
  authenticated `SessionEvidence` (caller subject from the launch record, the
  origin the broker observed, `delegable` false for a worker), the
  `TargetReport` (which controls the broker established, probed from kernel
  state), and the `Inventory` (the worker's complete route set). A worker frame
  can never be read as a fact, and a broker frame can never carry a `HostWire`
  request's authority; the broker is the supervisor in the `docs/PLATFORMS.md`
  topology and is explicitly trusted. The subject in a worker frame's
  `claimed_subject` is kept untrusted and is never read by any transition
  (`HostPrimitives.use` ignores it).
- Plan ruling (the FUSE canary is not changed): the mounted-view canary
  (`writfs.c`, `worker.c`, `policy_pipe.c`, `crash_probe.c`, `transport_probe.c`)
  stays byte-identical and its evidence stays historical. It is the bounded
  `native-host-canary-mounts` slice; the broker here is the general
  protected-worker boundary of `add-linux-host`. Shared confinement idioms
  (the launch prelude, the private-channel framing) are re-expressed in the new
  `launch.c`/`broker.c`, not refactored out of the canary. (See the open
  question below on whether the two should later converge.)
- Native facts the broker may report, and that none is an authority fact. The
  broker reports: the connecting peer's `SO_PEERCRED` uid/gid/pid and the
  matched pidfd and `/proc/PID/stat` start time; the trusted launch record's
  subject, monitor incarnation, and session generation; which kernel controls
  it installed (namespaces, privilege drop, `no_new_privs`, seccomp, each
  Landlock right, each rlimit); the worker's complete descriptor/route
  inventory; and the stable handle the broker resolved a bounded request to.
  Each is an observation. None is a grant, a label, a budget, a plan, a rights
  mask the worker chose, or a release decision. A uid, pid, descriptor number,
  or socket credential is a local fact, never a portable credential (AGENTS.md,
  `docs/PLATFORMS.md`): `SO_PEERCRED` records connection-time credentials, and a
  parent-created socketpair endpoint passed to a child does not relabel the
  child as the actor (LH-002). The Bend monitor decides; the broker reports and
  then executes only the effects an `Admitted` step returned.
- Executed evidence per control. Each required control carries a paired probe
  recorded in `verification/broker-v1/`: with the control removed the escape it
  guards is admitted (a socket opens, a write lands, a descriptor imports, an
  inherited fd survives) and the probe is marked so; with the control installed
  the same escape is denied, and the worker's one legitimate scoped read is
  admitted only once the complete profile is established before plaintext
  (LH-003). The record uses the shape and polarity of the canary's
  `native-revocation.log` and `setup-refusal.log` (`PASS`/`FAIL`, `PROBE`,
  `SETUP`, `ACTOR`, `PROFILE`, `EVENT` lines). A control whose paired probe
  does not show the differential is not credited; it is recorded and reported,
  never assumed from a model pass or a successful namespace creation (LH-010).
- Host qualification is separate from the library suite. The native harness
  (`broker`, `broker_probe`) never runs inside `Tests.bend`. `Tests.bend` gains
  only the pure Linux adapter model test (`LinuxHost.main()`), which runs
  synthetic broker facts and asserts the Linux adapter reaches the same shared
  decisions as adapters A and B. The broker's actual kernel evidence lives only
  in `verification/broker-v1/` and the CI artifact.
- Validation at every commit: `bend Tests.bend` (final line
  `ALL LIBRARY TESTS PASSED`; every pre-existing check still present; PASS
  count = 1428 + this lane's additions); native:
  `bend Tests.bend -o ../writ-build/linux-host/tests-native && ../writ-build/linux-host/tests-native +RTS --threads 4 --gpu off`
  (same count; this is CPU execution and is not a GPU test); `bend PROOF.bend`
  (`ALL PROOFS CHECK`, unchanged, no new law); `bend PROOF.bend --verdict` only
  if the Lean v4.34.0 kernel toolchain is on PATH, otherwise record its exact
  error line (Lean is not installed on the lane host, so record the refusal);
  and `~/.bun/bin/bunx @fission-ai/openspec@1.16.0 validate --all --strict --no-interactive`
  whenever `openspec/` changed. For the native tasks, also the broker build
  (`make -C contrib/native-hosts/linux OUT=../writ-build/linux-host`) and the
  `broker_probe` runs, with each command, its exit status and stderr, binary
  and log SHA-256 captured into `verification/broker-v1/`. Record every
  command, count, and result in the task report.
- Records: `docs/superpowers/records/2026-11-05-linux-host/`. Append one
  tab-separated line per step (UTC time, role, text) to its `activity.log`.
  While a build, suite run, or probe is going, write a heartbeat line at least
  every 10 minutes; 30 silent minutes marks the lane idle on the board, and no
  single command blocks more than 10 minutes without a heartbeat. Reports go to
  `task-N-report.md`, written early and completed, each giving the count before
  and after, the new check names, the exact native outcomes, and any plan
  ruling applied. Run `git add -A docs/superpowers/records/2026-11-05-linux-host`
  with each commit. One commit per task. No push. The change is not archived
  (section 2 is open).

- Cross-lane ruling (controller, 2026-11-05): two other Bend lanes
  (`lane/policy-aware-audit` and `lane/executor-rendezvous`) are adding tests to
  `Tests.bend` in parallel with this one, and the corpus count pins are live at
  1428. So: (1) this lane changes no recorded count pin, not `README.md`,
  `docs/INSTALL.md`, `utils/nix/writ.nix` (`assertTests` and its comments), the
  count sentences in `VERIFICATION.md`, nor `WRIT_CORE_EXPECTED` in any
  `.github/workflows/*.yml`; its records state the count its own tree prints
  ("1428 plus N new checks = M"), and the controller re-pins every count once
  after the three lanes merge, then watches the Genode CI run on that push;
  (2) keep this lane's `Tests.bend` edit to the smallest registration block,
  one import and one `LinuxHost.main()` call placed after the `HostConformance`
  entry, so a merge with the other lanes is a two-line conflict at most;
  (3) earlier Linux native evidence (the FUSE canary runs) stays historical and
  is not re-recorded here; (4) the `writfs-linux-native.yml` edit adds a job and
  does not retune the existing canary steps, so it does not collide with the
  audit or rendezvous lanes, which touch no workflow.

- Controller rulings on the plan author's questions (2026-11-05): (1) executed evidence for the controls comes from two places and each row says which: unprivileged user namespaces on the lane host for every control that needs no privilege (unprivileged_userns_clone is 1 here; no sudo is available and none is to be requested), and the existing writfs-linux-native.yml CI VM for the privileged ones, through the broker job Task 5 adds; a control that ran in neither place is a quoted gap, never a pass. (2) The broker stays a separate contribution from the FUSE mounted-view canary for section 1 and the canary stays byte-identical; whether they converge later is put to Spaceghost on q18.

### Task 1: Linux adapter, profile, and conformance replay (tasks.md 1.1, consuming 1.2 to 1.4)

Requirements it implements, by name: LH-001 "A supported profile is explicit"
(the model half: the profile is a named, versioned, monitor-owned record, and
an admission whose `TargetReport` lacks a required family or control is denied
`UnsupportedFamily`/`MissingControl` with no `DeliverInputs`); LH-005 "Required
Landlock rights cannot be dropped" (the model half: a profile requires a fixed
control set and a report short of it cannot admit under a reduced set); and the
model consumption of LH-002 "Worker identity is bound to an authenticated
lifetime", LH-003 "Confinement precedes protected observation", LH-004
"Inherited authority is explicitly bounded", LH-006 "Broker requests preserve
exact resource scope", and LH-007 "Delegation is explicit and attenuating" (the
Linux adapter drives the shared transitions that enforce these; the native
establishment of each is Tasks 2 to 4).

Create `hosts/linux/monitor/LinuxHost.bend`, importing `Base`, `HostWire`,
`HostIdentity`, `HostPrimitives`, `HostPublication`, `Frontend`, and `Transfer`
only. Header: this is adapter glue for the direct Linux target; it supplies
only `Fact`/`TargetReport`/`RouteFact`/`SessionEvidence` values and executes
only the `Effect` values an `Admitted` step returned; it decides nothing, adds
no transition and no law, and no native fact it carries is an authority fact.

- `linux_host()` and `linux_incarnation()`: the Linux monitor's host id and
  starting incarnation (named constants, nonzero).
- The profile table. One configured profile `linux-worker-v1`:
  `required_families = HostPrimitives.all_families()`;
  `required_controls` = `control_address_isolation() .|. control_no_ambient_network() .|. control_output_mediation() .|. control_quota() .|. control_no_inherited_routes()` (every control but accelerator isolation); `backend = Cpu{}`;
  a named `quota_limit()`. Plan ruling: the control-to-kernel mapping the
  broker must satisfy, documented in the header and mirrored in
  `hosts/linux/INVENTORY.md`: `control_address_isolation` = private
  mount/IPC/PID/UTS namespaces, pivoted root, nondumpable; `control_no_ambient_network`
  = private network namespace with seccomp denying socket creation;
  `control_output_mediation` = only the private result channel survives, all
  public streams closed; `control_quota` = the address-space/CPU/NOFILE/NPROC
  and zero core/file-size rlimits; `control_no_inherited_routes` = the
  descriptor allowlist, `SCM_RIGHTS`-only input, and denied descriptor import.
  An `Accelerator{}` profile is not offered in section 1 (GPU is section 2 and
  `add-genode-host`/`validate-physical-gpu-execution` territory); the adapter
  denies an accelerator request through the shared `UnisolatedAccelerator` path
  rather than defining one.
- Fact translation. Pure helpers from a `LinuxFact` record the broker frames
  (its fields named below) to the shared types: `session_evidence_of` builds
  `SessionEvidence{caller, origin, delegable}` from the authenticated subject,
  the observed origin, and `delegable=False` for a worker; `report_of` builds
  `TargetReport{supported_families, established_controls}` from the installed
  control bits; `inventory_of` builds `Inventory{routes}` from the reported
  route set. No helper produces a `Context`, `Binding`, plan, rights grant, or
  caller that a transition treats as authority.
- Monitor dispatch. `initial()` is `HostPrimitives.empty(HostIdentity.empty(linux_host(), linux_incarnation()), profiles())`.
  `dispatch` applies exactly one transition per framed input: a trusted broker
  fact routes to `open_session`/the fact-consuming transition; an untrusted
  worker frame is `HostWire.decode_bytes`d and routed to `use`/`delegate`/
  `admit_worker` on the session the transport identified. The claimed subject
  is never read. The monitor retains the advanced state before the broker
  performs an admitted effect, exactly as `contrib/native-hosts/PROTOCOL.md`
  requires of the canary interpreter.

Create `hosts/linux/monitor/LinuxHostTests.bend` (registered in `Tests.bend` as
`LinuxHost`), importing `HostConformanceVectors` and the shared modules. Header:
every session, subject, report, inventory, and fact is SYNTHETIC MONITOR STATE,
standing in for what a real broker would report; nothing here authenticates a
caller or confines a worker. Checks:
- A Linux adapter fixture (`V.Adapter` with `host = linux_host()`, the Linux
  incarnation, and a report/inventory shaped like the broker's) replays all 37
  `HostConformanceVectors` vectors and reaches the same normalized outcome as
  adapters A and B for every one; assert the rendered line list equals
  `V.expected_lines()`.
- Profile checks: an admission whose report omits each required control bit in
  turn is denied `MissingControl`; a report omitting a required family is
  denied `UnsupportedFamily`; a report with every control admits and emits one
  `DeliverInputs` as the last step (LH-001, LH-003, LH-005).
- Translation checks: each fact-translation helper is a named check against a
  known `LinuxFact` input; a worker frame's `claimed_subject` of B on A's
  session resolves to A (the claim is never read).
- Each denial asserts full primitive-state equality with its input and no
  effect.
  End `main` with one summary line `LinuxHost: N checks passed` and nothing
  starting with `PASS`.

Create `hosts/linux/INVENTORY.md` (shape of `hosts/genode/INVENTORY.md`):
status, the Bend adapter files and that none is Writ policy, the profile and
its control-to-kernel mapping, and the explicit statement that the native
broker's facts are inputs and the Bend monitor holds the authority. Create
`openspec/traceability/linux-host.md` with a header naming the change, the
implementation and test modules, and the rule "model rows only in this task;
native evidence is Tasks 2 to 4". Add the LH-001 and LH-005 model rows with
exact check names. Register the module in `Tests.bend` (one import, one call).
Check box 1.1 citing the module and test file.

Acceptance: every listed check is named and green on both backends with PASS
count = 1428 + this task's checks; the 37-vector replay matches
`V.expected_lines()`; `bend PROOF.bend` is unchanged; OpenSpec strict passes.
One implementer dispatch.

### Task 2: Native broker and authenticated worker session (tasks.md 1.2)

Requirements it implements, by name: LH-002 "Worker identity is bound to an
authenticated lifetime" (both scenarios: "Parent-created socketpair is
inherited", "An endpoint moves to another process"); and the transfer-denial
half of LH-007 "Delegation is explicit and attenuating" ("Sender transfers an
FD without a delegation record").

Create `broker.c`/`broker.h` and the launch/session binding in `launch.c`/
`launch.h`. The broker owns a bounded `AF_UNIX` `SOCK_SEQPACKET` listener, the
trusted launch record, the two private channels to the generated Bend monitor
(`hosts/linux/monitor/LinuxHost.bend` built to a `.mjs` and run under Node with
a transport like `contrib/native-hosts/runtime/node-policy.mjs`, or the same
module invoked in-process), and the native session/handle table. It:
- Builds a trusted launch record before fork: the selected subject, the monitor
  incarnation, a fresh session generation, and the intended worker. It launches
  the worker (confinement from Task 3) and retains its pidfd and
  `/proc/PID/stat` start time.
- Authenticates each connection with `SO_PEERCRED`, then matches the credential
  to the retained pidfd and start time. Only a peer that is the launched worker
  with the recorded lifetime binds to its session; it reports a
  `SessionEvidence` to the monitor with the launch record's subject, never the
  peer's uid. `SO_PEERCRED` on a parent-created socketpair records the parent's
  connection-time credentials, so the broker never treats socketpair-time
  credentials as the child's identity; the binding comes from the launch record
  (LH-002, scenario one). It feeds `HostIdentity` through the Bend monitor:
  session id, incarnation, generation, caller, origin.
- Resolves every worker request to a session and reference through the monitor's
  `HostIdentity.resolve` only; a frame on a session that is not the bound holder,
  or a reference whose generation/incarnation is stale, is denied by the monitor.
- Denies descriptor transfer as authority acquisition: an ancillary
  `SCM_RIGHTS` descriptor arriving on a session without an approved delegation
  record does not authorize the sender as another subject; the broker drops it
  and the monitor denies the operation (LH-007, scenario one; the attenuating
  delegation path itself is modeled in `HostIdentity.delegate` and exercised in
  Task 4's resource-lookup probes).

`broker_probe.c` (or a `--case` of the broker) records, into
`verification/broker-v1/identity.log`:
- Claimed identity: a worker frame claiming another subject binds to the
  authenticated subject, not the claim.
- Parent-created socketpair: a socketpair made by a parent and handed to a
  child is not accepted as the child's identity; the bound actor comes from the
  launch record.
- PID reuse: after the worker exits and its pid is reused by an unrelated
  process, a frame on the old session is denied (the pidfd/start-time mismatch
  and the stale session generation).
- Namespace identity mapping: the worker's in-namespace uid/pid differ from the
  broker's view; the binding uses the launch record, not the in-namespace
  numbers.
- Transferred endpoint: a process that obtains the session socket from the
  worker and sends a frame is not authorized as the original subject.

Each case is a `PASS`/`FAIL` line with the kernel-observed values, in the shape
of the canary's `native-revocation.log`. Add the build targets to the Makefile
and the broker source/trust rows to `contrib/native-hosts/linux/README.md`
(canary section intact) and `hosts/linux/INVENTORY.md`. Add the LH-002 and
LH-007 native rows to `openspec/traceability/linux-host.md`, each citing the log
and its exact assertions. Check box 1.2.

Acceptance: the broker builds with `-Wall -Wextra -Werror`; each identity case
produces its recorded `PASS` line against real kernel credentials on the
qualification host (see the open question on where that host is); the Bend
suite and proofs are unchanged. One implementer dispatch.

### Task 3: Confinement before plaintext (tasks.md 1.3, and the native half of 1.1 and LH-005)

Requirements it implements, by name: LH-003 "Confinement precedes protected
observation" (both scenarios: "Filter setup fails", "A thread escapes setup
coverage"); LH-001 "A supported profile is explicit" (the native preconditions:
the runtime, architecture, kernel configuration, and required interfaces are
verified before protected work, and a model-only host is reported when no
broker is installed); and LH-005 "Required Landlock rights cannot be dropped"
("Older ABI lacks a required scope").

Extend `launch.c`/`launch.h`. The worker launch establishes the complete
`linux-worker-v1` profile before the broker delivers any protected input:
- Credentials and the user/mount/net/IPC/PID/UTS namespaces; privilege removal;
  `no_new_privs`; the architecture-checked seccomp allowlist (deny process
  creation, tracing, namespace change, descriptor import, async I/O, socket
  creation, and device interfaces); the Landlock ABI probe that requires every
  right the profile names and refuses launch on an older ABI that lacks one
  (never a reduced ruleset); and the resource/lifetime rlimits with
  parent-death. The worker children are forked before the source is loaded or
  Bend authority exists, as the canary's are, so a fork never copies broker
  memory after admission.
- The barrier: any failed setup step terminates the pending worker without
  delivering protected data, and the profile is installed for every execution
  thread before untrusted code runs; if a thread could escape coverage, dispatch
  is denied (LH-003, scenario two).
- Preconditions: the broker records the kernel, architecture, Landlock ABI,
  seccomp availability, namespace availability, and the pinned runtime, and
  reports model-only (no protected execution) when a required interface is
  absent, substituting no weaker profile.

The probe harness records, into `verification/broker-v1/controls.log`, one
paired probe per control: with the control removed the escape it guards is
admitted and the worker never reaches a legitimate read; with the control
installed the escape is denied and the single scoped read is admitted only
after the complete profile is established. Include the deliberate
missing-Landlock-right refusal in the shape of the canary's `setup-refusal.log`
(`SETUP step=...`, `SETUP REFUSED before input loading or Bend admission`),
and the per-step failure injection (namespace, privilege, `no_new_privs`,
seccomp, Landlock, rlimit) each terminating before plaintext.

Plan ruling (privileged vs unprivileged establishment): the broker launches the
worker through unprivileged user namespaces where the host allows them, so the
probes need no root; a control that cannot be established unprivileged on the
qualification host is recorded and reported, never silently dropped. Whether
the qualification host permits unprivileged user namespaces is the open
question below; the implementer confirms it on the chosen host before claiming
any control, and records the exact kernel knobs
(`/proc/sys/kernel/unprivileged_userns_clone`, the AppArmor
`apparmor_restrict_unprivileged_userns` state, `/sys/kernel/security/lsm`).

Record the environment and source/build hashes into
`verification/broker-v1/environment.log` and `source-and-build-sha256.txt`. Add
the LH-001 (native preconditions), LH-003, and LH-005 (native) rows to the
traceability file with exact log references. Check box 1.3.

Acceptance: each required control shows its differential in `controls.log`; the
missing-right and per-step injections refuse before plaintext; the model-only
report is recorded when an interface is removed; the Bend suite and proofs are
unchanged. One implementer dispatch.

### Task 4: Descriptor allowlisting, SCM_RIGHTS delivery, and broker resource lookup (tasks.md 1.4)

Requirements it implements, by name: LH-004 "Inherited authority is explicitly
bounded" (both scenarios: "An old writable file descriptor survives", "An
environment variable names a private broker socket"); LH-006 "Broker requests
preserve exact resource scope" (both scenarios: "Validated request bytes are
changed", "A descriptor number is recycled"); and the scope half of LH-007
"Delegation is explicit and attenuating" ("Delegate asks for a broader
destination").

Extend `broker.c`/`launch.c`. The launch inventories the worker's effective
authority and removes every inherited descriptor, mapping, credential, and
environment-derived resource outside the declared profile (the public standard
streams, device access, and any inherited environment value that names a
private broker socket are excluded before protected inputs are released); a
writable descriptor opened before Landlock enforcement is removed or the launch
is denied, and later path restrictions are not credited with revoking it
(LH-004). The broker delivers the scoped inputs only by `SCM_RIGHTS` on the
private channel, as the one `DeliverInputs` effect of an accepted admission, and
resolves every bounded request through its own stable handle and the monitor's
current registry: it copies and validates a bounded snapshot of the request
before deciding, so request bytes changed after submission cannot select a
different action, and a recycled descriptor number cannot resolve to a new
resource under an old reference and generation (LH-006). An attenuating
delegation is driven through `HostIdentity.delegate` (exact plan copied, rights
and expiry only narrowing); a delegate asking for a broader destination than
its parent's plan is denied under the original plan scope (LH-007).

The probe harness records, into `verification/broker-v1/escape.log`, the
descriptor and resource matrix, each as a paired or adversarial probe with the
kernel outcome: an inherited writable fd surviving into the worker (removed, or
launch denied); an inherited environment value naming the broker socket
(excluded); a descriptor import attempt (denied); a request buffer mutated after
submission (the validated snapshot decides); a recycled descriptor number under
an old reference (denied); direct-copy, mmap, ioctl, and asynchronous-I/O bypass
attempts (denied, as the canary's `W_MMAP_*`, `W_IOCTL_DENY`, `W_IOURING_DENY`,
`W_COPY_DENY`, `W_RIGHTS_DENY` probes already do, now under the broker's
session); and a delegate requesting a broader destination (denied by the
monitor).

Add the LH-004, LH-006, and LH-007 (scope) rows to the traceability file. Check
box 1.4.

Acceptance: every matrix row produces its recorded outcome against the real
kernel on the qualification host; `SCM_RIGHTS` is the only input route and the
inventory is bounded; the Bend suite and proofs are unchanged. One implementer
dispatch.

### Task 5: Evidence, CI, traceability, and records

No new requirement; this task consolidates and validates the section-1
evidence, and names section 2.

- Write `contrib/native-hosts/linux/verification/broker-v1/README.md` pinning
  the exact source commit and tree, the kernel, architecture, Landlock ABI,
  libraries, runtime, and compiler versions, the source/build SHA-256 set, and a
  per-file index of `environment.log`, `native-build.log`, `controls.log`,
  `identity.log`, and `escape.log`, in the shape of
  `verification/run-41776660115/README.md`. Preserve any failed outcome
  verbatim. State that section 1 establishes the authority boundary only: it
  claims no release, no sealing, no durable publication, no revocation
  quiescence, and no GPU behavior, and it does not qualify arbitrary
  applications or a complete protected-data host.
- Update `contrib/native-hosts/linux/verification/README.md` with a broker-v1
  section (the canary section unchanged) pointing at the new evidence and the
  CI run.
- Extend `.github/workflows/writfs-linux-native.yml` with one job (or step) that
  builds the broker and runs `broker_probe`, uploading
  `verification/broker-v1/`-shaped logs as an artifact, with the existing canary
  steps unchanged and no count assertion added. Plan ruling: extend the existing
  Linux lane rather than add a new workflow, so the Linux native evidence stays
  in one place and the two parallel Bend lanes (which touch no workflow) do not
  collide.
- Finalize `openspec/traceability/linux-host.md`: every LH-001 to LH-007 row is
  model-tested (named checks or the 37-vector replay) or native-evidenced (a
  named log with its exact assertions); LH-008, LH-009, and LH-010 are marked
  "section 2, pending" and are not claimed. In
  `openspec/changes/add-linux-host/tasks.md`, set the header line to say section
  1 (the runtime and authority boundary) has landed as a Linux adapter plus a
  native broker/confinement with per-control evidence, and section 2 (release
  and evidence: sealing, the common Bend commit gate, durable publication,
  revocation and quiescence, the full egress matrix, GPU separation, and the
  per-target runtime qualification record) is pending; the change stays
  unarchived.
- Run `bend Tests.bend` (record the printed count as "1428 plus N = M"; change
  no count pin), the native run, `bend PROOF.bend` (unchanged),
  `bend PROOF.bend --verdict` (record the exact refusal while Lean is absent),
  and OpenSpec strict. The report states that the Genode CI run at the new count
  has not been executed by this lane (the controller re-pins and runs it after
  the three lanes merge).

Acceptance: every evidence file agrees with the stored runs and preserves
failures; traceability marks every section-1 row model-tested or
native-evidenced and marks LH-008/LH-009/LH-010 pending; OpenSpec strict passes;
`bend PROOF.bend` passes with `--verdict` reported as run or with its exact
error; the change is not archived. No count pin is touched. One implementer
dispatch.
