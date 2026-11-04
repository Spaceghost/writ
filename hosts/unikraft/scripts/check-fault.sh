#!/bin/sh
# Usage: check-fault.sh <set> <label> <probe> <reference> <expected_qemu_status> [timeout_s] [mem_MiB]
# For images whose run ends in a Unikraft crash (the Overflow and Exhaust probes), where
# console.sh cannot be used: the crash screen carries NUL bytes, which console.sh refuses.
# Boots $W/<set>/images/<probe>-qemu once through run.sh (or, with WRIT_NO_BOOT=1, reads
# the existing run-<label>.log) and checks:
#   1. the program's lines equal <reference> line for line: every line of run.sh's
#      cleaned log after Unikraft's banner line (" Ijiraq 0.21.0~7351f8b"), without
#      Unikraft's own log lines ("[  <seconds>] ..."), the QEMU status line, and the wall
#      time line;
#   2. if expected_qemu_status is 253 (the exit hook's crash value), the log holds
#      Unikraft's "CRIT: Unikraft Crash" line;
#   3. QEMU's exit status equals expected_qemu_status.
# Prints one line per check and exits 1 if any expected outcome changed, 0 otherwise.
# Host tooling: makes no Writ decision.
. "$(dirname "$0")/env.sh"
S=${1:?usage}; LB=${2:?usage}; P=${3:?usage}; REF=${4:?usage}; XQ=${5:?usage}
T=${6:-60}; M=${7:-1024}
L="$W/$S/logs/run-$LB.log"
C=$(mktemp); trap 'rm -f "$C"' EXIT
if [ "${WRIT_NO_BOOT:-0}" != 1 ]; then
  "$HERE/run.sh" "$S" "$LB" "$P" "+RTS --threads 1 --gpu off" "$T" "$M" > /dev/null
fi
Q=$(tail -n 2 "$L" | head -n 1)
BAD=0
sed -n '/^ *Ijiraq 0\.21\.0~7351f8b$/,$p' "$L" | sed '1d' | head -n -2 \
  | grep -v '^\[ *[0-9][0-9.]*\] ' > "$C"
if diff "$C" "$REF"; then echo "program lines: equal"; else echo "program lines: DIFFER"; BAD=1; fi
if [ "$XQ" = 253 ]; then
  if grep -q 'CRIT: Unikraft Crash' "$L"; then echo "crash screen: present"; else echo "crash screen: MISSING"; BAD=1; fi
fi
if [ "$Q" = "$XQ" ]; then echo "QEMU exit: $Q"; else echo "QEMU exit: $Q, expected $XQ"; BAD=1; fi
echo "log: \$W/$S/logs/run-$LB.log; result: $([ $BAD = 0 ] && echo PASS || echo FAIL)"
exit $BAD
