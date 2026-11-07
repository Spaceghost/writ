# Locality filtered-source check at 75e8818

The isolated checkout was at `75e8818cb1c174ee863ba71df2fcd58eb19dec7b`
([source identity](source-commit.txt), [initial status](source-status-before.txt)).
The tests below are local observations of the Nix JavaScript check's filtered
source and its evaluated gate. **They are not a Nix derivation build or a full
flake check.** No dependency closure was built, and no native host or GPU
qualification is claimed.

## Offline evaluation

With Nix 2.35.2, the following evaluated the existing flake without updating its
lock file or fetching sources:

```sh
timeout 90s nix eval --offline --no-write-lock-file --raw \
  .#checks.x86_64-linux.tests-js.drvPath
timeout 30s nix derivation show /nix/store/pp4pa4px020ddj1y5s8bsr15mpnz4v90-writ-tests-js.drv
```

The [evaluation](eval.stdout) and [derivation inspection](derivation.json)
exited 0 ([eval exit](eval.exit), [inspection exit](derivation.exit)); their
stderr captures are retained. The evaluated derivation names the filtered source
`/nix/store/yjl2wrjpgvxp2rifa4pcba33afxgv7b7-source`, runs `bend Tests.bend`,
checks the producer status, requires 2,318 `PASS` lines and the final
`ALL LIBRARY TESTS PASSED` sentinel. Inspection of a derivation does not execute
those commands. Unlike the earlier [2,281-check evaluation and dry run](../nix-evaluation-0689636/README.md),
this record does not claim a dry run or a count of uncached derivations.

The evaluated source contained [82 Bend files](filtered-source.sha256) and no
other files. Their hashes were independently compared with the exact Git blobs
at `75e8818`; the [30 excluded tracked Bend paths](filtered-source-excluded.txt)
and [counts](filtered-source-counts.txt) are recorded. All 82 matched again
[after the run](filtered-source-after.exit). The complete tracked set is the
[112-file Bend inventory](../locality-conjunction/bend-inputs.sha256). This
comparison establishes file content, not process attestation or complete host
qualification.

## Direct filtered-source run

The pinned Bend 2.0.39 binary (SHA-256
`2ec160fa4486d33aff51e9eedcc294d6b531dc10c279c00b0c00685dae2045cd`)
ran its JavaScript suite directly from the evaluated store source using
bubblewrap (binary SHA-256
`d9498f8b15b1c69e09791badee317d56f33abd359a306d6e96534f136381ad74`):

```sh
timeout 120s bwrap --unshare-net --ro-bind / / --dev-bind /dev /dev --proc /proc \
  --bind /tmp/writ-locality-filtered-run.q6qRA9LP /tmp/writ-locality-filtered-run.q6qRA9LP \
  --chdir /nix/store/yjl2wrjpgvxp2rifa4pcba33afxgv7b7-source \
  /usr/bin/env TMPDIR=/tmp/writ-locality-filtered-run.q6qRA9LP BEND_NO_TELEMETRY=1 \
  /home/jadams/.local/share/writ-toolchains/bend-2.0.39/bend/bin/bend Tests.bend
```

`HOME` was not changed. The filesystem view, including home and the store, was
read-only except for the new temporary directory and `/dev` and `/proc` mounts;
network was unshared. The run [exited 0](filtered-run.exit), with
[empty stderr](filtered-run.stderr), 2,318 PASS lines and the final sentinel.
Its [stdout](filtered-run.stdout) is byte-identical to the prior
[local Bend suite](../locality-conjunction/bend.log), SHA-256
`e87d601d12b49d85bc45d20f2b59ca1d7ece694cc1828b7f21d4713be3f9ad50`.
It used the local compiler and this separately configured sandbox; it did not
run the Nix derivation, its count gate, its pinned build environment, or its
native check. The model's rules and domain IDs remain unauthenticated synthetic
descriptions, and the locality acceptance tasks remain open.
