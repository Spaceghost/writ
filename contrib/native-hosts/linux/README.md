# Native Linux WritFS canary

For writable public desktop files and downloadable Linux packages, see the
[separate public sync preview](public-sync/README.md). This document covers the
protected-reader canary contribution.

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

`--case policy-exit` serializes supervisor-requested policy termination with
in-flight FUSE reply attempts, marks the host fatal, and checks that existing
and new reads fail. Because the fatal flag is set deliberately, this case does
not demonstrate pipe-detected loss or an unsolicited interpreter death. The
separate nonprivileged transport probe kills its own policy child after a valid
request and checks actual pipe poisoning and retry denial; it is not mounted
host acceptance evidence. `--require-landlock 4294967294` is an
intentional setup-refusal probe; no canary is loaded or admitted. `--case hold`
and its private `--ready-file` are only for the external broker-crash test.

The nonprivileged callback interleaving test compiles the actual callbacks with
mocked FUSE, policy and OS boundaries. It does not mount or probe process identity:

```sh
make -C contrib/native-hosts/linux OUT="$WRIT_BUILD" "$WRIT_BUILD/handoff-order-test"
timeout 35 "$WRIT_BUILD/handoff-order-test"
```

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
| `writfs.c` | libfuse callbacks, sealed memfd ownership, native requester/lifetime mapping, serialized reader detachment, bounded event capture and canary orchestration |
| `policy_pipe.c`, `policy_pipe.h` | Private process/pipe setup, sanitized environment, canonical bounded replies, sequence checks, deadlines and teardown |
| `worker.c`, `worker.h` | Trusted launch prelude and fixed native escape/read/revocation probes; these do not decide Writ authority |
| `transport_probe.c` | Real C-to-Bend transport checks, owned policy-process loss and explicitly malformed test peers with no filesystem/data-serving route |
| `handoff-order-test.c` | Nonprivileged mocked scheduling and failure checks of the real callbacks and supervisor helpers; no native identity or mount claim |
| `channel-identity-test.c` | Unprivileged owned-process kernel test of `SCM_PIDFD` attribution across endpoint transfer and receive rejections ([record](../../../verification/linux-channel-identity/README.md)); no broker, mount or authority decision |
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

## Handoff ordering and teardown limits

A single FUSE loop thread handles callbacks while the supervisor can issue
REVOKE. An instance mutex now orders each protected callback's policy decision
and FUSE reply **attempt** before the supervisor can commit REVOKE; intentional
policy termination uses the same ordering. It does not recall a reply already
submitted to the kernel or establish when a client observed it. The fixed probe
worker waits for the supervisor before its post-revocation reads; the historical
VM record did not demonstrate an actual overlapping authorized read and REVOKE.
The new mock schedules that overlap without mounting FUSE.

This mutex is held across the FUSE reply attempt. A stalled reply can delay
revocation, POSIX mutex fairness gives no bounded progress guarantee, and the
change does not qualify teardown, crash recovery or spontaneous interpreter
death.

During cleanup, if the FUSE thread exists and the effect mutex is immediately
available, the supervisor detaches the entire reader record under that mutex,
invalidates the shared record, then retires the detached copy without the lock.
If the mutex is busy, cleanup marks the instance fatal and incomplete, requests
FUSE exit/unmount, checks join and retires the original record only afterward.
An in-flight callback that already passed the fatal check may still obtain a
later allowed policy decision and reply while shutdown proceeds; no completed
REVOKE is implied by this cleanup path. Unexpected trylock or unlock errors,
and failed join, immediately fail-stop without claiming resource cleanup.

Join success establishes only that the loop thread no longer uses the host; it
does not establish that the loop succeeded. The dedicated supervisor sets
SIGCHLD to its default before forking workers and is their sole reaper. A
retirement checks pidfd child ownership before signaling and reports signal,
wait and descriptor-close failures. Missing or unverified pidfds cause no
numeric-PID signal or wait; a failed signal uses a nonblocking wait. Each
descriptor is closed at most once, including after EINTR. Partial startup
leaves the child record to the caller for cleanup. A reported failure leaves
cleanup incomplete, even if another resource was subsequently retired.
When the child is still alive, waitid's zero-info response confirms a child
but not its numeric PID. The pidfd/PID pairing relies on the supervisor's
original fork and protected pidfd acquisition and its unmodified record; an
arbitrarily corrupted record is not independently authenticated here.
This does not check all pipe-close errors in pre-child launch failure paths,
policy-process teardown, or all other supervisor resource releases. The
SIGCHLD failure path is source-reviewed, not fault-injected. Lock acquisition,
unmount, join and a successful-signal retirement wait may block, and fail-stop
does not prove that children, pipes or mounts were cleaned up. No new native mounted acceptance, crash
recovery or protected-host qualification is claimed for the changed source.
