# Final whole-branch review: lane/unikraft-signals

Reviewer: final whole-branch reviewer, 2026-11-04. Branch head 4e2b8ec, merge base 5cd0ace,
master 4126850. Read-only review; this file is the only write.

**Assessment: Needs fixes before merge** (small documentation fixes in the trust inventory,
plus one mechanical merge conflict; no script, configuration, or evidence defect found).

## Findings, by severity

### Must fix before merge

1. **Trust inventory states a shutdown behaviour the adopted library no longer has.**
   `hosts/unikraft/INVENTORY.md:109` (the exit-map table, value 0x09 / QEMU 19) says
   "posix-process stores the signal number, or `0x80 | SIGKILL` for an init process still
   running at shutdown". The branch's own evidence says that with
   `CONFIG_LIBPOSIX_PROCESS_SIGNAL` posix-process instead sends SIGTERM to a still-running
   init process and waits on its exit semaphore (`lib/posix-process/shutdown.c:61-67`; the
   0x80|SIGKILL store is the non-signal path, :100-101; verification/unikernel-fault-qemu.txt,
   "Exit map runs"). Every shipped image now has the library, so the cell is false for every
   image. Fix: replace the parenthesis with "posix-process stores the signal number for a
   signal death; with the signal library (every template image) an init process still running
   at shutdown is sent SIGTERM and waited for (`shutdown.c:61-67`), so the outcome is 19 if it
   dies or the harness timeout if it does not; neither exercised (0x80 | SIGKILL is the
   non-signal path, :100-101)".
   The same stale reading is in `docs/UNIKERNELS.md:115` ("turned success into QEMU 255 (now
   19, a signal death, by reading the map; not rerun)"). Fix: "(under the current map and the
   signal library: 19 if the SIGTERM sent at shutdown ends the helper, otherwise a hang to the
   harness timeout; not rerun)".

2. **Inventory row for `check-fault.sh` omits the new check.**
   `hosts/unikraft/INVENTORY.md:146` lists what check-fault.sh checks (program lines, crash
   screen at 253, QEMU status) but not check 2a, added on this branch: for the probe named
   `overflow`, the line `bend: memory fault (machine stack overflow?)` must appear before the
   first `CRIT: Unikraft Crash` line. Fix: add that clause to the "Role" cell, and note that the
   overflow reference now lists the message line.

3. **Inventory evidence pointer still describes the trial.**
   `hosts/unikraft/INVENTORY.md:118-121`: "Evidence: `verification/unikernel-fault-qemu.txt`
   (the current map, the fault-message trial, arena exhaustion), `verification/unikernel-corpus-qemu.txt`
   ("Task 3 rerun", the corpus at QEMU 33)". Both now point at sections that are history.
   Fix: "(the adopted signal configuration: fault message, exit map re-recorded, arena exhaustion
   with signals; the earlier trial kept as history), `verification/unikernel-exit-codes.txt`
   ("CURRENT MAP, RE-RECORDED WITH POSIX SIGNALS"), `verification/unikernel-corpus-qemu.txt`
   (the signals record, 782 PASS at QEMU 33)". The same paragraph's limit sentence (:115-117) is
   still accurate.

4. **Merge conflict with master (mechanical).** `git merge-tree master HEAD` reports a content
   conflict in `openspec/traceability/unikernel-library-runtime.md`: master (linuxu lane)
   changed the UL-002 and UL-007 rows, this branch the adjacent UL-006 row. Resolution: keep
   master's UL-002 and UL-007 rows and this branch's UL-006 row; nothing else in the file
   differs. `docs/UNIKERNELS.md`, `tasks.md`, and `unikernel-pins.txt` auto-merge. Rerun
   OpenSpec strict after the merge and regenerate `verification/source-sha256.txt` on master
   (it still has the old overflow-reference hash 5e19eec7...; the branch rightly did not touch
   the manifest).

### Optional (follow-ups, not blocking)

5. Same stale SIGKILL reading in C comments: `hosts/unikraft/exit_device.c:31-33` and
   `hosts/unikraft/effects/unikraft_sleep.c:10-15`. The plan forbids touching exit_device.c
   unless the exit map breaks, so leave it for a comment-only follow-up, with an
   implementation-token comparison as AGENTS.md requires.
6. `openspec/traceability/unikernel-library-runtime.md` UL-005 row still cites
   unikernel-corpus-qemu.txt "Task 3 rerun" (now history) as the executed 782/33 evidence;
   add the signals record (sets sigcorpustests/sigcorpus). The UL-004 row cites
   unikernel-fault-qemu.txt "Channel monitor", which is now inside the history section; point
   at unikernel-channel-qemu.txt's current (signals) record as well.
7. `verification/unikernel-exit-codes.txt:28-29`: "Every value equals the map recorded before
   the library (unikernel-fault-qemu.txt, trial section)". The pre-library map is in that
   history block's "Runs with the new map (template configuration)" section, not the trial
   configuration; say "earlier (history) section, 'Runs with the new map'".
8. Box 2.3 is checked while its text asks for "distinct exit codes" and exhaustion still shares
   253. This follows Josh's q2 ruling and the 1.1 "recorded outcome" precedent, and the box note,
   the traceability gap column, and UNIKERNELS.md all say plainly that this half of UL-006 is
   not met. Acceptable as recorded; any future feature-acceptance or archive step must not count
   UL-006 as satisfied (the requirement is still unmet).

No Critical findings.

## What I verified, and how

Security and contribution rules
- `git diff --stat master...HEAD -- '*.bend'` is empty: no Bend source changed. (The two-dot
  `git diff master` shows master's own later edits, e.g. hosts/genode/INVENTORY.md; those are not
  this branch.)
- `git diff master...HEAD --stat -- hosts/unikraft/exit_device.c hosts/unikraft/host.c
  hosts/unikraft/scripts/mkapp.sh` is empty. Host code changes are one Kconfig line plus comment
  (Kraftfile), one UK_CFLAGS edit plus comment (build.sh), one 6-line check plus comment
  (check-fault.sh). None makes a policy, grant, label, accounting, or release decision; the
  check script is test tooling that only compares console lines and status.
- UL-004 still holds: the library is Unikraft's own posix-process code selected by
  configuration, and the flag is a compiler option; no new Writ kernel-specific code. The trust
  inventory names both: INVENTORY.md:135 (Kraftfile row, EXPERIMENTAL, pin) and :140
  (build.sh row, flag and shutdown.c / signal.h:116/287 reason); docs/UNIKERNELS.md:136-152
  ("Image configuration pins"); verification/unikernel-pins.txt "Unikraft image configuration
  pins" with Config.uk:78 and the selected libraries.
- spec.md is untouched; the UL-006 requirement and box 2.3 text are verbatim (diff shows only
  the checkbox and note lines).

Evidence integrity
- Hashes recomputed and matching every citation: Kraftfile ea319440...; build.sh 67ceb9d2...;
  check-fault.sh 16e2cc07...; overflow reference 32dab546...; exhaust reference 805668e1...;
  exit_device.c c4012e46....
- Every sha256 in the current (signals) section of unikernel-binary-check.txt appears in the
  corpus, effects, or channel record; the ten unmatched hashes are all in the history section.
- Set names (sigfault, sigcodes, sigeffects, sigchannel, sigcorpus, sigcorpustests), the exit
  map (33/35/39/17/17/253/253), "two boots", "-m 1024 only for exhaustion", and 782 PASS agree
  across fault-qemu, exit-codes, corpus-qemu, pins, matrix, traceability, tasks.md, and
  UNIKERNELS.md.
- Not-run items are stated as not exercised everywhere they arise: signal value 19, non-halt
  251, statuses above 108, the shutdown SIGTERM-and-wait path, exhaustion at 4096/12288 with
  signals, KVM/Firecracker, GPU (GpuExample's CPU-fallback line is explicitly "not GPU
  evidence").
- The wrong exhaustion prediction is recorded as refuted (fault-qemu "Result" 3 and "Arena
  exhaustion with signals"; tasks.md; matrix E4 note; UNIKERNELS.md:97-98).
- The trial section is headed "history, superseded by the adopted configuration"; corpus,
  effects, channel, and binary-check files each mark "CURRENT RECORD" and a history rule.
- Load caveat ("wall times are indicative only", with load averages) present in the fault,
  corpus, effects, and channel records; exit-codes defers its wall times to fault-qemu.

Script correctness
- Read build.sh, check-fault.sh, and the Kraftfile in full. The flag is on the single kraft
  invocation in build.sh, quoted correctly, so every build.sh build gets it; mkapp.sh copies the
  template Kraftfile unchanged and refuses to overwrite a differing one, which is why the lane
  used new set names (a stale pre-library app directory therefore fails loudly rather than
  building without the library). The linuxu lane on master builds outside build.sh and the pin
  text is scoped to qemu/x86_64 images from hosts/unikraft/app/, so that is consistent.
- `sh -n` passes. Exercised check-fault.sh with WRIT_NO_BOOT=1 on synthetic logs in the
  scratchpad: message before the crash line -> PASS, 0; message absent -> FAIL, 1 (also the
  reference diff); message after the crash line -> FAIL, 1 (the reference diff alone passed
  here because the crash line is filtered as a Unikraft log line, so check 2a is what catches
  ordering); probe named `exhaust` -> check 2a not printed. The check applies only to the
  overflow probe, as intended.
- OpenSpec 1.16.0 `validate --all --strict --no-interactive` on the worktree: 44 passed,
  0 failed.

Cross-task consistency
- Grepped docs/UNIKERNELS.md, INVENTORY.md, tasks.md, traceability, the matrix, and the
  current evidence files for "no message", "without signals", "trial", "not adopted",
  "not the template", "delivered configuration", "SIGKILL", "0x80". Remaining hits are either
  correct (exhaustion still has no message; negative control "built without signals"; history
  sections) or the findings above (1, 3, 5, 6).

Not verified by me: I did not rebuild or boot any image or rerun `bend Tests.bend` (Task 3
reports 782 PASS on Linux); `bend PROOF.bend` was not run by the lane and need not be (no
policy or proof change). The Task 3 task review was running in parallel and is not yet in the
record directory.

## Open for add-unikernel-library-runtime after this branch

- UL-006 exhaustion half: arena exhaustion has no message and no code distinct from a fault
  (253); only -m 1024 rerun with signals. Needs a runtime-side bound reached before guest RAM
  runs out, or an eager backing strategy, without weakening the requirement.
- Unexercised exit-map values with the library: 19 (signal death), 251 (non-halt), >108
  (255), and the shutdown SIGTERM-and-wait path (an io_work helper image would reach it).
- The `-include uk/config.h` workaround and the EXPERIMENTAL library are pins; revisit when
  the Unikraft pin moves (upstream include-order fix would let the flag go).
- 2.1: authenticated ingress subject (UL-008) and an `IO.print` twin; channel resync after a
  partial frame.
- 2.4 multi-lane (plan unikraft-lanes), 3.1 hardware-accelerated boot, 3.2 appliance rules
  and reproducible builds (images embed build time), 3.3 (plan unikraft-closing); 1.3 linuxu
  stays open.
