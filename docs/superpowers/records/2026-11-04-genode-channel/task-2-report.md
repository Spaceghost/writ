# Task 2 report: the Writ channel

Status: DONE_WITH_CONCERNS
Commits (lane/genode-channel, on 7793a60; not pushed):
- f87b018 formats + shim service (Channel.md, writ_mem.cc, writ_channel_session.h, INVENTORY)
- 75895d2 effects + monitor (Genode.bend Request/Reply/take/put, twins, Monitor.bend, MonitorCheck.bend, monitor target.mk)
- 75c7f61 client runs (client probe, run scripts + tcl, build.conf.fragment, evidence, docs/GENODE.md)

## Result
Accepted round trip: yes. Substituted subject denied by Bend: yes.
- Run 1 (`make run/writ_bend_monitor_accept`): child writ_client_r, policy
  `label_prefix="writ_client_r ->" subject="1"` (reader R), session 1, client
  waits 2000 ms so Genode.take is parked first. Monitor:
  `decision=Committed reason=0 ... session_revision=7 reader_balance=45`;
  result words 1 2 1 0 1 1 20 1 99 3 1 7 45 0 0 0. Client exit 0.
- Run 2 (`make run/writ_bend_monitor_substitute`): same route, body
  claimed_subject 2 and S's session 2: `decision=Denied reason=6
  (DataOS.commit_from_capability rejected)`, route_subject=1. Reason 6 (library
  rejection: R is not the session's reader) differs from reason 5 that S as
  caller would get (descriptor refused), shown by MonitorCheck.bend on Linux.
- Both records hex-dumped in verification/genode-channel-base-linux.txt.
- Flipped expectation: client FAIL, exit 1, run refused. Unmatched label
  (writ_client_x): session DENIED with one warning, nothing reaches Bend.
- Regression: 8 Bend components relinked; hello, rts, probe pass; corpus 782
  PASS, 834 lines byte-identical (fc3a08aa...). Probe.c re-emit identical.

## Decisions (recorded in shim header, INVENTORY, evidence)
- Libc keeps the main ep in wait_and_dispatch_one_io_signal while Bend waits
  (libc/internal/kernel.h:460-533), so RPCs/non-I/O signals would stall: the
  Writ_channel root and channels run on a dedicated Genode::Entrypoint
  "writ_channel" (as Root_proxy does).
- Wakeup: request Signal_handler -> ring (depth 8, one entry per channel) ->
  Genode::Semaphore; writ_shim_take blocks on it on the io_work helper; the
  runtime's own io_wake_fd pipe wakes the loop. Coarse spin check: monitor
  threads all S, 0 s CPU across the 2 s park.
- Subject: `<writ_channel><policy label_prefix subject>` via
  with_matching_policy; default-policy/no match/0 -> DENIED.
- Session: Writ_channel::Session with request_bucket, result_bucket,
  request_sigh, result_sigh only. RAM_QUOTA 32 KiB, CAP_QUOTA 8.
- Buckets: 16-byte header (length, seq) + 64-byte record at offset 16; shim
  copies once at take; wrong length dropped+counted (no reply yet: Task 3).
- Monitor state threads the committed session/ledger (a replay is reason 6).
- writ_bend.tcl untouched (no stdout parameter needed); new shared
  scripts/genode/writ_bend_monitor/writ_bend_monitor.tcl.

## Concerns
1. The session header writ_channel_session.h is a second authored C++ file
   (header, same TU, no second .cc); also included by the client. Inventoried.
2. The client probe is C++, not C (Genode session clients need Rpc_client).
3. Every Bend component now opens its config ROM once at start (+20 KiB in
   the hello, caps unchanged), even without <writ_channel>.
4. The descriptor is mounted/opened per request inside Bend from
   Frontend.empty(), not bound to the channel at session creation; S's
   session (Monitor.other_session) is synthetic, opened not negotiated.
5. Run 2's denial alone does not distinguish "body ignored" from "body used"
   (both deny); the reason word does (6 vs 5), shown by the Linux check only.
6. Client may map the result bucket writable (no RO ds cap in Genode); the
   shim never reads it. Words are host-order (x86_64 LE).
7. Not exercised: bad length, full ring, coalescing, stale entry, put
   skipped, multiple channels, channel close, unresponsive client, fuel
   exhaustion (Task 3). check-binary.sh not run on the monitor (Task 3).
   Monitor RAM not recorded (it never exits in these runs).
8. Three commits were staged after the work rather than at each point in time.
9. One shim comment line corrected after the runs; rebuilt writ_mem.o and
   ELF byte-identical.

## Fix round 1

Status: DONE. Commit: efff44c (on lane/genode-channel, not pushed; no manifest regeneration).

- Important 1 (reason 6 vs 5): runs 3 `writ_bend_monitor_routed_s` (writ_client_s, policy subject 2) -> `route_subject=2 ... Denied reason=5`, descriptor 0; run 4 `writ_bend_monitor_claim_ignored` (route R, session 1, claimed 2) -> Committed, same reply as run 1. Shared Tcl parametrized (client, subject, session, expected, claimed, decision, reason, delay, policies). Evidence reworded: reason 6 = descriptor opened, library refused; the reader gate (DataOS.bend:52-61) and the Proposed/Running point come from reading the code, not the log. Hex dumps for runs 1-4 recorded.
- Important 2 (GB-010): MonitorState.channels, a bounded list (8) of channel -> {subject, Frontend.State, descriptor}; bind on first take, reuse after, commit with the stored frontend and Frontend.revision. Reasons 7 (table full) and 8 (bound to another subject) in Channel.md; reply words 13/14 = descriptor, frontend_revision. Gaps recorded (no unbind on close: Task 3; S's session opened, not negotiated). MonitorCheck covers reuse, table full, bound channel still served, subject mismatch; a flipped expectation exits 1.
- Minor 3: Libc::Env::with_config, no second ROM. Hello RAM is still 8335360 without it, so the earlier "+20480 = config ROM" attribution was wrong; corrected in evidence and INVENTORY (cause not isolated).
- Minor 4: static_assert(MAX_CHANNELS <= CHANNEL_QUEUE_DEPTH); INVENTORY says a full ring is impossible by construction.
- Minor 5: policies with neither label nor label_prefix are refused; Channel.md "Route subject" says so; suffix-only scratch run refused ("no <policy> with a subject ...") and removed.
- Minor 6: acquire fence after reading the bucket length.
- Minor 7: a shim cap check was tried and fired in every run (adjusted args show 7 caps); removed and replaced by the citation of base/service.h:170-177 (budget_adjusted_args refuses below CAP_QUOTA, then subtracts the session cap, 179-186). Final runs have no cap warning.
- Minor 8: the shim's channel counters (bad length, stale) and the monitor's RAM are left for Task 3's fuel-exhaustion run.
- Regressions with the final shim: hello (rc 0, ram 8335360, caps 35), rts, probe (delta 101 ms PASS), flow (4 PASS, exit 0). The corpus was not rerun this round because the memory path did not change; the final review reruns it. Tests.bend/PROOF.bend not rerun (no library/example/test file changed).
- Live copies cmp-identical; monitor.c re-emitted after the last Bend edit (edbb9ff7..., 68330 lines).
