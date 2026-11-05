# Final whole-branch review: lane/unikraft-lanes

Assessment: **Needs fixes before merge**

Branch: `lane/unikraft-lanes` (9 commits, 3cf56c0..47b486d, base = master 7bc3811).
The required fixes are text only: evidence wording, stale sentences, and two
inventory rows. The scripts are correct, and the default behaviour is byte-identical
for every existing caller. The contribution rules hold. No finding touches code,
policy, or a security law.

## Findings, by severity

### Important (fix before merge)

**I1. "Halted at pool_open" is not what gdb shows.**
- Where:
  - `verification/unikernel-lanes-qemu.txt:24-26` (Result 2);
  - the same sentence again at `:249-250` (Stopping point item 1).
- What the logs show: trace 1 (`$W/lanes/gdb-lanes-s2.cmd`) runs only `bt 3` at the
  pool_open stop. The `info threads` listings showing `Thread 1.2 (CPU#1 [halted ])
  0x00000000000fd5fd` come at three points:
  - pool_work (`$W/lanes/logs/gdb-lanes-t2-s2.log`);
  - `_uk_crash` (same log);
  - the alloc.c:198 `_uk_printk` stop (`gdb2-lanes-t2-s2.log:26`).
- Fix: in both places replace "at pool_open, at pool_work and at the crash" with "at
  pool_work and at _uk_crash (trace 1) and at the alloc.c:198 assertion print (trace 2),
  each from gdb's `info threads`". This was the carried Task 1 review item.

**I2. Stale E6 and "SMP not tried" sentences without a pointer to the new finding.**
Each of these contradicts or predates the new record:
- `verification/unikernel-matrix-unikraft.md:68`: "`--threads 2`: the second lane is
  created but does not run (E6)." Append: "Since 2026-11-05 (Unikraft lanes lane), on the
  current template it is entered and runs on vCPU 0 only, and every `--threads 2` run
  crashes at shutdown (QEMU 253); verification/unikernel-lanes-qemu.txt, 'Stopping point'."
- `verification/unikernel-matrix-unikraft.md:449`: "SMP was not tried." The bullet added
  at `:465` contradicts it two entries later. Append "(since tried, 2026-11-05: see the
  entry below)".
- `docs/UNIKERNELS.md:198` (Threads row; master :194): the E6 cell, no pointer. Append
  "Since 2026-11-05: second lane entered, vCPU 0 only; `--threads 2` crashes at shutdown,
  QEMU 253 (unikernel-lanes-qemu.txt, 'Stopping point')".
- `docs/UNIKERNELS.md:205` (Atomics row; master :201): "exercised on one lane and one CPU
  only". Append "(2026-11-05: a second lane ran on vCPU 0 only, cooperatively; atomics
  across CPUs still unexercised; unikernel-lanes-qemu.txt items 1 and 4)".
- `docs/UNIKERNELS.md:204` (Process: CPU count; not in the known list): "SMP not tried".
  `-smp 2` was run, but always with an explicit `--threads`, so the runtime's default
  count on two vCPUs is still unrecorded. Reword to "`-smp 2` booted (set `lanes`) only
  with explicit `--threads`; the default count on two vCPUs was not recorded".

**I3. Task 1 text in the evidence file is superseded by Task 2 but not marked.**
- Where:
  - `verification/unikernel-lanes-qemu.txt:40-43`: "Whether the same crash happens with
    the shipped ... template ... was not tried: no Lanes image of that template exists and
    the time box allows no third probe build";
  - `:199-200` (Not exercised): "The shutdown crash on an image built with
    UKPLAT_CPU_MAXCOUNT=1 ... not built (time box)".
- Problem: both contradict the "Shipped template control" section at `:204-238`, which
  ran that build under the controller's ruling (ledger, Task 1 ruling).
- Fix: append to each "(superseded by Task 2: built and run under the controller's
  ruling, crashes the same way; see 'Shipped template control')". Keep the original
  sentences, since failed and incomplete outcomes are preserved.

**I4. Observations from set `lanes` are attributed to the shipped template, and a cause
is stated as observed.**
- `verification/unikernel-matrix-unikraft.md:41` (Threads, "Since"): "On the current
  template (signals on) `pool_work(arg=1)` is entered ... on vCPU 0 only".
  - Every gdb trace is of set `lanes` (`UKPLAT_CPU_MAXCOUNT=2`, `HAVE_SMP=y`), the
    `-smp 1` traces included.
  - The shipped-template image `lanes1` has no gdb trace (`lanes-qemu.txt:237-238`).
  - Fix: "On set `lanes` (the current template with `UKPLAT_CPU_MAXCOUNT=2`, so
    `HAVE_SMP=y`), on `-smp 1` and `-smp 2`, `pool_work(arg=1)` is entered ...; not traced
    on the shipped template".
- `verification/unikernel-lanes-qemu.txt:20-21`: credits the difference from E6 to "the
  signal library and the exit hook". E6's image also had `UKPLAT_CPU_MAXCOUNT=1` with no
  `HAVE_SMP`, so the comparison is confounded. Fix: add "and HAVE_SMP/the APIC
  interrupt controller; which change matters was not isolated".
- `verification/unikernel-lanes-qemu.txt:236-237`: "It follows from a second runtime lane
  (a second musl thread) existing at shutdown" is an inference. Also, the thread released
  in the traced crash is named "main" (trace 3). Fix: "Inferred: `--threads 1` ends 33 and
  `--threads 2` ends 253 on both images; in the traced (lanes-set) crash the thread being
  released is 'main'".
- The traceability UL-005 row and the tasks.md 2.4 note say "a second lane runs but only
  on vCPU 0" with no qualifier. Add "(set `lanes`, `UKPLAT_CPU_MAXCOUNT=2`)" to both. This
  matches `docs/UNIKERNELS.md:277-279`, which already qualifies it correctly.

**I5. The trust/source inventory does not list the new script signatures.**
- Where:
  - `hosts/unikraft/INVENTORY.md:144` still lists `scripts/run.sh <set> <label> <probe>
    <append> [timeout] [mem]`;
  - `:148` still lists `scripts/check-corpus.sh <set> <label> [timeout] [mem]`.
- Why it matters: AGENTS.md requires an explicit source and trust inventory. The plan's
  touch list left INVENTORY.md out, so the gap comes from the plan, not the implementer.
- Fix (controller ruling to touch the file):
  - `:144`: add `[vcpus]` (adds `-smp <vcpus>` when given; nothing when omitted).
  - `:148`: add `[lanes] [vcpus]` (when either is given, boots once through `run.sh` with
    `+RTS --threads <lanes> --gpu off` and `-smp <vcpus>`, both default 1, then checks
    under `WRIT_NO_BOOT=1`).

### Merge step (not a branch fix)

**M1. `verification/source-sha256.txt` needs regenerating at merge.** It still lists the
master hashes:
- `run.sh` 671c63a3… (now d42e928f…);
- `check-corpus.sh` 5fc75ee4… (now cf20cee2…).

The new `verification/unikernel-lanes-qemu.txt` and the edited docs are also missing or
stale in it. The plan says "no manifest" in the lane. Earlier merges (10a59cf, 7071864)
regenerated it in the merge commit, so do the same after the fixes above.

### Minor (optional)

- m1. "Firmware range" / "halted in firmware" for 0xfd5fd interprets the address; it
  wasn't measured. It appears at `lanes-qemu.txt:25`, `:250`, `:195` and
  `unikernel-matrix-unikraft.md:41`. The observed facts are the address and gdb's
  `[halted ]` flag. Suggest "at 0xfd5fd, below 1 MiB and outside the image (a BIOS
  address; interpretation)". This was Task 1 review minor 2.
- m2. `lanes-qemu.txt:1-2`: the header says "Task 1" only, but the file now also holds
  Task 2's sections. Add "and Task 2 (shipped-template control, stopping point)".
- m3. `lanes-qemu.txt:252`: the recorded grep is limited to `--include=*.c --include=*.h`.
  A whole-tree grep of `$W/src/unikraft` (7351f8b) also hits
  `lib/uklcpu/exportsyms.uk:18`, which is an export-list entry, not a caller. The claim
  stands, but say so for completeness. No caller exists in `$W/src/libs` or the
  `lanes-unikraft` app either (checked).
- m4. `run.sh`: `vcpus` is not validated (a non-number is passed to QEMU, which rejects
  it). Optional: `case $7 in ''|*[!0-9]*) ...`.
- m5. `check-corpus.sh`: with `WRIT_NO_BOOT=1` in the environment, the `[lanes] [vcpus]`
  arguments are silently ignored, and whatever capture exists is checked. Say so in the
  header comment.
- m6. `docs/UNIKERNELS.md:236` ("Threads is a single lane (E6)") is still true for the
  shipped template. An optional pointer to the new record.
- m7. In the record dir, `task-1-brief.md` and `task-2-brief.md` end with a blank line
  (`git diff --check`).

## What I verified and how

1. Contribution rules
   - `git diff --stat master -- '*.bend'`: empty.
   - `git diff --stat master`: the only files outside the record dir are the 2 scripts,
     the new evidence file, the matrix, UNIKERNELS.md, tasks.md (one added line under
     2.4, box unchecked) and the UL-005 row.
   - Unchanged:
     - no runtime, generated C, Unikraft source, `host.c` or `exit_device.c` change;
     - `git diff master -- hosts/unikraft/app/Kraftfile`: empty;
     - sha256 ea319440… equals the evidence's.
   - No policy in the scripts (argument pass-through only). No binaries or generated
     files in the tree.
2. Script correctness
   - Read run.sh, check-corpus.sh, check-image.sh and env.sh in full.
   - Stub test: I ran the master and branch scripts side by side against a stub
     `qemu-system-x86_64` that prints its argv, in a scratch workspace.
     - run.sh without a 7th argument: identical argv and identical logged command line,
       plain and with `WRIT_QEMU_FEED` + `WRIT_QEMU_SERIAL2` (a chardev spec containing a
       space stays one argument).
     - With `2`: `-smp 2` sits between `-m` and `-cpu max` in both argv and log.
     - check-corpus.sh with 2 or 4 arguments: identical command line to master.
     - With `2 2`: `-smp 2`, `--threads 2`.
     - With lanes only: `-smp 1`.
     - With `"" 2`: `--threads 1 -smp 2`.
     - Empty timeout or mem: defaults 600/4096.
     - Missing image: "log: missing", FAIL, exit 1, and the stale capture is removed
       first.
   - Call sites: every in-tree caller passes 6 or fewer arguments (check-image.sh:28,
     check-fault.sh:30, check-channel.sh:33). So does every recorded command in
     `verification/*.txt`, so no argument position shifted.
   - Bash 5.3: an empty `"${SMP[@]}"` expands to nothing (no `set -u` in the script).
3. Evidence integrity
   - I recomputed every sha256 in `unikernel-lanes-qemu.txt`; all are full-length and
     match:
     - both Kraftfiles and both resolved `.config`s;
     - Hello/Lanes.bend, the generated C (and the claimed equalities with
       `sigcodes/gen/hello.c` and `gen/lanes.c`);
     - all six images and .dbg files;
     - run.sh, check-corpus.sh, build.sh.
   - `cmp` confirms `lanes1-unikraft/Kraftfile` equals the template, and the lanes set
     differs only in the MAXCOUNT line.
   - The `.config` lines were checked (lanes: MAXCOUNT=2, HAVE_SMP, APIC, ACPI, FUTEX,
     UKLCPU IRQs, SCHEDCOOP; lanes1: MAXCOUNT=1, no SMP line, FUTEX=y), as were
     `plat/Config.uk:23-24` and `plat/kvm/x86/setup.c:149-154`.
   - The `uk_lcpu_start` grep, rerun, gives the definition, the declaration, and the
     exportsyms entry; there is no caller.
   - gdb logs read:
     - CPU#1 `[halted ] 0xfd5fd` listings, located as in I1;
     - breakpoint 3 never hit;
     - the lane stacks 0x1000069000 and 0x10800ad000;
     - "released thread 0x400008020 name main".
   - Stated limits:
     - TCG CPU-only and "no GPU" (`:5-9`, `:274-275`);
     - host load caveat (`:12-13`);
     - nothing claims SMP parallelism or two-lane parity: no corpus run, box 2.4
       unchecked, "two lanes on two vCPUs did not happen".
   - The third probe build is covered by the controller's ruling (ledger).
4. Cross-document consistency
   - The matrix, UNIKERNELS.md (`:169-173`, `:276-288`), the UL-005 row and the tasks.md
     note agree with the evidence on each point:
     - vCPU 0 only, `uk_lcpu_start` uncalled;
     - the `alloc.c @ 198` assertion, QEMU 253, on both images; `--threads 1` 33;
     - no two-lane corpus; box open.
   - Exceptions: the stale lines in I2/I3 and the over-attribution in I4.
   - Grepped for "does not run", "not entered", "never runs", "E6", "SMP was not tried",
     "SMP not tried", "two vCPUs" and "multi-lane" across docs/, verification/,
     openspec/ and hosts/unikraft/.
     - Remaining hits outside I2 are either followed by a "Since" pointer, true as
       history, or about OSv.
     - No mentions in `docs/FEATURES.md` or `openspec/FEATURE-ACCEPTANCE.md` need
       changing.
5. Checks run
   - `bunx @fission-ai/openspec@1.16.0 validate --all --strict --no-interactive`: 44
     passed, 0 failed.
   - `bend Tests.bend` not rerun: no `.bend` change; Task 3 recorded 782.
   - `PROOF.bend` not run: no security change.
   - The input `final-diff.diff` differs from a plain `git diff master` only in hunk
     context, not content.

## What remains open for add-unikernel-library-runtime

- Task 2.4 (UL-005 multi-lane): open. What it needs:
  - a `uk_lcpu_start` caller in Unikraft 0.21.0's boot and a per-LCPU scheduler (or a
    newer Unikraft that provides both) for parallel lanes;
  - a fix for the shutdown teardown assertion (`uk_free_ifpages` from the idle thread's
    GC of "main") on any `--threads 2` image;
  - only then a corpus build on two lanes with 782-PASS parity and the recorded lane
    count.
  - Not yet isolated: which configuration change made `pool_work` enter (signals, exit
    hook, or HAVE_SMP). The default lane count on `-smp 2` was not recorded.
- Atomics across CPUs: unexercised.
- The shipped template stays single-lane (`UKPLAT_CPU_MAXCOUNT: 1`, `--threads 1`). A
  `--threads 2` boot of it ends QEMU 253.
- Other open boxes, unchanged by this lane:
  - 1.3 (linuxu);
  - 2.1 (ingress subject scaffolding, `IO.print` twin);
  - 3.1 (accelerated boot);
  - 3.2 and 3.3 (appliance rules, validation);
  - the "Multi-lane divergence" scenario has no instance.
