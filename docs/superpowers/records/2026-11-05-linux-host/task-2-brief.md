### Task 2: Native broker and authenticated worker session (tasks.md 1.2)

Requirements it implements, by name: LH-002 "Worker identity is bound to an
authenticated lifetime" (both scenarios: "Parent-created socketpair is
inherited", "An endpoint moves to another process"); and the transfer-denial
half of LH-007 "Delegation is explicit and attenuating" ("Sender transfers an
FD without a delegation record").

Create `broker.c`/`broker.h` and the launch/session binding in `launch.c`/
`launch.h`. The broker owns a bounded `AF_UNIX` `SOCK_SEQPACKET` listener, the
trusted launch record, the two private channels to the generated Bend monitor
(`hosts/linux/monitor/LinuxHost.bend` built to a `.mjs` and run under Node with
a transport like `contrib/native-hosts/runtime/node-policy.mjs`, or the same
module invoked in-process), and the native session/handle table. It:
- Builds a trusted launch record before fork: the selected subject, the monitor
  incarnation, a fresh session generation, and the intended worker. It launches
  the worker (confinement from Task 3) and retains its pidfd and
  `/proc/PID/stat` start time.
- Authenticates each connection with `SO_PEERCRED`, then matches the credential
  to the retained pidfd and start time. Only a peer that is the launched worker
  with the recorded lifetime binds to its session; it reports a
  `SessionEvidence` to the monitor with the launch record's subject, never the
  peer's uid. `SO_PEERCRED` on a parent-created socketpair records the parent's
  connection-time credentials, so the broker never treats socketpair-time
  credentials as the child's identity; the binding comes from the launch record
  (LH-002, scenario one). It feeds `HostIdentity` through the Bend monitor:
  session id, incarnation, generation, caller, origin.
- Resolves every worker request to a session and reference through the monitor's
  `HostIdentity.resolve` only; a frame on a session that is not the bound holder,
  or a reference whose generation/incarnation is stale, is denied by the monitor.
- Denies descriptor transfer as authority acquisition: an ancillary
  `SCM_RIGHTS` descriptor arriving on a session without an approved delegation
  record does not authorize the sender as another subject; the broker drops it
  and the monitor denies the operation (LH-007, scenario one; the attenuating
  delegation path itself is modeled in `HostIdentity.delegate` and exercised in
  Task 4's resource-lookup probes).

`broker_probe.c` (or a `--case` of the broker) records, into
`verification/broker-v1/identity.log`:
- Claimed identity: a worker frame claiming another subject binds to the
  authenticated subject, not the claim.
- Parent-created socketpair: a socketpair made by a parent and handed to a
  child is not accepted as the child's identity; the bound actor comes from the
  launch record.
- PID reuse: after the worker exits and its pid is reused by an unrelated
  process, a frame on the old session is denied (the pidfd/start-time mismatch
  and the stale session generation).
- Namespace identity mapping: the worker's in-namespace uid/pid differ from the
  broker's view; the binding uses the launch record, not the in-namespace
  numbers.
- Transferred endpoint: a process that obtains the session socket from the
  worker and sends a frame is not authorized as the original subject.

Each case is a `PASS`/`FAIL` line with the kernel-observed values, in the shape
of the canary's `native-revocation.log`. Add the build targets to the Makefile
and the broker source/trust rows to `contrib/native-hosts/linux/README.md`
(canary section intact) and `hosts/linux/INVENTORY.md`. Add the LH-002 and
LH-007 native rows to `openspec/traceability/linux-host.md`, each citing the log
and its exact assertions. Check box 1.2.

Acceptance: the broker builds with `-Wall -Wextra -Werror`; each identity case
produces its recorded `PASS` line against real kernel credentials on the
qualification host (see the open question on where that host is); the Bend
suite and proofs are unchanged. One implementer dispatch.

