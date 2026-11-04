# Genode shim trust inventory (GB-006)

Status: started in the Genode host-layer lane, Task 1 (2026-11-03). Since
Task 2 the shim is linked into the Bend component `writ_bend_hello`, which
prints `hi` under init on base-linux at 256M
(`verification/genode-bend-hello-base-linux.txt`, host-layer section). Task 3
completes this inventory. This file lists
host binding code only; none of it is Writ policy, and no authority, label,
budget, or release decision is made here.

## Files

| File | Role | Linked into |
| --- | --- | --- |
| `hosts/genode/shim/writ_mem.cc` | memory host layer: lazily populated anonymous reservations, guard pages, component entry | `writ_probe_reservation` (C probe, Task 1); `writ_bend_hello` (Bend program, Task 2; `scripts/genode/writ_bend_hello/target.mk`, `LIBS = base libc`, posix no longer linked) |

Live copy for the Genode build: `../writ-genode/writ-repo/src/writ_shim/writ_mem.cc`,
byte-identical; its sha256 is recorded with each run in
`verification/genode-reservation-probe-base-linux.txt` and, for the Bend
component, `verification/genode-bend-hello-base-linux.txt`.

How the entry points win: plain symbol interposition by the program binary.
Calls from the program's own objects bind to the shim's definitions at static
link time, and the binary exports them in `.dynsym`, so ld.lib.so's global
lookup finds them before libc's. No libc override mechanism is used (libc
offers none for these calls); libc's originals are reached by
`Shared_object` lookup.

Probe scaffolding (not part of the shim, holds no authority):
`hosts/genode/probes/reservation/` (`probe_reservation.c`, `target.mk`, two run scripts).

## Exported symbols (`writ_mem.cc`)

| Symbol | Kind | Behaviour |
| --- | --- | --- |
| `mmap` | public entry point, shadows libc | qualifying requests (len >= 1 GiB, `PROT_READ\|PROT_WRITE`, `MAP_PRIVATE\|MAP_ANON`, no `MAP_FIXED`/`MAP_SHARED`, fd -1, offset 0) become a reservation; everything else goes to libc's `mmap` |
| `munmap` | public entry point, shadows libc | whole reservation only (partial or overflowing length: -1 `EINVAL`); other ranges go to libc |
| `mprotect` | public entry point, shadows libc | `PROT_NONE` on a page-aligned range in a reservation makes a guard; `PROT_READ\|PROT_WRITE` on a guard-free range in a reservation returns 0 (it already is); lifting a guard or any other prot: -1 `ENOTSUP`; len 0, len larger than the reservation, or a range not contained in it: -1 `EINVAL`; outside reservations: libc (-1 `ENOSYS`) |
| (all three above) | | fail with `ENOSYS` before `Libc::Component::construct` has resolved libc's originals |
| `Libc::Component::construct` | component entry | stores the Env, resolves libc's originals, then runs `main` as `posix`'s construct.cc does (so `posix` is not linked); if the libc environment has `WRIT_MEM_REPORT=1` it registers an `atexit` report first (diagnostics only, reads no other configuration) |
| `writ_mem_report` | diagnostics helper | logs PD RAM used/limit, caps, and reservation counters (populated chunks, faults resolved, benign retries, reservations placed at the hint or elsewhere, released); called by the probes, and from `exit` when `WRIT_MEM_REPORT=1` |
| `writ_mem_restore_rt` | local (not global) asm symbol | `rt_sigreturn` restorer for the SIGSEGV handler |

## Sessions and kernel interfaces used

- **RM** (`Rm_connection`, one per component, opened at the first reservation):
  `create`/`destroy` of one region map per reservation. On base-linux this
  session is local to the component.
- **PD** (the component's own), through a plain `Pd_session_client` on
  `Env::pd_session_cap()`: `alloc_ram`/`free_ram` for 2 MiB chunks and
  `stats()` to refuse a chunk the RAM or cap quota cannot cover. The
  expanding `Env::pd()` client is deliberately not used for chunks, so a
  fault never turns into a blocking resource request.
- **Parent**: `exit(1)` if libc's originals cannot be resolved. Parent
  `resource_request` can still be issued indirectly by `Env::ram()`/`Env::pd()`
  allocations outside the fault path (the Heap below, Rm_connection session
  upgrades in `Rm_connection::create`), never from the fault handler's chunk
  allocation.
- **Env::ram() and Env::rm() behind a Genode `Heap`**: the per-reservation chunk
  tables and the `Shared_object` metadata.
- **Local region map** (`Env::rm()`): attach/detach of each reservation.
- **ROM** (through the dynamic linker): `Shared_object` for `libc.lib.so` to
  reach libc's own `mmap`, `munmap`, `mprotect`.
- **base-linux only**: the raw Linux `rt_sigaction`, `getpid`, `gettid`, and
  `tgkill` system calls for SIGSEGV (the region-map fault signal is never
  delivered on base-linux). Kernels
  that deliver region-map faults need a different front end, not built.

## Lifetime

The shim's Heap, Rm_connection, plain PD client, and libc `Shared_object`
are never destroyed (`Kept<T>`, no destructor): the Bend runtime exits with
its reservations still mapped, and static destruction inside `exit` would
otherwise revert the live chunk tables and close the RM session under mapped
memory (observed as a "dangling allocation" warning with the Bend hello).

## Bounds

32 reservations, 4 guards per reservation, 2 MiB chunks, 1 GiB threshold,
1 TiB maximum (a larger qualifying `mmap`, including one whose length would
wrap when page-rounded, fails with `ENOMEM` before a region map is created).
A chunk is only allocated if the PD's available RAM covers it plus 64 KiB
and at least 8 caps remain. At most 16 benign retries per page address
(16 slots) for faults on an already populated chunk. Limits of that table:
counts never decay, so a page that races benignly more than 16 times over
the whole run is refused (component dies); and with more than 16 addresses
stuck at once the slots evict each other before any reaches the bound, so an
unresolvable fault among them livelocks instead of terminating.

## Concurrency assumption

Only single-lane use has been run. One mutex guards all shim state and is
also taken by the SIGSEGV handler. Two lanes faulting on the same chunk, or
a touch while mprotect re-pieces a chunk, are handled by a bounded retry
(not exercised). A fault taken while the faulting thread holds a Genode
lock the handler needs would deadlock. The handler runs on the faulting
stack (no SA_ONSTACK, see the source header), so a machine-stack overflow
dies without the shim's line.

## Reviewer

Not yet reviewed. To be named when the shim is linked into the Bend component.
