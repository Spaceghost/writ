# Native Genode verification record

This record separates the executing native filesystem and passing native corpus
from the remaining product gates. The public-canary lane is not a protected-data
qualification.

## Final integrated CI result on 2026-11-04

[Run 41776659987](https://github.com/Spaceghost/writ/actions/runs/41776659987),
[job 126398485896](https://github.com/Spaceghost/writ/actions/runs/41776659987/job/126398485896),
**passed the complete fresh build and all three native boots** at source
[`a66c03e5249d3e507694dbe11070a27aa8024d81`](https://github.com/Spaceghost/writ/commit/a66c03e5249d3e507694dbe11070a27aa8024d81),
tree `bb800e0950d579028a560d4868809c69e7aebd5a`.
This revision includes the later upstream HostBinding changes that expand the
core corpus to 782 assertions and 41 vectors.

| Gate | Final native CI result |
| --- | --- |
| Host allocator sanitizers | **PASS**, 24 assertions with AddressSanitizer, UndefinedBehaviorSanitizer, and leak detection enabled |
| Native allocator invariants | **PASS**, the same 24 assertions on Genode libc |
| Complete generated core corpus | **PASS**, 782 assertions and 41 HostBinding vectors; 6,623 ms |
| Complete generated mount corpus | **PASS**, all 69 assertions including the full 64 KiB boundary; 132,427 ms |
| Native filesystem sessions | **PASS**, 56 assertions: admitted reader 44, unadmitted component six, forged-label component six |
| Native libc/VFS consumer | **PASS**, eight assertions through the real mounted service |
| Interpreter reservation bound | **PASS**, peak 61,331,033 bytes below 67,108,864; zero live and reserved bytes at teardown |

The clean Ubuntu 24.04 job used the standalone build script, the pinned Genode
25.05 cross-compiler, QEMU 8.2.2 TCG, and native Genode 26.08 base-hw x86_64.
It ran the ordinary Bend proof check and completed source, executable, and ISO
hash capture. It needed no source patch, manual ABI-check substitution, or
local-prefix workaround.

The [final run manifest](evidence/ci-a66c03e-success.json) records the exact run,
job, source tree, original artifact digest, per-file hashes, and native results.
The repository retains the [corpus](evidence/corpus-41776659987.log),
[filesystem](evidence/filesystem-41776659987.log), and
[VFS](evidence/vfs-41776659987.log) serial transcripts, the
[sanitizer result](evidence/41776659987-allocator.log),
[source/build hashes](evidence/41776659987-source-and-build.sha256),
[environment](evidence/41776659987-environment.log), and exact supervisor
configurations listed in the manifest. Transcript normalization is explicit;
original artifact bytes retain their own hashes.

The downloaded [artifact 13296943548](https://github.com/Spaceghost/writ/actions/runs/41776659987/artifacts/13296943548)
was verified against SHA-256
`1dcbf8b452afbceb9b6cfb55034af8adbaf39a342cf1e45ef9a2caa2485ad74e`.
The final generated core script has SHA-256
`9321b4a53c43cf6e44b2f6f4c46ac427f206f3d1974e88dd1e223707c65450db`.
Both generated mount scripts match the local hashes below. The native component
executables also match the preceding successful 764-corpus CI run byte-for-byte;
the later core assertions arrive through the freshly generated ROM input and
the explicitly updated expected-count configuration.

The preceding cached-runtime [run 41776304723](https://github.com/Spaceghost/writ/actions/runs/41776304723)
also passed at `897f3fa807fae9a3fe02b23db7244425ca986717`, with the then-current
764 core assertions and 40 vectors. Its
[separate manifest](evidence/ci-897f3fa-success.json) retains the exact earlier
source, artifact, configurations, and native transcripts. It is preserved as
historical evidence; the 782-result above covers the later upstream changes.

## Earlier local execution on 2026-11-04

The guest is Genode 26.08 **base-hw x86_64**, booted as a native ISO in QEMU
8.2.2 using software CPU emulation. It is not Genode's Linux base. Components
were cross-built with the official Genode 25.05 toolchain, GCC 14.2.0, and run
with native QuickJS 2026-06-04. Archive pins are in [README.md](README.md).

| Gate | Result and exact scope |
| --- | --- |
| Native `File_system` sessions | **PASS**, 56 native assertions: 44 for the admitted reader, six for an unadmitted component, and six for a forged-label component |
| Native shared-memory descriptor safety | **PASS**, including offset `-1`, and offset `tx_dataspace_end - 1` with size `SIZE_MAX` and requested length eight; replies deny the operation with zero returned bytes and no payload-buffer change |
| Native names and handles | **PASS**, including embedded NUL, missing terminator, traversal, metadata-only and closed handles, foreign-session handles, nonreused identities, and a 32-handle bound |
| Native revocation | **PASS**, trusted revoke-only capability blocks retained-handle reads, metadata, and new opens; handles still close |
| Native libc VFS consumer | **PASS**, eight assertions through actual `open`, `read`, `lseek`, `fstat`, and `close`, with write/unknown-object denial |
| Native allocator invariants | **PASS**, 24 assertions for alignment, requested-size reporting, in-place growth/shrink, copy preservation, failed growth, charged cached capacity, bounded cache counts, eviction, the 64 MiB limit, and complete teardown |
| Integrated 764-test core corpus inside native Genode | **PASS**, including the concurrent upstream HostBinding additions; zero live and reserved QuickJS bytes after teardown |
| All 69 mount model checks inside native Genode | **PASS**, including the full 64 KiB boundary, with the unchanged generated policy and the bounded runtime allocation cache |
| Host allocator AddressSanitizer and UndefinedBehaviorSanitizer | **PASS**, the same 24 assertions; local leak detection could not execute because of the workspace's `/proc` namespace, so that result is not claimed |
| CI allocator sanitizer gate | Requires AddressSanitizer, UndefinedBehaviorSanitizer, and leak detection on the ordinary Ubuntu runner; a failure stops the lane before native builds |

The raw session and VFS results above were rerun with the bounded allocator
cache, subtraction-based descriptor guard, and exact native name validation.
Passing them establishes a native filesystem service and native VFS integration
for the public fixture. The complete core and mount corpus executed in the
native guest; no boundary test was skipped and no Linux-hosted substitute was
used.

The local timed guest reported **5,288 ms** for the 764 core assertions and
**107,454 ms** for the 69 mount assertions through its native Timer session.
The corpus build plus boot took **120.622 seconds** of host wall time. The raw
filesystem and libc VFS build-plus-boot runs took **11.862** and **6.817 seconds**.
These are observations from software emulation on this shared build host, not
product performance guarantees. The native corpus deadline remains 600 seconds.

The public fixture is the 33-byte UTF-8/ASCII string
`Writ native Genode public canary` followed by LF. Bend computed its actual
SHA-256 as:

```text
4e69733490c465b5561bd477617265a72e614cbabb3ec570fcb1c1b54df32e6a
```

The service reported live and reserved peaks of **2,064,846 tracked bytes** while
initializing this fixture. The complete corpus reached a live reservation peak
of **60,675,673 bytes** and a total reservation peak, including free cached
capacity, of **61,331,033 bytes**, below the enforced **67,108,864-byte** limit.
Both live and reserved counters were zero after each interpreter was destroyed.
These metrics include the wrapper's allocation headers and charged cache
capacity, but do not measure all libc slab overhead or total resident memory.
The separate native component RAM quota is 128 MiB.

## Local evidence and source alignment

Local serial logs retained outside the checkout are named:

- `genode-native-filesystem-cached.log`: all three native client roles pass,
  ending with `WRIT GENODE FILE_SYSTEM ACCEPTED reader stranger forger`.
- `genode-native-vfs-cached.log`: the final guarded server with the libc
  consumer, ending with `WRIT GENODE LIBC VFS ACCEPTED`.
- `genode-native-corpus-cached-timed.log`: 24 native allocator checks, 764 core
  assertions, 69 mount assertions, timing and memory counters, ending with
  `WRIT GENODE CORPUS ACCEPTED 764 + 69`.
- `genode-allocator/asan-ubsan.log`: the 24 host allocator assertions under
  AddressSanitizer and UndefinedBehaviorSanitizer, with local leak detection
  explicitly disabled after its unsupported-environment failure.

The generated scripts were checked byte-for-byte against their embedded
contents in the final native boot images before retaining them:

| Embedded generated artifact | SHA-256 |
| --- | --- |
| `core-tests.js`, integrated 764 corpus | `849333764b8d32e34befc8ba067710246fe4a11abb5296fae6fd38099515309c` |
| `mount-tests.mjs`, 69 assertions with balanced boundary-fixture construction | `cad0f40f0d8d5fea4ea3f9c90614f513aedb01ecfc7477736d2a0d06ce90abaf` |
| `mount.mjs`, actual filesystem service policy | `11595d6ad83fd3a072784a1feded3e39d0f23cd21843278be4f959a13cd235d8` |

The workflow regenerates all scripts from its own checkout and records the
source, generated-script, executable, and ISO hashes. The local results in this
section remain distinct from the later CI records above.

The local build host used downloaded Ubuntu tools in an unprivileged prefix.
The upstream libc, libm, and VFS ABI checks and HID syntax checks were executed
explicitly with the extracted Tcl interpreter because `/usr/bin/tclsh` was
absent. No guest or upstream runtime source was patched and no ABI check was
waived. The CI workflow installs Tcl normally and runs the upstream build checks
directly.

## Preserved failed attempts

The initial CI [run 41774496385](https://github.com/Spaceghost/writ/actions/runs/41774496385),
job `126391570920`, failed at source
`35c5665efef64420b73fe84d6d198f17e1fec891`: its native 764 core assertions passed,
then the complete mount corpus exceeded the 600-second deadline. The script
exited 254 before the filesystem/VFS boots or final hash-manifest step.
The [failure manifest](evidence/ci-35c5665-failure.json) and
[native transcript](evidence/corpus-41774496385-failure.log) retain that outcome.
Artifact `13297266061` was downloaded and verified with SHA-256
`ab8956864a88f7ed25546b6a8a8e4ca4dfabcbff040de3a3c62a93167386e85b`.

Before the allocation cache, the historical 638-test core corpus passed in the
native guest, but the complete mount corpus timed out first at 180 seconds and
then at 600 seconds. `genode-native-corpus-final.log` retains the latter failure.
The core script embedded in that historical image has SHA-256
`63e06f1caee7ae094a0926be8c0b043d40c763d749b974a778b31c2535d627a8`.
Its 69-check mount script is byte-identical to the successful final script
listed above. Host QuickJS passed that corpus in about six seconds; that host
result did not satisfy the missing guest gate.

The runtime fix reuses bounded allocation reservations to avoid repeated native
RAM allocation and region-map RPCs for copied substrings. It leaves the generated
policy, upstream engine, stack checks, 64 MiB aggregate bound, and complete test
corpus intact. The later 764-result covers the upstream test additions; the
earlier 638-result alone did not.

## Unqualified behavior

This contribution has no claim of complete worker confinement, control of all
direct/indirect egress, safe arbitrary capability delegation, human attribution,
durable audit/recovery, writable publication, or native Btrfs/ZFS block storage.
Its test clients have diagnostic `LOG` capabilities. Administrative revocation
does not erase bytes already delivered to a client. General Bend C runtime
support on Genode remains separate; this service executes generated Bend
JavaScript with a native engine and preserved memory/stack checks.

The complete native product requirements in
[WRITFS-PRODUCT.md](../../../docs/WRITFS-PRODUCT.md) and the broader Genode
specification remain open unless their own native evidence is supplied.
