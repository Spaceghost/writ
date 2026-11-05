# Linux host trust inventory (add-linux-host)

Status: started in the linux-host lane, Task 1 (2026-11-05). The Bend
adapter for the direct Linux target exists and is model-tested; no native
broker, launcher, or confinement exists yet (Tasks 2 to 4 of
[the plan](../../docs/superpowers/plans/2026-11-05-linux-host.md), under
`contrib/native-hosts/linux/`). Until those tasks supply executed evidence,
the Linux host is **model-only**: protected execution is unavailable (LH-001
"Model execution without a launcher"). A green `bend Tests.bend` on Linux is
library evidence, not host qualification.

This file lists Linux host binding code. None of it is Writ policy: no
authority, grant, label, budget, accounting, replay, or release decision is
made here. Every decision is a shared transition in `HostIdentity.bend`,
`HostPrimitives.bend`, or `HostPublication.bend`.

## Files

| File | Role | Run by |
| --- | --- | --- |
| `hosts/linux/monitor/LinuxHost.bend` | Adapter glue: the Linux host id and incarnation, the profile table (`linux-worker-v1`), the translators from broker-framed native facts (`LinuxFact`) to `SessionEvidence`, `TargetReport`, and `Inventory`, and the two-channel `dispatch` that applies at most one shared transition per framed input. Adds no transition, no `Error`, and no law. | imported by the test module; the native broker (Tasks 2 to 4) will run it as the generated Bend monitor |
| `hosts/linux/monitor/LinuxHostTests.bend` | Model tests on SYNTHETIC broker facts, and the replay of the 37 portable-host conformance vectors through a Linux adapter fixture | `Tests.bend` as `LinuxHost` |

No C, JavaScript, or other native file is in `hosts/linux/`. The native
broker and launcher belong under `contrib/native-hosts/linux/` (AGENTS.md,
the native-hosts exception) and will be inventoried there.

## Authority

The native broker's facts are inputs; the Bend monitor holds the authority.
The broker is the trusted supervisor of the docs/PLATFORMS.md topology: it
reports observations (the launch record's subject, token, and monitor
incarnation; the launch record's expected process credential and the
`SO_PEERCRED`/pidfd credential of the connected peer; how the endpoint
arrived; the contract families it implements; the controls it established;
the worker's complete descriptor inventory) and executes only the effects of
an `Admitted` step the monitor returned, after the monitor has retained the
advanced state (contrib/native-hosts/PROTOCOL.md). A uid, pid, start time,
or descriptor number is a local fact, never a portable credential: the peer
credential is only compared with the launch record's, the caller comes from
the launch record, and descriptor numbers are dropped before the contract
sees a route.

The worker channel carries only HostWire bytes on the session the broker's
transport identified. A worker frame cannot carry a fact, and its claimed
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
