# Task 1 review: enable the signal library and show the fault message

Reviewer, 2026-11-04. Reviewed d0d86d9 against dd53a5f. Read-only except this file.

## Verdicts

1. Spec compliance: APPROVED
2. Record quality: APPROVED (two minor notes)

## Findings, by severity

No blocking or major findings.

Minor:

1. verification/unikernel-fault-qemu.txt, "Exit map runs" (about lines 189-205): several hashes are truncated with "..." (hello-ref 98ea6e4f..., run-hello1.log b206bb42..., die1 db57a219..., exit1 56de3188..., rtsthreads0 eb25a181..., rtsbogus 38837224..., exhaust reference 805668e1..., .config d8f0bedf.../1f66e321...). The task-wide rule is "hashes". All of them match the files still present (checked by prefix), but the record cannot be checked without the workspace. Full 64-digit values would be better, as the other hashes in the file are.
2. verification/unikernel-fault-qemu.txt:58: "-include uk/config.h" is still needed is cited from the trial's failure (line ~299), not re-shown with the template. The report says so (Not exercised); the evidence file does not state it in its own words. One sentence would close it.
3. verification/unikernel-exit-codes.txt: the new table cites the check names but carries no hashes or wall times itself; it points to fault-qemu.txt for them. Acceptable, since the pointer is explicit.
4. Report wording only: "pre-library codesb" is a scratch set name that is not explained in the report (it is in the evidence file).

## Spec compliance detail

- Kraftfile (hosts/unikraft/app/Kraftfile:33-37): carries CONFIG_LIBPOSIX_PROCESS_SIGNAL: 'y' with a comment (experimental, adopted 2026-11-04, UL-006 fault message, needs build.sh's flag). OK. Editing this file rather than mkapp.sh is the ruled case. mkapp.sh is unchanged.
- build.sh (24-28): exactly `UK_CFLAGS="-std=gnu11 -include uk/config.h"`, comment names shutdown.c:63 and signal.h:116 and :287. OK.
- check-fault.sh (42-47): for probe overflow, `grep -n -m 1 -Fx` finds the first exact message line (F) and the first crash line (K). It passes only when both are non-empty and F < K; otherwise it prints MISSING and sets BAD=1. An absent line makes F empty, so it fails. There is no `set -e`, so the failing grep inside the substitution does not abort early. The report and the evidence show the negative control (pre-library image, negsig1) printing "fault message: MISSING ..." and exiting 1, and a no-boot negative on codesb/ovf2. OK.
- verification/unikernel-fault-qemu.txt: leads with the adopted configuration (Result, Configuration, Builds, runs); the whole trial is kept below a double-rule heading marked "history, superseded". The diff is 220 additions, 0 deletions, so the trial is intact. OK.
- verification/unikernel-exit-codes.txt: new "CURRENT MAP" table at the top: 33, 35, 39 (IO.exit(3)), 17, 253; says 19, 251 and 255 not exercised; the 2026-11-03 record is kept. The brief's 253 is shown for both Overflow and Exhaust. OK.
- verification/unikernel-overflow-reference.txt: +1 line, as the brief allows.
- No .bend, host.c, exit_device.c or mkapp.sh change (git diff --stat empty for them; exit_device.c sha256 c4012e46... matches the recorded value). The file list is the touch list plus the ruled Kraftfile plus the lane's record files.
- The script diffs are a handful of lines (build.sh +5/-1, check-fault.sh +9, Kraftfile +5).

## Record quality detail

- Commands, QEMU exit codes, console lines, wall times, build times, and the "Not exercised" paragraphs are present for the fault runs and the exit-map runs. CPU-only, TCG, "no GPU was used or tested" is stated at the head of the evidence file and in the exit-codes table.
- Arena exhaustion: stated honestly. Still 253, no message, now the assertion at deliver.c:125 (handle_self), the earlier "would presumably print the message" prediction called refuted, only -m 1024 run, 4096 and 12288 not repeated, and the second faulting access not traced.
- Shutdown SIGTERM risk with signals (shutdown.c:61-67 versus the non-signal path :100-101): recorded, with "not traced" and the harness-timeout consequence. The report flags it for Task 2's images. The evidence file says Task 2 explicitly.
- musl download flakiness: recorded (three first builds failed on musl-1.2.3.tar.gz, retries succeeded, not a compile error).
- Negative controls are shown for the check script and for check-image.sh.
- Task 2 items (corpus, effects, channel) and the Bend suite, PROOF and OpenSpec are explicitly not claimed.

## What I verified

- Images present under ../writ-unikernel (sigfault: overflow, exhaust; sigcodes: hello, die, exit): the sha256 of all five equal the hashes in the evidence file (07ec5c16..., 51e27500..., 235bb67a..., c17a9adb..., acaa9248...).
- Logs run-ovs1, ovs2, exs1, hello1, die1, exit1, rtsthreads0, rtsbogus exist; ovs1, ovs2 and exs1 match the full hashes recorded; the others match the recorded prefixes.
- Script and file hashes match the evidence: Kraftfile ea319440..., build.sh 67ceb9d2..., check-fault.sh 16e2cc07..., overflow reference 32dab546..., exit_device.c c4012e46....
- Cited Unikraft lines under src/unikraft/lib/posix-process of the work directory: shutdown.c:11 includes signal/signal.h before :14 uk/config.h; :63 calls pprocess_signal_send(pproc_init, SIGTERM); :61-67 the SIGTERM and semaphore wait; :100-101 the 0x80|SIGKILL path; signal/signal.h:116 `#if CONFIG_LIBPOSIX_PROCESS_MULTITHREADING` and :287 the pprocess_signal_send declaration; signal/deliver.c:125 the UK_ASSERT on SS_ONSTACK and :428 the UK_CRASH "Cannot deliver SIGSEGV"; Config.uk:78 LIBPOSIX_PROCESS_SIGNAL. All as cited.
- Not re-run: no builds or boots (the host is loaded and the task is a record review); I did not re-execute check-fault.sh.
