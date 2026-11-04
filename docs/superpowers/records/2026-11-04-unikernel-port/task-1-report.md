# Task 1 report: harness-visible exit code for Bend images on Unikraft

Status: DONE (acceptance met: three distinct QEMU exit codes; hook inventoried)
Commit: 9672669 on lane/unikernel-port (not pushed)

## Result (emulated boots, QEMU 11.1.2 TCG, -cpu max, -no-reboot, -device isa-debug-exit,iobase=0xf4,iosize=0x04)

| Program | Path | QEMU exit |
| --- | --- | --- |
| Hello.bend (-m 1024) | main returns 0 | 1 |
| Die.bend (new; IO.die(Unit, 1, "die")) (-m 1024) | exit(1) | 3 |
| Overflow.bend (-m 4096) | stack-guard page fault, Unikraft crash | 253 |
| Exit.bend (supplementary) | exit(3) | 7 |
| Hello +RTS --threads 0 (supplementary) | err_fail -> _exit(1) | 3 |
| Hello +RTS --bogus (supplementary) | main returns 1 | 3 |
| Hello without the device | main returns 0 | 0 |

## What was done

- `hosts/unikraft/exit_device.c` (host binding header; all functions static):
  1. termination-table entry `uk_early_initcall_prio(0, writ_exit_term, 0)` (last term
     function, right before `uk_pm_shutdown`, lib/ukboot/boot.c:447/452) writes
     `tctx->exit_code` (0..124 passed, >124 -> 0x7f) or 0x7d when the shutdown target
     is not SYSHALT;
  2. `POSIX_PROCESS_PPEXIT_HANDLER` requests `uk_boot_shutdown_req(SYSHALT)` when pid 1
     exits, so exit()/_exit() reach the termination path; posix-process's own term
     (shutdown.c:103) supplies the stored status;
  3. `UK_CRASH_EVENT` handler (raised at lib/ukdebug/crash.c:129, before crash_shutdown)
     writes 0x7e. Supported hook; no Kconfig change needed for the crash path.
  `#error` guards refuse to build without LIBUKBOOT_MAINTHREAD / POSIX_PROCESS_MULTITHREADING.
- Root cause of matrix E9 (exit idles) found: LIBUKBOOT_MAINTHREAD unset, so main runs
  on the init thread and exit() ends the thread that would run shutdown;
  `uk_boot_shutdown_req` is then a -ENOTSUP macro (boot.h:59). Observed with gdb.
- App dir `$W/exitcode-unikraft/` (beside the others): A3 Kraftfile + H2
  `CONFIG_LIBUKBOOT_MAINTHREAD: 'y'` + explicit `CONFIG_UKPLAT_CPU_MAXCOUNT: 1`;
  Makefile.uk references the hook in place (not copied) via `WRIT_HOSTS_UNIKRAFT ?=` and
  adds H1 `-I$(UK_PLAT_COMMON_BASE)/include` (first build failed on
  uk/plat/common/bootinfo.h). Scripts `$W/exitcode-build.sh`, `$W/exitcode-run.sh`.
- Images rebuilt after a comment-only edit of the hook gave identical sha256.
- check-binary.sh on hello/die/overflow .dbg: PASS (effect rows IO.print; static link).
- Evidence: verification/unikernel-exit-codes.txt; inventory hosts/unikraft/INVENTORY.md;
  docs/UNIKERNELS.md "What the effect-twins task needs" item 1 updated; new probe
  scripts/unikernel/Die.bend. tasks.md untouched (no boxes this task).

## Limits / concerns

- IO.die status 1 and runtime failure `_exit(1)` (and arena exhaustion, by reading the
  emitted C, not induced) both give QEMU 3: UL-006's "corpus failure vs arena
  exhaustion distinct" is not met by the exit code alone.
- QEMU's code is (v<<1)|1 in 8 bits: statuses >124 collapse to 255; 251/253 are
  reserved for hook-only outcomes so a program cannot forge the crash code.
- Crash code covers every unhandled trap (guard fault, RAM exhaustion by stack growth);
  the runtime's `bend: memory fault` text still does not appear (E4).
- Whether MAINTHREAD's own main_thread_dtor alone would end an exit() run was not
  tested; gdb shows the ppexit handler's request comes first.
- The Overflow crash console contains NUL bytes; removed in the evidence (stated there).
- verification/source-sha256.txt was not regenerated: it was already stale at the
  branch base (the 2026-11-04 plans are not listed), so regeneration is left to
  integration; it now also lacks hosts/unikraft/*, Die.bend, and the new evidence file.
- Bend Tests/PROOF not run: no library, policy, or proof file changed.
- All runs are CPU emulated boots; no GPU, no SMP, single lane only.
