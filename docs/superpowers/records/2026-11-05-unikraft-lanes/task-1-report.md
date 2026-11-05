# Task 1 report: two lanes on two vCPUs with a probe

Status: DONE_WITH_CONCERNS. Evidence: `verification/unikernel-lanes-qemu.txt`.

## Outcome

- The second runtime lane runs: with `+RTS --threads 2`, `pool_work(arg=1)` is entered
  and calls `pool_rows` on its own lane stack (gdb). This differs from E6.
- It runs on the boot vCPU only. With `-smp 2` the second vCPU stays halted in firmware
  (`CPU#1 [halted] 0xfd5fd`) at every breakpoint, and `uk_lcpu_start` is never hit. In
  0.21.0 it has no caller; `plat/kvm/x86/setup.c:149-154` runs only `uk_lcpu_mp_init`.
  So two lanes ran interleaved on one vCPU under ukschedcoop. Two lanes on two vCPUs
  did not happen.
- Every Lanes `--threads 2` run (on `-smp 1` and `-smp 2`) prints complete, correct
  output (`lanes 2`, `pow2 4194304`). It then crashes at shutdown:
  `alloc.c @ 198 Assertion failure: metadata->base != NULL`, QEMU 253. The call chain
  is `idle_thread_fn` -> `uk_sched_thread_gc` -> `uk_thread_release` (thread "main")
  -> `uk_free_ifpages`. Nothing hung; no run reached the timeout.
- hello prints `hi`, QEMU 33 in all four configurations.

## Changes (file and line)

- `hosts/unikraft/scripts/run.sh`:
  - the usage line (:2) and comment (:5-9) describe the new optional 7th argument
    `vcpus`;
  - the usage messages are at :31-33;
  - `SMP=(); [ -n "$7" ] && SMP=(-smp "$7")` is at :35;
  - the logged command is at :50;
  - `"${SMP[@]}"` appears in both QEMU invocations (:53, :57).
  - If you omit the argument, nothing is added, so existing calls run and log
    byte-identically.
- `hosts/unikraft/scripts/check-corpus.sh`:
  - the usage line (:2) and comment (:10-14) describe the optional `[lanes] [vcpus]`;
  - :17-25: when either is given (and WRIT_NO_BOOT is not 1), the script:
    1. removes the old capture;
    2. boots once through run.sh with `+RTS --threads <lanes> --gpu off` and `-smp <vcpus>`;
    3. fails if no log appears;
    4. sets WRIT_NO_BOOT=1;
  - :26-27: execs check-image.sh with the same arguments as before.
  - check-image.sh is not touched; it is not in the touch list.
- Workspace only (not in the tree):
  - `$W/lanes-unikraft/Kraftfile`: `CONFIG_UKPLAT_CPU_MAXCOUNT: 2`, the only change.
  - `CONFIG_LIBPOSIX_FUTEX` was already y, so it was not added.
- `verification/unikernel-lanes-qemu.txt` (new).
- This record directory (activity.log, this report).

## Commands and results

1. `mkapp.sh lanes`, then `sed` MAXCOUNT 1 -> 2 in the set copy.
   - Kraftfile hash: `c5ce5a37b387cea2b83d1865ef1dc25936477868070fb406f39a9626ff208eaf`.
   - The template is unchanged (`ea319440...`).
2. `.config` (`2091895ebb95bf8e81d38c7e919b38ec401728ad777b510d491664030f2b44d9`):
   - `UKPLAT_CPU_MAXCOUNT=2`;
   - `HAVE_SMP=y`. At plat/Config.uk:23 this is `default y if UKPLAT_CPU_MAXCOUNT > 1`, a
     default rather than a platform select;
   - `LIBUKINTCTLR_APIC=y`, `LIBUKACPI=y`, `LIBPOSIX_FUTEX=y`, `LIBUKSCHEDCOOP=y`.
3. `bend scripts/unikernel/Hello.bend -o $W/lanes/gen/hello.c` -> `260b70a3...`
   (= sigcodes). `bend scripts/unikernel/Lanes.bend -o $W/lanes/gen/lanes.c` -> `26d9873e...`
   (= the E5/E6 gen).
4. Builds:
   - `build.sh lanes hello`: exit 0 in 89 s, image
     `212b40900a6c962fd54d7d7cd6eab4544acce01c5143b41df1aff237ee0fe621`;
   - `build.sh lanes lanes`: exit 0 in 70 s, image
     `d0fcf6a18ec2e5d08707fb37cd4e75a83d3eb7d8de32975e526c882c02df9818`.
   - No download retries were needed.
5. `run.sh lanes <probe>-t<N>-s<V> <probe> "+RTS --threads N --gpu off" 120 1024 <V>`:

| Probe | N | V | console | QEMU | wall |
| --- | --- | --- | --- | --- | --- |
| hello | 1 | 1 | `hi` | 33 | 0.4 s |
| hello | 1 | 2 | `hi` | 33 | 0.4 s |
| hello | 2 | 1 | `hi` | 33 | 0.3 s |
| hello | 2 | 2 | `hi` | 33 | 0.3 s |
| lanes | 1 | 1 | `lanes 1`, `pow2 4194304` | 33 | 1.2 s |
| lanes | 1 | 2 | `lanes 1`, `pow2 4194304` | 33 | 0.9 s |
| lanes | 2 | 1 | `lanes 2`, `pow2 4194304`, then the alloc.c:198 assertion and crash screen | 253 | 0.9 s |
| lanes | 2 | 2 | same | 253 | 1.0 s |

   - The output is complete in every run.
   - For t2, console.sh refuses the capture because of the NULs in the crash screen;
     the lines above come from run.sh's log.
   - The last console line of the t2 runs is the `r13/r14/r15` register line.
6. gdb runs. QEMU had `-gdb tcp::<port> -S`; the command files and logs are under
   `$W/lanes/`. They gave:
   - the order pool_open -> pool_work(arg 1) on CPU#0 -> _uk_crash;
   - CPU#1 halted at 0xfd5fd;
   - pool_rows called twice from pool_turn (main lane, stack 0x1000069000), then once
     from pool_work (stack 0x10800ad000);
   - the assertion's backtrace given above, with the released thread named "main".
7. Compatibility checks:
   - `WRIT_NO_BOOT=1 check-corpus.sh sigcorpustests tests-m4096` -> PASS, 782,
     QEMU 33;
   - `check-corpus.sh lanes nocorpus 60 1024 2 2` -> run.sh exit 2, `log: missing`,
     FAIL, exit 1;
   - `run.sh` without vcpus logs no `-smp`.

## Concerns

1. Two vCPUs give no parallelism on this kernel. Unikraft 0.21.0 never starts secondary
   CPUs (`uk_lcpu_start` has no caller), and ukschedcoop has one run queue. The
   "second lane runs" result means cooperative interleaving on vCPU 0 only. Atomics are
   still not exercised across CPUs.
2. Shutdown crash: two-lane runs end with QEMU 253, not 33. Task 2's
   `check-corpus.sh ... 2 2` will therefore fail its QEMU-exit check even with complete
   output. The controller should decide whether Task 2 runs or turns into the
   stall/limit record. I did not determine whether the crash comes from MAXCOUNT=2 or
   from any second musl thread alive at shutdown with the current (signals) template.
   That needs a Lanes build of the shipped template, a third probe build that the time
   box does not allow.
3. Time box: the plan says "one hello-sized probe" build. The brief required both hello
   and a pool-entering probe, so I made two probe builds (89 s and 70 s) and no corpus
   build.
4. The set's Kraftfile copy still carries the template comment "Single lane (UL-005):
   one virtual CPU" above the changed value. Only the value was changed, as the plan
   allows.
5. All runs are TCG on the CPU. Wall times were taken on a loaded host (load average 26
   to 76).
