### Task 1: Pin and build the hello program on Unikraft

Install Unikraft's `kraft` CLI for the current user and pin its version and the Unikraft core version it uses; record both in `verification/unikernel-pins.txt` with the exact install commands.

Emit C for the hello program: `bend scripts/runtime-profile/Hello.bend -o ../writ-unikernel/hello/hello.c` (or the `scripts/unikernel/` path per the constraints). Create a Unikraft application directory under `../writ-unikernel/hello-unikraft/` that compiles that single C file as the application against musl, selecting the `posix-mmap`, `posix-process`, `posix-fdtab`, and `posix-sysinfo` libraries if the pinned Unikraft offers them, and no networking or filesystem library. Attempt two targets: `linuxu/x86_64` and `qemu/x86_64`.

For each target record in `verification/unikernel-matrix-unikraft.md`: the build command, whether the link succeeded, the first undefined symbol or error if it failed, and, if it linked, the run command and the output. For `linuxu`, run with the runtime options `+RTS --threads 1 --gpu off` passed as program arguments and record the full output. For `qemu`, run under `qemu-system-x86_64 -accel tcg -nographic` with serial to stdout and record the output.

Acceptance: the pins file and the matrix file exist; each target has a recorded outcome (success with output, or failure with the first error). A failure is acceptable; an unrecorded attempt is not.

