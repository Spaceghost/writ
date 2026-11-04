# Task 4 report: profile check, inventory, and task boxes

Status: DONE.

- verification/unikernel-binary-check.txt: check-binary.sh on 12 non-stripped image ELFs
  (.dbg): Task 3's five corpus/example images, Task 1's four probes, Task 2's two Overflow
  images: each PASS (effect rows IO.print; static link, so the host-symbol surface is not
  checked). Negative control: scripts/runtime-profile/Widened.bend (adds TCP.listen) built
  as a Unikraft image with the same template (it links; not booted): FAIL on TCP.listen,
  exit 1. That shows the row detection works on gcc-built Unikraft ELFs, not only clang.
- hosts/unikraft/INVENTORY.md: every file under hosts/unikraft/ listed (hook, app template
  Kraftfile/Makefile.uk/Config.uk, env/mkapp/build/run/console scripts); states that no
  Bend effect defs or effect twins exist yet.
- openspec/changes/add-unikernel-library-runtime/tasks.md:
  - 2.1 left unchecked: only the exit hook exists; no console/time/ingress twins, no
    Bend effect defs (the brief's condition "any Bend effect defs exist" is not met).
  - 2.2 checked: corpus 764 PASS + ALL LIBRARY TESTS PASSED, QEMU 1, four examples
    diff empty; notes that Bend 2.0.39 has no separate inline-IO switch (IO.print uses
    no helper thread) and that UL-005's "638 count" predates the 764 corpus.
  - 2.3 left unchecked: stack overflow gives a distinct 253, but no handler prints the
    runtime's fault message and arena exhaustion was not forced (would share QEMU 3).
  - 2.4 and section 3 untouched. Preamble sentence updated.
- openspec validate --all --strict --no-interactive: 43 passed, 0 failed, with OpenSpec
  1.11.0 at first; superseded by the pinned 1.16.0 run in fix round 1 (verification/unikernel-openspec-validate.txt).

Not run: bend Tests.bend / PROOF.bend (no .bend file, library, policy, or proof source
changed in Tasks 2-4). verification/source-sha256.txt not regenerated (integration).

## Integration rerun (782 checks)

- `git merge master` (dc6ff2b) -> aaa6885, no conflicts (source-sha256.txt merged cleanly).
- tests.c regenerated from the merged tree; image built in the new app dir
  $W/corpustests782-unikraft (5498 s); the 764 image and logs are untouched.
- Linux reference recaptured from the merged tree into
  verification/unikernel-corpus-linux-reference.txt (header names aaa6885/dc6ff2b); 782 PASS,
  identical to the merged tests-native.txt.
- check-corpus.sh at -m 4096 and -m 32: diff empty, 782 PASS, ALL LIBRARY TESTS PASSED,
  QEMU 1, script exit 0. Dated section appended to unikernel-corpus-qemu.txt; the 764 run
  kept as history (its reference recoverable from 2985b2f).
- Examples' emitted C is byte-identical on the merged tree; their images rechecked with
  check-image.sh (all PASS); negative control exits 1.
- check-binary.sh on the 782 ELF: PASS (appended).
- 764 -> 782 in tasks.md 2.2; docs/UNIKERNELS.md and INVENTORY.md had no 764. The new
  check-corpus.sh takes WRIT_CORPUS_PASS (default 782).

## Fix round 1 (review of Tasks 2-4)

1. The four unlogged runs (0x501 crash 85, system_reset control 0, Hello with/without
   device 1/0) rerun through run.sh with .log files (command + status); evidence points at
   them. Added Hello with the device at 0x501: 83. run.sh gained WRIT_QEMU_DEVICE=501 and
   WRIT_QEMU_FEED.
2. run.sh now exits with QEMU's status. New check-image.sh (console diff, optional PASS
   count, optional last line, QEMU status; exit 1 on any mismatch) and check-corpus.sh
   (corpus wrapper, WRIT_CORPUS_PASS default 782); used for the 782 corpus and the four
   examples, named in the evidence; negative control exits 1.
3. binary-check: the crash/overflow ELF row is the third clean build (image d6eb5822...),
   not the booted 2d1301c2...; stated.
4. corpus-qemu Harness: timeouts listed per size.
5. tasks.md 2.2: "inline IO helper" interpreted as no helper thread, citing io_work's
   definition with no caller in all five emitted C files and the matrix event-loop row.
6. docs/UNIKERNELS.md preamble and item 5: "observed no reset; QEMU 0 consistent with ACPI
   power-off", plus the 0x501 runs (85 crash, 83 halt).
7. INVENTORY: exported symbols/variables column; console.sh temp files ($T, $T.banner,
   $T.tail) all in the trap; check-image.sh / check-corpus.sh rows.
8. env.sh: W must be a non-empty existing directory, else the caller stops.
9. console.sh: fails if the program's part of the capture holds NUL, ESC, or a CR not
   followed by LF; all earlier captures recheck clean; a crash capture (NULs) fails as
   expected.
10. crash-action Limits: "Unikraft's own crash path (and its halt path)".
11. verification/unikernel-openspec-validate.txt: OpenSpec 1.16.0 (flake store path),
    43 passed, 0 failed, exit 0.

## Final-review fixes

- I1 docs/UNIKERNELS.md: new "Port status" section before the matrix (782-line parity,
  exit hook, crash action, INVENTORY, check-corpus.sh/check-image.sh, open items: 2.1 twins,
  2.3 fault message, arena exhaustion sharing QEMU 3, statuses > 0x7c sharing 0x7f,
  timeout 125/127 aliasing statuses 62/63, 2.4, 3.1). "(matrix, before the port; see ...)"
  pointers on the exit-status row, the rebuild-stable row (now: clean builds are not
  hash-stable, HOSTUTC), the "reproducible image" bullet, the exit-status gap bullet,
  effect-twins item 1, and the blocker line; the UKPLAT_CPU_MAXCOUNT item marked done.
- I2 run.sh: `${n:?usage}` guards and exit 2 before QEMU if the image or logs dir is
  missing. "Only QEMU 1 is success" reworded (hook header, run.sh, crash-action,
  exit-codes): QEMU 1 is success only with the banner-verified console check. timeout
  125/127 aliasing added to exit-codes limits; s + 0x10 noted for 2.1.
- I3 tasks.md 2.1: UL-004 tension recorded (hook, Kraftfile, Makefile.uk are
  kernel-specific non-twins; the crash handler cannot be a twin); 2.1 must subsume the hook
  or amend UL-004 with a rationale. Spec not amended.
- Minors: hook comment wording (observed, 0x501) and H2 citation; Kraftfile declares
  LIBPOSIX_PROCESS_MULTITHREADING (already the resolved default, so images are unchanged);
  lane-relative wording replaced with evidence/adjustment citations; writ_strip_serial in
  env.sh; build.sh WRIT_JOBS (default nproc); INVENTORY lists itself, probe scaffolding,
  bc, WRIT_JOBS, WRIT_NO_BOOT; "native path" gone from crash-action; plan note 764 -> 782;
  reference header says when to recapture.
- Hook edits are comment-only: comment-stripped tokens identical to HEAD (gcc
  -fpreprocessed -E -P); new sha256 752a215e... recorded in exit-codes.
- Rechecks (no rebuild, no boot): check-image.sh (WRIT_NO_BOOT=1) on flow PASS exit 0;
  check-corpus.sh on the 782 capture PASS exit 0; negative control (booted) FAIL exit 1;
  run.sh on a missing image exits 2. Recorded in unikernel-corpus-qemu.txt.
- OpenSpec 1.16.0: 43 passed, 0 failed, exit 0 (appended to unikernel-openspec-validate.txt).
- Note: the template app files now differ from the $W app directories made earlier, so
  mkapp.sh refuses to refresh those directories; a new set gets the new template.
