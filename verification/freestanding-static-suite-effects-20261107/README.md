# Hosted static-suite effect-symbol checks, 2026-11-07

The existing runtime-profile binary checker inspected two previously built
static hosted Linux suite binaries on 2026-11-07 local time (2026-11-08 UTC).
Both checks exited 0, reported `IO.print` as the effect row, and explicitly
reported that the host-symbol surface was not checked. This is symbol-table
inspection of hosted binaries; neither binary was executed by this check.
It is not a freestanding image check or host-qualification evidence.

## Inputs and observed results

| Hosted binary | Build | SHA-256 | Checker capture | Exit |
| --- | --- | --- | --- | ---: |
| Historical suite | static clang `-O2` | `4fb1c6d9f594aa97097c4f1ef4835517c90ea6d8b07f5ff453fc83cee67fcf88` | [stdout](historical-check.stdout), [stderr](historical-check.stderr), [status](historical-check.exit) | 0 |
| Current suite | static clang `-O0` | `2b2653b2234aab3fe2778711f5365b29c8ae338f81fad54a65d0c3ef1c47d01f` | [stdout](current-check.stdout), [stderr](current-check.stderr), [status](current-check.exit) | 0 |

The historical binary and its source C are identified by the [hosted C
record](../freestanding-hosted-c-20261107/README.md); the current binary and
its source C are identified by the [exploratory `-O0` record](../freestanding-hosted-o0-20261107/README.md).
Each binary matched its recorded hash before and after the check. The current
`-O0` C expansion disables the `PRESERVE` calling-convention attributes that
this clang enables at `-O2`; the two binary checks do not establish equivalent
ABIs or replace the current `-O2` build attempts, which failed or timed out.

The checker and its two allowlists were copied directly from source commit
`f786ece59e62437cfd925847f4de3a7603fee8c1`; their
[SHA-256 values](checker-sha256.txt) identify the copies in the capture
archive. The checker uses `nm`/`readelf` and an effect-name mapping over symbol
names; it does not directly prove all runtime reachability or behavior. Its
output calls the inferred names effect rows. For a static binary it skips
undefined-symbol comparison because libc is resolved into the binary. A pass
therefore checks the tool's effect-symbol criteria only; it says nothing about
the full host-symbol surface or whether a freestanding implementation supplies
correct host behavior.

## Execution boundary

Checks ran serially at nice 15 with 300-second wall/CPU limits, 2 GiB virtual
memory, bounded file size and core dumps disabled. Both available-memory
preflights exceeded the 40 GiB minimum. GNU `nm` and `readelf` reported version
2.47. Exact commands, checker and allowlist copies, timestamps, preflight
results, raw stdout/stderr/status and before/after hashes are preserved in
[captures.tar.gz](captures.tar.gz), SHA-256
`0f18481c4b881720d4f1ce974d615a94ad9f9a2551e6681717bfa70ec2fb400a`.
The archive contains neither executable binaries nor generated backend C.

Neither result checks the effect rows of a future freestanding image, validates
its link map or host symbols, demonstrates GPU execution, or completes task 2.4.
The future freestanding binary and its independently reviewed host dependency
inventory remain required.
