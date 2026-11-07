#!/bin/sh
# Observed validation run of one GPU probe workload (GV-001, GV-004).
#
# Usage:
#   GV_SOURCES="scripts/gpu-validation/Bang.bend ..." \
#     sh scripts/gpu-validation/observe.sh PROBE_BIN MODE ARGS...
#
#   MODE is `on`, `off`, a size such as `8GB` (each passed as
#   `+RTS --gpu MODE -RTS`), or `default` (no +RTS block: the runtime's own
#   default, which probes the device and falls back to the CPU in silence).
#   ARGS are the probe's arguments (for bang: REPEATS).
#   CR/LF and RTS delimiter substrings in ARGS are refused before launch:
#   v1 flattens arguments and cannot safely represent them.
#   GV_SOURCES lists, relative to the worktree root, the probe source and
#   every library `.bend` it imports. When it is unset the `source_sha256`
#   field stays empty and the record is INCOMPLETE; nothing is guessed.
#   GV_EMITTED_C names the emitted C (default PROBE_BIN.c); the GPU program is
#   PROBE_BIN.gpu, where the runtime writes it.
#   GV_RUN_DIR names the run directory (default
#   ../writ-build/physical-gpu/runs/<probe>-<mode>-<UTC>-<pid>).
#
# The same binary and arguments run twice, with the environment the caller
# gave (CUDA_VISIBLE_DEVICES included, recorded as unset, empty or its value):
#   1. plain pass: an idle baseline sample; `nvidia-smi pmon -s u -d 1` and
#      `nvidia-smi --query-gpu=utilization.gpu,memory.used --format=csv
#      -lms 200` under `timeout` into run-local files; the probe under
#      `timeout 600`, its PID captured by an exec wrapper; and
#      `--query-compute-apps` polled every 200 ms while it runs. This pass
#      gives `compute_app_seen`, the sampler fields and the wall time.
#   2. observed pass: the probe under `timeout 600 compute-sanitizer
#      --print-session-details --log-file LOG --dump-kernel-launches
#      --print-limit 0 --kernel-name-exclude regex=.*`. This pass gives the
#      bend_dev launch count (recounted by check-record.sh from LOG) and a
#      second correctness result; its `exit_status` is compute-sanitizer's.
# It then writes both records to RUN/record.txt, asks check-record.sh
# --derive for the gate verdict, adds the `gate` line, prints the file, and
# exits with check-record.sh's status on the finished file (0 PASS, 1 FAIL,
# 2 INCOMPLETE, 3 MISMATCH).
#
# This harness starts processes, samples nvidia-smi and hashes files. It
# makes no Writ authority, label or admission decision; correctness is the
# probe's own PASS/FAIL lines. A value it cannot establish is left empty so
# that the record is INCOMPLETE, never filled in. nvidia-smi reports physical
# GPU 0 and ignores CUDA_VISIBLE_DEVICES; `cuda_visible_devices` records what
# the CUDA runtime was shown.

set -u

usage() {
  echo "usage: [GV_SOURCES=...] observe.sh PROBE_BIN MODE ARGS..." >&2
  echo "  MODE: on | off | default | a size such as 8GB" >&2
  exit 64
}

[ $# -ge 2 ] || usage
# Refuse ambiguous workload arguments before creating output or starting any
# probe. The v1 record flattens argv, and later RTS blocks can override MODE.
writ_cr=$(printf '\r')
writ_lf='
'
for writ_arg do
  case "$writ_arg" in
    *"$writ_cr"*|*"$writ_lf"*|*+RTS*|*-RTS*)
      echo 'observe.sh: argument contains a line break or RTS delimiter' >&2
      exit 64 ;;
  esac
done
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../.." && pwd)
CHECK="$HERE/check-record.sh"
BIN=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
MODE=$2
shift 2
[ -x "$BIN" ] || { echo "observe.sh: $BIN is not an executable" >&2; exit 64; }

case "$MODE" in
  on|off) RTS="+RTS --gpu $MODE -RTS" ;;
  default) RTS="" ;;
  *[0-9]GB|*[0-9]MB) RTS="+RTS --gpu $MODE -RTS" ;;
  *) usage ;;
esac

# Runtime options must all be on the command line, where the record names
# them. The runtime also reads BENDRTS; refuse rather than run with options
# the record would not show.
if [ -n "${BENDRTS-}" ]; then
  echo "observe.sh: BENDRTS is set ('$BENDRTS'); refusing, options must be on the command line" >&2
  exit 64
fi

NAME=$(basename "$BIN")
RUN=${GV_RUN_DIR:-$ROOT/../writ-build/physical-gpu/runs/$NAME-$MODE-$(date -u +%Y%m%dT%H%M%SZ)-$$}
mkdir -p "$RUN" || exit 2
RUN=$(cd "$RUN" && pwd)

sha() { [ -r "$1" ] && sha256sum "$1" | cut -d ' ' -f 1; }
now_ms() { date +%s%3N; }
oneline() {
  # A file as one line: newlines shown as \n; an empty file is "empty".
  if [ -s "$1" ]; then
    awk 'NR > 1 { printf "\\n" } { printf "%s", $0 } END { printf "\n" }' "$1"
  else
    echo empty
  fi
}

# ---- Facts shared by both passes ------------------------------------------

lane=$(git -C "$ROOT" rev-parse HEAD 2>/dev/null)
dirty=$(git -C "$ROOT" status --porcelain --untracked-files=all -- ${GV_SOURCES-} scripts/gpu-validation 2>/dev/null | tr '\n' ',' | sed 's/,$//; s/,/, /g')
[ -n "$lane" ] && lane="$lane (${dirty:+uncommitted: }${dirty:-clean})"

sources=""
if [ -n "${GV_SOURCES-}" ]; then
  for s in $GV_SOURCES scripts/gpu-validation/observe.sh scripts/gpu-validation/check-record.sh; do
    h=$(sha "$ROOT/$s")
    if [ -z "$h" ]; then
      echo "observe.sh: cannot read source $s" >&2
      sources=""
      break
    fi
    sources="${sources:+$sources }$s=$h"
  done
fi

bendp=$(command -v bend)
bendv=""
[ -n "$bendp" ] && bendv="$(bend version) (driver $bendp sha256 $(sha "$bendp"))"
base=$( [ -n "$bendp" ] && bend base | sha256sum | cut -d ' ' -f 1)

ccn=${CC:-clang}
ccp=$(command -v "$ccn")
cc=""
[ -n "$ccp" ] && cc="$ccp $("$ccp" --version | head -n 1) (the compiler the driver selects here; the build is bound by emitted_c_sha256 and binary_sha256)"

cuda_home=${CUDA_HOME-}

nvp=$(ldd "$BIN" 2>/dev/null | sed -n 's/^[[:space:]]*libnvrtc[^ ]* => \([^ ]*\) .*/\1/p' | head -n 1)
nvrtc=""
if [ -n "$nvp" ]; then
  nvr=$(readlink -f "$nvp")
  nvrtc="$(basename "$nvr" | sed 's/^libnvrtc\.so\.//') ($nvr, resolved by ldd for the binary)"
fi

# The GPU build flags, copied verbatim from the pinned driver's cli_build.
flags=""
if [ -n "$bendp" ]; then
  flags=$(strings -n 6 "$bendp" | sed -n '/^  const cpu = \[$/,/^  const steps = /p' | sed 's/^ *//' | tr '\n' ' ' | sed 's/ *$//')
  [ -n "$flags" ] && flags="driver cli_build, verbatim: $flags"
fi

csrc=${GV_EMITTED_C:-$BIN.c}
emitted=""
h=$(sha "$csrc") && emitted="$h  $csrc"
binsha=""
h=$(sha "$BIN") && binsha="$h  $BIN"
gpusha=""
arch=""
if h=$(sha "$BIN.gpu"); then
  gpusha="$h  $BIN.gpu"
  tail -c +9 "$BIN.gpu" > "$RUN/program.cubin"
  a=$(cuobjdump -elf "$RUN/program.cubin" 2>/dev/null | grep -m 1 -o 'sm=[0-9]*')
  [ -n "$a" ] && arch="$a (cuobjdump -elf of $NAME.gpu after its 8-byte header)"
fi

q=$(nvidia-smi -i 0 --query-gpu=driver_version,name,uuid,pci.bus_id --format=csv,noheader 2>/dev/null)
drv=$(printf '%s\n' "$q" | awk -F', ' '{ print $1 }')
dname=$(printf '%s\n' "$q" | awk -F', ' '{ print $2 }')
duuid=$(printf '%s\n' "$q" | awk -F', ' '{ print $3 }')
dbus=$(printf '%s\n' "$q" | awk -F', ' '{ print $4 }')

if [ "${CUDA_VISIBLE_DEVICES+set}" != set ]; then
  cvd="unset"
elif [ -z "$CUDA_VISIBLE_DEVICES" ]; then
  cvd="set, empty"
else
  cvd="set: $CUDA_VISIBLE_DEVICES"
fi

rtsv=${RTS:-none (no +RTS block; BENDRTS unset)}
threads="runtime default: cpu_count() (nproc $(nproc))"
workload="probe=$NAME mode=$MODE args=$*"

# common FILE: the shared fields, in record order.
common() {
  {
    echo "record_version: gpu-validation-record v1"
    echo "lane_commit: $lane"
    echo "source_sha256: $sources"
    echo "bend_version: $bendv"
    echo "base: $base"
    echo "cc: $cc"
    echo "cuda_home: $cuda_home"
    echo "nvrtc_version: $nvrtc"
    echo "build_flags: $flags"
    echo "emitted_c_sha256: $emitted"
    echo "binary_sha256: $binsha"
    echo "gpu_program_sha256: $gpusha"
    echo "gpu_arch: $arch"
    echo "driver_version: $drv"
    echo "device_name: $dname"
    echo "device_uuid: $duuid"
    echo "device_bus: $dbus"
    echo "cuda_visible_devices: $cvd"
    echo "rts_options: $rtsv"
    echo "threads: $threads"
    echo "workload: $workload"
  } > "$1"
}

# correctness FILE: the probe's PASS/FAIL line counts.
correctness() {
  p=$(grep -c '^PASS' "$1")
  f=$(grep -c '^FAIL' "$1")
  echo "PASS $p, FAIL $f (lines beginning PASS/FAIL in the probe stdout)"
}

# ---- 1. Plain pass ---------------------------------------------------------

baseline=$(nvidia-smi --query-gpu=utilization.gpu,memory.used --format=csv,noheader 2>/dev/null | tr -d ' ')
nvidia-smi --query-compute-apps=pid,process_name,used_memory --format=csv,noheader > "$RUN/baseline.apps" 2>&1

timeout 620 nvidia-smi pmon -s u -d 1 > "$RUN/plain.pmon" 2>&1 &
PM=$!
timeout 620 nvidia-smi --query-gpu=utilization.gpu,memory.used --format=csv -lms 200 > "$RUN/plain.util" 2>&1 &
UT=$!
sleep 1

load_plain=$(uptime | sed 's/^ *//')
rm -f "$RUN/plain.pid"
t0=$(now_ms)
# The wrapper writes its own PID and execs the probe, so the PID that
# --query-compute-apps lists is that PID.
timeout 600 sh -c 'echo $$ > "$0"; exec "$@"' "$RUN/plain.pid" "$BIN" $RTS "$@" \
  > "$RUN/plain.stdout" 2> "$RUN/plain.stderr" &
TP=$!
: > "$RUN/plain.apps"
polls=0
while kill -0 "$TP" 2>/dev/null; do
  polls=$((polls + 1))
  echo "# poll $polls $(date -u +%FT%T.%3NZ)" >> "$RUN/plain.apps"
  nvidia-smi --query-compute-apps=pid,process_name,used_memory --format=csv,noheader >> "$RUN/plain.apps" 2>&1
  sleep 0.2
done
wait "$TP"
st_plain=$?
t1=$(now_ms)
kill "$PM" "$UT" 2>/dev/null
wait "$PM" "$UT" 2>/dev/null
pid=$(cat "$RUN/plain.pid" 2>/dev/null)

seen=$(grep -v '^#' "$RUN/plain.apps" | awk -F', *' -v pid="$pid" '$1 == pid { n++ } END { print n + 0 }')
if [ -n "$pid" ] && [ "$seen" -ge 1 ]; then yn=yes; else yn=no; fi
pmon_rows=$(awk -v pid="$pid" '$1 !~ /^#/ && $2 == pid { n++ } END { print n + 0 }' "$RUN/plain.pmon")
pmon_num=$(awk -v pid="$pid" '$1 !~ /^#/ && $2 == pid && $4 ~ /^[0-9]+$/ { n++ } END { print n + 0 }' "$RUN/plain.pmon")
pmon_max=$(awk -v pid="$pid" '$1 !~ /^#/ && $2 == pid && $4 ~ /^[0-9]+$/ { if ($4 + 0 > m + 0) m = $4; n++ } END { if (n) print m + 0; else print "-" }' "$RUN/plain.pmon")
usamples=$(grep -c -E '^[0-9]+ %' "$RUN/plain.util")

common "$RUN/plain.rec"
{
  echo "exit_status: $st_plain"
  echo "stdout_sha256: $(sha "$RUN/plain.stdout")"
  echo "stderr: $(oneline "$RUN/plain.stderr")"
  echo "observer: none (plain pass; launches are counted in the paired observed record)"
  echo "bend_dev_launches: not observed (plain pass)"
  echo "compute_app_seen: $yn pid=$pid seen=$seen polls=$polls interval_ms=200 log=$RUN/plain.apps log_sha256=$(sha "$RUN/plain.apps")"
  echo "pmon_max_sm: $pmon_max pid=$pid rows=$pmon_rows numeric=$pmon_num interval_ms=1000 log=$RUN/plain.pmon log_sha256=$(sha "$RUN/plain.pmon")"
  echo "util_samples: $usamples interval_ms=200 scope=global(display shares the GPU) baseline=$baseline log=$RUN/plain.util log_sha256=$(sha "$RUN/plain.util")"
  echo "wall_ms: $((t1 - t0))"
  echo "load_avg: $load_plain"
  echo "correctness: $(correctness "$RUN/plain.stdout")"
} >> "$RUN/plain.rec"

# ---- 2. Observed pass ------------------------------------------------------

SANLOG="$RUN/observed.sanitizer.log"
# What the sanitizer's target actually sees of CUDA_VISIBLE_DEVICES. The
# 2026.3 sanitizer removes an empty CUDA_VISIBLE_DEVICES from its target's
# environment (verification/gpu-gate-controls.txt), so the observed pass
# would run with the device visible; check-record.sh fails a pair whose
# observed target saw a different value from the plain pass.
case "$cvd" in
  unset) cvd_tok=unset ;;
  "set, empty") cvd_tok=set-empty ;;
  *) cvd_tok="set:$CUDA_VISIBLE_DEVICES" ;;
esac
seen_cvd=$(timeout 120 compute-sanitizer --print-limit 0 sh -c \
  'if [ "${CUDA_VISIBLE_DEVICES+set}" != set ]; then echo unset; elif [ -z "$CUDA_VISIBLE_DEVICES" ]; then echo set-empty; else echo "set:$CUDA_VISIBLE_DEVICES"; fi' \
  2>/dev/null | grep -v '^=========' | head -n 1)
load_obs=$(uptime | sed 's/^ *//')
t0=$(now_ms)
timeout 600 compute-sanitizer --print-session-details --log-file "$SANLOG" \
  --dump-kernel-launches --print-limit 0 --kernel-name-exclude regex=.* \
  "$BIN" $RTS "$@" > "$RUN/observed.stdout" 2> "$RUN/observed.stderr"
st_obs=$?
t1=$(now_ms)

if grep -q 'were not printed' "$SANLOG" 2>/dev/null; then
  echo "observe.sh: sanitizer output truncated ('were not printed'); the gate fails closed" >&2
fi
launches=""
[ -r "$SANLOG" ] && launches=$(sh "$CHECK" --count-launches "$SANLOG" "$NAME")
sanv=$(compute-sanitizer --version 2>/dev/null | sed -n 's/^Version //p' | head -n 1)

common "$RUN/observed.rec"
{
  echo "exit_status: $st_obs"
  echo "stdout_sha256: $(sha "$RUN/observed.stdout")"
  echo "stderr: $(oneline "$RUN/observed.stderr")"
  echo "observer: compute-sanitizer ${sanv:-version unknown} --print-session-details --dump-kernel-launches --print-limit 0 --kernel-name-exclude regex=.* caller_cuda_visible_devices=$cvd_tok target_cuda_visible_devices=$seen_cvd log=$SANLOG log_sha256=$(sha "$SANLOG")"
  echo "bend_dev_launches: $launches"
  echo "compute_app_seen: not sampled (observed pass; the paired plain record samples)"
  echo "pmon_max_sm: not sampled (observed pass)"
  echo "util_samples: not sampled (observed pass)"
  echo "wall_ms: $((t1 - t0)) (under the observer)"
  echo "load_avg: $load_obs"
  echo "correctness: $(correctness "$RUN/observed.stdout")"
} >> "$RUN/observed.rec"

# ---- Record, gate, check ---------------------------------------------------

{
  echo "--- record v1 ---"; cat "$RUN/plain.rec"; echo "--- end record ---"
  echo "--- record v1 ---"; cat "$RUN/observed.rec"; echo "--- end record ---"
} > "$RUN/record.pre"
verdict=$(sh "$CHECK" --derive "$RUN/record.pre")
awk -v g="gate: $verdict" '$0 == "--- end record ---" { print g } { print }' "$RUN/record.pre" > "$RUN/record.txt"
rm -f "$RUN/record.pre"

echo "run directory: $RUN"
cat "$RUN/record.txt"
sh "$CHECK" "$RUN/record.txt"
