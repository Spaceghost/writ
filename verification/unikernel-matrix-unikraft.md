# Unikraft build matrix for the Bend hello program

Recorded 2026-11-03. Task 1 of the library-unikernel runtime lane (native link: Bend's
generated C compiled as the Unikraft application against lib-musl). Versions and
install commands are in `verification/unikernel-pins.txt`. Everything built lives under
`../writ-unikernel/`; nothing generated is in the tree. The `linuxu` run is **process
execution** of the image as a Linux process, not a boot. The QEMU runs are **emulated
boots** under TCG. All runs use `+RTS --threads 1 --gpu off`; no accelerator was used.

Input: `scripts/unikernel/Hello.bend` (`IO.print("hi")`), emitted with
`bend scripts/unikernel/Hello.bend -o ../writ-unikernel/hello/hello.c`
(Bend 2.0.39, 3074 lines, sha256 `260b70a3...cf8cfd4a4`).

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
  `stdatomic.h` (`/usr/lib/gcc/x86_64-pc-linux-gnu/16/include/stdatomic.h`).
- **A2** GCC 16 defaults to C23, where `void (*f)()` takes no arguments; Unikraft core
  0.21.0 calls constructors as `(*ctorfn)(argc, argv)`. Built with `UK_CFLAGS=-std=gnu11`
  in the environment (applies to all Unikraft and app objects).
- **A3** Added `CONFIG_LIBPOSIX_PIPE` and `CONFIG_LIBPOSIX_POLL` to the plan's four
  libraries so the runtime's self-pipe (`pipe`, `select`) exists. Supplementary to Task 1;
  the plan's library set is the A1 + A2 row.

The CUDA and Metal includes in the emitted C are under `#ifdef __OBJC__` / `#elif
BEND_CUDA` / `#ifdef __METAL_VERSION__` and were not pulled in by the Unikraft build; the
only header the build lacked was `stdatomic.h`. GCC warns `ignoring '#pragma clang fp'`
and several `-Wmisleading-indentation` in `hello.c`; neither is an error.

## Application directory

`../writ-unikernel/hello-unikraft/` (0.21.0) and `../writ-unikernel/hello-unikraft-0.16.3/`
(0.16.3, linuxu). Both use the same `Makefile.uk` and an empty `Config.uk`.

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

Common kraft prefix used below (`$W` = `../writ-unikernel`):

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
timeout 60 .unikraft/build/hello-bend_linuxu-x86_64 +RTS --threads 1 --gpu off
```

Full output, exit status 1:

```
[172573.930571] CRIT: [liblinuxuplat] <console.c @   92> Failed to initialize terminal console
```

(linuxu's console calls `tcgetattr(STDIN)` and crashes when stdin is not a TTY.)

Run 2, under a pseudo-terminal (process execution):

```sh
timeout 60 script -q -e -c ".unikraft/build/hello-bend_linuxu-x86_64 +RTS --threads 1 --gpu off" /dev/null </dev/null
```

Full output (escape sequences and CRs removed), exit status 124 from `timeout`:

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
  -append "+RTS --threads 1 --gpu off" -no-reboot
```

Full serial output (escape sequences and CRs removed), exit status 124 from `timeout`:

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
```

The reservation passed (no `reservation failed`); the self-pipe could not be created
without `posix-pipe`, the runtime printed its failure, and the image did not halt.

### Unikraft 0.21.0, A1 + A2 + A3 (supplementary)

Same build and run commands after adding `CONFIG_LIBPOSIX_PIPE` and `CONFIG_LIBPOSIX_POLL`.
Link: **succeeded**; image sha256 `90740194620c27f04749217d179a125073480114328bbe03677e81770c3dce91`.

Full serial output, QEMU exit status 0 (the guest shut down after `main` returned):

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
```

## Limits of this record

- Whether the `-append` string reached `main` as `argv` (with `LIBUKLIBPARAM` unset) was
  not checked; the runtime accepted it without a usage error. Task 2 should confirm.
- The exit status of `main` is not visible from QEMU here; only "halted" vs "did not halt
  within 60 s" is recorded.
- Only one lane was requested (`--threads 1`, `UKPLAT_CPU_MAXCOUNT=1`); thread creation,
  faults, and clocks are Task 2 rows and are not established by these runs.
- The linuxu evidence is from Unikraft 0.16.3, not the primary 0.21.0 pin, and its
  posix-mmap was unavailable. These are process executions, not boots.
- Full build and run logs are in `../writ-unikernel/logs/` (outside the tree).
