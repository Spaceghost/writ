# Supervisor driver for the issuer and clock owner

Example: worker 1 runs as an owned process. Role 1's process (principal 101)
writes the 16-byte "revoke approval 5" record on the supervisor channel. The
native driver receives it through the
[`SCM_PIDFD` receiver](../linux-supervisor-channel/README.md), reads one clock
sample and sends
`LINUXSUP1 CONTROL 0 1 0 114 01000000010000000100000005000000` to the private
interpreter that retains the [`SupervisorOwner`](../../hosts/linux/monitor/SupervisorOwner.bend).
The interpreter replies `REVOKE_APPLIED`, containment required, no effect. The
driver then sends `DRAIN`, gets `DRAIN_STEP S1`, and kills worker 1 through
the pidfd it registered for worker 1, and acknowledges the stop only after
that pidfd reports exit; the test reaps it as killed by `SIGKILL`.
The same record from role 2 (principal 102) or from an unregistered process is
refused or denied, and nothing is stopped.

Current gap: the interpreter's starting owner is a **synthetic test
provisioning module**, and the clock samples in these cases are scripted,
because the synthetic issuer's grant times (110 to 120) are not a host time base.
Nothing provisions a real issuer or role map, aligns `CLOCK_BOOTTIME` with grant
times, survives a restart or qualifies a host.

## What changed

| Part | Source | Responsibility |
| --- | --- | --- |
| Wire protocol | [`SupervisorWire.bend`](../../hosts/linux/monitor/SupervisorWire.bend) | LINUXSUP1: parses one `CONTROL`, `FRAME` or `DRAIN` frame, calls `SupervisorOwner.step`, renders the outcome, the containment flag and the effects. A malformed frame replies `ERROR` and stops the interpreter. |
| Test provisioning | [`SupervisorDriverModule.bend`](../../hosts/linux/monitor/SupervisorDriverModule.bend) | SYNTHETIC: `initial()` is the joint owner fixture's running stage with roles 1 → 101 and 2 → 102 |
| Bridge | [`runtime/supervisor-policy.mjs`](../../contrib/native-hosts/runtime/supervisor-policy.mjs) | Byte framing and reply shape only, same as `node-policy.mjs` |
| Native driver | [`supervisor_owner.c`](../../contrib/native-hosts/linux/supervisor_owner.c), [`.h`](../../contrib/native-hosts/linux/supervisor_owner.h) | Forwards the receiver's verdict number, role word and payload with one sample; executes only StopEffects through registered worker pidfds |
| Pipe | [`policy_pipe.c`](../../contrib/native-hosts/linux/policy_pipe.c) | New `writ_policy_exchange`: one raw line, same deadline and kill-on-failure; WRITFS1 calls are unchanged |
| Test | [`supervisor-owner-test.c`](../../contrib/native-hosts/linux/supervisor-owner-test.c), [`supervisor-owner-fake.mjs`](../../contrib/native-hosts/linux/supervisor-owner-fake.mjs) | Unprivileged owned-process cases; the `.mjs` is an explicitly malformed peer for the bridge that holds no policy and answers with replies the owner never sends |

The driver makes no decision of its own. It does not attribute senders, decode
payloads, compare times, decide containment or choose a worker. It forwards
the role word only for a `FROM_ROLE` verdict, and the payload only for the two
verdicts where the receiver defines one. Anything it cannot execute is
fail-stop, and it sends nothing more after that:

- a reply with an effect other than `S<worker>`, or with more than eight stops;
- a stop for a worker it has no pidfd for, or a worker whose pidfd does not
  report exit within five seconds of `SIGKILL`;
- any effect returned for a control message;
- a malformed or out-of-sequence reply;
- an outcome that does not belong to the operation sent, which includes an
  interpreter-side `ERROR`, `STOPPED` or `EXHAUSTED`;
- a receiver verdict outside the C enum, or an oversized record;
- a dead interpreter.

Fail-stop also kills the interpreter, so nothing can exchange with it again.
Containment is sticky in the driver. A supervisor is for one thread at a
time; frame and record buffers are on the stack. The driver does not drain by itself; its
caller sends `DRAIN` (the test does so after containment).

`FRAME` is in the protocol and the Bend checks, so monitor frames and control
messages are serialized by one interpreter. The native driver does not send
monitor frames yet.

## What ran

| Run | Result |
| --- | --- |
| [`SupervisorWireTests.bend`](../../hosts/linux/monitor/SupervisorWireTests.bend) | [8 checks](wire-checks.txt) |
| Native driver test (gcc, Makefile flags with `-Werror`) | [26 cases](native-run.txt), exit 0; [20 repeats](native-repeat.txt) all pass |
| clang build with `-Werror` | builds |
| [Mutants](mutant-results.txt) ([diffs and outputs](mutants/)) | all 15 Bend mutants fail; 18 of 19 C mutants fail, and the survivor is listed below |
| `bend Tests.bend` | [differs from master](suite-diff-against-master.txt) `757c0ab1` only by the nine new lines; `check_core.py` verifies 3250 (3242 + 8), see the [suite tail](suite-tail.txt) |
| Native CPU suite (`clang -std=c11 -O0`, `+RTS --threads 4 --gpu off`) | [byte-identical](native.txt) to the Bend run; no GPU test is claimed |
| `bend PROOF.bend`, and `--verdict` with the Lean-built BendTT | [`ALL PROOFS CHECK`](verdict.txt); no law mentions the driver |

The [commands](commands.txt) and the [environment](environment.txt) are
recorded: Linux 7.2.9, gcc 16.2.1, clang 23.1.1, glibc 2.44, Node 26.10.0 (not
the canary's pinned Node 22), `CapEff` 0, and source and binary hashes. The
receiver needs `SO_PASSRIGHTS`, so Linux 6.16 or newer; the test exits 77 on
older kernels. This test is not part of any CI lane.

## Cases

| Case | Observed |
| --- | --- |
| `non_issuer_revoke_refused` | role 2 revoke 5: `REVOKE_REFUSED`, no containment, worker alive |
| `unregistered_sender_denied` | an unregistered process's revoke 5: `CHANNEL_DENIED` |
| `malformed_payload_undecoded` | role 1 three-byte payload: `CONTROL_UNDECODED` |
| `issuer_revoke_applied` | role 1 revoke 5: `REVOKE_APPLIED`, containment; the control step kills nothing |
| `drain_returns_worker_stop`, `drained_worker_killed` | `DRAIN_STEP S1`; worker 1 reaped, killed by `SIGKILL` |
| `second_drain_complete` | `DRAIN_COMPLETE`, no stop |
| `idle_channel_not_forwarded` | nothing queued: `EAGAIN`, no frame sent, no clock sample taken |
| `regressing_sample_contains`, `regressing_then_drain_stops` | samples 115 then 112: the second refused revoke is `CONTAINED`; the drain still stops worker 1 |
| `expired_grant_contains` | sample 125, past the grant expiry at 120: `CONTAINED` |
| `unavailable_clock_issuer_revoke_applies` | unavailable sample: the issuer revoke still applies, with containment (LH-012) |
| `unregistered_worker_fail_stop` | `S1` with no registered pidfd: fail-stop, nothing signalled |
| `frame_verdicts_exact`, `frame_clock_kinds_exact`, `frame_bounds` | exact CONTROL frames: the verdicts 0 to 8 and the three faulted clock kinds by number, the role only for `FROM_ROLE`, the payload only for the two accepted verdicts; verdict 9 and 4097 bytes are refused, 4096 bytes are framed |
| `peer_wrong_operation_outcome`, `peer_control_effect`, `peer_interpreter_error`, `peer_drain_wrong_outcome` | against the malformed peer: `SERVED` for a control message, a control reply carrying `S1`, an interpreter `ERROR`, and `REVOKE_APPLIED` for a drain are each fail-stop; the interpreter is killed and no worker is signalled |
| `interpreter_loss_fail_stop` | the test kills its own interpreter: fail-stop, the later `DRAIN` is not sent, no replay |
| `decode_stop_list`, `decode_stop_bound`, `decode_rejects` | reply decoding: order, the eight-stop bound, and rejection of a non-stop effect, a wrong sequence, a trailing comma, a leading zero, an unknown outcome and a bad flag |
| `boottime_reading` | `CLOCK_BOOTTIME` read twice, non-decreasing |
| `descriptor_cleanup` | the descriptor count is unchanged |

The Bend checks cover:

- exact reply strings for refused, applied and drained revokes;
- unattributed senders and malformed payloads, which deny without containment;
- faulted, expired and regressing samples;
- twelve malformed frames, each of which replies `ERROR` and stops the interpreter;
- the 4096/4097-byte payload bound;
- a frame and a later message sharing one watermark, so a refused revoke sampled behind a frame is `CONTAINED`;
- the exhausted and stopped interpreters;
- effect rendering.

Every process, socket and descriptor in the native test is created by the
test. It requests no privilege, signals only its own children, mounts nothing,
probes nothing host-wide and starts no VM.

Mutant notes:
- The C mutant that samples the clock before receiving is caught by the test's
  script-exhaustion guard, not by a named case.
- `stop-without-exit-wait` survives: acknowledging a stop as soon as the
  signal is sent passes, because every owned worker dies on `SIGKILL` at once.
  An unprivileged test cannot hold a worker in an uninterruptible wait, so the
  wait for exit is reviewed only. Treating `ESRCH` as a stop that already
  happened is also reviewed only.

## Not established

- **Provisioning:** no issuer installation, role map or worker-to-pidfd
  registration from a trusted source. Here the test does all three.
- **Clock:** no alignment of a host clock with the issuer's time base, and no
  continuity across a restart.
- **Monitor frames:** none come from a real broker.
- **Role binding:** a worker's channel role is not bound to its session.
- **Containment:** no whole-instance containment beyond killing the one
  registered worker.
- **Qualification:** no host qualification.

These remain reviewed-only gaps under LH-011 to LH-017.
