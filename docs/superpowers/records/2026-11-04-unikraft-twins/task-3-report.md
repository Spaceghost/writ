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
