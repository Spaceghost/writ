# Bend runtime as a Genode component

## Why

The Genode host change says the Writ monitor runs as a Genode component and
leaves the runtime port as task 1.2. Nothing describes how a Bend-built binary
becomes a component, how its effects reach Genode sessions, or how it serves
requests when Genode's RPC model is a C++ framework API and Bend's effect loop
is a C event loop. Without that, the Genode lane cannot start.

Bend's custom-effect mechanism is the hook: an effect is a def whose body is
a `.c` and a `.js` import, and the `.c` file is spliced into the generated
program after the runtime. That means Writ can author its Genode effects in Bend
with small C twins, and those twins can call an `extern "C"` shim over Genode's
session APIs. The shim is authored binding code and needs the trust inventory
AGENTS.md requires. [docs/GENODE.md](../../../docs/GENODE.md) has the pinned
source; [docs/BEND-RUNTIME.md](../../../docs/BEND-RUNTIME.md) has the runtime
surface the component must satisfy through Genode's libc.

## What Changes

- Build the Bend monitor as a Genode component on `base-linux` first, then
  x86_64 `base-hw` under QEMU, satisfying the runtime host profile through
  Genode's FreeBSD-derived libc and recording which runtime rows it supplies
  natively, which need the profile's substitutes (single lane, halting fault
  path), and which fail.
- Define **Genode effects** authored in Bend with C twins: console output over
  the LOG session, time over the Timer session, and a **Writ channel** pair of
  effects (`take`, `put`) over bounded typed request and result buckets, so
  the interaction above the kernel is records in channels rather than
  procedure calls. Genode's RPC objects, dataspaces, and signals are only the
  transport.
- Define the `extern "C"` shim as the only authored C++ binding, with an
  explicit source and trust inventory.
- Require corpus parity inside the component before any session is served.

## Capabilities

### New Capabilities

- `genode-bend-component`: Execute the pinned Bend runtime and Writ policy
  corpus inside a Genode component and expose the monitor through Bend-authored
  effects over Genode sessions, with the binding shim inventoried.

### Modified Capabilities

None. The Genode host's topology, confinement, sealing, and revocation
requirements remain in that change; this change supplies its runtime and
ingress pieces.

## Impact

Adds a Genode build target for the monitor, Bend effect modules with C twins,
one C++ shim, run scripts, and serial-captured evidence. Writ policy stays in
Bend and the generated runtime stays an upstream artifact. Genode itself is an
external dependency pinned to 26.08.

## Dependencies

- [Portable host contract](../add-portable-host-contract/proposal.md)
- [Bend runtime host profile](../add-bend-runtime-host-profile/proposal.md)
- [Genode reference host](../add-genode-host/proposal.md): this change
  implements its tasks 1.2 and 1.3; it does not complete its confinement tasks.

Related: [Genode capability adoption](../add-genode-capability-adoption/proposal.md)
supplies the Bend model the Writ session effect binds to.

## Explainer

[explainer.html](explainer.html) is a standalone reading page for this change.
