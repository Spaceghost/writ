#!/usr/bin/env bash
set -euo pipefail
prefix=$(cd -- "$(dirname -- "$0")" && pwd -P)
[[ $(cat -- "$prefix/.writ-install") == 'Writ per-user application' ]] || { echo 'Not an installed Writ application.' >&2; exit 1; }
# This must succeed BEFORE removing any application files or the launcher.
# Busy mounts retain the application so the user can close files and retry.
"$prefix/writ-linux" cleanup
desktop=$(cat -- "$prefix/.writ-desktop-path")
if [[ -f $desktop ]] && cmp -s -- "$desktop" "$prefix/.writ-desktop"; then rm -- "$desktop"; fi
while IFS= read -r line; do
    name=${line#*  }
    [[ $name =~ ^[A-Za-z0-9._/-]+$ && $name != /* && $name != *..* ]] || { echo 'Invalid installed manifest.' >&2; exit 1; }
    rm -f -- "$prefix/$name"
done < "$prefix/SHA256SUMS"
rm -- "$prefix/SHA256SUMS" "$prefix/.writ-install" "$prefix/.writ-desktop-path" "$prefix/.writ-desktop"
rmdir -- "$prefix/lib"
if ! rmdir -- "$prefix"; then echo 'Additional files in the application directory were retained.'; fi
echo 'Writ removed. Hydrated files, local edits, backing data and recovery copies were retained.'
