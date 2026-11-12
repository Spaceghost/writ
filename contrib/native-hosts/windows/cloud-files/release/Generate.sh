#!/usr/bin/env bash
# Release preparation only; all runtime decisions remain in Bend.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
writ_out=$(realpath -m "${1:?Pass a new output directory outside the checkout}")
case "$writ_out/" in "$PWD/"*) echo 'Build outside the checkout' >&2; exit 1;; esac
test ! -e "$writ_out"
mkdir -p "$writ_out/toolchain" "$writ_out/policy" "$writ_out/logs"
sha256sum -c --quiet verification/source-sha256.txt
writ_pins=contrib/native-hosts/windows/cloud-files/release/toolchains.json
writ_url=$(jq -r .bend.url "$writ_pins")
writ_hash=$(jq -r .bend.sha256 "$writ_pins")
curl --proto '=https' --tlsv1.2 --retry 3 -fL "$writ_url" -o "$writ_out/toolchain/bend.tar.gz"
printf '%s  %s\n' "$writ_hash" "$writ_out/toolchain/bend.tar.gz" | sha256sum -c -
tar -xzf "$writ_out/toolchain/bend.tar.gz" -C "$writ_out/toolchain"
writ_bend="$writ_out/toolchain/bend/bin/bend"
export BEND_NO_TELEMETRY=1
"$writ_bend" version | tee "$writ_out/logs/bend-version.txt"
"$writ_bend" writfs/PublicSync.bend -o "$writ_out/policy/public-sync.mjs"
"$writ_bend" writfs/PublicSync.bend -o "$writ_out/public-sync-repeat.mjs"
cmp "$writ_out/policy/public-sync.mjs" "$writ_out/public-sync-repeat.mjs"
"$writ_bend" writfs/PublicSyncTests.bend -o "$writ_out/policy/public-sync-tests.js"
"$writ_bend" writfs/drive/Model.bend -o "$writ_out/policy/drive.mjs"
"$writ_bend" writfs/drive/Model.bend -o "$writ_out/drive-repeat.mjs"
cmp "$writ_out/policy/drive.mjs" "$writ_out/drive-repeat.mjs"
"$writ_bend" writfs/drive/Tests.bend -o "$writ_out/policy/drive-tests.js"
"$writ_bend" writfs/drive/Tests.bend > "$writ_out/logs/drive-tests.txt"
"$writ_bend" writfs/drive/Tests.bend -o "$writ_out/drive-tests.c"
cc -O2 -pthread "$writ_out/drive-tests.c" -lm -o "$writ_out/drive-tests-native"
"$writ_out/drive-tests-native" > "$writ_out/logs/drive-tests-native.txt"
cmp "$writ_out/logs/drive-tests.txt" "$writ_out/logs/drive-tests-native.txt"
"$writ_bend" writfs/PublicSyncTests.bend > "$writ_out/logs/public-sync-tests.txt"
"$writ_bend" writfs/DirectorySync.bend -o "$writ_out/policy/directory-sync.mjs"
"$writ_bend" writfs/DirectoryNamespace.bend -o "$writ_out/policy/directory-namespace.mjs"
"$writ_bend" writfs/DirectorySync.bend -o "$writ_out/directory-sync-repeat.mjs"
"$writ_bend" writfs/DirectoryNamespace.bend -o "$writ_out/directory-namespace-repeat.mjs"
cmp "$writ_out/policy/directory-sync.mjs" "$writ_out/directory-sync-repeat.mjs"
cmp "$writ_out/policy/directory-namespace.mjs" "$writ_out/directory-namespace-repeat.mjs"
"$writ_bend" writfs/DirectorySyncTests.bend -o "$writ_out/policy/directory-sync-tests.js"
"$writ_bend" writfs/DirectoryNamespaceTests.bend -o "$writ_out/policy/directory-namespace-tests.js"
"$writ_bend" lib/Sha256StreamTests.bend -o "$writ_out/policy/stream-tests.js"
"$writ_bend" writfs/DirectorySyncTests.bend > "$writ_out/logs/directory-tests.txt"
"$writ_bend" writfs/DirectoryNamespaceTests.bend > "$writ_out/logs/namespace-tests.txt"
"$writ_bend" lib/Sha256StreamTests.bend > "$writ_out/logs/stream-tests.txt"
"$writ_bend" Tests.bend > "$writ_out/logs/core-tests.txt"
python3 utils/verification/check_core.py "$writ_out/logs/core-tests.txt"
"$writ_bend" PROOF.bend > "$writ_out/logs/proof.txt"
git rev-parse HEAD > "$writ_out/policy/commit.txt"
cp "$writ_out/logs/bend-version.txt" "$writ_out/policy/"
(
  cd "$writ_out/policy"
  sha256sum public-sync.mjs public-sync-tests.js directory-sync.mjs directory-namespace.mjs directory-sync-tests.js directory-namespace-tests.js stream-tests.js drive.mjs drive-tests.js commit.txt bend-version.txt > SHA256SUMS
)
tail -n 1 "$writ_out/logs/public-sync-tests.txt" "$writ_out/logs/core-tests.txt" "$writ_out/logs/proof.txt"
