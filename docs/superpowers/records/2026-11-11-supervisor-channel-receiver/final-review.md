# Final whole-branch review: lane/supervisor-channel-receiver (93f78e0d..352a8598)

Verdict: **Fix first** (one Important finding; the fix is small. Accepting it as a recorded gap would also be defensible, because nothing calls the receiver yet.)

## What I ran (scratch: ~/tmp/writ-sc-final-review/)
- `bend hosts/linux/monitor/LocalChannelTests.bend`: 8 PASS, "LocalChannel: 8 checks passed".
- `bend Tests.bend` + `check_core.py`: "ALL LIBRARY TESTS PASSED", "Verified 3136 core checks", rc 0. 3136 = 3128 + 8.
- `bend PROOF.bend`: ALL PROOFS CHECK, rc 0. I did not rerun `--verdict`. The recorded verdict was run on e0d985be. e0d985be..352a8598 changes only docs, verification records and the manifest, and no `.bend` file, so the verdict still applies to this tree's proofs.
- `make ... supervisor-channel-test` built with the Makefile's strict flags. The run gave 27 PASS, RESULT PASS, exit 0 (Linux 7.2.9, CapEff 0).
- `openspec validate --all --strict --no-interactive` (1.16.0): 45 passed, 0 failed.
- `git diff --check 93f78e0d 352a8598`: clean.
- Manifest: I recomputed sha256 over every file tracked at 352a8598 (from `git archive`), except `verification/source-sha256.txt`, sorted. All 7145 lines match the committed file exactly.
- The C source hashes in `environment.txt` match the blobs at 352a8598. The C sources have not changed since f644064e.
- Probe (~/tmp/writ-sc-final-review/probe/p.c): with `SO_PASSRIGHTS` = 0 on the receiver, the sender's `sendmsg` with `SCM_RIGHTS` fails with `EPERM` on this kernel.

## Task 3 fix round 1 (352a8598): verified
1. `reaped_role_sender` is supporting only: traceability/linux-host.md:139-141 and README.md:61 both say so, and both state that FROM_ROLE 1 and SENDER_ERROR are accepted. Addressed.
2. The Bend payload check is described as structural, by signature, and as confirming only that role 2 maps to 102: traceability :142-146, README :50-53. Addressed.
3. `missing_sender_without_enable` is described as a receiver-configuration denial: traceability :153-155, README :63. Addressed.
4. "No `from`" is described as structural: traceability :151-153, README :62. Addressed.
5. q24.html is cited, and the docs say the answer files are kept out of the tree: profile :94-97, README :19-23. q24.html exists and contains option `select-scm-pidfd`. Addressed.
6. The Lean verdict is recorded: verdict.txt, commands.txt (kernel SHA-256, stack size, tree), README :113-117 and VERIFICATION.md :1168. Addressed. The task-3 review's finding 6, the mapped-by-name caveat, was dropped correctly; the mappings now match the test bodies (supervisor-channel-test.c:526-538, :440-445).

## Cross-task checks
- Enum mapping: C `WRIT_MISSING_SENDER..WRIT_SENDER_ERROR` (supervisor_channel.h:28-34) corresponds 1:1, in order, to `ChannelReject` (LocalChannel.bend:16-23). The C FROM_ROLE and UNKNOWN_SENDER values correspond to `FromRole` and `UnknownSender`. OK.
- Role rules: C role indices are `uint32_t`, nonzero and unique, with at most 8 entries. Bend roles are `Nat`, nonzero and unique (`valid_roles`). Every table that `writ_roles_add` can produce therefore satisfies Bend's index rules, so C cannot admit an index set that Bend's rules reject. C also rejects a second index for an already-registered lifetime, which Bend has no notion of (see M-2). If a caller builds the public struct directly and skips `writ_roles_add`, it could emit FROM_ROLE 0. Bend's `lookup` on a valid map denies that as UnknownRole, so it fails closed. The count is bounds-checked before every loop over `role[]` (supervisor_channel.c:155, :216). No unchecked index.
- EOF, EAGAIN and errors: each returns -1 and sets the output verdict to `WRIT_SENDER_ERROR` with the payload zeroed (c:248-260). EOF is recognised only when `got == 0`, `controllen == 0` and neither truncation flag is set. A failed pidfd install is reported either as a negative value (SENDER_ERROR) or as MSG_CTRUNC (CONTROL_TRUNCATED), so neither is mistaken for EOF. Payload bytes are passed on only for FROM_ROLE and UNKNOWN_SENDER, and Bend denies UNKNOWN_SENDER. I found no path where C emits FROM_ROLE without a pidfs identity match.
- Native/Bend line: C classifies kernel facts and returns a role index. Naming the principal, validating the map and denying are all done in Bend (`attribute`). The C ordering of reject reasons is classification, not policy. I found no grant, label or accounting decision in C.
- Overclaims: none found. On the GPU: the README says "No GPU was involved; the Bend runs are CPU." Host qualification, wiring, the capable-sender adversary, exec, isolation and `dev` matching are all stated as unproven or reviewed-only in the README (:81-117), the traceability (:157-159), VERIFICATION.md (:1164-1169), the profile (:97-104) and the native README row. The spec scenarios stay in `openspec/changes/` and are described as receiver-level evidence only.
- Source inventory: contrib/native-hosts/linux/README.md:141 lists all three new files. The Makefile target is outside `all` and enforces OUT outside the checkout.

## Findings

### I-1 (Important): sender-chosen `SCM_RIGHTS` files are installed in the supervisor and closed there, which a sender can use to block the supervisor
- Where: contrib/native-hosts/linux/supervisor_channel.c:144-148 (`writ_channel_enable` sets only `SO_PASSPIDFD`) and :200-202 (`close(value)` on each received right).
- Failure scenario: any process holding the endpoint can send `SCM_RIGHTS`. That includes a process the endpoint was passed to, with no role. The kernel installs those files in the supervisor, which then closes them. The sender can send its last reference, so the supervisor's `close` becomes the final close and runs the file's flush and release in the supervisor's context. If the file is on a FUSE mount the sender serves, which is possible unprivileged through fusermount3, `close` sends FUSE_FLUSH and waits for the attacker to reply. The supervisor's receive then hangs indefinitely. The profile says "cleanup and revocation remain available" (local-supervisor-profile.md:170). A supervisor stuck in this receive cannot revoke or STOP. Any rights beyond what the control buffer holds are released by the kernel on return to user space in the supervisor task as well. The classification itself is correct (UNEXPECTED_RIGHTS); the problem is availability.
- Fix: in `writ_channel_enable`, also set `SO_PASSRIGHTS` = 0 (Linux 6.16+, value 83). The kernel then refuses `SCM_RIGHTS` at the sender's `sendmsg` with `EPERM`; the probe confirmed this on 7.2.9. Make `writ_channel_profile_check` return ENOTSUP when the option is unavailable. Keep the close-on-receipt path and the classifier seam as defense in depth. Change `rights_rejected`/`reject_then_accept` to expect the sender's EPERM. The classifier branch stays covered by a built buffer. Re-run the mutants and recapture. If the fix is deferred, add this hazard to README "What this does not establish" and to the traceability gaps.

### M-1 (Minor): the receiver does not check the socket type
- Where: supervisor_channel.c:144-148 and :243-264.
- Failure scenario: the bounded-record guarantees ("one record", MSG_TRUNC meaning payload truncation) hold only for `SOCK_SEQPACKET`, which the header and README promise. If a caller passes a `SOCK_STREAM` socket, an oversize write is split across several receives, each attributed, and MSG_TRUNC is never set. If a caller passes an unconnected `SOCK_DGRAM` socket, any process that can reach its address can send. Each of these is a caller error, but nothing stops it.
- Fix: in `writ_channel_enable`, check `SO_DOMAIN == AF_UNIX` and `SO_TYPE == SOCK_SEQPACKET` with getsockopt, and return EINVAL otherwise. Add one negative case.

### M-2 (Minor): the "one role per lifetime" rule exists only in C and is not documented as a well-definedness rule
- Where: supervisor_channel.c:159 and supervisor_channel.h:62-64. LocalChannel.bend has no counterpart.
- Failure scenario: a reader could take the EINVAL for a lifetime that is already registered as separation-of-duties policy enforced natively, which AGENTS.md forbids. It is really there so that the first-match lookup in classify (c:225-231) is unambiguous. If a future bridge needs source and destination roles to be distinct processes, that rule must live in Bend.
- Fix: add one sentence to the header saying the rejection keeps the lifetime-to-index translation a function and is not an authority rule. Also add a line to the README or traceability noting that Bend's `RoleMap` and the C table are provisioned separately, with no consistency check, until a bridge exists.

### M-3 (Minor): the README's example does not match what the test does
- Where: verification/linux-supervisor-channel/README.md:3-5.
- Failure scenario: the README says "a supervisor holds one endpoint ... It passes that endpoint to a second process B". In the test (supervisor-channel-test.c:526-538), role-1 child A sends a record, passes its own endpoint to role-2 child B and is reaped; B's record is then attributed to role 2. The example names B's role as the outcome but leaves out that B is itself a provisioned role and that A did the transfer. A reader could think an unprovisioned recipient was tested at the transfer step. An unprovisioned sender was tested separately, on another socket (`unregistered_sender_unknown`).
- Fix: change the example to say that role process A passes its endpoint to role process B, and that the record is attributed to B's role 2. Mention that a recipient with no role is covered by `unregistered_sender_unknown`.

### M-4 (Minor): one line in VERIFICATION.md is not wrapped, and the verdict clause is attached to the wrong sentence
- Where: VERIFICATION.md:1167-1168.
- Failure scenario: "The two are not connected, and the existing-law proof also passed with `--verdict`." joins two unrelated facts. Line 1168 is about 140 characters, where the surrounding text wraps at about 80.
- Fix: make the verdict its own sentence and rewrap. Doing so changes the manifest entry for VERIFICATION.md, so regenerate the manifest afterwards.

### M-5 (Minor, informational): the new native test runs only manually
- Where: contrib/native-hosts/linux/Makefile:48-51. .github/workflows contains no reference to it.
- Failure scenario: the native CI lane will not catch a regression in the receiver. This follows the existing precedent: `channel-identity-test` is not in CI either.
- Fix: optional. Either add it to the native CI lane with a 77 (unsupported) tolerance for kernels without pidfs or `SO_PASSPIDFD`, or say in the evidence README that it is run manually only.
