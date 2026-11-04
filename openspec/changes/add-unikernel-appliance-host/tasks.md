# Unikernel appliance host tasks

All tasks remain pending. A statically linked Bend hello-world running on Linux
is runtime evidence only; no image has been built or booted.

## 1. Image and boot

- [ ] 1.1 Pin two candidate unikernels that run unmodified Linux ELF executables; build the `Tests.bend` and example binaries under the monitor runtime profile and attempt to boot each under QEMU; record per candidate which runtime primitives work and which fail.
- [ ] 1.2 Select one unikernel from that evidence and record the reason, its license terms, and the pinned version; add a reproducible image build task whose output hash is stable across two clean builds.
- [ ] 1.3 Boot the image under QEMU and capture serial output showing every corpus PASS line, the 638 count, and all four examples; record lane count and CPU execution mode.

## 2. Service and state

- [ ] 2.1 Add the portable host contract's authenticated channel as the image's only ingress; verify no shell, debug, or second service endpoint is reachable from the virtual network.
- [ ] 2.2 Attach the durable publication store from outside the image; verify a boot with an empty store serves no protected work and a boot with a populated store reconciles outstanding invocations exactly once.
- [ ] 2.3 Verify that clock unavailability denies protected work and that a missing entropy source denies challenge issuance; record the observed denials.
- [ ] 2.4 Verify that a request to execute requester-supplied code inside the appliance is denied rather than sandboxed.

## 3. Rebuild drill and evidence

- [ ] 3.1 Run the rebuild drill: destroy the appliance, boot the pinned image on a fresh virtual machine, attach the store, and record elapsed time and reconciliation results; repeat after an image change.
- [ ] 3.2 Record the trusted base (hypervisor, host kernel, firmware, unikernel) and keep QEMU, KVM, and physical runs as separate evidence; run the ordinary Bend checks and strict OpenSpec validation.
