#!/usr/bin/env bash
# Per-user application installation only. Never change system FUSE or services.
set -euo pipefail
umask 077
source_dir=$(cd -- "$(dirname -- "$0")" && pwd -P)
user_home=$(realpath -e -- "$HOME")
data_home=$(realpath -m -- "${XDG_DATA_HOME:-$HOME/.local/share}")
prefix="$data_home/Writ/app"
if [[ $# == 2 && $1 == --prefix ]]; then prefix=$(realpath -m -- "$2"); elif [[ $# != 0 ]]; then echo 'Usage: install.sh [--prefix ABSOLUTE_PATH]' >&2; exit 2; fi
for path in "$prefix" "$data_home"; do
    case "$path" in "$user_home/"*) ;; *) echo 'Install paths must be beneath your home directory.' >&2; exit 1;; esac
    # These characters need extra desktop Exec escaping; reject them explicitly.
    if [[ $path == *[$'\n\r"\\`$%']* ]]; then echo 'Unsupported character in install path.' >&2; exit 1; fi
done
for retained in "$user_home/Writ" "$user_home/Writ Drive" "$data_home/WritDemo" "$data_home/WritDrive"; do
    case "$prefix/" in "$retained/"*) echo 'Keep the application outside Writ user data.' >&2; exit 1;; esac
    case "$retained/" in "$prefix/"*) echo 'Keep the application outside Writ user data.' >&2; exit 1;; esac
done
desktop="$data_home/applications/writ.desktop"
[[ ! -e $prefix && ! -L $prefix && ! -e $desktop && ! -L $desktop ]] || { echo 'Writ installation or launcher already exists; uninstall it first. User files are retained.' >&2; exit 1; }
(cd -- "$source_dir" && sha256sum --quiet -c SHA256SUMS)
"$source_dir/writ-linux" version
mkdir -p -- "$(dirname -- "$prefix")" "$(dirname -- "$desktop")"
cp -R -- "$source_dir" "$prefix"
printf '%s\n' 'Writ per-user application' > "$prefix/.writ-install"
printf '%s\n' "$desktop" > "$prefix/.writ-desktop-path"
cat > "$prefix/.writ-desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Writ
Comment=S3-compatible files, provenance and managed transfer rules
Exec="$prefix/writ-linux" app
Terminal=false
Categories=Utility;
EOF
cp -- "$prefix/.writ-desktop" "$desktop"
printf 'Installed Writ in %s\nLaunch Writ from your applications menu, or run "%s/writ-linux".\nUninstall with "%s/uninstall.sh".\n' "$prefix" "$prefix" "$prefix"
