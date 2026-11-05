# Report: unikraft-linuxu, Tasks 1 and 2

Branch `lane/unikraft-linuxu`, base 9835bd7. Implementer, 2026-11-04.

## Outcome

Stalled, recorded. The Bend hello, built as a Unikraft 0.16.3 `linuxu` application and run as a
process on the host kernel (process execution, not a boot), prints the banner and then
`bend: reservation failed`. It does not exit afterwards and is killed by `timeout` (124). `hi` was
not printed, so Task 2 took the stall branch. Box 1.3 is still unchecked.

## Task 1

- Tree: fresh clones of RELEASE-0.16.3 (unikraft e453b74a, lib-musl fd1abc92, the same commits
  the matrix used) under `../writ-unikernel/linuxu/src-0.16.3`, unpatched. The tag-archive sha256
  values are in the new pins section. The app directories `linuxu/hello-linuxu{,-heap4095,-heap8196}`
  were written by hand (A1 stdatomic symlink, A2 `-std=gnu11`) and were not copied from
  `hosts/unikraft/app/`.
- The failing mapping, seen under gdb with no strace: the runtime's CPU heap, `corpus_map`, makes
  13 requests of `mmap(len=0x200000000, MAP_NORESERVE|MAP_ANONYMOUS|MAP_PRIVATE)`, 12 high-base
  hints and then NULL. Each one returns -ENOMEM from Unikraft's `uk_syscall_e_mmap` (lib/ukmmap),
  and then `err_fail` is called from `pool_mmap` (hello.c:1662). The 2 GiB stack reservation is
  never reached.
- Attempt 1 (runtime options): there are none. The generated C accepts only `--threads`, `--gpu`,
  `--gpu-build` and `--help`. The CPU heap is `1ull << 33` (hello.c:2257) and the stack is
  `1ull << 31` (hello.c:1668).
- Attempt 2 (platform memory): `LINUXU_DEFAULT_HEAPMB` (plat/linuxu/Config.uk:14-21) is the only
  option. setup.c:62-72 computes the heap length as a `__u32`, so 4095 MiB is the maximum. With
  4095 the host maps all of it (seen in /proc maps) and the run still stops at the reservation.
  8196 wraps to 4 MiB. This attempt came closest.
- Attempt 3 (MAP_NORESERVE path): there is none. `posix-mmap` needs `ukvmem`, which selects
  PAGING, and `linuxu` depends on `!HAVE_PAGING`. `ukmmap` serves every request with
  `uk_memalign` plus `memset` from the platform heap (mmap.c:98, :112).
- Evidence: `verification/unikernel-linuxu.txt`. Pins: `verification/unikernel-pins.txt`,
  section "Unikraft 0.16.3 linuxu tree".

## Task 2 (stall branch)

- The stopping point is now in three places: one paragraph in `docs/UNIKERNELS.md` (it replaces
  the older one-liner, which put the stop down to the missing `posix-mmap`), a note on 1.3 in
  `openspec/changes/add-unikernel-library-runtime/tasks.md` with the box left unchecked, and the
  evidence file.
- Not done, because hello did not run: building Tests.bend, the 782-PASS comparison, and
  check-binary.sh.

## Checks

- `openspec validate --all --strict --no-interactive`: 44 passed, 0 failed. This ran under
  OpenSpec **1.11.0**, the version installed here, not the 1.16.0 that AGENTS.md names.
- `bend Tests.bend` and `bend PROOF.bend` were not run. The changes are documentation and evidence
  only; no Bend source changed.

## Concerns

- `openspec/traceability/unikernel-library-runtime.md` (UL-002, UL-007) still cites only matrix
  E10 for linuxu. It is outside this lane's touch list, so it does not point at the new evidence
  file.
- `verification/source-sha256.txt` was not updated, because the brief said no manifest.
- Nothing traced why linuxu's `_exit(1)` does not end the process.

## Fix round 1

This round answers task-1-review.md.

- OpenSpec: I reran validation with the pinned 1.16.0 (`~/.bun/bin/bunx @fission-ai/openspec@1.16.0 validate --all --strict --no-interactive`). Result: 44 passed, 0 failed, exit 0. I ran it once before the traceability edit and once after. The evidence file records the command and the result, and says the 1.11.0 run is superseded.
- Observation commands: `verification/unikernel-linuxu.txt` now gives the gdb command file verbatim, the gdb run line, the `/proc/<pid>/maps` and status capture, and the commands behind the other outputs it quotes (image hashes, .config grep, run-log extraction, generated-C hash, nm).
- Traceability (controller ruling): `openspec/traceability/unikernel-library-runtime.md` rows UL-002 and UL-007 now cite `unikernel-linuxu.txt` as the 0.16.3 linuxu chase, alongside matrix E10. The citation says the run stalled at the 8 GiB reservation and that box 1.3 is still open. This is a text change only: no box or requirement changed.
- `verification/source-sha256.txt` is still not updated (no manifest, as instructed).
