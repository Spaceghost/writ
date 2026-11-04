# Task 2 report: corpus, examples, and the fault row on base-hw

Status: DONE (2026-11-04, about 11:50 to 12:58 -06:00)

All evidence is QEMU TCG emulated boot (Genode 26.08 base-hw, BOARD=pc),
CPU only (`--threads 1 --gpu off`). Not native hardware, not GPU.

## Outcome

- Corpus on base-hw at ram 256M, caps 1000: 782 PASS lines, 834 component
  lines, byte-identical to the Linux reference (sha256 fc3a08aa...), exit 0.
  Run before and after the shim change; identical shim reports
  (12681216 bytes used, caps 50).
- Four examples at 256M: exit 0, each byte-identical (example 17 lines,
  flow 5, transfer 5, gpuexample 7). Run twice, as the corpus.
- Overflow at ram 3G, caps 2000 (QEMU guest 4096M):
  - Run 1: refused at 0x2206c00000 with `chunk could not be attached: attach
    OUT_OF_CAPS`, init exit 139, core silent. The RM session's quota
    (2 caps) was exhausted by piece attaches; core-side attach does not
    upgrade on demand.
  - Fix in the shim (not the run script): bounded RM-session upgrade from
    the PD's own quota, under the PD margins.
  - Run 2: `writ_mem: unresolved fault at 0x2280000000 (guard page),
    component terminates`, then `[init] child "writ_bend_overflow" exited
    with exit value 139`. Core logged nothing. No result, no resumption.
- Core's own record of an unresolvable fault was seen only for a component
  without the shim (C probe `writ_probe_fault`): `Error: illegal WRITE at
  address 0x402beff0 by pager_object: pd='init -> writ_probe_fault'
  thread='ep' ip=0x1000025` (region_map_component.cc:103). With the shim's
  handler registered, core reflects and omits diagnostics
  (region_map_component.h:430-440).
- Box 1.3 checked, worded "the parent records the component's self-reported
  fault exit on base-hw", with the six limits cited. Box 1.4's evidence stays
  base-linux. Box 3.1 stays open (it also needs 2.3 on base-hw).
- Rows file written: `verification/genode-runtime-rows-base-hw.md`; all rows
  run on base-hw (Bend program, C probe, or source reading per row).

## Changes

- `hosts/genode/shim/writ_mem.cc` (2ad3e416 -> 67cc3617):
  - M1: the PD-area check runs before the shim mutex.
  - M2: a fault on the writ_fault thread halts with no record (header).
  - `_upgrade_rm_session` and the retry in `_attach_pieces`
    (8 KiB / 2 caps, at most 4 per piece, PD margins kept). The header
    states the Env-mutex limit.
- `scripts/genode/writ_bend_overflow/writ_bend_overflow.run`: hw header,
  `-m 4096` on hw, exit 139 required on hw, `\r*\n`.
- Seven run scripts: `\r?\n` -> `\r*\n` (the first hw run of each failed
  on the matcher only; the component lines were correct). Rerun on both
  kernels, rc 0.
- `hosts/genode/INVENTORY.md`: RM session text, observed list, Task 2
  changes, Overflow on base-hw.
- `verification/genode-bend-hello-base-hw.txt`: M3 (GB-003 item 5).
- New: `verification/genode-corpus-base-hw.txt`,
  `verification/genode-runtime-rows-base-hw.md`.
- `openspec/changes/add-genode-bend-component/tasks.md`: 1.3 box and text.

## Verification

- base-linux, final shim: hello, rts, reservation live and guard,
  writ_bend_probe, Overflow (guard at 0x7ffff7f43000, init silent), corpus
  (782, identical). All rc 0.
- base-hw, final shim: hello, guard probe (exit 139), null-pointer scratch
  probe (exit 139), corpus, four examples, Overflow, rts, writ_bend_probe,
  reservation live, threads, clock, evloop, process probes. All rc 0, except
  writ_probe_fault, whose script expects base-linux behaviour (recorded as
  core's line above).
- Live copies under `../writ-genode/writ-repo/` cmp-identical to every
  committed file touched.
- OpenSpec 1.16.0 (`~/.bun/bin/bunx @fission-ai/openspec@1.16.0`):
  `validate --all --strict --no-interactive`, 44 passed, 0 failed.
- Not run: `bend Tests.bend` and `bend PROOF.bend`. No `.bend` file changed.
  The corpus ran as a component on both kernels.

## Concerns

- The RM-session upgrade calls `Env::upgrade` from the writ_fault thread.
  That takes the Env's session mutex. If a faulter is halted while holding
  it, the component halts with no record. Not observed. This is stated in
  the header and in INVENTORY.
- The GB-003 record on base-hw is self-reported (six limits). It is not a
  parent-observed fault. A supervising parent with its own handler would
  replace the shim's.
- Stack-area and linker-area faults, and concurrent faulters, were not
  exercised on base-hw.
- writ_probe_fault's run script is still base-linux only. On hw it times out
  after core's line. It was left unchanged.
