# Bend runtime host profile

## Why

Every proposed native target needs the Bend runtime before it can run Writ's
authority path: Genode task 1.2, the Windows runtime port, the Drift kernel host
task 1.3, and the unikernel appliance all say "port the runtime" without naming
what the runtime requires. The generated C for Bend 2.0.39 reserves memory with
`mmap`, installs fault handlers, starts worker and IO helper threads, reads a
monotonic clock, and wakes its event loop through a pipe. A target that lacks one
of these fails at startup or, worse, behaves differently without saying so.

[docs/BEND-RUNTIME.md](../../../docs/BEND-RUNTIME.md) records the inspected
surface. Nothing in the repository today turns that inspection into a checked
contract, and no build verifies that a monitor binary links only the host
symbols and effects a monitor should have.

## What Changes

- Define a pinned, per-Bend-version inventory of host primitives the generated
  runtime needs, split into memory, faults, threads, clock, event loop, process,
  atomics, and device groups.
- Define the **monitor profile**: the subset a Writ policy monitor may link, with
  an effect allowlist (`IO.print`, `IO.print_err`, `IO.now`, `IO.sleep`, exit, and
  the authenticated channel effects a host adds) and an explicit denial of
  sockets, files, process spawning, audio, windows, and GPU program loading.
- Require a build-time check of a produced binary's undefined and linked symbols
  against the profile, and a runtime corpus check that the same 638 library
  checks and example assertions pass on the profile.
- Require that single-lane and reduced-thread execution produce the same policy
  decisions as the recorded Linux runs, and that CPU fallback is reported as such.

## Capabilities

### New Capabilities

- `bend-runtime-host-profile`: A checked inventory of host primitives and
  effects that a Bend-built Writ monitor may use, with evidence that a given
  host target satisfies it.

### Modified Capabilities

None. Existing library, verification-evidence, and host-contract requirements
remain. This change supplies a prerequisite those changes reference.

## Impact

Adds an inspection document, a profile definition, and a symbol and effect
checking script in the build tooling. No Bend policy code changes. The runtime
itself is an upstream compiler artifact; this change does not modify or fork it.
Host targets gain a precise prerequisite instead of an informal "port the runtime"
task.

## Dependencies

- [Portable host contract](../add-portable-host-contract/proposal.md): the
  profile is one of the contract's qualification inputs.

Used by [add-unikernel-appliance-host](../add-unikernel-appliance-host/proposal.md),
[add-freestanding-bend-runtime](../add-freestanding-bend-runtime/proposal.md),
[add-genode-host](../add-genode-host/tasks.md), [add-windows-host](../add-windows-host/proposal.md),
and [add-drift-kernel-host](../add-drift-kernel-host/tasks.md).

## Explainer

[explainer.html](explainer.html) is a standalone reading page covering this change together with the appliance and freestanding runtime changes.
