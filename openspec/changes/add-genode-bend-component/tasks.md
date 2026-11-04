# Bend runtime as a Genode component: tasks

Only 1.2 is complete. It is checked because every execution named in 1.2 was
performed, while Atomics and `munmap` remain unverified. The generated C of the reference program builds and
loads as a component on `base-linux`, but it stops at the stack guard before
printing (verification/genode-bend-hello-base-linux.txt), so 1.1 stays open.
The runtime rows are in verification/genode-runtime-rows-base-linux.md; the
fault outcome there comes from a C probe, and the parent does not record the
fault, so 1.3 stays open.

## 1. Component build and runtime rows

- [ ] 1.1 Pin Genode 26.08, its toolchain, and a `base-linux` run script; compile the generated C of the `IO.print` reference program as a Genode component and show its output in the Genode log.
- [x] 1.2 Check each runtime inventory row against the pinned libc source and record supplied, substituted, or missing; verify `mmap` with `MAP_NORESERVE`, `mprotect`, pthreads, `pipe`/`select`, and the fault path by executing each, not by reading headers.
- [ ] 1.3 Select the fault substitute if signal delivery does not reach the handler; force a stack overflow and show the component terminates and the parent records it, with no resumption.
- [ ] 1.4 Compile and run `Tests.bend` and the four examples as components on `base-linux`; capture the log and compare line for line with the Linux single-lane record.

## 2. Effects and the Writ session

- [ ] 2.1 Author the `Genode.log`, `Genode.now`, and `Genode.sleep` effects in Bend with C twins over the shim; verify output and monotonic time from inside the component.
- [ ] 2.2 Write the `extern "C"` shim with a bounded request queue and publish its trust inventory (files, exported symbols, sessions opened, reviewer); show it contains no policy decision.
- [ ] 2.3 Author `Genode.accept` and `Genode.answer`; serve one report-to-summary request through `DataOS.commit_from_capability` and one request with a substituted subject, showing the second denied by Bend.
- [ ] 2.4 Bound and test request size, queue depth, and a client that never reads its reply; verify the loop keeps serving other sessions.

## 3. base-hw and evidence

- [ ] 3.1 Repeat 1.4 and 2.3 on x86_64 `base-hw` under QEMU with a pinned image; record results separately from `base-linux`.
- [ ] 3.2 Run the runtime profile's binary check on the component, record CPU execution for device paths, and validate OpenSpec strictly; leave the Genode host's confinement tasks unchecked.
