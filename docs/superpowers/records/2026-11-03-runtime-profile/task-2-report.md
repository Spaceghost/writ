# Task 2 report: monitor allowlists and binary check

Status: DONE_WITH_CONCERNS

Commits (branch lane/runtime-profile, not pushed):
- a49e0ac Extract _exit and raise in the runtime inventory and refresh its evidence
- 68aebc5 Add monitor profile allowlists and a binary check for monitor builds

## Inventory refresh (controller ruling)
- `inventory.sh`: `_exit` and `raise` added to HOST_CALLS (areas: process, faults); `bend` is now run
  as `bend "$SRC" -o "$C_FILE"` (the `$EMIT` string is kept only for the evidence echo); a
  `command -v bend` check exits 2 with the pinned-toolchain PATH hint (verified with PATH=/usr/bin:/bin).
  shellcheck clean (one intentional SC2016 disable for the literal hint).
- Re-run: evidence diff is exactly the pattern line plus `_exit process` and `raise faults`. Committed.

## Allowlists
- `scripts/runtime-profile/monitor-symbols.txt`: exact names, `#` comment per group. Inventory groups
  (memory, faults incl. raise, threads incl. pthread_detach, clock, event loop, process incl. _exit and
  `__sched_cpucount`, cgroup quota fopen/fscanf/`__isoc23_fscanf`/fclose, allocation/text), then
  nm-observed groups not in the inventory (C startup/toolchain hooks, stdio, memory/string helpers incl.
  `__isoc23_strtol`). Atomics omitted with a comment (compiled to instructions, not imports). Denied:
  device group (cu*, nvrtc*, open, MTL*) with rationale; sockets/files/spawn/audio/windowing by omission.
  fopen/fscanf/fclose kept per ruling.
- `scripts/runtime-profile/monitor-effects.txt`: IO.print, IO.print_err, IO.now, IO.sleep. Exit path
  documented as loop-handled (Exit/Halt via `c == CID_...`), no row. Denied groups with reasons per
  RH-002 (TCP/UDP/Listener/Socket, File, Process.run, Audio, Window; GPU via symbols), plus
  denied-by-omission list (IO.args, IO.get_env, IO.write, IO.random_u32, IO.thread_count, IO.spawn,
  Chan.*, foreign imports).

## check-binary.sh — deviation from the brief (documented in header)
The brief's `nm | grep -oE 'io_[a-z_]+_use$'` finds nothing in a real build: `bend -o` compiles at -O2
and clang evaluates the `io_<name>_use` constructor at compile time and drops it (`.init_array` holds
only frame_dummy). Confirmed: compiling hello.c at -O0 keeps `io_print_use`; -O2 removes it. The
external `<prefix>_run` function survives as a global `T` symbol. The script takes every global
`T <prefix>_run` plus any `<prefix>_use` and maps: split at first `_`; ns io/tcp/udp -> upper case,
otherwise capitalize first letter; effect = NS.rest. Validated against all 57 `io_eff(CID(...), x_run)`
registrations in the toolchain's Base effs (57/57). Static `cube_run`/`gpu_run` are excluded (not T).
Fails closed (exit 2): wrong usage, missing file, no `(NEEDED)` dynamic section (static binary),
missing `io_runs` effect-table symbol (stripped / not Bend). Exit 1 prints offending effects and symbols.

## Runs
Evidence: `verification/runtime-profile-binary-check.txt` (commands, version, clang 23.1.1, glibc 2.44,
hashes, verbatim output).
- Hello: 58 imports, effects `IO.print`, PASS, exit 0.
- Widened (`l : Result<...Listener> <- TCP.listen("127.0.0.1", 0)` then IO.print): FAIL, exit 1;
  effect `TCP.listen`; symbols bind, close, inet_pton, listen, setsockopt, socket, strerror.
Extra probes (throwaway, in ../writ-build/runtime-profile/probe/, not committed):
- IO.now + IO.sleep + IO.print_err + IO.print + IO.die (RH-002 pass scenario): PASS, exit 0, no extra imports.
- File.open probe (RH-003 widening scenario): FAIL on `File.open`, `open`, `strerror`.
- stripped Hello: exit 2; `clang -static` Hello: exit 2; -O0 Hello (uses `_use` path): PASS.

Other checks: `bend Tests.bend` rc 0, 638 `^PASS` lines, ALL LIBRARY TESTS PASSED; `bend PROOF.bend`
rc 0 ALL PROOFS CHECK (no --verdict); `openspec validate --all --strict --no-interactive` 42/42.
Both shell scripts shellcheck clean. No existing .bend file modified (only new Widened.bend).

## Doc
`docs/BEND-RUNTIME.md`: paragraph on constructor elimination at -O2 and `_run` symbols; paragraph
naming the allowlists, check, exit codes, evidence, and that a pass alone does not qualify a host.
tasks.md not touched (plan assigns box-checking to Task 3; 1.2 and 1.3 evidence is now committed).

## Concerns
1. The effect check depends on `<prefix>_run` being a global symbol and on the naming convention; a
   future Bend that makes it static or renames it would make rows invisible. Mitigated only partly by
   the `io_runs` guard; re-validate per Bend version (the 57/57 mapping check is a one-liner in this report's
   history, not a committed script).
2. The symbol allowlist is glibc/Linux x86-64 specific (`__isoc23_*`, `__sched_cpucount`, `_ITM_*`).
3. fopen is allowed for the cgroup read, so a foreign C import calling fopen would pass the symbol
   check; it would still fail the effect check as an unlisted row.
4. (Superseded by the fix below.) Static binaries were refused.
5. verification/source-sha256.txt still stale (Task 1 concern 2), not regenerated.

## Fix pass (coordinator review) — commit 1afb90a

What changed:
1. Important: `check-binary.sh` no longer refuses static binaries. With no `(NEEDED)` entries it sets
   LINK=static, prints `undefined symbols: not applicable (static link)`, skips the symbol comparison,
   still requires `io_runs` (stripped stays exit 2), still runs the effect-row check (exit 1 on a denied
   effect), and a pass prints `result: PASS (effect rows within the monitor profile; static link, so the
   host-symbol surface was not checked)`. Header and the docs/BEND-RUNTIME.md sentence updated. Header also
   notes glibc's own symbols in a static table: `_dlerror_run` (starts with `_`) is the only `_run` name in
   static Hello, and it is excluded by the lower-case-start match; a collision would be denied, not admitted.
2. Header sentence: `_run` detection and the mapping depend on Bend 2.0.39's emitted C and how `bend -o`
   compiles it; re-validate on any toolchain change.
3. `monitor-symbols.txt`: inline `# glibc-only` tags on `__sched_cpucount` (observed glibc 2.44) and both
   `__isoc23_*` entries (glibc 2.38 and later; observed 2.44). The parser already strips `#...`.

Commands (repo root, pinned PATH, BEND_NO_TELEMETRY=1):
  clang -std=c11 -O2 -static ../writ-build/runtime-profile/hello.c -o ../writ-build/runtime-profile/hello-static -lpthread -lm
  sh scripts/runtime-profile/check-binary.sh ../writ-build/runtime-profile/{hello,widened,hello-static}
Evidence regenerated: verification/runtime-profile-binary-check.txt now has three sections (dynamic Hello,
dynamic Widened, static Hello) with commands, hashes, and exit statuses.

Output:
- hello: 58 imports, effects IO.print, PASS, exit 0.
- widened: FAIL, exit 1; effect TCP.listen; symbols bind close inet_pton listen setsockopt socket strerror.
- hello-static: `undefined symbols: not applicable (static link)`, effects IO.print, PASS (effect rows only), exit 0.
Extra probes (not committed): static Widened FAIL exit 1 on TCP.listen; stripped static Hello exit 2.
shellcheck clean. No .bend change, so Tests/PROOF not re-run after this pass (passed at 68aebc5).
