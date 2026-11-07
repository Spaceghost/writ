#!/usr/bin/env bash
# Own synthetic descendant only. No Genode, host process discovery or group kill.
set -euo pipefail
writ_here="$(cd -- "$(dirname -- "$0")" && pwd -P)"
writ_tmp="$(mktemp -d /tmp/writ-capture-probe.XXXXXX)"
trap 'rm -rf -- "$writ_tmp"' EXIT
[ "$(grep -c '46m' "$writ_here/ci-log-capture.sh")" -eq 1 ]
sed 's/46m/1s/' "$writ_here/ci-log-capture.sh" > "$writ_tmp/ci-log-capture.sh"
cat > "$writ_tmp/ci-disposable.sh" <<'DRIVER'
#!/usr/bin/env bash
(sleep 4) &
printf 'synthetic descendant temporarily retains the pipe\n'
exit 0
DRIVER
mkdir "$writ_tmp/raw"
set +e
timeout --foreground --signal=TERM --kill-after=1s 2s \
  bash "$writ_tmp/ci-log-capture.sh" positive "$writ_tmp" "$writ_tmp/raw" 1-1
writ_status=$?
set -e
[ "$writ_status" -eq 124 ]
printf 'outer timeout returned 124 while the synthetic pipe was retained\n'
# The owned synthetic child exits naturally; allow its pipe holder to finish.
sleep 5
rg -F 'synthetic descendant temporarily retains the pipe' "$writ_tmp/raw/setup.log" >/dev/null
printf 'synthetic pipe output eventually arrived; cleanup is not attested\n'
