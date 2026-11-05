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
