# Task 3 report: OSv attempt and selection

Status: DONE_WITH_CONCERNS
Commits (branch lane/unikernel-library, not pushed):
- b1cd726 Record OSv 0.57.0 pins and the compat-mode runtime matrix; fold Task 2 review fixes
- 96512b8 Add the 2026-11 selection matrix: Unikraft chosen for the native-link lane; check 1.1 and 1.2
- 97c510e Mark the OSv alternate-stack reading as inferred

## OSv outcome (compat mode, inside the time-box: 20:58 to about 21:30)
- Pins: OSv v0.57.0 prebuilt release assets (osv-loader.qemu.x86_64, osv-loader.elf.x86_64.gz,
  osv.bootstrap.mpm), capstan v1.0.0 Go binary. Tag and commit SHAs from the GitHub API;
  observed sha256 only (neither release publishes checksums). Not built from source.
  CAPSTAN_ROOT=$W/capstan-home; loader and bootstrap placed by hand, no capstan pull.
- Native link: not possible. OSv apps are always .so/PIE loaded by its in-kernel ELF linker
  (documentation and build layout, not executed). The program was built as a dynamic Linux
  PIE with host clang and run as a compat observation, labeled as such.
- Build adjustments: O1 link with lld (GNU ld 2.47 emits PT_GNU_SFRAME, rejected by OSv:
  "Unknown p_type 1685382484"); O2 objcopy rename of __isoc23_strtol/__isoc23_fscanf to the
  C17 names (glibc 2.44 redirects them under _GNU_SOURCE; OSv 0.57 lacks them). Both first
  errors are recorded.
- argv: arrives. Boots both from the capstan disk (baked cmdline) and by PVH
  `-kernel osv-loader.elf -append "<cmdline>"` with the disk as ROFS root, so +RTS options
  vary per run. `+RTS --threads 1 --gpu off`, `--bogus`, `--help` all reach main.
- Rows: Memory supplied (heap lands at third hint 1<<43; boots at -m 32). Faults supplied:
  the runtime's own "bend: memory fault" message, then OSv powers off ("Uncaught signal 11"
  with --verbose); QEMU 0. RAM exhaustion: kernel abort in page pool, halts without
  power-off. Threads supplied: pool_work entered, two stacks, correct results on 1 and 2
  vCPUs; but with >1 lane the guest never shuts down after main returns (gdb: main returns 0
  into osv::application::run_main, exit not called, CPUs idle; cause inferred: workers parked
  in pthread_cond_wait). Clock, event loop supplied. BENDRTS supplied via --env=. Exit status:
  every path powers off with QEMU 0; code visible on the console only with --verbose.
  CPU count sane. Atomics exercised with two lanes on two TCG vCPUs. Device dispatch missing by
  construction. Image rebuild reproducible.

## Selection
docs/UNIKERNELS.md "Selection matrix, 2026-11": one table, 14 rows, two columns with evidence
pointers (E<n> Unikraft, O-E<n> OSv). Chosen: Unikraft 0.21.0, because it is the only native
link (UL-001 cell), with Memory/Clock/Event loop/argv supplied and gaps (single lane, halting
trap) the profile allows; OSv's better fault/thread cells are compat-path evidence. Effect-twins
needs: a harness-visible exit path (e.g. isa-debug-exit plus power-off instead of idle; distinct
codes), a declared single-lane config (UKPLAT_CPU_MAXCOUNT=1, --threads 1, inline IO helper),
the fault halt printing the runtime's message, and a decision on the A3 libraries. Blockers named:
Unikraft = exit status; OSv = its ELF loader (no link-into-kernel mode).

## Task 2 carried fixes (in verification/unikernel-matrix-unikraft.md)
- Device dispatch: "missing, by construction; no `!` program was run".
- Native calibration: commands and outputs added (Overflow 10^6/10^8 return, 10^9 SIGSEGV 139;
  Clock; Lanes --threads 2; Exit 3). Re-emitted C byte-identical to Task 2's.
- `--threads 0` -> `_exit(1)` stated as source reading (hello.c:3043).
- Atomics narrowed to the pool counters on one lane and err_claim.
- Threads: "not entered by shutdown", cause inferred (cooperative scheduler, one CPU).
- gdb command files inlined for E2, E6, and E9.
- 0.16.3 A1-only build re-run: `echo $?` = 1, same boot.c:499 error.

## Boxes
- 1.1, 1.2 checked (matrix complete for two candidates; 1.1 annotated that OSv's outcome is
  compat, not a native build). The preamble now says what is recorded.
- 1.3 left unchecked, with a note: 0.21.0 has no linuxu, and the 0.16.3 linuxu run stops at
  "reservation failed" before the program's first output, so the reference program has not
  really run under linuxu. Process execution of the image did happen and is recorded (E10).

## Checks
- OpenSpec 1.16.0 (from the root flake, `nix shell .../writ#openspec`):
  `openspec validate --all --strict --no-interactive` gives 42 passed, 0 failed.
- No .bend file was modified; Bend Tests/PROOF not run (no library source changed).
- git status clean; all downloads, images, logs under ../writ-unikernel/ (logs/task3/,
  osv/, capstan-home/, calib/).

## Concerns
- The OSv column does not meet UL-001; it is there to complete UL-002's two-candidate matrix
  as the brief allows. A reviewer may read UL-002's "built with the reference program" as
  requiring a native build on both; if so, 1.1/1.2 should be unchecked.
- The OSv kernel is an unverified prebuilt binary (no published checksums; built on Fedora 35).
- The claim that OSv has no link-into-kernel mode is documentation reading, not executed.
- Exit status is harness-invisible on both candidates; every fault/exit is QEMU 0.
- All runs are TCG; two-vCPU runs are multi-threaded TCG, not hardware.
- The OSv shutdown-with-open-pool hang cause is inferred (not traced into OSv threads).
- Harness scripts and gdb files live in $W/osv/ outside the tree; their contents are given
  in the matrix.

## Review fixes (commit 7315a4c; wording and evidence only, no rebuilds)
1. Selection preamble: "Every cell except those marked 'by construction' or 'from
   documentation' comes from running an image". OSv Native-link cell, the rationale bullet,
   and the OSv blocker bullet are marked "(from documentation, not built)", and they say O-E0
   shows the loader rejecting a header, not that no other mode exists.
2. Effect-twins item 2: "the OSv hang at shutdown with more than one lane (cause inferred,
   O-E6) should be investigated as part of it."
3. "All boot runs are emulated boots" (the linuxu run is process execution).
4. OSv exit-status cell is now "substituted (single lane)", and it notes the multi-lane hang and
   that IO.exit with an open pool was not tried.
5. Both event-loop cells: helper-thread wake path not exercised.
6. unikernel-matrix-osv.md: osv-build.sh inlined with the two earlier compile variants used
   for O-E0; mmap.cmd, mmap-ret.cmd (full), lanes.py (plus the smp1 variant: port 1234,
   range(6)), and hang.cmd inlined (mainret.cmd already was). Both probes.qemu hashes are given:
   first build ($W/osv/probes.qemu.first) and rebuild, identical 28b441c4...
7. Reproducible-image pointers name the exact sections ("Build and run harness (outside the
   tree)" image hash table; "Image and executable hashes").
OpenSpec: bunx @fission-ai/openspec@1.16.0 validate --all --strict --no-interactive gives 42 passed, 0 failed.
