# Task 1 report: console and time effects over the shim

Status: DONE_WITH_CONCERNS
Commit: 626327f (on lane/genode-channel, base 27048ff). Not pushed.

## Result
- `hosts/genode/monitor/Probe.bend` -> `writ_bend_probe` under init, base-linux, 256M:
  `[init -> writ_bend_probe] probe: hello from Bend through the Genode LOG session`,
  `probe: now before=0 after=101`, `probe: delta_ms=101 sleep_ms=100`, PASS, exit 0.
  Runs 2-5: delta 101, 101, 101, 102 ms; `timer short wakes=0`. libc stdout was
  /dev/null and the IO.print control line was absent, so the text came through
  Genode.log -> writ_shim_log -> Genode::log.
- Regression with the new shim: hello, rts, and the 782-check corpus rerun; corpus
  lines byte-identical to genode-tests-2.lines.
- check-binary.sh on the probe ELF: rc 1; effect rows beyond the profile are exactly
  Genode.log, Genode.now, Genode.sleep (the script sees them: twins named
  genode_<x>_run). The symbol half fails for every Genode binary (Linux allow list);
  the probe adds 15 Timer/Signal symbols plus pthread_detach (allowed) over the hello.
  Allow lists not edited.

## Files
- hosts/genode/shim/writ_mem.cc (same TU, name kept): writ_shim_log, writ_shim_now_ms,
  writ_shim_sleep_ms; lazy Timer::Connection "writ_shim"; report gains
  `timer short wakes=`. sha256 df94a002...6f42 -> 01d7dccb...920c.
- hosts/genode/effects/Genode.bend + genode_{log,now,sleep}.{c,js}.
- hosts/genode/monitor/Probe.bend.
- scripts/genode/writ_bend_probe/{target.mk,writ_bend_probe.run}; build.conf.fragment
  gains writ_bend_probe (live build.conf too).
- verification/genode-effects-base-linux.txt (new); rows file, INVENTORY, docs/GENODE.md.

## Concerns
1. Naming: brief/plan use writ_shim_now_ms/writ_shim_sleep_ms (followed); design.md's
   table says writ_shim_now/writ_shim_sleep. design.md not touched (out of scope).
2. Bend requires an import alias: calls are Host.Genode.log etc.; C ids are
   path-mangled (CID____effects_Genode_Genode_log). Bend names are Genode.*.
3. Genode.sleep uses io_work (helper pthread) per the guide's blocking-work rule;
   that it ran on a helper thread is source reading, not observed. Concurrent
   sleeps serialize on the one Timer::Connection (msleep's mutex) - recorded.
4. writ_shim_sleep_ms loops until the session clock passes the deadline (guarantees
   delta >= sleep); no early wake observed. Clock origin is the session's creation
   (first reading 0).
5. Probe run config is written out (not writ_bend_boot) because stdout -> /dev/null.
6. Not exercised: probe FAIL branch, missing Timer route, >232-byte or NUL log text.
   Examples/overflow/reservation probe relinked but not rerun.
7. Bend Tests.bend/PROOF.bend not rerun on Linux (no Bend library change); the Genode
   corpus run covers the shim change.

## Fix round 1

Status: DONE. Commit 7793a60 (on top of 626327f). Not pushed.

1. Probe.bend verdict: t1 >= t0 and 100 <= delta < 1100 (max_delta_ms); the run
   script requires t1 >= t0, the unmasked delta matching the logged line, and the same
   window. FAIL branch exercised with a scratch build (lower bound 5000): FAIL line,
   exit value 1, run refused. Committed probe passes again (runs 6-10, delta 101 ms).
2. Shim (confined to "Console and time"): route check with Env::try_session before
   Timer::Connection (Env::session would sleep_forever on DENIED, component.cc:200-202),
   catch on construction, _timer_fail = one error line + Parent::exit(1); sleep loop
   stops on reversed/frozen clock and after MAX_SLEEP_ROUNDS = 16. Comment says host
   failure handling, not policy. Missing-route scratch run (shim's Timer label routed
   to the parent): "Error: writ_shim: Timer session denied (no route for label
   writ_shim), component exits 1", init exit value 1. sha256 -> 6664b650...dfca.
   INVENTORY records the three outcomes and the never-timeout-mode invariant.
3. Regexps anchored to the [init -> name] label.
4. writ_bend_boot duplication left for Task 2, noted in the run script.
5. INVENTORY: lazy open from the io_work helper thread (first call Genode.sleep) unexercised.
6. INVENTORY: a queued sleeper overshoots (about the earlier sleep plus its own).
7. INVENTORY and evidence: check-binary.sh sees effects only via genode_<x>_run ->
   Genode.<x>; Task 2 twins must follow it.
Reruns: probe x5, hello, rts; corpus not rerun (shim diff only in the timer section,
which the corpus never calls). Live copies cmp-identical; scratch files removed from
writ-repo and build.conf restored.
