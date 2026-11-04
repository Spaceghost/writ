### Task 3: Single-lane parity and fail-stop evidence

Build the test suite natively: `bend Tests.bend -o ../writ-build/runtime-profile/tests-native`. Run it twice:

```
../writ-build/runtime-profile/tests-native +RTS --threads 1 --gpu off
../writ-build/runtime-profile/tests-native +RTS --threads 4 --gpu off
```

Capture each run to `verification/runtime-profile-parity-1.txt` and `verification/runtime-profile-parity-4.txt`. Produce `verification/runtime-profile-parity.txt` containing: the two commands, the count of lines beginning `PASS` in each (expect 638 in both), the output of `diff` between the two captures (expect empty), and the final line of each (expect `ALL LIBRARY TESTS PASSED`). If the counts or diff are not as expected, record exactly what you observed and report DONE_WITH_CONCERNS; do not edit library source.

Fail-stop: create `scripts/runtime-profile/Overflow.bend` whose `main` calls a non-tail recursive function on a large `Nat` deep enough to exceed the evaluation stack (start with a depth that recurses one million times and increase until it faults; keep it under one minute). Build natively, run with `--threads 1 --gpu off`, and capture the runtime's fault message and exit status to `verification/runtime-profile-fault.txt`. Then run the Hello binary with a tiny address-space limit so the reservation fails (`ulimit -v 65536` in a subshell, or document why that does not trigger it and find another way the runtime's own `reservation failed` path fires) and capture the message and status to `verification/runtime-profile-reservation.txt`.

Check boxes 1.1, 1.2, 1.3, 2.1, and 2.2 in the change's `tasks.md` only for items whose evidence file you committed. Leave 2.3, 3.1, and 3.2 unchecked.

Acceptance: parity file shows 638 and 638 with an empty diff; fault file shows a nonzero exit and the runtime's own message; reservation file shows the runtime's own message or an explanation of what was tried; `tasks.md` boxes match the evidence.
