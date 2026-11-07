#!/usr/bin/env bash
# Fixed public-fixture capture. An outer workflow timeout must bound this whole
# process: a surviving descendant can keep the pipe open after driver timeout.
set -uo pipefail
if [ "$#" -ne 4 ]; then exit 2; fi
writ_scenario="$1"
case "$writ_scenario" in positive|negative) ;; *) exit 2 ;; esac
writ_fixture="$2"
writ_evidence="$3"
writ_key="$4"
writ_here="$(cd -- "$(dirname -- "$0")" && pwd -P)"
set +e
timeout --foreground --signal=TERM --kill-after=15s 46m \
  env -i PATH=/usr/local/bin:/usr/bin:/bin HOME=/tmp LC_ALL=C \
  bash "$writ_here/ci-disposable.sh" "$writ_scenario" "$writ_fixture" "$writ_evidence" "$writ_key" \
  2>&1 | head -c 16777217 > "$writ_evidence/setup.log"
codes=("${PIPESTATUS[@]}")
set -e
printf 'driver_exit=%s\nlog_capture_exit=%s\ncleanup=unverified\n' "${codes[0]}" "${codes[1]}" \
  > "$writ_evidence/driver-status.txt"
if [ "$(wc -c < "$writ_evidence/setup.log")" -gt 16777216 ]; then
  echo 'INCOMPLETE: setup log bound exceeded' >&2
  exit 1
fi
[ "${codes[0]}" -eq 0 ] && [ "${codes[1]}" -eq 0 ]
