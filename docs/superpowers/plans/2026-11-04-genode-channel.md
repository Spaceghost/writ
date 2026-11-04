# Plan: Genode component, channel milestone

Spec: `openspec/changes/add-genode-bend-component/` (GB-005 through GB-011; tasks 2.1 to 2.4). Prerequisite: the host-layer memory milestone (`docs/superpowers/plans/2026-11-04-genode-host-layer.md`) has landed, so the unmodified Bend hello prints under init on `base-linux` with `hosts/genode/shim/` linked in. Read the design's "Writ is data-centric above the kernel: channels, not procedure calls" and "The channel is served from the event loop" sections first, then `bend guide effects`.

## Global Constraints

- Toolchain, tree, and pins as the Genode lanes record. `base-linux` only in this milestone; `base-hw` is task 3.1 and stays unchecked.
- GB-006: exactly one authored C++ unit in the monitor component, the shim under `hosts/genode/shim/`. Extending it with LOG, Timer, and channel functions is allowed; a second C++ unit is not. Every exported `extern "C"` function, every session the shim opens, and every bound (queue depth, record size) goes in `hosts/genode/INVENTORY.md`. The shim contains no policy decision: it moves records and signals.
- Effects are Bend defs with `.c` twins under `hosts/genode/effects/` (and `.js` twins that fail with a clear message, since the JavaScript runner is not a Genode target). The twins call the shim and nothing else. GB-005: no effect logic in C++.
- GB-010/GB-011: one channel object per descriptor, each a bounded request bucket, a bounded result bucket, and a signal; no method surface with Writ semantics. Records are fixed-width little-endian words with a version word first; the authenticated subject comes from the parent route (session label prefix) and never from the record body (GB-007).
- The monitor program is Bend under `hosts/genode/monitor/` using the library's real `DataOS.commit_from_capability` over the synthetic monitor state from `examples/Scenario.bend` (import it; do not copy it), clearly marked synthetic as the examples are. A client is C scaffolding under `hosts/genode/probes/client/`, headers saying so.
- No `.bend` under the root, `examples/`, `lib/`, `writfs/` is modified; `Tests.bend` untouched. Nothing built committed. Evidence under `verification/` with commands and logs; base-linux is Genode-on-Linux. Do not push; commit at each acceptance point; write the SDD report early.
- Time-box each task at about three hours.

### Task 1: Console and time effects over the shim

Add to the shim `extern "C"` functions `writ_shim_log(const char*, size)`, `writ_shim_now_ms()`, `writ_shim_sleep_ms(ms)` over the LOG and Timer sessions (`Timer::Connection`). Author `hosts/genode/effects/Genode.bend` with effect defs `Genode.log(text: String) -> IO(Unit)`, `Genode.now() -> IO(U32)`, `Genode.sleep(ms: U32) -> IO(Unit)` and their `.c`/`.js` twins per `bend guide effects`. Write `hosts/genode/monitor/Probe.bend` that prints through `Genode.log`, reads `Genode.now` twice around `Genode.sleep(100)`, and prints the delta. Build it as a component (new target.mk under `scripts/genode/writ_bend_probe/`, same pattern as writ_bend_hello) and run under init at 256M. Evidence: `verification/genode-effects-base-linux.txt` with the log showing the text and a delta of at least 100 ms. Update the inventory.

Acceptance: the Bend program's output reaches the Genode LOG through the shim, and the time delta is monotone and at least the sleep.

### Task 2: The Writ channel

Define the record formats in `hosts/genode/effects/Channel.md` (version word, kind, plan identity words, and the result's decision word plus reason or intent words; sizes fixed; both buckets 4 KiB; queue depth 8). Add to the shim: a channel service that, per client session routed by the parent, creates one channel object (two RAM dataspaces and a signal context), hands the client the dataspace capabilities through the session, and queues `(channel id, subject from the route label prefix)` when the client signals. Export `writ_shim_take(out record, out channel id, out subject)` (blocking through the libc wakeup mechanism the event loop uses, see the design) and `writ_shim_put(channel id, record)`. Author `Genode.take() -> IO(Request)` and `Genode.put(channel: U32, reply: Reply) -> IO(Unit)` with twins; `Request` and `Reply` are Bend records mirroring the formats. Write `hosts/genode/monitor/Monitor.bend`: a fuel-bounded loop that takes a record, resolves it against `examples/Scenario.bend`'s registry and session, calls `DataOS.commit_from_capability`, and puts a decision record. Write the C client probe that attaches the buckets, writes the report-to-summary request, signals, and prints the decision; then a second run where the body claims subject S while the route names R. Evidence: `verification/genode-channel-base-linux.txt` showing the accepted decision for the routed reader and `Denied` for the substituted subject, both decided by Bend (GB-007), with the records dumped as hex.

Acceptance: one request round trip accepted, one denied by Bend, both through buckets and signals with no method surface; inventory lists every new export, session, and bound.

### Task 3: Bounds, liveness, and task boxes

Tests through the client probe: a record larger than the bucket's declared size is counted and answered with a bounded-size denial record before any Bend parsing (GB-006); a client that never reads its reply does not stop a second client from being served (GB-008); fuel exhaustion exits the monitor cleanly with exit value 0 (GB-008). Record each in the evidence. Run `scripts/runtime-profile/check-binary.sh` on the monitor ELF and record the result (the Genode effects must be the only rows beyond the monitor profile; list them as the host-added channel effects the profile allows). Check `tasks.md` 2.1, 2.2, 2.3, and 2.4 only as the evidence supports; leave section 3 unchecked.

Acceptance: the three behaviours recorded, the binary check result recorded, boxes match evidence.
