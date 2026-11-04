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

