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
