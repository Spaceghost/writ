# Ledger Nat-boundary regressions

A stale reservation at revision `281474976710655` previously aborted with a
Nat overflow instead of returning its unchanged ledger. The same eager
successor construction affected all four transitions. A structurally valid
supplied state with a maximum available balance and a positive held amount also
made cancellation and expiry overflow while constructing a provisional refund,
including on a stale request. Such a refund state cannot arise from a fixed
in-range initial balance through these ledger transitions alone, but `valid`
accepts supplied snapshots. See the [ledger contract](../../openspec/specs/reservation-ledger/spec.md)
and [traceability](../../openspec/traceability/reservation-ledger.md).

The pinned Bend runtime supports Nat values through 2^48−1. A mutation at the
terminal revision rejects unchanged; the preceding revision can still advance
to that terminal value. A refund exceeding the maximum rejects unchanged, while
exact-fit refunds, including maximum plus zero, remain eligible. The arithmetic
helpers return provisional numbers, not authority. The exported `.allowed`
implementation steps require the Boolean produced by the corresponding bound
check; calling those internal steps with a forged Boolean is outside their
precondition and can overflow. Public state remains forgeable data, and the host
must authenticate, serialize and persist the current state before effects.

The [25 boundary tests](../../LedgerBoundaryTests.bend) compare all fields of
rejected states and exercise stale and current requests for each transition at
the maximum, final successful increments, positive overflow, exact-fit and zero
refunds. The 2,381-check root suite passed in [Bend](bend.log) and
[generated Node](node.log), identical with SHA-256
`26f1b8bc6cc92cc8c8a0f15ce733b97e3bbc5a0fb603f33435c47219837bd8ae`.
The [existing-law Lean verdict](proof.log) passed; it adds no new law or proof
of these boundary cases. The [input inventory](bend-inputs.sha256) records 121
Bend source hashes. Bend and Node were repeated after the final comment
clarification and produced the same logs. The original test/proof/native inputs
used [the preceding inventory](bend-inputs-native.sha256); its only difference
from the delivered inventory is a Ledger comment clarification, with all
non-comment lines byte-identical as [recorded](comment-comparison.txt). The
native build began before the change and before the evidence commit; the hashes
are observations rather than process attestation. The pinned Bend executable and Lean kernel hashes were
`2ec160fa4486d33aff51e9eedcc294d6b531dc10c279c00b0c00685dae2045cd` and
`e365eba1741602bb45261aa0eb6bd2c6f5db885d4b9d4cd603a27bc3c5a9ed18`.

The [original ledger Bend](baseline-bend.log) and [Node](baseline-node.log)
runs failed on the first stale maximum-revision reservation. For that baseline
only, the new test's reference to the new `max_nat` helper was replaced with a
positive parsed-number check; all other boundary checks were unchanged. Four
isolated source mutations and their Bend/Node logs are retained here:

- `successor-unsafe` removes the staged successor guard and crashes at stale max.
- `add-unsafe` removes the staged addition guard and crashes on stale refund.
- `successor-gate` removes the terminal admission condition and fails a current
  maximum-revision refusal check.
- `refund-gate` removes both headroom admission conditions and fails an
  overflowing cancellation refusal check.

Each [zero-context patch](successor-unsafe.patch.txt) and corresponding named
`.patch.txt` file describes only its selected mutation. All eight focused
mutant runs exited nonzero; the overflow mutants are runtime failures, not
proof-kernel rejections. Generated JavaScript and native binaries stay outside
the checkout.

The separately built [optimized native CPU suite](native.log) also passed all
2,381 checks, byte-identical to Bend and Node, with `+RTS --threads 1 --gpu off
-RTS`. Build and run both exited 0; [build stdout](native-build.log),
[build stderr](native-build.stderr) and [run stderr](native.stderr) are empty.
An [observed compiler command](native-clang-observation.txt) used `-O3`, which
is not process attestation. The build started against the pre-comment inventory
before source commit `a87b38d`; the only later Bend input difference is the
comment clarification described above. No GPU execution is claimed.

The separately run [allocator test](allocator.log) passed 24 checks with
ASan/UBSan, and the [owned-temp synthetic pair handoff](handoff.log) passed its
capture-to-Bend/Node controls. Neither exercises a ledger host integration.
There is no protected-host, Linux identity, GPU, or durable recovery claim.
The numeric repair covers Ledger's four transitions only: session revision
exhaustion and any other modules' numeric boundaries require separate review.
