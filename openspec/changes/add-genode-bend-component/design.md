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
| `Genode.now()`, `Genode.sleep(ms)` | `writ_shim_now`, `writ_shim_sleep` | Timer |
| `Genode.accept()` | parks on a signal, then `writ_shim_take_request` | Writ session (server side) |
| `Genode.answer(request_id, reply)` | `writ_shim_reply` | Writ session |

The shim is one C++ translation unit exporting `extern "C"` functions. It owns
the Genode environment, the session objects, and a bounded request queue. It
contains no policy: a request is delivered to Bend as an opaque, bounded term
with the authenticated session identity the parent route established, and Bend
decides. The shim's source, size, and reviewed obligations are listed in the
trust inventory that AGENTS.md requires for authored binding code.

### The Writ session is served from the event loop

Bend's loop runs effects one at a time and parks blocking ones. `Genode.accept`
parks with the runtime's wait mechanism on a descriptor the shim signals when a
request arrives (on `base-linux`, a pipe; on `base-hw`, the shim's signal
receiver bridged to the libc wakeup). The monitor's `main` is a fuel-bounded
loop: accept, decide through `DataOS`, answer. One request is processed at a
time, which is what the backplane's "one authoritative state at commit" rule
requires anyway.

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
contract. A request that exceeds the shim's bound is dropped before parsing and
counted. An alien effect halts, as on Linux.

## Evidence before claiming implementation

- Genode commit, toolchain, run script, and component build hashes pinned.
- Per-row runtime profile outcome table for `base-linux` and `base-hw`.
- Corpus and example output captured from each base's log.
- The shim's trust inventory: file list, exported functions, line count,
  reviewer, and the sessions it may open.
- A served request round trip on each base, with a forged-identity request
  shown denied by Bend, not by the shim.
