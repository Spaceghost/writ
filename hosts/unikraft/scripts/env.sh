# Sourced by the other scripts in this directory. Sets:
#   REPO  the repository checkout holding this file
#   W     the build workspace (nothing in it is committed); taken from the
#         environment if set, otherwise $REPO/../writ-unikernel as the pins record
#   KRAFT the pinned kraft 0.12.16 command line (verification/unikernel-pins.txt)
HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../../.." && pwd)
W=${W:-$(realpath "$REPO/../writ-unikernel")}
KRAFT="$W/tools/kraftkit-0.12.16/kraft --config-dir $W/kraft-home/config \
  --manifests-dir $W/kraft-home/manifests --sources-dir $W/kraft-home/sources \
  --runtime-dir $W/kraft-home/runtime --no-check-updates --no-prompt --no-emojis \
  --no-color --log-type basic"
