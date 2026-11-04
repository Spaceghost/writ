# Plan: Unikraft `linuxu`, the process-execution row (task 1.3)

Spec: `openspec/changes/add-unikernel-library-runtime/` task 1.3: "If Unikraft is chosen, run the reference program under its `linuxu` platform and record it as process execution, not a boot." Ruling (Josh, 2026-11-04, question q4): chase it, time-boxed. The pinned Unikraft 0.21.0 has no `linuxu`; the 0.16.3 tree that has it stopped at `bend: reservation failed` in the earlier matrix work (`verification/unikernel-matrix-unikraft.md`, `docs/UNIKERNELS.md`). Prior work on master: `hosts/unikraft/` (scripts, `host.c`, `exit_device.c`, INVENTORY), `verification/unikernel-*.txt`, `verification/unikernel-pins.txt`.

## Global Constraints

- The 0.21.0 pin is untouched. A second, separately pinned 0.16.3 tree lives under `../writ-unikernel/linuxu/` with its own `kraft` or `make` configuration recorded in `verification/unikernel-pins.txt` (new section) and never mixed with the 0.21.0 app directories. The generated C is never edited; the Bend runtime never patched; Unikraft sources never patched (build configuration may change and is recorded with its reason).
- A `linuxu` run is process execution on the host kernel, recorded as such; never a boot, never native evidence. No root; no KVM.
- Touch only `hosts/unikraft/` (scripts and INVENTORY), `scripts/unikernel/`, `verification/`, `docs/UNIKERNELS.md`, and the change's `tasks.md` (box 1.3 only with evidence). Nothing built committed. Do not push; commit at each acceptance point; no manifest.
- Record: `docs/superpowers/records/2026-11-04-unikraft-linuxu/` (ledger with Branch line, briefs, report, activity.log with one line per step and a heartbeat every 10 minutes during long builds); `git add -A` that directory with each commit.
- Time-box: about three hours in total. A recorded stall with the exact message and the last working step is a valid outcome.

### Task 1: The hello under `linuxu`

Pin 0.16.3 (commit and tarball hash recorded), build the `IO.print` hello as a `linuxu` application with the same single-lane configuration the matrix used, and run it as a process. If the runtime's reservation fails, try in this order and record each: (1) `+RTS` options that shrink the heap and stack reservations if the runtime exposes them (cite `bend guide` or the generated C); (2) the platform's memory configuration (`CONFIG_LINUXUPLAT_*`, heap size) raised; (3) a `MAP_NORESERVE`-style path if `linuxu` has one. Expected: `hi` and exit status 0 from the process, or the exact failing line. Evidence: `verification/unikernel-linuxu.txt` with commands, versions, the process exit status, and the strace-free observation of the mapping that failed if it did.

Acceptance: `hi` as a `linuxu` process with exit 0, or a recorded stall naming the reservation and the three attempts.

### Task 2: The corpus or the stopping point, and the box

If Task 1 printed `hi`: build `Tests.bend` the same way and run it as a process; compare line for line with the Linux single-lane reference (782 PASS expected); run `scripts/runtime-profile/check-binary.sh` on the ELF and record it; check box 1.3 with the evidence named and the words "process execution, not a boot". If Task 1 stalled: write the stopping point into `docs/UNIKERNELS.md` (one paragraph) and `tasks.md` 1.3's note, leave the box unchecked, and record which of the three attempts came closest.

Acceptance: either 782 PASS as a process with the box checked, or the stall recorded in the three places.
