# Task 3 report: records (stall branch)

Status: DONE. The stall branch of the brief was written; the "parity achieved" branch does
not apply. No box was checked (2.4 stays open), no requirement text was changed, and no
Bend source changed. Every added sentence cites verification/unikernel-lanes-qemu.txt and
names its section.

## Edited files

- `verification/unikernel-matrix-unikraft.md`
  - :41 Threads row: a "Since (Unikraft lanes lane, 2026-11-05, kept above as recorded)"
    note is appended to the evidence cell. The shipped template is still single-lane. A
    second lane runs, on vCPU 0 only, because nothing calls `uk_lcpu_start` ("Stopping
    point" item 1). Every `--threads 2` run crashes at shutdown on `alloc.c @ 198` with
    QEMU 253, on the `lanes` set and on the shipped template alike ("Stopping point"
    item 2, "Shipped template control"). The corpus was not run on two lanes ("Stopping
    point" item 4). The E6 text and the value column are kept as recorded.
  - :45 Atomics row: a "Since" note: still single CPU, and atomics are not exercised
    across CPUs, on `-smp 2` as well ("Stopping point" items 1 and 4).
  - :465-473 Limits of the Task 2 record: two "Added 2026-11-05" items, one for SMP tried
    with vCPU 0 only and one for the shutdown crash, no corpus run and 2.4 open.
- `docs/UNIKERNELS.md`
  - :276-288, item 2 "A declared single-lane configuration": a "Since" passage. The shipped
    template stays single-lane, and the `lanes` set is the multi-lane evidence (item 1).
    `--threads 2` on the shipped image crashes at shutdown (QEMU 253), so a multi-lane
    build must not be configured ("Shipped template control", item 2). The fix needed is
    named, none was made, and 2.4 stays open (item 3). The earlier E6 sentence is kept.
  - :169-173, Open list: "more lanes (2.4)" now carries the stall with a citation of
    "Stopping point".
- `openspec/traceability/unikernel-library-runtime.md:51` (UL-005 row, gap column): a
  2026-11-05 clause with the stall and a citation of "Stopping point" and "Shipped
  template control". The "Multi-lane divergence" gap now reads "no multi-lane corpus run
  exists", because multi-lane probe runs now exist. The status column is unchanged.
- This record directory: activity.log and this report.

## Checks (verbatim)

`~/.bun/bin/bunx @fission-ai/openspec@1.16.0 validate --all --strict --no-interactive`
(final line, run after the last edit):

    Totals: 44 passed, 0 failed (44 items)

`bend Tests.bend` (Bend 2.0.39, BEND_NO_TELEMETRY=1), exit 0, wall 2.3 s: 782 lines
starting with `PASS`. The summary lines include `Core: 52 checks passed; ...`,
`Property: 324 checks passed; ...`, and the last line is:

    ALL LIBRARY TESTS PASSED

`git diff --stat -- '*.bend'`: empty.

## Concerns

1. Two out-of-scope passages still carry the earlier wording, because they are not in the
   touch list:
   - `verification/unikernel-matrix-unikraft.md:68`, "Open questions settled", still
     says "`--threads 2`: the second lane is created but does not run (E6)". The Threads
     row and the Limits list now carry the update, but this line was not touched. The
     controller may want a "Since" pointer on it.
   - The Unikraft column of the selection matrix in `docs/UNIKERNELS.md` (:194, :201)
     still gives the E6 wording. It is dated 2026-11 and is a record, so I left it.
2. A process slip, now fixed: my second edit pass first replaced the "# Task 1: build
   matrix" heading of the matrix file with "## Matrix" (I had picked the wrong anchor). I
   saw it in the diff, restored the heading, and reran strict validation after the fix.
   The final diff touches only the lines listed above.

## Fix round (final-review.md, findings I1 to I5; text only)

- I1, `verification/unikernel-lanes-qemu.txt` (Result 2 and Stopping point item 1): the
  phrase "at pool_open, at pool_work and at the crash" now reads "at pool_work and at
  _uk_crash (trace 1) and at the alloc.c:198 assertion print (trace 2), each from gdb's
  `info threads`".
- I2, pointers added; the older sentences are kept:
  - `verification/unikernel-matrix-unikraft.md:68` (Open questions settled) gains a
    "Since 2026-11-05" sentence;
  - the "SMP was not tried" item in the matrix's Limits list gains "(since tried,
    2026-11-05: see the entry below)";
  - in the `docs/UNIKERNELS.md` selection matrix, the Threads and Atomics cells gain
    pointers;
  - the Process: CPU count cell now reads "`-smp 2` booted (set `lanes`) only with
    explicit `--threads`; the default count on two vCPUs was not recorded".
- I3, `verification/unikernel-lanes-qemu.txt`: two Task 1 sentences gain a
  "(Superseded by Task 2 ...)" note pointing to "Shipped template control". They are
  Result 3 (shipped template not tried) and the matching "Not exercised" item.
- I4, attribution and inference:
  - the Threads "Since" note in the matrix (:41) now credits `pool_work` entered to set
    `lanes` (`UKPLAT_CPU_MAXCOUNT=2`, `HAVE_SMP=y`) on `-smp 1` and `-smp 2`, and says
    it was not traced on the shipped template;
  - in the evidence file, Result 1 now names the confounded E6 comparison (HAVE_SMP and
    the APIC controller; which change matters was not isolated) and says every trace is
    of set `lanes`; the shipped-template control showed the same output and crash
    without a trace;
  - Stopping point item 1 says the same;
  - the "It follows from" sentence of the shipped-template control is now marked
    "Inferred", naming the 33/253 split and the released thread "main" (trace 3);
  - the UL-005 traceability row and the tasks.md 2.4 note gain "(set `lanes`,
    `UKPLAT_CPU_MAXCOUNT=2`)"; box 2.4 stays unchecked.
- I5, `hosts/unikraft/INVENTORY.md`, under the controller's ruling to touch the file:
  - the `run.sh` row shows `[vcpus]`: `-smp <vcpus>` when given, nothing when omitted
    (QEMU's default of one vCPU);
  - the `check-corpus.sh` row shows `[lanes] [vcpus]` (both default 1): when either is
    given, the script boots once through `run.sh`, then checks the capture under
    `WRIT_NO_BOOT=1`.
- Not done:
  - `verification/source-sha256.txt` is untouched (M1, the merge step);
  - the minor items m1 to m7 were not applied.
- `~/.bun/bin/bunx @fission-ai/openspec@1.16.0 validate --all --strict --no-interactive`,
  final line:

      Totals: 44 passed, 0 failed (44 items)

- `git diff --check`: clean. No `.bend` file changed, so `bend Tests.bend` was not rerun
  (782 is recorded above).
