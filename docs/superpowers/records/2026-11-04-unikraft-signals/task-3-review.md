# Task 3 review: record the adoption and check box 2.3

Reviewer, 2026-11-05. Read-only except this file. Package: e90cc8c..4e2b8ec.

## Verdicts

1. Spec compliance: APPROVED
2. Record quality: APPROVED

## Findings (by severity)

No blocking or major findings.

Minor:

1. docs/UNIKERNELS.md:261-263 (item 3 of "What the effect-twins task needs") still opens with
   "The runtime's `SIGSEGV` handler does not run on Unikraft (E4)" as the problem statement; the
   adoption sentence follows at 263-269, so the item reads correctly as a whole. Optional: mark
   the first sentence as historical.
2. Report concern 3 stands and is correctly disclosed: the exhaustion limit rests on `-m 1024`
   only. The documents say so (UNIKERNELS.md:99 area, tasks.md:128-129, matrix 460-462, traceability row).
3. The UL-006 traceability row (openspec/traceability/unikernel-library-runtime.md:52) is a very
   long single cell. It is accurate; readability only.

## Spec compliance, checked

- docs/UNIKERNELS.md:136-152 lists lib/posix-process with signals, EXPERIMENTAL (Config.uk:78), in
  every image from hosts/unikraft/app/, and `-include uk/config.h`. Verified against
  hosts/unikraft/app/Kraftfile:37 and hosts/unikraft/scripts/build.sh:28.
- Fault section (UNIKERNELS.md:86-104): message appears; still a Unikraft crash, deliver.c:428, hook
  value 253; arena exhaustion a crash with no message, deliver.c:125, a "recorded limit of UL-006",
  with unikernel-fault-qemu.txt "Arena exhaustion with signals" cited.
- Matrix: SIGNALS NOTE (15-16), Faults row/E4 (40), "E4 SUPERSEDED" (256-257), Limits bullets
  (455-464). Recorded text kept, supersession added alongside. Good.
- Open/Limits list updated (UNIKERNELS.md:157-164): 19, 251 and the shutdown SIGTERM-and-wait path
  (shutdown.c:61-67) are stated outright as not exercised (also matrix 460-464, tasks.md 133-137,
  traceability row).
- UL-006 row: "fault message: executed" / "arena exhaustion: limit", and says 2.3 is checked "with this
  half recorded as a limit, not met".
- Box 2.3 is checked; the diff shows exactly one checkbox flipped (git diff on tasks.md: only the
  2.3 line). The box text is unchanged. The note cites evidence files by section and states outright
  that exhaustion shares 253, with no message, and that "this half of UL-006 is not met" (tasks.md:127-131).
  This satisfies the controller's ruling.
- No spec.md or openspec/specs change in the range; no requirement text weakened. No .bend change.
- INVENTORY.md cells (UK_CFLAGS, Kraftfile row): in scope per the ruling; only those two cells changed.
- Checks: report records `Totals: 44 passed, 0 failed (44 items)` and 782 PASS lines with the final
  "ALL LIBRARY TESTS PASSED". I did not re-run them (read-only review); the figure 782 is
  independently corroborated by verification/unikernel-corpus-qemu.txt:383,432,435.

## Record quality, checked

Spot-checks against the evidence files (all agree):
- unikernel-fault-qemu.txt: "Fault message runs" has check-fault.sh passing twice (ovs1, ovs2) with
  QEMU 253 and deliver.c:428, and a negative control (negsig1) on the no-signals build; "Arena
  exhaustion with signals" (154-179) shows QEMU 253, deliver.c:125 assertion, handle_self, no
  message, only -m 1024, "Limit, recorded".
- unikernel-exit-codes.txt:11-37: "CURRENT MAP, RE-RECORDED WITH POSIX SIGNALS" gives 33/35/39/17/253
  and the exhaustion paragraph (no code of its own); the table at 46-47 matches.
- unikernel-corpus-qemu.txt: 782 PASS lines, exit 33, in the signals-present reruns (382-435).
  Also 19, 251 and the shutdown path are stated as not exercised in fault-qemu.txt:206-213, 268-270.

Cited sections exist: "Result" (13), "Fault message runs" (98), "Arena exhaustion with signals" (154),
"Exit map runs" (181) in unikernel-fault-qemu.txt; "Unikraft image configuration pins" in
unikernel-pins.txt:54. Config.uk:78 and shutdown.c:61-67 are cited consistently in the evidence.

Overstatement check: nothing reads UL-006 as fully met. Every place that mentions 2.3 pairs it
with the limit (tasks.md preface 9-12 and note; traceability gap column; UNIKERNELS.md fault and Open
lists; matrix Limits). The only residual risk is a reader of the bare checkbox, which the
controller's ruling accepts and the note's first sentence mitigates.

Not verified: that the stated builds and boots reproduce (no rebuild); GPU is not applicable and
the documents say CPU only.
