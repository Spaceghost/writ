# Hosted frozen-C example references, 2026-11-07

The [C freeze](../freestanding-c-freeze-20261107/README.md) contains four
historical example C files and six from a later source revision. On 2026-11-07
local time (2026-11-08 UTC), each was separately built as a static hosted Linux
program and run single-lane with GPU disabled. All ten builds and runs exited
0 with empty stderr, and every complete stdout matched its identified expected
output byte for byte. The historical examples had 29 PASS assertions in total;
the current examples had 37. This is hosted CPU execution, not a freestanding
comparison, GPU test or host qualification.

## Inputs, captures and comparisons

Each input C matched the [committed freeze inventory](input-sha256.txt) before
and after its build; all 13 frozen C files matched that inventory again after
the batch. Historical inputs came from source
`28a10fefa09fc2250b65e24b01a65535765aba36`; current inputs came from
`bbaca70559efb72d6adc416874ad25db1786fe70`. The three historical/current
Flow, Transfer and Parallel C pairs have equal hashes, but were separately
built and run; Commit C differs between revisions.

| Source | Example | PASS | Captured stdout |
| --- | --- | ---: | --- |
| Historical | Flow | 4 | [Flow](historical/Flow.stdout) |
| Historical | Transfer | 4 | [Transfer](historical/Transfer.stdout) |
| Historical | Commit | 16 | [Commit](historical/Commit.stdout) |
| Historical | Parallel | 5 | [Parallel](historical/Parallel.stdout) |
| Current | Flow | 4 | [Flow](current/Flow.stdout) |
| Current | Transfer | 4 | [Transfer](current/Transfer.stdout) |
| Current | Commit | 16 | [Commit](current/Commit.stdout) |
| Current | Parallel | 5 | [Parallel](current/Parallel.stdout) |
| Current | StageGraph | 3 | [StageGraph](current/StageGraph.stdout) |
| Current | PlannerProposal | 5 | [PlannerProposal](current/PlannerProposal.stdout) |

The four historical expected stdout files came from commit `810e8ee`'s
[reconstructed historical run](../freestanding-historical-638-20261107/README.md),
which had separately matched the original captured output. The exact original
worktree's provenance is still unproven. The six current expected outputs were
extracted in order from the `Captured output` blocks in commit `bbaca70`'s
`examples/README.md`; the source README SHA-256 was
`603dc87c3154f21ba8f86e329c75881dbf47775b05bb703347896a5682e517ad`.
Their [expected hashes](expected-sha256.txt) include StageGraph
`d3167692ac49a8051c177469d1a1947bcdb0fceb849da4ba6c9aab1dac57ad55` and
PlannerProposal `ba86437fc4749f6228d538dfdc8a270ca957c9f47ce2fccad6af49d7b83eb2bf`,
matching the respective earlier [stage graph](../stage-graph/README.md) and
[planner proposal](../planner-proposal-example/README.md) records. Every
`cmp` against the relevant expected output exited 0. Output equality does not
make the separate source revisions identical or establish host authority.

## Commands and resource boundary

Every build used `clang -std=c11 -O2 -static <example.c> -o <binary> -lpthread
-lm`; every run used `<binary> +RTS --threads 1 --gpu off`. These custom hosted
flags match the prior [hosted C reference](../freestanding-hosted-c-20261107/README.md),
and are not a claim that these binaries equal Bend's own native builds.

Builds and runs were serial at nice 15, with 300-second wall and CPU limits,
8 GiB virtual memory per build, 20 GiB virtual memory per run for Bend's
reservations, bounded file size, and core dumps disabled. `BENDRTS` was unset.
Before every build and run, an available-memory preflight required at least
40 GiB; all 20 checks passed, and the smallest recorded `MemAvailable` was
84,294,244 KiB. No resource stop or retry occurred.

The [capture archive](captures.tar.gz), SHA-256
`d8ab01f86464efd4489a2fcf45d20842da69b2800d3b35deee38b000e53d4520`,
retains the exact commands, timestamps, preflights, source and expected-output
hashes, extraction script, compiler and environment, per-program build/run
stdout and stderr, statuses, comparisons and binary hashes. It contains no
native binaries or generated C; those remain outside the source package under
`~/tmp`. These hosted outputs are inputs for future comparison with a
freestanding implementation. No freestanding image was built or run here,
and task 2.1 remains open.
