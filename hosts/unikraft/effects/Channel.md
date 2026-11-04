# Writ channel record formats (Unikraft)

Unikraft effect-twins lane, Task 2. The byte layout of the frames a client and the
Bend monitor `hosts/unikraft/monitor/Monitor.bend` exchange over the image's one Writ
channel, and what carries them. The records are those of the Genode channel
(`hosts/genode/effects/Channel.md`) word for word; only the carrier, the frame header's
place, and the subject's source differ. `host.c` copies the words and never interprets
them beyond the header's length word (a wrong length gets the fixed transport refusal
below); the monitor decides. The Bend records `Request` and `Reply` in `Unikraft.bend`
mirror the formats field for field, and the twins `unikraft_take.c` and
`unikraft_put.c` marshal the words only.

Example: the host-side client `hosts/unikraft/probes/client/client.c` writes reader R's
report-to-summary request as one 80-byte frame to the Unix socket QEMU binds the second
serial port to; the monitor answers `Committed` in an 80-byte result frame
(`verification/unikernel-channel-qemu.txt`, run "accepted"). Current gaps: the subject is
a build-time word, not a route (below); one channel and one outstanding request; the
monitor exits at fuel 0 and nothing restarts it; no RPC surface exists beyond these
frames.

## Transport

QEMU's second `-serial` (chardev `unix:<path>,server=on,wait=off`) is the ISA serial port
at 0x2f8 on the `pc` machine. With `CONFIG_LIBNS16550_COM2=y` (template Kraftfile),
Unikraft 0.21.0's `drivers/ukconsole/ns16550/com.c` registers it as the console device
"COM2" with flags 0 (`com_init_port`), so it is neither a STDOUT nor a STDIN device:
`uk_console_out`, `IO.print`, and `Unikraft.log` never write to it, and the boot console
stays on COM1. `host.c` finds it by name (`uk_console_count`/`uk_console_get`) and reads
and writes it with `uk_console_in_direct`/`uk_console_out_direct`; `com_in` and `com_out`
move bytes unchanged (no CR or echo processing, unlike `lib/posix-tty`'s serial file).

How `Unikraft.take` waits: the twin parks on the runtime's own timer
(`io_wait_on(w, 0, 0, io_until(ms), more)`) and polls COM2 on each wake. It does not park
on a descriptor because this configuration has none for COM2: `lib/posix-tty`'s serial
file reads every STDIN console (not COM2) and reports POLLIN statically
(`lib/posix-tty/serial.c`, `serial_state`), and `com_setup` disables the port's
interrupts, so nothing would make a descriptor readable. It does not use `io_work` (its
helper thread outlives `main` and turns success into QEMU 255,
`verification/unikernel-effects-qemu.txt` R0-E1) and does not block the loop thread.
Between wakes the CPU halts in the idle thread; nothing spins.

Cost: `com_setup` never writes the FIFO control register, so the port's 16550A FIFOs are
off and it holds one received byte; a wake collects about one byte, however long the
park. With a fixed 10 ms park that was about 100 B/s, 0.8 s per 80-byte frame (measured:
0.86 s from starting the client to its reply, one accept, the monitor already in a take).
The twin now parks 10 ms while nothing has arrived and 1 ms while a frame is partly in
(`host.c` answers BUSY; after 100 empty polls in a row, about 100 ms, it answers IDLE
again, so a client that stops mid-frame does not keep the twin on 1 ms parks): 0.14 to
0.56 s per accept round trip in seven runs, wall time per boot 0.8 to 1.8 s (was 4.3 to
4.4 s; the spread follows host load). Enabling the FIFOs from `host.c` (FCR 0x2fa = 0x07)
was tried and dropped: a client that had connected and sent before the first take then
hung to the timeout, read as the UART flushing its receive FIFO when the FIFOs are
enabled after bytes arrived (`verification/unikernel-channel-qemu.txt`, "Fix round 1").
An interrupt-driven descriptor (COM2's IRQ 3 feeding a pipe) or a driver that enables the
FIFO at setup would remove the poll; neither is built.

Flow control: `host.c` holds one partial frame and no queue, reads only while a take is
outstanding, and handles at most one whole frame per poll, so the loop always returns to
a park. Unread bytes wait in QEMU's emulated UART and, behind it, in QEMU's chardev. That
QEMU then stops reading the socket rather than dropping bytes is QEMU's serial device
behaviour as understood here, not read from its source; the runs lost no byte. Output
can block: `com_write` busy-waits on the transmit register, so once a client stops
reading and QEMU's socket buffer fills, a put or refusal waits in the loop thread until
the client reads (the image is then stuck; the harness timeout bounds it). `host.c`
bounds its own output so that bad frames alone cannot reach that point: it answers at
most `WRIT_UK_REFUSAL_MAX` (8) bad-length frames per boot, then drops further ones with
a console line and no reply. This is host failure handling, not policy: the cap makes no
Writ decision, and dropped frames never reach Bend. A client that sends only good
frames gets one 80-byte result per request and the monitor's fuel (4) bounds them; the
size of buffer at which a non-reading client blocks `com_write` was not tested.

## Frames

Every field is an unsigned 32-bit word, little-endian (the only target is x86_64). A
frame is always 80 bytes: a 16-byte header, then a 64-byte record.

| Offset | Word | Meaning |
| --- | --- | --- |
| 0x00 | length | bytes of the record; exactly 64 |
| 0x04 | sequence | request: chosen by the client; result: the sequence of the request it answers |
| 0x08 | reserved | 0 (not checked) |
| 0x0c | reserved | 0 (not checked) |

The frame size is fixed, so a frame with a wrong length word still occupies 80 bytes and
the stream stays aligned: `host.c` reads all 80, counts it (`bad length=` in its console
line `writ_uk: channel frame refused: length=0x... bad length=N`), and answers the
transport refusal before any Bend parsing (after the eighth, it is dropped with
`writ_uk: channel frame dropped, no reply (refusal cap): ...` instead); Bend never sees it
and the monitor spends no fuel on it.

There is no resynchronisation: frames are counted from the first byte of the boot. A
client that sends part of a frame and disconnects leaves those bytes in `host.c`'s
buffer, and the next client's frames are read shifted by that many bytes; they then
fail the length check or decode as other words. This widens no authority: every frame,
however aligned, is checked as any other (length word, then the monitor's record checks),
and the subject is the built-in word either way. Not exercised.

## Transport refusal (kind 3, written by host.c)

The one result record `host.c` writes on its own. It carries no Writ decision: it is a
fixed record that depends only on the request frame's length word being wrong. Its kind,
decision, and reason words are outside the monitor's (kind 2, decisions 1 and 2,
reasons 0 to 6).

| Word | Value |
| --- | --- |
| 0 version | 1 |
| 1 kind | 3: transport refusal |
| 2 decision | 3: transport refusal (not a Writ decision) |
| 3 reason | 256: bad length (the header length was not 64) |
| 4 to 15 | 0 |

The result header carries length 64 and the refused frame's sequence.

## Request record (kind 1, commit request)

As the Genode channel's, word for word: 0 version (1), 1 kind (1), 2 session (1 the
reader's negotiated session, 2 subject S's session, synthetic), 3 expected_session (6
for session 1), 4 to 6 the plan stamp's graph, policy, and authority epochs (1, 2, 3),
7 invocation (99), 8 and 9 the source object and version (10, 1), 10 and 11 the
destination object and version (20, 1), 12 claimed_subject (untrusted, never used as
identity), 13 to 15 reserved (0; the monitor refuses others with reason 1). Offsets
are within the record (frame offset = 16 + record offset).

`Unikraft.take` answers a `Request` whose first field, `subject`, is not a record word
(below), followed by the 16 words above.

## Result record (kind 2, decision)

As the Genode channel's: 0 version, 1 kind (2), 2 decision (1 Committed, 2 Denied),
3 reason (0 none; 1 bad record; 2 route subject unknown; 3 session unknown; 4 the body's
plan is not the session's plan; 5 the caller's descriptor mount/open was rejected, no
binding made; 6 `DataOS.commit_from_capability` returned Rejected), 4 subject, 5 session,
6 to 10 the write intent (destination object and version, invocation, first artifact
word, backend), 11 session_revision, 12 reader_balance, 13 descriptor, 14
frontend_revision, 15 reserved. Reasons 7 and 8 of the Genode channel (table full,
channel bound to another subject) cannot occur with one channel and one built-in subject.
A write intent is descriptive: nothing is written.

## Subject

There is no parent route on a unikernel: nothing outside the image labels the channel the
way Genode's init labels a session. The subject word is therefore a **build-time
constant**: `WRIT_CHANNEL_SUBJECT` (a nonzero decimal word) given to
`hosts/unikraft/scripts/build.sh` becomes `-DWRIT_UK_CHANNEL_SUBJECT` for `host.c`
(`app/Makefile.uk`), and `writ_uk_take_poll` hands it to Bend beside every record. It is
never read from the record body. An image built without it ends at its first take
(`writ_uk: no channel subject built in`). The kernel command line was not used because
it is supplied by whoever boots the image, at run time.

This is SCAFFOLDING for the ingress twin, not an identity: whoever builds the image
chooses the word, and whoever can reach the serial port's socket speaks as that subject.
It is the gap that UL-008's single-ingress rule and the appliance host must close (an
authenticated channel whose subject comes from outside the client's reach). The runs
use word 1, which `Monitor.bend` maps to `examples/Scenario.bend`'s reader R; word 2
maps to the synthetic subject S, shown only by `MonitorCheck.bend` on Linux.
