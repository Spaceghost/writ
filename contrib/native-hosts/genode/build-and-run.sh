#!/usr/bin/env bash
# Cross-build real base-hw components and execute them in three QEMU boots.
set -euo pipefail

if [ "$#" != 1 ]; then
  printf 'Usage: %s ABSOLUTE_BUILD_DIRECTORY_OUTSIDE_CHECKOUT\n' "$0" >&2
  exit 2
fi
writ_repo="$(cd -- "$(dirname -- "$0")/../../.." && pwd)"
writ_out="$(realpath -m -- "$1")"
case "$writ_out" in
  "$writ_repo"|"$writ_repo"/*|*[[:space:]]*)
    printf 'Build directory must be outside the checkout and contain no whitespace\n' >&2
    exit 2 ;;
esac
mkdir -p "$writ_out/inputs" "$writ_out/logs" "$writ_out/generated"
if [[ ! ${WRIT_CORE_EXPECTED:-} =~ ^[1-9][0-9]{0,4}$ ]]; then
  printf 'Set WRIT_CORE_EXPECTED to the reviewed complete core assertion count (currently 2472)\n' >&2
  exit 2
fi
export WRIT_CORE_EXPECTED

(
  cd "$writ_repo"
  gcc -std=c11 -O1 -g -Wall -Wextra -Werror \
    -fsanitize=address,undefined -fno-omit-frame-pointer \
    contrib/native-hosts/runtime/genode/quickjs_alloc.c \
    contrib/native-hosts/runtime/genode/allocator_checks.c \
    contrib/native-hosts/runtime/genode/allocator_probe.c \
    -o "$writ_out/allocator-probe"
  ASAN_OPTIONS=detect_leaks=1 UBSAN_OPTIONS=halt_on_error=1 "$writ_out/allocator-probe"
) 2>&1 | tee "$writ_out/logs/allocator-sanitizers.log"

writ_fetch() {
  local file="$1" hash="$2" url="$3"
  if [ ! -f "$file" ]; then
    curl --proto '=https' --tlsv1.2 --retry 3 --fail --location \
      "$url" --output "$file.part"
    printf '%s  %s\n' "$hash" "$file.part" | sha256sum --check --status
    mv -- "$file.part" "$file"
  fi
  printf '%s  %s\n' "$hash" "$file" | sha256sum --check
}

writ_fetch "$writ_out/inputs/genode-26.08.tar.gz" \
  df74f96c70c72607d66f5440439680b63683f09edd92809996845f0f29453a74 \
  https://codeberg.org/genodelabs/genode/archive/26.08.tar.gz
writ_fetch "$writ_out/inputs/quickjs-2026-06-04.tar.xz" \
  b376e839b322978313d929fd20663b11ba58b75df5a46c126dd19ea2fa70ad2a \
  https://bellard.org/quickjs/quickjs-2026-06-04.tar.xz
writ_fetch "$writ_out/inputs/genode-toolchain-25.05.tar.xz" \
  6cab8e5f4490399a296a73b01695d5fb055a40f6ac04d61a3f7a7344003eb739 \
  https://codeberg.org/genodelabs/genode/releases/download/25.05/genode-toolchain-25.05-ubuntu-24.04.tar.xz

writ_genode="$writ_out/inputs/genode"
writ_quickjs="$writ_out/inputs/quickjs"
writ_toolchain="$writ_out/inputs/toolchain"
if [ ! -d "$writ_genode" ]; then
  mkdir "$writ_genode"
  tar --no-same-owner -xzf "$writ_out/inputs/genode-26.08.tar.gz" \
    --strip-components=1 -C "$writ_genode"
fi
if [ ! -d "$writ_quickjs" ]; then
  mkdir "$writ_quickjs"
  tar --no-same-owner -xJf "$writ_out/inputs/quickjs-2026-06-04.tar.xz" \
    --strip-components=1 -C "$writ_quickjs"
fi
if [ ! -d "$writ_toolchain" ]; then
  mkdir "$writ_toolchain"
  # The official archive has /usr/local paths; GNU tar strips the leading /.
  tar --no-same-owner -xJf "$writ_out/inputs/genode-toolchain-25.05.tar.xz" \
    -C "$writ_toolchain"
fi
writ_cross="$writ_toolchain/usr/local/genode/tool/25.05/bin/genode-x86-"

{
  printf 'Writ source: %s\n' "$(git -C "$writ_repo" rev-parse HEAD)"
  printf 'Genode source: 26.08 d18ee9e917200b059549e21f2dd9a55bfe61a0eb\n'
  printf 'QuickJS source: 2026-06-04\nGenode toolchain: 25.05\n'
  printf 'Required complete core assertions: %s\n' "$WRIT_CORE_EXPECTED"
  uname -a
  "${writ_cross}gcc" --version
  gcc --version
  qemu-system-x86_64 --version
  expect -v
  bend version
  sha256sum "$writ_out"/inputs/*.tar.*
} 2>&1 | tee "$writ_out/logs/environment.log"
test "$(bend version)" = 'bend 2.0.39'

(
  cd "$writ_genode"
  TAR_OPTIONS=--no-same-owner tool/ports/prepare_port libc grub2
) 2>&1 | tee "$writ_out/logs/ports.log"

(
  cd "$writ_repo"
  bend writfs/Mount.bend -o "$writ_out/generated/mount.mjs"
  bend writfs/MountTests.bend -o "$writ_out/generated/mount-tests.mjs"
  bend Tests.bend -o "$writ_out/generated/core-tests.js"
  bend PROOF.bend
) 2>&1 | tee "$writ_out/logs/bend-generation-and-proof.log"

writ_build="$writ_out/hw"
if [ ! -f "$writ_build/Makefile" ]; then
  "$writ_genode/tool/create_builddir" x86_64 BUILD_DIR="$writ_build"
fi
writ_repositories="$writ_genode/repos/base-hw $writ_genode/repos/base $writ_genode/repos/os $writ_genode/repos/libports $writ_repo/contrib/native-hosts/genode"
cat > "$writ_build/etc/build.conf" <<EOF
GENODE_DIR := $writ_genode
BASE_DIR := \$(GENODE_DIR)/repos/base
CONTRIB_DIR := \$(GENODE_DIR)/contrib
KERNEL := hw
BOARD := pc
REPOSITORIES := $writ_repositories
export WRIT_QUICKJS_DIR := $writ_quickjs
export WRIT_GENERATED_DIR := $writ_out/generated
MAKE += -j4
EOF
printf 'CROSS_DEV_PREFIX := %s\n' "$writ_cross" > "$writ_build/etc/tools.conf"
export WRIT_GENERATED_DIR="$writ_out/generated"

for writ_case in writ_policy writfs writfs_vfs; do
  (
    cd "$writ_build"
    # Calling expect explicitly also works in an unprivileged tool prefix.
    expect "$writ_genode/tool/run/run" \
      --genode-dir "$writ_genode" --name "$writ_case" \
      --specs 'hw x86_64 x86 64bit' --board pc \
      --repositories "$writ_repositories" --cross-dev-prefix "$writ_cross" \
      --qemu-args "${WRIT_QEMU_ARGS:-}" --make 'make -j4' \
      --include boot_dir/hw --include power_on/qemu --include log/qemu \
      --include image/iso \
      --include "$writ_repo/contrib/native-hosts/genode/run/$writ_case.run"
  ) 2>&1 | tee "$writ_out/logs/$writ_case.log"
  cp "$writ_build/var/run/$writ_case.config" "$writ_out/logs/$writ_case.config"
done

(
  cd "$writ_repo"
  git ls-files -z -- '*.bend' contrib/native-hosts/genode contrib/native-hosts/runtime/genode \
    writfs/Mount.bend writfs/MountAuthority.bend writfs/MountTests.bend \
    .github/workflows/writfs-genode-native.yml | xargs -0 sha256sum
  sha256sum "$writ_out"/generated/* "$writ_build"/var/run/*.iso
  for writ_binary in writfs test_writ_policy test_writfs test_writfs_vfs; do
    sha256sum "$writ_build/bin/$writ_binary"
  done
) | tee "$writ_out/logs/source-and-build-sha256.txt"
printf 'PASS native Genode generated-policy corpus, File_system sessions, and libc VFS mount\n'
