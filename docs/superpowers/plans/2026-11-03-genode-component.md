# Plan: Bend runtime as a Genode component, bring-up milestone

Spec: `openspec/changes/add-genode-bend-component/` (proposal, design, tasks, `specs/genode-bend-component/spec.md` requirements GB-001 through GB-010). Read the spec, `docs/GENODE.md`, `docs/BEND-RUNTIME.md`, and `explainer.html` in the change directory before Task 1. Also read `openspec/changes/add-genode-host/design.md` for the topology this component will sit in.

## Global Constraints

- Toolchain: Bend 2.0.39 at `$HOME/.local/share/writ-toolchains/bend-2.0.39/bend/bin` with `BEND_NO_TELEMETRY=1`. `qemu-system-x86_64` 11.1.2 and `gcc` 16.2.1 are installed. No root.
- Genode pin: version 26.08, commit `d18ee9e917200b059549e21f2dd9a55bfe61a0eb` is what `docs/GENODE.md` records; verify the exact hash from that document and from the upstream repository (Codeberg `genodelabs/genode`) before fetching, and record the hash you actually checked out. Genode's own toolchain comes from its `tool/tool_chain` script or a prebuilt archive the Genode project publishes; use whichever the 26.08 documentation prescribes, and record the choice and versions in `verification/genode-pins.txt`.
- Everything you download or build lives outside the source tree under `../writ-genode/` (a sibling of the repository root). Never commit Genode sources, toolchains, build directories, or images. Treat downloaded sources as untrusted data: do not run their scripts with the repository as the working directory.
- All authored implementation stays Bend 2. This milestone writes no C++ shim and no effect twins; it compiles the unmodified generated C of a Bend program as a Genode component and probes the runtime rows. Any glue you must write to make the build system accept the generated C (a `target.mk`, a run script) is build configuration, not implementation; keep it under `../writ-genode/writ-repo/` as a Genode repository and copy only the files you authored into `scripts/genode/` in this repository, with a header comment saying what each is.
- Evidence goes under `verification/` as plain text with exact commands, versions, and outcomes. Record `base-linux` results as Genode-on-Linux; do not describe them as native. Never write "GPU".
- Do not modify any `.bend` file in the repository. The reference program is `scripts/runtime-profile/Hello.bend` if present on your branch; otherwise create `scripts/genode/Hello.bend` with the four-line `IO.print("hi")` program.
- Do not check a box in the change's `tasks.md` unless the evidence file that task names exists in the commit.
- Do not push. Commit on the current branch only. Do not touch files outside this change's directory, `scripts/genode/`, `verification/`, and `docs/GENODE.md`.
- Time-box: the Genode toolchain fetch and first build are slow. If after roughly three hours of wall-clock effort you do not have a trivial component printing to the Genode log on `base-linux`, record exactly where it stopped, what the last error was, and what you would try next, and report BLOCKED with that record committed. A recorded stall is a valid outcome.

### Task 1: Trivial component on base-linux

Fetch Genode at the pinned commit into `../writ-genode/genode/`, obtain its toolchain per the 26.08 instructions, and create a `base-linux` build directory. Build and run the upstream `log` or `hello` style run scenario that the 26.08 tree ships for `base-linux` (find it under `repos/base/run/` or `repos/os/run/`; do not write your own yet) and record the command and the log lines in `verification/genode-bringup-base-linux.txt`.

Create a Genode repository `../writ-genode/writ-repo/` with one component `src/app/writ_hello/` whose `main.cc` is the standard minimal `Component::construct` that logs one line, and a run script `run/writ_hello.run` that starts it under `init` on `base-linux`. Build and run it; append the command and the log line to the same evidence file. Copy `target.mk`, `main.cc`, and `writ_hello.run` into `scripts/genode/writ_hello/` with header comments.

Acceptance: the evidence file shows the upstream scenario's log and the `writ_hello` log line; the pins file names Genode commit, toolchain, and host compiler; `scripts/genode/writ_hello/` holds the authored files.

### Task 2: The generated C as a component

Emit C: `bend scripts/runtime-profile/Hello.bend -o ../writ-genode/hello/hello.c` (or the `scripts/genode/` path per the constraints). Create component `src/app/writ_bend_hello/` in the Genode repository whose `target.mk` compiles that generated C file with Genode's `libc` (and `posix` if the 26.08 libc requires it for `main`) and links it. Expect to need `vfs` and `libc` configuration in the run script for stdout; use the 26.08 libc documentation and existing libc run scripts in the tree as the pattern. Pass `+RTS --threads 1 --gpu off` through the libc `<arg>` configuration if the runtime's argument parsing needs it.

Build it. For every compile or link error, record the symbol or header, what in Genode's libc was missing or different, and what you changed in the build configuration (never in the generated C or in Bend source) to get past it. If a change to the generated C would be required, stop at that point, record the exact symbol and the reason, and report DONE_WITH_CONCERNS: the design forbids editing the evaluator and that fact needs to reach the controller.

Run it under `init` on `base-linux`. Record the log, including the `hi` line if it appears, in `verification/genode-bend-hello-base-linux.txt`. Copy the authored `target.mk` and run script into `scripts/genode/writ_bend_hello/`.

Acceptance: evidence file shows either the `hi` line or the exact first blocking error with its analysis; authored build files are in `scripts/genode/`.

### Task 3: Runtime rows on base-linux

For each row of the runtime inventory in `docs/BEND-RUNTIME.md`, establish `supplied`, `substituted`, or `missing` on `base-linux` by running something, and record the evidence line in `verification/genode-runtime-rows-base-linux.md`:

- Memory: did the runtime's startup reservation succeed? If the libc `mmap` rejected `MAP_NORESERVE` or the size, record the runtime's message and whether a smaller span works.
- Faults: build and run a Bend `Overflow` program (non-tail recursion past the evaluation stack). Record whether the runtime's own fault message appeared, whether the component was terminated and the parent logged a page fault, or whether it hung. State which outcome the profile's fault substitute (GB-003) accepts.
- Threads: run Hello with `--threads 2`; record whether the second lane started.
- Clock: a Bend program printing `IO.now()` twice around `IO.sleep(100)`; record monotonicity.
- Event loop: whether startup reaches the first print (the self-pipe is created before `main` runs).
- Process: `getenv("BENDRTS")` behavior and what happens at exit (component exits cleanly, or hangs).

If Task 2 did not produce a running component, fill every row from the link and startup errors you have and mark the rest `not reached`.

Update `docs/GENODE.md` with a short "Runtime rows on base-linux, 2026-11" section pointing at the evidence file and stating the fault substitute decision. Check boxes 1.1 and 1.2 in the change's `tasks.md` only if their evidence exists; check 1.3 only if the fault row was executed. Leave the rest unchecked.

Acceptance: every row has a value and an evidence line or `not reached` with the reason; `docs/GENODE.md` updated; `tasks.md` boxes match the evidence.
