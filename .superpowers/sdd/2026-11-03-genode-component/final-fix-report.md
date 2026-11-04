# Final fix wave report

- I1: verification/genode-runtime-rows-base-linux.md:87 (table, new vocabulary), headings :100, :345, :267; docs/GENODE.md:243, :257; tasks.md:3-4 (1.2 sentence).
- I2: verification/genode-runtime-rows-base-linux.md:75 (Authored non-Bend files).
- I3: openspec/changes/add-genode-bend-component/design.md:22 (musttail/clang sentence).
- I4: verification/genode-runtime-rows-base-linux.md:157; docs/GENODE.md:270.
- M1: verification/genode-pins.txt:43-46.
- M3: verification/genode-runtime-rows-base-linux.md:40.
- M4: docs/GENODE.md:228.
- M5: docs/GENODE.md:257.
- M7: scripts/genode/writ_bend_hello/writ_bend_hello.run:12-14.
- M8: verification/genode-runtime-rows-base-linux.md:195.
- build.conf.fragment:36 now uses <writ-genode> (still ?=, overridable).
- sha256 list: verification/genode-runtime-rows-base-linux.md:48 onward. Committed copies were cmp-identical to live before edits; the two edited run scripts (writ_bend_hello.run, writ_probe_clock.run) now differ from live in header comments only.
- Regenerate line: verification/genode-runtime-rows-base-linux.md:34.
- Clock run script header: scripts/genode/probes/clock/writ_probe_clock.run:8-10; rows file clock section notes "about half of runs".
- OpenSpec: Totals: 42 passed, 0 failed (42 items)
