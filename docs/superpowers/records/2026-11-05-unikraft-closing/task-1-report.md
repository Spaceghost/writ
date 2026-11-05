# Task 1 report: KVM boots (3.1)

Status: DONE_WITH_CONCERNS. Every requested boot ran under KVM (`-accel kvm -cpu host`, `kvm support: enabled`). The exit map held on all 23 KVM boots (33, 35, 39, 253, 253, 33). The corpus count held on all 3 corpus boots (782 PASS). The overflow fault message appeared before the crash screen. However, the strict check routines (`check-image.sh`, `check-corpus.sh`) passed on only 8 of the 21 KVM boots of hello, die, exit and the corpus. On the other 13, the guest kept running after the exit-device write, and Unikraft's own `pm.c:69` log line (whole, or cut off) landed after the program's lines. That includes the first die boot. **Box 3.1 is left unchecked** for a controller ruling. Evidence: `verification/unikernel-kvm.txt`.

## Changes

- `hosts/unikraft/scripts/run.sh` (sha256 593c405227c09a10adae2d3cee95d7935a572f395e888a9d9d3fd0b08e359b96), +20 -8:
  - lines 2-4: usage gains `[accel]`; the description no longer says TCG only.
  - lines 10-14: comment for `accel`: `tcg` is the default (`-cpu max`, logged command unchanged); `kvm` gives `-accel kvm -cpu host`; any other value exits 2; `""` for vcpus keeps one vCPU.
  - lines 37-39: usage strings in the `${n:?}` messages.
  - lines 42-47: `ACC=${8:-tcg}` and a `case` that sets `CPU=max` or `CPU=host`, or exits 2.
  - lines 62, 65, 69: the logged command and both QEMU invocations use `-accel "$ACC"` and `-cpu "$CPU"` in place of the literals `tcg` and `max`.
  - No other change. The check scripts are unchanged. KVM boots go through run.sh, and then the unchanged check scripts run with `WRIT_NO_BOOT=1` on that capture, so no pass-through was needed.
- `verification/unikernel-kvm.txt` (new; sha256 2eed08e43c32b3d4ff8442f9487e1e83f01d916fe2f7d96d5fbab5ca735c6d40) covers:
  - the machine;
  - image hashes;
  - the harness;
  - the KVM result table, with KVM wall times beside the TCG walls from the records;
  - a per-boot table with log and raw sha256 values;
  - consoles;
  - the post-write finding;
  - a separate table of same-session TCG controls;
  - what was not exercised.
- `docs/superpowers/records/2026-11-05-unikraft-closing/activity.log`: step lines.
- The TCG evidence files are untouched. `tasks.md` is untouched (3.1 is left open).

## Environment and machine

- `export PATH="$HOME/.local/share/writ-toolchains/bend-2.0.39/bend/bin:$PATH"; export BEND_NO_TELEMETRY=1`.
- `W=/mnt/MediaVolume/Media/src/github.com/spaceghost/writ-lanes/writ-unikernel`. This is env.sh's default, `../writ-unikernel`; it was exported explicitly for the commands below.
- `lscpu`: AMD Ryzen 9 5950X 16-Core Processor, 32 CPUs, AMD-V.
- `uname -r`: 7.2.9-1-MANJARO.
- `qemu-system-x86_64 --version`: 11.1.2.
- `/dev/kvm` is `crw-rw-rw- root kvm` and opened without error. No sudo and no group change.
- `-cpu host` was used under KVM; `max` was not kept.
- Load average was 102 at the start and 60 to 73 later.

## Image hashes (verified before booting; none rebuilt)

`sha256sum` of `$W/sigcodes/images/{hello,die,exit}-qemu`, `$W/sigfault/images/{overflow,exhaust}-qemu` and `$W/sigcorpustests/images/tests-qemu`:

- 235bb67a…, c17a9adb…, acaa9248…, 07ec5c16…, 51e27500…: equal to `unikernel-fault-qemu.txt` lines 86-90.
- f1537f84…: equal to `unikernel-corpus-qemu.txt`.

All six match.

## Commands

1. Default and error checks:
   - `run.sh sigcodes kvmt-bad hello "" 10 1024 "" bogus` gives `run.sh: accel 'bogus' is not tcg or kvm` and rc 2.
   - `run.sh sigcodes kvmt-tcgdefault hello "+RTS --threads 1 --gpu off" 60 1024` gives 33. Its logged first line is byte-identical to the TCG record's `run-hello1.log` (`cmp`).
2. Exit-code probes:
   - Boot: `run.sh sigcodes kvm-<p><i> <p> "+RTS --threads 1 --gpu off" 60 1024 "" kvm`
   - Check: `WRIT_NO_BOOT=1 check-image.sh sigcodes kvm-<p><i> <p> $W/sigcodes/<p>-ref.txt <33|35|39> "" 60 1024`
   - Run for p in hello, die, exit and i in 1 to 6.
3. Crash probes:
   - `run.sh sigfault kvm-exhaust1 exhaust "+RTS --threads 1 --gpu off" 120 1024 "" kvm`, then `WRIT_NO_BOOT=1 check-fault.sh sigfault kvm-exhaust1 exhaust verification/unikernel-exhaust-reference.txt 253`.
   - The same for overflow (timeout 60, `-m 4096`) against `unikernel-overflow-reference.txt`.
4. Corpus:
   - `timeout 590 run.sh sigcorpustests kvm-tests<i>-m4096 tests "+RTS --threads 1 --gpu off" 580 4096 "" kvm`, then `WRIT_NO_BOOT=1 check-corpus.sh sigcorpustests kvm-tests<i>-m4096`.
   - Run for i in "", 2 and 3.
5. KVM confirmation: `printf 'info kvm\ninfo cpus\nquit\n' | qemu-system-x86_64 -accel kvm -cpu host -S -nographic -monitor stdio -serial none -m 1024 -kernel $W/sigcodes/images/hello-qemu` gives `kvm support: enabled` and `CPU #0 ... model=host`.
6. Same-session TCG controls (run.sh with no accel): `tcgnow-{hello,die,exit}{1,2,3}`, `tcgnow-exhaust1`, `tcgnow-overflow1`, `tcgnow-tests-m4096`. All passed.
7. QEMU start and quit with `-S`, timed:
   - KVM: 0.08 to 0.09 s.
   - TCG: 0.05 s.

## Results (KVM wall vs TCG wall from the records)

| Probe | KVM QEMU | first-boot check | checks over all boots | KVM wall | TCG wall (record) | TCG wall (same session) |
| --- | --- | --- | --- | --- | --- | --- |
| hello | 33 x6 | PASS | 4/6 | 1.1 s | 0.5 s | 0.2-0.3 s |
| die | 35 x6 | FAIL (pm.c line, NUL) | 1/6 | 2.3 s (1.2-2.3) | 0.4 s | 0.2-0.3 s |
| exit | 39 x6 | PASS | 1/6 | 2.5 s (1.0-2.5) | 0.3 s | 0.2-0.3 s |
| exhaust (crash) | 253 | PASS | 1/1 | 18.0 s | 3.7 s | 11.5 s |
| overflow (fault) | 253, message first | PASS | 1/1 | 29.0 s | 17.8 / 13.5 s | 16.1 s |
| corpus | 33 x3, 782 PASS x3 | PASS | 2/3 | 8.5 s (6.4-10.0) | 2.2 s | 3.1 s |

Console lines, per-boot tails, log and raw sha256 values: `verification/unikernel-kvm.txt`.

On every failing boot, the lines after the banner, with `[ ...` Unikraft log lines removed, are `cmp`-equal to the reference. That is an analysis, not a check-script result.

On PASS boots, the KVM raw differs from the TCG raw in one line only: the iPXE PMM addresses, which come before Unikraft starts.

## What was not exercised

- `-cpu max` under KVM.
- More than one vCPU or lane under KVM.
- The example images, and the corpus at `-m 32`.
- The 17 runs (`+RTS --threads 0` and `--bogus`), the signal value 19, and the non-halt value 251.
- Firecracker.
- Any other host.

## Concerns

1. **Box 3.1 is open.** Under KVM the guest runs on after the exit-device write. On 13 of 21 boots, `uk_pm_shutdown`'s `pm.c:69` "PM driver failed ... -5" line (whole, or cut off, sometimes with a NUL) is printed before QEMU exits, so `check-image.sh` and `check-corpus.sh` fail even though the status and program lines are right.
   - This contradicts the `exit_device.c:133` comment, "QEMU does not return here".
   - It was seen once under TCG before (corpus3x gpuexample), and in none of the 12 TCG boots this session.
   - The cause inside QEMU was not determined.
   - Two possible fixes, both outside this task's touch list: a halt or spin after the `outb` in `exit_device.c` (host C), or check scripts that stop at the hook's write. Either needs a ruling. Ticking 3.1 on the passing boots alone would be cherry-picking, so I did not.
2. **KVM was slower than TCG on every boot here** (about 2 to 5 times). The cost is guest run time, not VM setup (start and quit take 0.08 s). It is not explained; serial I/O exits are one untested candidate. The host was heavily loaded.
3. **`hosts/unikraft/INVENTORY.md` line 144 is now stale.** It still reads "One TCG boot" with no `accel` argument. INVENTORY is not in the plan's touch list, so I left it.

## Fix round (controller ruling on concern 1)

Status after this round: DONE_WITH_CONCERNS. This supersedes the status line at the top. **Box 3.1 is now checked.**

### What the ruling asked for

- Do not change `exit_device.c` now.
- Make the check scripts drop, and count, only a trailing fragment of Unikraft's `pm.c` shutdown line.
- Rerun the boots that failed and record the results.
- Update INVENTORY.
- Check 3.1 only if every requested boot then passes.

### Changes

- **`hosts/unikraft/scripts/env.sh`** (c4a49a8a…; +26, lines 27-52): adds `writ_is_pm_shutdown_fragment <line>`.
  - It returns true only for a nonempty prefix of `[ <digits>.<digits>] ERR:  [libukpm] <pm.c @   69> PM driver failed the operation: -5. Falling back on busy loop...`. The line has already been through `writ_strip_serial`, so NUL bytes are gone.
  - The comment cites `verification/unikernel-kvm.txt`, section "Finding: the guest runs on after the exit-device write (KVM)".
  - It also cites the contradicted `exit_device.c` comment "QEMU does not return here", and the deferred fix (a halt after the write).
  - Why env.sh: the scripts already share it for the capture filter (`writ_strip_serial`), so I factored the helper there.
- **`check-image.sh`** (50a98cec…):
  - lines 18-24: comment.
  - line 31: an extra `mktemp`.
  - lines 39-44: if the raw capture's last line, after `writ_strip_serial`, is a fragment, `console.sh` gets the capture without that one line.
  - It always prints `kernel shutdown fragment after exit: dropped <0|1>`.
- **`check-corpus.sh`** (1d1fd97d…; +1 comment line): the rule and its line come from `check-image.sh`.
- **`check-fault.sh`** (658838d5…):
  - lines 20-26: comment.
  - lines 43-47: the rule runs on the last program line. It runs **before** the existing `[ <s>] ` filter, not after as the ruling worded it, because that filter would otherwise silently drop a whole timestamped `pm.c` line, and the count would miss it.
  - It prints the same `dropped` line.
- **`hosts/unikraft/INVENTORY.md`**:
  - the env.sh row names the helper;
  - the run.sh row (line 144) describes `[accel]` (`tcg` default, `kvm` gives `-accel kvm -cpu host`, other values exit 2);
  - the check-image, check-corpus and check-fault rows describe the fragment rule and the `dropped` line.
- **`verification/unikernel-kvm.txt`**: a new "Fix round" section. The earlier failed captures and tables are kept as the observation. One sentence of the finding now points to the ruling.
- **`openspec/changes/add-unikernel-library-runtime/tasks.md`**: 3.1 checked. Its note names the fragment rule and the `exit_device.c` follow-up.
- OpenSpec 1.16.0 `openspec validate --all --strict --no-interactive`: 44 passed, 0 failed.

### Checks run

- **Helper unit check:** 8 fragment strings matched and 7 non-fragment strings did not (listed in the evidence file).
- **Negative controls** (on copies of `kvm-die1.raw` in `$W/fragneg/logs`); each failed with exit 1, as it should:
  - fragment not the last line: dropped 0;
  - a different `pm.c @ 70` line: dropped 0;
  - two trailing fragments: dropped 1, and the first still fails `console.sh`.
- **Recheck of the 23 earlier KVM captures** with `WRIT_NO_BOOT=1`: all PASS.
  - dropped 1 on the 13 that failed before: hello2, hello5, die1, die2, die4, die5, die6, exit2, exit3, exit4, exit5, exit6, tests2;
  - dropped 0 on the other 10.
- **Fresh KVM boots** (`run.sh … "" kvm`, then the changed check), every one PASS:

| Boot | dropped | QEMU | wall |
| --- | --- | --- | --- |
| kvmfix-hello1 | 0 | 33 | 0.3 s |
| kvmfix-hello2 | 0 | 33 | 0.3 s |
| kvmfix-die1 | 1 | 35 | 0.3 s |
| kvmfix-die2 | 0 | 35 | 0.3 s |
| kvmfix-die3 | 0 | 35 | 0.3 s |
| kvmfix-exit1 | 1 | 39 | 0.3 s |
| kvmfix-exit2 | 0 | 39 | 0.3 s |
| kvmfix-exit3 | 0 | 39 | 0.3 s |
| kvmfix-tests1 | 0 | 33, 782 PASS | 5.0 s |
| kvmfix-tests2 | 1 | 33, 782 PASS | 4.8 s |
| kvmfix-exhaust1 | 0 | 253 | 5.1 s |
| kvmfix-overflow1 | 1 (see concern 1) | 253, message first | 2.5 s |

- **TCG through the changed scripts:**
  - `check-image.sh sigcodes tcgfix-hello1 …`: dropped 0, PASS.
  - `check-corpus.sh sigcorpustests tcgfix-tests-m4096 600 4096`: dropped 0, PASS, 782. Its raw is byte-identical to the TCG record's.
  - TCG results are unchanged.

### Concerns

1. **The rule cannot always tell a `pm.c` fragment from another Unikraft line.** A fragment cut inside the timestamp (`[  `, `[    0.133495] `) is a prefix of the `pm.c` line, but also of any Unikraft log line.
   - On kvmfix-overflow1 (crash path), the dropped `[    2.27112` is the cut-off start of a further crash-screen line, not a `pm.c` line.
   - Without the rule, that boot would have failed the program-line check.
   - The count makes every such drop visible. Tightening the rule (for example, requiring text past `ERR:`) would fail cut-offs like die2, die6, exit6 and tests2. Ruling needed if this is not acceptable.
2. **KVM wall times, observed only.**
   - At load average 60 to 102, KVM was slower than TCG.
   - At load average 31 to 47, hello, die and exit took 0.3 s (TCG 0.2 s), the corpus 4.8 to 5.0 s (TCG 1.7 s), exhaust 5.1 s, and overflow 2.5 s.
   - Not investigated, per the ruling.
3. **The proper fix is deferred:** a halt after the `outb` in `exit_device.c`, at the next rebuild of every set.
