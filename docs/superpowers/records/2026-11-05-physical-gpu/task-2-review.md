# Task 2 review: validation-run record, hardware-evidence gate, negative controls

Reviewer scope: read-only except this file. Commit under review: 50ed67c (base 23b82c8).

## Verdicts
1. Spec compliance: APPROVED
2. Script correctness and record quality: APPROVED (four low-severity hardening notes, none blocking)

## Findings, by severity (all low; none lets a record pass without an observed launch)

1. LOW, scripts/gpu-validation/observe.sh:262,278. SANLOG is not removed before the observed pass. I checked that compute-sanitizer overwrites an existing --log-file, including when the target fails to start (marker file replaced by the sanitizer's error text), so a stale log is not currently reachable. Fix: add `rm -f "$SANLOG"` before line 278 so the property does not depend on sanitizer behaviour.
2. LOW, observe.sh:273-275. `target_cuda_visible_devices` comes from a separate probe (`compute-sanitizer sh -c ...`), not from the probed binary's own environment. It is a sound inference (sanitizer strips the empty value; verified in the evidence file lines 686-700) and fails closed if the probe prints nothing, but the record should say "inferred by a sibling probe". Fix: add that wording to the observer-field comment or the Limits section.
3. LOW, check-record.sh:289-303. The pid in `pmon_max_sm` is not compared with the pid in `compute_app_seen`. Only matters for a forger, who is already out of scope. Fix: `[ "$(tok "$pv" pid)" = "$(tok "$cv" pid)" ] || fail ...`.
4. LOW, check-record.sh (no line). `binary_sha256` and the sanitizer target path are not re-hashed at check time. The report and Limits state this. Fix when convenient: if the binary path exists, re-hash and fail on mismatch, or keep it a stated limit.

Not findings (controller rulings and stated limits): the invalid-id convention for hiding the device, unsigned evidence, GPU 0 identity on a one-GPU host, separate exit statuses.

## 1. Spec compliance (details)
- Record: `gpu-validation-record v1`, one key per line. REQUIRED (check-record.sh:66) lists all 33 plan fields in plan order. Every record in the evidence file carries them. A missing or empty field gives `INCOMPLETE: missing <field> (record N)` and exit 2 (check-record.sh:151-153); control (f) shows it for driver_version.
- Gate (check-record.sh:222-311): requires `--gpu on` or a size (regex line 223), both exit statuses 0, correctness `PASS p>=1, FAIL 0`, the sanitizer log hash re-verified, at least one bend_dev launch with a host frame in this binary, the compute-apps poll listing the probe pid, and the 10 s sampler rule for plain runs. Verdict is re-derived, never trusted; a record whose gate claim differs gets exit 3.
- Controls present, each with command, output and exit status. Only (a) and (a-long) pass.
  - (b) `--gpu off`: FAIL, mode reason.
  - (c) silent fallback, empty CUDA_VISIBLE_DEVICES: plain exit 0, checksum PASS on the CPU, FAIL with the mode reason. (c2) with id 99: observed launches 0.
  - (d) `--gpu on`, device hidden: `bend: cuInit failed: CUDA_ERROR_NO_DEVICE`, exit 1, quoted at evidence lines 437 and 926. (d2) same with id 99.
  - (e) repeat 0 under `--gpu on`: exit 0, context opened, 0 launches, FAIL.
  - (f) missing field: exit 2.
  - Extras: (g) forged record with no sanitizer log (exit 3), (g2) inflated launch count (exit 3), (h) truncated log with re-hashed record (exit 3).
- Literal deviation from the brief: in (c) and (d) the observed pass shows 500 launches because the sanitizer strips the empty variable. This is the finding, stated clearly with version 2026.3.0.0 (evidence lines 686-700 and Result). The gate still refuses both pairs, and (c2) and (d2) cover the zero-launch intent. Controller ruling applies.
- observe.sh fails closed on truncation (warns at lines 284-286; the gate fails at check-record.sh:250-252, shown by (h)) and on an environment the sanitizer changed (check-record.sh:258-262, shown by (c) and (d)).
- Touch list: the diff 23b82c8..50ed67c contains only scripts/gpu-validation/{observe,check-record}.sh, verification/gpu-gate-controls.txt, and the lane record dir (report, activity.log). No .bend file added or changed (Bang.bend untouched), no count pin, no manifest change.

## 2. Script correctness and record quality (details)
Read both scripts in full.
- Ways to pass without an observed launch, tried against the code:
  - Another run's log: the target line must equal this binary plus options and args, the hash must match, the driver must match, and compute-sanitizer overwrites its log (verified). Only a consistent forgery gets through; that is the stated limit.
  - Wrong-line count: count_launches (check-record.sh:79-89) counts a block only when the kernel line is exactly `Kernel: bend_dev` and a Host Frame line ends in ` in <binary>`. I confirmed 500 for `bang` and 0 for `ban`.
  - "0 launches" matching as a launch: the count is numeric and compared with `-ge 1`; the record's claim must equal the recount.
  - Missing exit-status check: both passes must exit 0. The `ERROR SUMMARY`, driver and truncation checks fail closed.
- Quoting: `$RTS` and `$GV_SOURCES` are intentionally unquoted; the exec wrapper passes the arguments through `"$@"`; stderr is flattened to one line, so it cannot inject record lines; duplicate fields give MALFORMED. Paths with spaces fail closed. No bug found.
- Record quality: the evidence file has the plan's shape. Every control has its command, full record pair, exit statuses (probe in the plain record, sanitizer in the observed record), sha256 of the scripts, binary and logs, and uptime or load_avg. The header and Limits carry the load caveat (load average 43 to 92) for wall times. I re-ran check-record.sh on the eight stored records: exit statuses 0, 0, 1, 1, 1, 1, 1, 1 as recorded. The hashes of observe.sh, check-record.sh and the evidence file equal the report's.
- Scope of claims: the Limits say no Writ GPU path was run and that this is bang only; nothing reads as a path being validated. The wall times are not presented as performance.

## Ran
sha256sum of both scripts and the evidence file; check-record.sh on the eight stored control records and `--count-launches` on (a)'s log (bang and ban); compute-sanitizer on `true` and a missing path to test log overwrite (no GPU workload); git diff --name-only 23b82c8..HEAD. Did not rerun observe.sh or any GPU workload.
