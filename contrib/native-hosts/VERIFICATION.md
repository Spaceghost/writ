# Native canary execution evidence

This record covers one immutable public fixture of at most 64 KiB and one
supervised reader. It does not qualify arbitrary applications, external grant
issuance, durable publication/audit or a complete protected-data host. Native
filesystem execution and the selected confinement probes are separate claims.

## Common Bend implementation

The new sources are `writfs/MountAuthority.bend`, `writfs/Mount.bend` and
`writfs/MountTests.bend`. The concurrent HostBinding/runtime work from master
`58cdbfa4c239de048467bd838e636fe2eab490c6` was integrated before the latest
local regression checks; all 67 Bend files in that revision remain byte-identical.
This contribution changes no existing security law, core implementation, rclone
behavior or native storage operation. The source exception permits only the
inventoried native bindings and probes under this contribution.

| Check | Result | Captured evidence |
| --- | --- | --- |
| Shared mount corpus, generated JavaScript | 69 decision vectors plus one count-consistency assertion: 70 PASS lines, exit 0 | [mount-model-js.txt](verification/mount-model-js.txt) |
| Same mount corpus, native Bend CPU | 70 PASS lines, exit 0; four threads, GPU off | [mount-model-native.txt](verification/mount-model-native.txt) |
| Existing core, generated JavaScript | 782 PASS lines, 41 HostBinding vectors, exit 0 | [core-js.txt](verification/core-js.txt) |
| Existing core, native Bend CPU | 782 PASS lines, identical 41 vectors, exit 0; four threads, GPU off | [core-native.txt](verification/core-native.txt) |
| Real Node bridge subprocesses | Nine framing, malformed-input and maximum-payload checks | [transport.txt](verification/transport.txt) |
| Windows native C-to-Bend transport | 22 native assertions passed at `35c5665e`; the enclosing job failed separate worker probes | [transport-41774496221.log](windows/verification/transport-41774496221.log) |
| Existing ordinary proof check | Six laws including the upstream HostBinding additions; `ALL PROOFS CHECK` | [proofs.txt](verification/proofs.txt) |

The corpus covers canonical framing, exact SHA-256, the complete 64 KiB boundary,
oversize rejection, immutable replacement denial, full facade admission and
retained commit/origin policy, public-destination and revoked-registry denials,
native actor slots, metadata, handles, ranges, EOF, close/no-reuse, exhaustion,
revocation and STOP. It does not simulate an external issuer or a live wall-clock
revocation feed. Native identity comes from each binding's retained OS evidence.

Boundary fixture strings are constructed with logarithmic doubling, preserving
the exact original bytes and assertions while avoiding repeated string prepends
in QuickJS. The executable count is 70 because `main` adds one consistency check;
the pure exported `run` and `count` both return 69. Native Genode runs those pure
vectors and records the comparison separately.

The combined core outputs are byte-identical across the two local backends, and
their 41 HostBinding vectors match the integrated upstream record exactly. The
vector record's SHA-256 is
`1842e96673fe3b24eaff99ca820065d9dab05817c153132f6dd2b5d0ff9430ff`.
Earlier native snapshots ran 638 or 764 core checks; their retained records keep
those historical counts. Running the HostBinding model corpus does not qualify
general native delegation or complete its host adoption proposal.

Local checks used Bend 2.0.39, Linux x86_64, Node 24.22.1 and clang 19.1.1.
The platform CI lanes pin Node 22.23.4 where used. Ordinary proof checking is not
independent Lean kernel verification; `--verdict` was not run. No physical GPU
was exercised. Generated C/JavaScript and binaries remain outside the repository.

The committed stdout records are exact copies from Linux CI run 41776660115,
artifact 13296764680, whose archive SHA-256 was verified. Its core outputs are
byte-identical to the upstream records and the independently observed local
runs. The local Node 24.22.1 and CI Node 22.23.4 executions remain distinct.
The later master dc6ff2b2 adds only a Genode-channel plan; implementation inputs
tested in the native lanes are unchanged.

## Native target records

| Target | Actual native evidence | Scope |
| --- | --- | --- |
| Linux | [Passing run 41776660115](https://github.com/Spaceghost/writ/actions/runs/41776660115); [retained record](linux/verification/README.md) | Integrated 782-check core; real FUSE reads/metadata and actor denials; fixed confined-worker probes; revocation; interpreter loss; broker SIGKILL; owned cleanup |
| Windows | [Run 41778041710, overall failure](https://github.com/Spaceghost/writ/actions/runs/41778041710); [retained record](windows/VERIFICATION.md) | Real WinFsp mounted reads and revocation pass; byte-worker network, clipboard and COM probes remain incomplete; separate no-data diagnostics do not complete that profile |
| Genode | [Passing run 41776659987](https://github.com/Spaceghost/writ/actions/runs/41776659987); [retained record](genode/VERIFICATION.md) | Native x86_64/base-hw QEMU: 782 core checks, 69 mount vectors, 24 allocator assertions, 56 filesystem-session assertions and eight libc/VFS assertions; diagnostic clients are not qualified protected workers |

The Linux and Genode CI runs establish native execution of the integrated
782-check core independently of the local regression results. Earlier Linux
and Genode records retain their actual 638/764-check results and failed attempts.

The Windows byte worker's incomplete probes earn no confinement credit. A
separate no-data LPAC diagnostic helper, with registry-read capability and
Win32k enabled, passed seven configured probes both with and without the WFP
filters. That helper receives no canary bytes and has a different profile;
its results do not replace the byte worker's missing qualification. The overall
Windows run remains failed even though its mounted-read and revocation checks
passed. See the native record for the exact controls, API results and gaps.

Each record pins the source/runtime/OS or base configuration and preserves
failed outcomes. A model pass or successful cross-compile cannot replace a
mounted read or confinement result. The Windows and Genode bindings execute
Bend-generated JavaScript in native Node/QuickJS; neither claims a general
machine-code Bend runtime port.

## Review and failure behavior

The implementation was reviewed independently across platform ownership.
Review specifically examined native lifetime mapping, queued/late protocol
data, bounds before narrowing, packet ranges, failure propagation and cleanup
ownership. Findings and their fixes are retained with native evidence. No
passing result is inferred from a missing API or a target that was never shown
to work in its positive control.

The private interpreter owns its authoritative state. It adopts the next state
before admitting the corresponding effect. Native framing failures, timeouts,
sequence mismatches and interpreter loss poison that instance; there is no
automatic replay, restart or weaker grant path. A host may expose only its fixed
public mount structure before admission. User-controlled paths, labels and
packet fields cannot become authoritative actor identities.

Revocation stops future mediated observations. Plaintext already observed and
cached pages require the separately specified lifetime confinement controls.
Native callback facts identify a process/session context; they do not establish
human intent. The bounded in-memory event records are diagnostics and may be
lost on crash. Durable audit, restart-safe attribution and authenticated
production enrollment remain pending product requirements.

The broader host, WritFS namespace, issuer and durable-publication proposals
retain their own unchecked tasks. See the
[OpenSpec suite](../../openspec/README.md) and
[product requirements](../../docs/WRITFS-PRODUCT.md).
