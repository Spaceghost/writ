# Reconstructed historical Linux corpus, 2026-11-07

The freestanding plan needs a reproducible Linux reference for the older
638-check corpus. This is a hosted Linux CPU rerun of a reconstructed historical
source revision; it does not run a freestanding image or qualify a host.
Freestanding FR-005 and task 2.1 remain unchecked.

## Input identification and limits

The detached worktree was clean at commit
`28a10fefa09fc2250b65e24b01a65535765aba36`, tree
`2e6b1dd9bd59bbb392fcefe80e07c679b753bbcd`. That commit introduced the original
[runtime-profile captures](../runtime-profile-parity.txt) and changes only
those five capture files from its parent `1afb90ad9e7642daac7218800f60b3d1d681b7ff`.
Its tracked Bend files are hashed in [source-bend-sha256.txt](source-bend-sha256.txt).
The original record does not identify its source revision or exclude
uncommitted modifications at the time, so this candidate's reproduction does
not prove the original worktree's exact provenance.

The original record describes four teaching examples (`examples/Flow.bend`,
`Transfer.bend`, `Commit.bend`, and `Parallel.bend`) and reports 29 assertions
in total. The later Genode and Unikraft corpus records named other entry
points; they do not replace these four historical captures.

## Commands and result

Environment, executable hash, release-archive hash, compiler, and kernel are
in [environment.txt](environment.txt). `BEND_NO_TELEMETRY=1` and a task-specific
`TMPDIR` on MediaVolume were set; core dumps were disabled. Each command had a
600-second timeout. The build was lowered to nice 15 while running; the source
worktree and all binaries and temporary files were outside the current checkout.

```text
bend Tests.bend -o /mnt/MediaVolume/Media/writ-freestanding-baseline-build/Tests
/mnt/MediaVolume/Media/writ-freestanding-baseline-build/Tests +RTS --threads 1 --gpu off
```

Build exit: 0; [stdout](build.stdout) and [stderr](build.stderr) were empty.
Run exit: 0; [stderr](tests.stderr) was empty. The complete [run stdout](tests.stdout)
has 638 lines matching `^PASS[: ]` and ends `ALL LIBRARY TESTS PASSED`. Its
SHA-256 is `4c541b0077cea099fc568fab8a5c5b8c8a3c46462781903cc26828e4049e95e0`.
`cmp -s` against [the original single-lane capture](../runtime-profile-parity-1.txt)
exited 0; the bytes match. The rerun binary SHA-256 is
`f484c63158a8f05d3d97ef5fbdb7887e67c822ee1957642d9ebebaddc559b0e2`;
it differs from the original record's binary hash, and no byte-reproducible
binary claim is made. The historic worktree was clean after the run.

The four examples were built and run serially with the same environment,
timeout, lane count, and GPU setting, using `bend examples/<name>.bend -o
/mnt/MediaVolume/Media/writ-freestanding-baseline-build/<name>` followed by
the resulting binary with `+RTS --threads 1 --gpu off`. Each build and run
exited 0 and each build and run stderr was empty; the captured build stdout
files are also empty. The individual run stdout files follow:

| Example | PASS | Run stdout | Binary SHA-256 |
| --- | ---: | --- | --- |
| Flow | 4 | [Flow.stdout](Flow.stdout) | `aab9116bda360de6957ad1b03a0c4443e1784896ac38023c5ea370243428727f` |
| Transfer | 4 | [Transfer.stdout](Transfer.stdout) | `d5c50761326063212892d1c31da46ce219383b42b6e3f531bad2d3b35cff2030` |
| Commit | 16 | [Commit.stdout](Commit.stdout) | `2a5b8a384b97ab4d07e9e715c431685e6ee105101ca4bcb586c05ad1b4d9bdb5` |
| Parallel | 5 | [Parallel.stdout](Parallel.stdout) | `d8ca3bb026c834ba41d47cb3341133e37d9b4556e9f634664bb1e7c7be980ca5` |

Each stdout matched its section of the original single-lane example capture.
A combined capture, reconstructed from these raw outputs with the original
file headers and actual exit statuses, also matched the [original](../runtime-profile-parity-examples-1.txt)
with `cmp -s` exit 0; its SHA-256 is
`3ffb55bbbd3af78f262b5b3dc7145e9b6c0ef9839b2f027605745840c9f58d5b`.
The four binary hashes match those in the original record; the parallel
example ran on CPU with GPU disabled, despite its GPU-facing paths.

This result is one hosted Linux single-lane CPU execution using the pinned
Bend 2.0.39 release; it establishes no GPU execution, emulated or physical
kernel boot, host isolation, or freestanding parity. Generated C identity and
a full frozen current-revision corpus remain future work.
