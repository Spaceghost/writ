#!/usr/bin/env bash
# Source observations only: no compilation, execution of generated code, or host probe.
set -eu
export LC_ALL=C
if [ "$#" -ne 3 ]; then
  printf 'usage: %s FROZEN_OUTPUTS BEND_INSTALL FROZEN_MANIFEST\n' "$0" >&2
  exit 2
fi
frozen=$1
install=$2
manifest=$3
printf 'Frozen generated C hash check:\n'
(cd "$frozen" && sha256sum -c "$manifest")
for tree in historical current; do
  for path in "$frozen/$tree/"*.c; do
    printf '\n%s/%s\n' "$tree" "${path##*/}"
    # Keep function definitions as well as any uses; this is a textual scan.
    rg -n '\bio_work\b|\bio_wait_on\b|\bio_eff\s*\(' "$path"
  done
done
printf '\nPinned Bend effect implementations referring to io_work:\n'
rg -n '\bio_work\s*\(' "$install"/bend2/effs/*.c | sort
