#!/bin/sh
# Usage: build.sh <set> <probe>
# Builds $W/<set>/gen/<probe>.c (Bend 2.0.39 output, never edited; copied to
# $W/<set>-unikraft/app.c, so builds in different app directories can run at the
# same time even when their gen directories are shared) in the app
# directory $W/<set>-unikraft (made by mkapp.sh) as the qemu/x86_64 image
# $W/<set>/images/<probe>-qemu and its .dbg. The exit-code hook is linked unless
# WRIT_EXIT_HOOK=n is in the environment; the effect host layer host.c is linked
# when WRIT_HOST_LAYER=y (default n). WRIT_JOBS sets make's -j (default nproc).
# Prints the image sha256.
set -e
. "$(dirname "$0")/env.sh"
S=${1:?usage: build.sh <set> <probe>}; P=${2:?usage: build.sh <set> <probe>}
cp "$W/$S/gen/$P.c" "$W/$S-unikraft/app.c"
export WRIT_APP_C="$W/$S-unikraft/app.c"
export WRIT_HOSTS_UNIKRAFT="$REPO/hosts/unikraft"
export WRIT_EXIT_HOOK=${WRIT_EXIT_HOOK:-y}
export WRIT_HOST_LAYER=${WRIT_HOST_LAYER:-n}
cd "$W/$S-unikraft"
# Make tracks neither the environment nor the copied app.c's origin, so start clean.
rm -rf .unikraft/build
UK_CFLAGS=-std=gnu11 $KRAFT build --no-update --target qemu/x86_64 -j "${WRIT_JOBS:-$(nproc)}" . > "$W/$S/logs/build-$P.log" 2>&1 \
  || { tail -30 "$W/$S/logs/build-$P.log"; exit 1; }
cp .unikraft/build/writ-bend_qemu-x86_64 "$W/$S/images/$P-qemu"
cp .unikraft/build/writ-bend_qemu-x86_64.dbg "$W/$S/images/$P-qemu.dbg"
sha256sum "$W/$S/images/$P-qemu"
