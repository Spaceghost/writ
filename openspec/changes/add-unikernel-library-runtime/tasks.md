# Library-unikernel Bend runtime: tasks

All tasks remain pending. The survey in docs/UNIKERNELS.md is documentation
reading; no candidate has been built or booted with Bend.

## 1. Selection

- [ ] 1.1 Pin Unikraft and OSv versions and toolchains; build the generated C of the `IO.print` reference program against each as a native application and record build outcome.
- [ ] 1.2 Fill the selection matrix, one row per runtime inventory item per candidate, by executing each primitive (reservation with guard, threads or single lane, fault path, clock, self-pipe, environment, exit); publish the matrix and the chosen kernel with reasons.
- [ ] 1.3 If Unikraft is chosen, run the reference program under its `linuxu` platform and record it as process execution, not a boot.

## 2. Port

- [ ] 2.1 Author the console, time, exit, and ingress effect twins for the chosen kernel; publish their trust inventory; run the runtime profile's binary check on the image.
- [ ] 2.2 Configure a single lane with the inline IO helper; build `Tests.bend` and the four examples; capture console output under QEMU and compare line for line with the Linux single-lane record.
- [ ] 2.3 Install the halting fault handler; force a stack overflow and an arena exhaustion; record the console message and distinct exit codes.
- [ ] 2.4 Enable additional lanes behind the kernel's thread library; show the corpus still matches and record the lane count.

## 3. Boots and deployment rules

- [ ] 3.1 Boot the image under a hardware-accelerated hypervisor (Firecracker or QEMU with KVM); record results separately from software emulation.
- [ ] 3.2 Apply the appliance host's requirements UA-001 through UA-010 to the library image, including the rebuild drill with elapsed time and the trusted-base statement.
- [ ] 3.3 Validate OpenSpec strictly and run the ordinary Bend checks on Linux to show no policy source changed.
