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
| Generated source ROM | At most 8 MiB per module/script (the generated core corpus passed 2 MiB at 1942 checks) |
| Tracked QuickJS reservations | 128 MiB (raised from 64 MiB when the 1942-check corpus passed a 60.7 MB peak), including retained cache capacity and private allocation headers |
| Large-allocation reuse | At most two free reservations per size class; all remain charged to the same 128 MiB limit |
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
records the requested length separately from its internal capacity and reports
only the requested range to QuickJS. Reallocation preserves that range; failed
growth leaves the original allocation and its bytes owned by the caller. Both
the engine's ordinary memory limit and the wrapper's aggregate reservation limit
remain active, as do stack checks.

The pinned [Genode heap](https://codeberg.org/genodelabs/genode/src/commit/d18ee9e917200b059549e21f2dd9a55bfe61a0eb/repos/base/src/lib/base/heap.cc)
gives allocations of at least 64 KiB their own RAM dataspaces. Releasing and remapping a dataspace for each generated substring
made the full boundary corpus exceed 600 seconds. The wrapper therefore reuses
large allocations in power-of-two size classes. It charges the entire reserved
capacity while a block is live or cached, keeps at most two free blocks per
class, and evicts the largest cached blocks first when another allocation needs
space. All cached reservations are released after interpreter teardown. Policy
code and the QuickJS engine are unchanged.

For these large reservations the wrapper budgets 32 bytes for the
[pinned libc's](https://codeberg.org/genodelabs/genode/src/commit/d18ee9e917200b059549e21f2dd9a55bfe61a0eb/repos/libports/src/lib/libc/malloc.cc)
16-byte metadata and at most 15-byte alignment padding, in addition to its own
aligned header. Smaller libc allocations still incur their own slab and native
metadata overhead. The reported `heap_peak` counts live reservation charges;
`reserved_peak` includes cached capacity as well. Neither metric is total
resident memory. The separate 128 MiB component RAM quota also remains enforced.
Zero live and reserved bytes after teardown do not establish memory erasure.
The wrapper assumes one serialized interpreter thread per component and must
not be reused as a shared allocator without synchronization.

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
WRIT_CORE_EXPECTED=2318 bash contrib/native-hosts/genode/build-and-run.sh /absolute/path/writfs-genode-build
```

The script first runs the allocator checks with host AddressSanitizer,
UndefinedBehaviorSanitizer, and leak detection. It verifies downloaded archives,
prepares the pinned Genode libc and GRUB ports, generates Bend artifacts, builds
native ELF components with the Genode toolchain, and executes three independent
base-hw x86_64 QEMU boots.
Software CPU emulation is explicit; KVM access is not required. Build products,
generated policy, sources, ISO images, configuration copies, and logs stay in
the chosen build directory. Use a fresh directory for a clean qualification
run; existing extracted input trees are developer build caches.

The required core assertion count is an explicit, reviewed build input. The
workflow pins it to 2318 for the current source; the [recorded 2065-check
guest run](../../../docs/superpowers/records/2026-11-05-linux-host/model-only-integration.md)
used source `73a8055`. The native probe requires
that exact number of successful assertions, the complete corpus summary, and a
single successful exit; it does not infer success from whatever output appears.

The CI lane fails on missing native dependencies, source/build errors, failed
assertions, and timeouts. It does not substitute a Linux-hosted Genode run or a
model-only result. The artifact retains environment versions, exact source and
build hashes, supervisor configurations, and serial logs.

## Acceptance probes

| QEMU boot | Native checks |
| --- | --- |
| `writ_policy` | The same 24 allocator invariant checks run by the host sanitizer probe; the generated core tests (2065 in the recorded `73a8055` guest run); all 69 pure mount checks, including the 64 KiB boundary; zero live and reserved QuickJS bytes after each interpreter teardown |
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

## Experimental nested channel fixture

The [nested R fixture](nested-channel/writ_bend_monitor_nested_accept.run)
places the existing fixed-label public channel probe under a second `init` and
expects the existing Bend monitor to commit the synthetic R request. The
label `clients -> writ_client_r -> channel` was observed in the public
[route-control retry](../../../verification/genode-route-retry-42361441863/README.md);
the paired missing-route control also matched, but both jobs remained incomplete
with in-guest cleanup unverified. The
[reviewed plan](../../../openspec/changes/add-genode-host/nested-routing-first-slice.md)
describes the routes, quotas, source pins, negative control and evidence still
needed. This is not a protected worker or a qualified host.

To prepare the tracked sources and generated Bend C without running Genode,
use a clean committed worktree and an absolute path to the pinned Bend 2.0.39
executable:

```sh
contrib/native-hosts/genode/nested-channel/prepare-overlay.sh \
  /tmp/writ-genode-nested-overlay.example /absolute/path/to/bend
```

The output must be a new direct `/tmp/writ-genode-nested-overlay.*` directory.
It contains the external `writ-repo` overlay, generated C, and source, overlay
and output hashes. The script clears inherited Git overrides, checks the Git
top level, observes a clean source tree, and checks the HEAD and source hashes
again after generation; these observations do not attest to
the process or exclude concurrent changes between checks. A failed preparation
is retained for inspection; remove only the caller's own output when finished.
The standalone `tclsh contrib/native-hosts/genode/nested-channel/check-structure.tcl sample` check and its
`wrong-label`, `wrong-byte` and `missing-exit` modes exercise the harness with
synthetic logged text, not Genode or a native negative control.

The fixed guarded [positive](nested-channel/writ_bend_monitor_nested_guarded_positive.run)
and [route-negative](nested-channel/writ_bend_monitor_nested_guarded_negative.run)
entry points wrap only `install_config` and compare its entire ASCII argument
with a separate fixed [positive](nested-channel/writ_guard_positive.args) or
[negative](nested-channel/writ_guard_negative.args) reference. The negative
[fixture](nested-channel/writ_bend_monitor_nested_route_negative.run) is copied
byte-for-byte from the archived route-control retry, including its bounded
same-spawn continuation waits. The wrapper refuses a mismatched argument before
the original installer; it does not parse policy, select a subject, alter the
shim or verify the installed/boot configuration. Each call is checked separately;
the wrapper does not enforce a call count or stop arbitrary Tcl from bypassing it.
The overlay preparer checks the recorded SHA-256 pins for both references and
the negative fixture, then records all source and overlay hashes. Those hashes
depend on the trusted reviewed checkout and staging process, not independent
actor authentication. Direct invocation without that preparer does not perform
its pin check.

The reference reader, overlay and Tcl interpreter are trusted. The 16 KiB read
and comparison caps do not bound file-open/read latency or defend against a
FIFO, symlink or concurrent same-UID path replacement. An independently bounded
outer supervisor is needed to bound a stall; the guard makes no no-follow,
atomic-delivery or verified-cleanup claim. No guarded Genode run has been made.
The offline controls below use stubs for build, image construction and launch;
they do not start Genode or QEMU:

```sh
tclsh contrib/native-hosts/genode/nested-channel/test-fixture-config-guard.tcl
python3 contrib/native-hosts/genode/nested-channel/test-fixture-config-references.py
```

These controls verify the actual boot helper's generated arguments, both fixed
entry points and selected mismatch/boundary/continuation cases. The reference
check compares the separate source files against fixed hashes and the archived
ZIP bytes; it never derives a new expected value from a guarded invocation.
See the [guard design](../../../openspec/changes/add-genode-host/public-fixture-config-guard-design.md)
for the remaining trust, process-lifetime and host qualification gaps.

For a future reviewed run, use fresh external Genode source and build trees,
the pinned toolchain and prepared libc, plus this overlay. Set the fresh
base-linux build's repository list to include the overlay, `base`, `libports`
and `gems`; set `BOARD` and `KERNEL` to `linux`, the toolchain prefix and a
bounded make parallelism, and add `writ_bend_monitor_nested_accept` to the
existing local-expect run rule from `scripts/genode/writ_hello/build.conf.fragment`.
That fragment's shared paths and `-j16` are not suitable. Keep the generated C
beside the overlay as prepared so the monitor target can find it; preserve the
actual build/run commands, input hashes, logs and separate failing native
negative control. The pinned Genode run tool can retry and its base-linux
power-off fallback does not itself prove that descendants have exited. Before
running, review a supervisor that creates and records a process group owned by
that invocation, captures retries and cleanup status, and verifies retirement
of that group's descendants on success, error and timeout. A bare process group
cannot prove that escaped descendants are gone, and observed parent cgroup
writability does not rule out migration. The [PID-namespace alternative](nested-channel/PID-NAMESPACE-DESIGN.md)
is an unimplemented design with a separate synthetic test plan. The read-only
`supervisor-preflight.py` probe accepts no workload and always reports incomplete.
Report any run incomplete if cleanup cannot be verified. Never use global `core`
or QEMU kills, overwrite shared caches or touch unrelated VMs.
The helper's broad default route and diagnostic LOG remain present; the fixed
client cannot vary its suffix, and this fixture establishes neither
confinement nor original caller identity. Conflicting equally scored policies
are not rejected by the existing shim; trusted configuration must avoid them.

## Source and trust inventory

| Source | Responsibility and authority |
| --- | --- |
| `src/server/writfs/main.cc` | Native filesystem ABI, private immutable bytes, session/handle ownership, native resource bounds, exact trusted supervisor binding, and execution of Bend-admitted effects |
| `include/writfs/control.h` | Native administrative revoke-only RPC ABI; no grant or arbitrary command method |
| `../runtime/genode/policy.{h,cc}` | Native QuickJS lifetime and limits, unchanged generated export invocation, private state retention, strict reply validation, permanent failure state |
| `../runtime/genode/quickjs_alloc.{h,c}` and `malloc_np.h` | Missing libc allocator-size adaptation, bounded reservation reuse, and aggregate reservation accounting |
| `lib/mk/writ_quickjs.mk` | Cross-builds the verified upstream engine without its OS binding library; allocator name substitutions only |
| `src/test/writ_policy/` and `../runtime/genode/core_checks.cc` | Native corpus probes and separate diagnostic-only test adapter |
| `../runtime/genode/allocator_checks.{h,c}` and `allocator_probe.c` | Shared native/host allocator checks and the host sanitizer entry point; no service authority |
| `src/test/writfs/`, `src/test/writfs_vfs/` | Native diagnostic clients; never a protected worker profile |
| `run/` | Trusted supervisor topology, fixed public fixture, explicit ROM/service routes, and native completion gates |
| `nested-channel/` | Experimental trusted nested-init topology, source staging, public fixture assertions and exact-argument guard; fixed reference reads rely on the trusted checkout/overlay and bounded outer supervision. No policy, host qualification or identity attestation |
| `build-and-run.sh`, workflow | Pinned inputs, cross-build packaging, fresh generated Bend artifacts, QEMU execution and evidence |

Authorization, original policy/provenance, grant checking, state transitions,
accounting, revision/handle semantics, and release decisions remain in Bend.
