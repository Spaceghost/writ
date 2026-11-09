#!/usr/bin/env bash
# Run as root inside a new, quota-limited Fedora 44 Incus base container.
# This installs CI tools only; no Writ authority or runtime host is provided.
set -euo pipefail
# shellcheck source=/dev/null
source /etc/os-release
[[ $ID == fedora && $VERSION_ID == 44 ]]
export TMPDIR=/var/tmp/writ-ci-install
export TMP=$TMPDIR TEMP=$TMPDIR
export npm_config_cache=/var/cache/writ-npm
mkdir -p "$TMPDIR" "$npm_config_cache"
dnf -y install git curl tar gzip xz nodejs nodejs-npm gcc clang make \
  pkgconf-pkg-config fuse3-devel libicu openssl-libs zlib libstdc++ \
  libunwind shadow-utils findutils diffutils which
useradd --uid 1000 --create-home --shell /bin/bash runner
mkdir -p /opt/actions-runner /opt/bend /etc/systemd/journald.conf.d
printf '[Journal]\nStorage=volatile\nRuntimeMaxUse=64M\n' \
  > /etc/systemd/journald.conf.d/writ-runner.conf
curl --proto '=https' --tlsv1.2 --retry 3 -fL \
  https://github.com/actions/runner/releases/download/v2.338.2/actions-runner-linux-x64-2.338.2.tar.gz \
  -o "$TMPDIR/runner.tar.gz"
printf '%s  %s\n' \
  baebf204307bac6193480852732f0aba2ae97b6c5597c244f4d5558390147c40 \
  "$TMPDIR/runner.tar.gz" | sha256sum -c -
tar -xzf "$TMPDIR/runner.tar.gz" -C /opt/actions-runner
chown -R runner:runner /opt/actions-runner
# Listener checks create _diag; use the eventual service identity here too.
runuser -u runner -- /opt/actions-runner/bin/Runner.Listener --version
curl --proto '=https' --tlsv1.2 --retry 3 -fL \
  https://github.com/bendlang/bend/releases/download/v2.0.39/bend-2.0.39-linux-x64.tar.gz \
  -o "$TMPDIR/bend.tar.gz"
printf '%s  %s\n' \
  6cf462fd8f70b094a4950ebb709a9c4ffd8f1d1189d9cedf1fd63cd5d041c7ab \
  "$TMPDIR/bend.tar.gz" | sha256sum -c -
tar -xzf "$TMPDIR/bend.tar.gz" -C /opt/bend
test "$(/opt/bend/bend/bin/bend version)" = 'bend 2.0.39'
npm install --global @fission-ai/openspec@1.16.0
test "$(openspec --version)" = '1.16.0'
dnf clean all
# Only these disposable installation downloads/caches are removed.
rm "$TMPDIR/runner.tar.gz" "$TMPDIR/bend.tar.gz"
rm -r "$npm_config_cache"
echo 'Base ready; stop it before cloning. No runner is registered in this base.'
