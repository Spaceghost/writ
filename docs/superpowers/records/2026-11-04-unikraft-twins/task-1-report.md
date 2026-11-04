# Task 1 report: Unikraft console and time twins, UL-004 amendment

Status: DONE_WITH_CONCERNS

Commits (lane/unikraft-twins, not pushed):
- e740ed7 twins, host.c, Probe.bend, WRIT_HOST_LAYER (Makefile.uk/build.sh), WRIT_CONSOLE_SED (check-image.sh), probe reference
- 1427f51 verification/unikernel-effects-qemu.txt, UL-004 amendment, tasks.md 2.1 note
- 3d6e6d6 INVENTORY.md, docs/UNIKERNELS.md port status, OpenSpec record

Summary: text on serial yes (via Unikraft.log -> uk_console_out); delta 100, 100, 100, 101 ms
around sleep(100), QEMU 1, check-image PASS; FAIL branch (scratch min_delta 1000) QEMU 3 and
check-image exit 1; check-binary rows exactly Unikraft.log/now/sleep (exit 1, outside the
profile, allow lists untouched); UL-004 amended yes; OpenSpec 1.16.0 (bunx) strict 44/44.

## Decisions
- Console: uk_console_out (lib/ukconsole/include/uk/console.h); 0.21.0 has no ukplat_coutd.
  Log bound 4096 bytes, cut marked " [writ_uk_log: truncated]".
- Time: ukplat_monotonic_clock (include/uk/plat/time.h) / 1e6, truncated to U32 by the twin.
- Sleep: uk_sched_thread_sleep (lib/uksched/include/uk/sched.h) in a loop to the deadline,
  at most 16 rounds, _exit(1) on frozen/backward clock or round overflow. nanosleep is the
  same call under HAVE_SCHED (lib/posix-time/time.c:69-97). Runs on the loop thread, NOT
  io_work: the first build used io_work like Genode; the helper thread worked but outlives
  main, so pid 1 is still RUNNING at shutdown and posix-process (no LIBPOSIX_PROCESS_SIGNAL,
  shutdown.c:96-101) sets 0x80|SIGKILL -> exit hook 0x7f -> QEMU 255 (evidence E1).
- Build config: WRIT_HOST_LAYER (default n) so other images link as before (hello regression
  rebuilt, PASS, no writ_uk symbols). WRIT_CONSOLE_SED masks clock values for the reference
  diff; exit status still checks the values. No Kraftfile change.

## UL-004 rationale (also in tasks.md 2.1)
The old text made the effect twins the only kernel-specific code, but the termination and
crash hook cannot be a twin: a twin is a Bend effect the program calls, and no Bend code runs
on a Unikraft crash or after main has returned, exactly when the hook reports how the image
ended. Moving that into a twin would lose the crash/exit outcomes; dropping the hook would
hide them. New text: "the effect twins and the inventoried boot and termination host layer
SHALL be the only kernel-specific code", with the inventory naming each file, its exported
symbols, and what it may touch. Kraftfile and Makefile.uk remain build configuration listed
in INVENTORY.

## Concerns
- io_work on this configuration turns success into QEMU 255; Task 2's blocking take cannot use
  io_work as the Genode twin does (needs io_wait_on on a device fd, or a loop-thread block).
- Sleep blocks the event loop: no other computation runs during it (documented).
- host.c's re-sleep and clock-failure paths were not exercised (no fault injection without
  patching Unikraft).
- design.md line 42 still says "The twins are the only kernel-specific code"; left unchanged
  because the brief limited openspec edits to the spec delta and tasks.md.
- OpenSpec run via bunx @fission-ai/openspec@1.16.0 (Nix path gone), per coordinator.
- Bend Tests.bend / PROOF.bend not rerun: no library or security code changed.

## Fix round 1

Status: DONE. Commit: c3f2050.

1. Sleep now parks on the runtime's own timer: `unikraft_sleep_run` reads the start
   (`writ_uk_clock_ns`), and `unikraft_sleep_more` asks `writ_uk_sleep_left(start, deadline,
   &last, round)` for the time left, re-parking with `io_wait_on(w, 0, 0, io_tick() + left,
   more)` (as bend2/effs/sleep.c) at most 16 times. No helper thread, loop stays live.
   Why the loop-thread block was replaced: it served no other computation during a sleep,
   and the time park needs no helper thread, so the R0-E1 QEMU 255 shutdown status cannot
   arise. host.c no longer waits and no longer needs CONFIG_HAVE_SCHED. io_tick and host.c
   read the same clock (posix-time CLOCK_MONOTONIC -> ukplat_monotonic_clock,
   lib/posix-time/time.c:223-227). Reruns on the rebuilt image (d42680ce...):
   R1-E2 run.sh only, delta 103, QEMU 1; R1-E3..E5 check-image.sh, deltas 102, 102, 102,
   QEMU 1, PASS (three check-image runs); R1-E6 FAIL branch QEMU 3, check-image exit 1;
   R1-E7 check-binary rows exactly Unikraft.log/now/sleep, exit 1. E1 kept as R0-E1.
2. docs/UNIKERNELS.md gap line: the re-park and clock-failure paths were never exercised;
   stopped clock bounded only by the harness timeout.
3. Frozen-clock wording (host.c, Unikraft.bend, INVENTORY): the check covers a wake without
   clock progress; a fully stopped clock never wakes the park and is bounded only by the
   harness timeout (60 s, status 124).
4. unikraft_sleep.c now cites E1 (R0-E1).
5. UNIKERNELS.md event-loop row: helper-thread wake path exercised (R0-E1), failure at
   shutdown; file names qualified with links.
6. host.c cites console.h:45-46 (declaration :56), definition console.c:42.
7. Counts corrected: R0 had one run.sh-only boot (E2) and three check-image boots (E3-E5);
   R1 the same split, stated exactly in the evidence.
8. UL-004 alignment. Rationale addition: the amendment also drops "exit" from the twins'
   primitives (exit and crash reporting is the termination host layer) and adds the
   inventory sentence (each file, its exported symbols, what it may touch). Aligned: the
   tasks.md 2.1 task line ("console, time, and ingress effect twins ... (exit is the
   inventoried termination host layer)"), design.md:42, explainer.html:107, :118, and :130
   (the task list item mirroring 2.1). The 2.1 note records that images still send
   IO.print through lib-musl and only Unikraft.log uses a twin, so the "Console effect"
   scenario's IO.print twin is a gap.
9. Manifest not regenerated; left to integration.
OpenSpec 1.16.0 (bunx) strict: 44 passed, 0 failed.

Remaining concerns: proposal.md:27 still lists "console, time, exit, and the authenticated
channel ingress" among twins to rewrite (outside this round's allowed paths); the UL-003
"Minimal configuration" scenario's "uses console, time, exit" reads as the monitor's
needs, not twins, and is left. Re-park and clock-failure paths remain unexercised.
