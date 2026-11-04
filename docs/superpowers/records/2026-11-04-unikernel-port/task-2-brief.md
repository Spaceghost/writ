### Task 2: Halt versus reset after a crash

Run `Overflow.bend` without `-no-reboot` under a 60 s timeout, with serial captured. Record whether the guest halts (no further output), resets and re-runs the program (the banner or the probe's output appears again), or exits through the Task 1 hook. If it resets, state in the evidence and in `docs/UNIKERNELS.md` that `-no-reboot` is mandatory for every Writ image until a halting crash hook exists, and whether the Task 1 crash hook changes that. Evidence: `verification/unikernel-crash-action.txt`.

Acceptance: the platform action after a crash is observed, not inferred, and the harness requirement is stated accordingly.

