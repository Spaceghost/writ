# Task 2 re-review of fix round 1 (6bf70f8c..3f15722c)

Scratch: ~/tmp/writ-sc-rereview2/. Built with the Makefile target (strict flags, -Werror, OUT outside checkout): 27 PASS, RESULT PASS; 10 repeats all exit 0.

| Finding | Status | Note |
|---|---|---|
| I-1 | Addressed | `writ_channel_classify` is under WRIT_CHANNEL_TESTING only. A plain `-Wall -Wextra -Werror` compile without the macro leaves only a local `classify` symbol, with no exported seam or `with_control`. Production and the seam share the one static `classify`. The four required cases pass with the test's own fds. fd counts are balanced. |
| I-2 | Addressed | `unexpected_control_passcred` and `sender_error_emfile` use real sockets. RLIMIT is lowered only across the single receive and restored before any error check or `die`, so a failing case cannot leave it lowered. Exit 77 if setrlimit is refused. |
| I-3 | Addressed | EOF returns -1/EPIPE with no verdict. `peer_closed` passes. The enable-before-queue precondition is documented. The enum is untouched. |
| I-4 | Addressed | `writ_roles_add` returns EINVAL for count > capacity. classify yields SENDER_ERROR and closes the pidfd. Both are tested. |
| M-1 | Addressed | |
| M-2 | Addressed | In the header only, as before. |
| M-3 | Addressed | |
| M-4 | Addressed | Comment in classify and header. |
| M-5 | Addressed | |

Specific checks:
- Classifier closes every installed fd on every path: each branch closes SCM_PIDFD and SCM_RIGHTS values within the returned bytes, and `pidfd` is closed after the verdict. Only fds in a foreign-level cmsg cannot be interpreted. Same as before.
- Enum order is unchanged and matches `ChannelReject` (LocalChannel.bend:16-23).
- Mutants rerun: `eof-as-record` fails `peer_closed` (exit 1). `leak-duplicate-pidfd` fails 7 cases including `descriptor_cleanup` (exit 1).

New findings:
- Nit (cosmetic): supervisor_channel.h:27-30. The struct writ_roles comment has a run-on, over-long line after the M-4 edit. Reflow it.
