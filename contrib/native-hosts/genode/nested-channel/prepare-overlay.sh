#!/usr/bin/env bash
# Prepare public nested-channel inputs outside the source checkout.
# This script does not build Genode, launch a host, or run the fixture.
set -euo pipefail

# Git environment overrides can redirect -C to another repository or index.
# Source identity must come from the checkout containing this script.
for writ_git_env in ${!GIT_@}; do
  unset "$writ_git_env"
done

if [ "$#" -ne 2 ]; then
  printf 'Usage: %s ABSOLUTE_NEW_OUTPUT_DIR ABSOLUTE_BEND_EXECUTABLE\n' "$0" >&2
  exit 2
fi
writ_repo="$(cd -- "$(dirname -- "$0")/../../../.." && pwd -P)"
if [ "$(git -C "$writ_repo" rev-parse --show-toplevel)" != "$writ_repo" ]; then
  printf 'Git top level does not match the script checkout\n' >&2; exit 1
fi
case "$1" in /*) ;; *) printf 'Output directory must be absolute\n' >&2; exit 2 ;; esac
case "$2" in /*) ;; *) printf 'Bend executable must be absolute\n' >&2; exit 2 ;; esac
writ_out="$(realpath -m -- "$1")"
writ_bend="$(realpath -e -- "$2")"
if [ "$(dirname -- "$writ_out")" != "$(realpath -e /tmp)" ] ||
   [[ "$(basename -- "$writ_out")" != writ-genode-nested-overlay.* ]] ||
   [[ "$writ_out" == *[[:space:]]* ]]; then
  printf 'Output must be a fresh direct /tmp/writ-genode-nested-overlay.* directory\n' >&2
  exit 2
fi
if [ -e "$writ_out" ] || [ -L "$1" ]; then
  printf 'Output directory already exists; choose a fresh path\n' >&2; exit 2
fi
if [ ! -x "$writ_bend" ] || [ "$("$writ_bend" version)" != 'bend 2.0.39' ]; then
  printf 'Expected executable reporting bend 2.0.39\n' >&2; exit 2
fi
if ! writ_status="$(git -C "$writ_repo" status --porcelain --untracked-files=normal)"; then
  printf 'Could not inspect source worktree status\n' >&2; exit 1
fi
if [ -n "$writ_status" ]; then
  printf 'Source worktree must be clean to identify the staged inputs\n' >&2; exit 2
fi
writ_head="$(git -C "$writ_repo" rev-parse --verify HEAD)"

# mkdir without -p refuses to reuse a path; failed preparation is left intact
# for inspection. The output is private and a fresh direct child of /tmp.
umask 077
mkdir -- "$writ_out"
writ_overlay="$writ_out/writ-repo"
mkdir -p "$writ_overlay/run" "$writ_overlay/src/app/writ_bend_monitor" \
  "$writ_overlay/src/app/writ_channel_client" "$writ_overlay/src/writ_shim" \
  "$writ_out/bend-c/monitor"

writ_stage() {
  local source_rel="$1" target_rel="$2"
  install -m 0644 -- "$writ_repo/$source_rel" "$writ_overlay/$target_rel"
  cmp -s -- "$writ_repo/$source_rel" "$writ_overlay/$target_rel"
}
writ_stage scripts/genode/writ_bend.tcl run/writ_bend.tcl
writ_stage scripts/genode/writ_bend_monitor/writ_bend_monitor.tcl run/writ_bend_monitor.tcl
writ_stage contrib/native-hosts/genode/nested-channel/writ_bend_monitor_nested_accept.run run/writ_bend_monitor_nested_accept.run
writ_stage contrib/native-hosts/genode/nested-channel/writ_bend_monitor_nested_route_negative.run run/writ_bend_monitor_nested_route_negative.run
writ_stage contrib/native-hosts/genode/nested-channel/writ_bend_monitor_nested_guarded_positive.run run/writ_bend_monitor_nested_guarded_positive.run
writ_stage contrib/native-hosts/genode/nested-channel/writ_bend_monitor_nested_guarded_negative.run run/writ_bend_monitor_nested_guarded_negative.run
writ_stage contrib/native-hosts/genode/nested-channel/writ_fixture_config_guard.tcl run/writ_fixture_config_guard.tcl
writ_stage contrib/native-hosts/genode/nested-channel/writ_guard_positive.args run/writ_guard_positive.args
writ_stage contrib/native-hosts/genode/nested-channel/writ_guard_negative.args run/writ_guard_negative.args
writ_stage scripts/genode/writ_bend.inc src/app/writ_bend.inc
writ_stage scripts/genode/writ_bend_monitor/target.mk src/app/writ_bend_monitor/target.mk
writ_stage hosts/genode/probes/client/target.mk src/app/writ_channel_client/target.mk
writ_stage hosts/genode/probes/client/writ_channel_client.cc src/app/writ_channel_client/writ_channel_client.cc
writ_stage hosts/genode/shim/writ_mem.cc src/writ_shim/writ_mem.cc
writ_stage hosts/genode/shim/writ_channel_session.h src/writ_shim/writ_channel_session.h
writ_stage hosts/genode/shim/writ_shim.mk src/writ_shim/writ_shim.mk

# Fixed historical argument vectors and negative fixture; do not regenerate
# expected bytes from the configuration being tested. A source/overlay with a
# changed reference must be reviewed and these fixed pins deliberately updated.
if ! (cd "$writ_overlay" && sha256sum --check --status <<'PINS'
9832324d540f478108e0df4063468163702be4b2716ffb0663e59e35fe7e577e  run/writ_guard_positive.args
bb05c8aef62045425f71da1fee373b06e9b8539adc457592fdb50266856fe48c  run/writ_guard_negative.args
175a8e32cceaa6c4d38498a95e7754fc4fe5438ad0960a2ebadccb2f808e0c6e  run/writ_bend_monitor_nested_route_negative.run
PINS
); then
  printf 'Fixed public fixture reference or negative source hash differs\n' >&2
  exit 1
fi

{
  printf 'source_commit=%s\n' "$writ_head"
  printf 'bend_version='; "$writ_bend" version
  printf 'bend_executable_sha256='; sha256sum -- "$writ_bend"
  printf 'generated_c_command=bend hosts/genode/monitor/Monitor.bend -o %s\n' "$writ_out/bend-c/monitor/monitor.c"
} > "$writ_out/environment.txt"
(
  cd "$writ_repo"
  git ls-files -z -- '*.bend' | xargs -0 sha256sum
  sha256sum -- \
    scripts/genode/writ_bend.tcl \
    scripts/genode/writ_bend_monitor/writ_bend_monitor.tcl \
    contrib/native-hosts/genode/nested-channel/writ_bend_monitor_nested_accept.run \
    contrib/native-hosts/genode/nested-channel/writ_bend_monitor_nested_route_negative.run \
    contrib/native-hosts/genode/nested-channel/writ_bend_monitor_nested_guarded_positive.run \
    contrib/native-hosts/genode/nested-channel/writ_bend_monitor_nested_guarded_negative.run \
    contrib/native-hosts/genode/nested-channel/writ_fixture_config_guard.tcl \
    contrib/native-hosts/genode/nested-channel/writ_guard_positive.args \
    contrib/native-hosts/genode/nested-channel/writ_guard_negative.args \
    scripts/genode/writ_bend.inc \
    scripts/genode/writ_bend_monitor/target.mk \
    hosts/genode/probes/client/target.mk \
    hosts/genode/probes/client/writ_channel_client.cc \
    hosts/genode/shim/writ_mem.cc \
    hosts/genode/shim/writ_channel_session.h \
    hosts/genode/shim/writ_shim.mk
) > "$writ_out/source-sha256.txt"
(
  cd "$writ_overlay"
  sha256sum -- run/writ_bend.tcl run/writ_bend_monitor.tcl \
    run/writ_bend_monitor_nested_accept.run run/writ_bend_monitor_nested_route_negative.run \
    run/writ_bend_monitor_nested_guarded_positive.run run/writ_bend_monitor_nested_guarded_negative.run \
    run/writ_fixture_config_guard.tcl run/writ_guard_positive.args run/writ_guard_negative.args \
    src/app/writ_bend.inc \
    src/app/writ_bend_monitor/target.mk src/app/writ_channel_client/target.mk \
    src/app/writ_channel_client/writ_channel_client.cc src/writ_shim/writ_mem.cc \
    src/writ_shim/writ_channel_session.h src/writ_shim/writ_shim.mk
) > "$writ_out/overlay-sha256.txt"
(
  cd "$writ_repo"
  BEND_NO_TELEMETRY=1 "$writ_bend" hosts/genode/monitor/Monitor.bend \
    -o "$writ_out/bend-c/monitor/monitor.c"
) > "$writ_out/bend.stdout" 2> "$writ_out/bend.stderr"
sha256sum -- "$writ_out/bend-c/monitor/monitor.c" > "$writ_out/generated-sha256.txt"
if [ "$(git -C "$writ_repo" rev-parse --verify HEAD)" != "$writ_head" ]; then
  printf 'Source HEAD changed while preparing; output is not an exact-source capture\n' >&2
  exit 1
fi
if ! (cd "$writ_repo" && sha256sum --check --status "$writ_out/source-sha256.txt"); then
  printf 'Source inputs changed while preparing; output is not an exact-source capture\n' >&2
  exit 1
fi
if ! writ_status="$(git -C "$writ_repo" status --porcelain --untracked-files=normal)"; then
  printf 'Could not inspect source worktree status after preparation\n' >&2; exit 1
fi
if [ -n "$writ_status" ]; then
  printf 'Source worktree changed while preparing; output is not an exact-source capture\n' >&2
  exit 1
fi
printf 'Prepared external overlay at %s; no Genode build or run was started.\n' "$writ_out"
