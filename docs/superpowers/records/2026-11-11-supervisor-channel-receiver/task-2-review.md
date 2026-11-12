# Task 2 review: native supervisor channel receiver (1cdc630e..6bf70f8c)

Reviewer scratch: ~/tmp/writ-sc-review2/ (build in `out/`, probe in `probe/`).
Kernel 7.2.9-1-MANJARO; gcc 16.2.1; clang 23.1.1.

## What I ran

- `make -C contrib/native-hosts/linux OUT=$HOME/tmp/writ-sc-review2/out $HOME/tmp/writ-sc-review2/out/supervisor-channel-test`
  (Makefile strict flags, `-Werror`): all 16 PASS lines plus RESULT PASS, exit 0. Then 20 repeats, all exit 0.
- clang with `-Wall -Wextra -Werror -Wformat=2 -Wconversion -Wshadow -Wsign-conversion`: built clean.
- gcc with `-fsanitize=address,undefined`: RESULT PASS, no reports.
- My own probe (`~/tmp/writ-sc-review2/probe/probe.c`, linked against the unmodified `supervisor_channel.c`).
  It uses only its own process and socket pairs.

  | Probe | Observed |
  |---|---|
  | receiver also sets `SO_PASSCRED` | verdict 7 `WRIT_UNEXPECTED_CONTROL`, fd count 4->4 |
  | receiver at `RLIMIT_NOFILE` (lowered unprivileged) | rc 0, verdict 8 `WRIT_SENDER_ERROR` (kernel wrote a negative SCM_PIDFD) |
  | peer closed, queue empty | rc 0, verdict 2 `WRIT_MISSING_SENDER`, and the same on every later call |
  | record queued before `writ_channel_enable` | verdict 2 `WRIT_MISSING_SENDER` |
  | 20 SCM_RIGHTS fds (overflows the 64-byte buffer) | verdict 5 `WRIT_CONTROL_TRUNCATED`, fd count 8->8 |
  | empty record on an enabled socket | verdict 0, role 1 |

## Spec compliance: ❌

Met:
- Files, Makefile target `$(OUT)/supervisor-channel-test` (built with `-DWRIT_CHANNEL_TESTING`), and the README inventory row.
- Header interface matches the brief exactly: both macros, the enum with its order, `struct writ_roles`, `struct writ_channel_record`, the four functions, and the `#ifdef WRIT_CHANNEL_TESTING` seam.
- The enum values from `WRIT_MISSING_SENDER` to `WRIT_SENDER_ERROR` map 1:1, in order, to `ChannelReject` (`hosts/linux/monitor/LocalChannel.bend:16-23`).
- Every named test case is present and prints `PASS <name>`. Exit codes are 0, 1 and 77, and the timeouts are in place.
- The receive logic is lifted from `channel-identity-test.c` `receive_record`, including `short_control`, with the same verdict precedence. Comments state that the module translates facts only.
- Builds strict under gcc and clang. 20+ repeats all exit 0. Commit message as specified.
- Three of the four required mutants fail as intended. The implementer's mutant records are in `~/tmp/writ-sc-task2/mut/`.

Not met:
- **Step 5, duplicate-pidfd mutant.** The brief says skipping the close of the duplicate pidfd "must fail `descriptor_cleanup`" and "each mutant must exit 1". The mutant survives (exit 0). The implementer substituted a different mutant, the received pidfd not being closed, and reported the gap honestly. But the gap is closable without privilege through a parse seam (finding I-1), so this should not be accepted as reviewed-only.

## Quality: Changes requested

The descriptor handling is sound on every path I could reach:
- CMSG iteration is bounded by the returned `msg_controllen`: glibc `CMSG_NXTHDR`, plus the explicit `control_end` clamp for the first header.
- `cmsg_len < CMSG_LEN(0)` is rejected before any data is read. All size arithmetic is in `size_t` with no signed overflow.
- `MSG_CMSG_CLOEXEC`, `MSG_TRUNC` and `MSG_CTRUNC` are handled.
- Every SCM_PIDFD and SCM_RIGHTS value inside the returned bytes is closed. The single pidfd is closed after classification on all verdicts.
- `recvmsg` failure installs nothing.
- A rejected record is consumed and its payload is zeroed. `reject_then_accept` proves the next record is parsed cleanly.
- `writ_roles_add` validates before it mutates, so the table is unchanged on every error. It rejects index 0, a duplicate index, a duplicate dev/ino and non-pidfs descriptors, and matches on both dev and ino.

The problems are an EOF ambiguity, two test-coverage claims that are wrong, and unchecked `count` indexing.

## Findings

### Important

**I-1. Duplicate-sender and malformed-control branches are untested; add a parse seam.** `supervisor_channel.c:104-107,116-123`
- `WRIT_DUPLICATE_SENDER`, the extra-pidfd close at :107, a non-pidfs fd in an SCM_PIDFD slot, a non-SOL_SOCKET cmsg, and a first header that claims more than `msg_controllen` cannot be produced by the kernel. The current seam only shrinks the buffer that `recvmsg` fills.
- Fix: split `receive_impl` into `recvmsg` plus a static `classify(struct msghdr *msg, const struct writ_roles *, struct writ_channel_record *)`.
- Expose it under `WRIT_CHANNEL_TESTING` as, for example, `writ_channel_classify_control(void *control, size_t controllen, int msg_flags, size_t got, const struct writ_roles *, struct writ_channel_record *)`. The test builds the cmsg buffer itself, filling every slot with descriptors it owns: `dup()` of its own `pidfd_open(getpid())`, or `/dev/null`.
- Add the cases `duplicate_sender_closes_both` (two SCM_PIDFD cmsgs, or two ints in one; verdict 3; fd count unchanged), `non_pidfs_sender_error` (a `/dev/null` dup in the SCM_PIDFD slot; verdict 8; fd closed), `foreign_level_control` (verdict 7) and `overclaimed_header` (verdict 5; the in-bounds fds are still closed).
- This kills the brief's duplicate-pidfd mutant as written. The production path still uses the same `classify`, so this adds no alternate route. It needs no privilege and no crafted socket message.

**I-2. `WRIT_UNEXPECTED_CONTROL` and the negative-pidfd `WRIT_SENDER_ERROR` are reachable unprivileged, but the report says they are not.** Test `supervisor-channel-test.c` (missing cases); report "Deviations".
- The probe shows that `SO_PASSCRED` on the test's own receiving socket yields SCM_CREDENTIALS plus SCM_PIDFD, giving verdict 7 with the pidfd still closed.
- Lowering the receiver's own `RLIMIT_NOFILE` to its current fd count makes the kernel write a negative SCM_PIDFD (-EMFILE), giving verdict 8.
- Fix: add `unexpected_control_passcred`. It also covers the multi-cmsg close path.
- Add `sender_error_emfile`, run in a forked owned child, or in the parent with the old limit restored and the fd count checked. It needs PDEATHSIG, an alarm, and exit 77 if `setrlimit` is refused.
- Correct the report. Only the non-pidfs `fstatfs` path and the duplicate path are kernel-unreachable, and I-1 covers both.

**I-3. End-of-stream is reported as a consumed `WRIT_MISSING_SENDER` record.** `supervisor_channel.c:84-85` and the header contract at `supervisor_channel.h:68-71`
- On `SOCK_SEQPACKET`, when the peer has closed and the queue is empty, `recvmsg` returns 0 with no control. The probe gets rc 0 and verdict `MISSING_SENDER` on every call.
- A poll-driven supervisor that hits this will spin forever (POLLIN stays set on a hung-up socket). It will also feed spurious `Malformed{MissingSender}` facts to Bend. This breaks the documented "0 when one record was consumed".
- Fix: when `got == 0 && msg.msg_controllen == 0 && (msg.msg_flags & (MSG_TRUNC|MSG_CTRUNC)) == 0`, return a distinct end-of-stream result. Either `-1` with `errno = EPIPE`, which fits the brief's "0 or -1 with errno", or a documented positive return.
- Add `peer_close_reports_end`.
- An empty record queued before enable becomes indistinguishable from EOF. That is acceptable, because the brief makes enabling before any record is queued a precondition. Say so in the header.

**I-4. `roles->count` is used as a loop bound without checking it against the array size.** `supervisor_channel.c:59` (before the capacity check at :63) and `supervisor_channel.c:130`
- `struct writ_roles` is caller-writable. An uninitialized table, or a `count` above `WRIT_CHANNEL_ROLES`, reads past `role[]` in both functions.
- AGENTS.md forbids unchecked array indexes.
- Fix: in `writ_roles_add`, return `EINVAL` when `roles->count > WRIT_CHANNEL_ROLES`, before the duplicate scan. In classification, treat that as `WRIT_SENDER_ERROR`, or scan `min(count, WRIT_CHANNEL_ROLES)` and fail closed.
- Add an assertion to `duplicate_role_rejected`.

### Minor

**M-1. A failed receive leaves `out->verdict = WRIT_UNKNOWN_SENDER`.** `supervisor_channel.c:77`
- `UnknownSender` is a non-reject fact. A caller that ignores the `-1` would hand Bend an unknown-sender fact with an empty payload.
- Initialise it to `WRIT_SENDER_ERROR` so the record fails closed.

**M-2. The non-blocking receive is a contract choice, not a hidden change, but it is recorded only in the header.**
- `MSG_DONTWAIT` is inherited from the reviewed reference, is documented at `supervisor_channel.h:68-71`, and suits a poll-driven supervisor. I accept it as the default.
- Record it in the plan/brief interface (EAGAIN when empty) so Task 3+ callers do not assume blocking.

**M-3. No boundary test at exactly `WRIT_CHANNEL_PAYLOAD_MAX`.** `supervisor-channel-test.c:281-283`
- Add `payload_at_max_attributed`: 4096 bytes gives `FROM_ROLE`, length 4096. Paired with the existing 4097-byte case, this pins the bound from both sides.

**M-4. dev discrimination in role matching is reviewed-only.** `supervisor_channel.c:131`
- Every pidfs inode shares one `st_dev`, so a mutant that matches on ino alone would survive.
- No owned-process test can produce a second pidfs dev. State this as a reviewed-only gap in the report and the README row; it needs no code change.

**M-5. `descriptor_cleanup` is a single end-to-end count.** `supervisor-channel-test.c:337-340`
- It does detect leaks: the implementer's mutants went from 3 to 12 and from 3 to 5. But it cannot say which case leaked.
- Optional: wrap each rejection case in a before/after count, as the probe does, so a regression names its branch.

## Test hygiene (q23)

Compliant. Children are created with `clone3(CLONE_PIDFD)` and call `PR_SET_PDEATHSIG(SIGKILL)` with a `getppid` check and a 20s alarm. They close everything except a sorted keep list (stdio, the command socket, and the listed endpoints) with `close_range`. The parent has a 30s alarm and exits 77 when clone3, pidfs or SO_PASSPIDFD is missing. Children are reaped through `waitid(P_PIDFD)` and checked for a clean exit. The test sends no signals to other processes and uses no privilege, mounts or namespaces.
