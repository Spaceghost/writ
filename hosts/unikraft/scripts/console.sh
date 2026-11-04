#!/bin/sh
# Usage: console.sh <run-label.raw>
# Prints the program's console output from a run.sh serial capture, for a line-for-line
# diff with a Linux capture. What is removed, and nothing else:
#   1. NUL bytes, CR (the serial line ends lines with CR LF), and terminal escape
#      sequences (ESC [ ... letter, ESC c) from SeaBIOS and the console driver;
#   2. everything before the first "Booting from ROM" (SeaBIOS, iPXE), that text, and
#      the run of dots SeaBIOS prints after it (two or more; one capture had three and a
#      line break before the banner); the rest of that line is kept if not empty;
#   3. Unikraft's banner, exactly the 7 lines below, required as the first 7 lines
#      (the script fails if they are not there, so no other line can be dropped as banner):
#        ^Powered by$
#        ^o\.   \.o       _ _               __ _$
#        ^Oo   Oo  ___ (_) | __ __  __ _ ' _) :_$
#        ^oO   oO ' _ `| | |/ /  _)' _` | |_|  _)$
#        ^oOo oOO| | | | |   (| | | (_) |  _) :_$
#        ^ OoOoO \._, \._:_:_,\\_\._,  \.__,_:_, \\___)$
#        ^ {18}Ijiraq 0\.21\.0~7351f8b$
# Empty lines and all later lines, including any Unikraft line after the banner, are kept.
set -e
R=${1:?usage: console.sh <run.raw>}
T=$(mktemp); trap 'rm -f "$T"' EXIT
tr -d '\000' < "$R" | sed -e 's/\x1b\[[0-9;?]*[A-Za-z]//g' -e 's/\x1bc//g' -e 's/\r//g' \
  | awk 'f{print;next} i=index($0,"Booting from ROM"){f=1; r=substr($0,i+16); sub(/^\.\.+/,"",r); if (r!="") print r}' > "$T"
cat > "$T.banner" <<'B'
Powered by
o.   .o       _ _               __ _
Oo   Oo  ___ (_) | __ __  __ _ ' _) :_
oO   oO ' _ `| | |/ /  _)' _` | |_|  _)
oOo oOO| | | | |   (| | | (_) |  _) :_
 OoOoO ._, ._:_:_,\_._,  .__,_:_, \___)
                  Ijiraq 0.21.0~7351f8b
B
head -7 "$T" | cmp -s - "$T.banner" || { rm -f "$T.banner"; echo "console.sh: banner not found as the first 7 lines of $R" >&2; exit 1; }
rm -f "$T.banner"
tail -n +8 "$T"
