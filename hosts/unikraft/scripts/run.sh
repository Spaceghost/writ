#!/bin/bash
# Usage: run.sh <set> <label> <probe> <append> [timeout_s] [mem_MiB]
# Emulated boot (QEMU TCG) of $W/<set>/images/<probe>-qemu; serial on stdout.
# Defaults: timeout 60 s, -m 1024, the isa-debug-exit device at 0xf4 (the exit
# hook's port), and -no-reboot. Environment switches, each recorded in the log:
#   WRIT_QEMU_REBOOT=1   omit -no-reboot
#   WRIT_QEMU_DEVICE=0   omit the debug-exit device
#   WRIT_QEMU_DEVICE=501 put the device at QEMU's default port 0x501 instead
#                        (where Unikraft's own qemu_exit/qemu_crash write)
#   WRIT_QEMU_FEED='cmd' feed cmd's stdout to QEMU's stdin (serial/monitor mux)
#                        instead of /dev/null, e.g. to type a monitor command
# Writes $W/<set>/logs/run-<label>.raw (the serial bytes as captured) and
# run-<label>.log: the command, the console from the "Booting from ROM" line on
# with escapes, CRs, NUL bytes and empty lines removed (a reading aid; diffs use
# console.sh on the .raw), the QEMU (or timeout) exit status, and the wall time.
# Exits with QEMU's (or timeout's) status. That status alone is not success: QEMU
# also exits 1 on its own startup errors, so success is QEMU 1 together with the
# banner-verified console check of check-image.sh. Exits 2, before starting QEMU,
# if the image or the set's logs directory is missing. Needs bc for the wall time.
. "$(dirname "$0")/env.sh"
S=${1:?usage: run.sh <set> <label> <probe> <append> [timeout] [mem]}
LB=${2:?usage: run.sh <set> <label> <probe> <append> [timeout] [mem]}
P=${3:?usage: run.sh <set> <label> <probe> <append> [timeout] [mem]}
AP=$4; T=${5:-60}; M=${6:-1024}
if [ ! -f "$W/$S/images/$P-qemu" ] || [ ! -d "$W/$S/logs" ]; then
  echo "run.sh: no image $W/$S/images/$P-qemu or no directory $W/$S/logs" >&2
  exit 2
fi
case "${WRIT_QEMU_DEVICE:-1}" in
  0) DEV="" ;;
  501) DEV="-device isa-debug-exit,iobase=0x501,iosize=0x02" ;;
  *) DEV="-device isa-debug-exit,iobase=0xf4,iosize=0x04" ;;
esac
NR="-no-reboot"; [ "${WRIT_QEMU_REBOOT:-0}" = 1 ] && NR=""
L="$W/$S/logs/run-$LB.log"; R="$W/$S/logs/run-$LB.raw"
IN="</dev/null"; [ -n "$WRIT_QEMU_FEED" ] && IN="(stdin: $WRIT_QEMU_FEED)"
echo "\$ timeout $T qemu-system-x86_64 -accel tcg -nographic -m $M -cpu max -kernel \$W/$S/images/$P-qemu -append \"$AP\" $DEV $NR $IN; echo \$?" > "$L"
B=$(date +%s.%N)
if [ -n "$WRIT_QEMU_FEED" ]; then
  bash -c "$WRIT_QEMU_FEED" | timeout "$T" qemu-system-x86_64 -accel tcg -nographic -m "$M" -cpu max \
    -kernel "$W/$S/images/$P-qemu" -append "$AP" $DEV $NR > "$R" 2>&1
  RC=${PIPESTATUS[1]}
else
  timeout "$T" qemu-system-x86_64 -accel tcg -nographic -m "$M" -cpu max \
    -kernel "$W/$S/images/$P-qemu" -append "$AP" $DEV $NR </dev/null > "$R" 2>&1
  RC=$?
fi
E=$(date +%s.%N)
writ_strip_serial < "$R" \
  | sed -n '/Booting from ROM/,$p' | sed 's/^Booting from ROM\.*//' | grep -a -v "^$" >> "$L"
echo "$RC" >> "$L"
printf '(wall %.1f s)\n' "$(echo "$E - $B" | bc)" >> "$L"
cat "$L"
exit "$RC"
