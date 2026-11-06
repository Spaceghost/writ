# Native Linux WritFS canary

Mount one frozen object as `data`, let its admitted worker read it, and refuse
another process using the same Unix account. Revoke the object and test both the
original descriptor and a duplicate. This contribution implements that real
Linux/FUSE boundary with the shared Bend policy. It is a **public-canary
bring-up profile**, not an installed protected-data service or an external grant
issuer. Native acceptance is recorded separately from compilation/model tests.

The [native execution record](verification/README.md) captures the passing
Linux VM run, exact sources, observed controls, and earlier failures.

## What runs

`writfs-linux` owns the FUSE connection, sealed memory file, child lifetimes,
native handle table and two private pipes to the generated Bend interpreter.
The interpreter executes the complete capability-to-commit gate at admission,
retains the committed state, and decides later observations through
[WRITFS1](../PROTOCOL.md). The C adapter does not recreate those decisions.

The only file is read-only `data`, containing 1–65536 bytes from an explicit
`--public-fixture`. The input is read once, copied into a memfd, sealed against
write/growth/shrink, and read back for Bend's SHA-256 initialization. Native
callbacks serve only that retained sealed descriptor. The original path is
never used during a read. This freezes the bytes collected by the broker; it
does not assert an atomic source-file version while another writer changes it.

This presentation can live alongside the existing
[Btrfs/ZFS staging backend](../../../writfs/README.md). It does not yet expose
an entire cloned dataset, invent a disk format, or implement the proposed
WritFS data/view/job namespace.

## The bounded native profile

| Boundary | Implemented behavior |
| --- | --- |
| Request identity | Kernel FUSE UID/GID/PID must match the broker's launched reader, retained pidfd, and full `/proc/PID/stat` start time. Only that lifetime maps to actor slot 1. Unknown callers map to slot 0. |
| Data and metadata | Data lookup, stat, listing, open and read call Bend. Fixed public mount-root structure is the only metadata available without admission. Directory/attribute caches have zero lifetime; file opens use direct I/O. |
| Native handles | At most 32 live handles. Bend handle numbers are monotone and are never reused. Every read rechecks the native lifetime and Bend state. Release uses the retained binding as resource cleanup, including after revocation. |
| Worker setup | Dedicated non-root UID/GID; empty supplementary groups and capabilities; private mount, network, IPC and UTS namespaces; chroot containing only the mounted view; `no_new_privs`; nondumpable process; resource limits and parent-death termination. |
| Effects | Landlock ABI 3 or newer with all filesystem rights through `TRUNCATE` handled, read-only access inside the chroot, and an x86_64-checked syscall allowlist. Network/socket creation, fork/exec, tracing, shared memory, `io_uring`, mapping, ioctl and descriptor transfer are denied. |
| Output and failure | Only private command/result pipes survive in the worker. Native result bytes are bounded, compared privately, and never dumped to the log. Policy framing errors/timeouts stop serving; no automatic interpreter restart or replay occurs. |

Both test children are forked **before** the source is loaded or Bend authority
is created. Otherwise the fork itself would deliver a copy of broker memory
before admission. Their environment bytes are cleared, standard streams and
all unlisted descriptors are closed, and the full worker profile is installed
before the first input request. The second child deliberately remains outside
that profile, under the same UID/GID, to exercise foreign-caller rejection and
same-user tracing denial. Foreign opens, stat and listing are repeated after the
admitted reader has populated the filesystem's lookup/attribute paths; the tests
require actual kernel-derived actor-0 denial events from Bend.

The worker runs a pinned native probe in the same executable, not an arbitrary
application. Its limits are 128 MiB address space, five CPU seconds, 16 FDs,
zero core/file-output/process-creation allowance, and a bounded command wait.
The trusted Node policy process has a 256 MiB JavaScript heap limit; requests
have 15-second deadlines. These are distinct bounds: the JavaScript heap limit
is not a whole-process RSS or kernel-memory limit.

Linux direct I/O bypasses the FUSE page cache and read-ahead; shared mmap is
disabled unless explicitly enabled. This adapter does not enable that option,
and its worker additionally cannot issue mmap. Revocation denies subsequent
mediated reads, including through a retained duplicate. It cannot erase bytes
already observed. See the [kernel FUSE I/O documentation](https://docs.kernel.org/filesystems/fuse/fuse-io.html).

## Build and exercise

The initial target is Linux x86_64 with libfuse 3.14+, glibc 2.34+ (for the
private spawn/FD setup), Node 22.23.4, and Bend 2.0.39. Native Bend test executables
use clang 19. Generated JavaScript and binaries stay outside the checkout.

```sh
export BEND_NO_TELEMETRY=1
export WRIT_BUILD=/absolute/path/outside/writ
mkdir -p "$WRIT_BUILD"
bend writfs/Mount.bend -o "$WRIT_BUILD/mount.mjs"
make -C contrib/native-hosts/linux OUT="$WRIT_BUILD"
"$WRIT_BUILD/transport-probe" /absolute/path/to/node \
  "$PWD/contrib/native-hosts/runtime/node-policy.mjs" "$WRIT_BUILD/mount.mjs"
```

Use a disposable native Linux VM for the privileged launch tests. A container
without `/dev/fuse`, the necessary privileges, namespaces, Landlock or seccomp
must fail; there is no weaker fallback. Create a dedicated test user and an
operator-owned, empty work directory with traversable ancestors. The work
directory, interpreter files, binaries and ancestors are trusted configuration.
Do not point this experimental root launcher at paths maintained by an adversary.

Run as root, substituting that test account's numeric UID/GID:

```sh
"$WRIT_BUILD/writfs-linux" \
  --node /absolute/path/to/node \
  --bridge /absolute/path/to/writ/contrib/native-hosts/runtime/node-policy.mjs \
  --module "$WRIT_BUILD/mount.mjs" \
  --public-fixture /absolute/path/to/public-canary.bin \
  --work-dir /tmp/root-owned-writfs-test \
  --uid 12345 --gid 12345 --case revoke
```

`--case policy-exit` kills the policy interpreter after a successful read and
checks that existing and new reads fail. `--require-landlock 4294967294` is an
intentional setup-refusal probe; no canary is loaded or admitted. `--case hold`
and its private `--ready-file` are only for the external broker-crash test.

`crash-probe HOST NODE BRIDGE MODULE PUBLIC-FIXTURE WORK-DIR UID GID` starts the
real harness, pins its child lifetimes with pidfds, kills the broker after a
successful mounted read, checks worker/policy termination and `ENOTCONN`, and
unmounts only the newly created recorded fixture. Readiness is published
atomically. It does not signal processes identified by an ambiguous stale record.

The [native CI lane](../../../.github/workflows/writfs-linux-native.yml) runs
these tests on an Ubuntu VM, alongside shared Bend vectors, native transport
failure probes, both CPU core suites, and ordinary proof checks. It records the
actual kernel, library/runtime versions, source hashes and failed outcomes.

## Native source and trust inventory

| File | Responsibility |
| --- | --- |
| `writfs.c` | libfuse callbacks, sealed memfd ownership, native requester/lifetime mapping, bounded event capture and canary orchestration |
| `policy_pipe.c`, `policy_pipe.h` | Private process/pipe setup, sanitized environment, canonical bounded replies, sequence checks, deadlines and teardown |
| `worker.c`, `worker.h` | Trusted launch prelude and fixed native escape/read/revocation probes; these do not decide Writ authority |
| `transport_probe.c` | Real C-to-Bend transport checks and explicitly malformed test peers with no filesystem/data-serving route |
| `crash_probe.c`, `Makefile` | Native lifecycle probe and build glue |

Host events record the observed kernel identity, actor match, operation, handle,
status and fixed reason code. They contain no raw filename or payload. Their
in-memory queue is bounded at 256 entries; exhaustion stops serving bytes.
**The journal is not durable** and broker crash can lose events. A denial under
a process context is evidence of that operation, not a finding of human intent.

The current profile does not qualify general applications, external grant
issuance, multi-user authorization, durable publication/recovery, persistent
audit, host-wide DLP, or hostile-administrator/kernel resistance. UID/PID values
are local observations, never portable credentials. Physical GPU execution,
musl/Alpine runtime compatibility and other CPU architectures are unverified.
These gaps remain in the broader host specifications.

Primary interface references: [libfuse low-level API](https://libfuse.github.io/doxygen/structfuse__lowlevel__ops.html),
[Landlock](https://docs.kernel.org/userspace-api/landlock.html),
[seccomp filtering](https://docs.kernel.org/userspace-api/seccomp_filter.html),
and [`no_new_privs`](https://docs.kernel.org/userspace-api/no_new_privs.html).


## Separate experimental protected-worker broker

The [direct Linux host proposal](../../../openspec/changes/add-linux-host/specs/linux-host/spec.md)
needs a protected worker whose identity is bound to an authenticated process
lifetime. The following sources are unfinished work towards that proposal;
they are separate from the public WritFS/FUSE canary above. They have no
qualified end-to-end broker, completed identity probe or confinement evidence.
The existing canary's build commands and recorded native results do not test
these files. Linux host tasks 1.1–1.4 remain unchecked.

| File | WIP role and trust boundary |
| --- | --- |
| `broker.c`, `broker.h` | Private monitor-pipe setup and bounded `LINUXB` encoding; Unix socket and ancillary-message helpers obtain candidate kernel observations and close received rights. The broker must remain trusted to attribute facts correctly and execute only monitor-admitted effects. The helper layer is not a complete server or authentication proof. |
| `launch.c`, `launch.h` | Launch-record and process-lifetime helpers use `clone3`, pidfds, `/proc` start times, optional user/PID namespaces, capability removal and an FD allowlist. They are incomplete launcher scaffolding, not a full confinement profile or evidence that setup, identity and cleanup are secure. |
| `broker_monitor.mjs` | Small private-pipe Node harness converts bounded hex input to bytes, invokes generated `LinuxHost` functions, retains the returned state and frames replies. The monitor remains authoritative; a worker must not inherit the harness or its pipe ends. |

These helpers depend on Linux `clone3`/pidfd and socket credential interfaces,
procfs mounted in the appropriate PID namespace, and a configured Node runtime
and generated Bend module. Required kernel, headers, runtime, configuration,
and authority assumptions are not yet pinned as a protected-host profile.
The launcher holds the child pidfd in its launch record until its caller reaps
it. Broker monitor setup owns its process and pipes; a communication failure
marks it unavailable and signals the child, while the stop helper closes the
pipes and reaps it. The receive helper handles received ancillary descriptors.
These ownership and failure paths still need native review and evidence.

In particular, the launcher currently returns failure if its start-time
observation is zero, but source review found it writes the child release byte
before that return. Failed-setup execution and cleanup have not been tested.
The Node harness uses a request sequence as its monitor clock; whether that is
a valid trusted time source for a host profile remains unresolved. The monitor
compares the launch and peer credentials supplied in one broker frame; it does
not authenticate those facts or retain the native lifetime binding. The
recorded session generation is not yet framed. These limits are described in
the [synthetic identity report](../../../docs/superpowers/records/2026-11-05-linux-host/task-2-synthetic-report.md).

Native identity, endpoint transfer, pid reuse, descriptor handling, full
confinement, concurrent lifetime, setup failure and recovery require real-host
adversarial tests before any protected-host claim. Model tests, source presence
and the separate WritFS canary results do not close those gaps.
