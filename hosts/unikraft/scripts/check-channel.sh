#!/bin/sh
# Usage: check-channel.sh <set> <label> <probe> <client_reference> <console_reference> <expected_qemu_status> RECORD...
# One Writ channel run (hosts/unikraft/effects/Channel.md). Builds the host-side client
# probe hosts/unikraft/probes/client/client.c into $W/<set>/client (cc, default gcc),
# boots $W/<set>/images/<probe>-qemu through run.sh with the channel on a second serial
# port bound to the Unix socket $W/<set>/logs/chan-<label>.sock
# (WRIT_QEMU_SERIAL2=unix:<sock>,server=on,wait=off), waits up to 60 s for the socket,
# sends RECORD... with the client (one connection, one request outstanding), waits for
# QEMU to end, and checks:
#   1. the client's output (hex dumps and decoded replies, $W/<set>/logs/client-<label>.txt)
#      equals <client_reference> line for line, and the client exited 0;
#   2. console.sh's output of the boot equals <console_reference> line for line;
#   3. QEMU's exit status equals <expected_qemu_status> (33 = status 0 through the hook).
# The boot uses run.sh's defaults otherwise ("+RTS --threads 1 --gpu off", -m 1024, the
# exit device, -no-reboot) with timeout WRIT_CHANNEL_TIMEOUT (default 120 s).
# Prints one line per check and exits 1 if any expected outcome changed, 0 otherwise;
# exits 2 before booting on bad usage, a failed client build, a missing reference, or a
# socket path of 108 bytes or more (QEMU refuses it).
. "$(dirname "$0")/env.sh"
S=${1:?usage}; LB=${2:?usage}; P=${3:?usage}; CREF=${4:?usage}; KREF=${5:?usage}; XQ=${6:?usage}
shift 6
[ $# -ge 1 ] || { echo "check-channel.sh: no RECORD given" >&2; exit 2; }
[ -f "$CREF" ] && [ -f "$KREF" ] || { echo "check-channel.sh: missing reference" >&2; exit 2; }
T=${WRIT_CHANNEL_TIMEOUT:-120}
CL="$W/$S/client"
${CC:-gcc} -std=c11 -D_DEFAULT_SOURCE -Wall -Wextra -Werror -O2 \
  -o "$CL" "$REPO/hosts/unikraft/probes/client/client.c" || { echo "check-channel.sh: client build failed" >&2; exit 2; }
SOCK="$W/$S/logs/chan-$LB.sock"; OUT="$W/$S/logs/client-$LB.txt"
# A Unix socket path must be shorter than 108 bytes; QEMU refuses a longer one.
[ ${#SOCK} -lt 108 ] || { echo "check-channel.sh: socket path too long: $SOCK" >&2; exit 2; }
rm -f "$SOCK"
WRIT_QEMU_SERIAL2="unix:$SOCK,server=on,wait=off" \
  "$HERE/run.sh" "$S" "$LB" "$P" "+RTS --threads 1 --gpu off" "$T" 1024 > /dev/null &
QP=$!
i=0
while [ ! -S "$SOCK" ] && [ $i -lt 600 ]; do sleep 0.1; i=$((i + 1)); done
BAD=0
if [ -S "$SOCK" ]; then
  "$CL" "$SOCK" "$@" > "$OUT" 2>&1; CR=$?
else
  echo "no socket after 60 s" > "$OUT"; CR=1
fi
wait $QP; Q=$?
C=$(mktemp); trap 'rm -f "$C"' EXIT
if [ "$CR" = 0 ]; then echo "client: exit 0"; else echo "client: exit $CR"; BAD=1; fi
if diff "$OUT" "$CREF"; then echo "client diff: empty"; else echo "client diff: NOT EMPTY"; BAD=1; fi
if "$HERE/console.sh" "$W/$S/logs/run-$LB.raw" > "$C"; then :; else echo "console: FAIL"; BAD=1; fi
if diff "$C" "$KREF"; then echo "console diff: empty"; else echo "console diff: NOT EMPTY"; BAD=1; fi
if [ "$Q" = "$XQ" ]; then echo "QEMU exit: $Q"; else echo "QEMU exit: $Q, expected $XQ"; BAD=1; fi
echo "logs: \$W/$S/logs/run-$LB.log, \$W/$S/logs/client-$LB.txt; result: $([ $BAD = 0 ] && echo PASS || echo FAIL)"
exit $BAD
