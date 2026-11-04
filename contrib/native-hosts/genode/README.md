# Native Genode WritFS contribution

A Genode program can mount this `File_system` service through the ordinary VFS
`fs` plugin and read `/writ/data` with libc `open`, `read`, `lseek`, and `fstat`.
The service asks the shared Bend monitor before opening or reading the immutable
public canary. A separately routed administrative session revokes the admitted
invocation; retained file handles then return no additional bytes.

This is a bounded, read-only public-canary bring-up. It supplies a native Genode
filesystem session service and VFS integration. It does not implement a Btrfs or
ZFS block driver, a durable filesystem, or a qualified protected-data worker.
The diagnostic test clients deliberately have `LOG` capabilities. See the
[product acceptance requirements](../../../docs/WRITFS-PRODUCT.md) for the
separate confidentiality, delegation, attribution, and recovery obligations.

## Architecture

`src/server/writfs/main.cc` implements Genode's native `File_system` RPC and
packet-stream interfaces. It exposes only `/` and `/data`, rejects mutations,
keeps native handles local to their session, and copies only the number of bytes
admitted by Bend. Directory entries have initialized padding. A rejected packet
returns zero bytes and does not overwrite the client's payload buffer.

The policy source is [Mount.bend](../../../writfs/Mount.bend), including its full
authority facade, retained committed state, and immutable payload hash. It is
compiled with Bend 2.0.39 to `mount.mjs` outside the checkout. Native QuickJS
executes that generated module inside the Genode service. The service retains
the opaque state and commits `next(step)` before accepting `reply(step)`. Clients
cannot supply state, actor slots, grants, or arbitrary interpreter requests.
The mechanical bridge follows [PROTOCOL.md](../PROTOCOL.md).

The service copies the configured canary ROM into private memory once, then
submits those exact bytes to Bend's `INIT` operation. Bend computes SHA-256 from
the actual input. The ROM route belongs to the server; the client routes expose
only their executable and required runtime libraries.

The trusted supervisor pins the reader component's executable and route. The
first session with the exact parent-supplied label `reader -> /` binds actor slot
1 and triggers Bend's `ADMIT public-canary` gate. Every other session uses slot
0. A client-supplied suffix `reader -> /` under the `forger` component becomes a
different full label and cannot match. The admitted native session object is
retained for its lifetime. A second session, a closed session, or a restarted
component cannot inherit the invocation. Session destruction closes its handles
and revokes admission.

The `Writ_control` capability exposes only revocation and has its own exact
supervisor route. It is not a generic dispatch endpoint. The raw test reader
receives this diagnostic capability to test revocation; the VFS consumer does
not receive it.

These bindings establish a component/session association in the supplied
supervisor topology. A label alone is not a human identity. General capability
delegation, confused deputies, worker memory isolation against every authorized
peer, indirect output channels, and restart recovery need separate native
qualification. Revocation blocks subsequent service effects; it cannot erase
bytes already observed by a client.

## Runtime boundary and bounds

The pinned Bend native C runtime needs guarded sparse virtual-memory regions
that Genode's libc does not implement. This contribution therefore executes
the unchanged generated JavaScript with a native QuickJS engine. It does not
disable Bend C stack guards, emulate unsupported `mprotect` success, or claim
to be a general Bend C runtime port.

| Resource | Enforced bound |
| --- | --- |
| Registered immutable payload | 65,536 bytes |
| Root objects | One file named `data` |
| Live native filesystem sessions | Four |
| Admitted invocation | One, bound once per service boot |
| Live handles | 32, with Bend identities never reused |
| Session packet buffer | 4,096–131,072 bytes |
| Individual native read | At most 65,536 bytes, checked before U32 conversion |
| Packet processing | At most one protocol queue batch per dispatch |
| Generated source ROM | At most 2 MiB per module/script |
| Tracked QuickJS allocations | 64 MiB of requested bytes plus private allocation headers |
| QuickJS stack limit | 512 KiB; stack checking remains enabled |
| Component stack | 768 KiB, leaving the native stack slot's guard and metadata intact |
| Service/test component RAM quota | 128 MiB in the supplied supervisor configs |
| Interpreter call budget | 200,000 QuickJS interrupt callbacks per call |
| Reply | Exact protocol fields and sequence, at most 256 bytes |

The interrupt count is a finite VM work budget, not a wall-clock guarantee.
The QEMU harness separately imposes native test deadlines. Any interpreter
exception, invalid reply, sequence mismatch, or reentrant policy call makes the
bridge permanently unhealthy; later requests fail closed.

Genode libc does not expose `malloc_usable_size`. The narrow allocator wrapper
records each allocation's exact size in an aligned header, maintains the hard
aggregate limit, and supplies QuickJS's normal accounting. The engine's own
memory and stack checks remain active. The wrapper assumes one serialized
interpreter thread per component and must not be reused as a shared allocator
without synchronization.

Reported `heap_peak` and `heap_live` count those tracked allocations. They do
not measure libc's slab rounding, allocator caches, or the component's total
resident memory. The supervisor's separate 128 MiB RAM quota bounds the native
component; a zero tracked count after teardown is not a claim of memory erasure.

No QuickJS OS module, module loader, filesystem API, socket API, or process API
is installed in the service's interpreter. The core-corpus probe uses a separate
interpreter with a small ASCII diagnostic adapter for the existing generated
`Tests.bend` script. That adapter cannot open files or create processes and is
not linked into the filesystem service.

## Build and run

Use an x86_64 Ubuntu 24.04 build host with the same dependencies as
[the native Genode workflow](../../../.github/workflows/writfs-genode-native.yml):

```sh
sudo apt-get install --yes --no-install-recommends \
  build-essential libfl2 libncurses-dev libgmp10 libzstd1 \
  flex bison patch expect tcl xorriso qemu-system-x86 \
  curl xz-utils unzip rsync

# Put the verified Bend 2.0.39 compiler on PATH first.
WRIT_CORE_EXPECTED=764 bash contrib/native-hosts/genode/build-and-run.sh /absolute/path/writfs-genode-build
```

The script verifies downloaded archives, prepares the pinned Genode libc and
GRUB ports, generates Bend artifacts, builds native ELF components with the
Genode toolchain, and executes three independent base-hw x86_64 QEMU boots.
Software CPU emulation is explicit; KVM access is not required. Build products,
generated policy, sources, ISO images, configuration copies, and logs stay in
the chosen build directory. Use a fresh directory for a clean qualification
run; existing extracted input trees are developer build caches.

The required core assertion count is an explicit, reviewed build input. The
workflow pins it to 764 for the integrated source. The native probe requires
that exact number of successful assertions, the complete corpus summary, and a
single successful exit; it does not infer success from whatever output appears.

The CI lane fails on missing native dependencies, source/build errors, failed
assertions, and timeouts. It does not substitute a Linux-hosted Genode run or a
model-only result. The artifact retains environment versions, exact source and
build hashes, supervisor configurations, and serial logs.

## Acceptance probes

| QEMU boot | Native checks |
| --- | --- |
| `writ_policy` | The unchanged generated core tests (764 in the current workflow); all 69 pure mount checks, including the 64 KiB boundary; zero retained QuickJS allocation bytes after each interpreter teardown |
| `writfs` | Actual filesystem RPCs and packet streams; exact contents and ranges; directory metadata; EOF; write, traversal, and malformed-name denial; malformed lengths, negative/overflowing shared-memory descriptors, and oversized file offsets; stat-only, closed, and foreign-session handles; 32-handle exhaustion; unadmitted components; forged label suffix; denied direct ROM/admin routes; revocation of retained handles |
| `writfs_vfs` | A separate native libc consumer mounting the service through VFS; `open`, full/ranged `read`, `lseek`, `fstat`, rejected write-open, rejected unknown object, and `close` |

See [VERIFICATION.md](VERIFICATION.md) for observed results and explicit gaps.
The broader Genode specification is not completed by these public-canary probes.

## Pinned sources

| Dependency | Pin and archive SHA-256 |
| --- | --- |
| Genode | 26.08, commit `d18ee9e917200b059549e21f2dd9a55bfe61a0eb`; `df74f96c70c72607d66f5440439680b63683f09edd92809996845f0f29453a74` |
| Genode compiler | Official 25.05 Ubuntu 24.04 archive, GCC 14.2.0; `6cab8e5f4490399a296a73b01695d5fb055a40f6ac04d61a3f7a7344003eb739` |
| QuickJS | 2026-06-04; `b376e839b322978313d929fd20663b11ba58b75df5a46c126dd19ea2fa70ad2a` |
| Bend | 2.0.39 Linux x64; `6cf462fd8f70b094a4950ebb709a9c4ffd8f1d1189d9cedf1fd63cd5d041c7ab` |

Upstream sources: [Genode 26.08](https://codeberg.org/genodelabs/genode/src/commit/d18ee9e917200b059549e21f2dd9a55bfe61a0eb),
[official compiler instructions](https://genode.org/download/tool-chain),
[QuickJS source and license](https://bellard.org/quickjs/), and
[QuickJS embedding API](https://bellard.org/quickjs/quickjs.html).
Genode's own source includes AGPLv3 components and separately licensed ports;
QuickJS is MIT-licensed. Those upstream licenses are not replaced by this binding.

## Source and trust inventory

| Source | Responsibility and authority |
| --- | --- |
| `src/server/writfs/main.cc` | Native filesystem ABI, private immutable bytes, session/handle ownership, native resource bounds, exact trusted supervisor binding, and execution of Bend-admitted effects |
| `include/writfs/control.h` | Native administrative revoke-only RPC ABI; no grant or arbitrary command method |
| `../runtime/genode/policy.{h,cc}` | Native QuickJS lifetime and limits, unchanged generated export invocation, private state retention, strict reply validation, permanent failure state |
| `../runtime/genode/quickjs_alloc.{h,c}` and `malloc_np.h` | Missing libc allocator-size adaptation and an exact aggregate memory bound |
| `lib/mk/writ_quickjs.mk` | Cross-builds the verified upstream engine without its OS binding library; allocator name substitutions only |
| `src/test/writ_policy/` and `../runtime/genode/core_checks.cc` | Native corpus probes and separate diagnostic-only test adapter |
| `src/test/writfs/`, `src/test/writfs_vfs/` | Native diagnostic clients; never a protected worker profile |
| `run/` | Trusted supervisor topology, fixed public fixture, explicit ROM/service routes, and native completion gates |
| `build-and-run.sh`, workflow | Pinned inputs, cross-build packaging, fresh generated Bend artifacts, QEMU execution and evidence |

Authorization, original policy/provenance, grant checking, state transitions,
accounting, revision/handle semantics, and release decisions remain in Bend.
