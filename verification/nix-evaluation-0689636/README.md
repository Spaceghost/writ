# Bounded Nix JavaScript-check evaluation at 0689636

The current suite contains 2,281 synthetic library checks. The Nix JavaScript
check should reject a missing check or success sentinel. On a clean isolated
checkout of exact source `0689636350d49aac3a25379ece312e3f5dd2ab35`, Nix
2.35.2 evaluated that check and its filtered source. **The Nix check itself was
not built or run**, and no full flake check, native host qualification or GPU
test is claimed.

## Evaluation and dry run

These commands were run in `/tmp/writ-nix-master-0689636`; stdout, stderr and
exit values are retained separately. The [source commit](source-commit.txt)
and empty [Git status](source-status-before.txt) were captured locally alongside
the retained reruns; Git status was also checked before the initial evaluation.

```sh
timeout 90s nix eval --offline --no-write-lock-file --raw \
  .#checks.x86_64-linux.tests-js.drvPath
timeout 60s nix build --offline --no-link --dry-run \
  .#checks.x86_64-linux.tests-js
```

The [evaluation](eval.stdout) [exited 0](eval.exit), yielding
`/nix/store/jig50k55ai8rzihrxa4c8ng7v4j4hx79-writ-tests-js.drv`;
[stderr](eval.stderr) notes a concurrent local Nix fetch lock. The
[dry run](dry-run.stderr) [exited 0](dry-run.exit) and reported 344
uncached derivations to build, including LLVM/Clang and a GCC bootstrap.
Its [stdout](dry-run.stdout) was empty. A dry run lists planned work; it
does not build or establish that offline inputs are sufficient. We did not
start this closure because it was not a bounded, non-disruptive check.

`nix derivation show /nix/store/jig50k55ai8rzihrxa4c8ng7v4j4hx79-writ-tests-js.drv`
produced the retained [derivation JSON](derivation.json). Its `buildCommand`
uses the filtered source
`/nix/store/7kxkq1ya23w32zrvji14lvf84q8yjz8d-source`, invokes `bend
Tests.bend`, checks the producer exit, requires exactly 2,281 lines beginning
`PASS`, requires the final success sentinel and writes the log to the output.
Its output store path was not built by this work.

The filtered store source contained 80 Bend files and no non-Bend files. Their
[individual SHA-256 values](filtered-source.sha256) were independently compared
byte-for-byte with this commit's Git blobs; they include `Tests.bend`,
`HostBindingTests.bend` and `PlannerEnvelopeTests.bend`. Of the 110
[tracked Bend files](tracked-bend.sha256), the other 30 are
[excluded by the filter](filtered-source-excluded.txt). These are local
observations, not process attestation or evidence that the unbuilt derivation
executed. Git status does not prove ignored files were absent.

## Local controls on the evaluated gate

The shell block from `last=$(tail ...)` through the end of the two assertions
was copied from the evaluated `buildCommand` to
[`/tmp/writ-nix-0689636-assert.sh`](assert.sh.txt), with `set -e` prepended
and a trailing blank line removed. A local Python control
([exact body](gate-control.py.txt)) ran that block under Bash against the
[previously retained combined Bend output](../planner-order-binding-combined/bend.log),
then with one `PASS` line removed, then with the success sentinel removed.
Its [output](gate-check.txt) records exit 0, 1 and 1 respectively. Replaying
the retained control produced the same output and exit 0 for the control
script itself.

This tests only the extracted count/sentinel code against those three local
inputs. It does not execute the derivation, validate all possible outputs or
replace Nix's source, toolchain and sandbox build. The prior combined Bend,
Node, CPU and Lean verdict records retain their original source and scope.

## Direct run from the filtered store source

As a separate local observation, the pinned Bend 2.0.39 binary (SHA-256
`2ec160fa4486d33aff51e9eedcc294d6b531dc10c279c00b0c00685dae2045cd`)
ran the JavaScript suite from the evaluated filtered source, without executing
the Nix derivation. The command used bubblewrap 0.13.0 (binary SHA-256
`d9498f8b15b1c69e09791badee317d56f33abd359a306d6e96534f136381ad74`):

```sh
timeout 120s bwrap --unshare-net --ro-bind / / --dev-bind /dev /dev --proc /proc \
  --bind /tmp/writ-nix-filtered-js-0689636 /tmp/writ-nix-filtered-js-0689636 \
  --chdir /nix/store/7kxkq1ya23w32zrvji14lvf84q8yjz8d-source \
  /usr/bin/env TMPDIR=/tmp/writ-nix-filtered-js-0689636 BEND_NO_TELEMETRY=1 \
  /home/jadams/.local/share/writ-toolchains/bend-2.0.39/bend/bin/bend Tests.bend
```

The existing `HOME` was not changed; the filesystem view, including the home
directory and store, was read-only except for the separately created temporary
directory and the `/dev` and `/proc` mounts. The run [exited 0](filtered-run.exit),
with [empty stderr](filtered-run.stderr), 2,281 PASS lines and the final
sentinel. Its [stdout](filtered-run.stdout) is byte-identical to the prior
combined-suite capture, SHA-256
`b03250033ffabd8297d21375614e7e356a866548a2f0a23512178fc5adeb1248`.
All 80 filtered input hashes [matched again afterward](filtered-source-after.log).
These are local observations, not process attestation. The run used a local
compiler and a separately configured sandbox; it is **not** a Nix derivation
build, a full flake check, a native host test or a GPU test.
