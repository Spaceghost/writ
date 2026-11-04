# Task 3 review: fault message, exit-code map, arena exhaustion, boxes

Reviewer: task reviewer, 2026-11-04. Range e4cdc3d..005f560 (f14b626, 005f560), worktree
lane/unikraft-twins. Read: brief, plan Global Constraints, report, review diff,
UL-006/UL-004, tasks.md, the evidence files, exit_device.c, host.c, scripts, INVENTORY.md,
docs/UNIKERNELS.md, Channel.md. Spot-checked on disk: run logs under ../writ-unikernel/
and recomputed hashes. Ran `openspec validate --all --strict --no-interactive`: 44/44. The
installed CLI is 1.11.0, not the 1.16.0 that AGENTS.md pins, so this is structural only.
No Bend checks were run by me (none are required by the diff: no library `.bend` changed).

## Spec compliance

- ✅ **Fault-message outcome observed and recorded.** The 0.21.0 source path is cited
  (system_error.c, deliver.c sys_error_handler and do_deliver SA_ONSTACK). The trial ran
  twice, and `fault/logs/run-sig{1,2}.log` show `bend: memory fault (machine stack
  overflow?)`, then `deliver.c @ 428 Cannot deliver SIGSEGV for pf at 0x1080069000`, then
  QEMU 253. The compile failure (shutdown.c include order) and the `-include uk/config.h`
  workaround are stated with no source patched. The scratch Kraftfile carries
  `CONFIG_LIBPOSIX_PROCESS_SIGNAL: 'y'` (line 34). The template was not changed.
- ✅ **Controller ruling presented honestly.** The evidence (fault-qemu.txt:15-22,
  :102-106), UNIKERNELS.md ("Faults" and selection item 3), tasks.md 2.3 and the report
  all say the trial was not adopted, that delivered images crash with no message, and
  that a decision is pending. Nobody claims UL-006 is met. The re-raise interpretation is
  marked "not traced".
- ✅ **Exit map moved off QEMU 1.** The written values are 0x08, 0x09, 0x10..0x7c, 0x7d,
  0x7e and 0x7f, so q ∈ {17, 19, 33..249 odd, 251, 253, 255}. q is always odd, so 0 and
  124 cannot occur, and 1 cannot occur either. The clamp is documented: 0x10 + 0x6c =
  0x7c < 0x7d (exit_device.c:114, :37-39). The collisions with timeout's 125/127 (statuses
  46/47) are stated correctly.
- ✅ **exit() vs _exit().** I confirmed this against the musl source built into these
  images. `musl-1.2.3/src/exit/exit.c:27-33` has `exit` call `__funcs_on_exit()` before
  `_Exit`, and `src/unistd/_exit.c` is just `_Exit(status)`. The generated C agrees:
  err_fail is `_exit(1)` (overflow.c:538-542), CID_Halt/CID_Exit is `exit()` after
  io_sync (:3183-3187), and `main` returns only 0 or 1 (:3270 onward). A program cannot
  fool the mark. Bend reaches `exit()` only through IO.exit/IO.die, which really are
  program statuses, and it has no path to `_exit`. host.c's own stops use `_exit`. A
  failed `atexit` can only misname an outcome as 17 or 19, never as success (:143-147).
  Both sides of the distinction are shown by boots: die 35 and t3noport 17.
- ✅ **"HOST BINDING CODE, NOT WRIT POLICY"** header (exit_device.c:2-8). The new code is a
  constructor, a flag and a pure status-to-value function. Nothing in it interprets a
  Writ value.
- ✅ **Scripts consistent.** check-image.sh, check-corpus.sh (expects 33), check-channel.sh
  and run.sh have their comments and expectation updated. Each status check compares
  `$Q` with `$XQ` and sets BAD=1 on a mismatch. The old capture fails under
  `WRIT_NO_BOOT=1` (QEMU 1, expected 33), and that negative evidence is recorded in
  corpus-qemu.txt.
- ✅ **Reruns.** The logs on disk give hello 33, die 35, exit 39, overflow 253, ex1/ex2/ex3
  253 (crashes at 3.34/21.26/111.37 s, same rip 0x1c1f0d), sig1/sig2 253 and t3noport 17.
  The corpus3 logs at -m 4096 and -m 32 each show 782 `^PASS` lines and status 33.
  corpus3x has flow/transfer/example/gpuexample{,2,3} at 33, and the gpuexample first-boot
  `.raw` holds the PM line. Every hash I recomputed matches the record: exit_device.c,
  host.c, unikraft_take.c, Exhaust.bend, the five codes images, fault overflow image and
  C, the monitor C and image, probe, build-sig.sh, split.py, tests-qemu/.dbg, tests.c
  b50856fb, the four corpus3x images, and the codesa/codesb generated C.
- ✅ **Dated notes.** All six earlier evidence files open with the same CODE MAP NOTE and
  keep their recorded values.
- ✅ **Arena exhaustion.** Exhaust.bend's accumulator-then-walk keeps all cells live, and
  its comment says what a printed sum would mean. The explanation is consistent: rbx
  scales with -m, and as a word index ×8 it gives ≈1.0 GiB, ≈4 GiB and ≈12 GiB. The 12 GiB
  case passes the initial 8 GiB reservation. The crash is the first write to a fresh
  arena page, and the runtime's bound is never reached. The limit appears in tasks.md 2.3
  and UNIKERNELS.md. INVENTORY states it only in a misleading way (Important 1).
- ✅ **UL-006 distinctness (as asked).** The fault (253) is distinct from success (33),
  corpus failure (Test.bend:6 `IO.die(Unit, 1, ...)`, 35) and runtime stops (17). Arena
  exhaustion shares 253, so UL-006 is not met. That is recorded, and 2.3 stays open. The
  shared 17 for all runtime stops, including `main` returning 1 on a bad `+RTS`, is stated
  in exit_device.c:56-59, INVENTORY:105/112 and fault-qemu.txt:138-141.
- ✅ **Boxes.** 2.1 is open (IO.print has no twin; the subject is scaffolding). 2.3 is open
  with both reasons. 2.4 and section 3 are untouched. UL-006 is unchanged in the diff and
  states no number.
- ✅ **Carried nits.** host.c:6-8 now points at INVENTORY. The `WRIT_UK_BUSY_POLLS` 100-poll
  back-off is correct: the counter resets on any byte and only counts while
  `writ_uk_fill` is nonzero. It is documented in host.c, unikraft_take.c, Channel.md and
  INVENTORY, the split-frame run is recorded, and "not traced" is stated.
- ✅ **Hygiene.** The only `.bend` changes are under scripts/unikernel. Nothing built is
  committed. The only absolute path in hosts/ is the pre-existing elided `/mnt/...`
  mention in INVENTORY:120. The record directory and the "Fix round 1 re-review" section
  of task-2-review.md are committed (f14b626).
- ⚠️ **Report completeness.** The report does not mention the OpenSpec run (only the
  activity log does, "OpenSpec 44/44"), and it does not say which CLI version was used.

## Critical

None.

## Important

1. **exit_device.c:24-27, :45-47, :57-58 and INVENTORY.md:105, :112-113 say arena
   exhaustion maps to 17, which contradicts the evidence.**
   - What: the 0x08 row lists "the runtime's err_fail, including arena exhaustion", and
     the INVENTORY limit sentence says "arena exhaustion has no value of its own among
     them [the 17s]". Every forced exhaustion on this kernel was a Unikraft crash, 253.
   - Why: the host-binding header and the trust inventory are what a reader consults for
     what each code means, and both lead to the wrong one. AGENTS.md asks that captured
     outputs and explanations stay in sync.
   - Fix: qualify both places. For example: "the runtime's out-of-memory fail-stop
     (ERR_HEAP), if reached; on Unikraft 0.21.0 under QEMU it was not reached at -m 1024,
     4096 or 12288: arena exhaustion is a crash, 253 (verification/unikernel-fault-qemu.txt)".
     Also add that limit to INVENTORY's limit sentence.

## Minor

1. **Stale outcome claims in hosts/.** INVENTORY.md:115 still names only
   verification/unikernel-exit-codes.txt as the evidence for the map. Add
   unikernel-fault-qemu.txt and make clear that the table is the current map.
   Channel.md:38 and effects/unikraft_sleep.c:13 still say a leftover `io_work` thread
   "turns success into QEMU 255". UNIKERNELS.md was updated to read "(now 19 ... by
   reading the map; not rerun)". Use the same wording in these two places, or say "255
   under the first map".
2. **musl citation.** exit_device.c:53-55 asserts the musl behaviour without a path. Cite
   `musl-1.2.3/src/exit/exit.c:27-33` and `src/unistd/_exit.c`, the lib-musl origin
   pulled by this build.
3. **err_fail's own `_exit(1)` path → 17 was not booted.** Only host.c's `writ_uk_fail`
   was booted (t3noport). The mechanism is the same call, but say in fault-qemu.txt:44
   or :138 that 17 was exercised through host.c only. A one-line check would cover it:
   `+RTS` with a bad argument, so `main` returns 1. That outcome is also asserted to be 17
   and was not booted.
4. **The UL-006 decision has two independent halves.** Adopting the signal trial would
   close only the message half. Exhaustion would still share 253, and with signals it
   would presumably print the same memory-fault line (fault-qemu.txt:199-201). One
   sentence in tasks.md 2.3 or the report's Concerns would keep the decision from being
   read as "adopt signals ⇒ 2.3 done". tasks.md 2.3 could also name corpus failure's code
   (Test.bend's `IO.die(…, 1, …)`, 35), since UL-006 requires distinctness from it.
5. **Overflow and Exhaust have no checking script.** Both were run with bare run.sh, so
   nothing turns a changed outcome into a nonzero exit, as the Global Constraints
   require. The status is still recorded. A `check-image.sh … 253` with a masked
   crash-screen reference, or a small check-status wrapper, would close this. It is
   carried over from earlier tasks.
6. **gpuexample PM-line anomaly.** It is recorded honestly, with two clean reruns and
   "cause not determined". Since the line follows the port write, it is a harness flake
   risk for check-image.sh. Add it to docs/UNIKERNELS.md's "Open" list so it does not
   live only in corpus-qemu.txt.

## Assessment: Needs fixes

Important 1 is a small documentation correction in exit_device.c's header and INVENTORY.
It needs no rebuild of the delivered images beyond a hash update for exit_device.c,
because only comments change. Compare implementation tokens before and after as AGENTS.md
asks, and record the new hash. Once it is fixed (Minor 1 is worth taking at the same
time), I would approve. The map, the atexit discrimination, the evidence, the trial
record and the box states are sound and match what is on disk.
