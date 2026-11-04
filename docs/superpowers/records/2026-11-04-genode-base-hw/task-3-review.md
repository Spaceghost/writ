# Task 3 review: the channel on base-hw, the binary check, and the boxes

Reviewer: task reviewer, 2026-11-04. Range 2c34792..f05d643. Everything
below was recomputed from the logs under `../writ-genode/`, the Genode
26.08 source, and the generated C.

## Spec compliance

- ✅ **Eight channel runs on base-hw.** `batch-hw-t3d.summary`: all eight
  `writ_bend_monitor_*` runs have rc=0. `batch-linux-t3d.summary`: the same
  eight have rc=0 on base-linux. `writ_bend_probe` has rc 0 on both kernels
  (t3b). The t3d logs (13:22-13:24) are newer than the final shim (mtime
  13:04:44) and the final tcl (13:21:44).
- ✅ **Hex dumps (GB-007).** RUN 1 and RUN 2 in
  `verification/genode-channel-base-hw.txt` match the t3d base-hw logs
  verbatim; I diffed them after stripping CR and ANSI codes. The request and
  result dump lines of seven scenarios are identical across the kernels once
  CR is removed. The only difference is `\r\r\n` against `\r\n`, which is
  why the tcl now uses `\r*\n`. Substitute is identical in order. Accept is
  identical as a multiset.
- ✅ **Hashes.** The shim (db8a376d…), the monitor (bae344ed…), the client
  (b6197bcc…), and both ISOs (5c3801ae…, 36ab48b9…) all recompute.
- ✅ **First failing runs recorded.** `run-hw-…_liveness-t3b.out` has core's
  `illegal WRITE at address 0x4010 … pd='init -> writ_client_s'`, then a
  timeout, with make rc 2. `run-hw-…_dead_client-t3b.out` has "missing core
  warning for the freed context". The citations check out against the
  source:
  - `repos/base-hw/src/core/kernel/thread.cc:395-400` is
    `_call_signal_submit` with `/* ignore invalid signal */`;
  - `signal_delivery_proxy.h:70` is the base-linux warning;
  - `region_map_component.cc:103` is the `illegal` line.

  After these failures only the run scripts changed. t3c reran both runs on
  both kernels (rc 0), and t3d reran all eight on both kernels.
- ✅ **Wake path observed.** All 16 t3d logs (8 hw, 8 linux) log
  `take runs on thread 'pthread.0'`. Accept on hw shows the take parked
  before the client's signal, and the decision after it. The cited lines of
  the generated C are correct: `io_help` / `write(io_wake_fd[1])` at
  70140-70150, the `select` / `io_take` at 70197-70207, `genode_take_call`
  at 70524, and the `io_eff` registrations at 70507/70548/70573. The record
  states that the last hop was read from the generated C, not observed
  (channel record LIMITS, GENODE.md, INVENTORY).
- ✅ **The shim change was revalidated on both kernels.**
  - The t3b batches (after 13:04:44) cover hello, Overflow, the corpus,
    the probe, the guard probe, and probe_fault, all rc 0 on both kernels.
  - `genode-tests-hw-t3b.lines` and `genode-tests-t3b-linux.lines` both
    hash to fc3a08aa…; that is 834 lines and the same value as Task 2.
  - On hw, Overflow logs `[refusal] rm upgrades sent=22 declined=0`,
    `core fault line: 0`, and exit 139.
  - The t3a failure (the 232-byte split) is recorded.
- ✅ **Box 3.1.**
  - 1.4: the corpus was repeated on base-hw (Task 2), and again with the
    final shim.
  - 2.3: both round trips were repeated, with records word for word as on
    base-linux.
  - Both are in separate base-hw files: `genode-corpus-base-hw.txt` and
    `genode-channel-base-hw.txt`. GB-009's per-base split is held.
- ✅ **Box 3.2 may stay checked.** The box is written as three actions and
  one constraint: "**Run** the runtime profile's binary check on the
  component, **record** CPU execution for device paths, and **validate**
  OpenSpec strictly; leave the Genode host's confinement tasks unchecked".
  It does not say "pass the binary check", and no GB requirement or
  design.md line requires a passing check.
  - "Run" was done. I reran the check: 158 undefined, effect rows exactly
    `Genode.log Genode.put Genode.take`, "FAIL (outside the monitor
    profile)". The FAIL is stated as a FAIL in tasks.md:85-90, in the
    record, and in GENODE.md. The allow lists are unedited.
  - "Record CPU execution" was done. BANGS is 0, 1, and 3 in the generated
    C, the gate is at gpuexample.c:22043, and `--gpu off` is used
    throughout.
  - "Validate OpenSpec strictly" was done. I reran it from the store path:
    44/44.
  - The confinement tasks are untouched.

  The section text keeps the FAIL visible, so checking the box does not
  hide it.
- ✅ **docs/GENODE.md.** It has a new "Runtime rows on base-hw" section that
  leads with an example and states the gap. The "base-linux first,
  base-hw second" ordering is narrowed, not closed, with reasons: emulated
  boot, one lane, and no confinement. design.md is untouched; it is outside
  the touch list, which the report notes.
- ✅ **INVENTORY.** It records:
  - the counters;
  - the unlocked `cnt()` read, admitted as unable to change what take
    returns;
  - the 232-byte LOG split as the reason the counter sits on its own line;
  - the host differences;
  - the Task 3 change list.
- ✅ **Carried Task 2 minors, all eight addressed.**
  1. The tasks.md:3 wording.
  2. The lock-hazard rationale (shim header and INVENTORY).
  3. The no-blocking claim, scoped to RM routed to core through init.
  4. The rm-upgrade counters, in the report and before a refusal.
  5. Overflow on hw fails on a core fault line.
  6. The corpus record names the unstripped `app/` path.
  7. The reason for `-m 4096`.
  8. writ_probe_fault ends at core's line on hw. The t3b log ends at `core
     fault line: 1` with "Run script execution successful".
- ✅ **Hygiene.**
  - No `.bend` file changed.
  - Nothing built was committed. `.superpowers/` is ignored.
  - The live copies are cmp-identical: shim, monitor tcl, overflow.run, and
    probe_fault.run under `../writ-genode/writ-repo/`.
  - The Task 2 review and this record directory are committed. The only
    uncommitted changes are the controller's activity.log and progress.md
    lines.
  - The pkill mishap left no trace in the tree or the logs. Every batch
    summary ends in DONE.
- ⚠️ **Shim scope.** The brief says "fix only inside the shim's channel
  section". Only the take diagnostics are in the channel section. The
  population-path counters and the header text are the controller-carried
  minors 2-4, so this is acceptable and recorded in INVENTORY.

## Code quality

The shim change is diagnostics only: the `cnt()` read sits before the same
`down()`, and the new log lines are on lines of their own. The tcl changes
are confined to `have_spec hw` branches, and base-linux keeps its prior
requirements. The Overflow core-silence check uses the right core
strings (region_map_component.cc:97-110). No policy moved into the shim.

## Critical

None.

## Important

None.

## Minor

1. **The base-hw replacement row in dead_client is redundant and its label
   overstates it.**
   - Where: `scripts/genode/writ_bend_monitor/writ_bend_monitor.tcl:345`.
   - What: on base-hw the replacement row requires `client: request sent,
     staying alive with no result handler`. Row 343 already requires that
     exact line. Its label, "freed-context client still alive", also
     claims more than the row checks: the line is printed before the
     monitor's put, so it does not show the client survived anything.
   - Why it matters: the hw run silently has one requirement fewer than the
     label suggests. The record's own text (channel record:160-163) is
     accurate. The tcl label is not.
   - Fix: on hw, either require that init did not report `child
     "writ_client_f" exited`, or drop the row and keep a comment.
2. **The queue coverage is recorded from one run, without saying it is
   timing-dependent.**
   - Where: `verification/genode-channel-base-hw.txt:129-134` and
     `hosts/genode/INVENTORY.md:627-631`.
   - What: there were two hw queue runs. t3b gave signals=94 coalesced=78,
     and t3d gave 155 and 139. Only t3d is cited. Neither file says the
     number is timing-dependent, or that the script does not require
     coalescing (it requires `ring max=[1-8]` only). INVENTORY's "The ring
     bound held, and no entry was dropped (ring full=0)" reads as if ring
     full could have happened. INVENTORY:400 says it cannot happen, by
     construction.
   - Fix: add one sentence to both files. It should cite both runs' counts,
     call the coverage "observed, timing-dependent, not required by the
     script", and point to INVENTORY:400-402 for why ring full=0 holds by
     construction. GENODE.md:459 ("not reliably exercised") can stay, with
     "(on base-hw, observed in both runs)" added.
3. **The dead_client exit code is reported inconsistently.**
   - Where: `verification/genode-channel-base-hw.txt:165`.
   - What: the record says "rc 1" for the first base-hw dead_client run.
     `batch-hw-t3b.summary` records `rc=2` (make's exit; the inner run tool
     gave `Error 1`). The liveness line at :154 uses make's rc 2.
   - Fix: say "rc 2 (run script exit 1)" so both lines use the same
     convention.
4. **The corpus record's binary hashes are stale and not marked as such.**
   - Where: `verification/genode-corpus-base-hw.txt:53`.
   - What: the binary hashes are the Task 2 builds with shim 67cc3617. The
     corpus binaries were rebuilt with db8a376d at t3b; for example,
     `app/writ_bend_tests/writ_bend_tests` is now 5069f8a1…. The listed
     hashes therefore do not recompute against the current tree. The
     rerun's line hash is recorded only in the channel record and in the
     runtime-rows update.
   - Fix: add a dated Task 3 note under the hashes, giving the db8a376d
     binary hashes and the t3b log paths.
5. **The take counter's race is only half disclosed.**
   - Where: `hosts/genode/shim/writ_mem.cc:1696-1710` and
     `INVENTORY.md:597`.
   - What: `_channel_take_parked` is incremented outside `_channel_mutex`,
     but `writ_mem_report` reads it under that mutex. INVENTORY discloses
     only the `cnt()` race. The increment is harmless: there is a single
     take thread and the value is diagnostic.
   - Fix: add one clause, "the counter is written by the take thread
     without the channel mutex; diagnostics only".

## Assessment: Approved

Spec compliance holds on every point. Every claim in the brief was checked
against logs, hashes, the Genode source, and the generated C. The
differences between the kernels are real, cited, and handled in the run
scripts only. Box 3.1 is correct. Box 3.2 is correct as written, because
the box's verbs are "run", "record", and "validate", and the FAIL is stated
plainly. Code quality: the change is diagnostics only, the base-hw branches
are gated, and no policy moved into the shim. The five minors are wording
and test-precision fixes and can be carried.
