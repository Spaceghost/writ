# Task 3 report: the channel on base-hw, the binary check, and the boxes

Status: DONE (2026-11-04, about 13:00 to 13:45 -06:00)

All evidence is QEMU TCG emulated boot (Genode 26.08 base-hw, BOARD=pc),
CPU only (`--threads 1 --gpu off`). It is not native hardware and not GPU
evidence. The authority state is synthetic.

## Outcome

- **Channel runs:** all eight `writ_bend_monitor_*` scenarios pass on
  base-hw (8 of 8, t3d logs): accept, substitute, claim_ignored, routed_s,
  bad_length, liveness, queue, dead_client. The same eight pass on
  base-linux with the same shim and scripts. `writ_bend_probe` passes on
  both.
- **Hex dumps:** the accepted round trip (Committed) and the Bend-denied
  one (reason 6) are recorded verbatim. Their request and result records
  match base-linux word for word. For five scenarios the component lines
  are the same multiset on both kernels.
- **Wake path, observed:** `Genode.take` runs on the runtime's io_help
  thread `pthread.0`. It parks in the shim's semaphore, and the client's
  signal (handled on the "writ_channel" entrypoint) wakes it. The loop then
  resumes through `io_wake_fd`. That last hop was read in the generated C,
  not instrumented. It is the same on base-linux. No shim change was needed
  for base-hw behaviour.
- **Differences from base-linux, both outside the shim:**
  - liveness: when the monitor exits, its RAM dataspaces (the client's
    buckets) disappear. The flooding client's next write therefore faults,
    and core logs `illegal WRITE at address 0x4010 ...
    pd='init -> writ_client_s'`. addr2line puts the fault in
    `Main::_write`, line 277.
  - dead_client: the base-hw kernel drops a signal to a freed context
    silently (`kernel/thread.cc:395-400`). There is no base-linux-style
    core warning.
  - Both scripts now accept the base-hw behaviour. The first base-hw runs
    of both failed (rc 2 and rc 1), and those failures are recorded.
  - queue on base-hw filled the ring to 8 and coalesced 139 signals. On
    base-linux the ring reached 1 with 0 coalesced.
- **check-binary.sh** on the base-hw monitor ELF: rc 1. The effect rows are
  exactly Genode.log, Genode.put and Genode.take. The symbol half fails
  against the Linux allow list (158 undefined, 117 outside). The base-hw
  and base-linux symbol sets differ only by the fault front end. The allow
  lists were not edited.
- **CPU execution:** BANGS is 0 for the monitor. The tests (1) and
  gpuexample (3) ran with `--gpu off`, so the runtime's GPU gate is false.
- **OpenSpec 1.16.0** (nix store path, cross-checked with bunx): 44 of 44
  pass.
- **Boxes:**
  - 3.1 is checked: 1.4 was repeated on base-hw in Task 2, and 2.3 here.
  - 3.2 is checked. The check was run and recorded, and its FAIL is stated
    as a FAIL.
  - The confinement tasks are untouched.

## Carried minors from the Task 2 review

1. tasks.md:3 now says 1.3 is complete on base-hw only.
2. The shim header and INVENTORY say why the Env-lock hazard cannot fire on
   the single-lane runs.
3. "Without blocking" is scoped to RM routed to core through init.
4. RM-upgrade counters are in the exit report (on their own line) and are
   logged before a base-hw refusal. Overflow on hw: sent=22, declined=0.
5. On hw, the Overflow script fails if core logs a fault line.
6. The corpus record names the unstripped `app/` path for its hashes.
7. INVENTORY gives the reason for `-m 4096`.
8. `writ_probe_fault.run` ends at core's line on base-hw.

## Changes

- `hosts/genode/shim/writ_mem.cc`, 67cc3617 -> db8a376d:
  - the counters;
  - take diagnostics in the channel section;
  - the header sentences.
- `scripts/genode/writ_bend_monitor/writ_bend_monitor.tcl`: `\r*\n`, and
  the base-hw conditions for the liveness and dead_client runs.
- `writ_bend_overflow.run` and `writ_probe_fault.run` (minors 5 and 8).
- `docs/GENODE.md`:
  - a new "Runtime rows on base-hw" section;
  - the "base-hw not attempted" gap is replaced;
  - the design's ordering is narrowed.
- INVENTORY: Task 3 changes, and "Channel on base-hw".
- Verification:
  - new: `verification/genode-channel-base-hw.txt`;
  - updated: the rows and corpus records.
- tasks.md: 3.1, 3.2 and the section text.

## Errors on the way (recorded)

- t3a: the counters were first appended to the report line. That pushed
  the line past the LOG session's 232-byte limit, it was split, and the
  hello and corpus scripts failed on both kernels. The counters were moved
  to their own line, and everything was rerun.
- While stopping that batch I ran `pkill -f 'tool/run/run'`, which also
  killed my own shell. Only my own run processes were then stopped, by PID.
  No other process was affected.

## Verification

- Final shim, both kernels, rc 0:
  - hello and Overflow;
  - the corpus: 782 PASS, sha256 fc3a08aa, diff empty;
  - writ_bend_probe, the guard probe and writ_probe_fault;
  - the eight monitor runs.
- Live copies under `../writ-genode/writ-repo/` are cmp-identical.
- Not run: `bend Tests.bend` and `bend PROOF.bend`. No `.bend` file changed.

## Concerns

- I checked 3.2 because the task asks for the check to be run and
  recorded. The check itself FAILS: the monitor is outside the current
  monitor profile, and the Linux symbol list does not fit Genode. If the
  intended reading is "the check passes", 3.2 should be unchecked.
- `openspec/changes/add-genode-bend-component/design.md` was not edited. It
  is outside the touch list. The gap is narrowed in docs/GENODE.md and
  recorded in tasks.md.
- On base-hw the liveness evidence now ends at a client fault, not a
  client signal. The monitor-side requirements are unchanged.
- The take diagnostics read `cnt()` without the lock, so the parked count
  can misreport a racing signal.
