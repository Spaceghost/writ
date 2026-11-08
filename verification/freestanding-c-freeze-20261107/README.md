# Freestanding input C generation, 2026-11-07

The freestanding plan needs identical generated Bend C as input to separate
hosted Linux and freestanding builds. On 2026-11-07 local time (2026-11-08
UTC), pinned Bend 2.0.39 emitted 13 C files from two isolated source revisions.
All emissions exited 0 with empty stdout and stderr. The generated files are
outside the source package under
`/home/jadams/tmp/writ-freestanding-freeze-20261107/outputs/`; the
[per-file hashes](generated-sha256.txt) identify the artifacts for subsequent
linking. They are local scratch artifacts: if removed, future work must
regenerate them and check the hashes rather than assume they are retained.

No generated file in this record was compiled, linked, or executed. There was
no QEMU or freestanding run, no runtime-symbol or effect-row review, and no
Linux-versus-freestanding comparison. Generated C alone proves neither runtime
compatibility nor host confinement, and no freestanding acceptance task is
completed here.

## Source and outputs

* Historical candidate source commit
  `28a10fefa09fc2250b65e24b01a65535765aba36`, tree
  `2e6b1dd9bd59bbb392fcefe80e07c679b753bbcd`: `Tests.bend` and
  `examples/{Flow,Transfer,Commit,Parallel}.bend`. This candidate was
  separately [reconstructed and run on hosted Linux](../freestanding-historical-638-20261107/README.md);
  its exact relationship to the original unrecorded worktree remains unproven.
* Current frozen source commit
  `bbaca70559efb72d6adc416874ad25db1786fe70`, tree
  `20e85ba8f75feac55ac4b9b81baf9e3f8e51e870`: `Tests.bend`,
  `scripts/runtime-profile/Hello.bend`, and
  `examples/{Flow,Transfer,Commit,Parallel,StageGraph,PlannerProposal}.bend`.
  This is a frozen input revision, not a claim that later revisions match it.

Both detached worktrees were clean before and after generation. The complete
tracked Bend-file inventories for [historical](historical-source-bend-sha256.txt)
and [current](current-source-bend-sha256.txt) were checked against the respective
worktrees after generation. The source commit and tree identify other tracked
inputs; the inventories are not claims about arbitrary untracked files.

## Generation and captures

`BEND_NO_TELEMETRY=1` and a task-specific `TMPDIR` under `~/tmp` were set;
core dumps were disabled. The script ran serially at nice 15 and used a
600-second timeout per program. Each command used the pinned `bend` executable
and the form `bend <source.bend> -o <output.c>`; exact command lines, per-input
start/end timestamps, exit codes, and raw stdout/stderr are preserved in
[generation-captures.tar.gz](generation-captures.tar.gz), SHA-256
`4ed71a6152a1402cd40deae8c48233c66863a69415b9a02a6832885c05e13ac4`.
The archive contains no generated C. The generated-file and source inventories
were rechecked successfully after emission.

The executable reported `bend 2.0.39` and SHA-256
`2ec160fa4486d33aff51e9eedcc294d6b531dc10c279c00b0c00685dae2045cd`.
The previously downloaded release archive SHA-256 was
`6cf462fd8f70b094a4950ebb709a9c4ffd8f1d1189d9cedf1fd63cd5d041c7ab`.
The [installed toolchain file inventory](bend-install-sha256.txt) was taken
after emission; it identifies the inspected installation at that point and
is not independent proof of its contents during generation.

The exact C files must be checked against the recorded hashes immediately
before use in each future build. Hosted Linux output, freestanding serial
output, build and link details, artifact identity, failure behavior, and
platform qualification all remain separate evidence gates.
