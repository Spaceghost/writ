# Sourced by the other scripts in this directory. Sets:
#   REPO  the repository checkout holding this file
#   W     the build workspace (nothing in it is committed); taken from the
#         environment if set, otherwise $REPO/../writ-unikernel as the pins record
#   KRAFT the pinned kraft 0.12.16 command line (verification/unikernel-pins.txt)
HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../../.." && pwd)
W=${W:-$(realpath -e "$REPO/../writ-unikernel" 2>/dev/null)}
# A missing workspace must stop the caller, not leave W empty (paths would then
# resolve under /).
if [ -z "$W" ] || [ ! -d "$W" ]; then
  echo "env.sh: build workspace W='$W' is not a directory (set W or create $REPO/../writ-unikernel)" >&2
  exit 1
fi
KRAFT="$W/tools/kraftkit-0.12.16/kraft --config-dir $W/kraft-home/config \
  --manifests-dir $W/kraft-home/manifests --sources-dir $W/kraft-home/sources \
  --runtime-dir $W/kraft-home/runtime --no-check-updates --no-prompt --no-emojis \
  --no-color --log-type basic"

# writ_strip_serial < raw > text: the one serial clean-up every script uses. Removes
# NUL bytes, terminal escapes (ESC [ ... letter, ESC c) and CR, nothing else.
# console.sh checks that, in the program's part of a capture, these removals touch
# only the CR of each CR LF.
writ_strip_serial() {
  tr -d '\000' | sed -e 's/\x1b\[[0-9;?]*[A-Za-z]//g' -e 's/\x1bc//g' -e 's/\r//g'
}
