# Install and verify Writ

Writ is validated with **Bend 2.0.39**. Use that exact version when reproducing the
recorded examples and checks. Bend 1 is a different language and runtime.

## Install the pinned compiler

The following commands install the official Linux x86_64 release into a
version-specific directory without changing your shell profile. Run them in a
shell with `curl`, `tar`, and `sha256sum` available:

```sh
set -eu
writ_bend_dir="$HOME/.local/share/writ-toolchains/bend-2.0.39"
mkdir -p "$writ_bend_dir"
curl --proto '=https' --tlsv1.2 -fL \
  https://github.com/bendlang/bend/releases/download/v2.0.39/bend-2.0.39-linux-x64.tar.gz \
  -o "$writ_bend_dir/release.tar.gz"
printf '%s  %s\n' \
  6cf462fd8f70b094a4950ebb709a9c4ffd8f1d1189d9cedf1fd63cd5d041c7ab \
  "$writ_bend_dir/release.tar.gz" | sha256sum -c -
tar -xzf "$writ_bend_dir/release.tar.gz" -C "$writ_bend_dir"
export PATH="$writ_bend_dir/bend/bin:$PATH"
export BEND_NO_TELEMETRY=1
bend version
```

Check that the reported version is `2.0.39`. Keep the extracted `bin/`, `bend2/`,
and `guide/` directories together: the executable uses its adjacent installation.
To use it in another shell, repeat the two `export` commands with the same
`writ_bend_dir` assignment.

For macOS or Linux ARM64, use the matching archive from the same
[official release](https://github.com/bendlang/bend/releases/tag/v2.0.39).
The Linux release targets glibc; a musl-only Alpine installation needs a compatible
environment or a separately validated toolchain. The package's recorded run was
on Linux x86_64; other platforms are not claimed as tested here.

## Nix

The repository's `flake.nix` packages the same pinned toolchain. From the
repository root, on Linux x86_64 with Nix installed:

```sh
nix develop
bend version
openspec --version
```

The shell provides Bend 2.0.39 (the official release tarball above, fetched by
its recorded SHA-256 and patched only to use the Nix store's dynamic loader),
OpenSpec 1.16.0 (built from the npm registry tarball with a committed
`utils/nix/openspec/package-lock.json`), the newest clang in the locked nixpkgs as
`CC`, Node.js 22, Bun, Python 3, QEMU, git, gh, and make. It exports
`BEND_NO_TELEMETRY=1` and `OPENSPEC_TELEMETRY=0`, and prints the tool versions
on entry. `flake.lock` pins nixpkgs to one nixos-unstable revision. Run
`nix flake check` to confirm the packaged Bend and OpenSpec report the pinned
versions. The recorded commands and outputs are in
[verification/nix-shell.txt](../verification/nix-shell.txt).

The flake also builds and checks the library itself, offline in the Nix
sandbox, from a source tree filtered to authored `.bend` files, including the
root, `examples/`, and `hosts/` modules:

```sh
nix build .#tests-native
./result/bin/tests-native +RTS --threads 4 --gpu off
nix build .#examples-native
nix flake check
```

`packages.tests-native` is `bend Tests.bend -o tests-native` compiled with the
flake's clang; `packages.examples-native` holds `example`, `flow`, `transfer`,
and `gpu-example` built from `Example.bend`, `examples/Flow.bend`,
`examples/Transfer.bend`, and `GpuExample.bend`. `nix flake check` runs the
library suite on Bend's bundled JavaScript runner (`tests-js`) and as the native
binary with `+RTS --threads 4 --gpu off` (`tests-native`), requiring 2226 lines
beginning with `PASS` and the final line `ALL LIBRARY TESTS PASSED`; it runs
`bend PROOF.bend` and requires `ALL PROOFS CHECK` (`proofs`, without
`--verdict`); and it runs `openspec validate --all --strict --no-interactive`
over `openspec/` (`openspec`). The [2,102-check Nix JavaScript result](../verification/handoff-model-817ab1f-nix-js.log) covers the hardened `817ab1f` model inputs. The earlier 2,065-check Nix JavaScript and native CPU checks passed for source `73a8055` with the same output as each other.
The [2,223-check integration-preview Nix JavaScript result](../verification/planner-boundary-comparator-preview.md) covers source `6985302`; no current full flake check or Nix native result is claimed.
The earlier [2,065-check combined flake check](../verification/nix-combined-flake-check.log) for the `73a8055` implementation inputs passed all checks with evidence-only files staged. The historical artifacts below cover the previous
1942-check tree. The native checks use the flake's clang 23.1.3, not the
clang 19.1.1 of the recorded native run, and the JavaScript check uses Bend's bundled runtime, not
the separate Node.js 24.22.1 run. The native test check is a CPU run; nothing
in the flake builds a device program or tests a GPU. `nix flake check` does
not build `examples-native`; build it explicitly. The recorded runs are in
[verification/nix-checks.txt](../verification/nix-checks.txt), and two clean
builds of `tests-native` with identical store hashes are in
[verification/nix-determinism.txt](../verification/nix-determinism.txt).

These commands need flakes. If your Nix configuration does not enable them, add
`--extra-experimental-features 'nix-command flakes'` to each command, or add
`experimental-features = nix-command flakes` to `~/.config/nix/nix.conf`.

The manual instructions above remain valid and install the same pinned
versions; Nix is a convenience for obtaining them, not a requirement. The
native-build examples below name `clang-19`; inside the Nix shell use `$CC`
instead. The shell's clang (23.1.3 at the locked revision) is newer than the
clang 19.1.1 used for the recorded native run, so a native result from the shell
is a separate run, not a reproduction of that record.

## Run the examples

```sh
git clone https://github.com/Spaceghost/writ.git
cd writ
bend examples/Flow.bend
bend examples/Transfer.bend
bend Example.bend
bend GpuExample.bend
```

These are real Bend programs with assertions. A failed expectation exits nonzero.
The ordinary IO runner uses the JavaScript backend. The
[example guide](../examples/README.md) records the expected output and explains
what each check establishes.

All project imports are local. `Base` comes with the compiler. You do not need to
publish the package to BendHub or install a separate Writ dependency.

## Build a native CPU executable

Install clang 19 or newer for native builds; the recorded build used clang 19.1.1.
Set `CC` to its executable if the default compiler is different. Keep generated
files in a sibling build directory, outside the source package:

```sh
mkdir -p ../writ-build
CC=clang-19 bend Example.bend -o ../writ-build/example
../writ-build/example +RTS --threads 4 --gpu off
CC=clang-19 bend GpuExample.bend -o ../writ-build/parallel
../writ-build/parallel +RTS --threads 4 --gpu off
```

Use your compiler's actual name or absolute path in place of `clang-19`.
`--gpu off` makes this a CPU run, including the device-requesting calls.
Running without that option still does not establish GPU execution: Bend can
fall back to the CPU. Device compilation, device identity, execution evidence,
and performance measurements belong to the separate
[physical GPU validation change](../openspec/changes/validate-physical-gpu-execution/proposal.md).

## Reproduce the verification

For the explicit JavaScript build below, install Node.js as well; the recorded
run used Node.js 24.22.1. The ordinary `bend Example.bend` command uses Bend's
bundled JavaScript runtime and does not require this separate `node` command.
From the repository root:

```sh
mkdir -p ../writ-build
bend DataOS.bend --check-only
bend GpuLibrary.bend --check-only
bend Tests.bend -o ../writ-build/tests.js
node ../writ-build/tests.js
CC=clang-19 bend Tests.bend -o ../writ-build/tests
../writ-build/tests +RTS --threads 4 --gpu off
bend PROOF.bend
```

Each complete test run should report **2226 passing checks** and
`ALL LIBRARY TESTS PASSED`. `PROOF.bend` checks thirty-six declared laws about guards,
preservation of denied state, grant issuance, host-contract denials, policy-aware audit, and executor rendezvous; it does
not prove the whole system secure.
An independent kernel check is a distinct command, `bend PROOF.bend --verdict`.
The [recorded verdict](../verification/lean-verdict-be649f6/README.md) passed at
source `be649f6` using a BendTT kernel built with Lean 4.34.0. Earlier Lean
startup failures remain recorded separately.

### Reproduce the Lean-built BendTT verdict

On Linux x86_64, the following recipe builds the unmodified BendTT kernel from
the pinned Bend distribution in a new directory outside the checkout, then
rechecks this checkout's `PROOF.bend`. It uses the official
[Lean 4.34.0 release](https://github.com/leanprover/lean4/releases/tag/v4.34.0)
and verifies the Linux archive's SHA-256 before extracting it. The archive is
about 580 MB; the extracted distribution used about 2.9 GiB on the recorded
host. The recipe needs Bash, `curl` (unless supplying an archive), `git`,
`realpath`, `cmp`, `grep`, `mktemp`, `cp`, GNU `tar`, `zstd`, `sha256sum`,
`timeout`, and a compatible Linux
x86_64/glibc environment. Run it from a clean Writ checkout. The pinned Bend
installation above is the default; set `WRIT_BEND_ROOT` to the extracted `bend/`
directory if it is elsewhere. To reuse a previously downloaded archive without
network access, set `WRIT_LEAN_ARCHIVE` to its path; its hash is still checked.
For the Nix package, `WRIT_BEND_ROOT="$(nix build --no-link --print-out-paths .#bend)/bend"`
names its packaged distribution. The locked Nix shell's ordinary `proofs`
check does not provide or run this verdict.

```bash
(
  set -euo pipefail
  writ_repo="$(realpath -e "$(git rev-parse --show-toplevel)")"
  writ_tmp_parent="$(realpath -e "${TMPDIR:-/tmp}")"
  case "$writ_tmp_parent/" in
    "$writ_repo/"*) printf 'TMPDIR must be outside the checkout\n' >&2; exit 1 ;;
  esac
  writ_bend_root="$(realpath -e "${WRIT_BEND_ROOT:-$HOME/.local/share/writ-toolchains/bend-2.0.39/bend}")"
  writ_bend_version="$(BEND_NO_TELEMETRY=1 "$writ_bend_root/bin/bend" version)"
  test "$writ_bend_version" = 'bend 2.0.39'
  writ_work="$(mktemp -d "$writ_tmp_parent/writ-bendtt.XXXXXXXX")"
  printf 'Working directory (retained): %s\n' "$writ_work"
  mkdir "$writ_work/tmp"
  export TMPDIR="$writ_work/tmp"
  printf '%s\n' "$writ_bend_version" > "$writ_work/bend-version.txt"
  git -C "$writ_repo" rev-parse HEAD > "$writ_work/source-commit.txt"
  git -C "$writ_repo" status --porcelain > "$writ_work/source-status.txt"
  test ! -s "$writ_work/source-status.txt"

  if [ -n "${WRIT_LEAN_ARCHIVE:-}" ]; then
    cp -- "$WRIT_LEAN_ARCHIVE" "$writ_work/lean.tar.zst"
  else
    curl --proto '=https' --tlsv1.2 -fL \
      https://github.com/leanprover/lean4/releases/download/v4.34.0/lean-4.34.0-linux.tar.zst \
      -o "$writ_work/lean.tar.zst"
  fi
  printf '%s  %s\n' \
    caaa98356098c85dc0fcbbd28e1ec66f39eb6551829972b752ff20e1286b646b \
    "$writ_work/lean.tar.zst" | sha256sum -c -
  tar --zstd -xf "$writ_work/lean.tar.zst" -C "$writ_work"
  writ_lean_bin="$writ_work/lean-4.34.0-linux/bin"
  writ_lean_version="$("$writ_lean_bin/lean" --version)"
  case "$writ_lean_version" in
    'Lean (version 4.34.0,'*) printf '%s\n' "$writ_lean_version" > "$writ_work/lean-version.txt" ;;
    *) printf 'Expected Lean 4.34.0, got: %s\n' "$writ_lean_version" >&2; exit 1 ;;
  esac
  mkdir "$writ_work/kernel"
  cp -- "$writ_bend_root/bend2/bendtt.lean" "$writ_work/kernel/bendtt.lean"
  printf '%s  %s\n' \
    d7268ff461de974bd4cd875d9766c71c62ee6b2e6411b9bab84839870db68a80 \
    "$writ_work/kernel/bendtt.lean" | sha256sum -c -
  (
    cd "$writ_work/kernel"
    timeout 1200 "$writ_lean_bin/lean" -c bendtt.c bendtt.lean
    timeout 1200 "$writ_lean_bin/leanc" -O3 -DNDEBUG bendtt.c -o bendtt
  )
  sha256sum "$writ_work/lean.tar.zst" "$writ_bend_root/bin/bend" \
    "$writ_lean_bin/lean" "$writ_lean_bin/leanc" \
    "$writ_work/kernel/bendtt.lean" "$writ_work/kernel/bendtt.c" \
    "$writ_work/kernel/bendtt" > "$writ_work/tool-hashes.txt"
  sha256sum "$writ_work/kernel/bendtt" > "$writ_work/kernel-before.txt"
  cd "$writ_repo"
  timeout 1200 env BEND_NO_TELEMETRY=1 BENDTT="$writ_work/kernel/bendtt" \
    LEAN_STACK_SIZE_KB=4194304 "$writ_bend_root/bin/bend" PROOF.bend --verdict \
    > "$writ_work/verdict.stdout" 2> "$writ_work/verdict.stderr"
  grep -Fxq 'ALL PROOFS CHECK' "$writ_work/verdict.stdout"

  if timeout 120 env BEND_NO_TELEMETRY=1 BENDTT=/bin/false \
    "$writ_bend_root/bin/bend" PROOF.bend --verdict \
    > "$writ_work/negative.stdout" 2> "$writ_work/negative.stderr"; then
    printf 'Negative control unexpectedly succeeded\n' >&2; exit 1
  else
    writ_negative_status=$?
  fi
  test "$writ_negative_status" -eq 1
  grep -Fxq 'Error: BendTT infrastructure: kernel exited 1 without a verdict' \
    "$writ_work/negative.stderr"
  if grep -Fxq 'ALL PROOFS CHECK' "$writ_work/negative.stdout" "$writ_work/negative.stderr"; then
    printf 'Negative control emitted a success verdict\n' >&2; exit 1
  else
    writ_grep_status=$?
    test "$writ_grep_status" -eq 1
  fi
  sha256sum "$writ_work/kernel/bendtt" > "$writ_work/kernel-after.txt"
  cmp -s "$writ_work/kernel-before.txt" "$writ_work/kernel-after.txt"
  git -C "$writ_repo" rev-parse HEAD > "$writ_work/source-commit-after.txt"
  git -C "$writ_repo" status --porcelain > "$writ_work/source-status-after.txt"
  cmp -s "$writ_work/source-commit.txt" "$writ_work/source-commit-after.txt"
  test ! -s "$writ_work/source-status-after.txt"
  printf 'Verdict passed; failing-kernel control exited %s. Records: %s\n' \
    "$writ_negative_status" "$writ_work"
)
```

Inspect the retained directory for source commit, clean status, versions,
hashes, and verdict/control output; delete it when no longer needed. Binary
hashes are observations and may differ with compiler or environment; the
archive and kernel-source hashes above are the pinned input checks. The clean
checkout and kernel hashes are observed before and after, not continuously
monitored or process attestation; ordinary Git status does not inspect ignored
files or external imported inputs. `WRIT_BEND_ROOT` must refer to a verified
pinned Bend distribution; the version and kernel-source checks alone do not
authenticate all of its files. The
`/bin/false` control checks that a failing selected executable is not accepted;
it is not a malformed-proof rejection test. `BENDTT` must point to the kernel
just built from the checked source, not an arbitrary executable that can print a
success line. This verdict covers only the laws in this checkout's proof driver
and their stated assumptions; it is not a proof of all Writ code, the compiler,
native confinement, durable recovery, or GPU execution. The compiler, Lean
toolchain, C compiler, runtime libraries and operating system remain trusted.
The [recipe validation record](../verification/lean-verdict-recipe-dd3dac9/README.md)
captures one fresh-checkout run and its failure-path checks.

To validate the specification structure, use OpenSpec **1.16.0** and the commands
in [openspec/README.md](../openspec/README.md). OpenSpec scenarios and executable
Bend tests are counted separately.
