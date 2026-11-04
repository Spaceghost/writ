# Plan: Bend runtime host profile, first milestone

Spec: `openspec/changes/add-bend-runtime-host-profile/` (proposal, design, tasks, `specs/bend-runtime-host-profile/spec.md`). Read the spec's RH-001 through RH-008 before Task 1. Reading page: `openspec/changes/add-bend-runtime-host-profile/explainer.html`. Runtime surface already inspected: `docs/BEND-RUNTIME.md`.

## Global Constraints

- Toolchain: Bend 2.0.39 at `$HOME/.local/share/writ-toolchains/bend-2.0.39/bend/bin` with `BEND_NO_TELEMETRY=1`. Native builds use `clang` (23.1.1 on this machine).
- All authored implementation stays Bend 2. Shell scripts for build tooling are permitted because OpenSpec and the install guide already use shell; keep them POSIX `sh` where possible and put them under `scripts/runtime-profile/`. The root `.gitignore` ignores `/tools/`, so do not use a `tools/` directory.
- Generated C, JavaScript, and binaries go outside the source tree in `../writ-build/` (sibling of the repository root). Never commit them.
- Do not modify any existing `.bend` file. A new reference program `scripts/runtime-profile/Hello.bend` is the only new Bend source.
- Evidence files go under `verification/` as plain text with the exact command, the Bend version, the lane count, and `--gpu off`. A CPU fallback is recorded as CPU. Never write "GPU" for a `--gpu off` run.
- Do not check a box in `openspec/changes/add-bend-runtime-host-profile/tasks.md` unless the evidence file named by that task exists in the commit.
- Do not push. Commit on the current branch only. Do not touch files outside this change's directory, `scripts/runtime-profile/`, `verification/`, and `docs/BEND-RUNTIME.md`.
- Run `bend Tests.bend` and `bend PROOF.bend` once before your final commit and record that they still pass (they should; you changed no library source).

### Task 1: Inventory command and reconciled inspection

Create `scripts/runtime-profile/Hello.bend`:

```python
import Base

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print("hi")
```

Create `scripts/runtime-profile/inventory.sh` that, from the repository root:

1. Emits C with `bend scripts/runtime-profile/Hello.bend -o ../writ-build/runtime-profile/hello.c`.
2. Extracts, sorted and unique, every host call of the form `name(` matching this list: `pthread_[a-z_]+`, `mmap`, `munmap`, `mprotect`, `sigaltstack`, `sigaction`, `signal`, `clock_gettime`, `nanosleep`, `sched_yield`, `sched_getaffinity`, `pipe`, `fcntl`, `select`, `read`, `write`, `open`, `fopen`, `fscanf`, `fclose`, `getenv`, `exit`, `sysconf`, `malloc`, `calloc`, `realloc`, `free`, `strdup`, `snprintf`, `atomic_[a-z_]+`, `__atomic_[a-z_]+`, `cu[A-Z][A-Za-z]+`, `nvrtc[A-Z][A-Za-z]+`.
3. Extracts every effect registration of the form `io_eff(CID_<Name>, ...)` and lists the `<Name>` values.
4. Writes both lists, with a header naming the Bend version from `bend version` and the date, to `verification/runtime-inventory-bend-2.0.39.txt`.

Run it. Compare the result with the table in `docs/BEND-RUNTIME.md`. Where the doc is wrong or incomplete, correct the doc; where the doc lists something the extraction missed, extend the extraction. Commit the script, the Bend file, the evidence file, and any doc correction.

Acceptance: the evidence file exists, names the version, lists at least the calls in the doc's table, and lists exactly the effect rows the hello program registers (expect `IO.print` and the exit path; report what you actually see).

### Task 2: Monitor profile allowlists and the binary check

Create `scripts/runtime-profile/monitor-symbols.txt`: one undefined-symbol name per line that a monitor binary may import. Derive it from Task 1's inventory minus the GPU group (`cu*`, `nvrtc*`, `fopen`, `fscanf`, `fclose`) and plus the libc symbols a static link needs that the inventory did not name (determine these empirically from `nm -u` of a dynamic build of Hello). Document each group with a `#` comment line.

Create `scripts/runtime-profile/monitor-effects.txt`: effect names a monitor may link: `IO.print`, `IO.print_err`, `IO.now`, `IO.sleep`, and the exit path. One per line, `#` comments allowed.

Create `scripts/runtime-profile/check-binary.sh BINARY`:

1. For a dynamically linked `BINARY`, lists undefined symbols with `nm -u` (strip version suffixes after `@`) and reports every name not in `monitor-symbols.txt`.
2. Lists effect rows by running `nm BINARY | grep -oE 'io_[a-z_]+_use$'` and mapping each `io_<name>_use` constructor to its effect; reports every effect not in `monitor-effects.txt`. If the constructor naming differs in the emitted C, inspect `hello.c` from Task 1 and adapt; document the mapping rule in the script header.
3. Exits 0 when both lists are empty, 1 otherwise, printing the offending names.

Demonstrate: build Hello dynamically to `../writ-build/runtime-profile/hello` and show `check-binary.sh` exits 0. Create `scripts/runtime-profile/Widened.bend`, identical to Hello but with a `TCP.listen("127.0.0.1", 0)` bound inside the IO block (look up the exact signature with `bend base TCP`), build it, and show `check-binary.sh` exits 1 naming the socket effect and any socket symbols. Capture both runs verbatim into `verification/runtime-profile-binary-check.txt`.

Acceptance: both allowlists exist with comments; the script exits 0 on Hello and 1 on Widened; the evidence file shows both.

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
