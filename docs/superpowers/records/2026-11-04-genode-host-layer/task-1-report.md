# Task 1 report: lazily populated reservation with a guard (C probe, base-linux)

Status: DONE_WITH_CONCERNS (2026-11-03, about 1 h 15 min)
Branch: lane/genode-host-layer, commit 9f3451f (not pushed)

## Result

Under init on base-linux (Genode-on-Linux, not native) with ram 256M, a C probe
linked with the shim reserved 8 GiB anonymous memory. The reservation cost
233472 bytes of metadata and no RAM backing. Four touches in three 2 MiB chunks
charged exactly 6291456 bytes. A 16 KiB PROT_NONE guard split a populated chunk
without losing the bytes on either side. In mode B the probe unmapped
everything (used RAM went back to start + 64 KiB) and exited 0. In mode A a
write inside the guard was refused by the shim
(`writ_mem: unresolved fault at 0x7ffef7f02000 (guard page)`), the host
kernel logged a segfault at that address, and the process was gone. Init
logged nothing. Each mode ran twice with the same result.

## Files

- hosts/genode/shim/writ_mem.cc: one C++ unit, host binding header. Exports
  `mmap`/`munmap`/`mprotect`, `Libc::Component::construct` (it replaces
  posix's construct) and the diagnostics helper `writ_mem_report`.
- hosts/genode/probes/reservation/: probe_reservation.c, target.mk
  (`LIBS = base libc`, vpath to `$(REP_DIR)/src/writ_shim`),
  writ_probe_reservation_live.run (mode B), writ_probe_reservation_guard.run
  (mode A).
- hosts/genode/INVENTORY.md: a start, with no reviewer named yet.
- verification/genode-reservation-probe-base-linux.txt: the evidence (commands,
  logs, exit values, RAM figures, hashes, header citations).
- docs/GENODE.md: a short subsection added. scripts/genode/writ_hello/build.conf.fragment:
  the two new scenarios added to WRIT_RUN_SCENARIOS, also edited in the live
  etc/build.conf.
- verification/source-sha256.txt: regenerated from git ls-files. It also
  picked up the three 2026-11-04 plan files, which master's manifest was missing.
- Live copies in ../writ-genode/writ-repo are byte-identical (cmp). writ_mem.cc
  sha256 is 8f313e94...5e679b.

## How libc's originals are reached

The binary's definitions win: the probe binds to them when it is linked, and
the binary also exports them in .dynsym. libc's ABI exports only `mmap`,
`mprotect` and `munmap`, with no `__sys_` alias (repos/libports/lib/symbols/libc:486-490).
So the shim looks the originals up with
`Shared_object(env, heap, "libc.lib.so", BIND_LAZY, KEEP).lookup()`, and it
refuses to start if a lookup returns its own function. The observed libc
addresses differ from the shim's, so forwarding works. I needed no libc
override mechanism.

## Concerns / deviations

1. **The fault front end is not a Genode signal.** On base-linux the
   region-map fault signal is never delivered (region_map.h doc comment, and
   base-linux region_map_client.cc:49-56 is empty). An unpopulated page is a
   PROT_NONE Linux mapping, so the shim installs its own Linux SIGSEGV handler
   with the raw rt_sigaction call and fills chunks from it. The front end that
   kernels like base-hw, NOVA and seL4 need (fault signal on a separate
   entrypoint) has not been built or tested.
2. **Parent record not met.** Init logged nothing about the dead child,
   so the acceptance clause "parent logging the fault" fails on base-linux,
   and GB-003's parent-record requirement stays open. What we observe instead
   is the shim's refusal line, the process vanishing (with the timer's
   process as a ps control), and the host kernel's segfault line.
3. **The signal-context RPC is a hazard.** The handler calls `alloc_ram` (a PD
   RPC) and attaches to the region map on the faulting thread. That is fine
   for this single-threaded probe, but with several lanes it could deadlock
   if a thread faults while holding a lock the handler needs. Threads are not
   tested yet, so this needs attention in Task 2/3 (a pager thread is the
   next thing to try).
4. **Paths not exercised:** the quota-exhaustion refusal, address hints
   (the runtime's corpus_at walks hints down from 2^45), partial-munmap
   refusal, more than one reservation, and the base-linux limit of
   MAX_REGIONS = 4096 pieces per region map (an 8 GiB reservation fully
   touched is exactly 4096 chunks).
5. The shim's SIGSEGV handler replaces base-linux's for the whole process
   after the first qualifying mmap. For faults outside every reservation it
   prints its own line, still ends with SIG_DFL, and the process dies.
6. Not run: `bend Tests.bend`, the native tests, PROOF.bend, openspec validate.
   No .bend, Bend-generated, or openspec file was changed, and this is host
   scaffolding, not a security-law change.

## Next (Task 2)

Link writ_mem.cc into writ_bend_hello (`LIBS = base libc`, drop posix). Check
whether the 2 GiB stack plus its guard at +2 GiB works, and whether the
`corpus_at` hint/munmap loop behaves. Add vfs_pipe.

---

# Fix pass after review of 9f3451f (2026-11-03, 22:30 to 22:50)

Status: DONE_WITH_CONCERNS. The details, commands and full logs are in
verification/genode-reservation-probe-base-linux.txt, section 8.

## Fixes

1. **Cap or RAM exhaustion no longer hangs.** Chunks are now charged through a
   plain `Pd_session_client(env.pd_session_cap())`, not through the expanding
   `Env::pd()`. The shim also checks the PD has at least chunk + 64 KiB of RAM
   and 8 caps available before `alloc_ram`. The refusal line now names the
   cause ("RAM quota", "cap quota", or the alloc_ram error).
   - Case run: exhaust with caps 78. Five chunks were charged, then the shim
     printed `chunk could not be charged: cap quota` and the component died.
     It did not hang.
   - Extra case: exhaust with caps 300. 122 chunks were charged, then the
     shim printed `RAM quota`.
2. **Length overflow fixed.** Lengths are now checked before any addition, and
   overlap is tested without computing `a + n`. Case run: mprotect with len
   SIZE_MAX-1, mprotect with len 0, and munmap with len SIZE_MAX-1 each
   return -1 with errno 22 (EINVAL).
3. **A fault on an already populated chunk is retried, not refused.** A fault
   there outside every guard now returns and lets the access retry, up to 16
   times per page address. The single-lane assumption and this race are
   documented in the source header, evidence §7 and INVENTORY. This path has
   not been exercised; there is no threaded case.
4. Minor items, all done:
   - The handler only accepts `si_code > 0`; any other SIGSEGV sets SIG_DFL
     and is re-raised with tgkill (not exercised).
   - Before construct, the three entry points fail with ENOSYS.
   - INVENTORY: the mprotect RW row is corrected, and Parent and
     Env::ram/Heap are added to the sessions list.
   - Evidence §7: added the EFAULT-on-syscall limit.
   - Restorer asm now has `.pushsection`, `.p2align 4`, `.size` and
     `.popsection`.
   - New probe case: a guard straddling the 6 GiB chunk boundary. Both sides'
     bytes are kept, and a write into its upper-chunk half was refused as
     `guard page`.
5. **Found during this pass: SA_ONSTACK removed.** With the fixes in place but
   SA_ONSTACK still set, mode B faulted at 0x5100 inside libc.lib.so after
   five resolved faults, on a stack other than the application's. base-linux
   uses each thread's whole primary stack as its alternate signal stack
   (thread_linux.cc:53-59), and libc runs main on a separate stack. The
   likely mechanism is that the handler overwrote the suspended entrypoint's
   frames. That explanation fits the observation but is not proven. Without
   SA_ONSTACK every case passes. The trade-off: a machine-stack overflow now
   dies without the shim's line. The first commit's three-fault runs did not
   show this failure, so its mode-B result was luck.

## Runs

All ran at 256M, from `../writ-genode/build/x86_64`, twice each, and the two
logs of each case are identical:

| Case | Command | Outcome |
|---|---|---|
| live (mode B) | `make run/writ_probe_reservation_live` | exit 0 |
| guard-touch (mode A) | `make run/writ_probe_reservation_guard` | guard refusal, process gone |
| straddle-touch | `WRIT_RESERVATION_MODE=straddle-touch make run/writ_probe_reservation_guard` | guard refusal, process gone |
| exhaust, caps 78 | `WRIT_RESERVATION_MODE=exhaust WRIT_RESERVATION_CAPS=78 make run/writ_probe_reservation_guard` | cap-quota refusal, process gone |
| exhaust, caps 300 | `WRIT_RESERVATION_MODE=exhaust WRIT_RESERVATION_CAPS=300 make run/writ_probe_reservation_guard` | RAM-quota refusal, process gone |

Every death has a matching host kernel segfault line. Init logged nothing in
any death case.

writ_mem.cc sha256 is now `84cc8f12...04eddac`, and the live copy is
byte-identical.

## Remaining concerns

- The fault front end is still a Linux SIGSEGV handler, and init still records
  nothing when the component dies (both unchanged).
- The retry path, the si_code re-raise, the hint path and multi-lane use are
  not exercised.
