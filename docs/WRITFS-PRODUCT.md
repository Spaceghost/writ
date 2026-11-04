# WritFS product: native filesystems with controlled observation

An admitted analysis worker should be able to read a restricted report while an
ordinary browser opening that same object receives access denied. The record
should identify the observed process and its verified security context. Today
Writ has policy checks and private native storage staging; the mounted view and
the controls that contain the worker still need implementation.

**Product priority: Windows first, with native Linux and Genode targets sharing
one Bend authority model.** Genode remains the capability reference. This is a
proposed product design, not an implemented Windows service or a qualification
of any complete filesystem/host. The existing [native storage backend](../writfs/README.md)
has separately scoped Btrfs/ZFS evidence; it does not supply these frontends or
their confinement. Each target remains pending until its own native filesystem
and host acceptance tests pass.

The product should answer two concrete questions: may this process observe this
object under the current terms, and which authenticated execution context was
denied an operation? Ordinary file access alone cannot enforce downstream use:
once an unrestricted application receives plaintext, its other output channels
remain available. Protected reads therefore require a qualified confined domain.
An unrestricted application receives a denial or an explicitly authorized export;
an export carries no promise of continued control over its memory.

## Three native targets

| Target | Filesystem presentation | Enforcement and runtime boundary |
| --- | --- | --- |
| Windows | WinFsp filesystem backed by a dedicated broker and private object store | Verified LPAC workers, explicit object/handle permissions, WFP network policy, authenticated native actor records; Windows runtime bindings required |
| Linux | FUSE frontend backed by the same logical object contract; Btrfs/ZFS staging remains an optional storage backend | Native broker, scoped descriptors, supervised workers and a qualified namespace/seccomp/Landlock profile; a mount alone supplies no process confinement |
| Genode | Native file-system session service and VFS integration over broker-owned objects | Supervisor-controlled service routes, protection domains, dataspaces and quotas; Bend runtime/session bindings and a selected native base require qualification |

These are platform-specific presentation and enforcement adapters, not three
policy engines or a requirement to invent three disk formats. FUSE presents a
userspace filesystem through the Linux kernel; Genode capabilities identify
service objects and are delegable within the selected base implementation.
Neither mechanism establishes Writ's human subject or origin policy by itself.
[L1] [G1] See [the portable architecture](PLATFORMS.md),
[host profiles](HOST-PLATFORMS.md), and [Genode integration](GENODE.md).

## Windows architecture and first bounded slice

Choose **WinFsp + a dedicated broker + an explicitly verified LPAC worker + WFP**.
WinFsp supplies a real Windows filesystem interface with per-open context. ProjFS
is useful for projection, but hydrated contents become a local filesystem cache,
adding another plaintext store to protect. A custom minifilter can later cover
existing NTFS trees; it adds kernel deployment, cached/paging I/O and mapping
obligations, and still does not close non-filesystem output channels. [W1] [W2] [W3]

The first qualification profile uses one immutable object of at most 64 KiB, one
active invocation, and one pinned headless worker. Bounds on requests, audit
queues, memory, work and duration are explicit profile parameters. Use public
canary data until the complete native profile qualifies. The mounted view is
read-only; general writes, arbitrary desktop applications, GPU access, writable
workspaces and public publication are outside this first slice.

1. **Register the input.** The broker owns a private store, immutable bytes,
   content digest, logical object/version and source restrictions. The original
   source path must not remain an unintended alternative read route. Store,
   registry, journals and scratch have explicit ownership and DACLs.
2. **Authenticate and prepare the invocation.** Bind the initiating subject to
   current monitor state and the exact worker image, input, operation and worker
   input domain. Create the worker suspended under a dedicated execution
   identity and an invocation-specific LPAC profile. Keep the initiating user
   distinct from the account executing the worker.
3. **Close the environment before observation.** Verify the actual token and
   minimal capability set, inherited-handle allowlist, process/object DACLs,
   child-process restrictions, job membership and resource limits. Grant no
   network capabilities or loopback exemptions, public console, desktop,
   clipboard, device or general COM helper. Install and verify the required WFP
   rules and audit subscriptions. Any missing control denies setup without input.
4. **Authorize the observation through Bend.** Model release into the registered
   confined worker input domain as an exact immutable Copy with preserved origin
   policy. The reviewed host binding must use the full
   `DataOS.commit_from_capability` path before that view becomes readable. Its
   destination is that worker domain, not a caller-selected path or process.
   Retain the returned model state even if subsequent native setup fails.
   **Serve only the admitted worker.** At WinFsp open, obtain native requester
   evidence and compare it to the retained launch/lifetime binding and current
   registry. Ordinary processes, stale sessions and mismatched versions receive
   access denied before contents are returned. Bind admitted per-open context to
   the immutable object and invocation; unsupported operations fail closed.
   Enumeration, names, sizes and errors are outputs subject to an approved audience too.
5. **Contain and record attempts.** The worker can read the registered bytes but
   cannot publish arbitrary output. Exercise adversarial output attempts and
   collect structured denials. Retire the worker, mappings and private scratch
   before reusing resources. A later transform/publication feature needs its own
   sealed artifact and current, durable commit path.

`Frontend.open` creates a protocol descriptor, and `Frontend.checked_plan`
resolves a scoped proposal. **Neither is plaintext permission.** This design
does not add a successful-open shortcut around the existing authority path.
Public Bend `Context`, `Gate` or intent records are descriptions, not credentials;
only the serialized trusted monitor constructs their authoritative inputs.

LPAC requires explicit access to some resources ordinary AppContainers receive.
Runtime incompatibility must not trigger an ordinary-AppContainer or unrestricted
fallback. Job Objects control process lifetime and resources, while token and
object security still govern access. [W4] [W5] [W13] A dedicated execution identity and
explicit ownership also avoid assuming default same-user process/file ACLs
protect worker data: object owners normally have authority to change DACLs. [W6]

## Native actor identity and what the evidence means

The broker records the initiating user SID and authenticated logon identifier,
worker execution SID and token facts, AppContainer SID, retained process handle,
PID and creation time, image identity, monitor incarnation, invocation, handle
generation and current policy revision. Record the effective request security
context where available, separately from the process's primary identity; do not
invent it when a binding cannot establish it. Native handles remain local and
are never portable bearer credentials. [W7] [W14]

WinFsp's requester PID helper is valid only during Create, Open and certain
Rename requests. Capture identity at open and join it to a retained process
lifetime; cached reads and mappings cannot be relabeled as fresh independently
authenticated observations. A reused PID or a shared package SID alone cannot
identify the invocation. The selected bridge must preserve kernel-derived
requester information instead of trusting a username/PID in a request body. [W1]

An unchanged rclone remote behind `cmount` is insufficient for this product
boundary: the inspected rclone path does not propagate cgofuse requester context
into remote calls. WinFsp's FUSE implementation also lacks valid requester PID
context for ordinary Read/Write callbacks. A mount demonstration and an
actor-aware filesystem therefore need separate evidence. [W8]

For control IPC, use explicit local pipe security, reject remote clients, protect
the server endpoint, and bind the inspected peer to the launch record. If
impersonation is used, failure or an insufficient level denies the request;
restore the broker's identity before unrelated work. [W9]

Distinguish **Bend policy denials** on a particular authenticated object request
from **Windows enforcement events**. WFP event headers can identify application,
user, package and endpoints when those fields are present. Security event 5157
includes the blocked connection's process/application/filter information; 4688
distinguishes process creator and target security contexts. Correlate them with
recorded lifetimes, retaining uncertainty and collection gaps rather than
attributing an event to a newly reused PID. [W10] [W15] [W16]

A truthful report says that a process under a recorded security context was
denied a specific action. It does not establish a person's intent, knowledge or
malice. Unknown intent is not permission. Signed binaries and authenticated
accounts do not establish that a human requested a transfer; any required
approval must bind its exact plan and destination independently.

Audit records are protected outputs too. Use bounded structured identifiers and
reason codes, not raw worker errors, payloads or attacker-controlled filenames
in a public log. Protect the journal against workers and ordinary users, retain
sequence/incarnation and collection-health evidence, and stop new admission on
required-audit failure. Overload must produce a visible gap and retire affected
work, not a claim of complete capture. Local hash chaining alone does not make
logs trustworthy against an administrator controlling the host.

## Network, read handles and failure boundaries

Use WFP's built-in filtering through a user-mode management binding; a custom
network callout driver is unnecessary for the initial deny-network profile.
Rules cover IPv4/IPv6 and applicable connect/receive layers, scoped by the
verified application, user and AppContainer identity. WFP does not infer which
source bytes a connection would contain. Test indirect helpers, loopback and
name-resolution paths as well as direct sockets. [W11]

Dynamic WFP objects disappear when their owning session ends. Broker crash must
not create an egress window: the no-network worker profile remains independently
effective, and filter lifetime, worker teardown and any persistent rules require
explicit crash tests. [W12]

Revocation denies new admission and uncommitted release, invalidates bindings,
and retires affected workers. It cannot erase plaintext already observed or
recall every duplicate/mapping by closing one handle. Prevent unauthorized
handle transfer and memory inspection, and keep confinement effective for the
whole lifetime of retained data. AppContainer storage, registry, caches, dumps
and diagnostics need the same treatment as files. [W1] [W4]

The initial threat model excludes hostile administrators, compromised kernels
or trusted drivers, and unmeasured hardware/covert channels. Windows, WinFsp,
the selected runtime and all enabled native bindings belong to the trusted base.
The first slice claims neither general desktop DLP nor durable public
publication. Process/OS attribution is evidence of an observed action, not proof
of a payload leak or of the human behind it.

## Runtime and native binding work

The pinned Bend 2.0.39 runtime is not already a Windows host. Its inspected TCP
JavaScript effects use Bun FFI and POSIX APIs; some file-read effects do too.
Base has no ready-made HANDLE/token/WFP binding or stdin-read effect. Native C
runtime dependencies also require a Windows port. Do not run the existing TCP
service unchanged on Windows and describe it as portable. [B1] [B2] [B3]

Two distinct routes remain open:

| Route | Meaning and required work |
| --- | --- |
| Compiled Bend `.mjs` on native Windows | Generate the policy/state module from Bend and invoke it through a pinned Windows JavaScript runtime and reviewed host binding. This is Windows OS execution of generated JavaScript, not Bend native machine-code support. Validate the actual runtime under LPAC and replace unsupported effects explicitly. |
| Native machine-code Bend port | Port the generated backend/runtime's allocation, threads, synchronization, clocks, entropy and I/O to Windows, then bind WinFsp/Win32/WFP and run the same corpus. Compilation alone still does not qualify confinement. |

The first route is the smaller bring-up candidate. The existing core and native
storage model have already passed 638 and 78 checks respectively as generated
JavaScript under native Windows Server 2025 Node; see the
[execution record](../writfs/VERIFICATION.md#windows-policy-execution).
Those tests exercise policy, not filesystem or confinement bindings.
The product still needs a real
Windows host: an asserted setup record, a WSL process or a JSON conversation
cannot substitute for native observations and enforced controls.

| Binding family | Native responsibilities; policy remains Bend |
| --- | --- |
| Filesystem | WinFsp create/start/stop and Create/Open/Read/Close callbacks; security descriptors, immutable buffers, native requester capture and per-open context |
| Launch and confinement | AppContainer profile lifecycle; `CreateProcessAsUserW`/creation attributes for security capabilities, LPAC, handles, child policy and job assignment; inspect the resulting token; job limits and teardown |
| Identity and IPC | `GetTokenInformation`, retained process handles, `GetProcessTimes`, image verification; explicit named-pipe DACLs, local endpoint/peer checks, checked impersonation and reversion |
| Network and native audit | WFP engine transactions, filter installation/verification and event subscription; Windows event subscription, missing-field handling and lifetime correlation |
| Storage and host lifetime | Protected file/registry/profile ownership, immutable input snapshots, bounded journal writes, flush/error reporting, clock/entropy, cancellation and service shutdown |
| Generated-module invocation | Bounded canonical values, exact integer widths, serialized state application and safe callback/concurrency ownership; no caller-supplied authoritative context |

These API families are backed by the Windows/WinFsp references below; their Writ
composition is proposed and unimplemented. The binding must return facts and
errors, perform only accepted effects, and expose no general shell, arbitrary
native call or alternate release endpoint. [W1] [W5] [W7] [W9] [W11]

### Approved native source boundary

The user approved the native binding exception in [AGENTS.md](../AGENTS.md).
The existing `contrib/rclone/go/` exception remains limited to its rclone
interface/transport contribution.

The additional `contrib/native-hosts/` tree is limited to the following
mechanical native boundaries:

| Path | Permitted binding work |
| --- | --- |
| `windows/` | C/C++ WinFsp/Win32/WFP ABI bindings, generated Bend module invocation, and a small JavaScript I/O harness if the initial Windows runtime requires it |
| `linux/` | C libfuse connection, callback, buffer and descriptor-lifetime bindings |
| `genode/` | C++ filesystem session/packet-stream bindings, native resource and supervisor connections |
| `runtime/` | Minimal pinned Bend runtime ports for OS memory, stack guards, threading and effects; no policy changes |

Packaging and native negative-test probes that Bend cannot yet express belong
to the relevant host's inventory. Dependencies and the actual API/file surface
must remain pinned and reviewed. No new root Go module, policy engine, grants,
label decisions, accounting, replay rules or release decisions may move into
these packages. Policy and state machines stay authored in Bend; generated
outputs stay build artifacts.

Each binding requires its own source inventory and actual native acceptance.
Approval to write a binding is not host qualification. The shared mounted-view
state machine and authority path stay in Bend; the bindings own native resources
and translate observed facts and admitted effects.

Genode needs a substantive runtime adaptation: the pinned Bend CPU runtime
reserves a 2 GiB guarded stack and an initial 8 GiB sparse heap. Genode 26.08
libc's `mprotect` returns failure, while anonymous `mmap` allocates RAM-backed
storage and does not implement the required adjacent growth contract. A
single-thread setting does not remove these assumptions. Port guards and bounded
allocation through actual Genode region maps/dataspaces; do not disable the
guard or claim a linked binary is a running monitor. Sources: the
[Bend runtime](https://github.com/bendlang/bend/blob/v2.0.39/bend2/comp.ts),
[Genode libc dummy operations](https://codeberg.org/genodelabs/genode/src/commit/d18ee9e917200b059549e21f2dd9a55bfe61a0eb/repos/libports/src/lib/libc/dummies.cc),
and [memory mapping](https://codeberg.org/genodelabs/genode/src/commit/d18ee9e917200b059549e21f2dd9a55bfe61a0eb/repos/libports/src/lib/libc/file_operations.cc).

## Native acceptance before a product claim

Run common Bend vectors, then these tests against the actual mounted frontend,
broker, worker and Windows build. A mock native observation cannot satisfy them.

| Scenario | Required observed result |
| --- | --- |
| Authorized read | The admitted worker reads exactly the registered immutable bytes; the current intent and origin terms remain associated with its input domain. |
| Ordinary application or alternate storage path | No protected bytes are returned; the record identifies the verified actor/lifetime or explicitly records missing evidence. |
| Namespace aliases and metadata | Reparse points, links, alternate streams, path/case aliases and network-share paths cannot substitute another object or bypass admission; unsupported features are denied. Names and metadata respect their audience. |
| Direct and indirect egress | IPv4/IPv6 TCP/UDP, relevant loopback/DNS, public files, console, clipboard, named objects, COM helpers and devices cannot deliver the canary to an unapproved receiver. Pair native denials with receiver-side absence checks. |
| Same-user attack and handle transfer | Another process cannot inspect worker memory, duplicate useful handles, change ownership/DACLs to gain access, or read profile/scratch state. |
| False attribution | PID reuse, a shared package identity, substituted image, impersonation mismatch, forged subject and stale incarnation cannot inherit an invocation; no event is assigned to an ambiguous actor. |
| Revocation and cached observation | New opens and uncommitted releases fail; existing handles/mappings remain contained until worker retirement, without claiming erased memory. |
| Setup, broker or audit failure | No input arrives before all controls exist; broker death or dynamic-filter loss creates no output window; missing required audit and overload stop admission and expose collection gaps. |
| Restart and state reuse | Old descriptors and invocations remain invalid; scratch, registry and caches cannot leak to a later invocation; uncertain effects are not blindly retried. |

Record OS build, architecture, filesystem driver, runtime and binding versions,
launch/token/DACL/filter configuration, source hashes and actual denial evidence.
Repeat the analogous filesystem and confinement tests independently on Linux
and native Genode. WSL is Linux evidence; Genode-on-Linux does not qualify a
native Genode base. Existing native storage tests do not complete these gates.
Future durable publication must satisfy its separate crash/replay contract.

## Primary references

Research inspected 2026-11-04. Links establish platform mechanisms; the Writ
profile, source exception and acceptance plan above remain proposed decisions.

[W1]: https://winfsp.dev/doc/WinFsp-API-winfsp.h/
[W2]: https://learn.microsoft.com/en-us/windows/win32/projfs/cache-state
[W3]: https://learn.microsoft.com/en-us/windows-hardware/drivers/ifs/registering-preoperation-and-postoperation-callback-routines
[W4]: https://learn.microsoft.com/en-us/windows/win32/secauthz/implementing-an-appcontainer
[W5]: https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-updateprocthreadattribute
[W6]: https://learn.microsoft.com/en-us/windows/win32/secauthz/owner-of-a-new-object
[W7]: https://learn.microsoft.com/en-us/windows/win32/api/winnt/ns-winnt-token_statistics
[W8]: https://github.com/winfsp/winfsp/blob/v2.1/src/dll/fuse/fuse_intf.c
[W9]: https://learn.microsoft.com/en-us/windows/win32/ipc/impersonating-a-named-pipe-client
[W10]: https://learn.microsoft.com/en-us/windows/win32/api/fwpmtypes/ns-fwpmtypes-fwpm_net_event_header2
[W11]: https://learn.microsoft.com/en-us/windows-hardware/drivers/network/callout-driver-programming-considerations
[W12]: https://learn.microsoft.com/en-us/windows/win32/fwp/object-management
[W13]: https://learn.microsoft.com/en-us/windows/win32/procthread/job-objects
[W14]: https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-getprocesstimes
[W15]: https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-10/security/threat-protection/auditing/event-5157
[W16]: https://learn.microsoft.com/windows/security/threat-protection/auditing/event-4688
[B1]: https://github.com/bendlang/bend/blob/v2.0.39/README.md
[B2]: https://github.com/bendlang/bend/blob/v2.0.39/bend2/comp.ts
[B3]: https://github.com/bendlang/bend/blob/v2.0.39/bend2/effs/file_read.js
[L1]: https://docs.kernel.org/filesystems/fuse/fuse.html
[G1]: https://genode.org/documentation/genode-foundations/26.05/architecture/Capability-based_security.html

Additional precise API/evidence references:

- [Job Objects and process-tree limits](https://learn.microsoft.com/en-us/windows/win32/procthread/job-objects),
  [process security](https://learn.microsoft.com/en-us/windows/win32/procthread/process-security-and-access-rights),
  and [process creation time](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-getprocesstimes).
- [WFP identity conditions](https://learn.microsoft.com/en-us/windows-hardware/drivers/network/filtering-condition-identifiers),
  [ALE layers](https://learn.microsoft.com/en-us/windows/win32/fwp/ale-layers),
  [5157 connection denials](https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-10/security/threat-protection/auditing/event-5157),
  and [4688 process creation](https://learn.microsoft.com/windows/security/threat-protection/auditing/event-4688).
- [Named-pipe security](https://learn.microsoft.com/en-us/windows/win32/ipc/named-pipe-security-and-access-rights)
  and [native pipe client process ID](https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-getnamedpipeclientprocessid).
- [rclone v1.75.2 cmount callbacks](https://github.com/rclone/rclone/blob/v1.75.2/cmd/cmount/fs.go)
  and [WinFsp FUSE context implementation](https://github.com/winfsp/winfsp/blob/v2.1/src/dll/fuse/fuse_intf.c).
