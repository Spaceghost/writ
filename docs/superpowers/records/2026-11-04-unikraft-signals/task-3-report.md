# Task 3 report: record the adoption and check box 2.3

Status: DONE_WITH_CONCERNS (concerns at the end). Implementer, 2026-11-04/05.

Only documents changed. No `.bend` source, script, Kconfig, C file, or evidence `.txt` changed.

## Edited files

| File | Lines (new numbering) | Change |
| --- | --- | --- |
| `docs/UNIKERNELS.md` | 86-104 | "Faults" bullet rewritten. The message `bend: memory fault (machine stack overflow?)` now appears before the crash screen. The image still ends in a Unikraft crash (deliver.c:428) with the hook's 253 and does not resume. check-fault.sh requires the line, and the image built without signals fails it. Arena exhaustion is still a crash with no message and 253, now at deliver.c:125 (alternate stack already in use); the earlier prediction is stated to have been wrong; this is a recorded limit. The exit map is unchanged (33/35/39/17/253). CPU only, no GPU test. Cites unikernel-fault-qemu.txt "Result", "Fault message runs", "Arena exhaustion with signals" and unikernel-exit-codes.txt "CURRENT MAP, RE-RECORDED WITH POSIX SIGNALS". |
| `docs/UNIKERNELS.md` | 136-152 (new) | "Image configuration pins (trust inventory)" bullet. Every image from `hosts/unikraft/app/` links `lib/posix-process` with signals (`CONFIG_LIBPOSIX_PROCESS_SIGNAL: 'y'`, EXPERIMENTAL at Config.uk:78, with what it selects). The build flag `-include uk/config.h` is described with the shutdown.c / signal.h:116/287 reason and "no Unikraft source patched". Cites the pins section and the four Task 2 evidence files (corpus 782 PASS). |
| `docs/UNIKERNELS.md` | 157-164 (Open list) | Removed "the runtime's fault message in the delivered configuration (2.3: shown only with posix signals enabled)". Exhaustion is now stated as 2.3's recorded limit. Added, stated outright: signal value 19 and non-halt 251 not exercised with the library, and the shutdown SIGTERM-and-wait path (shutdown.c:61-67) reachable only by a program still running at shutdown and not exercised. |
| `docs/UNIKERNELS.md` | 265-269 | "What the effect-twins task needs" item 3: "not adopted (...)" replaced by the adoption (template, build.sh workaround, corpus 782 PASS; exhaustion still without the message). |
| `verification/unikernel-matrix-unikraft.md` | 15-16 (new) | SIGNALS NOTE after the CODE MAP NOTE: the library and flag, rows kept as recorded, Faults/E4 superseded as noted. |
| `verification/unikernel-matrix-unikraft.md` | 40 (Faults row) | Appended a "Since (signals lane, 2026-11-04, kept above as recorded)" sentence: message before the crash screen, still 253; exhaustion still 253 with no message. The recorded text is unchanged. |
| `verification/unikernel-matrix-unikraft.md` | 256-257 (new) | "E4 SUPERSEDED" note under the E4 heading, with the current outcome and the deliver.c:428 / :125 sites. The recorded E4 console is kept unchanged. |
| `verification/unikernel-matrix-unikraft.md` | 455-464 (Limits of the Task 2 record) | Two bullets. (1) Exhaustion remains a crash with no message and 253; only -m 1024 was rerun; this is a recorded limit of UL-006. (2) 19 and 251 were not exercised; the shutdown.c:61-67 SIGTERM-and-wait path was not exercised. |
| `openspec/traceability/unikernel-library-runtime.md` | 52 (UL-006 row) | Executed column: "fault message: executed", with the pins, two boots, the check-fault.sh requirement and its negative control, the unchanged codes (33/35/39/17/253), corpus 782, and crash action. Gap column: "arena exhaustion: limit" (deliver.c:125, prediction wrong, no distinct code; 2.3 checked with this half recorded as a limit, not met). Also states that 19, 251 and the SIGTERM path were not exercised, and that "Handler resumes" is rejected by review. |
| `openspec/changes/add-unikernel-library-runtime/tasks.md` | 9-12 (preface) | Now "2.2 ... and 2.3 (the fault message, with arena exhaustion's missing distinct code kept as a recorded limit) are checked". |
| `openspec/changes/add-unikernel-library-runtime/tasks.md` | 107-138 (box 2.3) | `[ ]` -> `[x]`. The box text is unchanged. The note was rewritten and cites the evidence files and sections: handler and message, pins, codes, rebuilt sets, then "Recorded limit" (exhaustion; "this half of UL-006 is not met"; 4096/12288 not rerun), then "Not exercised" (19, 251, shutdown.c:61-67), CPU only, spec unchanged. No other box changed (the diff shows only the 2.3 checkbox line). |
| `hosts/unikraft/INVENTORY.md` | 135, 140 | Outside the plan's touch list (concern 1). The trust inventory's `app/Kraftfile` row now lists `LIBPOSIX_PROCESS_SIGNAL=y` (EXPERIMENTAL, a pin). The `scripts/build.sh` row said `UK_CFLAGS=-std=gnu11`, which was stale since Task 1; it now gives the actual flag and its reason. |
| `docs/superpowers/records/2026-11-04-unikraft-signals/activity.log` | appended | Step lines. |

No requirement text was weakened. spec.md was not touched. The UL-006 requirement and the 2.3 box text are verbatim.

## Checks (run from the worktree root, Linux)

`~/.bun/bin/bunx @fission-ai/openspec@1.16.0 validate --all --strict --no-interactive`: exit 0. Last line:

```
Totals: 44 passed, 0 failed (44 items)
```

`export PATH="$HOME/.local/share/writ-toolchains/bend-2.0.39/bend/bin:$PATH"; export BEND_NO_TELEMETRY=1; bend Tests.bend`: exit 0, wall 6 s, 782 lines beginning `PASS`. Last lines:

```
HostBinding: 144 checks passed, 41 vectors emitted; GA-010 is a reviewed host obligation, not a model test
Facade: 10 checks passed
Property: 324 checks passed; 320 graph cases, each checked against CPU and Bend parallel producers
ALL LIBRARY TESTS PASSED
```

`git diff --quiet HEAD -- '*.bend'` is true: no Bend source changed. `bend PROOF.bend` was not run, because nothing changed in policy or proof. No GPU test was run: every Unikraft run cited is a QEMU TCG boot on the CPU.

## Concerns

1. `hosts/unikraft/INVENTORY.md` is not on the plan's touch list. The plan put "inventory" in `docs/UNIKERNELS.md`, but the spec's trust inventory (UL-004) is INVENTORY.md. Its Kraftfile and build.sh rows were stale after Task 1: the build.sh row still said `UK_CFLAGS=-std=gnu11`. I changed only those two cells. Revert them if the touch list is strict; UNIKERNELS.md carries the same pins either way.
2. Box 2.3 is checked as the brief directs, but its text asks for "distinct exit codes", and arena exhaustion still shares 253 with the fault. The note says plainly that this half of UL-006 is not met and is a recorded limit, following the precedent of box 1.1's "checked ... as a recorded outcome". A reader who reads only the checkbox would overstate UL-006.
3. The exhaustion limit rests on one size (-m 1024) with signals. The 4096 and 12288 MiB runs were not repeated, and the documents say so.

## Fix round (final review findings 1-4; task-3 review minor 1)

- Merge: `git merge master` gave merge commit f93c84d. The one conflict was in `openspec/traceability/unikernel-library-runtime.md`. I kept master's UL-002 and UL-007 rows (they cite the linuxu lane) and this branch's UL-006 row. Master's UL-006 was identical to the base, so no master fact was lost. After the merge, the file differs from master only in the UL-006 row. No conflict markers remain in the tree, `|||||||` base blocks included. `docs/UNIKERNELS.md`, `tasks.md` and `unikernel-pins.txt` merged automatically.
- `hosts/unikraft/INVENTORY.md:109` (the 0x09 / QEMU 19 row): with the signal library, a still-running init process is sent SIGTERM at shutdown and waited for (`shutdown.c:61-67`). The outcome is 19 if it dies, or the harness timeout if it does not. Neither was exercised. `0x80 | SIGKILL` is now named as the non-signal path (:100-101).
- `docs/UNIKERNELS.md:115` (io_work helper): now reads "under the current map and the signal library: 19 if the SIGTERM sent at shutdown ... ends the helper, otherwise a hang to the harness timeout; not rerun".
- `hosts/unikraft/INVENTORY.md:118-124` (evidence pointers): they now point at the adopted signal configuration in unikernel-fault-qemu.txt, at "CURRENT MAP, RE-RECORDED WITH POSIX SIGNALS" in unikernel-exit-codes.txt, and at the signals record in unikernel-corpus-qemu.txt (782 PASS at QEMU 33). The trial section, the effect-twins map runs, the first map, and "Task 3 rerun" are called history.
- `hosts/unikraft/INVENTORY.md` check-fault.sh row: added the fault-message check for the overflow probe (the line `bend: memory fault (machine stack overflow?)` must appear before the first `CRIT: Unikraft Crash` line). It also notes that the overflow reference now has two program lines.
- `docs/UNIKERNELS.md`, item 3 of "What the effect-twins task needs": rewritten to the current state, "(done for a stack overflow)". The handler runs and prints the message. The image still ends in the Unikraft crash at 253 and does not resume. Exhaustion still has no message. The matrix's E4 statement and the earlier trial are kept as one history sentence.
- OpenSpec 1.16.0 after the merge (`~/.bun/bin/bunx @fission-ai/openspec@1.16.0 validate --all --strict --no-interactive`): exit 0, `Totals: 44 passed, 0 failed (44 items)`.
- Not done, as instructed: the manifest (`verification/source-sha256.txt`, to regenerate on master), the optional findings 5-7 (the C comments in exit_device.c and unikraft_sleep.c, the UL-004/UL-005 evidence pointers, and the exit-codes.txt "trial section" wording), and the push. No `.bend` change, so `bend Tests.bend` was not rerun.
