#!/bin/sh
# Monitor profile binary check (RH-002, RH-003).
#
# Usage:
#   sh scripts/runtime-profile/check-binary.sh BINARY
#
# Reads the produced binary, not its source or a run log, and compares it with
# the two allowlists next to this script:
#
#   1. Undefined symbols. `nm -u BINARY`, version suffixes after `@` removed,
#      each name compared exactly with monitor-symbols.txt.
#
#   2. Effect rows. Bend 2.0.39 emits, for each effect a program uses,
#        Term io_print_run(Env e, Term* f, IoWork* w) { ... }
#        static void __attribute__((constructor)) io_print_use(void) {
#          io_eff(CID_IO_print, io_print_run);
#        }
#      At the -O2 that `bend -o BINARY` uses, clang evaluates the constructor
#      at compile time and drops it, so `io_<name>_use` is absent from the
#      binary (it is present at -O0). The `<prefix>_run` function is external
#      and stays as a global text symbol (nm type T). The check therefore takes
#      every global `T <prefix>_run` and every `<prefix>_use`, and maps
#      <prefix> to the Bend effect name by this rule:
#        split <prefix> at its first `_` into <ns> and <rest>;
#        <ns> io, tcp, udp becomes IO, TCP, UDP; any other <ns> gets an upper
#        case first letter (file -> File, process -> Process);
#        the effect is <NS>.<rest>.
#      Examples: io_print -> IO.print, io_print_err -> IO.print_err,
#      tcp_listen -> TCP.listen, process_run -> Process.run. The rule matches
#      all 57 io_eff registrations in the Bend 2.0.39 Base effect sources.
#      Runtime helpers that end in _run (cube_run, gpu_run) are static, so
#      they are not global T symbols. A name the rule maps to an effect that is
#      not allowlisted, including any foreign C import, fails the check.
#      IO.exit and IO.die are handled by the IO loop and have no row.
#      Both the `_run` detection and this mapping rule depend on the C that
#      Bend 2.0.39 emits and the way `bend -o` compiles it; re-validate them
#      against the emitted C and the Base effect sources on any toolchain change.
#      In a static binary, libc's own symbols share the table; they begin with
#      `_` or are not `_run`/`_use` names in glibc 2.44, and any lower-case
#      `<x>_run` that did collide would be denied, not admitted.
#
# Static links: a binary with no (NEEDED) dynamic entries resolves libc inside
# itself, so it has no imports to compare. The symbol comparison is skipped and
# reported as not applicable; the effect-row check still runs on its symbol
# table and still fails on a denied effect. A static PASS therefore confirms
# the effect rows only, not the host-symbol surface.
#
# Fails closed: a missing symbol table or a binary without the runtime effect
# table symbol `io_runs` (stripped, or not a Bend 2.0.39 binary) is refused
# rather than passed.
#
# Exit status: 0 when no symbol and no effect is outside the profile; 1 when
# any is, after printing each offending name; 2 when the binary cannot be
# checked. Only status 0 counts as satisfying the profile.

set -eu

LC_ALL=C
export LC_ALL

die() {
  echo "check-binary.sh: $*" >&2
  exit 2
}

[ $# -eq 1 ] || die "usage: check-binary.sh BINARY"
BIN=$1
[ -f "$BIN" ] || die "$BIN: no such file"
command -v nm >/dev/null 2>&1 || die "nm not found on PATH"
command -v readelf >/dev/null 2>&1 || die "readelf not found on PATH"

HERE=$(cd "$(dirname "$0")" && pwd)
SYMBOLS=$HERE/monitor-symbols.txt
EFFECTS=$HERE/monitor-effects.txt
[ -f "$SYMBOLS" ] || die "$SYMBOLS missing"
[ -f "$EFFECTS" ] || die "$EFFECTS missing"

# A static binary resolves its libc inside itself, so an empty `nm -u` would
# say nothing about the host surface; only its effect rows are checked.
LINK=dynamic
readelf -d "$BIN" 2>/dev/null | grep -q '(NEEDED)' || LINK=static

ALL=$(nm "$BIN" 2>/dev/null) || die "$BIN: nm could not read a symbol table"
echo "$ALL" | grep -qE ' [bBdD] io_runs$' \
  || die "$BIN: no io_runs effect table symbol (stripped, or not a Bend 2.0.39 binary)"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Allowlist bodies: comment and blank lines removed, surrounding space trimmed.
allow() {
  sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' "$1" \
    | grep -v '^$' | sort -u
}
allow "$SYMBOLS" > "$TMP/allowed-symbols"
allow "$EFFECTS" > "$TMP/allowed-effects"

if [ "$LINK" = dynamic ]; then
  nm -u "$BIN" | awk '{ print $NF }' | sed 's/@.*//' | sort -u > "$TMP/symbols"
else
  : > "$TMP/symbols"
fi

echo "$ALL" | awk '
  $2 == "T" && $3 ~ /^[a-z][a-z0-9_]*_run$/ { sub(/_run$/, "", $3); print $3 }
  $3 ~ /^[a-z][a-z0-9_]*_use$/              { sub(/_use$/, "", $3); print $3 }
' | sort -u | awk '
  {
    i = index($0, "_")
    if (i == 0) { print "unmapped:" $0; next }
    ns = substr($0, 1, i - 1); rest = substr($0, i + 1)
    if (ns == "io" || ns == "tcp" || ns == "udp") ns = toupper(ns)
    else ns = toupper(substr(ns, 1, 1)) substr(ns, 2)
    print ns "." rest
  }
' | sort -u > "$TMP/effects"

comm -23 "$TMP/symbols" "$TMP/allowed-symbols" > "$TMP/bad-symbols"
comm -23 "$TMP/effects" "$TMP/allowed-effects" > "$TMP/bad-effects"

echo "binary: $BIN"
if [ "$LINK" = dynamic ]; then
  echo "undefined symbols: $(wc -l < "$TMP/symbols" | tr -d ' ')"
else
  echo "undefined symbols: not applicable (static link)"
fi
echo "effect rows: $(tr '\n' ' ' < "$TMP/effects" | sed 's/ $//')"

STATUS=0
if [ -s "$TMP/bad-effects" ]; then
  STATUS=1
  echo "effects outside the monitor profile:"
  sed 's/^/  /' "$TMP/bad-effects"
fi
if [ -s "$TMP/bad-symbols" ]; then
  STATUS=1
  echo "undefined symbols outside the monitor profile:"
  sed 's/^/  /' "$TMP/bad-symbols"
fi

if [ "$STATUS" -eq 0 ] && [ "$LINK" = static ]; then
  echo "result: PASS (effect rows within the monitor profile; static link, so"
  echo "  the host-symbol surface was not checked)"
elif [ "$STATUS" -eq 0 ]; then
  echo "result: PASS (within the monitor profile)"
else
  echo "result: FAIL (outside the monitor profile)"
fi
exit "$STATUS"
