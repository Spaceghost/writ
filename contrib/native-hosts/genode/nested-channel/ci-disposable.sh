#!/usr/bin/env bash
# Public fixture on a dedicated disposable GitHub-hosted VM only.
# Host termination is not verified; no global process cleanup is attempted.
set -euo pipefail

if [ "$#" -ne 4 ]; then
  printf 'Usage: %s positive|negative FIXTURE_CHECKOUT EVIDENCE_DIR RUN_KEY\n' "$0" >&2
  exit 2
fi
writ_scenario="$1"
case "$writ_scenario" in positive|negative) ;; *) exit 2 ;; esac
writ_fixture="$(realpath -e -- "$2")"
writ_evidence="$(realpath -e -- "$3")"
writ_key="$4"
[[ "$writ_key" =~ ^[0-9]+-[0-9]+$ ]] || exit 2
writ_source=e129c931ceb1d249cf0b0874a91390e5eef840c9
[ "$(git -C "$writ_fixture" rev-parse --show-toplevel)" = "$writ_fixture" ]
[ "$(git -C "$writ_fixture" rev-parse HEAD)" = "$writ_source" ]
if ! writ_status="$(git -C "$writ_fixture" status --porcelain --untracked-files=normal)"; then
  printf 'Cannot inspect fixture worktree status\n' >&2
  exit 1
fi
[ -z "$writ_status" ]
(cd "$writ_fixture" && sha256sum --check --status verification/source-sha256.txt)

writ_root="/tmp/writ-genode-ci.${writ_key}.${writ_scenario}"
writ_overlay="/tmp/writ-genode-nested-overlay.${writ_key}.${writ_scenario}"
[ ! -e "$writ_root" ] && [ ! -L "$writ_root" ]
[ ! -e "$writ_overlay" ] && [ ! -L "$writ_overlay" ]
umask 077
mkdir "$writ_root"
mkdir "$writ_root/inputs" "$writ_root/cache" "$writ_root/bin" "$writ_root/tmp"
export TMPDIR="$writ_root/tmp" BEND_NO_TELEMETRY=1
printf 'source=%s\nscenario=%s\ncleanup=unverified; dedicated VM disposal is fallback only\n' \
  "$writ_source" "$writ_scenario" > "$writ_evidence/identity.txt"

writ_fetch() {
  local name="$1" hash="$2" url="$3"
  curl --proto '=https' --tlsv1.2 --retry 2 --connect-timeout 30 --max-time 600 \
    --fail --silent --show-error --location "$url" --output "$writ_root/inputs/$name"
  printf '%s  %s\n' "$hash" "$writ_root/inputs/$name" | sha256sum --check
}
writ_fetch bend.tar.gz 6cf462fd8f70b094a4950ebb709a9c4ffd8f1d1189d9cedf1fd63cd5d041c7ab \
  https://github.com/bendlang/bend/releases/download/v2.0.39/bend-2.0.39-linux-x64.tar.gz
writ_fetch genode.tar.gz df74f96c70c72607d66f5440439680b63683f09edd92809996845f0f29453a74 \
  https://codeberg.org/genodelabs/genode/archive/26.08.tar.gz
writ_fetch toolchain.tar.xz 6cab8e5f4490399a296a73b01695d5fb055a40f6ac04d61a3f7a7344003eb739 \
  https://codeberg.org/genodelabs/genode/releases/download/25.05/genode-toolchain-25.05-ubuntu-24.04.tar.xz
if timeout --foreground --signal=TERM --kill-after=5s 21m \
    "$(dirname -- "$0")/ci-fetch-libc.sh" "$writ_root/inputs" "$writ_evidence"; then
  printf 'wrapper_exit=0\n' >> "$writ_evidence/libc-fetch.txt"
else
  writ_fetch_status=$?
  # This is an observation when the wrapper returns; hard cancellation can
  # prevent recording it and is already incomplete. No process-group kill.
  printf 'wrapper_exit=%s\n' "$writ_fetch_status" >> "$writ_evidence/libc-fetch.txt"
  exit 1
fi
writ_fetch llvm.tar.gz 2998c82e4035d090e5e748d1a8fc118b1b7b48643f5d5b8f30c9135036a730f6 \
  https://mirror.facebook.net/kernel.org/pub/tools/llvm/files/llvm-23.1.3-x86_64.tar.gz
sha256sum "$writ_root"/inputs/* > "$writ_evidence/input-sha256.txt"
mkdir "$writ_root/bend" "$writ_root/genode" "$writ_root/toolchain" "$writ_root/llvm"
tar --no-same-owner -xzf "$writ_root/inputs/bend.tar.gz" -C "$writ_root/bend"
tar --no-same-owner -xzf "$writ_root/inputs/genode.tar.gz" --strip-components=1 -C "$writ_root/genode"
tar --no-same-owner -xJf "$writ_root/inputs/toolchain.tar.xz" -C "$writ_root/toolchain"
tar --no-same-owner -xzf "$writ_root/inputs/llvm.tar.gz" --strip-components=1 -C "$writ_root/llvm"
# Prove the pinned archive matches a separately obtained checkout of the
# expected upstream commit; retain any mismatch as setup failure.
git clone --quiet --depth 1 --branch 26.08 https://codeberg.org/genodelabs/genode.git "$writ_root/genode-reference"
[ "$(git -C "$writ_root/genode-reference" rev-parse HEAD)" = d18ee9e917200b059549e21f2dd9a55bfe61a0eb ]
git -C "$writ_root/genode-reference" status --porcelain --untracked-files=normal > "$writ_evidence/genode-git-status.txt"
[ ! -s "$writ_evidence/genode-git-status.txt" ]
diff -rq --exclude=.git "$writ_root/genode" "$writ_root/genode-reference" > "$writ_evidence/genode-archive-comparison.txt"
git -C "$writ_root/genode-reference" -c core.filemode=true -c core.autocrlf=false \
  --work-tree="$writ_root/genode" status --porcelain --untracked-files=all > "$writ_evidence/genode-archive-git-status.txt"
[ ! -s "$writ_evidence/genode-archive-git-status.txt" ]
printf 'genode_commit=d18ee9e917200b059549e21f2dd9a55bfe61a0eb\n' > "$writ_evidence/genode-commit.txt"
writ_bend="$writ_root/bend/bend/bin/bend"
writ_cross="$writ_root/toolchain/usr/local/genode/tool/25.05/bin/genode-x86-"
[ "$($writ_bend version)" = 'bend 2.0.39' ]
[ -x "$writ_root/llvm/bin/clang" ]
ln -s "$writ_root/llvm/bin/clang" "$writ_root/bin/clang-23"
export PATH="$writ_root/bin:$writ_root/llvm/bin:$PATH"
{
  printf 'Bend: '; "$writ_bend" version
  printf 'Genode VERSION: '; cat "$writ_root/genode/VERSION"
  clang-23 --version
  clang-23 -print-resource-dir
  printf 'Node: '; node --version
  printf 'Node zlib: '; node -p 'process.versions.zlib'
  "${writ_cross}g++" --version | head -n 1
  sha256sum "$writ_bend" "$(realpath -e "$writ_root/bin/clang-23")" "${writ_cross}g++" "$(command -v node)"
} > "$writ_evidence/tool-identity.txt"
writ_clang_resource="$(clang-23 -print-resource-dir)"
(cd "$writ_clang_resource" && find . -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum) \
  > "$writ_evidence/clang-resource-sha256.txt"

# Genode's port tool otherwise permits HTTP/wget certificate bypass. Seed the
# hash-verified private cache and forbid any wget fallback during preparation.
cp "$writ_root/inputs/libc.txz" \
  "$writ_root/cache/0da393ac2174168a71c1c527d1453e07372295187d05c288250800cb152a889b_src.txz"
printf '#!/bin/sh\necho "unexpected port network fallback" >&2\nexit 1\n' > "$writ_root/bin/wget"
chmod 755 "$writ_root/bin/wget"
PATH="$writ_root/bin:$PATH" GENODE_CONTRIB_CACHE="$writ_root/cache" \
  "$writ_root/genode/tool/ports/prepare_port" libc

"$writ_fixture/contrib/native-hosts/genode/nested-channel/prepare-overlay.sh" \
  "$writ_overlay" "$writ_bend"
cp "$writ_overlay"/{environment.txt,source-sha256.txt,overlay-sha256.txt,generated-sha256.txt} "$writ_evidence/"
cp "$writ_overlay/writ-repo/run/writ_bend_monitor_nested_accept.run" "$writ_evidence/original.run"
python3 "$(dirname -- "$0")/ci-route-fixture.py" prepare "$writ_scenario" \
  "$writ_evidence/original.run" "$writ_overlay/writ-repo/run/writ_bend_monitor_nested_accept.run"
cp "$writ_overlay/writ-repo/run/writ_bend_monitor_nested_accept.run" "$writ_evidence/actual.run"
sha256sum "$writ_evidence/original.run" "$writ_evidence/actual.run" > "$writ_evidence/config-sha256.txt"
if [ "$writ_scenario" = negative ]; then
  set +e
  diff -u "$writ_evidence/original.run" "$writ_evidence/actual.run" > "$writ_evidence/negative.diff"
  writ_diff_status=$?
  set -e
  [ "$writ_diff_status" -eq 1 ]
fi

"$writ_root/genode/tool/create_builddir" x86_64 BUILD_DIR="$writ_root/build"
python3 - "$writ_root/build/etc/build.conf" "$writ_overlay/writ-repo" <<'PY'
import pathlib, sys
p, overlay = pathlib.Path(sys.argv[1]), sys.argv[2]
s = p.read_text()
for a, b in [('#MAKE += -j4', 'MAKE += -j2'),
             ('BOARD ?= pc', 'BOARD ?= linux\nKERNEL ?= linux'),
             ('#REPOSITORIES += $(GENODE_DIR)/repos/libports', 'REPOSITORIES += $(GENODE_DIR)/repos/libports'),
             ('#REPOSITORIES += $(GENODE_DIR)/repos/gems', 'REPOSITORIES += $(GENODE_DIR)/repos/gems')]:
    if s.count(a) != 1:
        raise SystemExit('unexpected fresh Genode build template: ' + a)
    s = s.replace(a, b)
s += '\nREPOSITORIES += ' + overlay + '\n'
p.write_text(s)
PY
printf 'CROSS_DEV_PREFIX = %s\n' "$writ_cross" > "$writ_root/build/etc/tools.conf"
cp "$writ_root/build/etc/build.conf" "$writ_root/build/etc/tools.conf" "$writ_evidence/"
sha256sum "$writ_evidence/build.conf" "$writ_evidence/tools.conf" > "$writ_evidence/build-config-sha256.txt"

# Fixed native I/O collector preserves the complete raw stream as bounded gzip.
# The outer foreground timeout bounds waiting; it does not prove cleanup.
set +e
node "$(dirname -- "$0")/ci-log-collect.mjs" "$writ_root/build" "$writ_evidence"
writ_capture_status=$?
set -e
printf 'collector_exit=%s\n' "$writ_capture_status" > "$writ_evidence/run-status.txt"
writ_boot="$writ_root/build/var/run/writ_bend_monitor_nested_accept/genode"
if [ -d "$writ_boot" ]; then
  (cd "$writ_boot" && find -L . -maxdepth 1 -type f -print0 | LC_ALL=C sort -z | xargs -0 -r sha256sum) \
    > "$writ_evidence/boot-inputs-sha256.txt"
  if [ -f "$writ_boot/config" ]; then
    cp "$writ_boot/config" "$writ_evidence/installed-config.txt"
  fi
fi
if ! writ_status="$(git -C "$writ_fixture" status --porcelain --untracked-files=normal)"; then
  printf 'Cannot inspect fixture worktree status after run\n' >&2
  exit 1
fi
printf '%s' "$writ_status" > "$writ_evidence/fixture-post-status.txt"
[ -z "$writ_status" ]
[ "$(git -C "$writ_fixture" rev-parse HEAD)" = "$writ_source" ]
(cd "$writ_fixture" && sha256sum --check --status verification/source-sha256.txt)
printf 'tracked source manifest rechecked after run\n' > "$writ_evidence/fixture-post-manifest.txt"
[ "$writ_capture_status" -eq 0 ]
node "$(dirname -- "$0")/ci-log-audit.mjs" "$writ_evidence" "$writ_scenario"
[ -f "$writ_evidence/installed-config.txt" ]
python3 "$(dirname -- "$0")/ci-route-fixture.py" check-config "$writ_scenario" \
  "$writ_fixture/verification/genode-nested-ci-7b31cfc/raw/positive.zip" \
  "$writ_evidence/installed-config.txt"
printf 'fixture_assertions=matched\ncleanup=unverified\noverall=incomplete\n' > "$writ_evidence/observed.txt"
