# Final whole-branch review: Unikraft effect twins

Reviewer: final whole-branch reviewer, 2026-11-04. Range 09cd9bc..08123e4 (HEAD 08123e4),
lane/unikraft-twins. I read AGENTS.md, docs/PLATFORMS.md, the plan, the change (spec,
tasks, proposal, design, explainer), the ledger, the three task reviews and the final
diff. I read host.c, exit_device.c, the five C twins, the Makefile.uk/Kraftfile, every
script, INVENTORY.md, Channel.md and the UNIKERNELS.md diff in full. I also checked
master (09cd9bc..master) for integration overlap. The per-task reviews already matched
hashes and logs, and I did not redo that. I booted nothing and did not run Bend, so this
review is source and record reading only.

## 1. Security and authority

- `git diff --stat 09cd9bc..HEAD -- '*.bend'` lists only hosts/unikraft/{effects,monitor}
  and scripts/unikernel/{Probe,Exhaust}.bend. No library or test `.bend` imports
  `hosts/` or `scripts/unikernel` (grep over every tracked `.bend` outside those trees).
- host.c and the twins hold no policy. host.c compares one length word with 64, copies 16
  fixed words, and writes a constant refusal record. The twins only marshal. The length
  word is never an index or a count: reads are bounded by `WRIT_UK_FRAME_BYTES - fill`,
  and copies by the constant 16. A wrong-length frame returns BUSY before
  `writ_uk_pending` or `record` is touched, so it never reaches Bend.
- The subject is `WRIT_UK_CHANNEL_SUBJECT` only (host.c:415). No code path reads it from
  frame bytes. Makefile.uk:42-49 accepts only `[1-9][0-9]{0,9}` ≤ 2^32-1 and appends
  `u`. The `_Static_assert` (host.c:137) catches a direct `-D` that is negative, zero or
  wider than 32 bits. Without the word, the first take or put ends the image.
- The build-time subject is labelled SCAFFOLDING and the UL-008 gap in Channel.md,
  INVENTORY, UNIKERNELS.md, tasks.md 2.1, Monitor.bend and the evidence. Every evidence
  file says QEMU TCG, "not native, not GPU".

## 2. host.c and exit_device.c

**Framing.** The loop at host.c:382-419 terminates: each iteration either returns, or
adds ≥1 byte toward a fixed 80-byte total and then returns. One frame per call holds.
The back-off counter resets on any byte and counts only while `fill > 0`, so it is
correct. A partial frame left by a disconnect stays in `writ_uk_frame` with no
resynchronisation, and that is recorded. The refusal cap is correct, and the 8 x 80-byte
bound on host.c's own channel output holds.

**Clock and sleep.** The arithmetic cannot overflow: u32 ms x 1e6 < 2^53 ns. `io_tick`
is in nanoseconds (Bend 2.0.39 effs/sleep.c:10 adds `ms * 1000000ull` to it), so
`io_tick() + left` is in the right units. The round, regression and no-progress checks
come after the `now >= deadline` early return, so a late wake is never a failure.

**Exit map.** I could not find a path that reports a non-success as 33:
- 33 needs status 0, which means either a return from main or `exit(0)`. Bend reaches
  `exit()` only through IO.exit/IO.die (task-3 review), and `_exit(0)` occurs nowhere.
- A failed `atexit` can only turn 35+ into 17/19.
- A crash writes 0x7e directly from the event.
- A main-returns-0 run with a leftover thread becomes 0x80|SIGKILL, which maps to 19. That
  is a failure, not a false success.
- The clamp keeps every program value ≤ 0x7c.

All q values are odd, so 0, 1 and 124 are impossible.

**Hangs.** There are three ways to hang without a recorded code, and all three are
bounded only by the harness timeout (124). They are a take that no client answers, a
`com_write` toward a non-reading client, and a stopped clock. Each is documented
(INVENTORY:40, :59-62, :75-77; Channel.md:63-65). Nothing spins.

## 3-4. Records and consistency

The UL-004 amendment's rationale is in tasks.md 2.1. No other requirement text changed:
the spec diff touches only the UL-004 body. proposal.md:27, design.md:38-47 and
explainer.html:107/118/130 match the amended text. Six older evidence files carry the
dated CODE MAP NOTE, and the reruns under the new map are in unikernel-fault-qemu.txt
(channel t3acc/t3den at 33, t3noport at 17) and unikernel-corpus-qemu.txt (782 PASS, 33).
Scripts source env.sh. run.sh and console.sh share `writ_strip_serial`, and check-fault.sh
reads run.sh's cleaned log rather than stripping again. Nothing built is tracked. The only
absolute path in hosts/ is the quoted historical `/mnt/...` at INVENTORY.md:124.

## Critical

None.

## Important

1. **host.c is filed under the wrong UL-004 category, and the rationale does not cover
   it.** INVENTORY.md:5-8 calls `host.c` part of "the inventoried boot and termination
   host layer". host.c is neither boot nor termination code. It is the C side of the
   effects: console, clock, channel, and a port-I/O probe of 0x2ff. The amendment's
   rationale (tasks.md:60-72) argues only for the exit hook. A reader of the amended
   UL-004 cannot tell which category admits 435 lines of channel code. AGENTS.md requires
   an explicit rationale for a law change, so no category should be implied without one.
   Fix (no spec text change needed): state in tasks.md 2.1's rationale and in
   INVENTORY.md:5-8 that `host.c` is part of the effect twins' C side (the twins'
   `unikraft_<x>.c` files plus the `writ_uk_*` functions only they call). Say that the
   "boot and termination host layer" is `exit_device.c` alone. If Spaceghost prefers
   host.c in its own category, amend the UL-004 wording instead, with a rationale
   sentence.

2. **check-fault.sh can pass on a stale log.** hosts/unikraft/scripts/check-fault.sh:21-24
   ignores run.sh's exit status and always reads `run-<label>.log`. run.sh exits 2
   *before* writing that log when the image or the logs directory is missing
   (run.sh:32-35). A missing or failed image therefore re-checks the previous boot and
   can print PASS. check-image.sh avoids this because it uses run.sh's `$?`. Fix: in boot
   mode, capture `RC=$?` from run.sh and set BAD=1 (or exit 2) unless the log is newer
   than the call, or `rm -f "$L"` before booting. Note the mirror risk in WRIT_NO_BOOT
   mode in the usage line.

## Minor

1. **Stale text in tasks.md 2.1.** tasks.md:39-40 says the ingress twin "must park on its
   device descriptor the same way", which contradicts the Ingress paragraph below it (COM2
   has no descriptor, and take parks on the timer). The same lines still say io_work
   "turns success into QEMU 255" with no map qualifier. Fix: replace both with "made
   success QEMU 255 under the first map (19 now, not rerun); the ingress twin parks on the
   runtime timer (below)".
2. **The matrix cell in docs/UNIKERNELS.md:158 still says "turns success into QEMU 255"**,
   and the Port status bullet was fixed. Fix: append "(first map; 19 under the current
   map, not rerun)".
3. **docs/UNIKERNELS.md:124-131 "Open" omits gaps the other records carry**: the IO.print
   twin (the reason 2.1 stays open beyond the subject), partial-frame misalignment, and
   the untraced back-off. Fix: add the three items with links to Channel.md and tasks.md
   2.1.
4. **Misalignment plus the refusal cap kills the channel for the rest of the boot, and
   that is not stated.** After one partial frame, every later frame is shifted, so it
   usually fails the length check. After 8 refusals, host.c drops frames silently, the
   client blocks on its read, and the monitor never spends fuel. The image then runs to
   the harness timeout. Each dropped frame also writes one console line, so console output
   is unbounded under a flood. Fix: state this in Channel.md "Frames"/"Flow control" and
   in INVENTORY:77-80 (recovery is a reboot). It widens no authority.
5. **design.md:40-42 still says the ingress "uses the kernel's networking or a virtio
   transport"**, but the twins use ISA COM2. Fix: add one sentence to design.md or tasks.md
   2.1 saying the COM2 transport is scaffolding chosen in this lane (the plan allowed
   `-serial`) and is not the channel change's transport.
6. **INVENTORY.md:156-157's probe list (Hello, Die, Exit, Overflow, Clock, Lanes, Probe)
   omits Exhaust.bend.** Fix: add it ("arena exhaustion, check-fault.sh reference
   unikernel-exhaust-reference.txt").
7. **Carried from task-3-review.md (open): wrong log labels.**
   verification/unikernel-fault-qemu.txt:256 and :259, and the task-3 report, use the
   labels `rtsrtsbogus` and `rtsrtsthreads0`. The logs on disk are `run-rtsbogus.log` and
   `run-rtsthreads0.log`. Fix: correct the two labels in both places.
8. **The corpus file's note refers to itself.** verification/unikernel-corpus-qemu.txt:8
   says "(and the corpus rerun in verification/unikernel-corpus-qemu.txt)". Fix: change it
   to "(and this file's 'Task 3 rerun' section)".
9. **The working tree holds uncommitted record edits** (activity.log, progress.md,
   task-3-review.md with the re-review section) plus this file. Fix: commit them with the
   integration so the record matches the branch.

## 5. Integration notes

Master is 60 commits ahead. Likely conflicts:
- **tasks.md of this change.** Master adds a preface line pointing to
  `openspec/traceability/unikernel-library-runtime.md`. Merge by hand and keep both.
- **docs/UNIKERNELS.md** (lane adds about 43 lines before the matrix), INVENTORY, the
  spec delta, `verification/source-sha256.txt`, and docs/superpowers/records (each lane
  has its own directory, so these are additive).

What integration must redo:
- **Manifest.** Regenerate `verification/source-sha256.txt`. Every new hosts/unikraft
  file, the scripts, Exhaust/Probe/Monitor/MonitorCheck, the new verification files and
  the changed change files are missing or stale there.
- **`verification/runtime-profile-hosts.md` (master).**
  - The Unikraft 782 row says "QEMU exit 1". Keep it as history with a CODE MAP NOTE,
    and add the 33 rerun (uqemu "Task 3 rerun", the corpus3 image hashes).
  - Fill the pending "Unikraft channel" row from unikernel-channel-qemu.txt and the t3acc
    and t3den reruns at 33 in unikernel-fault-qemu.txt.
  - Every `uqemu lines N` citation is now off by +7, because of the note inserted after
    line 3. The `docs/UNIKERNELS.md line 109/111` citations are off by about +43. Re-cite
    all of them, and do the same in docs/superpowers/records/2026-11-04-host-profile-evidence
    if those records are meant to stay live.
- **`openspec/traceability/unikernel-library-runtime.md` (master).** The UL-004 row
  ("the exit part only ... QEMU 1 / 3 / 253") and the UL-005/UL-006 rows (QEMU 1, 3)
  predate this lane. Update them to the amended UL-004, the twins and their evidence, and
  33 / 35 / 17 / 253, with the UL-006 two-half gap.
- **add-bend-runtime-host-profile task 2.3.** Cite the runtime profile in this change's
  design.md and its runtime tasks (2.1/2.2/2.3). Box 2.3 can then close once genode-base-hw
  also cites it.
- Run `bend Tests.bend`, `bend PROOF.bend` and OpenSpec 1.16.0 strict on the merged tree,
  and record them as 3.3 evidence.

## Is the unikernel change finished?

No. These boxes are open:
- **1.3 `linuxu`.** The 0.21.0 pin has no `linuxu`, and 0.16.3 stops at `bend:
  reservation failed`. It needs a reservation that works on `linuxu`, or a ruling that
  UL-007's process row is met by the native Linux reference.
- **2.1.** It needs an `IO.print` twin (the "Console effect" scenario) and an
  authenticated ingress subject from outside the client's reach (UL-008/appliance). An
  interrupt- or descriptor-driven COM2, or a virtio transport, is desirable.
- **2.3.** It needs a decision on the experimental `LIBPOSIX_PROCESS_SIGNAL` (the message
  half) plus a corpus rerun, and a distinct exhaustion code, for example an arena bound
  below guest RAM so that the runtime's ERR_HEAP stop (17, or its own value) is reached
  before the Unikraft crash.
- **2.4.** It needs lanes behind the thread library (E6 shows `pool_work` never entered),
  corpus parity, and a recorded lane count.
- **3.1.** It needs a KVM or Firecracker boot, recorded apart from TCG.
- **3.2.** It needs UA-001 to UA-010 applied: the rebuild drill with elapsed time and the
  trusted-base statement.
- **3.3.** It needs OpenSpec strict and the Bend checks run on the merged tree.

## Assessment: Needs fixes before merge

Important 1 is a records fix: name host.c's UL-004 category in tasks.md 2.1 and
INVENTORY. Important 2 is a three-line script fix. Minors 1, 2, 7 and 9 are cheap and
worth doing in the same round. I found no correctness or authority defect in host.c,
exit_device.c or the twins.
