# Task 1 report: enable the signal library and show the fault message

Status: DONE_WITH_CONCERNS (concerns at the end). Implementer, 2026-11-04.

## What changed

| File | Lines | Change |
| --- | --- | --- |
| `hosts/unikraft/app/Kraftfile` | 33-37 (+5) | `CONFIG_LIBPOSIX_PROCESS_SIGNAL: 'y'` with a 4-line comment (experimental, adopted 2026-11-04 for UL-006's fault message, q2; needs build.sh's flag). This is the template `mkapp.sh` copies; `mkapp.sh` itself is unchanged (see concern 1). |
| `hosts/unikraft/scripts/build.sh` | 24-28 (+4 comment, 1 line changed) | `UK_CFLAGS="-std=gnu11 -include uk/config.h"`; comment names shutdown.c:63, signal.h:116 and :287, no source patched. |
| `hosts/unikraft/scripts/check-fault.sh` | 13-15 (header), 42-47 (+6) | Check 2a: for probe `overflow`, the log's first line exactly `bend: memory fault (machine stack overflow?)` must precede the first `CRIT: Unikraft Crash` line; prints `fault message: before the crash screen` or `MISSING ...` and fails. |
| `verification/unikernel-overflow-reference.txt` | +1 | Second program line `bend: memory fault (machine stack overflow?)` (identical to the trial's `$W/fault/sig-ref.txt`). |
| `verification/unikernel-fault-qemu.txt` | rewritten | Adopted configuration's evidence first; the whole earlier file kept below a heading marking it as the trial (history, superseded). |
| `verification/unikernel-exit-codes.txt` | +23 at the top | "CURRENT MAP, RE-RECORDED WITH POSIX SIGNALS" table; the 2026-11-03 record kept as recorded. |

Not changed: `exit_device.c`, `host.c`, any `.bend`, `mkapp.sh`, docs, openspec (Task 3).

## Commands and results

Environment: Bend 2.0.39 on PATH, `BEND_NO_TELEMETRY=1`, `W=/mnt/MediaVolume/Media/src/github.com/spaceghost/writ-lanes/writ-unikernel`. All boots QEMU 11.1.2 TCG emulated, `-no-reboot`, device 0xf4, `+RTS --threads 1 --gpu off`, CPU only (no GPU test).

1. `mkapp.sh sigfault`, `mkapp.sh sigcodes`: OK; `$W/sigfault-unikraft/Kraftfile` sha256 equals the template (ea319440...). New set names because the trial's `fault` set holds a hand-edited Kraftfile that mkapp.sh refuses to overwrite (kept as trial history).
2. `bend scripts/unikernel/{Overflow,Exhaust,Hello,Die,Exit}.bend -o ...`: all five generated C files byte-identical to the recorded hashes (1e273e1a, 8d79a44c, 260b70a3, 94048ae7, 7b1b4c43).
3. `build.sh` per probe. First pass: hello OK (167 s), exit OK (69 s); overflow, exhaust, die failed fetching `musl-1.2.3.tar.gz` (wget left no file; `tar: Cannot open`), not a compile error. Retried same command: overflow 141 s, exhaust 70 s, die 76 s, all OK. Resolved .config versus the pre-library codesb: only SIGNAL=y, EXECVE=y, UKBINFMT=y (selected), SIGNALFD unset.
   Images: overflow 07ec5c16..., exhaust 51e27500..., hello 235bb67a..., die c17a9adb..., exit acaa9248... (full hashes in the evidence file).
4. `WRIT_NO_BOOT=1 check-fault.sh fault sig1 overflow <new ref> 253` -> PASS, 0 (trial capture); `... codesb ovf2 ...` -> FAIL, 1 (no-signal capture).
5. `check-fault.sh sigfault ovs1 overflow verification/unikernel-overflow-reference.txt 253 60 4096` -> program lines equal / crash screen present / fault message before the crash screen / QEMU exit 253 / PASS, exit 0, wall 17.8 s. Console:
   ```
   overflow probe start
   bend: memory fault (machine stack overflow?)
   [   17.370422] CRIT: [libposix_process] <deliver.c @  428> Cannot deliver SIGSEGV for pf at 0x1080069000
   [   17.372288] CRIT: Unikraft Crash - Ijiraq (0.21.0~7351f8b)
   ```
   rip 0x129811 = sys_error_handler, deliver.c:428 (addr2line), same as the trial.
6. `... ovs2 ...` -> PASS, 0, 253, wall 13.5 s.
7. Negative control `check-fault.sh codesb negsig1 overflow <new ref> 253 60 4096` (pre-library image) -> program lines DIFFER, fault message MISSING, 253, FAIL, exit 1.
8. `check-fault.sh sigfault exs1 exhaust verification/unikernel-exhaust-reference.txt 253 120 1024` -> PASS, 0, 253, wall 3.7 s. New crash site: `deliver.c @ 125 Assertion failure: !(altstack->ss_flags & 1)` (handle_self), no `bend:` line.
9. `check-image.sh sigcodes hello1 hello ... 33 "" 60 1024` -> diff empty, 33, PASS; `die1 die ... 35` -> PASS; `exit1 exit ... 39` -> PASS. `run.sh sigcodes rtsthreads0 hello "+RTS --threads 0"` -> 17; `rtsbogus "+RTS --bogus"` -> 17. Negative control `check-image.sh sigcodes neg1 hello <exit ref> 39` -> FAIL, exit 1 (33, diff not empty).

Exit map: 33 / 35 / 39 / 17 / 253 all unchanged. Not BLOCKED.

Log hashes are in `verification/unikernel-fault-qemu.txt`. Script hashes: build.sh 67ceb9d2..., check-fault.sh 16e2cc07..., Kraftfile ea319440..., overflow reference 32dab546....

## Not exercised

- Signal value 19 (no program here ends by a signal; io_work leftover thread not built), non-halt 251, statuses above 108 (255).
- Exhaust at -m 4096 and 12288 with signals (only 1024 run).
- Corpus, effects, channel images with the library (Task 2). `bend Tests.bend`, `bend PROOF.bend`, OpenSpec validation: not run (no Bend or spec change in this task; Task 3 runs the suite and OpenSpec).
- That `-include uk/config.h` is still needed is cited from the trial's failure, not re-shown with the template.

## Concerns

1. The brief and plan put the Kconfig line "in the Kraftfile template in mkapp.sh", but mkapp.sh has no inline template; it copies `hosts/unikraft/app/Kraftfile`. I edited that file (not on the plan's touch list) and left mkapp.sh unchanged. The linuxu lane may touch the same template; the edit is 5 lines appended after `CONFIG_LIBNS16550_COM2`.
2. The template runs used new sets `sigfault` and `sigcodes`, not `fault`, so the trial's scratch set stays intact; mkapp.sh would refuse it anyway.
3. Arena exhaustion with signals now crashes on a posix-process assertion (nested delivery on the alternate stack) instead of in heap_alloc_miss. Still 253 with no message, which matches the recorded limit, but the earlier "would presumably print the message" note is refuted and recorded so.
4. With signals, posix-process shutdown sends SIGTERM to a still-running init process and waits on its exit semaphore (shutdown.c:61-67). A process that never ends after SIGTERM would hang the image until the harness timeout instead of getting 0x80|SIGKILL. Not observed (no program here reaches it). Relevant to Task 2's effects/channel images.
5. The musl tarball is fetched on every clean build. musl-libc.org was slow and three builds failed on the download before their retries succeeded. Task 2's long corpus build can hit the same thing.
