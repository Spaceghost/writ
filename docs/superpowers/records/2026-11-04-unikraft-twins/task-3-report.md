# Task 3 report: the fault message and distinct exit codes

Status: DONE_WITH_CONCERNS. Commits: f14b626 (map, fault trial, arena exhaustion, docs) and
the corpus/examples rerun commit. Evidence: verification/unikernel-fault-qemu.txt (corpus
and examples rerun: verification/unikernel-corpus-qemu.txt, "Task 3 rerun"). All runs are QEMU
TCG emulated boots; none is native, accelerated, or GPU evidence.

## Fault message (task 2.3)
- Source, Unikraft 0.21.0: lib/posix-process/signal/system_error.c turns a page fault
  outside the aux stack into SIGSEGV; signal/deliver.c sys_error_handler delivers it
  (crashing if masked, ignored, or SIG_DFL), and do_deliver uses the alternate stack for
  SA_ONSTACK (:112-132). So SIGSEGV can reach Bend's err_trap on its alternate stack, but
  only with CONFIG_LIBPOSIX_PROCESS_SIGNAL (experimental; the template does not set it).
- Tried once on the Overflow image (scratch set `fault`, two boots): the console shows
  `bend: memory fault (machine stack overflow?)`, then posix-process's "Cannot deliver
  SIGSEGV for pf at 0x1080069000" crash and QEMU 253 (the hook's crash value). No resume.
- The library does not compile in 0.21.0 as shipped: shutdown.c includes signal/signal.h
  before <uk/config.h>, so pprocess_signal_send is undeclared. The trial added
  `-include uk/config.h` to UK_CFLAGS (no source patched).
- Not adopted in the template (experimental library, a build flag, shutdown semantics
  change, corpus rerun): recorded for a decision. Delivered configuration: crash screen
  only, QEMU 253.

## Exit-code map
- exit_device.c: program status s (main's return or exit(s)) -> s + 0x10, q = 2s + 33
  (success 33, IO.die 35, IO.exit(3) 39), clamped at 108 (above: 0x7f, 255); status 1
  without exit() (the runtime's err_fail and host.c's writ_uk_fail, both _exit(1)) ->
  0x08, q = 17; other nonzero without exit() (signal death) -> 0x09, q = 19; non-halt
  0x7d (251) and crash 0x7e (253) unchanged. Values 0x00-0x07 and 0x0a-0x0f never
  written, so q = 1 (QEMU startup failure) is never an outcome.
- exit() is told from _exit() by an atexit function registered from an application
  constructor (musl's exit runs it, _exit does not). The status alone cannot separate
  IO.die(1) from err_fail (generated C cited in the evidence: err_fail :538-542,
  ERR_HEAP :728-731, exit :3183-3187).
- Arena exhaustion: forced with the new scripts/unikernel/Exhaust.bend at -m 1024, 4096,
  12288: always a Unikraft crash (253) in heap_alloc_miss writing a fresh arena page,
  later with more memory. The guest runs out of backing memory before the runtime's own
  bound, so err_fail ("out of memory", which would be 17) never runs. Limit recorded:
  arena exhaustion has no code of its own and shares 253 with a fault.
- Updated: exit_device.c (header, map), check-image.sh, check-corpus.sh (expects 33),
  check-channel.sh, run.sh comments, INVENTORY.md (map table, exit_device row, host.c
  stop code), docs/UNIKERNELS.md, tasks.md 2.1/2.3 notes, a dated code-map note at the top
  of every earlier evidence file that states codes (exit-codes, crash-action,
  corpus-qemu, effects-qemu, channel-qemu, matrix-unikraft), whose recorded values stay as
  recorded. UL-006's scenario states no number: spec unchanged.

## Reruns (new map)
- hello 33 PASS, die 35 PASS (first check used a reference without die's stderr line and
  failed on the diff; rechecked from the capture), exit 39 PASS, Overflow 253 (no
  message), Exhaust 253 x3.
- Channel monitor rebuilt: accepted 33 PASS, denied 33 PASS, negative FAIL (exit 1),
  cross-check == MonitorCheck (10 PASS), no-port 17 (host.c _exit(1)), probe 33 PASS,
  binary check rows log/put/take as before, split-frame request answered.
- Old corpus capture under WRIT_NO_BOOT=1 now FAILs on the code (QEMU 1, expected 33), as
  it should: that capture no longer applies.
- Corpus rebuilt once (5847 s, same tests.c): check-corpus.sh at -m 4096 and -m 32: diff
  empty, 782 PASS, last line ALL LIBRARY TESTS PASSED, QEMU 33, PASS; binary check PASS.
- Examples rebuilt: flow, transfer, example PASS (QEMU 33). gpuexample's first boot FAILED:
  after the program's output the capture held Unikraft's "PM driver failed the operation:
  -5" line (lib/ukpm/pm.c:67-69, reached after the hook's port write) with two NULs, so
  console.sh refused it; QEMU was 33. Two reruns PASS. Not seen elsewhere; cause not
  determined (recorded in the corpus evidence).
- Negative controls fail as they should (flow against transfer's reference; channel).

## Boxes
- 2.1 left unchecked: `IO.print` has no twin (the "Console effect" scenario) and the
  ingress subject is scaffolding.
- 2.3 left unchecked: the fault message appears only in the trial configuration, and
  arena exhaustion has no code distinct from a fault (UL-006).
- 2.4 and section 3 untouched.

## Carried nits
- host.c:6-7 helper list now points at INVENTORY.md.
- A partial frame no longer keeps the take twin on 1 ms parks: after 100 empty busy polls
  (about 100 ms) host.c answers IDLE (WRIT_UK_BUSY_POLLS). A split request across a 0.5 s
  pause was answered (0.098 s after its second half); the back-off itself was not traced.

## Concerns
1. UL-006 is not met in the delivered configuration: no fault message; it needs the
   experimental posix-signal library plus a compile flag (decision needed).
2. Arena exhaustion and a fault share 253; the runtime's "out of memory" path is
   unreachable before the guest's memory runs out at every size tried.
3. Runtime stops share 17 (arena exhaustion would, if it ever reached err_fail, not be
   told from other fail-stops); main returning 1 on a bad +RTS argument is also 17.
4. The signal value 19, the clamp 255, and 251 were not exercised.
5. One gpuexample boot showed the guest running on past the exit port write to
   uk_pm_shutdown's error line before QEMU exited (QEMU still 33); not reproduced in two
   reruns, cause unknown.
6. Host load (about 48) made wall times indicative only.

## Fix round 1

Status: DONE. Evidence: verification/unikernel-fault-qemu.txt, "Fix round 1".

1. (Important) exit_device.c and INVENTORY.md no longer say arena exhaustion maps to 17:
   the runtime's own out-of-memory stop would be 17 if reached, but on this kernel a forced
   exhaustion runs out of guest memory first and is a crash (253). Comment-only:
   implementation tokens compared with the previous revision (gcc -fpreprocessed -dD -E
   -P, whitespace squeezed): identical (39158e3e...). New source hash c4012e46... in the
   evidence; the images were built from 88098cb9..., the same tokens.
2. INVENTORY cites the fault and corpus evidence as well as exit-codes. Channel.md and
   unikraft_sleep.c say the leftover helper thread gave 255 when observed and maps to 19
   now (not rerun). unikraft_sleep.c is comment-only (tokens identical, c92e0284...);
   the probe's regenerated C differs from the built one in those comment lines only, so
   the probe image stands.
3. exit_device.c cites musl 1.2.3: src/exit/exit.c:27-33 (__funcs_on_exit before _Exit)
   and src/unistd/_exit.c:4-7 (_Exit only).
4. Booted Hello with "+RTS --bogus" (main returns 1) and "+RTS --threads 0" (err_fail,
   _exit(1)): both QEMU 17, each with the runtime's message on the console.
5. tasks.md 2.3: the UL-006 gap has two independent halves (the signal library closes only
   the message half; exhaustion still shares 253); corpus failure is QEMU 35
   (Test.bend check -> IO.die(Unit, 1, ...)).
6. New hosts/unikraft/scripts/check-fault.sh with references
   verification/unikernel-overflow-reference.txt and unikernel-exhaust-reference.txt
   (check-image.sh cannot be used: console.sh refuses the crash screen's NUL bytes, tried
   first). Overflow PASS (253), Exhaust PASS (253, -m 1024), negative control (Hello
   against the overflow reference) FAIL exit 1; the signals trial capture passes with the
   message line in its reference.
7. docs/UNIKERNELS.md Open list names the one-off gpuexample "PM driver failed the
   operation: -5" line.
8. OpenSpec, pinned form: `~/.bun/bin/bunx @fission-ai/openspec@1.16.0 validate --all
   --strict --no-interactive` -> Totals: 44 passed, 0 failed (44 items). (Task 3's earlier
   runs used the same bunx form, also 44/44.)

Boxes unchanged: 2.1, 2.3, 2.4, section 3 unchecked. No long build in this round.

## Final-review fixes

Review: `final-review.md` in this directory. Master merged first (7433b20, clean, no
manifest conflict). No requirement weakened; no generated C, runtime, or Unikraft source
touched; no C changed in this round.

1. Important 1, host-layer scope: `hosts/unikraft/INVENTORY.md` intro and tasks.md 2.1 now
   say the boot and termination host layer is `exit_device.c` alone; `host.c` is the C side
   of the effect twins (console, clock, channel, COM2 scratch-register probe). Rationale:
   description alignment with the delivered files. UL-004 not reworded.
2. Important 2, `check-fault.sh`: deletes the log and raw capture before booting, captures
   run.sh's exit status and fails on a mismatch, and fails when no log exists. Reruns
   (QEMU TCG, emulated): Overflow ovf2 PASS 253; Exhaust exf2 (-m 1024) PASS 253; negative
   control negf2 (Hello vs. the overflow reference) FAIL, "run.sh exit: 33, expected 253",
   script exit 1; missing image FAIL, "log: missing", exit 1. Recorded at the end of
   `verification/unikernel-fault-qemu.txt` ("Final-review fixes").
3. Minor 3: tasks.md 2.1's "must park on its device descriptor" now says the ingress parks
   on the runtime timer since COM2 has no descriptor; "QEMU 255" qualified as the first map
   (19 under the current one, not rerun), here and in docs/UNIKERNELS.md. Its Open list gains
   the `IO.print` twin, the unresynchronised partial frame, and the untraced back-off.
   Rationale: description alignment.
4. Minor 4: Channel.md states the partial-frame-plus-cap silent death until the harness
   timeout and the unbounded console line per dropped frame. Rationale: records a limit.
5. Minor 5: design.md's networking/virtio sentence now says the channel's transport is the
   host layer's choice and the record is the contract (COM2 to a Unix socket today; an
   authenticated ingress over any transport stays open, UL-008). Rationale: description
   alignment; the transport is the host layer's choice, the record is the contract.
6. Minor 6: INVENTORY.md probe list includes Exhaust.bend.
7. Minor 7: `unikernel-fault-qemu.txt` labels are rtsbogus/rtsthreads0 (the log names on
   disk). This report had no such labels to fix. `unikernel-corpus-qemu.txt` line 9 now
   names its own "Task 3 rerun" section instead of another file.
8. Traceability (`openspec/traceability/unikernel-library-runtime.md`): Implementation and
   evidence lists cover effects/, monitor/, check-channel.sh, check-fault.sh and the
   effects/channel/fault records; UL-004 and UL-006 rows rewritten to the current codes
   (33/35/17/253), the amendment, and the gaps (IO.print twin, scaffolding subject, no fault
   message in the delivered configuration, exhaustion at 253); UL-005 gives QEMU 1 under the
   first map and 33 under the current one. Rationale: record alignment.
9. `verification/runtime-profile-hosts.md` (Unikraft rows and the channel row only): the
   782 Unikraft row adds the Task 3 rerun (33; uqemu lines 280-294); the pending channel row
   is filled from ufault/uchan; uqemu citations shifted +7 for the code-map note (also in the
   764/782 summary rows, where only the uqemu numbers changed) and UNIKERNELS.md 109/111 ->
   156/158; one new paragraph defines ufault/uchan and the line-number revision. No other
   line touched. Rationale: record alignment.
10. Runtime profile citation: design.md gains "The runtime host profile gates the image"
    (scripts/runtime-profile/, check-binary.sh, runtime-profile-hosts.md, BEND-RUNTIME.md;
    qualifies no host) and tasks.md 2.2 cites the profile; the host-profile tasks.md 2.3 note
    gains one sentence ("unikernel cited on 2026-11-04"); its box stays unchecked.
    Rationale: description alignment, so that sentence is true.
11. OpenSpec 1.16.0 (`~/.bun/bin/bunx @fission-ai/openspec@1.16.0 validate --all --strict
    --no-interactive`): Totals: 44 passed, 0 failed (44 items).

Boxes unchanged.
