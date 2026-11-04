# Freestanding Bend runtime

## Why

The Drift kernel host needs the Bend runtime to run with no C library on a
kernel that has no processes, and its task 1.3 says only "port the actual Bend
runtime." The Genode base-hw lane has the same shape of problem. Nothing in the
repository says what a freestanding port must replace, what it may not change,
or how to show it still computes the same authorizations.

The generated runtime for Bend 2.0.39 depends on `mmap`, signal handlers on an
alternate stack, pthreads, a monotonic clock, and a self-pipe
([docs/BEND-RUNTIME.md](../../../docs/BEND-RUNTIME.md)). Drift's reference
kernel is a 32-bit Multiboot image with no paging, scheduler, or allocator, and
on this machine's QEMU and compiler it boots and then stops before its device
tests. The gap between those two is the work this change describes.

## What Changes

- Define the **freestanding runtime** as the pinned Bend-generated evaluator and
  effect table running over a small host layer that supplies an arena instead
  of `mmap`, a halting trap instead of signals, a single lane or kernel threads
  instead of pthreads, a TSC- or timer-backed monotonic clock, a serial console
  for `IO.print`, and a direct completion queue instead of a self-pipe.
- Require a long-mode (64-bit) kernel variant for the first port because the
  Bend term is a 64-bit word; the 32-bit reference kernel is not qualified for it.
- Require parity: the corpus and examples over the serial console must match
  the recorded Linux single-lane output line for line.
- Keep policy code and the evaluator unchanged; only the host layer is new, and
  it is reviewed as part of the trusted base.

## Capabilities

### New Capabilities

- `freestanding-bend-runtime`: Execute the unchanged Bend evaluator and Writ
  policy corpus on a kernel without a C library, through a minimal reviewed host
  layer, with line-for-line parity against the recorded Linux results.

### Modified Capabilities

None. The Drift kernel host's requirements remain; this change supplies the
runtime prerequisite its task 1.3 names.

## Impact

Adds a host layer in C beneath the generated runtime, a 64-bit kernel build
variant alongside Drift's reference kernel, and serial-captured corpus
evidence. The host layer is external to Writ's Bend policy in the same sense
the compiler's runtime is; it is not a second policy implementation. No Bend
source changes.

## Dependencies

- [Bend runtime host profile](../add-bend-runtime-host-profile/proposal.md):
  the inventory this port must satisfy.
- [Drift-backed kernel host](../add-drift-kernel-host/proposal.md): the
  consumer; its isolation, capability, and publication requirements are not
  satisfied by this change.

Drift's reference kernel and its device tests are an external dependency
inspected in [docs/DRIFT.md](../../../docs/DRIFT.md).

## Explainer

The lane reading page is [add-bend-runtime-host-profile/explainer.html](../add-bend-runtime-host-profile/explainer.html).
