# Task 2 report: ingress twins over a second serial channel

Status: DONE_WITH_CONCERNS

Summary: accepted round trip yes (Committed 0); Bend-denied round trip yes (S's session
named by the body under subject R: Denied 6 by DataOS.commit_from_capability); binary check
rows exactly Unikraft.log, Unikraft.put, Unikraft.take (exit 1, allow lists unchanged).
Evidence: verification/unikernel-channel-qemu.txt.

## What was built
- `Unikraft.take() -> IO(Request)` and `Unikraft.put(reply: Reply) -> IO(Unit)` in
  hosts/unikraft/effects/Unikraft.bend; twins unikraft_take.c / unikraft_put.c (+ failing .js).
- host.c: writ_uk_take_poll, writ_uk_put; COM2 found by name, read/written with
  uk_console_in_direct/out_direct; fixed 80-byte frames (16-byte header + 64-byte record);
  wrong length read whole, counted, answered with the transport refusal (kind 3, decision 3,
  reason 256) and a console line, never reaching Bend.
- hosts/unikraft/effects/Channel.md; hosts/unikraft/monitor/Monitor.bend (fuel 4, one channel,
  SYNTHETIC Scenario imported) and MonitorCheck.bend (Linux; reasons 0-6 incl. the reason-5
  contrast; both run sequences; exits 1 on change); hosts/unikraft/probes/client/client.c.
- scripts: run.sh WRIT_QEMU_SERIAL2; new check-channel.sh (exits 1 on a changed outcome).
- Build config: Kraftfile CONFIG_LIBNS16550_COM2='y'; Makefile.uk/build.sh WRIT_CHANNEL_SUBJECT.

## Decisions
- Transport: QEMU second `-serial unix:<sock>,server=on,wait=off` = ISA COM2 (0x2f8), Unikraft
  0.21.0 drivers/ukconsole/ns16550/com.c (registered flags 0, so no console output reaches it).
- Waiting: take parks with io_wait_on on the runtime timer and polls COM2 every 10 ms. The
  brief asked for io_wait_on on the device fd; no such fd exists in this configuration
  (lib/posix-tty's serial file reads all STDIN consoles with static POLLIN; com_setup leaves
  COM2's interrupts off). Not io_work, not a loop-thread block, no spin. An IRQ-driven fd was
  not built (concern 1).
- Subject: build-time constant WRIT_CHANNEL_SUBJECT=1 -> -DWRIT_UK_CHANNEL_SUBJECT; never read
  from the body; recorded in Channel.md, the evidence, Monitor.bend and tasks.md 2.1 as
  scaffolding and the gap UL-008 / the appliance host must close. Not the kernel command line
  (supplied by whoever boots the image at run time).
- Runs: two boots, each 4 Bend records + 1 bad-length frame (fuel 4), orders
  accepted: accept, badlen, badver, other, accept; denied: other, badlen, badver, accept, accept.
  Image replies equal MonitorCheck's byte for byte in both orders. Negative control exits 1.
  Missing second serial port exercised: one line, QEMU 3.
- Reasons 7/8 of the Genode channel cannot occur with one channel and a fixed subject; not
  produced.

## Carried nits
- host.c header: now "the functions exported here and the runtime's own helpers", "never
  waits" (code also changed in host.c, so no token compare applies).
- unikraft_sleep.c: E1 -> R0-E1; comment-only, tokens compared with the previous revision
  (gcc -fpreprocessed -dD -E -P, whitespace squeezed): identical.
- proposal.md:27: exit removed from the twins' list ("exit is the inventoried termination host
  layer, UL-004").

## Checks
- MonitorCheck.bend: 10 PASS lines, exit 0. check-channel accepted PASS, denied PASS, negative
  FAIL (exit 1). Task 1 probe (delta 102, QEMU 1) and hello regressions PASS with the new
  template. OpenSpec 1.16.0 strict: 44 passed, 0 failed. Manifest not regenerated (integration).

## Concerns
1. take polls COM2 every 10 ms on the timer instead of parking on a device descriptor; an
   interrupt-driven descriptor (IRQ 3 feeding a pipe) would be needed for a true fd park.
2. The subject is a build-time word: anyone reaching the socket speaks as R. Scaffolding only.
3. COM2 is now in every template image's config (flags 0; regressions show no output change).
4. Unexercised: missing-subject path, skipped put, partial frame then disconnect; QEMU's
   no-loss behaviour under a slow guest is not read from QEMU's source.
