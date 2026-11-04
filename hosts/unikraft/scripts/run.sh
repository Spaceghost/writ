#!/bin/bash
# Usage: run.sh <set> <label> <probe> <append> [timeout_s] [mem_MiB]
# Emulated boot (QEMU TCG) of $W/<set>/images/<probe>-qemu; serial on stdout.
# Defaults: timeout 60 s, -m 1024, the isa-debug-exit device, and -no-reboot.
# WRIT_QEMU_REBOOT=1 omits -no-reboot; WRIT_QEMU_DEVICE=0 omits the device.
# Writes $W/<set>/logs/run-<label>.raw (the serial bytes as captured) and
# run-<label>.log: the command, the console from the "Booting from ROM" line on
# with escapes, CRs, NUL bytes and empty lines removed, the QEMU (or timeout)
# exit status, and the wall time.
. "$(dirname "$0")/env.sh"
S=$1; LB=$2; P=$3; AP=$4; T=${5:-60}; M=${6:-1024}
DEV="-device isa-debug-exit,iobase=0xf4,iosize=0x04"; [ "${WRIT_QEMU_DEVICE:-1}" = 0 ] && DEV=""
NR="-no-reboot"; [ "${WRIT_QEMU_REBOOT:-0}" = 1 ] && NR=""
L="$W/$S/logs/run-$LB.log"; R="$W/$S/logs/run-$LB.raw"
echo "\$ timeout $T qemu-system-x86_64 -accel tcg -nographic -m $M -cpu max -kernel \$W/$S/images/$P-qemu -append \"$AP\" $DEV $NR; echo \$?" > "$L"
B=$(date +%s.%N)
timeout "$T" qemu-system-x86_64 -accel tcg -nographic -m "$M" -cpu max \
  -kernel "$W/$S/images/$P-qemu" -append "$AP" $DEV $NR </dev/null > "$R" 2>&1
RC=$?
E=$(date +%s.%N)
tr -d '\000' < "$R" | sed -e 's/\x1b\[[0-9;?]*[A-Za-z]//g' -e 's/\x1bc//g' -e 's/\r//g' \
  | sed -n '/Booting from ROM/,$p' | sed 's/^Booting from ROM\.\.//' | grep -a -v "^$" >> "$L"
echo "$RC" >> "$L"
printf '(wall %.1f s)\n' "$(echo "$E - $B" | bc)" >> "$L"
cat "$L"
