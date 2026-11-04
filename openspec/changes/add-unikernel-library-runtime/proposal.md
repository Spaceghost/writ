# Library-unikernel Bend runtime

## Why

The appliance change boots the unmodified Bend binary under a Linux-ABI
compatibility kernel. That is the fastest first boot, but the image still
carries a syscall emulation layer the monitor barely uses, and the Bend effect
table still talks to that layer instead of to the kernel. The theme Josh and
Spaceghost settled on is to leverage an existing unikernel and make the Bend
runtime fit it, so the end state is a **native link**: the generated C of the
monitor compiled against a library unikernel's own libc and linked into one
image that is nothing but the monitor and the kernel pieces it needs.

[docs/UNIKERNELS.md](../../../docs/UNIKERNELS.md) surveys the candidates.
Unikraft is the leading native-link candidate on paper: musl as default libc,
threads through a `clone` shim, a `posix-mmap` library, KVM via QEMU and
Firecracker, and a `linuxu` platform for debugging the image as a Linux process.
OSv is the fallback with the broadest POSIX surface. None has been tried with
Bend.

## What Changes

- Build the monitor as a library-unikernel application: generated C compiled
  with the unikernel's toolchain against its libc, with only the libraries the
  runtime profile needs selected.
- Rewrite the monitor-profile effects' C twins to call the unikernel's
  primitives directly where that removes a layer: console, time, exit, and the
  authenticated channel ingress.
- Select the unikernel by a recorded evidence matrix over the runtime inventory
  rows, trying Unikraft first and OSv second; treat Nanos as the appliance's
  compat-mode candidate, not this change's.
- Inherit the appliance's deployment rules (immutable image, one ingress, state
  outside, rebuild drill) rather than restating them.

## Capabilities

### New Capabilities

- `unikernel-library-runtime`: Execute the Bend monitor natively linked into a
  library unikernel with the runtime profile satisfied by the kernel's own
  libraries and effects bound to kernel primitives.

### Modified Capabilities

None. The appliance host's UA-004 through UA-010 apply to the resulting image
unchanged; this change governs how the image is built and what it links.

## Impact

Adds a unikernel build configuration, effect C twins for the chosen kernel, and
boot evidence under QEMU, Firecracker or KVM, and `linuxu` where available. The
unikernel is an external dependency pinned by version. No Bend policy changes.
The freestanding runtime change remains the route for the Drift kernel, which
is not a library unikernel.

## Dependencies

- [Portable host contract](../add-portable-host-contract/proposal.md)
- [Bend runtime host profile](../add-bend-runtime-host-profile/proposal.md)
- [Unikernel appliance host](../add-unikernel-appliance-host/proposal.md):
  deployment rules and the rebuild drill are inherited from it.
