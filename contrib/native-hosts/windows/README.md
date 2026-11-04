# Native Windows WritFS

The native canary runner mounts a real WinFsp volume containing one immutable
file, `data`. Its supervised reader must pass the shared Bend gate before that
file or its metadata can be read. A second process under the same account is
denied by the mounted view. The separate LPAC lane exercises native Windows
egress controls with public canaries.

This contribution is a bounded native bring-up profile. **Use public fixtures
only.** It is not a Windows service installer, a multi-user grant issuer, a
general desktop DLP product, or a qualified protected-data host. The policy and
state live in [`writfs/Mount.bend`](../../../writfs/Mount.bend); this directory
contains OS bindings and native probes.

## Build and run

The pinned native lane uses Windows Server 2025 x64, MSVC/Windows SDK, Node
22.23.4, and WinFsp **2.2B5 / 2.2.26286**. WinFsp is a prerelease dependency
chosen because upstream lists security fixes absent from 2.1; the release and
its exact Windows build must be qualified before product deployment.

Compile the policy on a machine with Bend 2.0.39:

```sh
bend writfs/Mount.bend -o /absolute/build/mount.mjs
```

Install the pinned WinFsp SDK and runtime, then use elevated native PowerShell.
Keep generated policy and build output outside the checkout:

```powershell
cmake -S contrib/native-hosts/windows -B C:\writ-build -A x64
cmake --build C:\writ-build --config Release
$node = (Get-Command node.exe).Source
$bridge = (Resolve-Path contrib/native-hosts/runtime/node-policy.mjs).Path
$probe = 'C:\writ-build\Release\writfs-probe.exe'
& C:\writ-build\Release\writfs-windows.exe --public-fixture `
    C:\public-canary.bin $node $bridge C:\writ-build\mount.mjs $probe mount
& C:\writ-build\Release\writfs-windows.exe --public-fixture `
    C:\public-canary.bin $node $bridge C:\writ-build\mount.mjs $probe lpac
```

The source file must be an ordinary file of at most 64 KiB, with no existing
writer or reparse point. The runner freezes it into read-only memory, records
the Bend-computed SHA-256 digest, chooses an unused drive letter, runs the fixed
reader, revokes its logical authority, and unmounts. The original public file
remains an independent copy; this command does not enroll protected data.

The `lpac` mode never falls back to the `mount` mode. Missing Windows controls,
driver failures, a failed native check, or a malformed policy reply fail the
run. The generated policy is executed by native Windows `node.exe`, not WSL or
a native machine-code Bend runtime.

## Source and authority inventory

| File | Native responsibility |
| --- | --- |
| `writfs.c` | WinFsp callbacks, immutable byte snapshot, bounded reply decoding, per-open handle ownership, native requester capture, fixture lifecycle and evidence collection |
| `policy_pipe.c` | Private anonymous pipes to generated Bend; exact executable/module paths, stripped environment, handle allowlist, serialization, timeout and poisoned-connection teardown |
| `worker.c` | Held executable identity, suspended process launch, actual token inspection, lifetime binding, job limits, fresh LPAC profile, WFP transactions/readback, owned-resource cleanup |
| `probe.c` | Native canary reads and negative probes that Bend cannot directly express; fixed-size reports to the private supervisor |
| `CMakeLists.txt` | Windows SDK/MSVC linkage and native hardening flags; generated binaries stay outside the repository |

Workers never receive the policy pipe or a general-purpose control endpoint.
The native host assigns actor slot 1 only when WinFsp's request PID and effective
token match its retained process lifetime, user SID, authenticated logon, and
selected AppContainer facts. No worker supplies a username, SID, PID, context,
grant, or replacement policy state. `ADMIT` executes the Bend facade before
observation; `OPEN` alone does not release data.

WinFsp supplies requester evidence during Create/Open. Read and close callbacks
use the binding retained in their per-open context. Cached reads and mappings
are not fresh authenticated opens. The revocation probe uses uncached I/O and
tests new opens; it does not claim to erase already observed or cached bytes.

The policy interpreter has one process, a 128 MiB V8 old-space ceiling, a
256 MiB Windows job/process commit ceiling, a 30-second process CPU budget,
and a 15-second request deadline. A timed-out, malformed, out-of-sequence or
failed exchange stops serving bytes. The worker has a separate kill-on-close
job, one-process limit and 64 MiB process memory ceiling. The fixture lifecycle
also has bounded phase waits. Limits are fail-closed, not performance claims.

The LPAC launch grants no capability SIDs. It inspects the real token before
admission, uses explicit inherited test handles, restricts children and Win32k,
and installs/read-backs four package-scoped WFP blocks for IPv4/IPv6 connect
and receive/accept. A separate phase removes the dynamic filters and checks
the LPAC's independent network denial while it still holds the canary.

## Evidence and remaining product work

The [native Windows workflow](../../../.github/workflows/writfs-windows-native.yml)
records the source commit, generated module digest, Windows/Node/driver
versions, MSVC output, requester identity facts and every observed probe result.
Its mount lane and LPAC lane are distinct results. A successful build alone is
not either result.

The current launch uses the broker account's user SID with an LPAC token and an
explicit worker process/thread owner and DACL. **It does not yet establish a
dedicated execution account.** The worker-to-broker probe is not a proof that an
ordinary same-user outsider cannot inspect the worker. Complete same-user
isolation, verified image enrollment, profile/registry/cache disposal, hostile
helper/device coverage, broker-crash teardown, restart recovery and durable
publication remain separate acceptance gates.

Structured local event lines report a policy result against an observed process
binding. They are bounded fixture evidence, not an administrator-resistant
journal, a complete Windows event collector, or proof of a human's intent.
Administrator/kernel compromise, arbitrary desktop applications, GPU isolation,
and hardware/covert-channel guarantees are outside this profile.

## Pinned primary sources

- [WinFsp 2.2B5 release and published security fixes](https://github.com/winfsp/winfsp/releases/tag/v2.2B5),
  [API source at `14d6e0280ae15e2550c44d6dbc476be51649727f`](https://github.com/winfsp/winfsp/blob/14d6e0280ae15e2550c44d6dbc476be51649727f/inc/winfsp/winfsp.h),
  and [upstream licensing](https://github.com/winfsp/winfsp/blob/v2.2B5/License.txt).
- [Microsoft LPAC launch guidance](https://learn.microsoft.com/en-us/windows/win32/secauthz/implementing-an-appcontainer)
  and [token information classes](https://learn.microsoft.com/en-us/windows/win32/api/winnt/ne-winnt-token_information_class).
- [Process creation attributes](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-updateprocthreadattribute),
  [Job Objects](https://learn.microsoft.com/en-us/windows/win32/procthread/job-objects),
  and [WFP object lifetime](https://learn.microsoft.com/en-us/windows/win32/fwp/object-management).

WinFsp installer SHA-256:
`293ffb9bcc0b625c85079fe85fa77f8fe98170aba51a02ac9c83d58f6c3b0e2f`.
