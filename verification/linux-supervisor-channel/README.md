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
(answer `select-scm-pidfd`; the answer is recorded on the board, whose answer
files are deliberately kept out of the tree, so `q24.html` is the in-tree
reference), following the observation recorded under
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
| Proof | `PROOF.bend` | [`ALL PROOFS CHECK`](proof-tail.txt) without `--verdict`; with the Lean kernel, [`--verdict` also exited 0](verdict.txt) |

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
`attribute` has no payload parameter, so payload independence is structural, by
signature; the "payload-named principal is ignored" check only confirms that
role 2 maps to principal 102. No Bend test decodes a payload or models a transfer.

Native (27 PASS lines; `transferred_endpoint_attributes_receiver_role` and
`unregistered_sender_unknown` assert the two new scenarios, the others support them):

| Case | Observed |
| --- | --- |
| `transferred_endpoint_attributes_receiver_role` | After an endpoint transfer, the record is attributed to the receiving process's registered role |
| `reaped_role_sender` | Supporting only: a record queued before the sender was reaped is FROM_ROLE 1 or SENDER_ERROR (either accepted) |
| `unregistered_sender_unknown` | Asserts the unprovisioned-sender scenario: no registered lifetime yields `UNKNOWN_SENDER`. That no `from` is attached is structural (`Denied` carries no principal) |
| `missing_sender_without_enable` | Supporting, a receiver-configuration denial: without `SO_PASSPIDFD` there is no sender and nothing is attributed; not the unprovisioned-sender scenario |
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
- The proofs cover the existing laws; this change adds no law. The `--verdict`
  run used a restored BendTT kernel (SHA-256
  `e365eba1741602bb45261aa0eb6bd2c6f5db885d4b9d4cd603a27bc3c5a9ed18`),
  `LEAN_STACK_SIZE_KB=4194304`, on the e0d985be tree, exit 0, `ALL PROOFS CHECK`.
  No GPU was involved; the Bend runs are CPU.
