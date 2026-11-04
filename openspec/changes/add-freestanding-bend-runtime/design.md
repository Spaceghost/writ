# Freestanding Bend runtime design

## Context

`bend Tests.bend -o tests` produces a C file whose lower half is the Bend
runtime: a term heap, a flat state-machine evaluator, a fork-join lane pool,
an effect table, and an event loop. On Linux that file links against libc and
pthreads. The Drift kernel route has neither. The concrete target for a first
port is a QEMU x86 machine booted from a Multiboot image, which is what Drift's
`examples/kernel` already does for its drivers.

Current gap: no host layer exists, Drift's reference kernel is 32-bit, and the
runtime is written for 64-bit hosts. On this machine Drift's own kernel check
builds with GCC 16.2.1 and stops under QEMU 11.1.2 after printing its banner
([docs/BEND-RUNTIME.md](../../../docs/BEND-RUNTIME.md)). That failure belongs to
Drift's reference kernel on this toolchain and is recorded, not resolved, here.

## Decisions

### The evaluator and effect table are not modified

The port adds a host layer beneath the generated file. It does not edit the
evaluator, the scheduler, or the effect dispatch. Where the generated file calls
a libc function, the host layer provides that symbol. If a future Bend version
makes this impossible, the change is re-planned; forking the runtime is out of
scope because it would make the freestanding monitor compute with code that no
other target runs.

### The host layer may be nelibc

Spaceghost is building **nelibc**, a small Nelua-authored libc. It is a
candidate for the host layer's libc subset: the generated runtime needs only
the memory, fault, thread, clock, environment, and exit symbols the profile
lists, and a libc whose C is generated from Nelua under the Drift pattern (an
explicit external dependency, no Nelua runtime, no allocator of its own) fits
the trust model better than a general-purpose libc. The selection task compares
nelibc against a hand-written minimal host layer on exactly those symbols and
records which rows each supplies. Either way the evaluator is not modified.

### 64-bit first

The Bend term is one 64-bit word with pointers stored inline, and the runtime
assumes 64-bit pointers and atomics. The first port targets x86_64 long mode
with identity-mapped memory. A 32-bit build is not attempted; Drift's 32-bit
reference kernel is used as the pattern for boot, serial, PCI, and clock code,
not as the binary the runtime links into.

### Single lane first, kernel threads later

The runtime's `--threads 1` mode needs no additional lanes. The first port runs
one lane and one IO helper executed inline, which removes pthreads entirely. The
runtime profile requires decision parity between one lane and many, so this
loses no authorization behavior. A later step adds kernel threads behind the
same pthread-shaped symbols once the Drift kernel host has a scheduler.

### Memory is a fixed arena with a guard

`mmap(MAP_ANON | MAP_NORESERVE)` becomes a reservation from a fixed physical
arena sized at build time. The guard page below the evaluation stack is kept by
mapping it non-present when paging is enabled, or by a bounds check in the host
layer before paging exists. Exhaustion halts with the runtime's own
out-of-memory message.

### Faults halt

`sigaltstack` and `sigaction` become an exception handler that prints the
runtime's fault message to the serial console and halts the machine. There is
no resume path. The isa-debug-exit device reports a distinct exit code for a
fault so the QEMU harness can tell a fault from a corpus failure.

### Clock is monotonic or absent

`clock_gettime(CLOCK_MONOTONIC)` reads the TSC calibrated against a timer, as
Drift's kernel does, or a paravirtual clock when available. If calibration
fails, the host layer reports no clock and the runtime's time effects fail; the
monitor then denies work that needs deadlines, matching the Drift kernel host's
clock requirement.

### Effects are the monitor profile only

`IO.print` and `IO.print_err` write to the serial console. Exit codes go to the
debug-exit device. `IO.now` and `IO.sleep` use the clock. No file, socket,
process, audio, or window effect is linked, and `getenv("BENDRTS")` returns a
build-time string. The self-pipe and `select` become a direct in-memory
completion queue because every effect completes inline in the single-lane port.

The monitor profile's allow lists in `scripts/runtime-profile/` are the contract
for what the freestanding image may link and call, and the host layer, whether
nelibc or hand-written, supplies no symbol or effect row outside them (no host
libc is present to supply others).
`scripts/runtime-profile/check-binary.sh` is the check, and the image's corpus
run belongs in `verification/runtime-profile-hosts.md`. See
[docs/BEND-RUNTIME.md](../../../docs/BEND-RUNTIME.md).

### GPU dispatch is CPU

`!` calls run on the single lane. The port records this as CPU execution and
makes no device claim.

## Failure and denial behavior

A missing symbol fails the link, which is the intended way to discover a widened
runtime surface. An arena exhaustion, fault, or missing clock halts or denies
exactly as on Linux, with the message captured on the serial console. A corpus
line mismatch fails qualification. A 32-bit build is refused by the build task
rather than attempted.

## Evidence before claiming implementation

- Pinned Bend version, host layer source and hash, kernel variant, compiler,
  QEMU version, and machine type.
- Serial capture of the full corpus and all four examples, compared line for
  line with the Linux single-lane record.
- A forced fault and a forced exhaustion, each showing the halt code.
- The runtime profile's binary check applied to the freestanding image.
- A statement that the result is emulated execution under QEMU, separate from
  any physical machine and from the Drift kernel host's isolation evidence.
