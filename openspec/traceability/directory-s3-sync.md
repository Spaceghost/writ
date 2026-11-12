# Directory/S3 preview traceability

Contract: [directory/S3 sync](../specs/directory-s3-sync/spec.md).
Source-bound execution: [verification record](../../verification/directory-s3-preview/README.md).
This ordinary Windows file-sync profile does not qualify a protected Writ host.

| Requirement | Implementation and executable evidence | Remaining scope |
| --- | --- | --- |
| DSS-001 | `writfs/DirectorySync.bend`; `DirectorySyncTests.bend` checks distinct edits, rollback, same-version mutation and exact base; native `Smoke.ps1` exercises offline edits, competing clients and stale ETags | No dedicated conflict-resolution UI; user files and remote versions are retained |
| DSS-002 | `lib/Sha256Stream.bend`, 20 independent boundary/vector checks; `DirectorySyncTests.bend`: “directory corrupt remote body rejected”, “directory application needs local recheck”, “directory exact applied artifact advances baseline”, “directory application cannot replay” | 1 GiB per file; native fixture includes a 1,048,577-byte binary, not a 1 GiB throughput qualification |
| DSS-003 | `directory.hpp` retained handles, recovery rename and no-replace installation; `native_probe.cpp` competing writer/rename and recreated target; `Smoke.ps1` conditional publishers, corrupt download, write failure and writer-after-hash barrier | No power-loss qualification or remote garbage collection |
| DSS-004 | `DirectoryNamespace.bend` and 24 named namespace checks; native name/reparse/alias guards; `connection.hpp`, `connection_dialog.hpp`, `s3.hpp`; native form and HTTPS/SigV4 smoke checks | 2,048 tracked paths including tombstones; actual R2 execution unrun; OneDrive deferred |

Focused model execution comprises 20 streaming, 42 reconciliation and 24
namespace assertions on JavaScript and emitted C. Native Windows tests use the
exact packaged executable and a separate HTTPS fixture that verifies SigV4 and
conditional writes. Local root identity and observed-remote markers prevent a
replaced root or missing established manifest from becoming a fresh sync. They
are exercised by the native smoke suite. OS credential isolation and the remote
service remain trust dependencies; the fixture does not prove either service.
