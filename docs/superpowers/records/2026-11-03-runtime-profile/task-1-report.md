# Task 1 report: inventory command and reconciled inspection

Status: DONE_WITH_CONCERNS (one concern affects Task 2; see below)

Commit: 35a9b22 Add runtime host inventory command and reconcile the Bend runtime inspection

## Implemented

- `scripts/runtime-profile/Hello.bend`: the reference program, verbatim from the brief.
- `scripts/runtime-profile/inventory.sh` (POSIX sh, shellcheck clean). From the repo root it:
  1. runs `bend scripts/runtime-profile/Hello.bend -o ../writ-build/runtime-profile/hello.c`;
  2. extracts sorted (LC_ALL=C), unique host calls `name(` matching the brief's pattern list, with an
     area tag per name; a name preceded by an identifier char, `.` or `>` is not counted (so `fread(`,
     `io_read(` are not `read(`);
  3. extracts `io_eff(CID_<Name>,` registrations (the definition `io_eff(u32 cid, ...)` does not match)
     and prints `<Name>` plus Bend spelling (first `_` -> `.`);
  4. additionally lists requests the IO loop handles before the effect table (`c == CID_<Name>`), to
     report the exit path, which is not an effect row;
  5. writes `verification/runtime-inventory-bend-<version>.txt` with `bend version`, local date, the
     exact commands, emitted line count and sha256, and lane/GPU mode stated as not applicable (nothing runs).
- Matched registration pattern (documented in the script header), confirmed in hello.c line ~2988:
  `static void __attribute__((constructor)) io_print_use(void) { io_eff(CID_IO_print, io_print_run); }`
- Extraction extension: `MTL[A-Z][A-Za-z]+` added, because the doc's GPU row names Metal and the brief's
  list would otherwise miss it (yields `MTLCreateSystemDefaultDevice`, `MTLSizeMake`).

## Run and output

`sh scripts/runtime-profile/inventory.sh` -> `wrote verification/runtime-inventory-bend-2.0.39.txt`.
Header: `Bend version: bend 2.0.39`, `Date: 2026-11-03 (CST)`, emitted C 3074 lines (matches the doc).

- Host calls: 69 names across memory, faults, threads, clock, event-loop, process,
  process-and-device (fopen/fscanf/fclose), allocation-and-strings, atomics, device.
- Effect rows: exactly one, `IO_print -> IO.print`.
- Loop-handled requests: `Emit`, `Exit`, `Halt`. The exit path (`IO.exit` -> Exit, `IO.die` -> Halt)
  is handled in the IO loop and calls `exit()`; it has no `io_eff` row. So the brief's expectation
  "IO.print and the exit path" holds, but only IO.print is an effect row.

Every call named in the doc's table appears in the evidence file (mmap, mprotect, munmap, sigaltstack,
sigaction, signal, pthread_create, mutex/cond, pthread_detach, sched_yield, clock_gettime, nanosleep,
pipe, fcntl, select, read, write, getenv, exit, sysconf, sched_getaffinity, cgroup reads via
fopen/fscanf/fclose, atomics, fopen, cu*, nvrtc*, MTL*).

Other checks:
- `bend Tests.bend`: rc 0, 638 PASS lines, `ALL LIBRARY TESTS PASSED`.
- `bend PROOF.bend`: rc 0, `ALL PROOFS CHECK` (no `--verdict`; Lean kernel check not run).
- `openspec validate --all --strict --no-interactive`: 42 passed, 0 failed.
- A throwaway `bend ... -o hello-probe` dynamic build (deleted afterwards) showed `nm -u` has no
  cu*/nvrtc* symbols although /opt/cuda/bin/nvcc exists; cited in the doc's GPU row.

## Doc corrections (docs/BEND-RUNTIME.md)

- Added a paragraph naming the repeatable command and evidence file; noted extraction is textual.
- Memory: notes the `reservation failed` fail-stop.
- Faults: handler uses `write(2)`, `signal(SIG_DFL)`, `raise`.
- Threads: names the mutex/cond calls and adds `pthread_self` (error-claim).
- Clock: nanosleep also used by the error-claim wait.
- Process: cgroup reads are `fopen`/`fscanf`/`fclose` of cpu.max or cgroup v1 files; `_exit(1)` on failure.
- New row "Allocation and text": malloc, calloc, realloc, free, strdup, snprintf, stdio.
- Atomics: named the C11 ops and the `__atomic_exchange_n`/`__atomic_store_n` host spin-lock builtins
  (removed the "fences" claim: the only `atomic_thread_fence(` is in the Metal device path).
- GPU: CUDA/NVRTC plus `open`/`fopen` under `BEND_CUDA`, Metal under `__OBJC__`; replaced
  "absent with --gpu off on a machine without a device" with the observed nm result.
- Effects paragraph: names the io_eff pattern, says Hello registers exactly IO.print, and that
  Halt/Exit/Emit are handled by the loop, not rows.

## Files changed

- scripts/runtime-profile/Hello.bend (new)
- scripts/runtime-profile/inventory.sh (new)
- verification/runtime-inventory-bend-2.0.39.txt (new)
- docs/BEND-RUNTIME.md (edited)
No existing .bend file touched; tasks.md untouched (Task 3 checks boxes).

## Self-review

- Acceptance: evidence exists, names the version, includes every doc-table call, lists exactly the
  effect rows Hello registers (one) and reports the exit path separately. Met.
- Built only what was asked plus the documented MTL extension and loop-handled section.
- `_exit` and `raise` are used by the runtime but are not in the brief's pattern list; I mentioned
  them in the doc but did not extend the extraction (the doc table did not list them before).

## Concerns

1. Task 2 says to derive the monitor allowlist as "inventory minus the GPU group (cu*, nvrtc*, fopen,
   fscanf, fclose)". On Linux `fopen`/`fscanf`/`fclose` are used unconditionally by `cpu_count()`
   (cgroup quota) at startup in `main`, so removing them would make a correct monitor fail the check.
   `open` is the device-only one. Task 2 should keep fopen/fscanf/fclose (or its empirical `nm -u` step
   will re-add them).
2. `verification/source-sha256.txt` is already stale on this branch (DRIFT.md, GENODE.md, PLATFORMS.md,
   ROADMAP.md fail `sha256sum -c`; ~48 tracked files absent including docs/BEND-RUNTIME.md). I did not
   regenerate it, since that would span other lanes' files; the controller should decide.
3. The extraction is textual over all preprocessor branches, so it is an upper bound, not a link set.
