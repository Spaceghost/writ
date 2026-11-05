#!/bin/sh
# Usage: check-corpus.sh <set> <label> [timeout_s] [mem_MiB] [lanes] [vcpus]
# check-image.sh for the Tests.bend image $W/<set>/images/tests-qemu against
# verification/unikernel-corpus-linux-reference.txt, expecting QEMU exit 33 (program
# status 0 through exit_device.c), the last
# line 'ALL LIBRARY TESTS PASSED', and WRIT_CORPUS_PASS PASS lines (default 782, the
# corpus of the tree last checked; set it when Tests.bend's check count changes).
# Exits nonzero if any expected outcome changed. WRIT_NO_BOOT=1 checks the existing
# capture run-<label> instead of booting (see check-image.sh).
# lanes and vcpus (both optional, for the multi-lane lanes set): when either is given,
# this script boots once itself through run.sh with "+RTS --threads <lanes> --gpu off"
# (default lanes 1) and <vcpus> passed as run.sh's vcpus argument (-smp; default 1),
# then checks that capture with check-image.sh under WRIT_NO_BOOT=1, so the checks are
# the same. Without them the call is exactly the single-lane check it always was.
. "$(dirname "$0")/env.sh"
S=${1:?usage: check-corpus.sh <set> <label> [timeout] [mem] [lanes] [vcpus]}; LB=${2:?usage}
T=${3:-600}; M=${4:-4096}
if [ -n "$5$6" ] && [ "${WRIT_NO_BOOT:-0}" != 1 ]; then
  # Remove the previous capture first, so a run.sh that stops before booting (exit 2)
  # cannot leave a stale log to be checked.
  rm -f "$W/$S/logs/run-$LB.log" "$W/$S/logs/run-$LB.raw"
  "$HERE/run.sh" "$S" "$LB" tests "+RTS --threads ${5:-1} --gpu off" "$T" "$M" "${6:-1}" > /dev/null
  [ -f "$W/$S/logs/run-$LB.log" ] || { echo "log: missing"; echo "result: FAIL"; exit 1; }
  export WRIT_NO_BOOT=1
fi
WRIT_EXPECT_LAST_LINE="ALL LIBRARY TESTS PASSED" exec "$HERE/check-image.sh" "$S" "$LB" tests \
  "$REPO/verification/unikernel-corpus-linux-reference.txt" 33 "${WRIT_CORPUS_PASS:-782}" "$T" "$M"
