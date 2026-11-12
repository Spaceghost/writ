# Task 2 report: native supervisor channel receiver

Status: DONE_WITH_CONCERNS

## Files changed
- contrib/native-hosts/linux/supervisor_channel.h (new)
- contrib/native-hosts/linux/supervisor_channel.c (new)
- contrib/native-hosts/linux/supervisor-channel-test.c (new)
- contrib/native-hosts/linux/Makefile (target $(OUT)/supervisor-channel-test, built with -DWRIT_CHANNEL_TESTING)
- contrib/native-hosts/linux/README.md (inventory row)

## Commands
    export OUT=$HOME/tmp/writ-sc-task2/out
    make -C contrib/native-hosts/linux OUT=$OUT $OUT/supervisor-channel-test   # gcc, strict flags, -Werror
    $OUT/supervisor-channel-test
    clang -DWRIT_CHANNEL_TESTING -std=c11 -O2 -g -Wall -Wextra -Werror -Wformat=2 -Wconversion -Wshadow supervisor-channel-test.c supervisor_channel.c   # CLANG_OK, RESULT PASS

## Test output (saved: /home/jadams/tmp/writ-sc-task2/run1.out)
    INFO supervisor-channel-test: owned processes only, timeout 30s
    PASS profile_check_passes: pidfs and SO_PASSPIDFD available
    PASS role_one_attributed: verdict 0 role 1 length 2 (expected 0 role 1)
    PASS role_one_payload: payload ok, length 2
    PASS empty_record_attributed: verdict 0 role 1 length 0 (expected 0 role 1)
    PASS empty_record_length: length 0
    PASS rights_rejected: verdict 6 role 0 length 0 (expected 6 role 0)
    PASS reject_then_accept: rights record rejected, next record from role 1
    PASS payload_truncated: verdict 4 role 0 length 0 (expected 4 role 0)
    PASS control_truncated: verdict 5 role 0 length 0 (expected 5 role 0)
    PASS unregistered_sender_unknown: verdict 1 role 0 length 2 (expected 1 role 0)
    PASS missing_sender_without_enable: verdict 2 role 0 length 0 (expected 2 role 0)
    PASS duplicate_role_rejected: duplicate lifetime/index, index 0, non-pidfd: EINVAL, table unchanged
    PASS role_table_full: ninth add: ENOSPC, table unchanged
    PASS reaped_role_sender: role 1 after reaping
    PASS transferred_endpoint_attributes_receiver_role: verdict 0 role 2 length 2 (expected 0 role 2)
    PASS descriptor_cleanup: 3 descriptors at start and 3 at end
    RESULT PASS (0 failures)

Repeat tally: 25/25 runs exit 0 (/home/jadams/tmp/writ-sc-task2/repeat.txt).

## Mutants (diffs and outputs in /home/jadams/tmp/writ-sc-task2/mut/<name>.diff, .out; originals /home/jadams/tmp/writ-sc-task2/orig.c)
- no-rights-rejection: exit 1, FAIL rights_rejected, reject_then_accept
- first-role-always: exit 1, FAIL unregistered_sender_unknown, transferred_endpoint_attributes_receiver_role
- leak-received-pidfd (skip close of the received pidfd): exit 1, FAIL descriptor_cleanup (3 -> 12)
- no-close-rights (extra, SCM_RIGHTS fds not closed): exit 1, FAIL descriptor_cleanup (3 -> 5)
- leak-duplicate-pidfd (skip close of the extra pidfd in the pidfds>1 branch): exit 0, SURVIVES

## Versions
kernel 7.2.9-1-MANJARO; gcc (GCC) 16.2.1 20260810; ldd (GNU libc) 2.44; clang version 23.1.1

## Deviations and concerns
- The brief's "skipping close of the duplicate pidfd must fail descriptor_cleanup" is not achievable as worded:
  the kernel will not deliver two SCM_PIDFD values for one record and a sender cannot forge the cmsg, so the
  WRIT_DUPLICATE_SENDER branch is unreachable from a test using only owned processes. I killed the
  equivalent leak (received pidfd not closed) instead; the literal duplicate-branch mutant survives. The branch
  is kept as defensive fail-closed code and is reviewed-only, not tested.
- No test for WRIT_UNEXPECTED_CONTROL or the SENDER_ERROR negative/non-pidfs paths (kernel cannot be made to
  produce them unprivileged); reaped_role_sender observed role 1 here, SENDER_ERROR also accepted per brief.
- writ_channel_receive is non-blocking (MSG_DONTWAIT, errno EAGAIN when empty); callers poll. Brief did not say.
- Extra checks beyond the brief: role_one_payload, empty_record_length.
- Verdict payload/length is zeroed for rejected verdicts; length is meaningful for FROM_ROLE/UNKNOWN_SENDER only.

## Fix round 1

Correction to the "Deviations" above: UNEXPECTED_CONTROL and the negative-pidfd SENDER_ERROR are reachable unprivileged
(SO_PASSCRED; own RLIMIT_NOFILE), and the duplicate and non-pidfs branches are reachable through a classifier seam. Only the
pidfs `dev` comparison remains reviewed-only.

| Finding | Change | Evidence |
|---|---|---|
| I-1 | `receive_impl` split: `recvmsg` plus static `classify(msghdr)`; `writ_channel_classify` exposed under WRIT_CHANNEL_TESTING | PASS duplicate_sender_closes_both, duplicate_sender_one_header, non_pidfs_sender_error, foreign_level_control, overclaimed_header (CONTROL_TRUNCATED, in-bounds fd closed), each with fd count unchanged; mutant leak-duplicate-pidfd now exit 1 |
| I-2 | cases unexpected_control_passcred (SO_PASSCRED), sender_error_emfile (RLIMIT_NOFILE set to lowest free fd, restored; exit 77 if setrlimit refused) | PASS lines in /home/jadams/tmp/writ-sc-task2/run2.out |
| I-3 | EOF (got 0, no control, no trunc flags) returns -1/EPIPE, no verdict; documented in header incl. enable-before-queue precondition | PASS peer_closed; mutant eof-as-record fails peer_closed |
| I-4 | writ_roles_add returns EINVAL for count > capacity; classify yields SENDER_ERROR | PASS duplicate_role_rejected (corrupt table assertion), corrupt_table_fails_closed; mutants roles-add-no-count-check, unchecked-count fail |
| M-1 | record verdict initialised to WRIT_SENDER_ERROR | peer_closed checks verdict stays SENDER_ERROR |
| M-2 | header documents non-blocking, EAGAIN | header |
| M-3 | payload_at_max_attributed (4096 bytes, FROM_ROLE) | PASS |
| M-4 | reviewed-only dev comment in classify, header and README row | source |
| M-5 | receive helpers check the fd count around every receive and name the case on a leak | mutant leak-received-pidfd now names many cases |

Result: 27 PASS lines, RESULT PASS; 25/25 repeats exit 0 (/home/jadams/tmp/writ-sc-task2/repeat2.txt, output /home/jadams/tmp/writ-sc-task2/run2.out). gcc and clang -Werror strict builds clean;
the library alone also compiles clean without WRIT_CHANNEL_TESTING.
Mutants (diffs/outputs /home/jadams/tmp/writ-sc-task2/mut2/): no-rights-rejection, first-role-always, leak-received-pidfd, leak-duplicate-pidfd, no-close-rights,
eof-as-record, unchecked-count, roles-add-no-count-check, no-nonpidfs-check: all exit 1.
Concern: the cmsg buffer builder in the test is hand-made; classify trusts msg_control/msg_controllen as the kernel would set them.
