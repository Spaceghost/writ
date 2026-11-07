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
$node = @(Get-Command node.exe -CommandType Application)[0].Source
$bridge = (Resolve-Path contrib/native-hosts/runtime/node-policy.mjs).Path
$probe = 'C:\writ-build\Release\writfs-probe.exe'
& C:\writ-build\Release\writfs-windows.exe --public-fixture `
    C:\public-canary.bin $node $bridge C:\writ-build\mount.mjs $probe mount
& C:\writ-build\Release\writfs-windows.exe --public-fixture `
    C:\public-canary.bin $node $bridge C:\writ-build\mount.mjs $probe lpac
& C:\writ-build\Release\writfs-transport-probe.exe `
    $node $bridge C:\writ-build\mount.mjs
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
| `worker.c` | Held executable identity, reduced primary/LPAC token launch, actual-token checks, lifetime binding, job limits, WFP transactions/readback, a separate no-data diagnostic profile and owned-resource cleanup |
| `isolation.c` | Explicit broker/child process ownership and DACLs; a same-SID, medium-integrity outsider probe with administrator group disabled and privileges removed |
| `probe.c` | Native canary reads and negative probes that Bend cannot directly express; fixed-size reports to the private supervisor |
| `channels.c` | Fixed clipboard-open and local COM activation probes, with stage-specific results and ordinary-process positive controls |
| `transport_probe.c` | Actual native pipe lifecycle, 64 KiB transfer and hostile-peer checks, including both read and write deadlines |
| `init_diagnostic.c`, `init_worker.c`, `init_child.c`, `init_report.h` | Experimental no-data supervisor, output-prefixed shared launcher, fixed child and bounded initialization report; no mount, Writ session, policy pipe or byte-input route |
| `init_report_test.c` | Synthetic report framing and positive-control checks; no native confinement claim |
| `init-diagnostic/CMakeLists.txt` | Separate optional MSVC/Windows SDK diagnostic build, without WinFsp; generated binaries stay outside the checkout |
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
and receive/accept. A separate phase removes the dynamic filters and tests
whether the LPAC independently denies network access while it holds the canary.

LPAC inspection checks the actual AppContainer/package token, zero capabilities,
low integrity and no elevation. Native `AccessCheck` must allow unchanged
descriptors granting the exact package and ALL RESTRICTED APPLICATION PACKAGES,
and deny descriptors granting only ALL APPLICATION PACKAGES or the user SID.
The host does not simulate an LPAC by editing a descriptor, and it does not
depend on the availability of token-information class 46. Job membership,
limits and child/Win32k mitigations are read back before admission.

WinFsp's default virtual-disk descriptor does not grant AppContainer traversal.
The host opens only the newly created instance's OS-returned volume device and
sets an Administrators/SYSTEM-owned descriptor granting its exact user/package
read and execute rights. Owner, group, protected DACL and every ACE are read back;
the actual LPAC token must pass a native access check. No global driver or device
class setting changes. This permits requests to reach the filesystem callbacks;
the shared Bend gate still decides whether any file bytes or metadata are served.

A separate fixed diagnostic has the same package identity, a separate retained
process/job and **only `registryRead`** as an additional capability. Win32k is
enabled there so it can reach the clipboard/COM APIs, while child and job UI
restrictions remain installed and read back. It receives one report pipe and
four public receiver ports, with no input bytes, mount name, filesystem handle,
policy pipe or logical admission. It never replaces the admitted worker in the
actor mapping. Its API results are reported separately from the zero-capability,
Win32k-disabled byte worker. Generic loader or initialization failures in that
byte worker remain incomplete direct channel evidence.

The four network destinations are real local IPv4/IPv6 TCP/UDP receivers with
successful send/receive positive controls. They are loopback evidence, not
an external-route qualification. Clipboard and COM probes also require positive
controls; a missing DLL/export, unregistered COM class, unrelated error or
arbitrary process-launch failure does not count as a restriction.

## Evidence and remaining product work

The [native Windows workflow](../../../.github/workflows/writfs-windows-native.yml)
records the source commit, generated module digest, Windows/Node/driver
versions, MSVC output, requester identity facts and every observed probe result.
Its mount lane and LPAC lane are distinct results. A successful build alone is
not either result.

See [the native verification record](VERIFICATION.md) for exact source commits,
passing checks, retained failures and current qualification gaps. The strict
LPAC command currently returns nonzero: mounted I/O and revocation pass, and
the separate no-data diagnostics pass, while direct byte-worker channel
initialization results remain incomplete and receive no confinement credit.

The current launch uses the broker account's user SID with an LPAC token.
Broker, policy child and worker process objects have explicit Administrators/SYSTEM
ownership and DACLs before observation. The separate ordinary outsider probe
retains the same user SID, medium integrity, no AppContainer, no restricting SID
list, administrator membership disabled, and no privilege beyond traversal. It
first verifies the four process-access APIs against itself, then requires native
access denial for `VM_READ`, `DUP_HANDLE`, `WRITE_DAC` and `WRITE_OWNER` against
each live broker, policy and worker lifetime. The workflow records the outcome;
source presence alone is not passing evidence.

**This does not establish a dedicated execution account or complete same-user
isolation.** Thread objects, all auxiliary runtime objects, verified image
enrollment, profile/registry/cache disposal, hostile helper/device coverage,
broker-crash teardown, restart recovery and durable publication remain separate
acceptance gates. The test account's administrator token is trusted.

Structured local event lines report a policy result against an observed process
binding. They are bounded fixture evidence, not an administrator-resistant
journal, a complete Windows event collector, or proof of a human's intent.
Administrator/kernel compromise, arbitrary desktop applications, GPU isolation,
and hardware/covert-channel guarantees are outside this profile.

## Experimental no-data initialization observation

The strict byte worker could not initialize Winsock and two system DLLs, so
its network, clipboard and COM restriction observations remain incomplete.
This separate diagnostic runs an ordinary control, a zero-capability LPAC
child and another ordinary control, recording only fixed initialization results.
The controlled child has one bounded report pipe and no mount, input file,
protected bytes, policy pipe or Writ session. Direct child invocation accepts
a pipe handle but does not read data from it. Its executable, package, process
lifetime, command and handle list differ from the byte worker; it is not an
admitted Writ actor and does not establish equal execution conditions.

On a disposable, isolated Windows x64 machine with MSVC and the Windows SDK,
with no protected-data worker running, build outside the checkout and use an
elevated PowerShell session:

```powershell
cmake -S contrib/native-hosts/windows/init-diagnostic -B C:\writ-init-build -A x64
cmake --build C:\writ-init-build --config Release
ctest --test-dir C:\writ-init-build -C Release --output-on-failure
& C:\writ-init-build\Release\writfs-init-diagnostic.exe
```

The optional diagnostic creates its own package profile, private image and job;
the LPAC launch also installs four temporary owned WFP filters. Successful
launches require checked owned-resource teardown and readback that those filters
are absent. A launcher setup failure can erase cleanup state: that result is
incomplete and cleanup is not independently verified. Destruction of the
disposable runner is fallback containment, not evidence of successful cleanup.
Timeout, profile-readback and cleanup-failure paths have not been fault injected.

The [recorded Windows run](../../../verification/windows-init-observation-42313767360/README.md)
at source `9b02fa5` completed its ordinary controls, separate LPAC observation
and checked cleanup. Its generic error values do not establish a cause or an
access denial, and it gives no byte-worker confinement or host qualification
credit. The [earlier build failure](../../../verification/windows-init-build-42313479154/README.md)
is preserved. Independent full-token equivalence and controlled-factor
comparisons remain open. The diagnostic is not part of the default native build
or registered workflow; source presence does not establish a new Windows run.

## Pinned primary sources

- [WinFsp 2.2B5 release and published security fixes](https://github.com/winfsp/winfsp/releases/tag/v2.2B5),
  [API source at `14d6e0280ae15e2550c44d6dbc476be51649727f`](https://github.com/winfsp/winfsp/blob/14d6e0280ae15e2550c44d6dbc476be51649727f/inc/winfsp/winfsp.h),
  and [upstream licensing](https://github.com/winfsp/winfsp/blob/v2.2B5/License.txt).
- [Microsoft LPAC launch guidance](https://learn.microsoft.com/en-us/windows/win32/secauthz/implementing-an-appcontainer)
  and [AccessCheck](https://learn.microsoft.com/en-us/windows/win32/api/securitybaseapi/nf-securitybaseapi-accesscheck).
- [CreateRestrictedToken's returned-handle rights](https://learn.microsoft.com/en-us/windows/win32/api/securitybaseapi/nf-securitybaseapi-createrestrictedtoken)
  and [SetTokenInformation](https://learn.microsoft.com/en-us/windows/win32/api/securitybaseapi/nf-securitybaseapi-settokeninformation).
- [Process creation attributes](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-updateprocthreadattribute),
  [Job Objects](https://learn.microsoft.com/en-us/windows/win32/procthread/job-objects),
  and [WFP object lifetime](https://learn.microsoft.com/en-us/windows/win32/fwp/object-management).

WinFsp installer SHA-256:
`293ffb9bcc0b625c85079fe85fa77f8fe98170aba51a02ac9c83d58f6c3b0e2f`.
