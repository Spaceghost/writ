### Task 3: The corpus and examples as single-lane images

Build `Tests.bend`, `Example.bend`, `examples/Flow.bend`, `examples/Transfer.bend`, and `GpuExample.bend` as Unikraft images with the Task 1 hook, single lane (`UKPLAT_CPU_MAXCOUNT=1`, `+RTS --threads 1 --gpu off` via `-append`), and enough guest RAM for the runtime's reservations plus the corpus (start at `-m 4096`; record the first size that works). Capture each serial console and compare line for line with the Linux single-lane records (`verification/runtime-profile-parity-1.txt` for the corpus; `verification/runtime-profile-parity-examples-1.txt` or the examples captures the runtime-profile lane stored). Record QEMU exit codes. Evidence: `verification/unikernel-corpus-qemu.txt` with the diff output (expected empty apart from any banner lines the harness strips; say exactly what was stripped).

If the corpus does not fit or hangs, bisect once between the hello image and the corpus (for example `examples/Flow.bend` first) and record where it stops.

Acceptance: the corpus prints 764 PASS lines and `ALL LIBRARY TESTS PASSED` on the console with QEMU exit 1 (status 0 via the hook), and the four examples print their recorded assertion lines; or a recorded stopping point.

