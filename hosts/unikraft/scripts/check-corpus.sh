#!/bin/sh
# Usage: check-corpus.sh <set> <label> [timeout_s] [mem_MiB]
# check-image.sh for the Tests.bend image $W/<set>/images/tests-qemu against
# verification/unikernel-corpus-linux-reference.txt, expecting QEMU exit 33 (program
# status 0 through exit_device.c), the last
# line 'ALL LIBRARY TESTS PASSED', and WRIT_CORPUS_PASS PASS lines (default 782, the
# corpus of the tree last checked; set it when Tests.bend's check count changes).
# Exits nonzero if any expected outcome changed. WRIT_NO_BOOT=1 checks the existing
# capture run-<label> instead of booting (see check-image.sh).
. "$(dirname "$0")/env.sh"
S=${1:?usage: check-corpus.sh <set> <label> [timeout] [mem]}; LB=${2:?usage}
WRIT_EXPECT_LAST_LINE="ALL LIBRARY TESTS PASSED" exec "$HERE/check-image.sh" "$S" "$LB" tests \
  "$REPO/verification/unikernel-corpus-linux-reference.txt" 33 "${WRIT_CORPUS_PASS:-782}" "${3:-600}" "${4:-4096}"
