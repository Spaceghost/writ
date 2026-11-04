#!/bin/sh
# Usage: check-image.sh <set> <label> <probe> <reference> <expected_qemu_status> [expected_pass] [timeout_s] [mem_MiB]
# Boots $W/<set>/images/<probe>-qemu once through run.sh ("+RTS --threads 1 --gpu off",
# the exit device, -no-reboot) and checks the outcome against what is expected:
#   1. console.sh's output equals <reference> line for line (a plain capture, or a file
#      whose capture follows a line '== capture ==', as the corpus reference does);
#   2. if expected_pass is given (not empty), exactly that many lines match ^PASS[: ];
#   3. if WRIT_EXPECT_LAST_LINE is set, the console's last line equals it;
#   4. QEMU's exit status equals expected_qemu_status (1 = status 0 through the hook).
# WRIT_CONSOLE_SED, if set, is a sed script applied to console.sh's output before
# check 1, for consoles that carry run-dependent values (clock readings); the
# reference then holds the masked text, and the program's own exit status still
# checks the values (the effects probe exits 1 outside its window). Printed when used.
# WRIT_NO_BOOT=1 checks the existing capture run-<label>.{raw,log} instead of booting
# (the QEMU status is then read from the log, where run.sh recorded it).
# QEMU 1 counts as success only with checks 1 to 3 passing: QEMU also exits 1 on its
# own startup errors, which leave no banner, so console.sh fails on them.
# Prints one line per check and exits 1 if any expected outcome changed, 0 otherwise.
. "$(dirname "$0")/env.sh"
S=${1:?usage}; LB=${2:?usage}; P=${3:?usage}; REF=${4:?usage}; XQ=${5:?usage}
XP=$6; T=${7:-600}; M=${8:-4096}
C=$(mktemp); E=$(mktemp); trap 'rm -f "$C" "$E"' EXIT
if [ "${WRIT_NO_BOOT:-0}" = 1 ]; then
  Q=$(tail -n 2 "$W/$S/logs/run-$LB.log" | head -n 1)
else
  "$HERE/run.sh" "$S" "$LB" "$P" "+RTS --threads 1 --gpu off" "$T" "$M" > /dev/null
  Q=$?
fi
BAD=0
if "$HERE/console.sh" "$W/$S/logs/run-$LB.raw" > "$C"; then :; else echo "console: FAIL"; BAD=1; fi
if [ -n "$WRIT_CONSOLE_SED" ]; then
  echo "console masked with: sed -e '$WRIT_CONSOLE_SED'"
  sed -e "$WRIT_CONSOLE_SED" "$C" > "$C.m" && mv "$C.m" "$C" || { echo "console mask: FAIL"; BAD=1; }
fi
if grep -qx '== capture ==' "$REF"; then sed '1,/^== capture ==$/d' "$REF" > "$E"; else cat "$REF" > "$E"; fi
if diff "$C" "$E"; then echo "diff: empty"; else echo "diff: NOT EMPTY"; BAD=1; fi
if [ -n "$XP" ]; then
  N=$(grep -cE '^PASS[: ]' "$C")
  if [ "$N" = "$XP" ]; then echo "PASS lines: $N"; else echo "PASS lines: $N, expected $XP"; BAD=1; fi
fi
if [ -n "$WRIT_EXPECT_LAST_LINE" ]; then
  L=$(tail -n 1 "$C")
  if [ "$L" = "$WRIT_EXPECT_LAST_LINE" ]; then echo "last line: $L"; else echo "last line: '$L', expected '$WRIT_EXPECT_LAST_LINE'"; BAD=1; fi
fi
if [ "$Q" = "$XQ" ]; then echo "QEMU exit: $Q"; else echo "QEMU exit: $Q, expected $XQ"; BAD=1; fi
echo "log: \$W/$S/logs/run-$LB.log; result: $([ $BAD = 0 ] && echo PASS || echo FAIL)"
exit $BAD
