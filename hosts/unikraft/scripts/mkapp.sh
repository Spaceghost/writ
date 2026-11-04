#!/bin/sh
# Usage: mkapp.sh <set>
# Creates the Unikraft app directory $W/<set>-unikraft from hosts/unikraft/app/
# (Kraftfile, Makefile.uk, empty Config.uk) and the image set $W/<set>/{gen,images,logs}.
# Refuses to overwrite an existing app directory whose files differ from the template.
set -e
. "$(dirname "$0")/env.sh"
S=${1:?usage: mkapp.sh <set>}
A="$W/$S-unikraft"
mkdir -p "$A/compiler-include" "$W/$S/gen" "$W/$S/images" "$W/$S/logs"
for f in Kraftfile Makefile.uk Config.uk; do
  if [ -e "$A/$f" ] && ! cmp -s "$A/$f" "$REPO/hosts/unikraft/app/$f"; then
    echo "mkapp.sh: $A/$f differs from the template; not overwritten" >&2; exit 1
  fi
  cp "$REPO/hosts/unikraft/app/$f" "$A/$f"
done
# Adjustment 1: the compiler's own freestanding <stdatomic.h>.
ln -sf "$(${CC:-gcc} -print-file-name=include)/stdatomic.h" "$A/compiler-include/stdatomic.h"
echo "$A"
