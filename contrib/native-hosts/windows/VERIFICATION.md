# Native Windows evidence

**Final workflow result: FAILURE.** The real mounted filesystem passes reads
and revocation, including in the zero-capability, Win32k-disabled LPAC worker.
The separate no-data API diagnostic passes. Direct network, clipboard and COM
observations in the byte worker remain incomplete and receive no confinement
credit; the LPAC command retains exit code 1. The diagnostic is not a substitute
for qualification of the byte worker.

This is a bounded public-canary contribution, not a qualified Windows
protected-data host. The native presentation and the stronger confinement
contract have separate results.

This record addresses the bounded [native-host canary contract](../../../openspec/specs/native-host-canary-mounts/spec.md), especially NM004 through NM008, and the [private transport protocol](../PROTOCOL.md). It does not complete the broader [Windows host proposal](../../../openspec/changes/add-windows-host/specs/windows-host/spec.md).

## Later master run

[Run 42311207831](https://github.com/Spaceghost/writ/actions/runs/42311207831)
at source `9c08eb9` also **failed** the strict LPAC canary gate. The retained
[run record](verification/run-42311207831/README.md) includes the full
normalized captures and raw artifact hashes. Mounted reads and revocation
passed; the byte-worker network, clipboard and COM observations remained
incomplete and received no restriction credit. Its separate no-data diagnostic
is not a substitute. The cause is not yet established.

## Standalone initialization diagnostic (separate no-data observation)

The source now includes `writfs-init-diagnostic`, a standalone no-data
initializer observer and synthetic `init-report-framing` test. Its LPAC
launch reuses the same control setup and readbacks, but its executable,
package, lifetime and single report handle differ from the byte worker.
The first [Windows diagnostic build](../../../docs/superpowers/records/2026-11-06-windows-init/run-42313479154/README.md) failed on a nonexistent SDK header before the diagnostic or its synthetic test ran. The corrected source `9b02fa5` was then built and executed in the separate [no-data diagnostic run 42313767360](../../../docs/superpowers/records/2026-11-06-windows-init/run-42313767360/README.md). Its ordinary controls initialized successfully, while its separate LPAC process reproduced Winsock 10107 and DLL load errors 1114 and 1359. The observation and owned-resource cleanup completed; it is not byte-worker confinement evidence.
Full token-group and privilege equivalence has not been independently
verified, and the control-factor matrix is not implemented. This does not
change the failed and incomplete outcomes recorded above.

## Prior detailed source and run

- Tested source:
  [7b50d99d451f0f5b44dfa6d0ec23a8ced8790496](https://github.com/Spaceghost/writ/commit/7b50d99d451f0f5b44dfa6d0ec23a8ced8790496),
  tree `f2e69e256c47ea0f9e0268175d1dd550587964f7`.
- [Workflow run 41778041710](https://github.com/Spaceghost/writ/actions/runs/41778041710),
  [native Windows job 126402930375](https://github.com/Spaceghost/writ/actions/runs/41778041710/job/126402930375):
  **failure**, 2026-11-04 UTC.
- [Retained native transcript](verification/native-41778041710.log) preserves
  the observed identity, policy event, positive-control, probe and final-result
  lines, including failed and incomplete results.
- [Exact source SHA-256 inventory](verification/source-7b50d99d.sha256) covers
  20 native/shared source files and the workflow at that tested commit.
  These hashes identify the pinned source, including its protocol document;
  later documentation edits are not retroactively described as tested source.
- [Evidence artifact 13297464201](https://github.com/Spaceghost/writ/actions/runs/41778041710/artifacts/13297464201),
  `windows-native-evidence-1`, 42,879 bytes, ZIP SHA-256
  `bcee72e0587ceefcf6b35ab5502697f2fc362167229c3ebcc3090cf38895ad15`.
  GitHub artifact retention is 14 days. The retained transcript and source
  inventory remain in the repository.

| Component | Recorded version or identity |
| --- | --- |
| OS | Microsoft Windows Server 2025 Datacenter 10.0.26100, x64 |
| Runner image | `win25-vs2026 20261030.294.1` |
| Native compiler | MSVC 19.51.36260.0 |
| Policy compiler | Pinned Bend 2.0.39, generated on the workflow's Linux job |
| Native interpreter | Windows Node 22.23.4 |
| Generated `mount.mjs` SHA-256 | `11595d6ad83fd3a072784a1feded3e39d0f23cd21843278be4f959a13cd235d8` |
| WinFsp runtime | `2.2.26286.14d6e02`, prerelease 2.2B5 |
| WinFsp source | `14d6e0280ae15e2550c44d6dbc476be51649727f` |
| Native reader image SHA-256 | `2d2c13a11b90176df62785d4a1992f0eb51681d0eda39227262308c0dd4d0dea` |

The workflow verifies the pinned WinFsp installer's SHA-256 and Authenticode
signature, the generated module digest and originating commit. Its Windows
execution uses native MSVC binaries, WinFsp and `node.exe`; it is not WSL
evidence. The upstream WinFsp header emits C4324 for alignment padding; there
were no compilation errors. WinFsp prerelease qualification remains open.

## Results by boundary

| Boundary | Observed result |
| --- | --- |
| Generated Bend model on native Windows Node | PASS: 69 Mount cases plus the count assertion, 70 true results |
| Node bridge contract checks | PASS: 9 transport probes |
| Native C private-pipe transport | PASS: 22 assertions, including the real Bend lifecycle, stripped environment, exact 64 KiB transfer/digest, fragmented replies, malformed/unsolicited/replayed replies, EOF, both 15-second read/write deadlines, child retirement and retry refusal |
| Ordinary mounted canary | PASS: actual WinFsp mount, reads/digest/range/EOF/directory, unsupported mutations denied, revocation and normal teardown |
| Actual LPAC token and launch controls | PASS: exact package/user/logon binding, low integrity, no elevation, zero capability SIDs, native LPAC AccessCheck controls, job/child/Win32k readback and four package-scoped WFP blocks |
| LPAC volume traversal | PASS: security descriptor of only the newly owned device is read back, the actual token passes access checking, and the worker reaches the Bend-backed callbacks |
| LPAC filesystem reads | PASS: the same seven filesystem checks; plain/wrong callers remain denied |
| Impersonation boundary | PASS: another native process presenting the actual worker token is still denied as actor 0 |
| Ordinary same-user process access | PASS: 12 denials for VM_READ, DUP_HANDLE, WRITE_DAC and WRITE_OWNER across the live broker, Node policy and worker processes, with self-access positive controls |
| LPAC revocation | PASS: new open and a subsequent uncached read through the existing handle are both denied |
| Direct byte-worker network/clipboard/COM | **INCOMPLETE**: Winsock 10107; user32 loader error 1114; ole32 loader error 1359. No restriction credit |
| Separate no-data diagnostic | PASS: all seven strict API probes before and after removal of the owned WFP filters; receiver-side checks remain empty |
| Strict LPAC command and enclosing workflow | **FAILURE**, exit 1 retained |

The final structured result is:

```text
LPAC_OBSERVATIONS mounted_and_revoked=pass byte_worker_confinement=incomplete no_data_diagnostic=pass
```

### What the diagnostic demonstrates

The diagnostic has the same package identity but its own retained process and
job, exactly the `registryRead` capability and Win32k enabled. Its child and job
UI restrictions are checked. The ordinary-process positive controls first
demonstrate successful TCP/UDP sends and receives, an actual child launch,
clipboard open/close, and local COM initialization/activation. The two
diagnostic runs then record these specific restrictions:

| Probe | Native diagnostic result, both phases |
| --- | --- |
| TCP IPv4, TCP IPv6, UDP IPv4, UDP IPv6 | `WSAEACCES`, 10013, all four |
| Child creation | `ERROR_CHILD_PROCESS_BLOCKED`, 367 |
| Clipboard | Stage 3, the OpenClipboard call: `E_ACCESSDENIED`, 0x80070005 |
| COM | Stage 3, CoInitializeEx: `E_ACCESSDENIED`, 0x80070005 |

Phase 1 runs with the owned package WFP filters installed; phase 2 runs after
their removal. The code checks live receivers after each diagnostic, including
an explicit check after phase 2. These are four local loopback routes, not
coverage of every Windows network route or helper.

The diagnostic receives one report pipe and four public receiver ports. It
receives no canary bytes, input path, mount name, filesystem handle, policy
pipe or logical admission. Its process never replaces the byte worker in the
host's actor mapping. Sharing the package SID therefore does not grant actor 1.

The byte worker retains the stronger zero-capability and Win32k-disabled
profile. Its Winsock initialization error 10107 and DLL load failures
`0x8007045a`/1114 and `0x8007054f`/1359 prevent the direct probes from reaching
the corresponding API stages. A missing DLL/export, initialization error,
unregistered COM class or unrelated error is not accepted as a successful
restriction. The no-data profile's results remain separate.

### Cleanup and exit semantics

The ordinary mount lane prints its final PASS only after worker retirement,
dispatcher quiescence, removal and deletion of the owned mount, verification
that the owned drive letter disappeared, owned worker resource cleanup, Bend
STOP and verified policy-child retirement. The LPAC lane reaches revocation,
completes the same cleanup path and prints no cleanup-error message. Its
overall result is still failure. There is no independent positive LPAC
cleanup line, so this is normal-exit evidence, not crash/recovery qualification.

The generic final line also prints `win32=10035`. In this run that is the last
nonblocking receiver result (`WSAEWOULDBLOCK`), not the cause of the overall
failure. The explicit INCOMPLETE lines and `LPAC_OBSERVATIONS` identify the
failed direct confinement gate. This field is preserved in the transcript.

## Earlier native results retained

These earlier runs explain the separate results and preserve the failures
encountered during native bring-up.

| Source and run | Evidence and limit |
| --- | --- |
| [35c5665e](https://github.com/Spaceghost/writ/commit/35c5665efef64420b73fe84d6d198f17e1fec891), [41774496221](https://github.com/Spaceghost/writ/actions/runs/41774496221) | First native C transport PASS, all 22 assertions; [retained transcript](verification/transport-41774496221.log). The enclosing job failed separately after partial mounted success: same-user probe error 5, LPAC native-lifetime/token setup error 87. This was not a passing mount/confinement run. |
| [eb5f769a](https://github.com/Spaceghost/writ/commit/eb5f769a4a3e2b5e9ab638b3871d6c9a88da1ef9), [41775445171](https://github.com/Spaceghost/writ/actions/runs/41775445171) | Complete ordinary mounted read/revocation/normal-teardown PASS and 12 same-user process denials; [retained transcript](verification/mount-41775445171.log). The LPAC launch still failed its no-elevation gate. |
| [ade584c1](https://github.com/Spaceghost/writ/commit/ade584c113676530a244f62b8ec032a0042451d9), [41777164952](https://github.com/Spaceghost/writ/actions/runs/41777164952) | The exact per-volume descriptor/readback fix allowed the real zero-capability LPAC reader to reach the callbacks and pass all seven filesystem checks; [retained transcript](verification/lpac-read-41777164952.log). Direct network/clipboard/COM results failed their strict gate; this run did not yet reach LPAC revocation. |

The error 87 in the earlier setup is an observation from that implementation
and Windows build, not a general claim that a Windows token-information API is
unsupported. The final code verifies LPAC behavior with native AccessCheck on
the real token and unchanged descriptors: exact-package and ALL RESTRICTED
APPLICATION PACKAGES permits succeed; ALL APPLICATION PACKAGES-only and
user-only permits fail. It retains the actual AppContainer, capability and
launch-attribute checks and never falls back to an ordinary AppContainer.

## Remaining qualification limits

This profile contains one immutable object, one admitted reader and a fixed
local public-canary standing. It is not an authenticated external grant issuer
or general file enrollment system. Create/Open identity joins an OS request PID
and effective token to a retained process lifetime; Read/Close use that open's
binding. This is process evidence, not attribution of a human's intent.

Revocation covers new opens and the subsequent uncached reads demonstrated
here. It does not erase bytes already returned, copied, mapped or cached.
The original operator-supplied file is expressly public and remains an
independent copy.

Dedicated execution accounts, thread and auxiliary object isolation, verified
image/data enrollment, profile/registry/cache/crash-artifact disposal, hostile
helper/device coverage, broker-crash teardown, restart recovery, durable
publication and protected audit storage remain open. The fixture's elevated
administrator account is trusted; administrator/kernel compromise is outside
the claimed boundary. WinFsp prerelease deployment qualification and direct
byte-worker channel evidence remain required before a protected-data Windows
product claim.
