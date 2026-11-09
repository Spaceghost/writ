#!/usr/bin/env bash
# Host-side CI supervisor. Never copy GitHub credentials into the guest.
set -euo pipefail
readonly repo=Spaceghost/writ
readonly remote=fedora
readonly base=writ-runner-base
readonly instance=writ-runner-job
runner_id=
owned=0

cleanup() {
  if [[ -n $runner_id ]]; then
    gh api -X DELETE "repos/$repo/actions/runners/$runner_id" >/dev/null || true
    runner_id=
  fi
  if (( owned )); then
    incus delete --force "$remote:$instance"
    owned=0
  fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# A second supervisor must not reuse or delete another process's guest.
exec 9>"${XDG_RUNTIME_DIR:?}/writ-incus-runner.lock"
flock -n 9 || exit 1
if incus info "$remote:$instance" >/dev/null 2>&1; then
  echo "Existing $remote:$instance needs inspection before starting." >&2
  exit 1
fi

while :; do
  incus copy "$remote:$base" "$remote:$instance" --ephemeral
  owned=1
  incus start "$remote:$instance"
  # One-use registration, restricted to this repository. gh's credential stays
  # on the supervisor host; only the encoded JIT configuration crosses stdin.
  jit=$(gh api -X POST "repos/$repo/actions/runners/generate-jitconfig" \
    --input - <<'JSON'
{"name":"writ-fedora-incus","runner_group_id":1,"labels":["self-hosted","Linux","X64","writ-fedora","fedora-44"],"work_folder":"_work"}
JSON
  )
  runner_id=$(jq -er '.runner.id' <<<"$jit")
  # The quoted config expression is evaluated inside the guest, not here.
  # shellcheck disable=SC2016
  printf '%s' "$jit" | jq -er '.encoded_jit_config' | \
    incus exec "$remote:$instance" --user 1000 --group 1000 \
      --env HOME=/home/runner --env USER=runner --env LOGNAME=runner \
      --env BEND_NO_TELEMETRY=1 \
      --env PATH=/opt/bend/bend/bin:/usr/local/bin:/usr/bin:/bin \
      --cwd /opt/actions-runner -- bash -c \
      'IFS= read -r config; exec ./run.sh --jitconfig "$config"' \
    || echo "Runner exited unsuccessfully; retiring guest." >&2
  unset jit
  cleanup
  sleep 10
done
