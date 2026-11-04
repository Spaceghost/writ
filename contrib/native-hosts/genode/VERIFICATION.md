# Native Genode verification record

This record separates the executing native filesystem and passing native corpus
from the remaining product gates. The public-canary lane is not a protected-data
qualification.

## Observed locally on 2026-11-04

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

The final timed guest reported **5,288 ms** for the 764 core assertions and
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

## Evidence and source alignment

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

The current workflow regenerates all scripts from its own checkout and records
the source, generated-script, executable, and ISO hashes. The results above are
local native execution evidence; CI results must identify their own commit and
retained artifact rather than inheriting these local results.

The local build host used downloaded Ubuntu tools in an unprivileged prefix.
The upstream libc, libm, and VFS ABI checks and HID syntax checks were executed
explicitly with the extracted Tcl interpreter because `/usr/bin/tclsh` was
absent. No guest or upstream runtime source was patched and no ABI check was
waived. The CI workflow installs Tcl normally and runs the upstream build checks
directly.

## Preserved failed attempts

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
