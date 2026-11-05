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

# Kernel fragment after the exit write. Under KVM the guest runs briefly past
# exit_device.c's port write before QEMU exits, so a capture whose QEMU status is already
# the hook's can end with the start of a further timestamped Unikraft kernel line, cut off
# where the guest stopped (verification/unikernel-kvm.txt, "Finding: the guest runs on
# after the exit-device write (KVM)"); exit_device.c's comment "QEMU does not return here"
# is contradicted there. Observed: on a normal shutdown, lib/ukpm/pm.c:67-69's line
#   [    0.173610] ERR:  [libukpm] <pm.c @   69> PM driver failed the operation: -5. Falling back on busy loop...
# whole or cut off (sometimes with a NUL); on the crash path (kvmfix-overflow1) the start
# of a further crash-screen line, "[    2.27112". The proper fix is a halt after the write
# in exit_device.c, deferred to the next rebuild of every set.
#
# writ_is_kernel_fragment_text <line>: true only when <line> (NUL bytes already removed)
# is the start of a timestamped kernel line: a nonempty prefix of Unikraft's timestamp
# "[%5lu.%06lu] " (a 5-wide field of spaces then digits, with at least one space, i.e.
# an uptime below 10000 s; ".", exactly 6 digits, "] "), or that complete timestamp
# followed by a prefix of the pm.c:69 text above. Accepted limit: "[" alone, or "[" and
# spaces, cannot be told from program text; condition (a) below is what keeps a program
# line out.
# writ_kernel_fragment <raw capture>: prints the stripped last line and returns true only
# when (a) the capture does not end with a newline (the guest stopped mid-line; a
# program's lines are printed with a terminator) and (b) that last line, after
# writ_strip_serial, passes writ_is_kernel_fragment_text. Nothing else. A capture ending
# in a NUL-only or CR-only unterminated line gives an empty line: nothing is dropped, and
# the check then fails (the safe direction). Callers drop at most that one line and print
# "kernel shutdown fragment after exit: dropped <0|1>" on every run.
# Self-test (run in the Task 1 report, fix round 2), text only, expected result:
#   drop: "[", "[   ", "[    2", "[    2.27112", "[    2.271123] ",
#         "[    0.117238] ERR:  [li", the whole pm.c:69 line above
#   keep: "[1.5]", "[12", "[1", "[5.25]", "[ 1.0]", "[3.0] E", "[1, 2]", "hi",
#         "[    0.1] ERR:", "[    0.173610] CRIT: x", the whole pm.c line plus "x"
#   and as a capture: "[" or "[1.5]" with a final newline is kept.
WRIT_PM_SHUTDOWN_TEXT='ERR:  [libukpm] <pm.c @   69> PM driver failed the operation: -5. Falling back on busy loop...'
writ_is_kernel_fragment_text() {
  [ -n "$1" ] || return 1
  printf '%s\n' "$1" | awk -v pm="$WRIT_PM_SHUTDOWN_TEXT" '
    NR > 1 { exit 1 }
    {
      s = $0
      if (s == "[") exit 0
      if (substr(s, 1, 1) != "[") exit 1
      r = substr(s, 2)
      # the 5-wide seconds field: spaces, then digits
      if (!match(r, /^ +[0-9]*/)) exit 1
      f = substr(r, 1, RLENGTH); r = substr(r, RLENGTH + 1)
      if (length(f) > 5) exit 1
      if (r == "") { if (length(f) == 5 && f !~ /[0-9]$/) exit 1; exit 0 }
      if (length(f) != 5 || f !~ /[0-9]$/) exit 1
      if (substr(r, 1, 1) != ".") exit 1
      r = substr(r, 2)
      match(r, /^[0-9]*/); fr = substr(r, 1, RLENGTH); r = substr(r, RLENGTH + 1)
      if (length(fr) > 6) exit 1
      if (r == "") exit 0
      if (length(fr) != 6) exit 1
      if (substr(r, 1, 1) != "]") exit 1
      r = substr(r, 2)
      if (r == "" || r == " ") exit 0
      if (substr(r, 1, 1) != " ") exit 1
      r = substr(r, 2)
      if (index(pm, r) == 1) exit 0
      exit 1
    }'
}
writ_kernel_fragment() {
  [ -s "$1" ] || return 1
  [ "$(tail -c 1 "$1" | od -An -c | tr -d ' ')" != '\n' ] || return 1
  _writ_last=$(tail -n 1 "$1" | writ_strip_serial)
  writ_is_kernel_fragment_text "$_writ_last" || return 1
  printf '%s\n' "$_writ_last"
}
