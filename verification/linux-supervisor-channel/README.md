# Supervisor channel receiver

Example: a supervisor holds one `AF_UNIX` `SOCK_SEQPACKET` endpoint that it
provisioned for the source-read role. It passes that endpoint to a second
process B. B writes a record on it. The receiver reads the kernel's
per-message `SCM_PIDFD`, compares its pidfs device/inode identity with the
retained lifetime registered for each role, and attributes the record to the
role registered for B's lifetime, not to the role that owned the endpoint
before the transfer. A sender with no registered lifetime is classified
`UNKNOWN_SENDER`, and the Bend side denies it without attaching any `from`.
Malformed control data, truncation, unexpected `SCM_RIGHTS`, duplicate or
failed pidfds and an inconsistent role table all fail closed with a named
verdict.

Current gap: this is a receiver and a Bend attribution function, each tested
alone. Nothing connects them. There is no supervisor, no Bend pipe frame, no
session, no authenticated bridge, and no host qualification.

Josh selected this transport in
[board question 24](../../docs/superpowers/records/questions/q24.html)
(answer `select-scm-pidfd`), following the observation recorded under
[board question 23](../../docs/superpowers/records/questions/q23.html) and the
[owned-process channel identity record](../linux-channel-identity/README.md).
The [local supervisor profile](../../openspec/changes/add-linux-host/local-supervisor-profile.md)
now says the transport is *selected*; it does not say *implemented end to end*.

## What ran

| Part | Source | Result |
| --- | --- | --- |
| Bend attribution | [`LocalChannel.bend`](../../hosts/linux/monitor/LocalChannel.bend), [`LocalChannelTests.bend`](../../hosts/linux/monitor/LocalChannelTests.bend) | 8 checks, [focused run](bend-focused.txt) |
| Native receiver | [`supervisor_channel.c`](../../contrib/native-hosts/linux/supervisor_channel.c), [`.h`](../../contrib/native-hosts/linux/supervisor_channel.h), [`supervisor-channel-test.c`](../../contrib/native-hosts/linux/supervisor-channel-test.c) | 27 cases, [one run](native-run.txt), exit 0 |
| Full Bend suite | `Tests.bend` | `ALL LIBRARY TESTS PASSED`; [`check_core.py` verified 3136 core checks](bend-suite-tail.txt) |
| Proof | `PROOF.bend` | [`ALL PROOFS CHECK`](proof-tail.txt), without `--verdict` |

The test creates every process, socket and descriptor it uses, requests no
privilege (`CapEff` was zero), signals nobody and mounts nothing. It requires
pidfs and `SO_PASSPIDFD`, and exits 77 rather than use a weaker comparison.
[Commands](commands.txt) and [environment](environment.txt) (kernel, gcc, clang,
glibc, capabilities, source and binary hashes) are recorded. The tail of the
Bend suite and the proof output are recorded rather than the full logs.

## Observations

Bend (`LocalChannelTests.bend`): a provisioned role attributes to its
principal; an unknown role index, an unknown sender, each malformed reason and a
duplicate or zero role index deny; an attributed source role submits a source
approval; a destination role cannot submit source and leaves state unchanged;
a principal named in the payload is ignored.

Native (27 PASS lines; the names below are the cases that carry the two new
scenarios):

| Case | Observed |
| --- | --- |
| `transferred_endpoint_attributes_receiver_role` | After an endpoint transfer, the record is attributed to the receiving process's registered role |
| `reaped_role_sender` | A record queued by a role process that was then reaped is still attributed to that role |
| `unregistered_sender_unknown` | A sender with no registered lifetime yields `UNKNOWN_SENDER` |
| `missing_sender_without_enable` | A receiver without `SO_PASSPIDFD` gets no sender and does not attribute |
| `rights_rejected`, `reject_then_accept` | `SCM_RIGHTS` is rejected, the installed descriptors are closed, and a later good record is accepted |
| `payload_truncated`, `control_truncated`, `payload_at_max_attributed` | `MSG_TRUNC` and `MSG_CTRUNC` fail closed; a record of the 4096-byte maximum is attributed |
| `unexpected_control_passcred` | `SCM_CREDENTIALS` (real kernel control) is rejected as unexpected control |
| `sender_error_emfile` | A pidfd the kernel could not install (descriptor limit reached) is a sender error |
| `duplicate_sender_*`, `non_pidfs_sender_error`, `foreign_level_control`, `overclaimed_header` | Classifier branch cases, fed test-built control buffers (see limits) |
| `corrupt_table_fails_closed`, `duplicate_role_rejected`, `role_table_full` | A bad role table or a duplicate or excess role is rejected |
| `peer_closed` | End-of-stream returns -1 with `EPIPE` and produces no verdict |
| `descriptor_cleanup` | Descriptor count is unchanged at end; every receive helper also checks the count |

[20 repeated runs](native-repeat.txt): all exited 0 with `RESULT PASS (0 failures)`.

[Mutants](mutant-results.txt) (each [diff](mutants/) is against
`supervisor_channel.c`, with its [output](mutants/)): all nine exit 1 and fail
at least one named case. `no-nonpidfs-check` and `no-rights-rejection` were
built without `-Werror` because the mutation leaves an unused or
maybe-uninitialised variable. The mutants were re-run on this tree.

## What this does not establish

- No capable-sender test. A sender with `CAP_SYS_ADMIN` over its PID
  namespace's owning user namespace can supply different credentials, from
  which the kernel derives `SCM_PIDFD`. No sender here had any capability;
  `CapEff` was zero.
- No exec decision. A matching pidfd names a process lifetime only, not a
  human, an executable image, a role, or permission to disclose data. A process
  can `exec` another image without changing it.
- No namespace, ptrace or process-control isolation, and no protected role
  provisioning. The test registers roles itself; nothing here binds a role to a
  trusted program.
- No supervisor wiring and no Bend pipe frame. The C receiver and the Bend
  `LocalChannel` attribution are not connected; no `Issuance.from` is built
  from a received record.
- No host qualification, no live issuer or clock, no serialized owner, and no
  ordering of a sender's exit against revocation or effect admission. Queued
  data outliving its sender is attributed to that sender's lifetime only.
- Matching the pidfs `dev` is reviewed-only: unprivileged pidfds share one
  device, so no owned-process test can show that `dev` is compared. The
  `ino` comparison is exercised.
- The classifier branch cases (`duplicate_sender_*`, `non_pidfs_sender_error`,
  `foreign_level_control`, `overclaimed_header`) use control buffers built by
  the test, so they trust `msg_control` and `msg_controllen` as the kernel
  would set them. Kernel-produced control is covered only by the cases that go
  through a real socket.
- The receive is non-blocking: no record returns -1 with `EAGAIN`. End-of-stream
  returns -1 with `EPIPE` and produces no verdict, so a caller cannot read
  closure as a denied or attributed record. `SCM_PIDFD` must be enabled before
  messages are queued.
- One kernel (Linux 7.2.9), one architecture, 64-bit `ino_t`. Older kernels and
  32-bit `ino_t` need separate evidence. No Genode, Windows or Drift evidence.
- The proof ran without `--verdict` (no Lean kernel available here), so it
  checks the proof terms but not mathematical validity. No GPU was involved;
  the Bend runs are CPU.
