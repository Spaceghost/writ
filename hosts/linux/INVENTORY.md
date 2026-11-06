# Linux host trust inventory (add-linux-host)

Status: the direct Linux Bend adapter is model-tested. Partial native broker,
launcher and invocation-harness source now exists under
`contrib/native-hosts/linux/`, but it is unfinished and is not a qualified
protected-worker host. The [plan](../../docs/superpowers/plans/2026-11-05-linux-host.md)
Tasks 2 to 4 still need integration and executed native evidence, including
identity, confinement and failure behavior. Protected execution remains
unavailable for this host profile (LH-001). A green `bend Tests.bend` is
library evidence, not native host qualification. The separate WritFS public
canary and its evidence are described in the
[native Linux README](../../contrib/native-hosts/linux/README.md).

This file lists Linux host binding code. None of it is Writ policy: no
authority, grant, label, budget, accounting, replay, or release decision is
made here. Every decision is a shared transition in `HostIdentity.bend`,
`HostPrimitives.bend`, or `HostPublication.bend`.

## Files

| File | Role | Run by |
| --- | --- | --- |
| `hosts/linux/monitor/LinuxHost.bend` | Adapter glue: the Linux host id and incarnation, the profile table (`linux-worker-v1`), the translators from broker-framed native facts (`LinuxFact`) to `SessionEvidence`, `TargetReport`, and `Inventory`, and the two-channel `dispatch` that applies at most one shared transition per framed input. Adds no transition, no `Error`, and no law. | imported by the test module; the native broker (Tasks 2 to 4) will run it as the generated Bend monitor |
| `hosts/linux/monitor/LinuxHostTests.bend` | Model tests on SYNTHETIC broker facts, and the replay of the 37 portable-host conformance vectors through a Linux adapter fixture | `Tests.bend` as `LinuxHost` |

No C, JavaScript, or other native file is in `hosts/linux/`. The partial
protected-worker sources in `contrib/native-hosts/linux/` are inventoried in
the [native Linux README](../../contrib/native-hosts/linux/README.md#separate-experimental-protected-worker-broker).
They are separate from the WritFS canary; neither their presence nor model
tests establish that they implement or qualify the proposed host profile.

## Authority

The target design treats the native broker's facts as inputs; the Bend monitor
holds the authority. A qualified broker must be the trusted supervisor of the
docs/PLATFORMS.md topology: it must report observations and execute only the
effects of an `Admitted` step the monitor returned, after the monitor has
retained the advanced state (contrib/native-hosts/PROTOCOL.md). The partial
sources do not establish these host guarantees. **None of the facts below is
an authority fact**: none is a grant, label, budget, plan, rights mask, profile, or release
decision, and each reaches stored state only through a shared transition
(`open_session`, `admit_worker`, `charge`, `diagnostic`) or not at all. A uid,
gid, pid, start time, or descriptor number is a local fact, never a portable
credential.

### Facts the target broker must report

| Fact | Native source | Frame field | Contract destination | Why it is not authority |
| --- | --- | --- | --- | --- |
| Launch subject | trusted launch record | `LinuxFact.subject` | `SessionEvidence.caller` (with the token), consumed by `open_session`; compared with the session's caller at a Barrier | names who the launch record was issued for; the session id, delegability, and role are the monitor's |
| Launch code token | trusted launch record | `LinuxFact.token` | as the subject | identifies code, grants nothing |
| Launch record's monitor incarnation | trusted launch record | `LinuxFact.incarnation` | compared only (StaleLaunch) | a freshness check |
| Expected process credential (uid, gid, pid, start time) | trusted launch record | `LinuxFact.launch` | compared only (PeerMismatch) | local fact |
| Connected peer credential (uid, gid, pid, start time) | `SO_PEERCRED`, pidfd, `/proc/PID/stat` | `LinuxFact.peer` | compared only (PeerMismatch) | connection-time local fact; a socketpair endpoint does not relabel its holder |
| How the endpoint arrived | broker launch bookkeeping | `LinuxFact.endpoint` | `SessionEvidence.origin` at Launch; ignored at a Barrier | HostIdentity decides what an inherited or transferred origin may do |
| Contract families the binding implements | broker build | `LinuxFact.families` | `TargetReport.supported_families`, compared with the bound profile | can only fall short of the profile, never widen it |
| Established controls | kernel state the broker installed and probed | `LinuxFact.controls` | `TargetReport.established_controls`, compared with the bound profile | as families; bits the broker cannot credit are refused (UncreditedControl) |
| Descriptor inventory (number, kind, mediated) | the worker's fd table after the allowlist | `LinuxFact.routes` | `Inventory` of `RouteFact{kind, mediated}`; numbers dropped | an unmediated route can only deny |
| Barrier session | the broker's attribution of the barrier to a session | `Barrier.session` | the session `admit_worker` resolves on; checked against the fact's caller (SessionMismatch) | the entry, profile, and delegability are the identity table's |
| Request snapshot | worker bytes, copied once, bounded | `Barrier.request` | `W.decode_bytes`; only a Use's reference reaches `admit_worker` | a description that must resolve on the session; claim, operation, rights discarded |
| Resource request | broker's observation of the worker | `Usage{worker, amount}` | `P.charge` | bounded by the configured quota; changes only `quota_used` |
| Output attempt | broker's observation of the worker | `Emission{worker, public}` | `P.diagnostic` | a public emission is denied |
| Worker transport session | the worker connection the broker accepted | `FromWorker.session` | the session `use`/`delegate` resolve on | attribution only; the worker's bytes are untrusted |
| Session generation | trusted launch record | not yet framed (Task 2) | none yet | the replay obligation below |
| Each Landlock right, `no_new_privs`, privilege drop | kernel probes | not yet framed (Task 3) | none yet; which control they are credited under is open | evidence, not authority |
| Stable handle a bounded request resolved to | broker resource registry | not yet framed (Task 4) | none yet | must follow the monitor's resolution |

### Broker obligations (mirroring HostPrimitives' section-2 host obligations)

1. Execute only the effects of an `Outcome` this monitor returned, after the
   monitor has retained `Outcome.state`; a constructed `Effect` is not
   authorization.
2. Attribute each frame to the right session or worker: `Barrier.session`,
   `FromWorker.session`, and `Usage`/`Emission.worker` are trusted
   attribution the monitor cannot check beyond the session's caller.
3. Report as the barrier credential the session's own launch credential (the
   monitor stores none), and fix the endpoint at Launch.
4. Take the request snapshot once, bounded, before deciding; act on nothing a
   worker writes after it.
5. Execute nothing on a `Checked` result in section 1; the Task 4 resource
   lookup acts on the monitor's resolution, never on worker bytes.
6. Issue one Launch per launch-record generation: the adapter implements no
   replay rule, and a repeated Launch opens another session.
7. Report the complete descriptor inventory, remove or mediate every route
   before execution, enforce the quota natively, and report a control only
   when its kernel mechanism (below) is installed for every thread.
8. Use the monitor's trusted, monotone clock for every `now`.

The intended worker channel carries only HostWire bytes on the session the
broker's transport identified. A worker frame cannot carry a fact, and its
claimed subject is never read.

## Profile `linux-worker-v1`

| Field | Value |
| --- | --- |
| id | `linux_worker_v1()` = 1 |
| required families | `all_families()` (session, worker, artifact, publication, revocation) |
| required controls | address isolation, no ambient network, output mediation, quota, no inherited routes (every control but accelerator isolation) |
| backend | `Cpu` |
| quota limit | `quota_limit()` = 1024 |

Control-to-kernel mapping the broker must satisfy before it reports a
control bit (plan ruling; each needs a paired native probe in Tasks 2 to 4
before it is credited):

| Control | Linux mechanism |
| --- | --- |
| `control_address_isolation` | private mount, IPC, PID, and UTS namespaces; a pivoted root; nondumpable |
| `control_no_ambient_network` | a private network namespace with seccomp denying socket creation |
| `control_output_mediation` | only the private result channel survives; every public stream is closed |
| `control_quota` | address-space, CPU, NOFILE, and NPROC rlimits; zero core and file-size rlimits |
| `control_no_inherited_routes` | the descriptor allowlist, `SCM_RIGHTS`-only input, and denied descriptor import |

`control_accelerator_isolation` has no Linux mechanism in section 1: the
adapter's `report_of` refuses it (`UncreditedControl`), no `Accelerator`
profile is offered, and an accelerator profile would be denied by the shared
`UnisolatedAccelerator` path. GPU work is section 2 and the
`add-genode-host`/`validate-physical-gpu-execution` changes.

Not yet mapped: the ruled mapping names no Landlock right and no
`no_new_privs`/privilege-drop step. LH-005's native half (Task 3) must state
which control a Landlock right is credited under before any Landlock
evidence counts toward this profile.
