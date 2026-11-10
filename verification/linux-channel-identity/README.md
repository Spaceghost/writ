# Owned-process channel identity test

A child process A sends on a private `AF_UNIX` `SOCK_SEQPACKET` endpoint, then
passes that endpoint to a second child B with `SCM_RIGHTS` and stays alive. On
Linux 7.2.9, the receiver's per-message `SCM_PIDFD` names B for B's message and
A for messages A queued before the transfer, including one queued just before A
exited and was reaped. The connection-time `SO_PEERPIDFD` of the socket pair
still names its creator. Possession of the endpoint does not identify the sender
of a later message; the per-message pidfd does, under the assumptions below.

Josh approved this bounded test in
[board question 23](../../docs/superpowers/records/questions/q23.html). It is
one kernel-behaviour observation for the candidate transport in the
[local supervisor profile](../../openspec/changes/add-linux-host/local-supervisor-profile.md).
It is not an authenticated bridge, a selected transport, or host qualification.

## What ran

[`channel-identity-test.c`](../../contrib/native-hosts/linux/channel-identity-test.c)
creates every process, socket and descriptor it uses: two children from
`clone3(CLONE_PIDFD)` (the parent retains pidfds from creation, so there is no
numeric-PID reuse window) and five private socket pairs (the channel, a receiver without `SO_PASSPIDFD`, the transfer channel and one command socket per child). Children close every
descriptor except stdio, their command socket and their role's endpoints, set
`PR_SET_PDEATHSIG` and a 20 s alarm; the parent has a fixed 30 s alarm. The
test reads only its own `/proc/self/fd`, signals nobody, requests no privilege
(`CapEff` was zero), and changes no namespace or security setting.

Sender identity is compared only by pidfs device/inode identity of the received
pidfd against the retained pidfds, never by numeric PID. The test requires
`PID_FS_MAGIC` and a 64-bit `ino_t`; without pidfs or `SO_PASSPIDFD` it exits
77 rather than using a weaker comparison. Its receiver accepts one bounded
record with exactly one non-negative `SCM_PIDFD`, rejects `MSG_TRUNC`,
`MSG_CTRUNC`, control headers longer than the returned control bytes,
unexpected `SCM_RIGHTS` or other control messages, and closes every installed
descriptor on every path.

## Observations

[Single run](run.txt), exit 0: eleven cases pass.

| Case | Observed |
| --- | --- |
| original-holder | A's message names A, not B |
| queued-before-transfer | A2, queued by A before the transfer and read after it, names A |
| missing-passpidfd | A receiver without `SO_PASSPIDFD` gets no pidfd; rejected |
| reaped-sender | A3, queued before A exited and was reaped, names A's lifetime (a pidfd for an exited process; a kernel error in that slot would be the only other accepted outcome) |
| after-transfer | B1, sent by B on the transferred endpoint, names B, not A |
| unexpected-rights | A message carrying `SCM_RIGHTS` is rejected; both installed descriptors closed |
| payload-truncated | A 64-byte message into a 16-byte record sets `MSG_TRUNC`; rejected |
| control-truncated | A 16-byte control buffer sets `MSG_CTRUNC` and installs no pidfd; rejected |
| peer-snapshot | `SO_PEERPIDFD` names the socket pair's creator (the test parent), not A or B |
| descriptor-cleanup | Three parent descriptors at start and end |

[25 repeated runs](repeat.txt) all exited 0. The [negative control](mutant-after-transfer.diff)
expects A instead of B after the transfer; it [fails that case and exits 1](mutant-run.txt).
[Environment](environment.txt) and [commands](commands.txt) are recorded.

## Review before execution

An independent read-only review of the source preceded execution. It found that
the first draft would have stopped with ERROR at the reaped-sender case
(children exit without the expected reply), that reaped-sender accepted any
rejection, and that the receiver's control parsing could leak descriptors above
a fixed clamp or read past the returned control bytes on a malformed header.
It also suggested `SO_PEERPIDFD` instead of a numeric-PID peer check,
`close_range` in the children, and a correct `errno` on end-of-stream. All were
fixed before the recorded runs; the first draft was never executed.

## What this does not establish

- A matching pidfd names a process lifetime only: not a human, an executable
  image, a role, or permission to disclose data. A process can `exec` a
  different image without changing it.
- A sender with `CAP_SYS_ADMIN` over its PID namespace's owning user namespace
  can supply different credentials, from which the kernel then derives
  `SCM_PIDFD`. No sender here had any capability; that adversary was not tested.
- The reaped-sender result depends on pidfs on this kernel. Older kernels and
  32-bit `ino_t` need separate evidence.
- Queued data outliving its sender is attributed correctly, but the pidfd does
  not order that exit against revocation or effect admission.
- Namespace, ptrace and process-control isolation; protected role provisioning;
  a live issuer and clock; the serialized owner; and the single effect path
  remain unimplemented. No mount, VM, broker, or privileged probe ran.
