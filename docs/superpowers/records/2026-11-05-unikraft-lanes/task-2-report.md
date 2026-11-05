# Task 2 report: stopping point (stall record)

Status: DONE. Under the controller's ruling, Task 2 is the stall record: no corpus build
was made and box 2.4 stays open.

## Shipped-template control

- Set `lanes1`:
  - `mkapp.sh lanes1`; its Kraftfile is byte-equal to the template (`ea319440...`);
  - the resolved `.config` (`7e108a27...`) has `UKPLAT_CPU_MAXCOUNT=1`, no SMP line,
    and `LIBPOSIX_FUTEX=y`;
  - `lanes.c` is the same generated C as Task 1 (`26d9873e...`).
- `build.sh lanes1 lanes`: exit 0 in 44 s. Image
  `cec64bf8517de01689f8ed8d006e3e83fdb575c2548acb217f9d7d372e353df6`, .dbg `d0dd8b17...`.
- `run.sh lanes1 lanes-t2-s1 lanes "+RTS --threads 2 --gpu off" 120 1024 1`:
  - console: `lanes 2`, `pow2 4194304`, then
    `[    0.311243] CRIT: [libukalloc] <alloc.c @  198> Assertion failure: metadata->base != ((void *) 0)`
    and the crash screen;
  - QEMU 253, wall 0.5 s.
- `run.sh lanes1 lanes-t1-s1 lanes "+RTS --threads 1 --gpu off" 120 1024 1`:
  `lanes 1`, `pow2 4194304`, QEMU 33, wall 0.5 s.
- Answer: the shipped template also crashes on `--threads 2`. The crash does not
  depend on the CPU count.

## Changes

- `verification/unikernel-lanes-qemu.txt`: appended two sections.
  - "Shipped template control": commands, hashes, and console lines.
  - "Stopping point", in four parts:
    1. the second lane runs on vCPU 0 only. Evidence: the `uk_lcpu_start` grep (only
       the definition at lcpu.c:297 and the declaration at pm.h:118), CPU#1 halted at
       0xfd5fd, and the breakpoint that never hits;
    2. the shutdown crash, which is independent of the CPU count;
    3. what a fix would need, named and not implemented: a `uk_lcpu_start` caller in
       plat/kvm boot, a scheduler per LCPU, and a clean teardown of exited threads at
       shutdown. The alternative is a yielding wait in the runtime's lane loop, which
       would give turn-taking only and would not fix the crash;
    4. what was not exercised.
- `openspec/changes/add-unikernel-library-runtime/tasks.md:146`: box 2.4 stays
  unchecked and gains a one-sentence note citing the file's "Stopping point".
- The activity log.

## Checks

- `bunx @fission-ai/openspec@1.16.0 validate --all --strict --no-interactive`:
  44 passed, 0 failed.
- `bend Tests.bend` was not run. No `.bend` file changed, and Task 3 records the suite.

## Concerns

- No gdb trace of the `lanes1` image. Its crash attribution (the idle-thread GC of
  "main") is inferred from the identical assertion line and exit value, plus the
  Task 1 traces.
- All runs are TCG on the CPU.
