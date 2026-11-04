# Native Genode verification record

This record separates an executing native filesystem from the remaining corpus
and product gates. The initial lane is not a protected-data qualification.

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
| Historical 638-test core corpus | **PASS** inside native Genode, with zero tracked QuickJS allocations after interpreter teardown |
| All 69 mount model checks inside native Genode | **NOT YET PASSED**: a 180-second attempt and a later 600-second attempt timed out during the full corpus after the core checks completed |
| All 69 mount checks in host QuickJS | **PASS**, with the same 64 MiB engine limit and 512 KiB stack limit; about six seconds locally; this does not replace the guest gate |
| Integrated 764-test core corpus inside native Genode | **PENDING** the new lane; the workflow explicitly requires 764 after integration of concurrent upstream HostBinding tests |

The raw session and VFS results above use the final subtraction-based descriptor
guard and exact native name validation. Passing them establishes a native
filesystem service and native VFS integration for the public fixture. The
unfinished complete guest corpus remains a failing acceptance gate; no test is
skipped and no Linux-hosted substitute is accepted.

The public fixture is the 33-byte UTF-8/ASCII string
`Writ native Genode public canary` followed by LF. Bend computed its actual
SHA-256 as:

```text
4e69733490c465b5561bd477617265a72e614cbabb3ec570fcb1c1b54df32e6a
```

The service reported a peak of **2,013,426 tracked QuickJS allocation bytes**
while initializing this fixture. This metric includes the bridge's allocation
headers, but not libc slab rounding/caches or total component resident memory.
The separate native component RAM quota is 128 MiB.

## Evidence and source alignment

Local serial logs retained outside the checkout are named:

- `genode-native-filesystem-reviewed.log`: all three native client roles pass,
  ending with `WRIT GENODE FILE_SYSTEM ACCEPTED reader stranger forger`.
- `genode-native-vfs-reviewed.log`: the final guarded server with the libc
  consumer, ending with `WRIT GENODE LIBC VFS ACCEPTED`.
- `genode-native-corpus-final.log`: the historical 638 core passes, followed by
  the 600-second mount-corpus timeout. Preserve this failure as well as later
  results.

The historical generated scripts were checked byte-for-byte against their
embedded contents in that exact running native image before retaining them:

| Embedded generated artifact | SHA-256 |
| --- | --- |
| `core-tests.js`, historical 638 corpus | `63e06f1caee7ae094a0926be8c0b043d40c763d749b974a778b31c2535d627a8` |
| `mount-tests.mjs`, 69 assertions with balanced boundary-fixture construction | `cad0f40f0d8d5fea4ea3f9c90614f513aedb01ecfc7477736d2a0d06ce90abaf` |

The current workflow regenerates all scripts from its own checkout and records
the source, generated-script, executable, and ISO hashes. A later 764-corpus
result must identify that later source; the historical 638 result does not
cover the added HostBinding tests.

The local build host used downloaded Ubuntu tools in an unprivileged prefix.
The upstream libc, libm, and VFS ABI checks and HID syntax checks were executed
explicitly with the extracted Tcl interpreter because `/usr/bin/tclsh` was
absent. No guest or upstream runtime source was patched and no ABI check was
waived. The CI workflow installs Tcl normally and runs the upstream build checks
directly.

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
