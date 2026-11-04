# Task 2 review: corpus, examples, and the fault row on base-hw

Reviewer: task reviewer, 2026-11-04. Range 63af1b2..2c34792 (one commit).
Read: brief, plan Global Constraints, report, the full diff, the shim's
`_upgrade_rm_session`, `_attach_pieces`, `_populate`, `_resolve_fault`,
`Rm_fault_handler::_handle`, and the mprotect re-attach path; the Genode
26.08 sources `rm_session/connection.h`, `base/connection.h`,
`lib/base/component.cc` (Env::upgrade), `lib/base/child.cc` (Child::upgrade),
`core/include/region_map_component.h:420-440`. I recomputed what follows
from the files on disk rather than relying on the report.

## Recomputed

- Shim: committed and live `writ-repo/src/writ_shim/writ_mem.cc` both sha256
  `67cc3617...b32ff`; live mtime 12:39:07. Every touched run script is
  cmp-identical to its live copy (the seven at 12:46:20-21; overflow at 11:49,
  before both Overflow runs).
- Corpus: running the recorded extraction on `run-hw-writ_bend_tests-t2b.out`,
  `-1.out`, and `run-writ_bend_tests-t2b-linux.out` gives 834 lines, 782 PASS,
  sha256 `fc3a08aa...`, an empty diff against `merged/tests-1.out` for all
  three. The shim line in both hw logs reads `ram used=12681216 limit=268143196
  caps used=50 limit=951 ... elsewhere=9 released=8`. The base-linux line
  (12558336, caps 40) is the same as in Task 1's fr1 log, so the shim change
  left base-linux unchanged.
- Reference: `verification/tests-native.txt` last changed in a4cbe1d, an
  ancestor of d8b1473, and it has not changed since d8b1473. Recapture was not
  required, and the record says so (genode-corpus-base-hw.txt:38-40).
- Examples (t2b): example 17, flow 5, transfer 5, gpuexample 7 lines. The
  hashes match the record, every diff is empty, and every run reports exit 0.
- Binaries: the recorded sha256s match `app/<name>/<name>`, the unstripped
  binaries, not `bin/`. Their objects were rebuilt after 12:39:07, and each
  t2b log is newer than its binary.
- Overflow logs: run 1 shows `-m 4096`, "4078 MiB ... assigned to init", the
  `attach OUT_OF_CAPS` refusal, exit 139, and the script's guard-page error
  (rc 2). Run 2 shows the guard refusal at 0x2280000000, `exited with exit
  value 139`, and "Run script execution successful". Neither log has an
  illegal, violation, or unresolvable line. The base-linux Overflow still hits
  the guard at 0x7ffff7f43000, and its ps control reads 1.
- `writ_probe_fault` hw log: line 107 is core's `illegal WRITE ... pd='init ->
  writ_probe_fault'` line, followed by the timeout.
- Rows runs (t2c): every hw and base-linux log ends "Run script execution
  successful", and the quoted values (probe 1→112, clock delta 103453000,
  reservation `released=1` at 1814528, threads done=2, process exit 3,
  evloop EAGAIN, rts 1/0) match the logs.
- OpenSpec 1.16.0 strict: 44 passed, 0 failed. No file under
  `openspec/specs/` or the change's `specs/` was changed.

## Spec compliance

- ✅ Corpus: 782 PASS lines on base-hw, byte-identical to the Linux
  reference. No recapture was needed, for the reason recorded. The logs are on
  disk, newer than the final shim, and the live copy is identical.
- ✅ Quota recorded: 256M with 1000 caps (951 visible) for the corpus and
  examples, QEMU's 800M default ("779 MiB ... assigned to init"), and the
  shim report line quoted verbatim.
- ✅ The four examples are byte-identical and exit 0, run before and after the
  shim change.
- ✅ Overflow run 1 is recorded as an error with its cause: core's RM session
  starts with 64 KiB and 2 caps, and attach, unlike `create`, does not top up
  (connection.h:36-50). Run 2 shows the guard refusal and init's exit 139
  with core silent. On hw the script requires the refusal line, guard page at
  the default quota, and exit value 139 exactly. The `-m 4096` setting and its
  reason are in the header (overflow.run:44-54).
- ✅ The GB-003 substitute is worded as the controller ruled, and the six
  limits appear in tasks.md, the rows file, and INVENTORY. Core's `illegal
  WRITE` line is cited (region_map_component.cc:103) and attributed to a
  component without a handler, explicitly "not the GB-003 case".
- ✅ Box 1.3 is checked for base-hw only and says base-linux does not satisfy
  it. 1.4 is unchecked-then-unchanged with its base-linux evidence, 3.1 stays
  open, and no spec text changed.
- ✅ Rows file: it has the same eleven rows as the base-linux file, each with
  provenance (Bend program, C probe, or source reading/compile), and every row
  run on hw is recorded. writ_probe_fault's run script is left unchanged,
  with the reason (it expects base-linux behaviour).
- ✅ Carried minors: M1 checks the PD areas before the shim mutex
  (writ_mem.cc:806-814, with the reason why that is safe). M2 adds the
  writ_fault-thread limit to the header (writ_mem.cc:130-134) and INVENTORY.
  M3 extends GB-003 item 5 in genode-bend-hello-base-hw.txt.
- ✅ `\r?\n` → `\r*\n`: every positive check is still anchored to the exact
  line text and still requires a trailing `\n`, so a missing line still
  fails. The one negative check (`resumed`) gets stricter: under `\r?\n` it
  could never match QEMU's `\r\r\n`, which would have hidden a resumption on
  hw. The seven scripts were rerun on both kernels with rc 0 (t2c logs),
  after their final mtime.
- ✅ Hygiene: one authored C++ unit has policy-free changes; no `.bend` file
  changed; nothing built is committed; the evidence always says "emulated
  boot", never native hardware; the record directory is committed.
- ⚠️ docs/GENODE.md is unchanged. The plan assigns its base-hw paragraph to
  Task 3, so this is not a Task 2 defect. It is listed so it is not lost.

## The RM-session upgrade, judged

- **Bounded.** The loop allows at most 4 upgrades and 5 attaches per piece
  (`attempt < RM_UPGRADE_ATTEMPTS`). `REGION_CONFLICT` and
  `INVALID_DATASPACE` never retry, because `_upgrade_rm_session` returns
  false for them. Each upgrade is the amount `Rm_connection::create` itself
  uses. Total spend is bounded by the PD margins. When pieces detach, core
  returns their metadata to the session, so repeated populate and release
  cycles reuse the quota instead of growing it.
- **Fail-closed.** If the PD cannot pay, the function returns false and the
  named `attach OUT_OF_*` error stands. If init refuses the transfer,
  `Env::upgrade` ignores the non-PENDING result (component.cc:226-232),
  init logs a warning (child.cc:418-426), and the retry fails again until
  the bound. Both cases end in the named error, the refusal line, and exit
  139.
- **Policy-free.** Init moves quota the component already owns into its own
  session with core (child.cc:363-385). No new session, route, capability,
  or authority is acquired, and there is no `resource_request`. This is the
  right fix, better than raising the run script's caps, which would only
  have hidden the core-side accounting.
- **Classification first.** `_resolve_fault` rejects `off >= r.size` and
  `in_guard` before `_populate`. The PD-area faults are refused before the
  mutex and never reach `_populate`. A guard or out-of-reservation fault
  therefore cannot trigger an upgrade. The only other caller is the mprotect
  re-attach, on the caller's thread, which never makes the guard range a
  piece.
- **Locking.** The lock order is consistent: shim mutex, then Env mutex, on
  both the writ_fault thread and the mprotect path, and no path takes them
  in the reverse order. The admitted hazard needs three things together: the
  faulting thread holds the Env mutex, the fault is inside a reservation, and
  that chunk's attach exhausts the RM quota. The Env session, upgrade, and
  close code runs on Genode stacks and heap, and the "2 GiB stack" is
  Bend's evaluation stack (a data reservation), not a machine stack. The
  hazard is therefore not reachable on the single-lane corpus. A stack-area
  fault inside a session request is refused before any upgrade, and
  `Parent::exit` does not take the Env mutex. The hazard is stated in the
  header (writ_mem.cc:165-175) and in INVENTORY (Sessions, RM). It is not
  argued to be unreachable (Minor 2).
- **base-linux.** `_attach_pieces` is shared code, but the base-linux reruns
  (hello, rts, reservation live and guard, writ_bend_probe, Overflow, corpus)
  give the same figures as before Task 2.

## Critical

None.

## Important

None.

## Minor

1. `openspec/changes/add-genode-bend-component/tasks.md:3`: "1.1, 1.2, 1.3,
   and 1.4 are complete" does not say that 1.3 holds on base-hw only. A
   reader of the first sentence alone would read 1.3 as covering base-linux
   too; the qualification only appears ten lines later. Fix: "1.1, 1.2, and
   1.4 are complete; 1.3 is complete on base-hw only (below)."
2. `hosts/genode/shim/writ_mem.cc:165-175` and INVENTORY (Sessions, RM):
   the lock hazard is stated, but not why it cannot fire today. Fix: add one
   sentence saying that Env's session, upgrade, and close code touches no
   reservation memory, so the faulter would have to be the mutex holder
   faulting in a reservation, which no current path does. Also say that a
   PD-area fault inside a session request is refused before any upgrade.
3. `writ_mem.cc:166-169`: "answered by init without blocking" is true for
   core's RM service routed through init. Under a parent that serves RM
   asynchronously (a nested init or sandbox), `Env::upgrade` returns PENDING
   and blocks the writ_fault thread. That breaks "a fault never blocks on the
   parent". Fix: scope the sentence to "with RM routed to core, as in these
   run scripts".
4. `writ_mem.cc` `[exit]` report (around line 1760): no counter for
   RM-session upgrades. Overflow run 2 reached the guard, so upgrades
   happened, but the evidence cannot say how many were sent or refused. That
   would tell a reader how close the 3G and 2000-cap run came to the margins.
   Fix: count sent and declined upgrades and print them in the report and
   the refusal path. This would change the report line on both kernels, so
   it is optional at this stage.
5. `scripts/genode/writ_bend_overflow/writ_bend_overflow.run:115-119`: on hw
   the script does not assert that core is silent, although the record leans
   on "core silent". Fix: on hw, fail if `$output` matches `illegal |
   unresolvable exception|violation`.
6. `verification/genode-corpus-base-hw.txt:53`: the binary hashes are of
   `app/<name>/<name>` (unstripped), not of `bin/`. Name the path so the
   hashes can be recomputed without guessing.
7. `hosts/genode/INVENTORY.md:567`: the `-m 4096` entry gives no reason. The
   reason (an 800M guest cannot hold a 3G child) is only in the run script
   and the evidence. Add it in a few words.
8. `scripts/genode/probes/fault/writ_probe_fault.run` (unchanged): on hw it
   runs until timeout (rc 2). That is acceptable with the recorded reason,
   but a `have_spec hw` early exit naming the expected core line would stop
   sweeps from paying the timeout. Defer if preferred.

## Assessment: Approved

Both verdicts pass. Spec compliance: everything required is met, and the one
⚠️ is Task 3's scope. Code quality: the RM-session upgrade is bounded,
fail-closed, free of policy, and runs only after classification, and its
lock hazard is disclosed and not reachable on the evidence's configuration.
The minors are wording and observability improvements. None blocks Task 3.
