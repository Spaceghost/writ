# Task 1 report: profile citations

Edited lines (all additions or appended text; no box changed).

## openspec/changes/add-windows-host/design.md

Before: (heading `### Qualify the native target` only; unchanged)

After: inserted immediately above it:

```
### The runtime host profile gates the worker runtime

The WinFsp and authenticated-broker product runs the generated Bend runtime as
the monitor, so the runtime host profile applies to the Windows build. The
monitor profile's allow lists in `scripts/runtime-profile/` are the contract for
what a Windows monitor binary may link and call, and the Win32 bindings must
supply only those rows. `scripts/runtime-profile/check-binary.sh` is the check,
and the Windows corpus run belongs in `verification/runtime-profile-hosts.md`.
See [docs/BEND-RUNTIME.md](../../../docs/BEND-RUNTIME.md). The profile qualifies
no Windows host; confinement evidence stays separate.

```

## openspec/changes/add-drift-kernel-host/design.md

Before: (heading `## Conformance and evidence` only; unchanged)

After: inserted immediately above it:

```
### The runtime host profile bounds the ported runtime

The ported Bend runtime is held to the runtime host profile. The monitor
profile's allow lists in `scripts/runtime-profile/` are the contract for what
the kernel-hosted monitor binary may link and call; Drift supplies drivers and
bring-up code beneath it, not the authority boundary, so a driver symbol never
widens the allow lists. `scripts/runtime-profile/check-binary.sh` is the check,
and the kernel run belongs in `verification/runtime-profile-hosts.md`. See
[docs/BEND-RUNTIME.md](../../../docs/BEND-RUNTIME.md). The freestanding runtime
change supplies the host layer this port would reuse.

```

## openspec/changes/add-freestanding-bend-runtime/design.md

Before: (heading `### GPU dispatch is CPU` only; unchanged)

After: inserted immediately above it:

```
The monitor profile's allow lists in `scripts/runtime-profile/` are the contract
for what the freestanding image may link and call, and the host layer, whether
nelibc or hand-written, supplies no symbol or effect row outside them (no host
libc is present to supply others).
`scripts/runtime-profile/check-binary.sh` is the check, and the image's corpus
run belongs in `verification/runtime-profile-hosts.md`. See
[docs/BEND-RUNTIME.md](../../../docs/BEND-RUNTIME.md).

```

## openspec/changes/add-windows-host/tasks.md

Before:
```
- [ ] 1.1 Bring up a pinned native Windows/x64 Bend runtime/backend and OS binding; distinguish model execution, WSL evidence, and actual native confinement.
```
After:
```
- [ ] 1.1 Bring up a pinned native Windows/x64 Bend runtime/backend and OS binding; distinguish model execution, WSL evidence, and actual native confinement. (cite `scripts/runtime-profile/` and record the run in `verification/runtime-profile-hosts.md`)
```

## openspec/changes/add-drift-kernel-host/tasks.md

Before:
```
- [ ] 1.3 Port the actual Bend runtime and bounded native bridge; execute the unchanged authority path and reject caller-supplied replacements for monitor records.
```
After:
```
- [ ] 1.3 Port the actual Bend runtime and bounded native bridge; execute the unchanged authority path and reject caller-supplied replacements for monitor records. (cite `scripts/runtime-profile/` and record the run in `verification/runtime-profile-hosts.md`)
```

## openspec/changes/add-freestanding-bend-runtime/tasks.md

Before:
```
- [ ] 1.3 Write the host layer that provides the generated runtime's memory, fault, clock, environment, exit, and single-lane thread symbols; link the `IO.print` reference program and show its output on the serial console.
```
After:
```
- [ ] 1.3 Write the host layer that provides the generated runtime's memory, fault, clock, environment, exit, and single-lane thread symbols; link the `IO.print` reference program and show its output on the serial console. (cite `scripts/runtime-profile/` and record the run in `verification/runtime-profile-hosts.md`)
```

## openspec/changes/add-freestanding-bend-runtime/tasks.md

Before:
```
- [ ] 2.4 Run the runtime profile's binary check on the freestanding image and record the linked effect rows.
```
After:
```
- [ ] 2.4 Run the runtime profile's binary check on the freestanding image and record the linked effect rows. (cite `scripts/runtime-profile/` and record the run in `verification/runtime-profile-hosts.md`)
```

## openspec/changes/add-bend-runtime-host-profile/tasks.md

Before:
```
- [ ] 2.3 Document the profile's role in the Genode, Windows, Drift kernel, unikernel, and freestanding changes and update their runtime tasks to cite it; leave those tasks unchecked.
```
After:
```
- [ ] 2.3 Document the profile's role in the Genode, Windows, Drift kernel, unikernel, and freestanding changes and update their runtime tasks to cite it; leave those tasks unchecked.
  Note (2026-11-04): the Windows (`add-windows-host`), Drift kernel
  (`add-drift-kernel-host`), and freestanding (`add-freestanding-bend-runtime`)
  changes now cite the profile in their design.md and runtime tasks. The Genode
  and unikernel changes still wait for the live `genode-base-hw` and
  `unikraft-twins` lanes, so this box stays unchecked.
```

OpenSpec 1.16.0 strict: 44 passed, 0 failed.
Task lines annotated: 4 (windows 1.1, drift 1.3, freestanding 1.3 and 2.4); 2.3 note added, box unchecked.
