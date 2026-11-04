# Task 2 report: the Bend hello reaches main (base-linux)

Status: DONE_WITH_CONCERNS (2026-11-03, 22:50 to 23:10 -06:00)
Branch: lane/genode-host-layer. Commits (not pushed):
- 43a6e79: the shim bounds a qualifying mmap at 1 TiB, the retry-table limits
  are documented, the probe is tightened.
- 9d3b4a3: the shim is linked into writ_bend_hello, and hi prints at 256M.
- c96ef40: corrected the recorded hashes and regenerated the manifest.

## Result

The unmodified generated hello C (hello.c sha256 260b70a3...56cf, matching
the earlier record; it was not re-emitted) is linked with
hosts/genode/shim/writ_mem.cc. Under init on base-linux (Genode-on-Linux, not
native) at ram 256M it printed `hi` and exited with value 0. Three identical
runs (8, 9, 10). At exit the component had used 8314880 of 268313180 bytes of
RAM (about 7.9 MiB) and 35 of 963 caps. There were 2 reservations (the 8 GiB
term heap and the 2 GiB evaluation stack) and 1 guard. Three 2 MiB chunks
were charged. The corpus was placed at its first hint (1<<45), so the hint
path now has an execution.

Final log (run 10):
```
[init -> writ_bend_hello] writ_mem: libc mmap=0x16d14bc0 munmap=0x16d0aa00 mprotect=0x16cfc150 shim mmap=0x100ed20
[init -> writ_bend_hello] hi
[init -> writ_bend_hello] writ_mem: [exit] ram used=8314880 limit=268313180 caps used=35 limit=963 reservations=2 guards=1 chunks populated (total)=3 faults resolved=3 benign retries=0 reserved at hint=1 elsewhere=1 released=0
[init] child "writ_bend_hello" exited with exit value 0
Run script execution successful.
```

## What changed, and why (each item is in the evidence with its error)

1. target.mk: `SRC_C = hello.c`, `SRC_CC = writ_mem.cc`, `LIBS = base libc`.
   posix is dropped because the shim's construct replaces posix's. The build
   succeeded first time. CC_MARCH (small model) and LIBGCC_INC_DIR (clang's
   resource directory) are target-wide, so they also reach the shim. The
   include directory cannot be set per object, because global.mk expands
   ALL_INC_DIR with `:=`. writ_mem.d shows that the shim includes no compiler
   header, so neither setting affects it.
2. Interposition: the program binary's own definitions win. No libc override
   mechanism was used, and libc has none for these calls. hello.o's calls
   bind directly at static link time (objdump shows `call 100ec90 <mmap>`).
   The binary also exports the three functions in .dynsym. libc's originals
   are reached through Shared_object lookup, and the log shows different
   addresses for libc and the shim.
3. `-DMAP_NORESERVE=0` is still required. Without it the compile fails with
   `hello.c:1656:30: error: use of undeclared identifier 'MAP_NORESERVE'`.
   The shim does not need the flag, but the libc headers lack the name.
4. The run script adds a vfs_pipe mount at /pipe, the libc `pipe: /pipe`
   attribute and lib/vfs_pipe (replacing lib/posix in the build list). It
   keeps `+RTS --threads 1 --gpu off` as `<arg>` nodes and sets
   `<env WRIT_MEM_REPORT=1>`. The checks are: exit value 0, the shim's start
   line, the shim's exit report, and exactly one other component line, `hi`.
5. Found during the runs and fixed in the shim: the first run printed `hi`
   and exited 0, but also logged
   `Warning: 1 dangling allocation at allocator destruction time`. The cause
   was the shim's static Constructible<Heap>. Static destruction inside exit()
   destroyed it while the runtime's reservations were still live, so their
   chunk tables were freed under a still-installed fault handler, and the RM
   session would have closed under mapped memory. The Heap, Rm_connection,
   PD client and libc Shared_object are now Kept<T>: placement-constructed,
   with no destructor. The warning is gone.
6. The shim gained diagnostics only: an opt-in `atexit` report (it reads
   `getenv("WRIT_MEM_REPORT")` once in construct) and the counters
   hint/elsewhere/released.
7. Carried items: _reserve rejects len > 1 TiB, and a zero rounded size,
   with ENOMEM. The retry-table limits (livelock above 16 stuck addresses,
   counts never decay) are in the header and the INVENTORY. The probe now
   accepts only EINVAL for the big mprotect, and a new case checks that
   mmap(SIZE_MAX-1) and mmap(2 TiB) give MAP_FAILED/ENOMEM. The live and
   guard probes still pass.

Regressions with the final shim: writ_bend_rts (help exits 0, bogus exits 1),
writ_probe_reservation_live (exit 0) and writ_probe_reservation_guard (guard
refusal, process gone). All pass.

## Hashes (live writ-repo copies byte-identical, checked with cmp)

- writ_mem.cc 734c5c374eabec53997213611c76729e3b3b5fef9e747875f905f9c8f91d8866
- target.mk c62f23eaf78632a1ceb158f6995e6bf0ecf093fcc50f4935daaf4621af55a721
- writ_bend_hello.run 434cb23ef767ea96720315834558704f8649a23978cac801bd0d7ebb02983b00
- probe_reservation.c 7a35d1e93d6138073e2c0b7ec298e92fc26b9c86c6ad03c65e737e874cea5eef
- binary (not committed) 1cd506ea36a8deb7a0c365c0a4d506796f9062cc6b68b4339878c1f321ee7ba7

## Files

- hosts/genode/shim/writ_mem.cc
- hosts/genode/probes/reservation/probe_reservation.c
- hosts/genode/INVENTORY.md: the shim is now linked into writ_bend_hello. New
  sections: interposition, Lifetime, the 1 TiB bound, the retry limits and the
  report.
- scripts/genode/writ_bend_hello/target.mk and writ_bend_hello.run
- verification/genode-bend-hello-base-linux.txt: a dated host-layer section
  with H1-H7, the final run script, runs 6-10, the regressions, the fault
  interaction and the limits.
- verification/genode-reservation-probe-base-linux.txt: section 9.
- docs/GENODE.md: one paragraph.
- verification/source-sha256.txt: regenerated.
- tasks.md: not touched (no boxes this task).

## Concerns

- Fault interaction, recorded but not executed. Genode libc only emulates
  sigaction/sigaltstack, so err_trap never runs on base-linux, and the shim's
  raw handler is the only Linux SIGSEGV handler. A guard hit would print the
  shim's "guard page" line, not `bend: memory fault`. No guard touch through
  the Bend program was run; that is Task 3 (Overflow.bend). The handler has
  no SA_ONSTACK, so a machine-stack overflow, as distinct from the term-stack
  guard, would die without the shim's line.
- Single lane only (--threads 1). The signal-context PD RPC deadlock hazard
  and the retry table's limits remain unexercised.
- The parent record (GB-003) is still open on base-linux, and the fault front
  end is base-linux only.
- writ_bend_rts.run still builds lib/posix, which the binary no longer links.
  This is harmless and was left unchanged. The rows file's list of live-file
  hashes is now stale for writ_bend_hello.run and target.mk; Task 3 rewrites
  that file.
- Not run: bend Tests.bend, the native tests, PROOF.bend and openspec
  validate. No .bend, generated, or openspec file was changed, and this is
  host binding code, not a security-law change.
