# Genode shim trust inventory (GB-006)

Status: started in the Genode host-layer lane, Task 1 (2026-11-03); completed
for the memory host layer in Task 3 (2026-11-04). The shim is linked into the
Bend components `writ_bend_hello`, `writ_bend_tests`, `writ_bend_example`,
`writ_bend_flow`, `writ_bend_transfer`, `writ_bend_gpuexample`, and
`writ_bend_overflow`. Under init on base-linux at 256M the corpus prints 764
PASS lines and `ALL LIBRARY TESTS PASSED`, and the corpus and examples match
the Linux single-lane reference line for line
(`verification/genode-corpus-base-linux.txt`). This file lists host binding
code only; none of it is Writ policy, and no authority, label, budget, or
release decision is made here. The request queue and effects of task 2.2 are
not part of this shim yet.

## Files

| File | Role | Linked into |
| --- | --- | --- |
| `hosts/genode/shim/writ_mem.cc` | memory host layer: lazily populated anonymous reservations, guard pages, component entry | `writ_probe_reservation` (C probe, Task 1); `writ_bend_hello` (Bend program, Task 2; `scripts/genode/writ_bend_hello/target.mk`, `LIBS = base libc`, posix no longer linked); `writ_bend_{tests,example,flow,transfer,gpuexample,overflow}` (Bend programs, Task 3; `scripts/genode/writ_bend_<name>/target.mk`, same pattern) |

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
The 1 TiB bound also caps the runtime's `corpus_grow`, which doubles the
term heap in place by mapping a span as large as the current corpus at its
end (requests up to 4 TiB): growth stops after the 1 TiB request, at a 2 TiB
corpus, and the runtime then posts its out-of-memory error. No run comes
near it (each base-linux region map also holds at most 4096 pieces).
A chunk is only allocated if the PD's available RAM covers it plus 64 KiB
and at least 8 caps remain. At most 16 benign retries per page address
(16 slots) for faults on an already populated chunk. Limits of that table:
counts never decay, so a page that races benignly more than 16 times over
the whole run is refused (component dies); and with more than 16 addresses
stuck at once the slots evict each other before any reaches the bound, so an
unresolvable fault among them livelocks instead of terminating.

## Changes in Task 3

- Comments only, implementation tokens unchanged (compared with the c96ef40
  revision; `verification/genode-corpus-base-linux.txt`, "SHIM EDIT"): the
  1 TiB bound's note on `corpus_grow`, and the defence-in-depth note on the
  unreachable zero-size check. sha256 now
  `8ba108f2240aebb161f12ca85cf48cfae79968a5e80b772abfb9acdd03ef4774`.
- No functional change was needed for the corpus, the examples, or the
  fault run.

## Fault behaviour observed through a Bend program

`writ_bend_overflow` (`scripts/runtime-profile/Overflow.bend`): every
touched stack chunk costs RAM and one dataspace capability. At ram 256M the
shim refused a chunk for RAM quota; at 3G with 1000 caps for cap quota; at
3G with 2000 caps the recursion reached the runtime's guard and the shim
logged `unresolved fault at 0x7ffff7f43000 (guard page), component
terminates`. The process ended each time and nothing resumed. The parent
(init) logged nothing; the shim does not and cannot report to the parent.

## Concurrency assumption

Only single-lane use has been run. One mutex guards all shim state and is
also taken by the SIGSEGV handler. Two lanes faulting on the same chunk, or
a touch while mprotect re-pieces a chunk, are handled by a bounded retry
(not exercised). A fault taken while the faulting thread holds a Genode
lock the handler needs would deadlock. The handler runs on the faulting
stack (no SA_ONSTACK, see the source header), so a machine-stack overflow
dies without the shim's line.

## Reviewer

Not yet reviewed. The shim is now linked into the Bend components; the
reviewer is to be named by the lane's review of Task 3, and this line updated
with the name and the reviewed sha256.
