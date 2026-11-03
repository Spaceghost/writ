# Writ on Linux and Windows

**Design status: proposed adapters, not working host sandboxes.** Writ's tested
Bend library supplies the decisions. These targets must supply authenticated
sessions, worker isolation, protected state, and publication that obey those
decisions. [Genode](GENODE.md) is the reference capability architecture; the
[portable contract](../openspec/changes/add-portable-host-contract/proposal.md)
defines the semantics every host must preserve. The [platform overview](PLATFORMS.md)
places these adapters alongside Genode and the later Drift-backed kernel.

| Target | Native enforcement boundary | What its first release must demonstrate |
| --- | --- | --- |
| Direct Linux | Trusted broker and launcher, kernel isolation, restricted worker processes | A protected worker can reach only its admitted input/output interfaces |
| Native Windows | Trusted broker and launcher, AppContainer/LPAC workers, explicit object permissions | The same decisions hold through Windows tokens, handles, IPC, and process lifetime |
| Genode on Linux | Genode's component/session model on its Linux base | The Genode profile's guarantees, with Linux included in its trusted base; see [GENODE.md](GENODE.md) |
| WSL development | Linux environment hosted by Windows | Linux-target build/test evidence only; it does not qualify the native Windows adapter |

## One Bend core, distinct operating-system boundaries

Policy evaluation, verification, provenance, negotiation, accounting, and final
commit stay in Bend 2. Neither platform gets a second policy engine. A host adapter
resolves its local object references into monitor-owned records, calls the same
facade, and carries out only the accepted intent. Raw file descriptor or `HANDLE`
numbers never become portable credentials.

Linux `CAP_*` privileges divide traditional superuser authority; they are not
Genode-style references to particular service objects. Windows access tokens and
AppContainer capability SIDs likewise supply host access checks, not Writ's
origin policies or decentralized labels. These mechanisms protect the broker and
workers while Writ retains the information-flow contract. [L1], [W1]

There are three separate milestones: execute the Bend model, bind the runtime to
the host, and validate real confinement. The pinned
[Bend 2.0.39 release](https://github.com/bendlang/bend/releases/tag/v2.0.39) supplies
Linux/macOS distributions; its installer directs Windows users to WSL. The
recorded Writ Linux run does not exercise a sandbox. A native Windows runtime/ABI
binding is therefore explicit bring-up work. One possible bootstrap is compiler-
generated Bend JavaScript in a pinned Windows JS runtime; a Windows native-code
Bend backend is a separate option. Neither has been validated here. Such model
execution would not prove native worker isolation. Authored policy is not to be
replaced with C, C++, or Rust during that bring-up.

## Linux: construct a closed worker environment

The proposed first profile is a headless worker with brokered inputs and outputs.
The broker remains outside the worker's namespace and security domain. Its private
state, keys, object storage, and output transport are unavailable to the worker.
The launcher finishes confinement before admitting protected plaintext.

| Layer | Purpose in Writ's proposed Linux profile |
| --- | --- |
| Credentials and namespaces | Remove unnecessary privilege and isolate the process, mount, network, and IPC views; use user namespaces only where the selected launch profile supports them |
| `no_new_privs` | Prevent an `execve` from adding privilege through executable metadata |
| Seccomp | Permit only the runtime's measured syscall/architecture set; deny unsupported process creation, tracing, namespace changes, descriptor import, asynchronous I/O, and device interfaces |
| Landlock | Apply the profile's required filesystem/network/IPC restrictions and verify the available ABI before launch |
| Resource and lifetime controls | Bound memory, work, process count, and duration; retain trusted supervision of the complete worker tree |

These controls have different jobs. Namespaces isolate selected resource views.
Seccomp narrows the syscall surface and explicitly is not a complete sandbox.
`no_new_privs` does not stop every privilege change or descriptor transfer.
The composition and its kernel configuration require tests. [L2], [L3], [L4]

Landlock's coverage is versioned and has expanded over time, including network
and IPC controls. Writ must enumerate and probe the exact rights required by a
profile. If a required right or confinement step is unavailable, protected launch
fails. A best-effort fallback may be appropriate for other applications, but it
does not satisfy this protected-execution profile. [L5]

### Existing descriptors and IPC identity

Close all inherited descriptors except an explicit list, including standard
streams, directory descriptors, TTYs, device handles, sockets, and shared mappings.
Landlock does not retroactively impose its path restrictions on files opened
before confinement. Passing an open descriptor can retain the authority it had
when opened. [L5]

A Unix-domain control connection can supply kernel credentials, but its identity
needs careful interpretation. `SO_PEERCRED` captures credentials at connection or
socket-pair creation; a socketpair created by a parent and passed to a child does
not by itself prove that the child is now the actor. Writ binds the channel to a
trusted launch record, process lifetime, monitor incarnation, and session. FD
passing is initially denied; a future delegation path must authenticate the new
holder, preserve the exact plan and origin terms, and only narrow rights or
lifetime. A different subject or plan requires new authorization. [L6]

An integer that happens to equal an open descriptor is not an authorized Writ
operation. The broker looks up the current session/handle generation, resolves
the admitted plan, and checks the actor binding before invoking the Bend facade.
Metadata read from worker memory must be copied into a bounded broker-owned
request before validation; a later path lookup or mutable pointer cannot stand
in for the object that was approved.

### Revocation and publication

Linux duplicates refer to the same open file description. Closing one descriptor
does not make every duplicate unusable. The proposed adapter therefore keeps
revocable Writ references in the broker and rechecks live authority at release;
it does not implement revocation as a single `close`. [L7]

Workers get no final-destination descriptor. Their output remains in private
staging until the broker validates the bytes and schema, seals the artifact,
rechecks the current scope, and commits through the durable-publication contract.
Revoking authority blocks future admission and uncommitted publication. It cannot
erase plaintext already observed; confinement must continue until that worker
and its private staging state are retired.

The proposed POSIX character device is another frontend to this broker contract.
Mounting it does not confine an otherwise unrestricted process, and a Linux
filesystem path is not the cross-platform authority abstraction.

## Windows: explicit token, object, and process policy

The proposed native Windows profile is also headless. Start with an LPAC worker
where the required runtime can operate under that policy, explicit object grants,
no network capability, and no ambient desktop or device interfaces. An ordinary
AppContainer profile would be a separately named, reviewed profile if needed;
there is no silent fallback from LPAC to a less restrictive token.

AppContainer checks combine user/group and application authority. LPAC removes
some access that ordinary AppContainers receive by default. A low integrity level
alone is not equivalent to AppContainer confinement. Restricting a token's SIDs
and privileges is useful but does not by itself establish Writ's whole output
boundary. [W1], [W2], [W3]

| Layer | Purpose in Writ's proposed Windows profile |
| --- | --- |
| AppContainer/LPAC token | Constrain resource access under the declared capability set; verify the actual created process's token |
| Explicit object DACLs | Protect broker state and expose only the session's IPC and staging resources |
| Inherited-handle allowlist | Pass only intended handles; exclude console, final destination, process, token, device, and unrelated mapping handles |
| Job Object and child-process policy | Account for resources and control the worker tree; prevent breakaway and unbrokered descendant creation |
| Brokered output | Validate and seal output, then run the same live Bend commit checks |

Windows provides an explicit handle list at process creation. The launcher must
verify the resulting process token and lifecycle controls before any protected
input is delivered. A Job Object groups processes and supplies resource/lifetime
controls; security restrictions still apply to each process. Job assignment alone
does not establish an information-flow boundary. [W4], [W5]

### IPC authenticates a session, not an asserted name

For a named-pipe transport, create a specific DACL and reject unintended remote
clients. Do not use the default pipe security descriptor or broad generic rights
without inspecting what they permit. Writ validates the actual client security
context and its association with a trusted launch; claimed usernames, package
names, PIDs, and `HANDLE` numbers are not credentials. A package SID alone does
not identify the particular worker invocation. [W6]

If the selected protocol uses named-pipe impersonation to inspect the client,
failure rejects the request. The broker never continues under its more privileged
identity after failed impersonation and restores its identity before unrelated
work. The client can influence the available impersonation level, so insufficient
identity evidence is a denial, not a fallback. [W7]

Inheritance or duplication may move a handle to another process. That transfer
does not automatically authorize a different actor under Writ's subject-bound
model. The launcher constrains transfers, the broker binds sessions to known
lifetimes, and any permitted delegation requires a new explicit binding. Closing
one Windows handle does not revoke other copies or destroy already mapped views.
Fresh monitor incarnation and handle generations prevent numeric reuse from
reviving an old grant. [W4], [W8]

### Persistent state is an information channel

AppContainer profiles provide application-specific storage; that storage is not
automatically part of Writ's provenance tracking. The host must confine, label,
and retire scratch files, registry state, caches, dumps, and mappings. Reusing a
profile or worker across unrelated invocations requires accounting for every
retained input. [W2]

Only sealed outputs reach the final commit. Clipboard, console, errors, debugger
interfaces, crash reporting, network, desktop objects, and device access must be
denied or mediated according to the profile. A protected job cannot rely on a
UI restriction or token label as evidence that all those routes have been closed.

## Shared conformance, separate host evidence

Run identical versioned Bend decision vectors on every target. Match admitted
plans, denied conditions, retained origin policy, and unchanged state on failure.
The values describing OS resources are resolved locally rather than copied
between machines. A passing model vector is followed by a real host test:

| Scenario | Required observable outcome |
| --- | --- |
| Approved report-to-summary operation | Exactly the sealed internal artifact is published under the original terms |
| Descriptor/handle leak, inherited output, or an imported endpoint | Protected launch is refused or the unapproved authority is absent before input delivery |
| Revocation while work is running | No uncommitted output becomes visible; delayed completion cannot restore authority |
| Crash, restart, or identifier reuse | Old session/handle generations and consumed invocations stay invalid |
| Direct socket, public log, clipboard, shared-memory, or device attempt | No protected payload reaches an unapproved observer |

The first supported profile may reject an operation that another profile can
confine. It must explain that limitation without weakening the common policy.
No full-host noninterference or protection against a compromised host kernel is
claimed. Every kernel, runtime, launcher, broker, and enabled device driver in the
actual enforcement path belongs in the target's declared trusted base.

GPU access is an additional profile, not a free consequence of a passing CPU
test. Raw GPU handles and shared buffers are authority. Device memory, driver
access, synchronization, result sealing, and cross-worker reuse need separate
evidence. Until then the host uses its verified CPU path or refuses work that
requires a GPU; it does not quietly grant an unconfined device.

See the pending [Linux host](../openspec/changes/add-linux-host/proposal.md) and
[Windows host](../openspec/changes/add-windows-host/proposal.md) changes. No task
there is completed by this research or by the existing library tests.

## Primary references

References inspected on 2026-11-03. The operating-system behavior above is sourced;
the Writ profiles and launch/commit protocol are proposed design decisions.

[L1]: https://man7.org/linux/man-pages/man7/capabilities.7.html
[L2]: https://man7.org/linux/man-pages/man7/namespaces.7.html
[L3]: https://docs.kernel.org/userspace-api/seccomp_filter.html
[L4]: https://docs.kernel.org/userspace-api/no_new_privs.html
[L5]: https://docs.kernel.org/userspace-api/landlock.html
[L6]: https://man7.org/linux/man-pages/man7/unix.7.html
[L7]: https://man7.org/linux/man-pages/man2/dup.2.html
[W1]: https://learn.microsoft.com/en-us/windows/win32/secauthz/implementing-an-appcontainer
[W2]: https://learn.microsoft.com/en-us/windows/win32/secauthz/appcontainer-for-legacy-applications-
[W3]: https://learn.microsoft.com/en-us/windows/win32/api/securitybaseapi/nf-securitybaseapi-createrestrictedtoken
[W4]: https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-updateprocthreadattribute
[W5]: https://learn.microsoft.com/en-us/windows/win32/procthread/job-objects
[W6]: https://learn.microsoft.com/en-us/windows/win32/ipc/named-pipe-security-and-access-rights
[W7]: https://learn.microsoft.com/en-us/windows/win32/api/namedpipeapi/nf-namedpipeapi-impersonatenamedpipeclient
[W8]: https://learn.microsoft.com/en-us/windows/win32/api/handleapi/nf-handleapi-closehandle
