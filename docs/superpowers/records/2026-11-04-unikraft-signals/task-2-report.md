# Task 2 report: rebuild the corpus and the other image sets

Status: DONE_WITH_CONCERNS (minor; listed at the end). Implementer, 2026-11-04/05.

Every image set was rebuilt from the shipped template, with the posix signal library
(`CONFIG_LIBPOSIX_PROCESS_SIGNAL: 'y'`) and the flag `UK_CFLAGS="-std=gnu11 -include uk/config.h"`.
Every rerun passes, with the same program lines as its reference. The corpus is still 782
PASS. No image hung at shutdown. Every negative control fails as it should.

## What changed

All changes are evidence. No script, source, Kconfig, `.bend`, doc or openspec file changed.

| File | Lines | Change |
| --- | --- | --- |
| `verification/unikernel-corpus-qemu.txt` | 1-144 (+144) | New current section at the top: configuration (Kraftfile and build.sh hashes, the library, the flag, resolved .config hashes), result table, builds, emitted C, image/.dbg hashes, check-corpus.sh and check-image.sh outputs, negative controls, wall times, what was not exercised. The earlier record is kept below a "History" rule. |
| `verification/unikernel-effects-qemu.txt` | 1-168 (+168) | The same shape for the probe, the scratch FAIL branch and hello (set `sigeffects`). Includes the shutdown observation. |
| `verification/unikernel-channel-qemu.txt` | 1-207 (+207) | The same shape for the monitor (set `sigchannel`): accepted, denied, negative control, no-port, flood, MonitorCheck cross-check, binary check. |
| `verification/unikernel-binary-check.txt` | 1-120 (+116) | New header and a "Signals rerun" section with the full checker output for all nine new .dbg files. History is kept below. |
| `verification/unikernel-pins.txt` | 54-87 (+34) | New section "Unikraft image configuration pins" with the library (Kraftfile line, Config.uk:78 entry and what it selects, resolved .config lines) and the flag (build.sh line, why it is needed), the sets built with both, the musl tarball hash re-observed, and a note that clean builds embed the build time. |
| `docs/superpowers/records/2026-11-04-unikraft-signals/activity.log` | appended | Step lines and heartbeats. |

`verification/unikernel-channel-{accepted,denied}-{client,console}.txt` are unchanged. These
four files are byte references: check-channel.sh diffs the whole file, so adding a
library/flag note would break the check. The new boots reproduce them exactly (diff empty;
the client logs have the same sha256). The channel evidence file says this.

## Environment

The Bend 2.0.39 toolchain is on PATH and `BEND_NO_TELEMETRY=1`. `W=/mnt/MediaVolume/Media/src/github.com/spaceghost/writ-lanes/writ-unikernel`.
Every boot is QEMU 11.1.2 TCG, emulated, pc, -cpu max, -no-reboot, with the exit device at 0xf4
and `+RTS --threads 1 --gpu off`. The runs are CPU only: no GPU was used or tested, and GpuExample's
CPU-fallback line is not GPU evidence. The host load average ranged from 21 to 277 at the
samples taken. It peaked near 277 during the corpus build.

The new sets were made with `mkapp.sh`, and each Kraftfile is cmp-equal to the template (ea319440...
in the evidence, full hash there): `sigcorpustests` (corpus), `sigcorpus` (examples),
`sigeffects` (probe, probefail, hello), `sigchannel` (monitor). The old sets are untouched.
Each resolved `.config` equals Task 1's sigfault one, apart from the CONFIG_UK_APP path. `shutdown.o.cmd`
contains `-include uk/config.h`.

## Commands and results

1. **Emit C** with `bend <file> -o $W/<set>/gen/<n>.c`.
   - tests.c b50856fbba69f93b950cbb68d05a9d9ce876f5c5cb4f2ba83bb5c1e184bb0602 (28.6 s).
   - example, flow, transfer, gpuexample and monitor.c (08c58ee1...) are byte-identical to the earlier record.
   - hello.c is 260b70a3....
   - probe.c 0bb236e1... differs from effects2's only in the spliced unikraft_sleep.c comment. Its comment-stripped tokens are identical (f3b659cb...).
   - The scratch ProbeFail.bend is the earlier sed with the import path pointed at this worktree (afc19e2e...).
2. **Builds** with `build.sh` (through a scratch timing wrapper that would retry only on a musl fetch failure). Every build succeeded on its first attempt: no download failure, no retry.

   | Image | Build time |
   | --- | --- |
   | corpus tests | 9795 s (163 min) |
   | flow | 184 s |
   | transfer | 106 s |
   | example | 432 s |
   | gpuexample | 72 s |
   | probe | 192 s |
   | probefail | 132 s |
   | hello | 131 s |
   | monitor | 492 s |

   Every image and .dbg hash is in the evidence files, full length.
3. **Corpus** with `check-corpus.sh sigcorpustests tests-m4096 600 4096`: diff empty, PASS lines 782, last line `ALL LIBRARY TESTS PASSED`, QEMU 33, PASS, exit 0, wall 2.2 s.
   - `... tests-m32 600 32`: the same, wall 1.8 s.
   - Negative control `WRIT_NO_BOOT=1 WRIT_CORPUS_PASS=783 ...`: `PASS lines: 782, expected 783`, FAIL, exit 1.
4. **Examples** with `check-image.sh sigcorpus s2-<n>-m4096 <n> $W/corpus/linux/<n>-1.txt 33 <pass> 300 4096`. All have diff empty, QEMU 33, PASS and exit 0.

   | Example | PASS lines | Wall time |
   | --- | --- | --- |
   | flow | 4 | 0.4 s |
   | transfer | 4 | 0.4 s |
   | example | 16 | 0.6 s |
   | gpuexample | 5 | 0.4 s |

   - Negative control (flow against transfer's reference): diff NOT EMPTY, FAIL, exit 1.
5. **Effects probe.**
   - `run.sh sigeffects s2-probe-1 probe`: four probe lines, delta 107 ms, QEMU 33, wall 0.7 s.
   - `WRIT_CONSOLE_SED=... check-image.sh sigeffects s2-probe-{2,3,4} probe verification/unikernel-effects-probe-reference.txt 33 "" 60 1024`: diff empty, QEMU 33, PASS, exit 0 each. Deltas were 103, 103 and 105 ms; wall 0.8, 0.6 and 0.5 s.
   - FAIL branch: `run.sh ... s2-probefail-1 probefail` printed the FAIL line and gave QEMU 35. `WRIT_NO_BOOT=1 check-image.sh ... 33` gives diff NOT EMPTY and `QEMU exit: 35, expected 33`, FAIL, exit 1.
   - hello (no host layer): diff empty, QEMU 33, PASS, wall 0.8 s, and no writ_uk symbol.
6. **Channel.**
   - `check-channel.sh sigchannel s2acc monitor <accepted refs> 33 accept badlen badver other accept`: client exit 0, client diff empty, console diff empty, QEMU 33, PASS, exit 0, wall 1.0 s.
   - `s2den` (other badlen badver accept accept, denied refs): PASS, exit 0, wall 1.3 s.
   - `s2neg` (denied order against the accepted refs): client diff and console diff NOT EMPTY, FAIL, exit 1.
   - `run.sh ... s2noport`: the line `writ_uk: COM2 (0x2f8) does not answer; no second -serial, image exits 1`, QEMU 17, wall 0.5 s.
   - Flood with `$W/chanfix/flood <sock> 12`: 8 refusals, 4 dropped, 4 decisions, QEMU 33, wall 2.2 s.
   - `bend hosts/unikraft/monitor/MonitorCheck.bend`: 10 PASS, exit 0. Cross-check: the image replies equal MonitorCheck's, 4 replies in each order.
7. **Binary check** (`check-binary.sh`) on all nine new .dbg files:
   - corpus, examples and hello: IO.print, PASS, exit 0.
   - probe and probefail: Unikraft.log/now/sleep, FAIL, exit 1.
   - monitor: Unikraft.log/put/take, FAIL, exit 1.

   This is the same as before the library.

Exact console lines, run.sh command lines, and the full log and raw hashes are in each evidence file.

## Shutdown with signals (the SIGTERM risk from Task 1)

No effects or channel image hung. Every boot ended with its program's status in 0.4 to 2.2 s,
far inside the 60/120/600 s timeouts. The probe and the monitor create no helper thread: the
sleep and the take park on the runtime timer. So shutdown.c:61-67's SIGTERM-and-wait path is
not reached by them. Not BLOCKED.

## Not exercised

- The R0-E1 io_work variant of the probe, which is the one program that leaves a helper thread alive at shutdown and would reach the SIGTERM path. It was not rebuilt (it is history, not a shipped image), so signal value 19 is still not exercised.
- Channel: measure.sh timing and the split.py partial-frame run.
- The examples were run only at -m 4096. The corpus was run only at 4096 and 32.
- The binary-check negative control (bincheck/widened) was not rebuilt with signals. The sigfault/sigcodes .dbg files were not passed through check-binary.sh.
- `bend Tests.bend`, `bend PROOF.bend` and OpenSpec validation were not run. There is no Bend or document change in this task; Task 3 runs the suite and OpenSpec.
- No KVM, Firecracker, native or GPU run.

## Concerns

1. The corpus build took 163 min, against about 95 min before. It shared the host with the other builds and with load peaks near 277. The figure is not a regression measure.
2. The four channel reference files under `verification/` are named in the brief's `unikernel-channel-*.txt` but were not edited, because they are byte references (see above). The current record in `unikernel-channel-qemu.txt` names the library and the flag for them.
3. The earlier record's one-off gpuexample `pm.c` line (corpus3x) did not recur here. One boot shows nothing about its cause.
4. The scratch ProbeFail.bend imports `../../../unikraft-signals/...`, so it depends on this worktree's location. It is scratch only and is not committed.
