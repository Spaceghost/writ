# Unikernel appliance host

## Why

A Writ monitor should run as a small immutable image with no general-purpose
kernel, no shell, and nothing to log into, so that a Linux kernel vulnerability
on the deployment host is not a vulnerability inside the monitor, and so that
replacing a compromised or failed monitor means booting a fresh image on fresh
hardware and reattaching its durable state. The chat that started this project
put it as "wrap it in an existing unikernel" first and "rebuild from entirely new
hardware" as the business value.

Today the native Bend binary runs only as an ordinary Linux process. A
statically linked Bend executable was shown to build and run on this machine
([docs/BEND-RUNTIME.md](../../../docs/BEND-RUNTIME.md)), which is what a
Linux-binary-compatible unikernel consumes. No image, build task, boot test, or
rebuild drill exists.

## What Changes

- Add an **appliance profile**: a reproducible image that contains the Bend
  monitor binary built under the monitor runtime profile, a pinned unikernel
  that runs unmodified Linux ELF executables, and nothing else.
- Choose the unikernel by evidence between candidates such as Nanos and
  Unikraft's ELF loader; the choice is a task outcome, not a decision made here.
- Require the first milestone to be the library corpus and examples booting under
  QEMU and printing the recorded results, then the monitor service on an
  authenticated channel, then a timed rebuild drill.
- State what the appliance does **not** provide: a unikernel is one address
  space, so it is a monitor container and never a worker confinement boundary.
  Workers stay in separate domains under the portable host contract.

## Capabilities

### New Capabilities

- `unikernel-appliance-host`: Run the Writ monitor as an immutable
  single-purpose unikernel image with externalized durable state and a
  documented rebuild procedure.

### Modified Capabilities

None. The portable host contract, confined execution, and durable publication
changes define the surrounding guarantees; this change adds one deployment shape
for the monitor.

## Impact

Adds an image build task, boot tests under QEMU, and a rebuild drill. Adds a
pinned upstream unikernel as an external dependency, in the same way Genode and
Drift are external. No Bend policy changes. The hypervisor, host kernel, and
firmware remain in the trusted base and are named as such.

## Dependencies

- [Portable host contract](../add-portable-host-contract/proposal.md)
- [Bend runtime host profile](../add-bend-runtime-host-profile/proposal.md)
- [Authenticated grant issuance](../add-authenticated-grant-issuance/proposal.md)
- [Durable publication](../add-durable-publication/proposal.md)

The first milestone (corpus boots and passes) depends only on the runtime
profile. The service and rebuild milestones depend on the rest.
