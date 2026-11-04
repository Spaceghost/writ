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

