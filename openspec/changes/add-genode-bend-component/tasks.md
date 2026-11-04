# Bend runtime as a Genode component: tasks

1.1, 1.2, 1.3, and 1.4 are complete. 1.2 is checked because every execution
named in it was performed, while Atomics across lanes remains unverified.
1.1 is checked because the generated C of the reference program, linked with
the host-layer shim, prints `hi` under init on `base-linux` and exits 0
(verification/genode-bend-hello-base-linux.txt, host-layer section). 1.4 is
checked because `Tests.bend` (782 PASS lines and `ALL LIBRARY TESTS PASSED`
on the tree merged with master at d8b1473; 764 on the earlier tree caf13ca)
and the four examples ran as components on `base-linux` and each log is
byte-identical to a fresh Linux single-lane record of the same tree
(verification/genode-corpus-base-linux.txt and
verification/genode-corpus-linux-reference.txt). 1.3 is checked on `base-hw` (Genode base-hw lane, Task 2), worded:
the parent records the component's self-reported fault exit on base-hw. A
stack overflow forced through a Bend program (`Overflow.bend`, ram 3G, caps
2000, QEMU TCG emulated boot) was refused at the runtime's guard page by the
shim's Region_map fault handler, with no resumption, and init logged
`[init] child "writ_bend_overflow" exited with exit value 139`; core logged
nothing (verification/genode-corpus-base-hw.txt, OVERFLOW RUNS;
verification/genode-runtime-rows-base-hw.md, Faults). The record has six
limits (verification/genode-bend-hello-base-hw.txt, GB-003 ON BASE-HW): the
termination is self-requested through `Parent::exit(139)`; init records an
exit value, not a fault; core is silent; other threads may run before init
destroys the PD; coverage excludes non-page-fault exceptions, a parent's
handler displacing the shim's, and faults on the writ_fault thread, and
stack-area and linker-area faults were not exercised; the evidence is
emulated boot only. On `base-linux` 1.3 is not satisfied: the component
terminated at the guard with no resumption, but init recorded nothing. 1.4's
evidence stays `base-linux`; the base-hw corpus and example runs (782 PASS
lines and four examples, byte-identical) are recorded for 3.1 in
verification/genode-corpus-base-hw.txt and do not change 1.4. The GB-004 scenario's count of 638 checks
is the older corpus; parity for 1.4 was checked against the current
782-check record of this tree (and before the merge against the 764-check
record). The runtime rows are in
verification/genode-runtime-rows-base-linux.md (base-hw:
verification/genode-runtime-rows-base-hw.md).

Section 2 (Genode channel lane, 2026-11-04; all `base-linux`): 2.1, 2.3, and
2.4 are checked, 2.2 stays open. 2.1: the probe component's text reaches the
Genode LOG through `Genode.log`, and two `Genode.now` readings around
`Genode.sleep(100)` are ordered with a delta of 101 ms
(verification/genode-effects-base-linux.txt). 2.3: through `Genode.take` and
`Genode.put` over one channel object per session, bound to one descriptor,
reader R's report-to-summary request is Committed by
`DataOS.commit_from_capability`, and the same route with a body claiming S
is Denied by Bend (reason 6); S's session is synthetic, opened and not
negotiated (verification/genode-channel-base-linux.txt, runs 1 to 4). 2.4:
request size is bounded at 64 bytes and lengths 65, 0, and 0xFFFFFFFF
(above the 4 KiB bucket) are counted and answered by the shim's fixed
transport refusal before Bend; queue depth is bounded at one entry per
channel slot and 8 slots: with 9 clients 8 sessions opened (the ninth
refused) and 8 decisions over channels 1-4 (1-3 in the rerun) were made
in ring order before the fuel ran out, with at most 3 entries in the
ring at once (timing dependent; a full ring cannot occur by construction
and was not observed). Coalescing in the shim (a channel signalled again
while its entry is queued, kept to one entry) was not reliably exercised:
coalesced was 0 in every retained run, and in six burst attempts it was
above 0 twice (3 and 1), because Genode merges repeated submits to one
signal context before the handler runs (about 10 handler calls for 400
submits); no burst run is kept. A client that floods without ever reading its replies does not stop a second
client from being served, nor does a client that exits before its reply
or one that freed its result signal context, and the loop exits with
value 0 when its fuel runs out (same file, TASK 3 and FINAL REVIEW);
whether the reply signal can block the loop on base-linux in cases not
run is not shown. GB-008's restart by a supervisor with a new
generation is not configured. 2.2 stays open: the shim, its bounded queue,
and the trust inventory exist (hosts/genode/INVENTORY.md lists files,
exported symbols, and sessions), but the inventory's reviewer is still
"Not reviewed under GB-006", and that the shim holds no policy decision is
stated by its authors, not yet shown by that review.

## 1. Component build and runtime rows

- [x] 1.1 Pin Genode 26.08, its toolchain, and a `base-linux` run script; compile the generated C of the `IO.print` reference program as a Genode component and show its output in the Genode log.
- [x] 1.2 Check each runtime inventory row against the pinned libc source and record supplied, substituted, or missing; verify `mmap` with `MAP_NORESERVE`, `mprotect`, pthreads, `pipe`/`select`, and the fault path by executing each, not by reading headers.
- [x] 1.3 Select the fault substitute if signal delivery does not reach the handler; force a stack overflow and show the component terminates and the parent records it, with no resumption.
- [x] 1.4 Compile and run `Tests.bend` and the four examples as components on `base-linux`; capture the log and compare line for line with the Linux single-lane record.

## 2. Effects and the Writ channel

- [x] 2.1 Author the `Genode.log`, `Genode.now`, and `Genode.sleep` effects in Bend with C twins over the shim; verify output and monotonic time from inside the component.
- [ ] 2.2 Write the `extern "C"` shim with a bounded request queue and publish its trust inventory (files, exported symbols, sessions opened, reviewer); show it contains no policy decision.
- [x] 2.3 Author `Genode.take` and `Genode.put` over the per-descriptor request and result buckets; serve one report-to-summary request record through `DataOS.commit_from_capability` and one request with a substituted subject, showing the second denied by Bend.
- [x] 2.4 Bound and test request size, queue depth, and a client that never reads its reply; verify the loop keeps serving other sessions.

## 3. base-hw and evidence

- [ ] 3.1 Repeat 1.4 and 2.3 on x86_64 `base-hw` under QEMU with a pinned image; record results separately from `base-linux`.
- [ ] 3.2 Run the runtime profile's binary check on the component, record CPU execution for device paths, and validate OpenSpec strictly; leave the Genode host's confinement tasks unchecked.
