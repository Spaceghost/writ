# Plan: Library-unikernel runtime, port milestone

Spec: `openspec/changes/add-unikernel-library-runtime/` (UL-001 through UL-008; tasks 2.1 to 2.3). Prior evidence: `verification/unikernel-matrix-unikraft.md`, `verification/unikernel-pins.txt`, `docs/UNIKERNELS.md` ("Selection matrix, 2026-11"), `verification/runtime-profile-parity-1.txt` (the Linux single-lane record), `scripts/runtime-profile/check-binary.sh`. Read the "What the effect-twins task needs" list in `docs/UNIKERNELS.md` first; it names the gaps this plan closes.

## Global Constraints

- Toolchain: Bend 2.0.39 at `$HOME/.local/share/writ-toolchains/bend-2.0.39/bend/bin`, `BEND_NO_TELEMETRY=1`. Unikraft 0.21.0 with kraft 0.12.16 as pinned; the working app directories and `$W` are under `../writ-unikernel/` as the matrix records them (absolute path recorded there). qemu 11.1.2. No root.
- The generated C is never edited. Build configuration (Kraftfile, Makefile.uk, Kconfig, flags) may change and must be recorded with the error or need that motivated it.
- Host-layer code for the Unikraft target lives under `hosts/unikraft/` in this repository: Bend effect defs with their `.c` twins, plus any C linked into the Unikraft app (termination hook, exit device write). Each C file carries a header saying it is host binding code, not Writ policy, and `hosts/unikraft/INVENTORY.md` lists every authored non-Bend file, its exported symbols, and what it may touch (UL-004). Nothing under `hosts/` is imported by the library or the test suite.
- Everything built lives under `../writ-unikernel/`; nothing generated or downloaded is committed. Evidence under `verification/` with exact commands, versions, QEMU machine type, `-m` size, and whether `-no-reboot` was used. QEMU TCG is an emulated boot; never "GPU"; a run of an image as a Linux process is process execution.
- Monitor profile only: no socket, file, process, audio, or window effects linked (UL-003). Run `scripts/runtime-profile/check-binary.sh` on the image's ELF (static, non-stripped) and record the result (UL-003).
- Do not modify any `.bend` file under the root, `examples/`, `lib/`, or `writfs/`. Do not touch `Tests.bend`.
- Do not check a box in the change's `tasks.md` without its evidence file in the commit. Do not push. Commit on the current branch at each acceptance point. Write the SDD report file early and update it as you go.
- Time-box each task at about two hours of effort; a recorded stall with the last error is a valid outcome.

### Task 1: A harness-visible exit code

Today every outcome (success, `IO.die`, fault) ends with QEMU status 0 under `-no-reboot`. Make the three distinguishable.

1. Add the QEMU `isa-debug-exit` device to the harness (`-device isa-debug-exit,iobase=0xf4,iosize=0x04`); QEMU then exits with `(value << 1) | 1` when the guest writes `value` to port 0xf4.
2. Write a termination hook in C under `hosts/unikraft/` and link it into the app via `Makefile.uk`: on Unikraft's termination path (use its `uk_term`/termtab or `ukplat_terminate` hook mechanism in 0.21.0; read `lib/ukboot` and `plat/` to find the supported hook and cite the file) write the process exit status to port 0xf4 so that status 0 becomes QEMU exit 1 and status 1 becomes QEMU exit 3. If the termination hook cannot observe the exit status, write a fixed "terminated" value and record that limit.
3. Crash path: find whether Unikraft 0.21.0's crash handler (`uk_crash`, `CONFIG_LIBUKDEBUG_*`) can call a hook or be configured to halt rather than reset; if a hook exists, write a distinct value (for example 0x7e) on crash; if not, record the limit and rely on Task 2's observation.
4. Rebuild the hello image with the hook, run it under the harness, and record QEMU exit codes for: hello (success), a program that calls `IO.die(Unit, 1, ...)`, and `Overflow.bend` (fault). Evidence: `verification/unikernel-exit-codes.txt`.

Acceptance: three distinct QEMU exit codes for success, die, and fault, or a recorded limit for whichever path cannot be distinguished, with the hook's source inventoried.

### Task 2: Halt versus reset after a crash

Run `Overflow.bend` without `-no-reboot` under a 60 s timeout, with serial captured. Record whether the guest halts (no further output), resets and re-runs the program (the banner or the probe's output appears again), or exits through the Task 1 hook. If it resets, state in the evidence and in `docs/UNIKERNELS.md` that `-no-reboot` is mandatory for every Writ image until a halting crash hook exists, and whether the Task 1 crash hook changes that. Evidence: `verification/unikernel-crash-action.txt`.

Acceptance: the platform action after a crash is observed, not inferred, and the harness requirement is stated accordingly.

### Task 3: The corpus and examples as single-lane images

Build `Tests.bend`, `Example.bend`, `examples/Flow.bend`, `examples/Transfer.bend`, and `GpuExample.bend` as Unikraft images with the Task 1 hook, single lane (`UKPLAT_CPU_MAXCOUNT=1`, `+RTS --threads 1 --gpu off` via `-append`), and enough guest RAM for the runtime's reservations plus the corpus (start at `-m 4096`; record the first size that works). Capture each serial console and compare line for line with the Linux single-lane records (`verification/runtime-profile-parity-1.txt` for the corpus; `verification/runtime-profile-parity-examples-1.txt` or the examples captures the runtime-profile lane stored). Record QEMU exit codes. Evidence: `verification/unikernel-corpus-qemu.txt` with the diff output (expected empty apart from any banner lines the harness strips; say exactly what was stripped).

If the corpus does not fit or hangs, bisect once between the hello image and the corpus (for example `examples/Flow.bend` first) and record where it stops.

Acceptance: the corpus prints 764 PASS lines and `ALL LIBRARY TESTS PASSED` on the console with QEMU exit 1 (status 0 via the hook), and the four examples print their recorded assertion lines; or a recorded stopping point.

Note (2026-11-04): 764 was the corpus count before the lane merged master (dc6ff2b); the current corpus is 782 checks, and verification/unikernel-corpus-qemu.txt records both runs.

### Task 4: Profile check, inventory, and task boxes

Run `scripts/runtime-profile/check-binary.sh` on the non-stripped image ELFs (static link: effect rows only) and record the output in `verification/unikernel-binary-check.txt`. Write `hosts/unikraft/INVENTORY.md`. Check `tasks.md` 2.1 (effect twins and inventory, if the hook and any Bend effect defs exist and the binary check ran), 2.2 (corpus parity, if Task 3 matched), and 2.3 (fault handler, only if the crash path yields a distinct exit code; otherwise leave unchecked and say why). Leave 2.4 and section 3 unchecked.

Acceptance: evidence files exist, inventory complete, boxes match evidence.
