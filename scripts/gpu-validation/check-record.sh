#!/bin/sh
# Validation-run record checker and hardware-evidence gate (GV-001, GV-004).
#
# Usage:
#   sh scripts/gpu-validation/check-record.sh FILE
#   sh scripts/gpu-validation/check-record.sh --derive FILE
#   sh scripts/gpu-validation/check-record.sh --count-launches LOG BINARY_NAME
#
# FILE holds one or more `gpu-validation-record v1` records, each between a
# `--- record v1 ---` line and a `--- end record ---` line, one `key: value`
# per line. observe.sh writes a pair per workload: an observed pass (its
# `observer` value begins `compute-sanitizer`) and a plain pass (its
# `observer` value begins `none`).
#
# This script reads files and compares strings and counts. It makes no Writ
# authority, label or admission decision, and it never fills in a value: a
# field that is absent or empty is reported, not supplied.
#
# Default mode, in order:
#   1. Completeness. Every record must carry every field in REQUIRED with a
#      non-empty value, exactly once, and `record_version` must be
#      `gpu-validation-record v1`. Otherwise it prints
#      `INCOMPLETE: missing <field> (record N)` (or MALFORMED: ...) and exits 2.
#   2. Gate. The verdict is re-derived from the records and from the run-local
#      evidence files they name (sanitizer log, compute-apps poll log, pmon
#      and utilisation logs), each re-hashed against the sha256 the record
#      gives. The record's own `bend_dev_launches`, `compute_app_seen` and
#      `pmon_max_sm` claims are compared with the recount, never trusted.
#      A pair passes only if all of these hold:
#        - exactly one observed and one plain record, with identical inputs
#          (source, toolchain, build, device, environment, options, workload)
#          and identical stdout;
#        - `rts_options` contains `--gpu on` or `--gpu <size>`;
#        - `exit_status` is 0 in both;
#        - `correctness` is `PASS p, FAIL 0` with p >= 1 in both;
#        - the observed target saw the caller's CUDA_VISIBLE_DEVICES;
#        - the sanitizer log exists with the recorded hash, names this binary
#          and arguments as its target application, finished (ERROR SUMMARY),
#          has no "were not printed" truncation, and shows at least one
#          `bend_dev` launch whose host backtrace is in this binary; the
#          record's launch count equals that recount;
#        - the plain pass's compute-apps polls list the probe's PID at least
#          once (`compute_app_seen` yes, recounted);
#        - if the plain pass ran 10 s or longer: at least one utilisation
#          sample, and a per-PID pmon SM sample above 0.
#      It prints `gate: PASS` or `gate: FAIL (<reason>; ...)`.
#   3. Consistency. Each record's `gate` value must name the derived verdict.
#      A record that says PASS when the evidence says FAIL (or the reverse)
#      prints `GATE MISMATCH` and exits 3.
#   Exit 0: complete, gate PASS, records consistent. Exit 1: complete, gate
#   FAIL, records honestly say FAIL. Exit 2: incomplete or malformed. Exit 3:
#   a record's gate claim disagrees with its evidence. Exit 64: usage.
#
# --derive: the completeness check without `gate` (observe.sh calls it before
#   the gate line exists), then prints only the derived verdict
#   (`PASS`, `FAIL (...)`, or `INCOMPLETE (...)`) and exits 0.
# --count-launches: prints the number of `bend_dev` launches in a sanitizer
#   log whose saved host backtrace has a frame `in BINARY_NAME`.
#
# Utilisation is never a gate input for runs under 10 s: 1 s pmon samples can
# miss a short run, and the global utilisation reading cannot be attributed to
# the probe while the display shares the GPU.

set -u

REQUIRED="record_version lane_commit source_sha256 bend_version base cc cuda_home nvrtc_version build_flags emitted_c_sha256 binary_sha256 gpu_program_sha256 gpu_arch driver_version device_name device_uuid device_bus cuda_visible_devices rts_options threads workload exit_status stdout_sha256 stderr observer bend_dev_launches compute_app_seen pmon_max_sm util_samples wall_ms load_avg correctness gate"

# Fields that must be equal in the observed and plain record of a pair: the
# same inputs and environment, run twice.
PAIRED="lane_commit source_sha256 bend_version base cc cuda_home nvrtc_version build_flags emitted_c_sha256 binary_sha256 gpu_program_sha256 gpu_arch driver_version device_name device_uuid device_bus cuda_visible_devices rts_options threads workload stdout_sha256"

usage() {
  echo "usage: check-record.sh [--derive] FILE | --count-launches LOG BINARY_NAME" >&2
  exit 64
}

# bend_dev launches attributed to binary NAME: a launch block counts when its
# kernel is bend_dev and one saved host frame ends with " in NAME".
count_launches() {
  awk -v sfx=" in $2" '
    function close_block() { if (inb && k && a) n++ }
    /^========= Launch #/ { close_block(); inb = 1; k = 0; a = 0; next }
    inb && $0 == "=========   Kernel: bend_dev" { k = 1 }
    inb && index($0, "Host Frame:") > 0 \
      && length($0) >= length(sfx) \
      && substr($0, length($0) - length(sfx) + 1) == sfx { a = 1 }
    END { close_block(); print n + 0 }
  ' "$1"
}

if [ "${1-}" = "--count-launches" ]; then
  [ $# -eq 3 ] || usage
  [ -r "$2" ] || { echo "cannot read $2" >&2; exit 2; }
  count_launches "$2" "$3"
  exit 0
fi

DERIVE=0
if [ "${1-}" = "--derive" ]; then
  DERIVE=1
  shift
fi
[ $# -eq 1 ] || usage
FILE=$1
[ -r "$FILE" ] || { echo "INCOMPLETE: cannot read $FILE"; exit 2; }

WORK=$(mktemp -d "${TMPDIR:-/tmp}/check-record.XXXXXX") || exit 2
trap 'rm -rf "$WORK"' EXIT

# Split FILE into one file per record block. An unterminated block is
# malformed, not silently accepted.
awk -v dir="$WORK" '
  $0 == "--- record v1 ---" { if (open) { bad = 1 } n++; open = 1; out = dir "/rec." n; printf "" > out; next }
  $0 == "--- end record ---" { if (!open) { bad = 1 } open = 0; close(out); next }
  open { print > out }
  END { if (open) bad = 1; print n + 0 > (dir "/count"); print bad + 0 > (dir "/bad") }
' "$FILE"
NREC=$(cat "$WORK/count")
if [ "$(cat "$WORK/bad")" != 0 ]; then
  echo "MALFORMED: unbalanced record markers in $FILE"
  exit 2
fi
if [ "$NREC" -eq 0 ]; then
  echo "INCOMPLETE: no '--- record v1 ---' block in $FILE"
  exit 2
fi

# field N KEY: the value of KEY in record N (empty when absent).
field() {
  sed -n "s/^$2: //p" "$WORK/rec.$1" | head -n 1
}

# tok VALUE NAME: the NAME=... token of a space-separated value.
tok() {
  printf '%s\n' "$1" | tr ' ' '\n' | sed -n "s/^$2=//p" | head -n 1
}

# 1. Completeness: every required field present once and non-empty.
incomplete=""
i=1
while [ "$i" -le "$NREC" ]; do
  for f in $REQUIRED; do
    if [ "$DERIVE" -eq 1 ] && [ "$f" = gate ]; then
      continue
    fi
    c=$(grep -c "^$f:" "$WORK/rec.$i")
    if [ "$c" -gt 1 ]; then
      echo "MALFORMED: duplicate $f (record $i)"
      exit 2
    fi
    if [ -z "$(field "$i" "$f")" ]; then
      incomplete="${incomplete:+$incomplete; }missing $f (record $i)"
      [ "$DERIVE" -eq 1 ] || echo "INCOMPLETE: missing $f (record $i)"
    fi
  done
  v=$(field "$i" record_version)
  if [ -n "$v" ] && [ "$v" != "gpu-validation-record v1" ]; then
    echo "MALFORMED: record_version '$v' (record $i)"
    exit 2
  fi
  i=$((i + 1))
done
if [ -n "$incomplete" ]; then
  if [ "$DERIVE" -eq 1 ]; then
    echo "INCOMPLETE ($incomplete)"
    exit 0
  fi
  exit 2
fi

# 2. Gate, re-derived from the evidence.
reasons=""
fail() { reasons="${reasons:+$reasons; }$1"; }

# check_log NAME VALUE: the log=PATH log_sha256=HEX tokens of VALUE name a
# readable file with that hash. Sets LOG to the path on success; on failure
# records the reason and returns 1. (Not run in a subshell, so the reason
# reaches the verdict.)
check_log() {
  LOG=""
  p=$(tok "$2" log)
  h=$(tok "$2" log_sha256)
  if [ -z "$p" ] || [ -z "$h" ]; then
    fail "$1: no log= and log_sha256= in the record"
    return 1
  fi
  if [ ! -r "$p" ]; then
    fail "$1: log $p does not exist"
    return 1
  fi
  got=$(sha256sum "$p" | cut -d ' ' -f 1)
  if [ "$got" != "$h" ]; then
    fail "$1: log $p has sha256 $got, record says $h"
    return 1
  fi
  LOG=$p
}

OBS=""
PLN=""
nobs=0
npln=0
i=1
while [ "$i" -le "$NREC" ]; do
  case "$(field "$i" observer)" in
    compute-sanitizer*) OBS=$i; nobs=$((nobs + 1)) ;;
    none*) PLN=$i; npln=$((npln + 1)) ;;
    *) fail "record $i: observer is neither compute-sanitizer nor none" ;;
  esac
  i=$((i + 1))
done

if [ "$nobs" -ne 1 ] || [ "$npln" -ne 1 ]; then
  fail "pair: need one observed and one plain record (found $nobs observed, $npln plain)"
else
  for f in $PAIRED; do
    if [ "$(field "$OBS" "$f")" != "$(field "$PLN" "$f")" ]; then
      fail "pair: $f differs between the observed and plain record"
    fi
  done

  rts=$(field "$OBS" rts_options)
  if ! printf '%s\n' "$rts" | grep -E -q -e '--gpu (on|[0-9.]+(GB|MB))( |$)'; then
    fail "mode: rts_options '$rts' requests no device (--gpu on or a size is required)"
  fi

  for r in "$OBS" "$PLN"; do
    if [ "$r" = "$OBS" ]; then which=observed; else which=plain; fi
    st=$(field "$r" exit_status)
    [ "$st" = 0 ] || fail "$which: exit_status $st"
    cor=$(field "$r" correctness)
    p=$(printf '%s\n' "$cor" | sed -n 's/^PASS \([0-9][0-9]*\), FAIL \([0-9][0-9]*\).*/\1/p')
    q=$(printf '%s\n' "$cor" | sed -n 's/^PASS \([0-9][0-9]*\), FAIL \([0-9][0-9]*\).*/\2/p')
    if [ -z "$p" ] || [ "$p" -lt 1 ] || [ "$q" != 0 ]; then
      fail "$which: correctness '$cor' is not all PASS"
    fi
  done

  # Observed pass: launches recounted from the sanitizer log.
  ov=$(field "$OBS" observer)
  if check_log observer "$ov"; then
    log=$LOG
    bin=$(field "$OBS" binary_sha256 | sed 's/^[0-9a-f]*  //')
    args=$(field "$OBS" workload | sed -n 's/^.* args=//p')
    want="$bin"
    case "$rts" in none*) ;; *) want="$want $rts" ;; esac
    [ -n "$args" ] && want="$want $args"
    target=$(sed -n 's/^========= Target application: *//p' "$log" | head -n 1)
    [ "$target" = "$want" ] || fail "observer: log target '$target' is not '$want'"
    if grep -q 'were not printed' "$log"; then
      fail "observer: sanitizer output truncated (were not printed)"
    fi
    if grep -q 'Target application terminated before first instrumented API call' "$log"; then
      fail "observer: no CUDA API call was instrumented"
    fi
    # The observed target must have seen the caller's CUDA_VISIBLE_DEVICES
    # (observe.sh probes it through the sanitizer before the pass).
    cc_tok=$(tok "$ov" caller_cuda_visible_devices)
    tc_tok=$(tok "$ov" target_cuda_visible_devices)
    if [ -z "$cc_tok" ] || [ "$cc_tok" != "$tc_tok" ]; then
      fail "observer: target saw CUDA_VISIBLE_DEVICES '$tc_tok', caller set '$cc_tok' (environment not reproduced)"
    fi
    grep -q '^========= ERROR SUMMARY:' "$log" || fail "observer: sanitizer did not finish (no ERROR SUMMARY)"
    drv=$(sed -n 's/^========= Display Driver version: *//p' "$log" | head -n 1)
    [ "$drv" = "$(field "$OBS" driver_version)" ] || fail "observer: log driver '$drv' differs from driver_version"
    n=$(count_launches "$log" "$(basename "$bin")")
    claim=$(field "$OBS" bend_dev_launches)
    [ "$claim" = "$n" ] || fail "observer: record claims bend_dev_launches '$claim', log shows $n"
    [ "$n" -ge 1 ] || fail "launches: 0 bend_dev launches attributed to $(basename "$bin")"
  fi

  # Plain pass: process presence recounted from the compute-apps polls.
  cv=$(field "$PLN" compute_app_seen)
  if check_log compute_app_seen "$cv"; then
    log=$LOG
    pid=$(tok "$cv" pid)
    seen=0
    if [ -n "$pid" ]; then
      seen=$(grep -v '^#' "$log" | awk -F', *' -v pid="$pid" '$1 == pid { n++ } END { print n + 0 }')
    fi
    case "$cv" in
      yes*) [ "$seen" -ge 1 ] || fail "compute_app_seen: record says yes, polls show pid '$pid' $seen times" ;;
      *) [ "$seen" -eq 0 ] || fail "compute_app_seen: record says no, polls show pid $pid $seen times" ;;
    esac
    [ "$seen" -ge 1 ] || fail "compute_app_seen: probe pid '$pid' never listed by --query-compute-apps"
  fi

  # Samplers: always re-hashed; gating only for plain runs of 10 s or more.
  pv=$(field "$PLN" pmon_max_sm)
  uv=$(field "$PLN" util_samples)
  plog=""
  ulog=""
  check_log pmon_max_sm "$pv" && plog=$LOG
  check_log util_samples "$uv" && ulog=$LOG
  wall=$(field "$PLN" wall_ms)
  case "$wall" in
    ''|*[!0-9]*) fail "plain: wall_ms '$wall' is not a number" ;;
    *)
      if [ "$wall" -ge 10000 ]; then
        if [ -n "$plog" ]; then
          pid=$(tok "$pv" pid)
          max=$(awk -v pid="$pid" '$1 !~ /^#/ && $2 == pid && $4 ~ /^[0-9]+$/ { if ($4 + 0 > m + 0) m = $4 } END { print m + 0 }' "$plog")
          [ "$max" -gt 0 ] || fail "samplers: run of $wall ms has no per-PID SM sample above 0"
        fi
        if [ -n "$ulog" ]; then
          c=$(grep -c -E '^[0-9]+ %' "$ulog")
          [ "$c" -ge 1 ] || fail "samplers: run of $wall ms has no utilisation sample"
        fi
      fi
      ;;
  esac
fi

if [ -z "$reasons" ]; then
  verdict="PASS"
else
  verdict="FAIL ($reasons)"
fi

if [ "$DERIVE" -eq 1 ]; then
  echo "$verdict"
  exit 0
fi

echo "gate: $verdict"

# 3. Consistency: each record's gate claim names the derived verdict.
mismatch=0
i=1
while [ "$i" -le "$NREC" ]; do
  g=$(field "$i" gate)
  if [ "${g%% *}" != "${verdict%% *}" ]; then
    echo "GATE MISMATCH: record $i says '${g%% *}', the evidence gives '${verdict%% *}'"
    mismatch=1
  fi
  i=$((i + 1))
done
[ "$mismatch" -eq 0 ] || exit 3
[ "$verdict" = PASS ] && exit 0
exit 1
