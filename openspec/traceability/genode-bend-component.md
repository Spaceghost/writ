# Genode Bend component traceability

Proposed change: [add-genode-bend-component](../changes/add-genode-bend-component/specs/genode-bend-component/spec.md).
This is a proposed change; nothing here marks a host adapter, a base-hw
profile, or a host acceptance scenario as implemented. Every execution named
here is single lane, `--gpu off`, over the synthetic authority state of
`examples/Scenario.bend`, on `base-linux` (Genode-on-Linux) or on x86_64
`base-hw` under QEMU TCG (an emulated boot, not native hardware), each
recorded separately.

Implementation: the shim [writ_mem.cc](../../hosts/genode/shim/writ_mem.cc)
with [writ_channel_session.h](../../hosts/genode/shim/writ_channel_session.h)
(inventory: [INVENTORY.md](../../hosts/genode/INVENTORY.md)); the effects
[Genode.bend](../../hosts/genode/effects/Genode.bend) and their twins; record
formats [Channel.md](../../hosts/genode/effects/Channel.md); the monitor
[Monitor.bend](../../hosts/genode/monitor/Monitor.bend); the client probe
[writ_channel_client.cc](../../hosts/genode/probes/client/writ_channel_client.cc)
(scaffolding). Run scripts live under [scripts/genode/](../../scripts/genode/)
and are run as `make run/<name>` in the Genode build directory.

Run-script names below are the `make run/<name>` scenarios. MonitorCheck
cases are the exact `PASS` labels printed by
[MonitorCheck.bend](../../hosts/genode/monitor/MonitorCheck.bend) (Linux,
host scaffolding, not part of `Tests.bend`'s 782 checks). "Reviewed-only gap"
means the requirement, or the named part of it, has no execution here and
the gap text is quoted.

Evidence files: [genode-bend-hello-base-linux.txt](../../verification/genode-bend-hello-base-linux.txt),
[genode-runtime-rows-base-linux.md](../../verification/genode-runtime-rows-base-linux.md),
[genode-corpus-base-linux.txt](../../verification/genode-corpus-base-linux.txt),
[genode-effects-base-linux.txt](../../verification/genode-effects-base-linux.txt),
[genode-channel-base-linux.txt](../../verification/genode-channel-base-linux.txt);
base-hw: [genode-bend-hello-base-hw.txt](../../verification/genode-bend-hello-base-hw.txt),
[genode-runtime-rows-base-hw.md](../../verification/genode-runtime-rows-base-hw.md),
[genode-corpus-base-hw.txt](../../verification/genode-corpus-base-hw.txt),
[genode-channel-base-hw.txt](../../verification/genode-channel-base-hw.txt).

| Requirement | Executed evidence (base-linux; base-hw where named) | Reviewed-only gap |
| --- | --- | --- |
| GB-001 built from the generated C | `writ_bend_hello` (generated C of the `IO.print` program linked with the shim prints `hi`, exit 0) | "A Linux binary is dropped in": rejection is by review; no run tries it |
| GB-002 runtime rows per base | runtime rows executed by `writ_probe_threads`, `writ_probe_clock`, `writ_probe_evloop`, `writ_probe_process`, `writ_probe_fault`, `writ_probe_reservation_live`, `writ_probe_reservation_guard` (genode-runtime-rows-base-linux.md); base-hw: every row run again with provenance per row (genode-runtime-rows-base-hw.md) | Atomics across lanes unverified on both bases (tasks.md 1.2) |
| GB-003 faults terminate the component | `writ_bend_overflow` on base-linux (terminates at the runtime's guard page, nothing resumes); on base-hw (refused at the guard page, `[init] child "writ_bend_overflow" exited with exit value 139`, core silent; tasks.md 1.3, checked for base-hw only) | base-hw's record is the profile's halting substitute with six limits (genode-bend-hello-base-hw.txt, GB-003 ON BASE-HW): self-requested `Parent::exit(139)`, an exit value not a fault, core silent, other threads may run before the PD is destroyed, coverage limits (including a lock-holder fault halting with no record), emulated boot. "Forced overflow on base-linux": unmet, init records nothing. "Supervisor restarts the monitor": unmet, no supervisor restart is configured on either base |
| GB-004 corpus parity | `writ_bend_tests` (782 PASS, 834 lines byte-identical to the Linux single-lane record), `writ_bend_example`, `writ_bend_flow`, `writ_bend_transfer`, `writ_bend_gpuexample`; the same five on base-hw, byte-identical (genode-corpus-base-hw.txt; tasks.md 3.1) | the scenario's 638 count is the older corpus |
| GB-005 effects in Bend with C twins | `writ_bend_probe` (Genode.log text reaches the LOG; Genode.now ordered around Genode.sleep(100)); `Genode.take`/`Genode.put` in every `writ_bend_monitor_*` run | "Policy appears in the shim": shown by source review only (INVENTORY: "Not reviewed under GB-006") |
| GB-006 inventoried shim, bounded queue and size | `writ_bend_monitor_bad_length` (lengths 65, 0, 0xFFFFFFFF counted and answered with the fixed transport refusal before Bend); `writ_bend_monitor_queue` (8 channels, ninth session refused, ring full=0) | inventory reviewer named 2026-11-05 (Josh Adams, sha256 9d9d32d2…, "no policy decision found"; a ratified guided read through board questions q7 to q16, as INVENTORY.md "Reviewer" states; tasks.md 2.2 checked); coalescing "not reliably exercised"; a full ring "cannot occur by construction and was not observed"; on base-hw the queue run reached ring max 8 with coalesced signals in both runs (observed, timing dependent, not required by the script; genode-channel-base-hw.txt) |
| GB-007 route identity | `writ_bend_monitor_accept` (Committed), `writ_bend_monitor_substitute` (Denied reason 6), `writ_bend_monitor_routed_s` (Denied reason 5), `writ_bend_monitor_claim_ignored` (Committed); MonitorCheck: "routed reader R committed", "body naming S's session denied by DataOS.commit_from_capability", "S as route subject denied at the descriptor step", "R with a body claiming S committed (claim ignored)", "route subject 3 refused: route subject unknown (reason 2)" | S's session is synthetic, "opened and not negotiated"; how the route subject and channel id map onto HostBinding records, and which GA-005/GA-008 vectors a Genode run must replay (none replayed yet), is in "Binding records from `Genode.take`" in [design.md](../changes/add-genode-bend-component/design.md) |
| GB-008 one request at a time, liveness | `writ_bend_monitor_liveness` (a client that never reads its replies does not stop a second; fuel exhausted, monitor exit value 0); `writ_bend_monitor_dead_client` (a client that exits before its reply and one that freed its result signal context do not stop a third); both on base-hw too, with two host differences recorded (the flooding client faults when the monitor's buckets vanish; base-hw drops a signal to a freed context silently; genode-channel-base-hw.txt) | "the supervisor restarts it with a new generation": not configured; the fuel is global, so any client can end the service; "whether the reply signal can block the loop on base-linux beyond the cases run is not shown" (INVENTORY, Signal submit) |
| GB-009 evidence per base, CPU execution | base-linux and base-hw recorded in separate files (tasks.md 3.1); `--gpu off` in every run, every `!` call on the CPU; `check-binary.sh` run on the base-hw monitor ELF and OpenSpec 1.16.0 strict validation recorded (tasks.md 3.2) | the binary check FAILS: effect rows Genode.log/put/take are outside the monitor profile and the symbol half fails against the Linux allow list; base-hw is emulated boot only, not native hardware |
| GB-010 one channel object per descriptor | every `writ_bend_monitor_*` run (one session, one channel object, one bound descriptor); close event in `writ_bend_monitor_liveness` (bindings 1 -> 0); MonitorCheck: "second request on channel 1 reuses its descriptor and frontend revision (session now Committed)", "two requests on channel 1 leave one binding", "ninth channel refused: channel table full", "bound channel 3 still served with a full table", "channel 1 arriving with another subject refused", "closing channel 1 removes its binding", "closing an unbound channel leaves the table unchanged", "after channel 3 closed a ninth channel is bound and served (not reason 7)" | "two descriptors for one reader, closing one leaves the other usable": not run on Genode; "Object points at a publisher": review only |
| GB-011 records in channels | every `writ_bend_monitor_*` run (requests and decisions only as records; four capability-handover RPC functions); MonitorCheck: "record with version 2 refused: bad record (reason 1)", "session 9 refused: session unknown (reason 3)", "invocation 98 refused: plan is not the session's plan (reason 4)" | "A method surface is proposed": review only |

Cross-change coordination point: the capability-adoption change
([add-genode-capability-adoption](../changes/archive/2026-11-04-add-genode-capability-adoption/, archived 2026-11-04))
explainer now names the request effect `Genode.take` (formerly
`Genode.accept`), matching this change; its spec and tasks never named
`accept`. The adoption binding records and vectors are not yet replayed
through `Genode.take`.
