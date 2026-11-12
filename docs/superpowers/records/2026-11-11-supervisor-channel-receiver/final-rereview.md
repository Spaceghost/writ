# Final re-review of fix pass 352a8598..f0a6cc97

Tally: I-1, M-1, M-2, M-3, M-4, M-5 and the nit are all Addressed. 0 Not addressed. 0 new defects.

## Checks run (scratch: ~/tmp/writ-sc-final-rereview/)
- Build with the Makefile's strict flags (-Wall -Wextra -Werror -Wformat=2 -Wconversion -Wshadow), OUT outside the checkout: clean. 5 runs, all exit 0, 29 PASS + RESULT PASS.
- `openspec validate --all --strict --no-interactive`: 45 passed, 0 failed.
- `git diff --check 352a8598 f0a6cc97`: clean.
- Manifest recomputed from HEAD blobs (the working tree has uncommitted edits to the lane's activity.log and progress.md, which is not part of the commit): 7149 lines, identical to verification/source-sha256.txt.
- Counts: 29 PASS in native-run.txt and in my runs. native-repeat.txt shows 20 runs, all rc 0. mutant-results.txt lists 11 mutants, all exit 1, with 11 .diff files. README.md:35, :75, :78 and VERIFICATION.md:1166 agree.

## Per finding
- I-1 Addressed.
  - writ_channel_enable sets SO_PASSRIGHTS=0 first, and SO_PASSPIDFD only after that (supervisor_channel.c:~52-71). So there is no window where PASSPIDFD is on and rights are still allowed. A failure after the rights step leaves the socket with rights off, which is the safe state, and enable returns -1.
  - Nothing is queued before enable, so nothing can reach the classifier with rights in that order. Rights-first is correct and needs no change.
  - profile_check maps ENOPROTOOPT to ENOTSUP, and the test exits 77. The classifier reject/close path is kept, and `unexpected_rights_classified` covers it through a built buffer.
  - Sender-side assertion: child op 'r' replies 'k' only if sendmsg failed and errno == EPERM (test.c:119). The parent then calls writ_channel_receive and requires rc == -1, errno == EAGAIN (nothing queued) and an fd balance (test.c:~439-449). The reject_then_accept case reuses the same pattern.
  - The mutant drop-passrights fails rights_rejected and reject_then_accept. The comment giving the FUSE-close-stalls-revocation reason is in both the .c and the .h.
- M-1 Addressed. SO_DOMAIN and SO_TYPE are checked and fail with EINVAL. `enable_rejects_stream_socket` passes, and the mutant no-socket-type-check fails it.
- M-2 Addressed: the header sentence says it is not an authority rule (supervisor_channel.h:~39-44), and README:118 says RoleMap and the C table are provisioned separately.
- M-3 Addressed: the README example now reads "role process A passes to role process B", cites `unregistered_sender_unknown`, and states the kernel EPERM.
- M-4 Addressed: VERIFICATION.md:1166-1169 is rewrapped and the verdict is its own sentence.
- M-5 Addressed: README:121 says the test is run manually.
- Nit Addressed: the struct writ_roles comment is rewrapped.

## New findings
- None. Observations only, severity none:
  - `drop-passrights` is a valid negative control. It makes payload and transfer cases fail as well as the rights cases, because the sender-side kernel refusal is gone, so the failing set is wider than the two cases the report names. This is correct behaviour.
  - Bend outputs were not recaptured, which is correct because no .bend file changed.
  - GPU: none involved.
