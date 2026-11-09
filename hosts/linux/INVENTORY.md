# Linux host trust inventory (add-linux-host)

Status: this tree contains a model-tested Bend adapter for the direct Linux
target. It does not include a protected-worker native broker or launcher.
Partial WIP sources exist only on the separate `lane/linux-host` branch and
are not qualified. The [plan](../../docs/superpowers/plans/2026-11-05-linux-host.md)
still requires native identity, confinement and failure evidence. Protected
execution is unavailable for this profile (LH-001). Existing native
WritFS public-canary evidence covers a separate, bounded contribution; it
does not qualify this adapter.

This file lists Linux host binding code. None of it is Writ policy: no
authority, grant, label, budget, accounting, replay, or release decision is
made here. The adapter also retains broker-framed launch credentials and rejects
a Barrier whose session, incarnation or retained credential does not match.
Shared transitions in `HostIdentity.bend`, `HostPrimitives.bend`, and
`HostPublication.bend` still decide authority and effects.

## Files

| File | Role | Run by |
| --- | --- | --- |
| `hosts/linux/monitor/LinuxHost.bend` | Adapter glue: the Linux host id and incarnation, the profile table (`linux-worker-v1`), the translators from broker-framed native facts (`LinuxFact`) to `SessionEvidence`, `TargetReport`, and `Inventory`, and the two-channel `dispatch` that applies at most one shared transition per framed input. Retains per-session launch observations and checks them at Barrier. The trusted in-process `revoke` monitor action retains those observations while routing `HostPublication.revoke`'s result and `StopEffects` unchanged; it adds no portable `Error` or law. | imported by the test module; the native broker (Tasks 2 to 4) will run it as the generated Bend monitor |
| `hosts/linux/monitor/LinuxHostTests.bend` | Model tests on SYNTHETIC broker facts, and the replay of the 37 portable-host conformance vectors through a Linux adapter fixture | `Tests.bend` as `LinuxHost` |
| `hosts/linux/monitor/LinuxSessionOpenTests.bend` | Synthetic typed-open, denial, routing and legacy wire compatibility checks | `Tests.bend` as `LinuxSessionOpen` |
| `hosts/linux/monitor/LinuxCredentialBindingTests.bend` | Synthetic binding, restart, monitor-action revocation, denial and long-list controls | `Tests.bend` as `LinuxCredentialBinding` |
| `hosts/linux/monitor/LinuxClockTests.bend` | Synthetic trusted-sample watermark, poison, cleanup and guarded-branch checks | `Tests.bend` as `LinuxClock` |

No C, JavaScript, or other native file is in `hosts/linux/`. This tree does
not include the separate branch’s unfinished protected-worker broker or
launcher. The existing `contrib/native-hosts/linux/` sources implement the
distinct public WritFS canary and have their own native inventory and evidence.

The shared `open_session_result` exposes the session returned by the same
identity transition. Linux Launch returns that value in memory as `Opened`;
`LINUXMON1` retains its prior ordinary diagnostic replies, without a session
receipt, and adds `CLOCKFAULT` / `CLOCK` when the clock is poisoned.
Neither the value nor its publicly constructible representation authenticates a
caller or supplies correlation, replay protection or native host qualification.
Existing numeric terminal bounds remain an open concern.

`LinuxHost.revoke` is a trusted in-process monitor action, not a worker or
broker-frame command. The owning monitor must authenticate and authorize the
decision separately; a slot number is only a selector. The caller retains the
returned state before performing its exact `StopEffects`. The action does not
connect `Issuance.revoke` to an identity slot, establish a native revocation
channel, stop a Linux process itself, or prove that FUSE or protected delivery
uses this model. The existing legacy canary path is unchanged.

The model's `dispatch` and `serve` now take a supervisor-supplied `ClockSample`
instead of a bare natural number. The clock high-water is separate from
portable policy and credential state; it advances even when the request is
denied or malformed. A missing, ambiguous, owner-reported overflow or regressing sample
poisons new protected actions. Trusted `revoke` and `restart` still return the
shared cleanup steps while preserving poison. `without_credentials` imports
an unknown clock as poisoned. Equal samples are accepted, so the model cannot
detect a stale, frozen, replayed or slow but nonregressing clock.

The owner must actually sample a trusted clock, protect the sample channel,
retain state before effects and preserve continuity across restart. Public Bend
records and helpers cannot authenticate those facts or prevent an old state
being restored. This is an in-memory consistency check, not the local authority
owner, issuer/FUSE gate, native clock, durability or host qualification. The
off-master WIP broker harness passed a request sequence as its old bare `now`;
it is incompatible with this typed input and must not be treated as a clock.

## Authority

The intended native broker supplies facts as inputs; the Bend monitor holds
authority. A qualified broker must be the trusted supervisor of the
docs/PLATFORMS.md topology: it must report observations and execute only the
effects of an `Admitted` step the monitor returned, after the monitor has
retained the advanced state
(contrib/native-hosts/PROTOCOL.md). **None of the facts below is an authority
fact**: none is a grant, label, budget, plan, rights mask, profile, or release
decision. The launch credential is retained only for an accepted Launch, next
to the exact issued session and incarnation; it does not authenticate that
frame. Other facts reach shared transitions or are compared and discarded. A uid,
gid, pid, start time, or descriptor number is a local fact, never a portable
credential.

### Facts a target broker must report

| Fact | Native source | Frame field | Contract destination | Why it is not authority |
| --- | --- | --- | --- | --- |
| Launch subject | trusted launch record | `LinuxFact.subject` | `SessionEvidence.caller` (with the token), consumed by `open_session`; compared with the session's caller at a Barrier | names who the launch record was issued for; the session id, delegability, and role are the monitor's |
| Launch code token | trusted launch record | `LinuxFact.token` | as the subject | identifies code, grants nothing |
| Launch record's monitor incarnation | trusted launch record | `LinuxFact.incarnation` | compared only (StaleLaunch) | a freshness check |
| Expected process credential (uid, gid, pid, start time) | trusted launch record | `LinuxFact.launch` | compared to peer, retained on accepted Launch and compared at Barrier | local fact, not proof of authentication |
| Connected peer credential (uid, gid, pid, start time) | `SO_PEERCRED`, pidfd, `/proc/PID/stat` | `LinuxFact.peer` | compared only (PeerMismatch) | connection-time local fact; a socketpair endpoint does not relabel its holder |
| How the endpoint arrived | broker launch bookkeeping | `LinuxFact.endpoint` | `SessionEvidence.origin` at Launch; ignored at a Barrier | HostIdentity decides what an inherited or transferred origin may do |
| Contract families the binding implements | broker build | `LinuxFact.families` | `TargetReport.supported_families`, compared with the bound profile | can only fall short of the profile, never widen it |
| Established controls | kernel state the broker installed and probed | `LinuxFact.controls` | `TargetReport.established_controls`, compared with the bound profile | as families; bits the broker cannot credit are refused (UncreditedControl) |
| Descriptor inventory (number, kind, mediated) | the worker's fd table after the allowlist | `LinuxFact.routes` | `Inventory` of `RouteFact{kind, mediated}`; numbers dropped | an unmediated route can only deny |
| Barrier session | the broker's attribution of the barrier to a session | `Barrier.session` | the session `admit_worker` resolves on; checked against the fact's caller (SessionMismatch) and the same session's unique retained credential (LaunchMismatch) | the entry, profile, and delegability are the identity table's |
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
   attribution; the monitor also checks the retained launch credential, but
   cannot authenticate that either observation is true.
3. Obtain truthful current peer and process-lifetime facts, bind them to the
   exact issued session and endpoint, fix the endpoint at Launch, and report
   the barrier credential from that binding. A successful modeled restart
   clears credential records and returns the shared stop effects for execution;
   a denied restart retains the original records. Do not restore arbitrary
   primitive state as authenticated sessions.
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
broker's transport identified. A worker frame cannot carry a fact, and its claimed
subject is never read.

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
