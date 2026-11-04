# Bend runtime as a Genode component: design

## Context

Today `bend Tests.bend -o tests-native` produces a Linux executable. Genode
components are built by Genode's build system against its libc and base
libraries, and they talk to other components through typed session RPC. The
runtime surface the generated C needs is known (BEND-RUNTIME.md); what Genode's
libc provides for each row has not been checked against the pinned 26.08 source.
Older community reports describe signal support as rudimentary, which matters
because the runtime installs `SIGSEGV`/`SIGBUS` handlers on an alternate stack.

## Decisions

### Compile the generated C inside Genode's build, do not load a Linux ELF

The generated C file is the component's source. It is compiled with Genode's
toolchain against Genode's libc, not run through a Linux-ABI compatibility
layer. This keeps the runtime's host calls on Genode's own implementations and
makes every missing primitive a link or startup failure rather than a silent
emulation.
GCC 14.2 lacks statement-level `musttail`, so the generated translation unit
is compiled with a pinned clang while linking, `ld.lib.so`, and libc stay on
the Genode toolchain; this stays open until Genode moves to GCC 15 or later.

### Satisfy the runtime profile row by row, with the profile's substitutes

For each row of the runtime inventory the port records one of: supplied by
Genode's libc; supplied by a profile substitute; or missing. Expected outcomes
to verify, not assumptions: threads through libc pthreads; anonymous memory
through libc `mmap` backed by RAM dataspaces; monotonic time through the Timer
session; the self-pipe through libc `pipe` and `select`. The fault path is the
likely gap: if libc signal delivery cannot reach the runtime's handler, the
component uses the profile's halting substitute, where a page fault reported to
the parent terminates the component and the supervisor records it. Resuming
after a fault is never an option.

### Effects are Bend defs with C twins calling one shim

Three effect families are authored in Bend:

| Effect | C twin calls | Genode session |
| --- | --- | --- |
| `Genode.log(text)` | `writ_shim_log` | LOG |
| `Genode.now()`, `Genode.sleep(ms)` | `writ_shim_now_ms`, `writ_shim_sleep_ms` | Timer |
| `Genode.take()` | `writ_shim_take`, which blocks on an `io_work` helper thread until a request is queued | Writ channel: the client's request bucket |
| `Genode.put(channel_id, record)` | `writ_shim_put` | Writ channel: the client's result bucket |

The shim is one C++ translation unit exporting `extern "C"` functions. It owns
the Genode environment, the channel objects, and a bounded request queue. It
contains no policy: a request record is delivered to Bend as an opaque, bounded
term with the authenticated channel identity the parent route established, and
Bend decides. The shim's source, size, and reviewed obligations are listed in
the trust inventory that AGENTS.md requires for authored binding code.

### Writ is data-centric above the kernel: channels, not procedure calls

Genode's kernel-level mechanism is RPC objects, dataspaces, and signals, and
nothing above it can avoid using them as the transport. What Writ exposes on
top is not a procedure interface. A **Writ channel** is a pair of bounded,
typed buckets the monitor owns for one descriptor: a request bucket the client
writes a record into and a result bucket the client reads. Each bucket is a RAM
dataspace holding one record slot that the next record overwrites; Genode RAM
dataspaces have no read-only capability, so the client can map both writable,
and the shim copies the request once at take and never reads the result
bucket. A Genode signal tells the other party that a record landed. The Genode
object behind the channel exists for identity and lifetime (GB-010); it has no
method surface beyond "attach these dataspaces, deliver this signal."

This matches the rest of Writ: WritFS already frames interaction as names,
views, jobs, and framed control records, and transfer admission is a decision
over records. A client does not call `commit`; it writes a request record that
names an exact plan, and later reads a result record that carries a decision
and a write intent or a denial reason. "Search atop, not RPC below": clients
query buckets and views; the monitor materializes.

### The channel is served from the event loop

Bend's loop runs effects one at a time and parks blocking ones. `Genode.take`
runs `writ_shim_take` on a runtime `io_work` helper thread, which blocks on the
shim's semaphore until a client's request signal has queued an entry; the
runtime's own completion pipe then wakes the loop (the libc wakeup the event
loop already uses). The shim serves the sessions and signals on its own
entrypoint, because libc keeps the main entrypoint for I/O signals while Bend
waits. The monitor's `main` is a
fuel-bounded loop: take, decide through `DataOS`, put. One record is processed
at a time, which is what the backplane's "one authoritative state at commit"
rule requires anyway. A record larger than the bucket's bound is never copied
into Bend; the shim counts it and the client sees a bounded-size denial record.

### base-linux first, base-hw second, and evidence stays separate

`base-linux` gives fast iteration with Genode's socket-based capabilities and
seccomp. `base-hw` under QEMU is the native reference. The corpus must pass on
both, recorded separately, before the Writ session is served on either. No
GPU: `!` calls run on the CPU pool and are recorded as such.

### What this change does not do

It does not create the worker topology, seal artifacts, confine effects, or
prove revocation. Those are the Genode host change's own tasks 1.4 through 2.4.
It makes the monitor exist and speak.

## Failure and denial behavior

A missing libc primitive fails the build or startup. A corpus mismatch fails
qualification for that base. A fault terminates the component and is recorded
by the supervisor; the monitor is restarted with a new generation per the host
contract. A request that exceeds the shim's bound is dropped before parsing,
counted, and answered with the shim's fixed transport refusal record. An alien effect halts, as on Linux.

## Evidence before claiming implementation

- Genode commit, toolchain, run script, and component build hashes pinned.
- Per-row runtime profile outcome table for `base-linux` and `base-hw`.
- Corpus and example output captured from each base's log.
- The shim's trust inventory: file list, exported functions, line count,
  reviewer, and the sessions it may open.
- A served request round trip on each base, with a forged-identity request
  shown denied by Bend, not by the shim.
