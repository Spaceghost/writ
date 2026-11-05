# Task 2 review (reviewer, 2026-11-05)

Range reviewed: ef4523d..68e32eb (one commit, 7 files, 818 insertions, 0 deletions).

## Verdicts

1. Spec compliance: APPROVED
2. Record quality: APPROVED (two minor wording gaps, not blocking)

## Findings, by severity

No blocking findings.

Minor:

1. verification/unikernel-effects-qemu.txt:25 and unikernel-channel-qemu.txt:19 list "19 signal" in the exit map,
   but neither file says plainly that signal value 19 was not exercised. The effects file does say the R0-E1
   io_work variant, the one that would reach shutdown.c:61-67, was not rebuilt (effects:42-46 and :160-162), and
   the channel file says the SIGTERM path is not reached (channel:37-40). A reader can infer 19 from this, but a
   one-line "signal 19 not exercised" in each "Not exercised" list would be unambiguous. Optional.
2. verification/unikernel-corpus-qemu.txt (Not exercised paragraph, about lines 128-132) says nothing about the
   SIGTERM-at-shutdown path. It says only "No image hung at shutdown" (line ~49). The corpus is one lane with no
   helper thread, so it is harmless, but the scope is implied rather than stated. Optional.
3. Load figure differs between files: corpus says load 21 to 277, effects and channel say 42 to 54 (the samples
   taken during those runs). Both are caveated as indicative. Consistent with the report. No action.
4. The scratch ProbeFail.bend (afc19e2e...) lives under $W/sigeffects/scratch and is hash-recorded as "scratch,
   never committed". git status shows no stray file in the tree (only the controller's progress.md and
   activity.log are modified). No action.

## 1. Spec compliance

- Files refreshed: unikernel-corpus-qemu.txt, unikernel-binary-check.txt, unikernel-effects-qemu.txt,
  unikernel-channel-qemu.txt, unikernel-pins.txt. Each has new hashes, counts, wall times and the library
  (CONFIG_LIBPOSIX_PROCESS_SIGNAL: 'y', Config.uk:78) and the flag (UK_CFLAGS="-std=gnu11 -include uk/config.h").
  The build-time note is in corpus:~60, effects (Images), channel (Image) and pins (last paragraph of the new section).
- Corpus count is 782. I extracted the PASS and ALL lines from $W/sigcorpustests/logs/run-tests-m4096.log and the
  captured section of verification/unikernel-corpus-linux-reference.txt: 782 PASS each and the diff is empty
  (SAMEPROG). The reference sha256 (491859af...) is unchanged.
- Touch list: the changed files are verification/unikernel-*.txt plus the lane's own record files
  (activity.log, task-2-report.md). All are inside the plan's "verification/unikernel-*.txt" scope. No .bend,
  host.c, exit_device.c, Unikraft, script or doc change (git diff --stat over hosts and *.bend is empty; host.c and
  exit_device.c hashes equal the ones recorded).
- No overwrite of old evidence: 0 deleted lines in the verification diff. Each file gets a new CURRENT RECORD section
  on top and the old record is kept under a "History" rule, with new set names (sigcorpustests, sigcorpus,
  sigeffects, sigchannel). Pins adds a new section; nothing replaced. The history rules say what they are.
- Channel reference files left unchanged: ACCEPTABLE, no fix needed. check-channel.sh byte-diffs the whole file, so
  an added note would break the check; the intent of the brief ("refresh") is that the evidence names the library
  and flag and shows the boots reproduce the references. unikernel-channel-qemu.txt does that: it lists the four
  references with their sha256 (the values match sha256sum on the files in the tree today), shows client diff and
  console diff empty for accepted and denied, and states at lines 200-201 that the references are unchanged
  because the boots reproduce them exactly. The negative control (denied order against accepted refs) fails, which
  shows the check can fail. The plan's acceptance ("same program lines as its reference") is better met by
  unchanged files than by edited ones.

## 2. Record quality

- Hashes are full 64 hex digits. I searched the added lines for "hex...": no truncation in any evidence file. (The
  report uses truncated hashes in prose, e.g. "ea319440...", "08c58ee1..."; the evidence files carry full ones.)
- Self-contained: each file has its own configuration, build commands, run commands, console lines, exit codes,
  wall times, W definition and the cited reference names. Binary-check lists all nine .dbg files with their
  effect rows and exit status (3 groups PASS exit 0; probe, probefail, monitor FAIL exit 1, as before).
- CPU-only: stated in corpus, effects and channel ("CPU only: not native, not an accelerated boot, no GPU was used
  or tested"; the GpuExample CPU-fallback line is labelled not GPU evidence).
- Not-exercised sections: R0-E1 io_work variant named as not rebuilt (effects), SIGTERM path stated as not reached
  by the probe and monitor, channel measure.sh and split.py named, binary-check negative control not rerun (in the
  report; see minor 1 and 2 for the wording gaps).
- Load and wall caveat: stated in corpus, effects and channel ("indicative only"); the 163 min build figure is
  qualified by the concurrent builds in the corpus file and the report.
- No mistakable success claims: the unrun items (Tests.bend, PROOF, OpenSpec, KVM, GPU) are listed as not run.
  Failures are kept (probefail QEMU 35 FAIL, no-port QEMU 17, negative controls exit 1).

## What I verified

- sha256sum of all 18 images and .dbg files (corpus tests, 4 examples, probe, probefail, hello, monitor) under
  $W: every one appears in the added evidence. 23 "hash  $W/path" lines in the evidence match the files on disk, 0
  mismatch, 0 missing.
- Kraftfile ea319440..., build.sh 67ceb9d2..., Makefile.uk a2b00918..., exit_device.c c4012e46..., host.c
  9130a715...: current tree hashes equal the recorded ones.
- Run logs run-tests-m4096.log, run-tests-m32.log, run-s2-probe-1.log: sha256 equal the recorded values.
- The four channel reference files and the two other cited references (effects probe, corpus Linux) exist and have the
  recorded sha256.
- Not re-run: the QEMU boots and the builds. I did not redo them (the corpus build takes hours); I checked the
  records against the artifacts left on disk.
