# Task 3 report: runtime rows on base-linux

Status: DONE_WITH_CONCERNS
Branch: lane/genode-component (not pushed). Wall clock 20:58 to 21:12 -06:00.
Commits:
- 5a6204d Add runtime-row probes and BENDRTS run for base-linux
- d83f3c6 Record Bend runtime rows on Genode base-linux
- b6b6afa Add base-linux runtime-row section to GENODE.md; check task 1.2
- c78dba6 Correct the recording window in the runtime-rows evidence

## Rows (verification/genode-runtime-rows-base-linux.md)
| Row | Value | Provenance |
| --- | --- | --- |
| Memory | substituted-or-missing: 8 GiB heap committed and bzero'd (file_operations.cc:648-671), quota ~10 GiB + N*2 GiB; mprotect is a weak dummy (dummies.cc:126) -> `bend: stack guard failed`. Not stubbed. | Bend program (Task 2 runs) + source |
| Faults | missing (runtime handler). C probe: overflow -> base-linux's own handler (thread_env.cc:42-74) prints `Segmentation fault`, Linux kills the process, no resumption, init records nothing in 45 s (3 runs, ps + journalctl confirm). | Bend (setup failure) + C probe + source |
| Threads | supplied (2 lanes, condvar broadcast, detach, yield) | C probe |
| Clock | supplied, monotonic; 100 ms nanosleep came back 0.15/0.29 ms short in 2 of 4 runs (probe keeps its >=100 ms check, so its run script fails intermittently) | C probe |
| Event loop | supplied with configuration: pipe() fails without a vfs_pipe mount + libc `pipe` attribute (run 1); works with them (run 2). Needed enabling repos/gems. | C probe |
| Process | supplied: Bend binary run with BENDRTS=--help prints the runtime usage and exits 0, BENDRTS=--bogus prints `bend: unknown runtime option --bogus` and exits 1 (256M; returns before the heap). C probe: getenv, exit(3) seen by init; sysconf(_SC_NPROCESSORS_ONLN)=1. | Bend program + C probe |
| Atomics | compile-time fact only | Task 2 compile |
| Device dispatch | CPU only by construction (BANGS 0, --gpu off) | source |

## Fault-substitute decision
Halting substitute = the base platform's own fault path (terminates, no
resumption). GB-003 also requires the parent to record the fault; on
base-linux it does not, so that half is open. base-hw to be measured (3.1).

## Boxes
- 1.1 left unchecked, against the brief's expectation: the IO.print
  program never printed "hi"; the box requires its output in the log. The
  BENDRTS usage text is the runtime's option parser, not program output.
- 1.2 checked: every row recorded with value and evidence; mmap and mprotect
  executed through the Bend program, pthreads, pipe/select, and the fault
  path executed by C probes (stand-ins, stated in the evidence).
- 1.3 left unchecked: the fault substitute was executed only by a C probe
  (not a Bend Overflow program, not the runtime's evaluation stack), and the
  parent did not record the fault. Stack guard setup failing is not the
  fault path.
The tasks.md preamble ("no Genode component containing Bend has been built")
was replaced with a short status matching these boxes.

## Files
- scripts/genode/probes/{threads,clock,evloop,process,fault}/{probe_*.c,target.mk,writ_probe_*.run}
  (byte-identical to ../writ-genode/writ-repo/{src/app/writ_probe_*,run}; header comments)
- scripts/genode/writ_bend_hello/writ_bend_rts.run (unchanged Bend binary, BENDRTS via <env>)
- scripts/genode/writ_hello/build.conf.fragment: gems repo + new scenario names (matches live build.conf)
- verification/genode-runtime-rows-base-linux.md (new), verification/genode-pins.txt (Task 3 note)
- docs/GENODE.md: appended "Runtime rows on base-linux, 2026-11"
- openspec/changes/add-genode-bend-component/tasks.md
No .bend file touched. Nothing built or downloaded committed (logs in ../writ-genode/run-*.out).

## Verification
- All probe and BENDRTS runs as listed in the evidence (rc recorded per run).
- OpenSpec 1.16.0 (/nix/store/74ha4fyb...-openspec-1.16.0, OPENSPEC_TELEMETRY=0):
  `openspec validate --all --strict --no-interactive` -> 42 passed, 0 failed.
  (The bun-cache 1.16.0 lacks its node deps; PATH openspec is 1.11.0.)
- Bend tests / PROOF not run: no Bend source or security law changed.

## Concerns
1. Event loop: writ_bend_hello.run mounts no pipe fs, so even after an
   mprotect fix Hello would stop at `the event loop failed to open` until
   the run script adds vfs_pipe and `pipe: /pipe`.
2. Even with mprotect fixed, the runtime's err_trap can never run on
   base-linux (libc sigaction is emulation only); its fault message is
   unreachable there, and init does not see the death. Supervisor restart
   (GB-003 scenario 2) has no detection path on base-linux.
3. Clock short-sleep is intermittent and uninvestigated; the committed clock
   run script can fail because of it (deliberately not loosened).
4. Enabling repos/gems widens the build's repository search path (only
   lib/vfs_pipe is used).
5. verification/source-sha256.txt remains stale (does not list this change
   or the new files), as in Tasks 1 and 2.
6. The fault probe emits GCC's intended -Winfinite-recursion warning.
