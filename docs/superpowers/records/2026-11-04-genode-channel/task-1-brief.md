### Task 1: Console and time effects over the shim

Add to the shim `extern "C"` functions `writ_shim_log(const char*, size)`, `writ_shim_now_ms()`, `writ_shim_sleep_ms(ms)` over the LOG and Timer sessions (`Timer::Connection`). Author `hosts/genode/effects/Genode.bend` with effect defs `Genode.log(text: String) -> IO(Unit)`, `Genode.now() -> IO(U32)`, `Genode.sleep(ms: U32) -> IO(Unit)` and their `.c`/`.js` twins per `bend guide effects`. Write `hosts/genode/monitor/Probe.bend` that prints through `Genode.log`, reads `Genode.now` twice around `Genode.sleep(100)`, and prints the delta. Build it as a component (new target.mk under `scripts/genode/writ_bend_probe/`, same pattern as writ_bend_hello) and run under init at 256M. Evidence: `verification/genode-effects-base-linux.txt` with the log showing the text and a delta of at least 100 ms. Update the inventory.

Acceptance: the Bend program's output reaches the Genode LOG through the shim, and the time delta is monotone and at least the sleep.

