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

# writ_is_pm_shutdown_fragment <line>: true when <line> (already passed through
# writ_strip_serial, so NUL bytes are gone) is a nonempty prefix of Unikraft's own
# shutdown line, the timestamp being any "[ <digits>.<digits>]":
#   [    0.173610] ERR:  [libukpm] <pm.c @   69> PM driver failed the operation: -5. Falling back on busy loop...
# (lib/ukpm/pm.c:67-69, from uk_pm_shutdown, which runs after exit_device.c's port
# write). Under KVM the guest runs briefly past that write before QEMU exits, so the
# line, whole or cut off and sometimes with a NUL, can end a capture whose QEMU status
# is already the hook's; exit_device.c's comment "QEMU does not return here" is
# contradicted there (verification/unikernel-kvm.txt, "Finding: the guest runs on
# after the exit-device write (KVM)"). The proper fix is a halt after the write in
# exit_device.c, left for the next rebuild of every set. Callers apply this only to
# the capture's last line and print how many lines they dropped (0 or 1); nothing
# else is ever dropped.
WRIT_PM_SHUTDOWN_TAIL=' ERR:  [libukpm] <pm.c @   69> PM driver failed the operation: -5. Falling back on busy loop...'
writ_is_pm_shutdown_fragment() {
  [ -n "$1" ] || return 1
  # Cut inside the timestamp: "[", "[    0", "[    0.13", ...
  if printf '%s\n' "$1" | grep -qxE '\[ *([0-9]+(\.[0-9]*)?)?'; then return 0; fi
  printf '%s\n' "$1" | grep -qE '^\[ *[0-9]+\.[0-9]+\]' || return 1
  _writ_rest=$(printf '%s\n' "$1" | sed -E 's/^\[ *[0-9]+\.[0-9]+\]//')
  case "$WRIT_PM_SHUTDOWN_TAIL" in
    "$_writ_rest"*) return 0 ;;
  esac
  return 1
}
