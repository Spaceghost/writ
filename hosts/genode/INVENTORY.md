# Genode shim trust inventory (GB-006)

Status: started in the Genode host-layer lane, Task 1 (2026-11-03). Task 3
completes it once the shim is linked into a Bend component. This file lists
host binding code only; none of it is Writ policy, and no authority, label,
budget, or release decision is made here.

## Files

| File | Role | Linked into |
| --- | --- | --- |
| `hosts/genode/shim/writ_mem.cc` | memory host layer: lazily populated anonymous reservations, guard pages, component entry | `writ_probe_reservation` (C probe, Task 1); the Bend component from Task 2 on |

Live copy for the Genode build: `../writ-genode/writ-repo/src/writ_shim/writ_mem.cc`,
byte-identical; its sha256 is recorded with each run in
`verification/genode-reservation-probe-base-linux.txt`.

Probe scaffolding (not part of the shim, holds no authority):
`hosts/genode/probes/reservation/` (`probe_reservation.c`, `target.mk`, two run scripts).

## Exported symbols (`writ_mem.cc`)

| Symbol | Kind | Behaviour |
| --- | --- | --- |
| `mmap` | public entry point, shadows libc | qualifying requests (len >= 1 GiB, `PROT_READ\|PROT_WRITE`, `MAP_PRIVATE\|MAP_ANON`, no `MAP_FIXED`/`MAP_SHARED`, fd -1, offset 0) become a reservation; everything else goes to libc's `mmap` |
| `munmap` | public entry point, shadows libc | whole reservation only (partial: -1 `EINVAL`); other ranges go to libc |
| `mprotect` | public entry point, shadows libc | `PROT_NONE` on a page-aligned range in a reservation makes a guard; lifting a guard or any other prot: -1 `ENOTSUP`; outside reservations: libc (-1 `ENOSYS`) |
| `Libc::Component::construct` | component entry | stores the Env, resolves libc's originals, then runs `main` as `posix`'s construct.cc does (so `posix` is not linked) |
| `writ_mem_report` | diagnostics helper (probes only) | logs PD RAM used/limit and reservation counters |
| `writ_mem_restore_rt` | local (not global) asm symbol | `rt_sigreturn` restorer for the SIGSEGV handler |

## Sessions and kernel interfaces used

- **RM** (`Rm_connection`, one per component, opened at the first reservation):
  `create`/`destroy` of one region map per reservation. On base-linux this
  session is local to the component.
- **PD** (the component's own, `Env::pd()`): `alloc_ram`/`free_ram` for 2 MiB
  chunks, `stats()` to refuse a chunk the quota cannot cover.
- **Local region map** (`Env::rm()`): attach/detach of each reservation.
- **ROM** (through the dynamic linker): `Shared_object` for `libc.lib.so` to
  reach libc's own `mmap`, `munmap`, `mprotect`.
- **base-linux only**: the raw Linux `rt_sigaction` system call for SIGSEGV
  (the region-map fault signal is never delivered on base-linux). Kernels
  that deliver region-map faults need a different front end, not built.

## Bounds

32 reservations, 4 guards per reservation, 2 MiB chunks, 1 GiB threshold.
A chunk is only allocated if the PD's available RAM covers it plus 64 KiB.

## Reviewer

Not yet reviewed. To be named when the shim is linked into the Bend component.
