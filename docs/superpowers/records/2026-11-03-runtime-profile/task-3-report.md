# Task 3 report: single-lane parity and fail-stop evidence

Status: DONE_WITH_CONCERNS (minor; see Concerns)

Commits (branch lane/runtime-profile, not pushed):
- 28a10fe Record one-lane and four-lane native parity for the corpus and examples
- 9e2e028 Add a stack overflow probe and record the runtime's fail-stop on it
- b307583 Record reservation fail-stop, document lane parity and fail-stop, and check tasks 1.1 to 2.2

## Parity (RH-005), verification/runtime-profile-parity.txt
- `bend Tests.bend -o ../writ-build/runtime-profile/tests-native` (rc 0, about 64 s), sha256 a98cf24e...
- `tests-native +RTS --threads 1 --gpu off` and `--threads 4 --gpu off`: rc 0, stderr empty.
- `grep -cE '^PASS[: ]'`: 638 and 638. `diff` of the two captures: empty. Both are also byte-identical
  to verification/tests-native.txt. Final line of both: `ALL LIBRARY TESTS PASSED`.
- Added, because box 2.1 names the four examples too: Flow, Transfer, Commit, Parallel built natively and run
  at 1 and 4 threads (captures verification/runtime-profile-parity-examples-{1,4}.txt): 29 PASS lines each,
  4/4 exit 0, empty diff, matching verification/examples-native.txt (header and Total line aside).
- All CPU, `--gpu off`; the file says it is not GPU evidence.

## Stack overflow (RH-006), scripts/runtime-profile/Overflow.bend, verification/runtime-profile-fault.txt
- `climb(1n+p) = 1n+climb(p)` (not a tail call); depth given by a named `overflow_depth()` = 1000000000n.
  `--check-only` gives ALL PROOFS CHECK (it is a total, structural definition; nothing unsafe).
- Attempts, native, `--threads 1 --gpu off`, each built from Overflow.bend with only the depth literal changed:
  10^6 (prints count, rc 0, 0.007 s), 10^7 (rc 0, 0.03 s), 10^8 (rc 0, 0.54 s), 10^9: stderr
  `bend: memory fault (machine stack overflow?)`, stdout empty, exit status 139 (SIGSEGV re-raised by err_trap
  under SIG_DFL), 7.5 s (18 s on an earlier try).
- gdb: si_addr 0x7ffff79ee000 is the first byte of the 16 KiB `---p` guard directly above the 2 GiB rw
  stack, faulting in WL_FID_climb; so it is the evaluation-stack guard, not some other bad access.
- Aside, also recorded: `bend Overflow-1000000.bend` (run without building a binary) already faults at 10^6,
  exit status 1, with the same message.

## Reservation failure, verification/runtime-profile-reservation.txt
- Task 2 Hello (sha256 6d744943..., the same as the binary-check record), `( ulimit -v N; hello +RTS --threads 1 --gpu off )`:
  64 MiB, 8 GiB, 10 GiB -> `bend: reservation failed`, stdout empty, exit 1. 11 GiB and unlimited -> `hi`, exit 0
  (the controls).
- MAP_NORESERVE does not escape RLIMIT_AS. gdb at err_fail: at 8 GiB no corpus mapping exists (the 8 GiB corpus
  reservation failed); at 10 GiB the corpus at 0x200000000 is mapped, so the failing call is pool_stack's
  2 GiB stack reservation (the only other pool_mmap caller). Both paths fire the runtime's own message.

## Docs and tasks
- docs/BEND-RUNTIME.md: a paragraph linking the three records and stating that they cover one host.
- tasks.md: 1.1, 1.2, 1.3, 2.1, 2.2 checked, each naming its committed evidence file(s); 2.3, 3.1, 3.2 left
  unchecked. Intro line "All tasks remain pending" changed to say checked items name evidence, and that the
  evidence is CPU on one Linux host and qualifies no host.

## Checks (after the last change)
- `bend Tests.bend`: rc 0, 638 PASS lines, ALL LIBRARY TESTS PASSED.
- `bend PROOF.bend`: rc 0, ALL PROOFS CHECK (no --verdict).
- `openspec validate --all --strict --no-interactive`: 42 passed, 0 failed.
- No existing .bend file changed; the only new .bend file is Overflow.bend. Nothing generated is committed.

## Concerns
1. The overflow run dumped a 10 GiB core file (core.3612650) into the repo root because I ran it from there.
   I deleted it before committing; it was never staged. Anyone rerunning this should run it with `ulimit -c 0`
   or from ../writ-build. Separately, ../writ-unikernel/gen/core.3496221 exists. It is not from this task (another
   lane's directory, and an earlier PID), so I left it alone.
2. My first probe builds went by mistake to /mnt/.../spaceghost/writ-build (resolved from the wrong cwd). I moved
   them into ../writ-build/runtime-profile/overflow and removed the stray directory; the committed evidence was
   regenerated from the correct paths.
3. The overflow depth and the reservation thresholds depend on Bend 2.0.39's 8 GiB corpus and 2 GiB stack sizes;
   redo them for any other version. RH-006's "host swallows the fault" scenario is not tested.
4. verification/source-sha256.txt is still stale (carried over from Tasks 1 and 2), and I did not regenerate it.

## Fix pass (coordinator review)
I did not re-run the native suite; the committed captures stand.
1. Important: `verification/runtime-profile-parity.txt` now shows each count as its command followed by its output,
   run against the committed captures: `grep -cE '^PASS[: ]'` gives 638 for each corpus capture, and the
   split forms `grep -c '^PASS:'` 585 plus `grep -c '^PASS '` 53 are shown too. The examples give 29 each
   (they print only "PASS ").
2. `verification/runtime-profile-fault.txt`: says the original runs did not set `ulimit -c 0` and left a
   10 GiB core, which I deleted before committing. It gives the subshell form
   `( ulimit -c 0; ... )`. I verified that form once: status 139, same message, no core file.
3. `verification/runtime-profile-reservation.txt`, 8 GiB case: I re-ran gdb with `ulimit -c 0` and saved the full
   output. The file now quotes `grep -c '^ *0x0000200000000000 '`, which gives 0, and lists every anonymous rw-p
   mapping (none is 8 GiB). It also notes that the 10 to 11 GiB threshold was bracketed, not bisected.
