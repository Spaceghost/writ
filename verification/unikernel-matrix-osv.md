# OSv runtime matrix for the Bend native runtime (compat observation)

Recorded 2026-11-03. Task 3 of the library-unikernel runtime lane. Versions, downloads,
and hashes are in `verification/unikernel-pins.txt`. Everything downloaded or built lives
under the workspace `$W`, set from the repository root with `W=$(realpath ../writ-unikernel)`
(on this machine `/mnt/MediaVolume/Media/src/github.com/spaceghost/writ-lanes/writ-unikernel`);
nothing generated is in the tree. Every run below is an **emulated boot** under QEMU 11.1.2
with TCG. No run used an accelerator device; every run is CPU execution.

## Mode: compat, not a native link

**OSv on this program is compat-mode.** The executable is Bend's generated C compiled by
the host toolchain into a dynamically linked Linux PIE (against glibc 2.44 headers) and
loaded at boot by OSv's in-kernel ELF dynamic linker, which binds its libc and pthread
imports to the kernel's own exported functions. The kernel image is the unmodified
release `osv-loader` of OSv 0.57.0; the program is a file on a ROFS disk.

Why no native-link attempt was made: OSv has no build mode that links application C into
the kernel image. Its application modules (`apps/` in the OSv tree, `capstan package`)
are built as `.so` or PIE objects and are always loaded by the same ELF linker the
compat path uses. This is from OSv's documentation and build layout, **not executed**: OSv
was not built from source in this task. UL-001 forbids running through the kernel's
Linux-ELF loader, so no OSv configuration seen here can satisfy UL-001, and every cell
below is a compat observation. The distinction from Nanos-style binary compatibility:
the libc calls here are function calls into OSv, not trapped syscalls; the loader is
still a Linux-ELF loader.

Time-box: OSv work began 20:58 and the last run finished about 21:30 the same evening,
inside the two-hour box. No stall.

Value key as in `verification/unikernel-matrix-unikraft.md`: `supplied`, `substituted`
(the difference is stated), `missing`, `not reached`.

## Matrix

| Row | OSv 0.57.0, compat PIE, qemu/x86_64 (emulated boot) | Evidence |
| --- | --- | --- |
| Memory | **supplied**, lazily backed | Hello boots and prints `hi` with `-m 1024`, `-m 256`, `-m 64` and `-m 32` (O-E1). Under gdb the heap hints `1<<45` and `1<<44` come back at other addresses (`0x200000400000`, `0x100000200000`), so the runtime unmaps them and the third hint `0x80000000000` (`1<<43`, 8 GiB) is honored; the 2 GiB + guard stack is `mmap(0, 0x8000c000)` at `0x200000400000`; flags `0x4022` = `MAP_PRIVATE\|MAP_ANONYMOUS\|MAP_NORESERVE` (O-E2). No `reservation failed`. Exhausting guest RAM is an OSv kernel abort, not the runtime's message (O-E4). |
| Faults | **supplied** for the stack guard; exit code **missing** | Overflow.bend: the runtime's own `bend: memory fault (machine stack overflow?)` appears, so its `SIGSEGV` handler ran (that it ran on the `sigaltstack` stack is inferred from the overflowed stack, not traced); its re-raise with `SIG_DFL` ends in OSv's `Uncaught signal 11 ("Segmentation fault"). Powering off.` (with `--verbose`); QEMU exits **0** (O-E4). Halts, does not resume. Out of RAM (`-m 1024`) is different: `page fault outside application` in the kernel's page pool, `Aborted`, and the guest halts without powering off (killed, 124) (O-E4). |
| Threads | **supplied** (preemptive; second lane runs, on one or two vCPUs); shutdown with an open pool **missing** | Lanes.bend gives `lanes N` and the correct `pow2 4194304` for `--threads 1/2/4` on `-smp 1` and `--threads 2/4` on `-smp 2` (O-E5). gdb: `pool_work` is entered, and `pool_rows` runs on two stacks (`rsp` `0x2000001fe228` main, `0x200000300f68` worker) on `-smp 1` and `-smp 2` (O-E6). But with a second lane the image never shuts down: `main` returns 0 into `osv::application::run_main`, `exit` is never called, `program exited with status` is never printed, and both vCPUs sit in `sched::cpu::do_idle` (killed, 124) (O-E6). Cause inferred, not traced: the runtime leaves its workers parked in `pthread_cond_wait` and relies on Linux's process exit to end them; OSv waits for them. `--threads 1` shuts down normally. |
| Clock | **supplied** | Clock.bend prints `before 208`, `after 311`, `advanced`; QEMU 0 (O-E7). One sample: 103 ms across a 100 ms sleep. |
| Event loop | **supplied** | Startup reaches the first print in every probe (`pipe`, `fcntl`, `select` resolved by OSv's linker and working), and `IO.sleep` returns (O-E7). The helper-thread wake path was not exercised. |
| Process | **substituted**: argv supplied; `BENDRTS` supplied via `--env=`; exit status on the console only | argv: the kernel command line after the OSv options becomes `argv` (`+RTS --bogus -RTS` gives `bend: unknown runtime option --bogus`, `+RTS --help` prints the usage with `argv[0]` = `/hello`) (O-E3). `BENDRTS`: `--env=BENDRTS=--bogus /hello` gives `bend: unknown runtime option --bogus` (O-E8). Exit: `exit(3)`, `exit(0)`, return from `main` and `_exit(1)` all power the guest off with QEMU status **0** (O-E9); with `--verbose` OSv prints `program exited with status 3` on the console. CPU count: default `--threads` is 1 on `-smp 1` and 2 on `-smp 2` (O-E5). Return-with-open-pool hangs (Threads row). |
| Atomics | **supplied** by the compiler, exercised across two vCPUs | clang 23.1.1's `stdatomic.h` (the host headers; no adjustment needed). The pool counters ran with two lanes on one vCPU and on two vCPUs with correct results (O-E5, O-E6), and the `err_claim` compare-and-swap ran on the fault and `_exit` paths (O-E4, O-E9). The two-vCPU runs are TCG (multi-threaded TCG on an x86 host), not hardware. |
| Device dispatch (`!` calls) | **missing** (CPU only), by construction | No accelerator code is compiled (the CUDA/Metal branches are under `BEND_CUDA`/`__OBJC__`, unset), and no `!` program was run. `+RTS --gpu 64MB` gives the same reservations as `--gpu off` (O-E2). |

### Against the runtime profile's fault rule

RH-006 accepts the runtime's stack error with a nonzero exit, or a halting trap with a
recorded code, and forbids resumption. OSv gives the runtime's own message and a halt
(power-off), with no resumption. The code is not visible to the harness: QEMU exits 0, as
for success. The `Uncaught signal 11` line appears only with OSv's `--verbose`. Arena or
RAM exhaustion is a kernel abort that halts without power-off, not the runtime's message.

## Build adjustments (application build only; nothing in Bend output or the runtime changes)

- **O1** GNU ld 2.47 (the host default) emits a `PT_GNU_SFRAME` program header, which
  OSv 0.57.0's ELF loader rejects (O-E0). Linked with `clang -fuse-ld=lld` (LLD 23.1.1),
  which emits none.
- **O2** glibc 2.44 headers redirect `strtol` and `fscanf` to the C23 entry points
  `__isoc23_strtol` / `__isoc23_fscanf` whenever `_GNU_SOURCE` is set, and the emitted C
  sets it. OSv 0.57.0 predates them (O-E0). The object's references are renamed back with
  `objcopy --redefine-sym __isoc23_<f>=<f>` before linking. The runtime calls
  `strtol(v, NULL, 10)` and `fscanf(f, "%ld %ld", ...)`, where the C17 and C23 behavior
  is the same (C23 differs only on `0b` prefixes with base 0 or 2).

## Build and run harness (outside the tree)

`$W/osv/osv-build-all.sh` (the build part; `C=$W/tools/capstan-1.0.0/capstan`,
`CAPSTAN_ROOT=$W/capstan-home`):

```sh
for p in hello clock overflow lanes exit exit0; do
  clang -std=gnu11 -O2 -fPIE -pthread -c $W/gen/$p.c -o $W/osv/build/$p.o
  objcopy $(for s in strtol fscanf sscanf strtoul strtoll strtoull scanf; do
    printf -- '--redefine-sym __isoc23_%s=%s ' $s $s; done) $W/osv/build/$p.o     # O2
  clang -fuse-ld=lld -pie -pthread $W/osv/build/$p.o -o $W/osv/build/$p.pie -lm  # O1
  cp $W/osv/build/$p.pie $W/osv/pkg-probes/$p
done
# $W/osv/pkg-probes/meta/package.yaml: name writ.probes, version 0.0.1
cd $W/osv/pkg-probes && $C package compose --fs rofs --size 64M --run "/hello" probes
```

`$W/gen/<p>.c` are Task 2's emitted probes (hashes in the pins file). Capstan builds the
ROFS image on the host from the release `osv-loader` base and the release
`osv.bootstrap` package, both placed in `$CAPSTAN_ROOT` by hand (no capstan pull). The
image `$W/capstan-home/repository/probes/probes.qemu` was rebuilt and gave the same sha256
both times.

`$W/osv/osv-run.sh <label> "<cmdline>" [T=60] [M=1024] [S=1]` boots the release kernel ELF
by PVH with the command line on `-append` (so `argv` varies per run, as on Unikraft) and
the composed disk as the root:

```sh
timeout $T qemu-system-x86_64 -accel tcg -nographic -m $M -cpu max -smp $S \
  -kernel $W/osv/loader/osv-loader.elf -append "<cmdline>" \
  -drive file=$W/capstan-home/repository/probes/probes.qemu,if=none,id=hd0,format=qcow2,snapshot=on \
  -device virtio-blk-pci,drive=hd0 -no-reboot </dev/null; echo $?
```

The output is kept from the `OSv v0.57.0` line on, escapes and CRs removed, in
`$W/logs/task3/run-<label>.log`; the last line of each block below is `echo $?`. The
capstan disk also boots by itself with its baked command line (O-E1). gdb attaches with
`-gdb tcp::<port>` (`-S` where the run must stop at reset) and `gdb -nx -iex "set
auto-load off" -batch -x <cmds> $W/osv/loader/osv-loader.elf`. The kernel ELF is stripped
but keeps its dynamic symbols, which give the breakpoint addresses: `mmap` `0x403d0080`,
`pthread_create` `0x403ca570`, `exit` = `_exit` `0x40239600`. The probe PIE loads at
`0x100000005000` (found from `pthread_create`'s `entry` minus `pool_work`'s offset `0x6250`).

## Evidence

**O-E0 First errors before the adjustments.** Host `gcc -std=gnu11 -O2 -fPIE -pie -pthread
hello.c -lm` (GNU ld), composed and booted from the capstan disk:

```
OSv v0.57.0
Booted up in 0.00 ms
Cmdline: /hello +RTS --threads 1 --gpu off
Unknown p_type in executable �: 1685382484
[backtrace]
0x00000000402bbfce <elf::object::process_headers()+510>
...
qemu-system-x86_64: terminating on signal 15 from pid 186848 (timeout)
```

(1685382484 = `0x6474e554` = `PT_GNU_SFRAME`; `readelf -lW` shows `GNU_SFRAME` from the
`.sframe` section. The image then halts without power-off: killed, 124.) With O1 only:

```
Cmdline: /hello +RTS --threads 1 --gpu off
/hello: failed looking up symbol __isoc23_strtol
[backtrace]
0x00000000402c3239 <elf::object::symbol(unsigned int, bool)+1513>
...
qemu-system-x86_64: terminating on signal 15 from pid 284298 (timeout)
124
```

**O-E1 Startup and memory, Hello.** Capstan disk boot with the baked command line
(`$W/capstan-home/repository/hello/hello.qemu`, `osv-build.sh hello hello "/hello +RTS --threads 1 --gpu off"`):

```
$ timeout 60 qemu-system-x86_64 -accel tcg -nographic -m 1024 -cpu max -smp 1 \
    -drive file=$W/capstan-home/repository/hello/hello.qemu,if=none,id=hd0,format=qcow2,snapshot=on \
    -device virtio-blk-pci,drive=hd0 -no-reboot </dev/null; echo $?
Booting from Hard Disk...
OSv v0.57.0
Booted up in 0.00 ms
Cmdline: /hello +RTS --threads 1 --gpu off
hi
0
```

PVH boot: `osv-run.sh hello-t1 "/hello +RTS --threads 1 --gpu off"` prints `hi`, 0; the
same with `-m 256`, `-m 64`, `-m 32` (`run-hello-m*.log`) and with `"/hello"` (no options).

**O-E2 Reservations (gdb).** `$W/osv/gdb/mmap-ret.cmd`:

```
set pagination off
set confirm off
target remote :1234
hbreak *0x403d0080
continue
printf "mmap addr=%#lx len=%#lx\n", $rdi, $rsi
finish
printf "  returned %#lx\n", $rax
(the continue / printf / finish / printf group four times in all)
kill
```

Output for `/hello +RTS --threads 1 --gpu off` (`gdb-mmap-ret.log`):

```
mmap addr=0x200000000000 len=0x200000000
  returned 0x200000400000
mmap addr=0x100000000000 len=0x200000000
  returned 0x100000200000
mmap addr=0x80000000000 len=0x200000000
  returned 0x80000000000
mmap addr=0 len=0x8000c000
  returned 0x200000400000
```

`corpus_map` tries `1<<45` and halves; a mapping that comes back elsewhere is unmapped
(`corpus_at`). A second command file, `$W/osv/gdb/mmap.cmd` (the same breakpoint with
`commands; silent; printf "mmap addr=%#lx len=%#lx prot=%#lx flags=%#lx\n", $rdi, $rsi,
$rdx, $rcx; continue; end`), printed the same four calls, each `prot=0x3 flags=0x4022`, for
both `--gpu off` and `--gpu 64MB` (`gdb-mmap-off.log`, `gdb-mmap-64MB.log`).

**O-E3 argv and return from `main`, Hello.**

```
$ osv-run.sh hello-bogus "/hello +RTS --bogus -RTS" 40
Cmdline: /hello +RTS --bogus -RTS
bend: unknown runtime option --bogus
0
$ osv-run.sh hello-help "/hello +RTS --help" 40
Cmdline: /hello +RTS --help
usage: /hello [+RTS options -RTS] [arguments]
  --threads N       worker threads, 1 to 128 (default: the CPU count)
  [four further usage lines]
0
```

The `--bogus` path returns 1 from `main`; QEMU exits 0.

**O-E4 Faults, Overflow.**

```
$ osv-run.sh overflow-m4096 "/overflow +RTS --threads 1 --gpu off" 300 4096
Cmdline: /overflow +RTS --threads 1 --gpu off
overflow probe start
bend: memory fault (machine stack overflow?)
0
$ osv-run.sh overflow-verbose "--verbose /overflow +RTS --threads 1 --gpu off" 300 4096
Cmdline: /overflow +RTS --threads 1 --gpu off
overflow probe start
random: device unblocked.
bend: memory fault (machine stack overflow?)
Uncaught signal 11 ("Segmentation fault"). Powering off.
0
$ osv-run.sh overflow-m1024 "/overflow +RTS --threads 1 --gpu off" 300 1024
Cmdline: /overflow +RTS --threads 1 --gpu off
overflow probe start
page fault outside application, addr: 0x0000000000000000
[registers]
RIP: 0x0000000040352425 <memory::page_pool::l2::refill()+181>
...
Aborted

[backtrace]
0x00000000402053c7 <???+1075860423>
0x00000000402faf3f <page_fault+143>
0x00000000402f9df6 <???+1076862454>
0x0000000040352bd7 <memory::page_pool::l2::fill_thread()+327>
...
qemu-system-x86_64: terminating on signal 15 from pid 537798 (timeout)
124
```

(The verbose run's VFS/ROFS unmount lines before `Powering off.` are dropped here.) The
native Linux reference for the same probe is the `SIGSEGV` exit 139 recorded in
`verification/unikernel-matrix-unikraft.md` (Probes, calibration).

**O-E5 Threads and CPU count, Lanes.**

```
$ osv-run.sh lanes-t1 "/lanes +RTS --threads 1 --gpu off" 120
lanes 1
pow2 4194304
0
$ osv-run.sh lanes-default "/lanes" 120
lanes 1
pow2 4194304
0
$ osv-run.sh lanes-t2 "/lanes +RTS --threads 2 --gpu off" 120
lanes 2
pow2 4194304
qemu-system-x86_64: terminating on signal 15 from pid 391386 (timeout)
124
$ osv-run.sh lanes-t4 "/lanes +RTS --threads 4 --gpu off" 120
lanes 4
pow2 4194304
qemu-system-x86_64: terminating on signal 15 from pid 486954 (timeout)
124
$ osv-run.sh lanes-t2-smp2 "/lanes +RTS --threads 2 --gpu off" 120 1024 2
lanes 2
pow2 4194304
qemu-system-x86_64: terminating on signal 15 from pid 531424 (timeout)
124
$ osv-run.sh lanes-t4-smp2 "/lanes +RTS --threads 4 --gpu off" 120 1024 2
lanes 4
pow2 4194304
qemu-system-x86_64: terminating on signal 15 from pid 548178 (timeout)
124
$ osv-run.sh lanes-default-smp2 "/lanes" 120 1024 2
lanes 2
pow2 4194304
qemu-system-x86_64: terminating on signal 15 from pid 581034 (timeout)
124
```

With `--verbose` and `--threads 2` the output ends at `pow2 4194304` and no
`program exited with status` line appears (`run-lanes-t2-verbose.log`, 124).

**O-E6 Does the second lane run, and where does shutdown stop (gdb).** `$W/osv/gdb/lanes.py`
(gdb Python): hardware breakpoint on `pthread_create` with condition
`($rdx & 0xfff) == 0x250` (the app's `pool_work`), derive the base, then hardware
breakpoints on `pool_work` (base+`0x6250`) and `pool_rows` (base+`0x6300`), printing
`$rsp` at each stop. `-smp 2` (`gdb-lanes-smp2.log`):

```
app pthread_create entry=0x10000000b250 arg=0x1 base=0x100000005000
hit pool_work thread=1 rdi=0x1 rsi=0x40 rsp=0x200000300fa8
hit pool_rows thread=1 rdi=0x80000000000 rsi=0x10000000fb80 rsp=0x2000001fe228
hit pool_rows thread=1 rdi=0x80000000000 rsi=0x10000000fe80 rsp=0x200000300f68
hit pool_rows thread=1 rdi=0x80000000000 rsi=0x10000000fb80 rsp=0x2000001fe228
```

`-smp 1` (`gdb-lanes-smp1.log`) gives the same lines. gdb's `thread` is a vCPU, not an OSv
thread; the two `rsp` values are the two lanes' stacks. (A first `-smp 2` attempt connected
to a still-running `-smp 1` guest on the same port and is discarded; the run above used
port 1235.)

Shutdown, `--threads 2`, `-smp 1`, `$W/osv/gdb/mainret.cmd`:

```
set pagination off
set confirm off
target remote :1238
hbreak *0x10000000935c
continue
printf "main ret reached, eax=%d\n", $eax
stepi
printf "returned into pc=%#lx\n", $pc
hbreak *0x40239600
continue
printf "exit called status=%ld\n", $rdi
kill
```

(`0x935c` is the only `ret` in `main`, from `objdump -d lanes.pie`.) Output:

```
main ret reached, eax=0
returned into pc=0x40396ccd
```

`0x40396ccd` is inside `osv::application::run_main()` (`nm -DC`: `0x40396c90`). The `exit`
breakpoint is never hit before the 140 s timeout. Attached 10 s after `pow2` with `-smp 2`
(`$W/osv/gdb/hang.cmd`: `add-symbol-file lanes.pie -o 0x100000005000`, `target remote
:1236`, `info threads`, `thread apply all bt 12`, `kill`):

```
* 1    Thread 1.1 (CPU#0 [halted ]) 0x00000000403648a1 in sched::cpu::do_idle() ()
  2    Thread 1.2 (CPU#1 [halted ]) 0x00000000403648a1 in sched::cpu::do_idle() ()
```

Both backtraces are `do_idle` / `idle` / `thread_main_c`: nothing is runnable.

**O-E7 Clock.**

```
$ osv-run.sh clock "/clock +RTS --threads 1 --gpu off" 30
before 208
after 311
advanced
0
```

**O-E8 `BENDRTS`.**

```
$ osv-run.sh hello-env "--env=BENDRTS=--bogus /hello" 30
Cmdline: /hello
bend: unknown runtime option --bogus
0
$ osv-run.sh hello-env-t1 "--env=BENDRTS=--bogus /hello +RTS --threads 1 --gpu off" 30
Cmdline: /hello +RTS --threads 1 --gpu off
bend: unknown runtime option --bogus
0
```

**O-E9 `exit` and `_exit`.**

```
$ osv-run.sh exit "/exit +RTS --threads 1 --gpu off" 30
exiting with 3
0
$ osv-run.sh exit0 "/exit0 +RTS --threads 1 --gpu off" 30
exiting with 0
0
$ osv-run.sh hello-badthreads "/hello +RTS --threads 0" 30
bend: expected a thread count of 1 or more after --threads
0
$ osv-run.sh exit-verbose "--verbose /exit +RTS --threads 1 --gpu off" 40
exiting with 3
program exited with status 3
VFS: unmounting /dev
...
Powering off.
0
```

`--threads 0` reaching `_exit(1)` is from source reading of the emitted C (`err_fail` at
`hello.c:3043`, which calls `_exit(1)`), not from a breakpoint. In OSv 0.57.0 `exit` and
`_exit` are the same function (`nm -D`: both `0x40239600`).

## Image and executable hashes

| File | sha256 |
| --- | --- |
| `osv/build/hello.pie` | `3ea3e354bd96218390f03745a4412b298f0879962c61b1ca8956f760eaa12adc` |
| `osv/build/clock.pie` | `024aea25276ed09a8f20763415ab2f6e607d0d3000e5195d5a1867976314299f` |
| `osv/build/overflow.pie` | `2ae94f405016030231a804950dbe0da3c0f112c90fb26d34f08dff9532cdabda` |
| `osv/build/lanes.pie` | `dee2a09ea942cf7ab8698067c2613836a2cc5b1e077beea7dbbf71f55eda8c1a` |
| `osv/build/exit.pie` | `8d49bb06c2fdbd81dd307d758f54383105c81b9da8bb7720c79e5c43860759f1` |
| `osv/build/exit0.pie` | `768ac86b824d7c511c920a0e422c5066f9a9250165e9c07802eb6904f1299777` |
| `capstan-home/repository/probes/probes.qemu` | `28b441c4ee9852d7ac74fc9b50894c8633a62499847b46c1f029fb271d793ad5` |
| `capstan-home/repository/hello/hello.qemu` | `699dde0cae26b3328ffb947bc38b1d5f4d200ecc5a0aa08fcebed7f279c989cf` |

## Limits of this record

- Compat mode only: the program is a Linux PIE loaded by OSv's ELF linker. Nothing here
  is UL-001 evidence. OSv was not built from source; the claim that it has no
  link-into-kernel application mode is from its documentation and build layout.
- The prebuilt kernel is the release's `osv-loader` (built on Fedora 35 per its
  `index.yaml`); its build is not reproduced here, and the release publishes no checksums.
- One clock sample; the IO helper-thread wake path was not exercised.
- `IO.exit` with an open pool (more than one lane) was not tried; only return-from-`main`
  with an open pool was.
- Two-vCPU runs are multi-threaded TCG, not hardware. No accelerated hypervisor was used.
