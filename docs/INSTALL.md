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
binary with `+RTS --threads 4 --gpu off` (`tests-native`), requiring 2285 lines
beginning with `PASS` and the final line `ALL LIBRARY TESTS PASSED`; it runs
`bend PROOF.bend` and requires `ALL PROOFS CHECK` (`proofs`, without
`--verdict`); and it runs `openspec validate --all --strict --no-interactive`
over `openspec/` (`openspec`). The 2285-check integration preview passed the
offline Nix JavaScript check; its Nix native and full flake checks have not
been rerun. The 2065-check Nix JavaScript check passed for
source `73a8055`; the Nix native CPU check also passed with the same output.
The [combined flake check](../verification/nix-combined-flake-check.log) passed
all checks with evidence-only files staged. The historical artifacts below cover the previous
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

Each complete test run should report **2285 passing checks** and
`ALL LIBRARY TESTS PASSED`. `PROOF.bend` checks thirty-six declared laws about guards,
preservation of denied state, grant issuance, host-contract denials, policy-aware audit, and executor rendezvous; it does
not prove the whole system secure.
An independent kernel check is a distinct command, `bend PROOF.bend --verdict`.
The recorded Lean 4.34.0 installation could not start, so that result remains
unverified. See the [verification record](../VERIFICATION.md).

To validate the specification structure, use OpenSpec **1.16.0** and the commands
in [openspec/README.md](../openspec/README.md). OpenSpec scenarios and executable
Bend tests are counted separately.
