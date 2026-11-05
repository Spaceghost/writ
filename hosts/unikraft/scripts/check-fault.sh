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
#   2a. for the overflow probe, the log holds the runtime's own line "bend: memory fault
#      (machine stack overflow?)" before that crash line (UL-006, posix signals in the
#      Kraftfile); the reference must list it among the program lines as well;
#   3. QEMU's exit status equals expected_qemu_status (run.sh's exit status when booting,
#      and the status run.sh recorded in the log).
# Kernel fragment after the exit write (writ_kernel_fragment, env.sh): before check 1,
# and before the "[ <s>] " filter (so a counted line is never hidden by that filter), the
# last program line is dropped only when the raw capture run-<label>.raw ends with an
# unterminated last line that is the start of a timestamped kernel line (a cut-off
# timestamp, or the pm.c:69 shutdown line) and the log's last program line is that same
# text; nothing else is. Under KVM the guest runs briefly past exit_device.c's port
# write, contradicting that file's "QEMU does not return here"
# (verification/unikernel-kvm.txt). Counted every time: each run prints "kernel shutdown
# fragment after exit: dropped <0|1>".
# Prints one line per check and exits 1 if any expected outcome changed, 0 otherwise.
# Host tooling: makes no Writ decision.
. "$(dirname "$0")/env.sh"
S=${1:?usage}; LB=${2:?usage}; P=${3:?usage}; REF=${4:?usage}; XQ=${5:?usage}
T=${6:-60}; M=${7:-1024}
L="$W/$S/logs/run-$LB.log"
C=$(mktemp); trap 'rm -f "$C"' EXIT
BAD=0
if [ "${WRIT_NO_BOOT:-0}" != 1 ]; then
  # Remove the previous capture first, so a run.sh that stops before booting (exit 2:
  # no image or no logs directory) cannot leave a stale log to be checked.
  rm -f "$L" "$W/$S/logs/run-$LB.raw"
  "$HERE/run.sh" "$S" "$LB" "$P" "+RTS --threads 1 --gpu off" "$T" "$M" > /dev/null
  RC=$?
  if [ "$RC" != "$XQ" ]; then echo "run.sh exit: $RC, expected $XQ"; BAD=1; fi
fi
[ -f "$L" ] || { echo "log: missing ($L)"; echo "result: FAIL"; exit 1; }
Q=$(tail -n 2 "$L" | head -n 1)
sed -n '/^ *Ijiraq 0\.21\.0~7351f8b$/,$p' "$L" | sed '1d' | head -n -2 > "$C"
FR=0
if FT=$(writ_kernel_fragment "$W/$S/logs/run-$LB.raw") && [ "$(tail -n 1 "$C")" = "$FT" ]; then
  head -n -1 "$C" > "$C.f" && mv "$C.f" "$C"; FR=1
fi
echo "kernel shutdown fragment after exit: dropped $FR"
grep -v '^\[ *[0-9][0-9.]*\] ' "$C" > "$C.f"; mv "$C.f" "$C"
if diff "$C" "$REF"; then echo "program lines: equal"; else echo "program lines: DIFFER"; BAD=1; fi
if [ "$XQ" = 253 ]; then
  if grep -q 'CRIT: Unikraft Crash' "$L"; then echo "crash screen: present"; else echo "crash screen: MISSING"; BAD=1; fi
fi
if [ "$P" = overflow ]; then
  F=$(grep -n -m 1 -Fx 'bend: memory fault (machine stack overflow?)' "$L" | cut -d: -f1)
  K=$(grep -n -m 1 'CRIT: Unikraft Crash' "$L" | cut -d: -f1)
  if [ -n "$F" ] && [ -n "$K" ] && [ "$F" -lt "$K" ]; then echo "fault message: before the crash screen"
  else echo "fault message: MISSING before the crash screen"; BAD=1; fi
fi
if [ "$Q" = "$XQ" ]; then echo "QEMU exit: $Q"; else echo "QEMU exit: $Q, expected $XQ"; BAD=1; fi
echo "log: \$W/$S/logs/run-$LB.log; result: $([ $BAD = 0 ] && echo PASS || echo FAIL)"
exit $BAD
