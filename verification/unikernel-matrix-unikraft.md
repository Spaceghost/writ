# Unikraft runtime matrix for the Bend native runtime

Recorded 2026-11-03. Tasks 1 and 2 of the library-unikernel runtime lane (native link:
Bend's generated C compiled as the Unikraft application against lib-musl). Task 2's
runtime-row matrix comes first; Task 1's build matrix follows it. Versions and install
commands are in `verification/unikernel-pins.txt`. Everything built lives under the
workspace `$W`, set from the repository root with `W=$(realpath ../writ-unikernel)`
(on this machine `/mnt/MediaVolume/Media/src/github.com/spaceghost/writ-lanes/writ-unikernel`);
nothing generated is in the tree. The `linuxu` runs are **process execution** of the
image as a Linux process, not a boot. The QEMU runs are **emulated boots** under TCG.
Task 1's runs all use `+RTS --threads 1 --gpu off`; no accelerator was used in either task.

Input: `scripts/unikernel/Hello.bend` (`IO.print("hi")`), emitted with
`bend scripts/unikernel/Hello.bend -o $W/hello/hello.c`
(Bend 2.0.39, 3074 lines, sha256 `260b70a3...45d56cf`).

# Task 2: runtime rows

One row per item of the runtime inventory in `docs/BEND-RUNTIME.md`, each established by
running an image. **Primary configuration:** `qemu/x86_64`, Unikraft 0.21.0, lib-musl
0.21.0, adjustments A1 + A2 + A3 (the plan's four libraries plus `posix-pipe` and
`posix-poll`), `UKPLAT_CPU_MAXCOUNT=1`, cooperative scheduler. All primary runs are
**emulated boots** under QEMU 11.1.2 with TCG. **Secondary configuration:**
`linuxu/x86_64` on Unikraft 0.16.3 (A1 + A2, the Task 1 image), recorded as **process
execution**, not a boot. No run used an accelerator device; every run is CPU-only.

Value key: `supplied` (the host provides the behavior the runtime expects), `substituted`
(the host provides something else in its place; the difference is stated), `missing`
(absent or wrong), `not reached` (an earlier failure stops the runtime first).

## Matrix

| Row | qemu/x86_64, 0.21.0 (emulated boot) | Evidence (primary) | linuxu/x86_64, 0.16.3 (process execution) |
| --- | --- | --- | --- |
| Memory | **supplied**, lazily backed | Hello boots and prints `hi` with `-m 1024` down to `-m 8` (E1). Under gdb the runtime's two reservations are `mmap addr=0x200000000000 len=0x200000000` (8 GiB heap, first hint taken: inferred from no further calls; E2 printed mmap arguments, not return values) and `mmap addr=0 len=0x8000c000` (2 GiB stack + 16 KiB guard + alternate signal stack); no `reservation failed` or `stack guard failed` (E2). Pages are backed on touch only: exhausting guest RAM by stack growth is a Unikraft crash, not the runtime's own message (E4). | **missing**: `bend: reservation failed`, then the process does not exit (killed, 124); same with `+RTS --gpu 64MB` (E10). posix-mmap is dropped on linuxu (no `LIBUKVMEM`). |
| Faults | **substituted** by a Unikraft trap that halts (inferred) | Overflow.bend reaches the guard page (`r08: 000000108003f000` = stack base `0x100003f000` + 2 GiB) and the guest prints `CRIT: Unikraft Crash - Ijiraq (0.21.0~7351f8b)` plus registers; the runtime's `bend: memory fault (machine stack overflow?)` never appears, so its `SIGSEGV` handler does not run; QEMU exits **0** under `-no-reboot`; power-off vs reset not distinguished (inferred) (E4). | not reached: startup stops at the reservation. |
| Threads | **substituted** by a single lane: creation succeeds, `pool_work` was not entered before shutdown in a non-yielding program (E6); behaviour when the main lane yields not tried | Hello makes no parallel call, so `--threads 2` creates no thread (E5, prints `hi`, 0). Lanes.bend with `--threads 2` prints `lanes 2` and the correct `pow2 4194304`, 0 (E5). Under gdb, `pthread_create(entry=pool_work, arg=1)` returns 0, but `pool_work` is not entered by shutdown (the guest powers off first); both `pool_rows` turns run on the main loop's stack `0x100003f000` (E6). The cause is inferred, not traced: with one CPU and the cooperative scheduler, the new thread is never scheduled because the main loop never yields to it. Default thread count (no options): `lanes 1`. | not reached. |
| Clock | **supplied** | Clock.bend prints `before 108`, `after 211`, `advanced`; QEMU exits 0 (E7). One sample: 103 ms across a 100 ms sleep; backward motion was not hunted for. | not reached. |
| Event loop | **supplied** with A3; **missing** with the plan's four libraries | With A3, startup reaches the first print in every probe (E1); `IO.sleep` parks on `select` with a timeout and wakes (E7). Without `posix-pipe`/`posix-poll`, startup stops at `bend: the event loop failed to open` (Task 1 `qemu/x86_64` A1 + A2 run below). A helper thread writing the wake pipe was not exercised: no monitor-profile effect uses an IO helper thread. | not reached (0.16.3 linuxu pulls in posix-pipe and posix-poll by dependency, but startup stops earlier). |
| Process | **substituted**: argv supplied; `BENDRTS` is build-time only; exit status **missing** | argv: `-append "+RTS --bogus -RTS"` prints `bend: unknown runtime option --bogus`; `+RTS --help` prints the usage with `argv[0]` = the kernel path (E3). `getenv("BENDRTS")`: returns nothing by default (`LIBPOSIX_ENVIRON` with only `PATH=/bin`); compiled in as `CONFIG_LIBPOSIX_ENVIRON_ENVP1: 'BENDRTS=--bogus'` it is read (`bend: unknown runtime option --bogus`) (E8). Exit: returning from `main` ends the run with QEMU status 0 under `-no-reboot` whatever `main` returned (power-off vs reset not distinguished; inferred) (`return 1` after the bad option also gives 0) (E3); `exit(3)`, `exit(0)` (IO.exit) and `_exit(1)` (runtime failure; the `--threads 0` run, which is `err_fail` then `_exit(1)` by reading the emitted C, line 3043 of `hello.c`, not by a trace) leave the guest idle until killed, 124 (E9); gdb shows the idle thread in `plat_native_lcpu_halt_irq` (E9). | argv **supplied** (`--help` usage, `--bogus` message). `BENDRTS` from the host environment is **not** read (`BENDRTS=--bogus` still reaches `reservation failed`). Return from `main` gives status 0 whatever it returned (`--bogus` returns 1, observed 0); `_exit(1)` after the reservation failure does not end the process (124) (E10). Needs a TTY on stdin (Task 1). |
| Atomics | **supplied** by the compiler (A1), single CPU only | Every probe compiles against GCC's `stdatomic.h`. Exercised: the pool counters on the main lane in Lanes.bend `--threads 2/4` (correct result, E5; one lane only, since the second never runs, E6) and the `err_claim` compare-and-swap on the `_exit` paths (E9). Nothing here shows atomics under contention: no second lane ran and there is one CPU. | supplied at compile time; exercised only by `err_claim` before `_exit`. |
| Device dispatch (`!` calls) | **missing** (CPU only), by construction | The value is by construction, not an observed failure: no accelerator code is compiled (the CUDA/Metal branches are under `BEND_CUDA`/`__OBJC__`, unset; Task 1). No probe uses `!`. `+RTS --gpu 64MB` is accepted but, with no `!` call in the program, does not change the heap reservation: `len=0x200000000` either way (E2). Every run is CPU execution with `--gpu off` or no option; no `!` program was run. | same: not compiled, by construction. |

### What the runtime profile's fault rule accepts

RH-006 (`openspec/changes/add-bend-runtime-host-profile`) accepts either the runtime's
stack error with a nonzero exit, or "the freestanding host halts with a recorded trap",
and forbids resumption. Of the outcomes the brief lists (runtime message, kernel trap
message, hang, silent exit), **qemu showed a kernel trap message followed by a halt**: no
resumption, and the trap is recorded on the serial console only. The exit status (0) is
the same as a successful run, so a harness that reads only the status cannot tell a fault
from success; the substitute qualifies only if the harness reads the console record.
Running out of guest RAM by stack growth (Overflow at `-m 1024`; arena exhaustion not induced) gives the same trap with the same status (E4), so
the profile's memory requirement as summarized in its explainer (FR-003, "exhaustion
halts with the runtime's own message") is not met either.

### Open questions settled

- `+RTS` options reach `main` via `-append` on QEMU, with `LIBUKLIBPARAM` unset (E3).
- The reservation succeeds by default on qemu; no smaller span was needed. For a program
  without `!` calls, Bend 2.0.39 offers no option for a smaller span: the CPU heap is a
  fixed `1 << 33` bytes in `corpus_setup`, and `--gpu <size>` only sizes the device span
  (E2). The 2 GiB stack reservation per lane is fixed too.
- `--threads 2`: the second lane is created but does not run (E6).

## Probes

New Bend programs, all under `scripts/unikernel/`, each emitted with
`bend scripts/unikernel/<P>.bend -o $W/gen/<p>.c` (hashes in `verification/unikernel-pins.txt`):

- `Hello.bend` (Task 1): memory, event loop, argv, return-from-main.
- `Clock.bend`: `IO.now()` around `IO.sleep(100)`; exits 1 if the clock did not advance.
- `Overflow.bend`: non-tail recursion `depth(10^9)`. Calibrated as a native Linux
  process (`clang -O2 -static`, outside the tree): `depth(10^6)` and `depth(10^8)` return,
  `depth(10^9)` prints `bend: memory fault (machine stack overflow?)` and dies by
  `SIGSEGV` (status 139). That is the reference outcome the unikernel is compared with.
- `Lanes.bend`: `pow2(22)` with a parallel let at every level, plus `IO.thread_count()`.
  Hello cannot exercise threads: it makes no parallel call, so the runtime never opens
  its pool.
- `Exit.bend`: `IO.exit(3)`. The `exit(0)` variant (E9) was made outside the tree with
  `sed 's/IO.exit(3)/IO.exit(0)/; s/exiting with 3/exiting with 0/' scripts/unikernel/Exit.bend > $W/gen/exit0.bend`,
  emitted with `bend $W/gen/exit0.bend -o $W/gen/exit0.c` (exit0.c sha256 `ea0258f75b4f71f4145fc34cac2e0d4e34aacf4ddaa33f03d0790d75e01e6439`).

On the Linux host (native static build, outside the tree) Clock prints `advanced`, Lanes
prints `lanes 2` / `pow2 4194304` under `--threads 2`, and Exit exits 3: the probes are
right, so a different unikernel outcome is the host's.

Calibration commands and outputs (re-run in Task 3; Linux x86_64, clang 23.1.1, Bend
2.0.39; logs `$W/logs/task3/calib-*.log`). The depth variants are made outside the tree
from the in-tree probe; `overflow-1e9.c` is byte-identical to `$W/gen/overflow.c`
(sha256 `1e273e1a...`):

```sh
cd <repository root>; W=$(realpath ../writ-unikernel); mkdir -p $W/calib
for d in 6 8 9; do
  sed "s/depth(1000000000n)/depth(1$(printf '%0*d' $d 0)n)/" scripts/unikernel/Overflow.bend > $W/calib/overflow-1e$d.bend
  bend $W/calib/overflow-1e$d.bend -o $W/calib/overflow-1e$d.c
  clang -O2 -static $W/calib/overflow-1e$d.c -o $W/calib/overflow-1e$d -lm
done
for p in Clock Lanes Exit; do q=$(echo $p | tr A-Z a-z)
  bend scripts/unikernel/$p.bend -o $W/calib/$q.c
  clang -O2 -static $W/calib/$q.c -o $W/calib/$q -lm
done
cd $W/calib; ulimit -c 0
```

```
$ ./overflow-1e6 +RTS --threads 1 --gpu off; echo $?
overflow probe start
1000000
0
$ ./overflow-1e8 +RTS --threads 1 --gpu off; echo $?
overflow probe start
100000000
0
$ ./overflow-1e9 +RTS --threads 1 --gpu off; echo $?
overflow probe start
bend: memory fault (machine stack overflow?)
Segmentation fault
139
$ ./clock +RTS --threads 1 --gpu off; echo $?
before 175353151
after 175353251
advanced
0
$ ./lanes +RTS --threads 2 --gpu off; echo $?
lanes 2
pow2 4194304
0
$ ./exit +RTS --threads 1 --gpu off; echo $?
exiting with 3
3
```

(`Segmentation fault` is the shell's report of the child's `SIGSEGV`, shortened from
`bash: line 1: <pid> Segmentation fault  timeout 300 ./overflow-1e9 ...`.)

## Build and run harness (outside the tree)

Application directory `$W/rows-unikraft/`, created as in Task 1 (empty `Config.uk`,
`compiler-include/stdatomic.h` symlink by `gcc -print-file-name`), with the A3 Kraftfile
(`name: rows-bend`, only the `qemu/x86_64` target) and this `Makefile.uk`:

```make
$(eval $(call addlib,approwsbend))
APPROWSBEND_SRCS-y += $(APPROWSBEND_BASE)/../gen/app.c
APPROWSBEND_CINCLUDES-y += -I$(APPROWSBEND_BASE)/compiler-include
```

`$W/rows-build.sh <p>` copies `$W/gen/<p>.c` to `$W/gen/app.c`, runs
`UK_CFLAGS=-std=gnu11 $KRAFT build --no-update --target qemu/x86_64 -j 16 .` in
`$W/rows-unikraft`, and copies the image and its `.dbg` to `$W/images/<p>-qemu[.dbg]`.
`$W/rows-run.sh <label> <p> "<append>" [timeout] [mem]` runs

```sh
timeout $T qemu-system-x86_64 -accel tcg -nographic -m $M -cpu max \
  -kernel $W/images/<p>-qemu -append "<append>" -no-reboot </dev/null; echo $?
```

(default `T=60`, `M=1024`) and keeps the output from the `Booting from ROM` line on,
escapes and CRs removed, in `$W/logs/task2/run-<label>.log`. Rebuilding gave identical
image hashes:

| Image | sha256 |
| --- | --- |
| hello-qemu | `d8744263756b6b66ca4a694bbaf5013209d64bd92d1a226850cfaef0b83c20c4` |
| clock-qemu | `256945e7a4dac6f62be7cff7998124adc7811dcdd6a467e33768ec8ba36c75e6` |
| overflow-qemu | `c69d82a65497ba2d9f743395e6ac1d7bfa9d5894f068e2c5ca4080845e461b41` |
| lanes-qemu | `76ca0853202cccb481c430f0788485d8330a58d83a9e2bab6bbe508f8b1c84af` |
| exit-qemu | `1b81af7c782f23d5e3ed367f221cea4122963dea21aa68b9e8420efab678a1c1` |
| exit0-qemu | `e7dafee793878c8c05478277506be5add3292ef4afd9a14111cb0e0bb275647c` |
| hello-env-qemu | `f512bdcdd85992f8b65d51c002ac82a3deae0df1a032d0c2f9668e359d38c3c0` |

`hello-env-qemu` comes from `$W/rows-env-unikraft/`, the same directory with
`CONFIG_LIBPOSIX_ENVIRON_ENVP1: 'BENDRTS=--bogus'` added to the Kraftfile
(`.config` confirms `CONFIG_LIBPOSIX_ENVIRON_ENVP1="BENDRTS=--bogus"`).

gdb runs attach to `qemu ... -s -S` (or `-s` for the hang) with
`gdb -nx -iex "set auto-load off" -batch -x <cmds> $W/images/<p>-qemu.dbg`, so no script
from the Unikraft build tree is loaded.

In the outputs below the Unikraft banner is shortened to its last line; the last line of
each block is `echo $?`.

## Evidence

**E1 Memory and startup, Hello.** `rows-run.sh hello-t1 hello "+RTS --threads 1 --gpu off"`:

```
                  Ijiraq 0.21.0~7351f8b
hi
0
```

The same with `-m 128`, `-m 64`, `-m 32`, `-m 16` and `-m 8` (`run-hello-m*.log`): each
prints `hi` and gives 0. With `-append ""`: `hi`, 0.

**E2 Reservation sizes (gdb).** Break at `main`, then at `__mmap`, printing `$rdi`/`$rsi`
at each stop (`$W/logs/task2/gdb-span.log`). Command file `$W/gdb-span.cmd`:

```
set pagination off
set confirm off
target remote :1234
hbreak main
continue
hbreak __mmap
continue
printf "mmap addr=%#lx len=%#lx\n", $rdi, $rsi
continue
printf "mmap addr=%#lx len=%#lx\n", $rdi, $rsi
continue
printf "mmap addr=%#lx len=%#lx\n", $rdi, $rsi
continue
printf "mmap addr=%#lx len=%#lx\n", $rdi, $rsi
kill
```

Output:

```
== -append "+RTS --threads 1 --gpu off"
mmap addr=0x200000000000 len=0x200000000
mmap addr=0 len=0x8000c000
== -append "+RTS --threads 1 --gpu 64MB"
mmap addr=0x200000000000 len=0x200000000
mmap addr=0 len=0x8000c000
```

(gdb under TCG reported each stop twice; the duplicate lines are dropped here and kept
in the log.)

**E3 argv and return from `main`, Hello.** (QEMU 0 under `-no-reboot`: power-off vs reset not distinguished, inferred.)

```
$ rows-run.sh hello-bogus hello "+RTS --bogus -RTS" 30
                  Ijiraq 0.21.0~7351f8b
bend: unknown runtime option --bogus
0
$ rows-run.sh hello-help hello "+RTS --help" 30
                  Ijiraq 0.21.0~7351f8b
usage: /mnt/MediaVolume/Media/src/github.com/spaceghost/writ-lanes/writ-unikernel/images/hello-qemu [+RTS options -RTS] [arguments]
  --threads N       worker threads, 1 to 128 (default: the CPU count)
  [four further usage lines]
0
```

The `--bogus` path is `fprintf` then `return 1` from `main`; QEMU still exits 0.

**E4 Faults, Overflow.** (QEMU 0 under `-no-reboot`: power-off vs reset not distinguished, inferred.)

```
$ rows-run.sh overflow-m4096 overflow "+RTS --threads 1 --gpu off" 300 4096
                  Ijiraq 0.21.0~7351f8b
overflow probe start
[   24.999065] CRIT: Unikraft Crash - Ijiraq (0.21.0~7351f8b)
[   25.000094] CRIT:     _
[   25.000224] CRIT:   cx xo
[   25.000372] CRIT:   (|O|)/V
[   25.000482] CRIT:
[   25.000602] CRIT: Registers:
[   25.000752] CRIT:  rip: 0008:0000000000111da4
[   25.000925] CRIT:  rsp: 0010:0000000000010590 eflags: 00010206 orig_rax: 0000000000000002
[   25.001232] CRIT:  rax: 0000000000112930 rbx: 0000200000000000 rcx:0000000000000003
[   25.001540] CRIT:  rdx: 000000100003f030 rsi: 000000000021d280 rdi:0000200000000000
[   25.001813] CRIT:  rbp: 00000000000105d0 r08: 000000108003f000 r09:000000002b9aca05
[   25.002081] CRIT:  r10: 000000100003f028 r11: 0000000000000003 r12:0000200000000000
[   25.003062] CRIT:  r13: 0000000400053020 r14: 05000d0003109200 r15:000000ffffffffff
0
```

Wall time 26 s. `addr2line -f -e $W/images/overflow-qemu.dbg 0x111da4` gives
`WL_FID_depth` (the recursion's frame push). `r08` is exactly the guard page; the stack
base `0x100003f000` is the `stk=` gdb reports for the main loop in E6. The dump ends after
`r15`; no trap name or vector is printed (`orig_rax` 2 reads as a page-fault error code
for a write to a non-present page; that reading is not confirmed by a printed vector).

```
$ rows-run.sh overflow-m1024 overflow "+RTS --threads 1 --gpu off" 300 1024
                  Ijiraq 0.21.0~7351f8b
overflow probe start
[   13.140562] CRIT: Unikraft Crash - Ijiraq (0.21.0~7351f8b)
...
[   13.143939] CRIT:  rbp: 00000000000105d0 r08: 000000103fb88000 r09:0000000033a43805
...
0
```

Same `rip` and the same dump, at 1019 MiB into the 2 GiB stack (`r08` − base), short of
the guard: 1 GiB of guest RAM ran out first. This is guest RAM exhausted by stack growth,
not arena exhaustion; arena exhaustion was not induced. QEMU 0 here is under `-no-reboot`
(power-off vs reset not distinguished, inferred).

**E5 Threads, Hello and Lanes.**

```
$ rows-run.sh hello-t2 hello "+RTS --threads 2 --gpu off" 30
hi
0
$ rows-run.sh lanes-t1 lanes "+RTS --threads 1 --gpu off" 120
lanes 1
pow2 4194304
0
$ rows-run.sh lanes-t2 lanes "+RTS --threads 2 --gpu off" 120
lanes 2
pow2 4194304
0
$ rows-run.sh lanes-t4 lanes "+RTS --threads 4 --gpu off" 120
lanes 4
pow2 4194304
0
$ rows-run.sh lanes-default lanes "" 60
lanes 1
pow2 4194304
0
```

**E6 Does the second lane start (gdb, Lanes `--threads 2`).** Hardware breakpoints on
`pool_open`, then `pthread_create` (with `finish`), then `pool_work` and `pool_rows`
(`$W/logs/task2/gdb-lanes-t2.log`). Command file `$W/gdb-lanes.cmd`:

```
set pagination off
set confirm off
target remote :1234
hbreak pool_open
continue
hbreak pthread_create
continue
bt 2
finish
hbreak pool_work
hbreak pool_rows
continue
bt 3
continue
bt 3
continue
bt 3
```

Output:

```
Breakpoint 1, pool_open () at $W/rows-unikraft/../gen/app.c:2212
Breakpoint 2, __pthread_create (res=res@entry=0x105e8, attrp=attrp@entry=0x0, entry=entry@entry=0x1138d0 <pool_work>, arg=arg@entry=0x1) at .../musl-1.2.3//src/thread/pthread_create.c:257
Value returned is $1 = 0
Breakpoint 4, pool_rows (e=..., stk=0x100003f000) at $W/rows-unikraft/../gen/app.c:2171
Breakpoint 4, pool_rows (e=..., stk=0x100003f000) at $W/rows-unikraft/../gen/app.c:2171
[Inferior 1 (process 1) exited normally]
```

Breakpoint 3 (`pool_work`, the worker's entry) does not fire before shutdown; both `pool_rows` calls come
from `pool_turn` on the main loop's stack, then the guest powers off. (The `app.c` line
numbers gdb prints do not match the source lines; the function names are what matter.)

**E7 Clock.**

```
$ rows-run.sh clock clock "+RTS --threads 1 --gpu off" 30
before 108
after 211
advanced
0
```

**E8 `BENDRTS`, hello-env image.**

```
$ rows-run.sh hello-env hello-env "+RTS --threads 1 --gpu off" 30
                  Ijiraq 0.21.0~7351f8b
bend: unknown runtime option --bogus
0
```

The `hello` image, whose environment holds only `PATH=/bin`, prints `hi` with the same
arguments (E1), so `getenv("BENDRTS")` found nothing there.

**E9 `exit` and `_exit`.**

```
$ rows-run.sh exit exit "+RTS --threads 1 --gpu off" 30
exiting with 3
qemu-system-x86_64: terminating on signal 15 from pid 3649964 (timeout)
124
$ rows-run.sh exit0 exit0 "+RTS --threads 1 --gpu off" 30
exiting with 0
qemu-system-x86_64: terminating on signal 15 from pid 3862898 (timeout)
124
$ rows-run.sh hello-badthreads hello "+RTS --threads 0" 30
bend: expected a thread count of 1 or more after --threads
qemu-system-x86_64: terminating on signal 15 from pid 3640784 (timeout)
124
```

That `+RTS --threads 0` reaches `_exit(1)` is from source reading of the emitted C
(`err_fail("expected a thread count of 1 or more after --threads")` at `hello.c:3043`, and
`err_fail` prints then calls `_exit(1)`); no breakpoint on `_exit` was set.

Attaching gdb 8 s after boot of `exit-qemu` (`$W/logs/task2/gdb-exit-hang.log`; qemu
started with `-s`, then `$W/gdb-exit2.cmd`: `set pagination off`, `set confirm off`,
`target remote :1234`, `bt 12`, `kill`; `$W/gdb-exit.cmd` is the same without the last
two lines and was used only to let the guest run under a debugger):

```
#0  0x00000000001c1152 in plat_native_lcpu_halt_irq () at $W/src/unikraft/plat/native/arch/x86_64/lcpu_pm.c:235
#1  0x000000000015829d in idle_thread_fn (argp=0x43fbcb020) at $W/src/unikraft/lib/ukschedcoop/schedcoop.c:225
```

The exiting thread is gone and only the scheduler's idle thread is left; nothing shuts
the platform down.

**E10 linuxu 0.16.3 (process execution).** cwd `$W/hello-unikraft-0.16.3`, each under a
pty with `timeout 20 script -q -e -c "<cmd>" <log> </dev/null >/dev/null; echo $?`
(output after the banner):

```
.unikraft/build/hello-bend_linuxu-x86_64 +RTS --help
  usage: .unikraft/build/hello-bend_linuxu-x86_64 [+RTS options -RTS] [arguments]  (and the rest of the usage text)
  0
.unikraft/build/hello-bend_linuxu-x86_64 +RTS --bogus -RTS
  bend: unknown runtime option --bogus
  0
.unikraft/build/hello-bend_linuxu-x86_64 +RTS --threads 1 --gpu off
  bend: reservation failed
  124
.unikraft/build/hello-bend_linuxu-x86_64 +RTS --threads 1 --gpu 64MB
  bend: reservation failed
  124
BENDRTS=--bogus, .unikraft/build/hello-bend_linuxu-x86_64
  bend: reservation failed
  124
```

For `--bogus`, `script`'s own log records `COMMAND_EXIT_CODE="0"`, so the 0 is the
child's status, not the wrapper's. The same `script` wrapper confirms the variable reaches the child (`env | grep BENDRTS`
prints `BENDRTS=--bogus`). Faults, threads, clock and the event loop are `not reached` on
linuxu: every run stops at the reservation, and no option shrinks it.

## Limits of the Task 2 record

- One CPU (`UKPLAT_CPU_MAXCOUNT=1`) and the cooperative scheduler: parallel lanes were
  not available, and atomics were not exercised across CPUs. SMP was not tried.
- The clock row is one sample; backward motion was not hunted for.
- The event loop's helper-thread wake path (a helper `write` to the self-pipe) was not
  exercised.
- linuxu evidence is from 0.16.3 (process execution), not the 0.21.0 pin.
- No run is a device run: every run is CPU execution.

# Task 1: build matrix

## Summary

| Target | Unikraft | Build adjustments | Link | Run outcome |
| --- | --- | --- | --- | --- |
| `linuxu/x86_64` | 0.21.0 (primary pin) | none | not reached | configure succeeds, make stops: `Select exactly one target platform in the configuration!` (linuxu no longer exists in core) |
| `linuxu/x86_64` | 0.16.3 (last release with linuxu) | none | failed to compile | first error `hello.c:31:10: fatal error: stdatomic.h: No such file or directory` |
| `linuxu/x86_64` | 0.16.3 | A1 + A2 | **linked** | needs a TTY on stdin; under a pty prints banner then `bend: reservation failed`, then does not exit (killed at 60 s) |
| `qemu/x86_64` | 0.21.0 | none | failed to compile | first error `hello.c:31:10: fatal error: stdatomic.h: No such file or directory` |
| `qemu/x86_64` | 0.21.0 | A1 | failed to compile (core) | `lib/ukboot/boot.c:489:18: error: too many arguments to function '*ctorfn'; expected 0, have 2` (GCC 16 C23 default) |
| `qemu/x86_64` | 0.21.0 | A1 + A2 (plan's four libraries) | **linked** | boots; prints `bend: the event loop failed to open`; image does not halt (killed at 60 s) |
| `qemu/x86_64` | 0.21.0 | A1 + A2 + A3 | **linked** | boots; prints `hi`; QEMU exits 0 |

Build adjustments (none touches Bend output or the Bend runtime; all are application
build descriptors under `../writ-unikernel/`):

- **A1** Unikraft compiles with `-nostdinc`, and musl ships no `<stdatomic.h>` (it is a
  compiler header). Added an include directory containing only a symlink to GCC's own
  `stdatomic.h`, created in the application directory with:

  ```sh
  mkdir -p compiler-include
  ln -sf "$(gcc -print-file-name=include/stdatomic.h)" compiler-include/stdatomic.h
  # gcc -print-file-name=include/stdatomic.h prints
  # /usr/lib/gcc/x86_64-pc-linux-gnu/16/include/stdatomic.h on this host
  ```
- **A2** GCC 16 defaults to C23, where `void (*f)()` takes no arguments; Unikraft core
  0.21.0 calls constructors as `(*ctorfn)(argc, argv)`. Built with `UK_CFLAGS=-std=gnu11`
  in the environment (applies to all Unikraft and app objects). The 0.16.3 build needs
  A2 as well; it does not inherit a C dialect. With A1 only (Task 2, cwd
  `$W/hello-unikraft-0.16.3-a1`, `env -u UK_CFLAGS $KRAFT build --no-update --target
  linuxu/x86_64 -j 16 .`) the first error is
  `src-0.16.3/unikraft/lib/ukboot/boot.c:499:18: error: too many arguments to function '*ctorfn'; expected 0, have 2`.
  Re-run in Task 3 to capture the status (after `rm -rf .unikraft`; log
  `$W/logs/task3/build-linuxu-0.16.3-a1only.log`):

  ```
  $ env -u UK_CFLAGS $KRAFT build --no-update --target linuxu/x86_64 -j 16 . > $W/logs/task3/build-linuxu-0.16.3-a1only.log 2>&1; echo $?
  1
  ```

  The log's first `error:` line is the same `boot.c:499:18` error, followed by
  `could not complete build: build failed: exit status 2` (kraft's own status is 1).
- **A3** Added `CONFIG_LIBPOSIX_PIPE` and `CONFIG_LIBPOSIX_POLL` to the plan's four
  libraries so the runtime's self-pipe (`pipe`, `select`) exists. Supplementary to Task 1;
  the plan's library set is the A1 + A2 row.

The CUDA and Metal includes in the emitted C are under `#ifdef __OBJC__` / `#elif
BEND_CUDA` / `#ifdef __METAL_VERSION__` and were not pulled in by the Unikraft build; the
only header the build lacked was `stdatomic.h`. GCC warns `ignoring '#pragma clang fp'`
and several `-Wmisleading-indentation` in `hello.c`; neither is an error.

## Application directory

`$W/hello-unikraft/` (0.21.0) and `$W/hello-unikraft-0.16.3/` (0.16.3, linuxu). Both use
the same `Makefile.uk` and an empty `Config.uk`. Each directory was created by hand
(not by `kraft init`):

```sh
mkdir -p $W/hello-unikraft && cd $W/hello-unikraft
: > Config.uk                 # empty: the application adds no Kconfig options
# write Makefile.uk and Kraftfile with the contents below, then apply A1 above
```

`Makefile.uk`:

```make
$(eval $(call addlib,apphellobend))

# The only application source: Bend 2.0.39 output for scripts/unikernel/Hello.bend.
APPHELLOBEND_SRCS-y += $(APPHELLOBEND_BASE)/../hello/hello.c

# Adjustment 1: Unikraft builds with -nostdinc and musl ships no <stdatomic.h>;
# expose only the compiler's own stdatomic.h (a freestanding compiler header).
APPHELLOBEND_CINCLUDES-y += -I$(APPHELLOBEND_BASE)/compiler-include
```

`compiler-include/stdatomic.h` is a symlink to
`/usr/lib/gcc/x86_64-pc-linux-gnu/16/include/stdatomic.h`. The unadjusted runs used the
first four lines only.

`Kraftfile` (0.21.0, plan library set; A3 adds the two commented lines):

```yaml
spec: v0.6

name: hello-bend

unikraft:
  source: ../src/unikraft
  kconfig:
    CONFIG_LIBUKVMEM: 'y'
    CONFIG_LIBPOSIX_MMAP: 'y'
    CONFIG_LIBPOSIX_PROCESS: 'y'
    CONFIG_LIBPOSIX_FDTAB: 'y'
    CONFIG_LIBPOSIX_SYSINFO: 'y'
    # A3: CONFIG_LIBPOSIX_PIPE: 'y'
    # A3: CONFIG_LIBPOSIX_POLL: 'y'

libraries:
  musl:
    source: ../src/libs/musl

targets:
  - linuxu/x86_64
  - qemu/x86_64
```

`Kraftfile` (0.16.3): same, with `source: ../src-0.16.3/unikraft`,
`source: ../src-0.16.3/libs/musl`, no `CONFIG_LIBUKVMEM` line, and only the
`linuxu/x86_64` target.

Resolved configuration, as written by kraft to `.config.hello-bend_<target>`:

- 0.21.0 qemu: `LIBPOSIX_MMAP=y`, `LIBUKVMEM=y`, `LIBPOSIX_PROCESS=y`,
  `LIBPOSIX_PROCESS_MULTITHREADING=y`, `LIBPOSIX_FDTAB=y`, `LIBPOSIX_SYSINFO=y`,
  `LIBPOSIX_TIME=y`, `LIBUKSCHEDCOOP=y`, `UKPLAT_CPU_MAXCOUNT=1`; `LIBPOSIX_PROCESS_SIGNAL`,
  `LIBUKLIBPARAM` not set. lib-musl itself selects `LIBPOSIX_VFS` and `LIBUKFS` (a VFS
  core, no filesystem driver); no networking library is selected.
- 0.16.3 linuxu: **`LIBUKVMEM` is not set, so `posix-mmap` was dropped** (it depends on
  `LIBUKVMEM`, unavailable on linuxu). `LIBPOSIX_PIPE` and `LIBPOSIX_POLL` came in by
  dependency. lib-musl 0.16.3 selects `LIBVFSCORE`. No networking library.

Common kraft prefix used below (`$W` absolute, as above):

```sh
KRAFT="$W/tools/kraftkit-0.12.16/kraft --config-dir $W/kraft-home/config \
  --manifests-dir $W/kraft-home/manifests --sources-dir $W/kraft-home/sources \
  --runtime-dir $W/kraft-home/runtime --no-check-updates --no-prompt --no-emojis \
  --no-color --log-type basic"
```

## Target `linuxu/x86_64`

### Unikraft 0.21.0, no adjustments

Build (cwd `$W/hello-unikraft`):

```sh
$KRAFT build --no-update --target linuxu/x86_64 .
```

Link: not reached. Configure ran (with a Kconfig warning that `LIBUKPAGING` is selected
by `LIBUKVMEM` while `HAVE_PAGING` is n), then the build stopped:

```
.unikraft/build/Makefile:764: *** Select exactly one target platform in the configuration!.  Stop.
make: *** [Makefile:1175: sub-make] Error 2
could not complete build: build failed: exit status 2
```

Cause: `plat/linuxu` is absent from the 0.21.0 tree (`plat/` holds `common kvm native
xen`). The GitHub contents listing shows linuxu in 0.14.0 to 0.16.0 and absent from
0.17.0 onward. The pinned core therefore offers no `linuxu` target.

### Unikraft 0.16.3, no adjustments

Build (cwd `$W/hello-unikraft-0.16.3-noadj`):

```sh
$KRAFT build --no-update --target linuxu/x86_64 -j 16 .
```

Link: failed before link. First error:

```
hello-unikraft-0.16.3-noadj/../hello/hello.c:31:10: fatal error: stdatomic.h: No such file or directory
```

### Unikraft 0.16.3, A1 + A2

Build (cwd `$W/hello-unikraft-0.16.3`):

```sh
UK_CFLAGS=-std=gnu11 $KRAFT build --no-update --target linuxu/x86_64 -j 16 .
```

Link: **succeeded**. `build completed successfully kernel=".unikraft/build/hello-bend_linuxu-x86_64"`;
ELF 64-bit x86-64, statically linked, sha256 `375240271ff9245024ea016a873f380e62cb85827aa04e53c9fa3eb9e3b17d49`.

Run 1, stdin not a terminal (process execution):

```sh
timeout 60 .unikraft/build/hello-bend_linuxu-x86_64 +RTS --threads 1 --gpu off </dev/null; echo $?
```

Full output (re-run in Task 2 to capture the status line):

```
[174310.653739] CRIT: [liblinuxuplat] <console.c @   92> Failed to initialize terminal console
1
```

(linuxu's console calls `tcgetattr(STDIN)` and crashes when stdin is not a TTY.)

Run 2, under a pseudo-terminal (process execution):

```sh
timeout 60 script -q -e -c ".unikraft/build/hello-bend_linuxu-x86_64 +RTS --threads 1 --gpu off" /dev/null </dev/null; echo $?
```

Full output (escape sequences and CRs removed); the final line is `echo $?`:

```
Powered by
o.   .o       _ _               __ _
Oo   Oo  ___ (_) | __ __  __ _ ' _) :_
oO   oO ' _ `| | |/ /  _)' _` | |_|  _)
oOo oOO| | | | |   (| | | (_) |  _) :_
 OoOoO ._, ._:_:_,\_._,  .__,_:_, \___)
                 Telesto 0.16.3~e453b74
bend: reservation failed

Session terminated, killing shell... ...killed.
124
```

The runtime's startup reservation (`mmap` with `MAP_NORESERVE`) failed with posix-mmap
absent, and the process did not exit after the message; it was killed at 60 s.

## Target `qemu/x86_64`

### Unikraft 0.21.0, no adjustments

Build (cwd `$W/hello-unikraft`):

```sh
$KRAFT build --no-update --target qemu/x86_64 -j 16 .
```

Link: failed before link. First error:

```
hello-unikraft/../hello/hello.c:31:10: fatal error: stdatomic.h: No such file or directory
   31 | #include <stdatomic.h>
```

### Unikraft 0.21.0, A1

Same command. `hello.o` now compiles (258 KB object). Link: not reached; first error is
in Unikraft core under GCC 16:

```
src/unikraft/lib/ukboot/boot.c:489:18: error: too many arguments to function '*ctorfn'; expected 0, have 2
  489 |                 (*ctorfn)(argc, argv);
```

### Unikraft 0.21.0, A1 + A2 (plan's four libraries)

```sh
UK_CFLAGS=-std=gnu11 $KRAFT build --no-update --target qemu/x86_64 -j 16 .
```

Link: **succeeded** (`build completed successfully kernel=".unikraft/build/hello-bend_qemu-x86_64"`;
the image is a 32-bit multiboot ELF of 1,143,128 bytes).

Run (emulated boot):

```sh
timeout 60 qemu-system-x86_64 -accel tcg -nographic -m 1024 -cpu max \
  -kernel .unikraft/build/hello-bend_qemu-x86_64 \
  -append "+RTS --threads 1 --gpu off" -no-reboot; echo $?
```

Full serial output (escape sequences and CRs removed); the final line is `echo $?`:

```
SeaBIOS (version Arch Linux 1.17.0-2-2)


iPXE (http://ipxe.org) 00:03.0 C900 PCI2.10 PnP PMM+3EFD3EE0+3EF33EE0 C900
Press Ctrl-B to configure iPXE (PCI 00:03.0)...


Booting from ROM..Powered by
o.   .o       _ _               __ _
Oo   Oo  ___ (_) | __ __  __ _ ' _) :_
oO   oO ' _ `| | |/ /  _)' _` | |_|  _)
oOo oOO| | | | |   (| | | (_) |  _) :_
 OoOoO ._, ._:_:_,\_._,  .__,_:_, \___)
                  Ijiraq 0.21.0~7351f8b
bend: the event loop failed to open
qemu-system-x86_64: terminating on signal 15 from pid 3309451 (timeout)
124
```

The reservation passed (no `reservation failed`); the self-pipe could not be created
without `posix-pipe`, the runtime printed its failure, and the image did not halt.

### Unikraft 0.21.0, A1 + A2 + A3 (supplementary)

Same build and run commands after adding `CONFIG_LIBPOSIX_PIPE` and `CONFIG_LIBPOSIX_POLL`.
Link: **succeeded**; image sha256 `90740194620c27f04749217d179a125073480114328bbe03677e81770c3dce91`.

Full serial output; the final line is `echo $?` (the guest shut down after `main` returned):

```
SeaBIOS (version Arch Linux 1.17.0-2-2)


iPXE (http://ipxe.org) 00:03.0 C900 PCI2.10 PnP PMM+3EFD3EE0+3EF33EE0 C900
Press Ctrl-B to configure iPXE (PCI 00:03.0)...


Booting from ROM..Powered by
o.   .o       _ _               __ _
Oo   Oo  ___ (_) | __ __  __ _ ' _) :_
oO   oO ' _ `| | |/ /  _)' _` | |_|  _)
oOo oOO| | | | |   (| | | (_) |  _) :_
 OoOoO ._, ._:_:_,\_._,  .__,_:_, \___)
                  Ijiraq 0.21.0~7351f8b
hi
0
```

## Limits of the Task 1 record

- Task 2 settled `-append` delivery: the string reaches `main` as `argv` (see the
  Process row).
- Task 2 settled exit status on QEMU: never visible; see the Process row.
- Thread creation, faults, and clocks are Task 2 rows.
- The linuxu evidence is from Unikraft 0.16.3, not the primary 0.21.0 pin, and its
  posix-mmap was unavailable. These are process executions, not boots.
- Full build and run logs are in `$W/logs/` (Task 1) and `$W/logs/task2/` (Task 2),
  outside the tree.
