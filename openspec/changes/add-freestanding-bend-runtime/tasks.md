# Freestanding Bend runtime tasks

All tasks remain pending. Building and booting Drift's reference kernel on a
developer machine is driver evidence, and on this machine it did not pass; it
completes no task here.

## 1. Kernel variant and host layer

- [ ] 1.1 Reproduce Drift's `tools/check-kernel.sh` on a pinned GCC and QEMU and record whether it passes; if it fails, record the failing stage before building on it.
- [ ] 1.2 Add an x86_64 long-mode Multiboot variant beside Drift's reference kernel with serial output, a calibrated monotonic clock, a fixed arena, and a halting exception handler; boot it under QEMU and show a banner and halt code.
- [ ] 1.3 Write the host layer that provides the generated runtime's memory, fault, clock, environment, exit, and single-lane thread symbols; link the `IO.print` reference program and show its output on the serial console. (cite `scripts/runtime-profile/` and record the run in `verification/runtime-profile-hosts.md`)
- [ ] 1.4 Refuse a 32-bit build in the build task with a stated reason; record that the 32-bit reference kernel is not a qualified runtime target.

## 2. Corpus parity

- [ ] 2.1 Link `Tests.bend` and the four examples against the host layer; capture serial output and compare it line for line with the Linux `--threads 1 --gpu off` record, including the 638 count and the example assertion lines.
- [ ] 2.2 Force a stack overflow and an arena exhaustion; record the serial message and distinct halt codes for fault, exhaustion, and corpus failure.
- [ ] 2.3 Remove the clock at boot and show that time effects fail and deadline-dependent checks deny instead of extending.
- [ ] 2.4 Run the runtime profile's binary check on the freestanding image and record the linked effect rows. (cite `scripts/runtime-profile/` and record the run in `verification/runtime-profile-hosts.md`)

## 3. Evidence

- [ ] 3.1 Record pinned versions, hashes, QEMU machine type, and the serial captures under verification/; state the result as emulated single-lane CPU execution separate from Drift kernel host isolation evidence.
- [ ] 3.2 Run the ordinary Bend checks on Linux to show no policy source changed, and validate OpenSpec strictly.
