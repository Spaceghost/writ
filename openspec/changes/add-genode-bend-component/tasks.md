# Bend runtime as a Genode component: tasks

1.1, 1.2, and 1.4 are complete. 1.2 is checked because every execution
named in it was performed, while Atomics across lanes remains unverified.
1.1 is checked because the generated C of the reference program, linked with
the host-layer shim, prints `hi` under init on `base-linux` and exits 0
(verification/genode-bend-hello-base-linux.txt, host-layer section). 1.4 is
checked because `Tests.bend` (764 PASS lines and `ALL LIBRARY TESTS PASSED`)
and the four examples ran as components on `base-linux` and each log is
byte-identical to a fresh Linux single-lane record of the same tree
(verification/genode-corpus-base-linux.txt and
verification/genode-corpus-linux-reference.txt). 1.3 stays open: a stack
overflow was forced through a Bend program (`Overflow.bend`), and the
component terminated at the runtime's guard page with no resumption, but the
parent (init) recorded nothing. The GB-004 scenario's count of 638 checks
is the older corpus; parity for 1.4 was checked against the current
764-check record of this tree. The runtime rows are in
verification/genode-runtime-rows-base-linux.md.

## 1. Component build and runtime rows

- [x] 1.1 Pin Genode 26.08, its toolchain, and a `base-linux` run script; compile the generated C of the `IO.print` reference program as a Genode component and show its output in the Genode log.
- [x] 1.2 Check each runtime inventory row against the pinned libc source and record supplied, substituted, or missing; verify `mmap` with `MAP_NORESERVE`, `mprotect`, pthreads, `pipe`/`select`, and the fault path by executing each, not by reading headers.
- [ ] 1.3 Select the fault substitute if signal delivery does not reach the handler; force a stack overflow and show the component terminates and the parent records it, with no resumption.
- [x] 1.4 Compile and run `Tests.bend` and the four examples as components on `base-linux`; capture the log and compare line for line with the Linux single-lane record.

## 2. Effects and the Writ channel

- [ ] 2.1 Author the `Genode.log`, `Genode.now`, and `Genode.sleep` effects in Bend with C twins over the shim; verify output and monotonic time from inside the component.
- [ ] 2.2 Write the `extern "C"` shim with a bounded request queue and publish its trust inventory (files, exported symbols, sessions opened, reviewer); show it contains no policy decision.
- [ ] 2.3 Author `Genode.take` and `Genode.put` over the per-descriptor request and result buckets; serve one report-to-summary request record through `DataOS.commit_from_capability` and one request with a substituted subject, showing the second denied by Bend.
- [ ] 2.4 Bound and test request size, queue depth, and a client that never reads its reply; verify the loop keeps serving other sessions.

## 3. base-hw and evidence

- [ ] 3.1 Repeat 1.4 and 2.3 on x86_64 `base-hw` under QEMU with a pinned image; record results separately from `base-linux`.
- [ ] 3.2 Run the runtime profile's binary check on the component, record CPU execution for device paths, and validate OpenSpec strictly; leave the Genode host's confinement tasks unchecked.
