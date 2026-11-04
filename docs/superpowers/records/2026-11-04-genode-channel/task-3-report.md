# Task 3 report: bounds, liveness, binary check, task boxes

Status: DONE_WITH_CONCERNS
Commits (lane/genode-channel, on efff44c; not pushed, no manifest regeneration):
- 70f411a shim refusal + close event, Monitor close/fuel 8, client modes, bad_length and liveness runs, MonitorCheck cases
- 10144f0 queue run + ring high-water counter, binary check, evidence, INVENTORY/Channel.md/GENODE.md, tasks.md boxes

## Result (all base-linux; verification/genode-channel-base-linux.txt, TASK 3)
- GB-006 bad length: yes. `writ_bend_monitor_bad_length`: lengths 65 and 0
  are counted (warning lines with counts 1, 2), never copied, answered by the
  shim's fixed refusal (version 1, kind 3, decision 2, reason 256, rest 0,
  request seq) and signalled; the client checks all words; one Bend decision
  line in the log (the valid seq 3, Committed). Documented in Channel.md and
  INVENTORY as a transport refusal carrying no Writ decision.
- GB-008 unresponsive client: yes. `writ_bend_monitor_liveness`: S floods
  12x400 ms and never dispatches its result signal; R sends once and is
  Committed between S's records (S x3, R, R close, S x3).
- GB-008 fuel exhaustion: yes. Same run: "fuel exhausted", counters
  `signals=7 ... ring full=0 ring max=1 bad length=0 stale=0 taken=7 put=7
  put skipped=0 closed=1 open=1 closing=0`, monitor ram used 8667136 /
  268328754, caps 55 / 966, `child "writ_bend_monitor" exited with exit value 0`.
- Channel close: implemented. Shim holds the slot as closing and queues a
  close entry; take reports route subject 0 (never a channel subject, not a
  record word). Monitor drops the binding (no put; costs one fuel). Seen on
  Genode ("channel=1 closed ... bindings 1 -> 0"); MonitorCheck covers
  remove, unbound no-op, ninth channel served after a close.
- Extra (for 2.4 "queue depth"): `writ_bend_monitor_queue`, 9 clients: ninth
  session refused at MAX_CHANNELS, 8 decisions over channels 1-4 in ring order (corrected in fix round 1),
  ring max=3 (first run) and 1 (final run); a full ring never observed.
- Carried items: MonitorCheck asserts `Bindings.count == 1` after two
  requests on channel 1; reason 7 wording now "8 bound at once; made even for
  denied requests, removed at close" and notes the old "over the component's
  life" meaning (close is implemented, so that wording is historical); cap
  comment names Local_service::budget_adjusted_args called by Root_component.
- Binary check on the monitor ELF: rc 1. Effect rows: Genode.log, Genode.put,
  Genode.take only (no IO row). Not five: Monitor.bend calls neither
  Genode.now nor Genode.sleep, and Bend emits rows only for effects used. All
  rows beyond the profile are Genode host-added channel effects. Symbol half:
  158 undefined, 117 outside (Linux allow list; fails on every Genode binary;
  hello baseline 115, the extra two are Signal_transmitter). Allow lists untouched.
- Regression with the final shim: all 7 monitor runs rc 0; hello (8335360,
  caps 35), rts, probe (102 ms PASS); corpus 782 PASS, 834 lines cmp-identical
  to genode-tests-2.lines (fc3a08aa...). Shim diff touches only lines after the
  channel section header (line 925). Live copies cmp-identical. monitor.c
  re-emitted identical.

## tasks.md
- 2.1 checked: Bend effects with C twins over the shim; output and monotone
  time verified in the component (Task 1 evidence). All words met.
- 2.2 unchecked: shim, bounded queue, inventory (files, symbols, sessions)
  met; "reviewer" not met (INVENTORY: "Not reviewed under GB-006"); "show it
  contains no policy decision" only asserted by its authors.
- 2.3 checked: take/put over per-channel buckets bound to one descriptor;
  report-to-summary Committed via DataOS.commit_from_capability; substituted
  subject Denied by Bend (reason 6). Caveat: S's session synthetic.
- 2.4 checked: request size bounded and tested (65, 0); queue depth bounded
  (one entry per slot, 8 slots) and tested at the channel limit (ninth
  refused) with ring occupancy up to 3 in one run; a client that never reads;
  loop keeps serving other sessions. Weakest word: "test queue depth" (full
  ring unreachable by construction, never observed).
- Section 3 unchecked.

## Concerns
1. 2.4's "queue depth" rests on the channel-limit test and a timing-dependent
   occupancy (3, then 1); reviewer may judge it insufficient.
2. Close event overloads route subject 0 as a take-time flag instead of a
   new Request field (chosen to avoid changing Request/twins); not forgeable
   by a client, but a design choice to review.
3. Fuel raised 4 -> 8; close events consume fuel. GB-008's supervisor restart
   with a new generation is not configured (recorded as not met).
4. After the monitor exits, a flooding client on base-linux blocks in
   lx_sendmsg (-111); the liveness run therefore ends at the first flood
   request after the monitor's exit rather than at the client's exit.
5. Commit 70f411a's runs used the intermediate shim (no ring max=); the final
   runs after 10144f0's shim supersede them. The client ELF hash changed after
   a comment-only edit (debug line info); all runs were repeated with it.
6. OpenSpec 1.16.0 not installed; 1.11.0 strict validation passed (44/44).
   Tests.bend/PROOF.bend not rerun (no library/example/test file changed).
   Examples/overflow/reservation probes relinked, not rerun.

## Fix round 1

Status: DONE_WITH_CONCERNS. Commit: 1e19a45 (on 10144f0; not pushed, no manifest).

- Important 1: (a) tasks.md, INVENTORY, GENODE.md now say 8 sessions opened
  (ninth refused), 8 decisions over channels 1-4 (1-3 in the rerun) in ring
  order before fuel ran out. (c) attempted, bounded: a burst run requiring
  coalesced>0 and ring max>1, six runs in three configurations; it passed
  once (coalesced=1, ring max=2), coalesced>0 twice. Cause: Genode merges
  repeated submits to one signal context before the handler runs (400
  submits -> 9-10 handler calls), so the shim's coalescing branch needs a
  submit inside one decision's window. Not kept (a randomly passing run);
  logs kept under ../writ-genode/run-writ_bend_monitor_burst-t3-fix1-*.out.
  (b) applied: 2.4's rationale says coalescing was not reliably exercised.
  2.4 stays checked on request size, the channel/queue bound, and the
  unresponsive client; the reviewer may want it unchecked on this basis.
- Minor 2: TakeEvent = Closed{channel} | Record{request} (Event is taken by
  an import); classify once, step matches on it; MonitorCheck 13 PASS.
- Minor 3: the lx_sendmsg line is from the first timed-out liveness run,
  log not kept; stated in the evidence.
- Minor 4: INVENTORY lists _channel_ring_max / ring max=, states the new
  hash, adds "close event while a request is in Bend" and "coalescing not
  reliably exercised".
- Minor 5: bad length adds 0xFFFFFFFF; three refusals, counts 1-3, valid
  seq 4; rc 0.
- Minor 6: GENODE.md: queue-run clause, close events cost fuel.
- Shim unchanged this round (identical to 10144f0), so hello, rts, probe,
  corpus not rerun. Seven monitor runs rerun with the final client and
  monitor: rc 0. check-binary unchanged (3 Genode rows, 117 symbols outside).
  Live copies cmp-identical; monitor.c re-emitted identical.

## Final-review fixes

Commits: b068d40 (fixes), f45bb01 (merge of master 64c04b4, clean, no
manifest conflict; manifest not regenerated).

I1. Signal submit is an RPC to the shim's own PD session in core
(signal_transmitter.cc:31-44); core warns on an unknown context
(signal_delivery_proxy.h:64-72); on base-linux a failed lx_sendmsg
sleeps forever (ipc.cc:325-330). New writ_bend_monitor_dead_client run
(exited client, freed signal context, then a live client served
Committed) passes rc 0 three times. Claim narrowed to the cases run; a
dead process with a still-open session is listed as not shown.

I2. Runtime-rows live hash table regenerated (55 files, client
310f5a8c...); all live copies byte-identical to committed files.

Minors: refusal decision word 3 (outside Committed/Denied);
writ_bend_boot generalised and reused by the probe run, with
writ_bend_monitor_boot kept as a thin wrapper (configs byte-identical);
MonitorCheck reasons 1-4 (17 PASS); client mode buffer String<32>;
INVENTORY gaps (GB-010, static registry/epoch, global fuel, no
restart); Channel.md label_prefix guidance; docs/GENODE.md clauses.
The shim comment "never waits for a client" is unchanged: it is
accurate (no acknowledgement wait) and the submit caveat is stated
next to it.

Spec/design edits (naming or mechanism alignment only; no law or
requirement weakened):
- design.md, time and take: names writ_shim_now_ms/sleep_ms and the
  io_work helper thread that take really blocks on.
- design.md, buckets: describes the one overwritten record slot and
  that Genode has no read-only capability, as built.
- design.md and spec.md GB-006: oversize request is "dropped, counted,
  and answered with a fixed transport refusal before any Bend
  parsing"; adds the reply the shim already sends, keeps the
  before-parsing rule.
- spec.md GB-007 and explainer.html: Genode.accept renamed to
  Genode.take to match the effect's name.

Coordination point: add-genode-capability-adoption still says
Genode.accept; it was not edited (cross-lane). Integration should
rename it there or keep a note; the new explainer and
openspec/traceability/genode-bend-component.md record the former name.

Integration items: traceability file added (GB-001..GB-011 to run
scripts and PASS labels, reviewed-only gaps quoted); VERIFICATION.md
section added; OpenSpec 1.16.0 passes 44/44 before and after the merge.

Checks: hello, rts, probe and all 8 monitor runs rc 0 on the final
client; corpus rerun after the shim change cmp-identical (834 lines,
782 checks). Not rerun after the merge: bend Tests.bend and
PROOF.bend (merge touched no lane file and no Bend source of this
lane). Limits: CPU base-linux only, no GPU, no Lean verdict.

## Re-review fixes (commit a8941e0)

- D1: the dead-client run now requires writ_client_f's own decision
  (its channel read from the shim's open line) before R's Committed, and
  core's "Warning: invalid signal-context capability". I required f's
  decision, not "two S decisions": the dead client's queued entry can
  become the close event, and the re-run showed exactly that (1 S
  decision), so a count of two would fail on a legitimate interleaving.
  Re-run rc 0 (run-writ_bend_monitor_dead_client-t3-rr.out).
- D2: failed attempt -t3-fr-1.out recorded with its cause (String<16>
  mode buffer truncated "exit_after_signal").
- D3: shim comment qualified with "in the cases run" and a pointer to
  INVENTORY "Signal submit"; tokens identical with comments stripped;
  sha256 d97a98de...22e3 recorded in INVENTORY, the rows table and the
  evidence HASHES; live copy recopied; hello and dead-client rerun on the
  rebuilt binary (rc 0). No corpus rerun (comment-only change).
