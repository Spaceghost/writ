# Linux identity: synthetic monitor checks

A broker frame can describe a launched worker and its connected peer. If their
process credentials differ, the monitor must reject the frame without changing
its state or returning an effect. These checks use synthetic facts and encoded
`LINUXB` frames; they do not authenticate Linux credentials, run a broker,
prove confinement, or qualify a host. Board question q19 selected these checks
while native identity evidence remains open.

Twenty new cases run through `LinuxHost.serve`, the framed decoder and the
monitor's actual dispatch. They cover matching launch and barrier frames; a
socketpair parent's peer; differing uid, gid, pid or process start time; the
high word of a start time; stale monitor incarnation; and a barrier naming a
foreign subject, token, or session. Denials check the complete unchanged state
and empty effects. A selected mutation that dropped the start-time high word
was caught by `synthetic LINUXB launch rejects peer start-time high-word
mismatch`. Synthetic inputs are not authenticated issuer records and a passed
model check does not establish how the broker obtained them.

Seven additional cases test the direct frame decoder at 512 bytes, 513 bytes,
and 10,000 bytes, including a service call that preserves state and returns no
effect for an over-limit frame, and combined-error cases that pin the declared
length, alignment, and byte-range error order. Separate review reproduced a generated Node
stack overflow for 10,000 bytes in the old direct decoder: its non-tail walks
and eager helper arguments evaluated the rest of the parser before returning
`FrameTooLong`. `decode_frame` now performs a bounded walk and an explicit
branch before parsing; the same Node probe returns `FrameTooLong`. The partial
native broker and harness separately limit their private frames; this direct
API test does not show that an oversized frame crossed those limits.

## Remaining identity and host gaps

The monitor compares the launch and peer credentials in a single trusted
broker frame; it does not retain or authenticate the native credential or bind
it to the session's process lifetime. The partial launcher returns failure when
its start-time observation is zero. A separate synthetic review found that if
both frame credentials have start time zero, the model's equality comparison
can admit the launch. This is a broker-fact precondition and a limitation of the
current model, not evidence of an exploitable native acceptance; no caller of
`launch_worker` is present in the partial broker. No passing security test
asserts that an unverified zero is authenticated identity.

Source review also found that `launch_worker` writes the child's release byte
before returning failure on a zero start time. Whether a child executes after
that failed setup and how it is stopped or reaped require a separate native
review and test. No such execution test is claimed here. Native session binding,
per-message credential acquisition, transferred-endpoint behavior, PID reuse,
confinement, and their failure handling remain unqualified. The task 1.2 box
remains unchecked. Prior work recorded two attempts at the native identity probe
being withheld by an automatic safety classifier; the record gives no more
specific reason, and this work does not retry that probe.

## Validation

`LinuxHostTests.bend` passes 118 checks in Bend and generated Node with matching
output. The lane's full Bend and Node suites also pass with matching output
(SHA-256 `f39f04efaba52165546abd78ebf6440ff8ec247b538e7d5784dd8ddd08ac8bd4`).
Existing `bend PROOF.bend` checks pass; no Lean kernel verdict is available.
OpenSpec strict validation passes 44/44. In a host QuickJS verbose run, all
118 focused `PASS` checks were observed, but the process did not terminate
within 45 seconds. An unchanged baseline also timed out at the same point;
the full host QuickJS run is incomplete, not a pass. The full generated
native CPU suite compiled with Clang `-O0` passes with output identical to
Bend. The optimized native CPU build also passes with byte-identical output.
These results are for this older Linux lane and do not establish GPU execution
or a current-master integration result.

## Host QuickJS output-limit follow-up

The timeout was reproduced on the unchanged baseline. The Linux replay test
wrote 37 lines as one 2,027-byte diagnostic, exceeding the host QuickJS
harness's 1,024-byte write limit. Its returning exit hook let the generated
write-failure loop retry indefinitely. The test now prints the same lines
individually; complete Bend and Node output remains byte-identical to the prior
capture. The full host QuickJS suite now terminates with 1,546 passing checks,
program exit 0, no failure or exception, 7,062 ticks and 10,871,224 peak live
bytes. The focused run reports 118 passing checks and program exit 0; its
standalone wrapper returns 1 because it expects the full-suite summary. The
focused native CPU executable also matches the 118-check Bend capture. An
initial comparison used an older 115-check capture and differed only by the
three subsequently added checks and summary; comparison with the correct
118-check capture succeeds. This is host QuickJS and CPU evidence, not Genode
guest, native identity, or GPU evidence.
