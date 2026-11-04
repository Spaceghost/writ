### Task 2: The generated C as a component

Emit C: `bend scripts/runtime-profile/Hello.bend -o ../writ-genode/hello/hello.c` (or the `scripts/genode/` path per the constraints). Create component `src/app/writ_bend_hello/` in the Genode repository whose `target.mk` compiles that generated C file with Genode's `libc` (and `posix` if the 26.08 libc requires it for `main`) and links it. Expect to need `vfs` and `libc` configuration in the run script for stdout; use the 26.08 libc documentation and existing libc run scripts in the tree as the pattern. Pass `+RTS --threads 1 --gpu off` through the libc `<arg>` configuration if the runtime's argument parsing needs it.

Build it. For every compile or link error, record the symbol or header, what in Genode's libc was missing or different, and what you changed in the build configuration (never in the generated C or in Bend source) to get past it. If a change to the generated C would be required, stop at that point, record the exact symbol and the reason, and report DONE_WITH_CONCERNS: the design forbids editing the evaluator and that fact needs to reach the controller.

Run it under `init` on `base-linux`. Record the log, including the `hi` line if it appears, in `verification/genode-bend-hello-base-linux.txt`. Copy the authored `target.mk` and run script into `scripts/genode/writ_bend_hello/`.

Acceptance: evidence file shows either the `hi` line or the exact first blocking error with its analysis; authored build files are in `scripts/genode/`.

