# Task 2 review: ingress twins over a second serial channel

Reviewer: task reviewer (read-only), 2026-11-04. Range 5e43f8e..bc4c0b0 (50ef05d, bc4c0b0).

What I did: read the brief, the plan's Global Constraints, the report, the review package,
and the source as it is at HEAD (host.c, the twins, Unikraft.bend, Monitor.bend,
MonitorCheck.bend, client.c, the scripts, Kraftfile/Makefile.uk, Channel.md, INVENTORY.md,
tasks.md, proposal.md, UNIKERNELS.md). I compared Monitor.bend against
hosts/genode/monitor/Monitor.bend and genode_take.c. I ran
`bend hosts/unikraft/monitor/MonitorCheck.bend`: 10 PASS, exit 0, and every hex line equals
the evidence's lines 302-323. I recomputed all 25 recorded sha256 values (all match), diffed
the committed client references against `$W/channel/logs/client-{accepted,denied}.txt`
(identical), and read the run logs, including their wall times. I did not boot QEMU. No QEMU
source is available locally, so the points below about QEMU's UART are from my reading of
hw/char/serial.c, not checked here.

## Spec compliance

- ✅ Authority path. `WRIT_CHANNEL_SUBJECT` is checked in Makefile.uk as a nonzero decimal
  and becomes `-DWRIT_UK_CHANNEL_SUBJECT`. From there it goes into `*subject` in
  `writ_uk_take_poll` (host.c:348), into `v[0]` in the take twin, into `Request.subject`,
  and on to `route_caller` (Monitor.bend:213). No record word reaches a caller.
  `claimed_subject` is only logged. The `session` word selects a table entry, but
  `commit_from_capability` still checks that the caller is the reader, which is the
  reason-6 case. The plan words are compared by `Transfer.Plan.equal`.
- ✅ The monitor mirrors Genode. It has the same reasons 0-6 as closed constants. Its
  binding is a closed `Unbound | Bound` (one channel, so no table is needed, and reasons
  7/8 are explained). It mounts and opens through the protocol and binds even when the
  first record is then denied. A replay meets the Committed session (reason 6, shown in
  both runs). The SYNTHETIC banner is logged at start and `other_session` is marked
  synthetic. There are no unsafe defs and no index operations.
- ✅ Framing. Frames are fixed at 80 bytes, and the read size is `80 - fill`, so the buffer
  cannot overflow. The length word is checked before any record word goes to Bend. A wrong
  length is counted, answered with kind 3 / decision 3 / reason 256, and logged before
  Bend. No length is used as an index. host.c contains no policy.
- ✅ Twins marshal words only and mirror genode_take.c. The `.js` twins throw a clear
  message. The naming follows `unikraft_<x>_run`, and the static helpers end in neither
  `_run` nor `_use`.
- ✅ Binary check: exactly Unikraft.log, Unikraft.put and Unikraft.take, exit 1, allow lists
  unchanged. ⚠️ UL-003's text ("no effect row outside the monitor profile") is met only
  once the profile admits the Unikraft rows. That is accepted under the plan's rule, but
  the evidence never says that `Unikraft.now` and `Unikraft.sleep` are absent because the
  monitor does not call them (see Minor 1).
- ✅ MonitorCheck.bend: 10 checks, including the reason-5 contrast (S as the subject:
  Denied 5, descriptor 0). It exits 1 on a change and does not import Tests.bend.
- ✅ Runs. Accepted and Bend-denied round trips are recorded with hex dumps. I spot-checked
  accepted request 1's reply, `01000000 02000000 01000000 00000000 ... 2d000000 02000000
  02000000 00000000`, and it equals MonitorCheck's "accepted reply 1". The negative control
  exits 1. The no-second-port run gave QEMU 3. The hello and probe regressions are
  recorded. The logs are on disk and the hashes recompute.
- ✅ Build config. Each change is recorded with its reason. COM2 is on in every template
  image, and the evidence states its effect: none on output. Nothing built is committed.
  The only absolute path under hosts/ is the historical `/mnt/...` quote at INVENTORY.md:100.
- ✅ Subject gap. Channel.md, the evidence, Monitor.bend, tasks.md 2.1, UNIKERNELS.md and
  INVENTORY all record it as scaffolding that UL-008 and the appliance host must close.
- ✅ tasks.md 2.1 is correctly left unchecked. It should stay unchecked: the proposal names
  an *authenticated* ingress, and the UL-004 "Console effect" scenario (a twin for
  `IO.print`) is still a gap.
- ✅ Carried nits: the host.c header, unikraft_sleep.c `R0-E1` (the diff touches only the
  comment line), and proposal.md:27.
- ❌ The cost of the polling wait is misstated (Important 1).
- ⚠️ "Can put block forever / can a flood hang anything" is answered incorrectly in
  Channel.md (Important 2).
- ❌ "Inventory complete" (an acceptance criterion): two rows are stale (Important 3).

## Critical

None. The authority model holds. No record word selects or widens a caller.

## Important

1. **The 10 ms poll costs about 10 ms per byte, not 10 ms per request, and the evidence
   attributes the time to the solver.**
   - Where: verification/unikernel-channel-qemu.txt:52-53, Channel.md:32-41,
     UNIKERNELS.md, unikraft_take.c.
   - What: the evidence says "Wall time per boot 4.3 to 4.4 s, most of it before the first
     take (solver)". The evidence's own no-port run reaches the first take, after boot and
     the solve, and ends at **0.3 s** (`run-noport.log`). Every channel boot (accepted,
     denied, negative, two trials) takes 4.3-4.4 s. The extra ~4.0 s covers 5 × 80 = 400
     request bytes, which is 10 ms per byte.
   - Why: with the FIFO left off (Channel.md:45), the 16550 holds one received byte. QEMU
     refills the receive buffer from the chardev on its own loop, not while `com_in` reads
     LSR, so each wake almost always collects a single byte. Ingress is therefore about
     100 B/s, or about 0.8 s per request frame. The controller accepted the polling wait
     only "provided the cost is stated", and the stated cost is wrong. Nothing starves or
     hangs because of it: the timer always wakes the twin, and with one byte per wake the
     `for(;;)` in `writ_uk_take_poll` cannot loop for long.
   - Fix: correct the evidence paragraph (the solve is ≤0.3 s, per the no-port run; the
     rest is about 10 ms per received byte). State the per-byte cost in Channel.md
     "Transport", UNIKERNELS.md and the unikraft_take.c header. Optionally, enable the
     FIFO (an FCR write is a host-layer change: record it) or drain more per wake. Either
     way, re-measure once.

2. **A client that floods bad-length frames and never reads can wedge the image in a busy
   spin. Channel.md says the opposite.**
   - Where: host.c:340-345 and :270, Channel.md:48 ("A client that floods only waits"),
     the host.c header :12 ("It never waits"), and the INVENTORY host.c row ("Does not
     wait").
   - What: transport refusals are not fuel-bounded. Every 80 bad-length bytes produce an
     80-byte reply. `uk_console_out_direct` goes to `com_out` → `com_write`, which
     busy-waits on THRE (drivers/ukconsole/ns16550/com.c, `com_write`, read in
     `$W/src/unikraft`).
   - Why: suppose the client stays connected and does not read. Once QEMU's socket send
     buffer fills, QEMU's serial transmit gets EAGAIN and parks the byte on a chardev
     watch, leaving THRE clear (my reading of QEMU; not verified here). The guest then
     spins in `com_write` with interrupts off until the harness timeout. It never reaches a
     park, so "nothing spins" is false on this path. Bend replies cannot cause this (fuel 4
     means 320 bytes). Only host.c's own refusals can. At about 100 B/s ingress it takes
     tens of minutes, but it is unbounded and it is not recorded. The brief asked exactly
     "what happens if the host never reads?"
   - Fix, minimum: correct Channel.md "Flow control", the host.c header and the INVENTORY
     row, and list this as unexercised. Better: bound refusals in host.c, for example by
     ending the image with a `writ_uk:` line after N refusals (a fixed host-failure bound,
     not policy), or by returning 0 and re-parking after one refusal per wake, so that the
     loop always reaches a park.

3. **The inventory is incomplete.**
   - Where: hosts/unikraft/INVENTORY.md:36, :26 and :113.
   - What:
     - The `effects/Unikraft.bend` row still lists only log, now and sleep. It omits
       `Unikraft.take`, `Unikraft.put` and the `Request`/`Reply` types.
     - The naming rule's helper list at :26 omits `heap_alloc`, `io_seal`, `term_ctr`,
       `ctr_take`, `spare_free`, `cls_fit` and `io_until`, which the take and put rows use.
     - The `scripts/build.sh` row does not list the `WRIT_CHANNEL_SUBJECT` export.
   - Why: "inventory complete" is an acceptance criterion.
   - Fix: update those three places. Also add build.sh's hash to the evidence input list,
     since build.sh changed in this task.

## Minor

1. verification/unikernel-channel-qemu.txt:349: add one sentence saying that `Unikraft.now`
   and `Unikraft.sleep` are absent from the rows because Monitor.bend does not call them,
   so the twins are not linked as effects.
2. Channel.md:66 and the evidence "Not shown". A partial frame followed by a disconnect
   leaves `writ_uk_fill` nonzero for the *next* client, and there is no resync. Every
   later frame on that boot is misaligned: likely an endless run of refusals, or a shifted
   body that happens to read length 64. Shifted body words remain untrusted data and the
   subject stays fixed, so authority is not widened, but record it. A fix would reset
   `fill` on reconnect, which host.c cannot see; failing that, add a frame magic word in a
   reserved header word.
3. app/Makefile.uk: the pattern `[1-9][0-9]{0,9}` admits values above 4294967295. The `u`
   literal is then truncated on assignment to `uint32_t` (host.c:348), so a word such as
   4294967297 silently becomes subject 1 (R). Tighten the check to ≤ 4294967295 or add a
   `_Static_assert` in host.c.
4. Monitor.bend:40 lists the helpers MonitorCheck uses but omits `initial_reader`
   (MonitorCheck.bend:23). INVENTORY:127 has it.
5. run.sh: `$SER` is expanded unquoted, so a socket path containing spaces would split. W
   has no spaces today. Note it or quote it through an array.
6. The evidence's cross-check recipe writes to `/tmp/$n.*`. It is harmless but not
   reproducible in parallel. `mktemp` would match the scripts' style.

## Assessment: Needs fixes

The security-relevant core is sound. The subject comes only from the build-time word.
Record words cannot select or widen authority. The decision is Bend's via
`DataOS.commit_from_capability`, it mirrors the Genode monitor, and the image's replies
match MonitorCheck byte for byte. The fixes are Important 1 (state the real cost of the
polling wait, and correct the misattribution to the solver), Important 2 (correct the
flood/never-read claim, and preferably bound refusals so the loop always parks), and
Important 3 (complete the inventory). After that it can be approved. Important 2's code
bound may instead be recorded as a gap if the controller prefers to keep host.c unchanged
in this task.
