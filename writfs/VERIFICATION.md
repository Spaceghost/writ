# WritFS verification

Verified locally on **2026-11-04**, Linux x86_64, with **Bend 2.0.39**,
**clang 19.1.1**, and **Node 24.22.1**. Native CPU runs use four threads and
`--gpu off`. Native filesystem evidence comes from separately provisioned
GitHub Actions VMs; this editing workspace has no Btrfs/ZFS driver, mount
capabilities, `/dev/zfs`, `/dev/fuse`, or loop-control device.

## Model, parser, and runtime checks

| Suite | Checks per backend | Evidence |
| --- | ---: | --- |
| Native model | 78 | [JavaScript](verification/native-model-js.txt), [native CPU](verification/native-model-native.txt) |
| Host parser/runtime | 17 | [JavaScript](verification/host-js.txt), [native CPU](verification/host-native.txt) |
| **WritFS total** | **95** | **Both complete runs passed** |
| Shared SHA-256 regression | 25 | [JavaScript](verification/shared-sha-js.txt), [native CPU](verification/shared-sha-native.txt) |
| Existing rclone model regression | 74 | [JavaScript](verification/rclone-model-js.txt), [native CPU](verification/rclone-model-native.txt) |
| Existing core library regression | 638 | [JavaScript](../verification/tests-js.txt), [native CPU](../verification/tests-native.txt) |

The model checks exercise all three provider-specific operation identities,
complete uint64 identities, canonical locators, malformed/writable/nested source
denial, exact source seals, provider/plan/artifact/backend binding, full facade
authorization, current revisions and subjects, public-destination denial, revoked
descriptors, and complete output policy/DLM/state retention. Native postcondition
checks cover source substitutions, wrong parent/store/type/locator, writable or
exposed outputs, command changes, and exact reconciliation.

The host checks exercise Btrfs and ZFS metadata parsing, full high-bit identities,
duplicate/malformed observations, canonical subvolume roots, private staging
ownership and mode, exact store identity, destination collisions, fixed execution
environment, and redacted diagnostics. Actual subprocess probes verify that a
64-byte output fits a 64-byte runtime cap while 65 bytes returns failure; an
overflow is not a truncated successful observation.

`Main.bend` and `NativeIntegration.bend` compile to native executables.
The [CLI smoke record](verification/cli-smoke.txt) verifies usage, unsupported
provider, and traversal-selector exits. It is separate from the model counts.

## Native filesystem acceptance

Both native lanes passed in [run 41748733557](https://github.com/Spaceghost/writ/actions/runs/41748733557)
at implementation commit `ede07df5ccaa08b4695788770d16b7eeb269d3c0`:

| Native lane | Assertions | Recorded outcome |
| --- | ---: | --- |
| Btrfs | 11 | [All passed; cleanup exit 0](verification/native-btrfs.txt) |
| ZFS filesystem and zvol | 18 | [All passed; cleanup exit 0](verification/native-zfs.txt) |

The jobs used fresh Ubuntu 24.04.5 VMs, kernel `7.0.0-1017-azure`, Btrfs tools
`6.6.3`, ZFS userspace `2.2.2-0ubuntu9.5`, and ZFS kernel module
`2.4.1-1ubuntu5.1`. Exact run/job identities, image, and native versions are in
[native-environment.txt](verification/native-environment.txt). These are observed
compatibility results, not a claim that every Btrfs or OpenZFS version is supported.

The [workflow](../.github/workflows/writfs-native.yml) checks the Bend release
archive hash, requires the actual filesystem module, compiles the Bend test
driver, and creates a fresh 1 GiB regular-file-backed filesystem or pool.
All assertions are in [NativeIntegration.bend](NativeIntegration.bend).
Missing support or failed assertions fail the lane; neither becomes a skip.

The Btrfs fixture checks a real native snapshot's bytes and kernel read-only
behavior, unchanged snapshot contents after a later edit to the original live
subvolume, denial of writable/ordinary-directory/nested sources, full policy
retention, collision refusal, and exact receipt reconciliation. The ZFS fixture
checks real filesystem and **block-volume** payloads, read-only behavior, native
clone identity/origin, unmounted/hidden private stages, collision refusal,
reconciliation, and rejection after the harness explicitly changes presentation
controls to inspect its public data. Public and revoked authority are denied
before each provider's native mutation.

Only the test harness mounts the public filesystem clone or exposes its public
zvol. The supported host API never does so. Cleanup is limited to the exact pool,
mount, and loop device successfully created by the same job; cleanup failure
fails the job. This evidence does not involve any user pool or disk.

## Windows policy execution

[Run 41750878613](https://github.com/Spaceghost/writ/actions/runs/41750878613)
at commit `b709bd833cd71eb51d8dbf4ed0c60974a2b5e073` passed **638 core checks**
and **78 native-storage model checks** on Windows Server 2025 Datacenter
`10.0.26100`, using native `node.exe` **22.23.4**. The pinned Linux Bend compiler
generated the JavaScript; artifact hashes matched on Windows before execution.
Both suites exited zero. No WSL was used.

See the [environment and artifact record](verification/windows-policy-environment.txt),
[core output](verification/windows-policy-core.txt), and
[model output](verification/windows-policy-model.txt). The
[workflow](../.github/workflows/writfs-windows-policy.yml) reproduces this lane.

This is native Windows OS execution of Bend-generated JavaScript. It does not
establish a Windows filesystem mount, Windows-native machine-code Bend runtime,
LPAC/WFP confinement, attribution service, or Windows 11 qualification. The
17 host-parser/runtime checks and actual Btrfs/ZFS effects ran on Linux only.

## Corrections established by native execution

The first actual Btrfs run created a snapshot but correctly refused to call it
verified when the assumed source-generation equality failed. Diagnostic evidence
showed the read-only source generation advancing from `7` to `8`, with every
other source field unchanged; the new snapshot had generation and creation
generation `8`. Native snapshot creation can COW the source root in that
transaction. `Native.snapshot_source_transition` now accepts only the exact
relation `old < new == created.generation == created.creation`, preserving all
other source fields and the original artifact/intent. Preflight remains exact.

Eight additional model assertions cover numeric ordering across uint64 widths,
the admitted transition, unchanged preflight strictness, a wrong transaction,
substituted source UUID, inconsistent created generation/creation, successful
exact reconciliation, and rejection of a later unrelated source generation.
This is an operation-specific postcondition correction, not a removal of native
generation checks or a change to a core security law.

The initial zvol fixture used `udevadm settle`, which can return after draining
currently queued events before an asynchronous device appears. It now uses a
15-second `udevadm wait` for the exact newly owned `/dev/zvol/...` path. The
subsequent real zvol test passed payload, read-only, hidden-device, and changed-
control checks. No timeout, policy error, or unsupported operation was converted
into success.

The pinned native compiler also exposed its arity limit when test continuations
retained several wide authority/receipt records simultaneously. Splitting fixture
helpers and consuming independent records resolved compilation; assertions and
policy behavior were retained. Generated C, JavaScript, and binaries stay outside
the repository.

## Shared code and unchanged core

The SHA-256 implementation moved from the contribution to `lib/Sha256.bend`.
After excluding import-path lines, it is byte-identical to the prior version.
The contribution's existing Digest API forwards to it. Both 25-check vector and
74-check model suites passed after this extraction.

All **34** original core/example Bend files remain byte-identical to the
pre-WritFS rclone base (`06522bdce860ff720f16a8c331061f46627bb422`, tree
`c3ec0513ca10f44a5675daed3a2eea22903a0304`). The root 638-check suite passed on
each CPU backend, and [ordinary proof checking](../verification/proofs.txt)
passed for the same three selected laws. See the
[source comparison](verification/source-review.txt) and root
[verification record](../VERIFICATION.md).

The original rclone wire, service, CLI, and Go evidence remains scoped to that
unchanged behavior. WritFS does not silently replace its memory-only backend.

## Evidence limits

Native integration establishes the documented administrative private-staging
operation on the recorded Linux/native-tool combination. The source-seal SHA-256
names a canonical native manifest, not all payload bytes. ZFS clone GUID and
creation TXG are creation identities; current-control checks do not detect a
privileged mutate-and-restore history. Public Bend constructors and command
consistency checks do not authenticate a caller.

This work does not implement durable authority/receipt storage, crash-safe
logical publication, arbitrary-worker confinement, a mounted Writ POSIX view,
an authenticated multi-user storage service, or revocation of issued native
handles. The existing production host/issuance/confinement/publication tasks
remain pending. Physical GPU execution and independent Lean kernel verification
have not been established. Ordinary proof checking and finite tests do not
prove the whole host or native filesystem.

The root [source manifest](../verification/source-sha256.txt) covers the delivered
authored sources, documentation, and recorded output. Requirement mapping is in
[native traceability](../openspec/traceability/native-snapshot-staging.md).
