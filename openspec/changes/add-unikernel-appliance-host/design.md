# Unikernel appliance host design

## Context

The incident-report monitor from the examples is built with `bend Tests.bend -o`
into one ELF executable. On Linux it runs as a process beside everything else on
the machine. The appliance profile boots that same executable as the only program
in a tiny virtual machine whose kernel is a Linux-compatible unikernel.

Current gap: there is no image, no build task, and no evidence that the Bend
runtime's host surface (threads, anonymous memory with a guard page, signals on
an alternate stack, a monotonic clock, a self-pipe) is satisfied by any
unikernel. [docs/BEND-RUNTIME.md](../../../docs/BEND-RUNTIME.md) lists that
surface; the runtime profile change turns it into a checked allowlist.

## Decisions

### Wrap an existing unikernel first

The appliance uses an upstream unikernel that runs unmodified Linux ELF
binaries. Two candidates are known: Nanos runs ELF executables as a single
process with multiple threads, and Unikraft's ELF loader runs static or dynamic
PIE executables. The selection is made by running the corpus on each and
recording which runtime primitives work, which fail, and what the project's
license terms require. A freestanding Bend port is a separate change and is not
a prerequisite for this one.

### The image is the monitor and nothing else

The image contains the monitor binary built under the monitor runtime profile,
the unikernel, and the minimum configuration to boot. No shell, no SSH, no
package manager, no debugger, no file browser. Builds are reproducible: the same
pinned Writ source, Bend compiler, unikernel version, and build container
produce the same image hash, and that hash is what a deployment names.

### One address space is not a worker boundary

A unikernel has no process isolation. The appliance therefore hosts only the
monitor. Confined transformation workers run in separate virtual machines or
separate host domains and reach the monitor through the portable host contract's
authenticated channel. A request to run requester-supplied code inside the
appliance is denied, not sandboxed.

### Ingress is one authenticated channel

The appliance exposes exactly one service endpoint, the one the portable host
contract defines for session binding. Where the unikernel supplies networking,
the appliance uses it only for that endpoint and for the durable state
connection. The monitor runtime profile forbids general socket effects in the
monitor; the channel effect is added by the host adapter under its own review.

### State lives outside the image

Session, ledger, authority epochs, and sealed artifacts are durable through the
durable-publication contract in a store the image attaches to, never inside the
image. Booting the image on a new machine with the same store produces a monitor
that reconciles outstanding invocations and continues. The image holds no secret
that must survive a rebuild; keys and channel identities are provisioned at boot
from the deployment's trusted provisioning path, which this change does not
define.

### Rebuild is a drill with a clock on it

The rebuild drill is: destroy the running appliance, start the pinned image on a
fresh virtual machine, attach the durable store, and show that every in-flight
invocation is reconciled exactly once and that service resumes. The elapsed time
is recorded. The drill is repeated on each image change. This is the recovery
property from the project's founding discussion, made measurable.

### Clock and entropy come from the hypervisor and are checked

The monotonic clock and the random source the runtime uses come from the
virtual hardware. The appliance verifies a monotonic clock reading at boot and
refuses protected work when the clock is unavailable, matching the Drift kernel
host's deadline rule. Entropy for challenge nonces is sourced from a virtual
random device and the provisioning path; a fixed or missing source denies
negotiation challenges.

### What the Linux-zero-day claim means

The guest contains no Linux kernel, so a Linux kernel vulnerability on the host
does not run inside the monitor. The hypervisor, the host kernel it runs on, the
firmware, and the unikernel itself remain in the trusted base. The appliance
narrows the attack surface of the monitor; it does not remove the host from the
trust boundary, and the record must say so.

## Failure and denial behavior

A missing runtime primitive fails boot; the runtime already exits on failed
reservation or thread creation. A corpus mismatch under the unikernel fails
qualification. An attempt to execute worker code in the appliance is denied. An
unavailable clock or entropy source denies protected work and challenge
issuance. A rebuild that reconciles an invocation twice or loses one fails the
drill, and the image is not promoted.

## Evidence before claiming implementation

- Image hash, unikernel version, Bend version, and build container pinned.
- Corpus and example output captured from the serial console under QEMU, with
  lane count and GPU mode recorded; KVM and hardware runs recorded separately.
- The binary-profile check result for the image's monitor executable.
- Rebuild drill log with elapsed time and reconciliation outcome.
- An explicit trusted-base statement naming hypervisor, host, firmware, and
  unikernel.
