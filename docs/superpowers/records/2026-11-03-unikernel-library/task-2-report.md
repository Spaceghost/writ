# Task 2 report: Unikraft runtime rows

Status: DONE_WITH_CONCERNS
Commit: cc19fce (branch lane/unikernel-library, not pushed)

## Delivered
- scripts/unikernel/Clock.bend, Overflow.bend (depth 10^9), Lanes.bend (parallel pow2(22) +
  IO.thread_count), Exit.bend (IO.exit(3)). Hello unchanged. Lanes and Exit were added
  because Hello cannot exercise thread creation (no parallel call, so the pool is never
  opened) or the exit() path.
- verification/unikernel-matrix-unikraft.md: new "Task 2: runtime rows" part with an
  8-row matrix (Memory, Faults, Threads, Clock, Event loop, Process, Atomics, Device
  dispatch), a primary qemu column and a secondary linuxu-0.16.3 column, evidence blocks
  E1-E10, the harness, and image hashes. Task 1 part kept, with its review fixes.
- verification/unikernel-pins.txt: absolute W, rev-parse lines for all four pins,
  emitted-C hashes of the probes.

## Rows (qemu/x86_64, 0.21.0, A1+A2+A3, emulated boot)
- Memory: supplied, lazily backed. 8 GiB heap at 1<<45 plus a 2 GiB+guard stack reserved
  (gdb on __mmap); Hello boots with -m 8. No smaller CPU span exists in Bend 2.0.39:
  --gpu <size> only sizes the device span (the mmap length stays the same with --gpu 64MB).
- Faults: substituted. At the guard page (r08 = stack base + 2 GiB) Unikraft prints
  "CRIT: Unikraft Crash" plus registers. The runtime's SIGSEGV handler never runs, and
  QEMU exits 0. Running out of RAM (-m 1024) gives the same trap. Of RH-006's outcomes
  this is a trap that halts, recorded on the console only; the exit status matches success.
- Threads: substituted by a single lane. pthread_create returns 0, but pool_work is never
  entered (gdb). The main loop runs every row, and results are correct for 1, 2 and 4.
- Clock: supplied (before 108, after 211).
- Event loop: supplied with posix-pipe/poll. Without them it is missing (Task 1:
  "event loop failed to open").
- Process: argv via -append is supplied (settles Task 1's open question). BENDRTS is
  build-time only (posix-environ ENVP, test image read it). Exit status is missing:
  returning from main powers off with status 0 whatever main returned. exit(3), exit(0)
  and _exit(1) leave the guest idle forever (gdb: idle_thread_fn, plat_native_lcpu_halt_irq).
- Atomics: supplied by GCC stdatomic.h; one CPU only.
- Device dispatch: missing; every run is CPU execution.
- linuxu 0.16.3 (process execution): memory missing (reservation failed, also with
  --gpu 64MB). argv supplied. Host BENDRTS not read. Return code dropped (return 1 shows
  as 0). _exit hangs. Faults, threads, clock and event loop are not reached.

## Task 1 carry-overs
- W is absolute (realpath) in both evidence files.
- The A1 commands use gcc -print-file-name, and the Config.uk and app-directory creation
  is recorded.
- rev-parse lines are in the pins file.
- echo $? lines are on every QEMU and linuxu run. Task 1's linuxu no-TTY run was re-run
  to capture the status.
- 0.16.3 needs A2: with A1 only it stops at boot.c:499 ctorfn.
- Corrected the Task 1 matrix's abbreviated hello.c hash (it ended with the musl hash's tail).

## Concerns
- Exit status is never observable on QEMU. Fault, OOM, and success all give QEMU status 0,
  and every exit()/_exit path hangs. Qualification on Unikraft would need a console-reading
  harness, or an exit device plus a platform-shutdown change, before RH-006 can be met.
- The single-CPU cooperative scheduler means --threads >1 never runs a second lane. SMP was
  not tried.
- One clock sample; the helper-thread wake path of the self-pipe was not exercised.
- linuxu evidence is from 0.16.3 only. The column is mostly "not reached" because the fixed
  8 GiB heap cannot be reserved without posix-mmap.
- Lanes.bend and Exit.bend go beyond the two probes the brief named. Both were needed to
  observe their rows.
- docs/UNIKERNELS.md and tasks.md were not touched (Task 3 owns the selection and boxes).
- Bend Tests/PROOF not run: no library source changed.
- Harness scripts (rows-build.sh, rows-run.sh, gdb command files) live in $W, outside the
  tree, and are described in the matrix.

## Nothing generated in tree
git status is clean after the commit. Images, .dbg files, emitted C, and logs are under
../writ-unikernel/ (logs/task2/).
