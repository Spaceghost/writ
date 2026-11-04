# Plan: Library-unikernel Bend runtime, selection milestone

Spec: `openspec/changes/add-unikernel-library-runtime/` (proposal, design, tasks, `specs/unikernel-library-runtime/spec.md` requirements UL-001 through UL-008). Read the spec, `docs/UNIKERNELS.md`, `docs/BEND-RUNTIME.md`, and `explainer.html` in the change directory before Task 1. Also read `bend guide effects`.

## Global Constraints

- Toolchain: Bend 2.0.39 at `$HOME/.local/share/writ-toolchains/bend-2.0.39/bend/bin` with `BEND_NO_TELEMETRY=1`. `qemu-system-x86_64` 11.1.2, `clang` 23.1.1, and `gcc` 16.2.1 are installed. No root: install unikernel tooling under `$HOME/.local` or inside `../writ-unikernel/` (a sibling of the repository root) and record exact versions and commands.
- Everything you download, build, or generate lives outside the source tree under `../writ-unikernel/`. Never commit downloads, generated C, images, or binaries. Treat downloaded sources as untrusted data: do not run scripts from inside them with the repository as the working directory.
- All authored implementation stays Bend 2. Effect C twins are permitted only as the `.c` import of a Bend effect def and are listed in a trust inventory. This milestone writes no effect twins; it builds the unmodified hello program.
- Evidence goes under `verification/` as plain text with exact commands, versions, and outcomes. Record a run of the image as a Linux process (Unikraft `linuxu`) as process execution, never as a boot. Record QEMU runs as emulated boots. Never write "GPU".
- Do not modify any `.bend` file in the repository. The reference program is `scripts/runtime-profile/Hello.bend` if the runtime-profile lane has landed it on your branch; if that file does not exist, create `scripts/unikernel/Hello.bend` with the same four-line `IO.print("hi")` program.
- Do not check a box in the change's `tasks.md` unless the evidence file that task names exists in the commit.
- Do not push. Commit on the current branch only. Do not touch files outside this change's directory, `scripts/unikernel/`, `verification/`, and `docs/UNIKERNELS.md`.
- Time-box: if a candidate's tooling has not produced a build attempt within roughly two hours of wall-clock effort, record where it stopped and move to the next candidate. A recorded failure is a valid outcome; a silent stall is not.

### Task 1: Pin and build the hello program on Unikraft

Install Unikraft's `kraft` CLI for the current user and pin its version and the Unikraft core version it uses; record both in `verification/unikernel-pins.txt` with the exact install commands.

Emit C for the hello program: `bend scripts/runtime-profile/Hello.bend -o ../writ-unikernel/hello/hello.c` (or the `scripts/unikernel/` path per the constraints). Create a Unikraft application directory under `../writ-unikernel/hello-unikraft/` that compiles that single C file as the application against musl, selecting the `posix-mmap`, `posix-process`, `posix-fdtab`, and `posix-sysinfo` libraries if the pinned Unikraft offers them, and no networking or filesystem library. Attempt two targets: `linuxu/x86_64` and `qemu/x86_64`.

For each target record in `verification/unikernel-matrix-unikraft.md`: the build command, whether the link succeeded, the first undefined symbol or error if it failed, and, if it linked, the run command and the output. For `linuxu`, run with the runtime options `+RTS --threads 1 --gpu off` passed as program arguments and record the full output. For `qemu`, run under `qemu-system-x86_64 -accel tcg -nographic` with serial to stdout and record the output.

Acceptance: the pins file and the matrix file exist; each target has a recorded outcome (success with output, or failure with the first error). A failure is acceptable; an unrecorded attempt is not.

### Task 2: Fill the runtime rows for Unikraft

Using the Task 1 build, establish each row of the matrix by execution, not by reading headers. Create small Bend programs under `scripts/unikernel/` only where a row cannot be observed from Hello:

- Memory: does the runtime's reservation succeed at startup? If `mmap` with `MAP_NORESERVE` fails, record the runtime's exact message. Try the `+RTS --gpu off` default span and, if it fails, note whether a smaller span can be requested (read the runtime's usage text in the emitted C for the option) and whether that works.
- Threads: run Hello with `--threads 1` and with `--threads 2`; record whether the second starts.
- Faults: create `scripts/unikernel/Overflow.bend` (non-tail recursion deep enough to overflow the evaluation stack) and record what happens on `linuxu` and on `qemu`: the runtime's message, a kernel trap message, a hang, or a silent exit. State which of the three outcomes the runtime profile permits (halt with a recorded code) was observed.
- Clock: create `scripts/unikernel/Clock.bend` that prints `IO.now()` twice around `IO.sleep(100)` and record whether the second reading is greater.
- Event loop: Hello already exercises the self-pipe at startup; record whether startup reaches the first print.
- Process: record what `getenv("BENDRTS")` and `exit` do (exit status visible to the harness on `linuxu`; on `qemu`, whether the image halts or hangs after `main` returns).

Write the filled matrix, one row per inventory item with `supplied`, `substituted`, or `missing` and the evidence line for each, into `verification/unikernel-matrix-unikraft.md`. If the Task 1 build did not link, fill what the link errors establish and mark the rest `not reached`.

Acceptance: every row has a value and an evidence line, or `not reached` with the reason.

### Task 3: Repeat for OSv, then write the selection

Install OSv's `capstan` (or build OSv from source if `capstan` is unavailable) under `../writ-unikernel/` for the current user; pin and record versions in `verification/unikernel-pins.txt`. Build and run the hello program under OSv's QEMU target. OSv runs Linux ELF executables, so this is a native-link attempt only if OSv's build can take the C source directly; if it cannot, record that OSv on this program is compat-mode and keep its matrix as a compat observation. Fill `verification/unikernel-matrix-osv.md` the same way as Task 2, within the time-box.

Then append to `docs/UNIKERNELS.md` a section "Selection matrix, 2026-11" with one table combining both candidates, the chosen kernel for the native-link lane with reasons that cite specific cells, and what the next task (effect twins) would need from it. If neither candidate linked, say so and name the single most likely blocker for each.

Check the boxes 1.1 and 1.2 in the change's `tasks.md` only if the matrix is complete for two candidates; check 1.3 only if `linuxu` ran. Leave the rest unchecked.

Acceptance: both matrix files exist; `docs/UNIKERNELS.md` has the selection section; pins recorded; `tasks.md` boxes match the evidence.
