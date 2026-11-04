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

## Final-review fixes

Merge first: `git merge master` as 985189f (clean; the manifest
`verification/source-sha256.txt` was not touched, for integration to
regenerate). Then one fix pass, committed with final-review.md and
task-3-review.md.

Minors:
1. dead_client on hw: the repeated row is replaced by a check that init
   reports no exit of `writ_client_f`; base-linux keeps core's warning.
2. Queue coverage cites both hw runs (t3b 94/78, t3d 155/139, ring max 8)
   and is called timing dependent, in the channel record, INVENTORY,
   tasks.md Section 3, and GENODE.md.
3. Channel record: "rc 2 (run script exit 1)".
4. Corpus record: dated notes for the Task 3 build and the final-review
   build, with the final binary hashes (shim 9d9d32d2) and log paths. The
   db8a376d binaries were overwritten by the rebuild, so the delivered
   build's hashes are given instead.
5. Shim and INVENTORY: the take-parked counter is written without the
   channel mutex; diagnostics only.
6. `writ_mem_report` prints fixed lines, each under 232 bytes for every tag
   in use (longest 196 in the reservation_live fr run).
7. Limit 5 names the lock-holder halt (LOG, Env-session or shim lock held
   by the faulter: no record; not observed) in tasks.md, the hello record,
   the rows file and INVENTORY.
8. Shim header: the base-linux Env-lock sentence (upgrade in the SIGSEGV
   handler on the faulting thread would deadlock).
9. Stale base-linux-only wording: INVENTORY Status, the stack sentence, the
   run-script headers, and the corpus record's app/ path.
10. `writ_bend_tests.run`: `\r*$`.
11. One proc, `writ_bend_require_refusal_exit` in writ_bend.tcl, used by
    the Overflow and guard run scripts.
12. GENODE.md ordering paragraph: the corpus-then-channel order held per
    base, not across bases.

Integration alignments (each is a description alignment; no requirement
was weakened):
- traceability/genode-bend-component.md, header and GB-002/003/004/006/
  008/009 plus rows 1.3, 3.1, 3.2: describe the base-hw evidence that now
  exists; GB-003 base-linux and the supervisor restart stay unmet.
- traceability/bend-runtime-host-profile.md, header, RH-003, RH-006,
  RH-008: name the base-hw evidence; only the Unikraft channel is pending.
- verification/runtime-profile-hosts.md: the base-hw row filled from the
  corpus and channel records, cell by cell; the emulated-boot sentence, the
  782 history row and the binary-check gap include base-hw; the Unikraft
  channel row stays pending.
- add-bend-runtime-host-profile/tasks.md 2.3 note: cites the Genode change;
  only unikernel waits; box unchecked.
- add-genode-bend-component/design.md: ordering reworded to the per-base
  order that happened; "recorded by the supervisor" on base-hw means init's
  record of a self-requested exit, with no restart; shim line numbers
  refreshed to sha256 9d9d32d2 (the cited revision); a section on the
  runtime host profile gating the monitor.
- docs/PLATFORMS.md Genode row: generated Bend C now evaluates on Genode
  (base-linux and base-hw under QEMU TCG); not native hardware, no host
  qualified.

Reruns with the final shim 9d9d32d2, rc 0 for all 18 scenarios on each
kernel (logs `../writ-genode/run-hw-<name>-fr.out`,
`run-<name>-fr-linux.out`): hello, Overflow (hw: rm upgrades sent=22
declined=0, guard 0x2280000000, exit 139, core silent), the corpus (782
PASS, 834 lines, fc3a08aa, diff empty), the four examples (identical),
writ_bend_probe, reservation live and guard, and the eight monitor runs.
writ_probe_fault was not rerun in this pass (no change to it or to the
shim's refusal path; its t3b run stands). check-binary on the final hw
monitor: rc 1, rows Genode.log/put/take, 158 undefined symbols. OpenSpec
1.16.0 via bunx: 44 passed, 0 failed. Live copies cmp-identical. Not run:
`bend Tests.bend`, `bend PROOF.bend` (no `.bend` changed).

Left for integration: the manifest regeneration; the 3.1 note in
add-bend-runtime-host-profile/tasks.md still calls base-hw a pending
placeholder (outside this pass's allowed edit, which was the 2.3 note).
