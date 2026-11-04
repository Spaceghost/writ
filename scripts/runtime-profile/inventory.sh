#!/bin/sh
# Runtime host inventory for the Bend runtime host profile (RH-001).
#
# Usage, from the repository root:
#   sh scripts/runtime-profile/inventory.sh
#
# Emits C for scripts/runtime-profile/Hello.bend with the Bend compiler on PATH,
# then records three lists in verification/runtime-inventory-bend-<version>.txt:
#
#   1. Host calls. Every `name(` in the emitted C whose name matches the
#      HOST_CALLS pattern below, sorted and unique, each tagged with its area.
#      The match is textual over the whole file: it includes code under
#      BEND_CUDA, __OBJC__ (Metal), and __linux__ guards, so it is an upper
#      bound on what the source can ask of a host, not the set a particular
#      binary links. Link-level checks read the binary (`nm -u`), not this list.
#      A name must not be preceded by an identifier character, `.`, or `>`, so
#      `fread(`, `io_read(`, and member calls are not counted as `read(`.
#
#   2. Effect rows. Bend 2.0.39 registers each effect a program uses with a
#      constructor of the form
#        static void __attribute__((constructor)) io_print_use(void) {
#          io_eff(CID_IO_print, io_print_run);
#        }
#      The script matches `io_eff(CID_<Name>,` and lists <Name> with its Bend
#      spelling (the first `_` becomes `.`: IO_print -> IO.print). The
#      definition `static void io_eff(u32 cid, ...)` does not match.
#
#   3. Loop-handled requests. Constructors the IO loop tests directly
#      (`c == CID_<Name>`) before consulting the effect table, such as the
#      exit path. They have no effect row and cannot be removed per program.
#
# The emitted C goes to ../writ-build/runtime-profile/ (outside the tree). The
# inventory is valid only for the Bend version it names; another version needs
# a new inventory before any host qualification is reused.

set -eu

# Byte order for sort, so the list does not depend on the caller's locale.
LC_ALL=C
export LC_ALL

SRC=scripts/runtime-profile/Hello.bend
OUT_DIR=../writ-build/runtime-profile
C_FILE=$OUT_DIR/hello.c

if [ ! -f "$SRC" ]; then
  echo "inventory.sh: run from the repository root ($SRC not found)" >&2
  exit 2
fi

if ! command -v bend >/dev/null 2>&1; then
  echo "inventory.sh: bend not found on PATH; add the pinned toolchain, e.g." >&2
  # shellcheck disable=SC2016 # print the literal PATH hint
  echo '  export PATH="$HOME/.local/share/writ-toolchains/bend-2.0.39/bend/bin:$PATH"' >&2
  exit 2
fi

BEND_NO_TELEMETRY=1
export BEND_NO_TELEMETRY

VERSION_LINE=$(bend version)
VERSION=${VERSION_LINE#bend }
EVIDENCE=verification/runtime-inventory-bend-$VERSION.txt

# Host call names from the task brief. MTL[A-Z][A-Za-z]+ extends the list so
# the Metal entry points that docs/BEND-RUNTIME.md names are extracted too;
# _exit and raise extend it so the fault handler's fail-stop calls named in
# that document are extracted as well.
HOST_CALLS='pthread_[a-z_]+|mmap|munmap|mprotect|sigaltstack|sigaction|signal'
HOST_CALLS=$HOST_CALLS'|clock_gettime|nanosleep|sched_yield|sched_getaffinity'
HOST_CALLS=$HOST_CALLS'|pipe|fcntl|select|read|write|open|fopen|fscanf|fclose'
HOST_CALLS=$HOST_CALLS'|getenv|exit|_exit|raise|sysconf|malloc|calloc|realloc|free|strdup'
HOST_CALLS=$HOST_CALLS'|snprintf|atomic_[a-z_]+|__atomic_[a-z_]+'
HOST_CALLS=$HOST_CALLS'|cu[A-Z][A-Za-z]+|nvrtc[A-Z][A-Za-z]+|MTL[A-Z][A-Za-z]+'

# Area of a host call name, matching the groups in docs/BEND-RUNTIME.md.
area() {
  case $1 in
    mmap|munmap|mprotect) echo memory ;;
    sigaltstack|sigaction|signal|raise) echo faults ;;
    pthread_*|sched_yield) echo threads ;;
    clock_gettime|nanosleep) echo clock ;;
    pipe|fcntl|select|read|write) echo event-loop ;;
    getenv|exit|_exit|sysconf|sched_getaffinity) echo process ;;
    # cpu_read() reads cgroup cpu.max with these on Linux; gpu_make() also
    # writes the device program with fopen.
    fopen|fscanf|fclose) echo process-and-device ;;
    malloc|calloc|realloc|free|strdup|snprintf) echo allocation-and-strings ;;
    atomic_*|__atomic_*) echo atomics ;;
    open|cu*|nvrtc*|MTL*) echo device ;;
    *) echo unclassified ;;
  esac
}

mkdir -p "$OUT_DIR"
EMIT="bend $SRC -o $C_FILE"
bend "$SRC" -o "$C_FILE"

CALLS=$(grep -oE "(^|[^A-Za-z0-9_.>])($HOST_CALLS)\(" "$C_FILE" \
  | sed -E 's/^[^A-Za-z_]//; s/\($//' | sort -u)
EFFECTS=$(grep -oE 'io_eff\(CID_[A-Za-z0-9_]+,' "$C_FILE" \
  | sed -E 's/^io_eff\(CID_//; s/,$//' | sort -u)
LOOP=$(grep -oE 'c == CID_[A-Za-z0-9_]+' "$C_FILE" \
  | sed -E 's/^c == CID_//' | sort -u)

# Hello prints, so its C must register IO_print and name host calls. A renamed
# io_eff or a changed emission would otherwise leave a section silently empty.
if ! printf '%s\n' "$EFFECTS" | grep -qx 'IO_print'; then
  echo "inventory.sh: no io_eff(CID_IO_print, ...) in $C_FILE; the emitted C changed" >&2
  exit 2
fi
if [ -z "$CALLS" ]; then
  echo "inventory.sh: no host calls matched in $C_FILE; the emitted C changed" >&2
  exit 2
fi

{
  echo "Bend runtime host inventory"
  echo "Bend version: $VERSION_LINE (from \`bend version\`)"
  echo "Date: $(date +%Y-%m-%d) ($(date +%Z))"
  echo "Command: sh scripts/runtime-profile/inventory.sh"
  echo "Emit command: BEND_NO_TELEMETRY=1 $EMIT"
  echo "Reference program: $SRC"
  echo "Emitted C: $(wc -l < "$C_FILE" | tr -d ' ') lines, sha256 $(sha256sum "$C_FILE" | cut -d' ' -f1)"
  echo "Lanes: not applicable (C emission and text extraction only; nothing was run)"
  echo "GPU mode: not applicable; no --gpu run. Device calls below are source text"
  echo "  under BEND_CUDA and __OBJC__ guards, not evidence of GPU execution."
  echo
  echo "## Host calls (name, area), sorted and unique"
  echo "# Pattern: (^|[^A-Za-z0-9_.>])($HOST_CALLS)\\("
  for name in $CALLS; do
    printf '%s\t%s\n' "$name" "$(area "$name")"
  done
  echo
  echo "## Effect rows registered by io_eff(CID_<Name>, ...)"
  echo "# <Name> as emitted, then the Bend spelling"
  for name in $EFFECTS; do
    printf '%s\t%s\n' "$name" "$(echo "$name" | sed 's/_/./')"
  done
  echo
  echo "## Requests the IO loop handles before the effect table (c == CID_<Name>)"
  for name in $LOOP; do
    echo "$name"
  done
} > "$EVIDENCE"

echo "wrote $EVIDENCE"
