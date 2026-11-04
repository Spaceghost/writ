### Task 2: Monitor profile allowlists and the binary check

Create `scripts/runtime-profile/monitor-symbols.txt`: one undefined-symbol name per line that a monitor binary may import. Derive it from Task 1's inventory minus the GPU group (`cu*`, `nvrtc*`, `fopen`, `fscanf`, `fclose`) and plus the libc symbols a static link needs that the inventory did not name (determine these empirically from `nm -u` of a dynamic build of Hello). Document each group with a `#` comment line.

Create `scripts/runtime-profile/monitor-effects.txt`: effect names a monitor may link: `IO.print`, `IO.print_err`, `IO.now`, `IO.sleep`, and the exit path. One per line, `#` comments allowed.

Create `scripts/runtime-profile/check-binary.sh BINARY`:

1. For a dynamically linked `BINARY`, lists undefined symbols with `nm -u` (strip version suffixes after `@`) and reports every name not in `monitor-symbols.txt`.
2. Lists effect rows by running `nm BINARY | grep -oE 'io_[a-z_]+_use$'` and mapping each `io_<name>_use` constructor to its effect; reports every effect not in `monitor-effects.txt`. If the constructor naming differs in the emitted C, inspect `hello.c` from Task 1 and adapt; document the mapping rule in the script header.
3. Exits 0 when both lists are empty, 1 otherwise, printing the offending names.

Demonstrate: build Hello dynamically to `../writ-build/runtime-profile/hello` and show `check-binary.sh` exits 0. Create `scripts/runtime-profile/Widened.bend`, identical to Hello but with a `TCP.listen("127.0.0.1", 0)` bound inside the IO block (look up the exact signature with `bend base TCP`), build it, and show `check-binary.sh` exits 1 naming the socket effect and any socket symbols. Capture both runs verbatim into `verification/runtime-profile-binary-check.txt`.

Acceptance: both allowlists exist with comments; the script exits 0 on Hello and 1 on Widened; the evidence file shows both.

