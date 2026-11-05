# Task 1 review (diff 3cf56c0..d14eb71)

Verdict 1, spec compliance: APPROVED
Verdict 2, record quality: APPROVED (one minor wording fix recommended, not blocking)

## Findings, by severity

No blocking findings.

1. Minor, verification/unikernel-lanes-qemu.txt:24-26 (Result 2). The text says CPU#1 is
   listed "halted" "at pool_open, at pool_work and at the crash". The gdb logs show an
   `info threads` listing only at pool_work and at the crash
   ($W/lanes/logs/gdb-lanes-t2-s2.log lines 20 and 29; gdb2 log line 26). The pool_open
   stop ran `bt 3` only (gdb-lanes-s2.cmd). Suggest "at pool_work and at the crash".
2. Minor, :24-26. "(firmware range)" for 0xfd5fd is an interpretation (the usual
   BIOS AP wait region), not a measured fact; the observed facts are the address and
   gdb's `[halted ]` flag. Suggest "an address below 1 MiB, outside the guest image".
3. Minor, :15-17. "The second lane runs" is the heading of Result 1 and is qualified in
   the same item ("only on the boot vCPU"), so it is not misleading, but "interleaves
   cooperatively on vCPU 0" in the heading would be safer for a skimming reader.
4. Informational, :68 and report concern 4. The set's Kraftfile comment "Single lane
   (UL-005): one virtual CPU" is stale beside the changed value. Recorded; the plan allows
   only the value to change. Task 3 must not quote that comment.
5. Informational. The evidence file does not itself say two probe builds were made against
   a plan allowance of one; only the report (concern 3) does. The controller has accepted
   it. Optional one line in "Not exercised".
6. Informational, report line "HAVE_SMP selected by the platform": the brief said
   "selected"; the record correctly says `default y if UKPLAT_CPU_MAXCOUNT > 1`.

## Verdict 1 detail

- run.sh (read in full): the optional 7th argument only builds `SMP=()` (:35), emitted
  as `"${SMP[@]}"` in both QEMU invocations (:53, :57) and `${SMP[*]:+...}` in the
  logged line (:50). Empty array expands to nothing; no `set -u` in env.sh. Without the
  argument the logged command is byte-identical in form (run-hello-default.log shows
  `-m 1024 -cpu max`). With it, the log order matches the executed order. Usage text and
  comment are the only other changes.
- Call sites: check-image.sh:28, check-channel.sh:33, check-fault.sh:30 pass six
  arguments exactly as before; none passes a 7th. Unchanged.
- check-corpus.sh: with no 5th/6th argument, `$5$6` is empty and the path is the old
  exec of check-image.sh with the same arguments (T and M defaults 600 and 4096 are
  the old ones). With either given it removes the old capture, boots through run.sh
  with `+RTS --threads ${5:-1} --gpu off` and `${6:-1}`, refuses a missing log, and
  sets WRIT_NO_BOOT=1. Compatible. WRIT_NO_BOOT=1 from the caller skips the boot.
- Lanes set: diff of the template Kraftfile against `$W/lanes-unikraft/Kraftfile`
  shows one line, MAXCOUNT 1 -> 2. Hashes re-computed and equal the record:
  Kraftfile c5ce5a37..., template ea319440... (unchanged in tree), .config 2091895e...;
  the four image and .dbg hashes, gen hello.c and lanes.c, Hello.bend, Lanes.bend,
  run.sh, check-corpus.sh and build.sh all match. `.config` contains
  UKPLAT_CPU_MAXCOUNT=2 and HAVE_SMP=y per the record; LIBPOSIX_FUTEX was already y
  and is stated so.
- Runs: all eight run logs under `$W/lanes/logs/run-*.log` re-read: console lines, exit
  codes (33, 33, ..., 253 for lanes t2), `-smp` and `-m 1024` in the logged command,
  wall times all agree with the table. The hello-default run confirms the no-`-smp` log.
- uk_lcpu_start claim: grep under `$W/src/unikraft` (RELEASE-0.21.0), *.c *.h *.S, finds
  only the definition lib/uklcpu/lcpu.c:297, the declaration
  lib/uklcpu/include/uk/lcpu/pm.h:118 and the export in lib/uklcpu/exportsyms.uk:18; no
  caller. plat/kvm/x86/setup.c:149-154 calls only uk_lcpu_mp_init under
  CONFIG_HAVE_SMP, as stated. (The record omits the exportsyms.uk hit, which is not a
  caller.)
- Touch list: the Task 1 commit changes only run.sh, check-corpus.sh,
  verification/unikernel-lanes-qemu.txt and the record directory. No .bend, host.c,
  exit_device.c, runtime, generated C, Unikraft or template change. build.sh unchanged.

## Verdict 2 detail

- Full 64-character sha256 for every input, output and script; versions of QEMU, Unikraft,
  kraft and Bend given.
- CPU-only TCG stated at :5-9 and :202; no GPU use stated; host parallelism disclaimed.
- Load caveat (load average 26 to 76, wall times indicative) at :12-13.
- Crash: exact line `<alloc.c @  198> Assertion failure: metadata->base != ((void *) 0)`,
  QEMU 253, and the chain idle_thread_fn (schedcoop.c:199) -> uk_sched_thread_gc
  (sched.c:282) -> uk_thread_release (thread.c:1023, thread "main") ->
  uk_free_ifpages (alloc.c:198), matching the gdb trace 2 and 3 text. What is unknown
  (shipped template, not built) is stated.
- "Second vCPU halted" is stated as observed: gdb `info threads` at two stops shows
  `CPU#1 [halted ]` at 0xfd5fd, and breakpoint 3 on uk_lcpu_start is never hit
  (log: breakpoint set, never reported). The "never used" conclusion also rests on the
  source grep, which is cited separately. See findings 1 and 2 for the two overstatements.
- Nothing claims SMP parallelism: the text says interleaved on one vCPU, atomics under
  cross-CPU contention not exercised, and a row claim by the second lane not shown.
- Not run by this review: no image was booted or rebuilt; run results were checked
  against the retained logs and gdb logs, not re-executed.
