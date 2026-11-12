# Durable security protocol verification

Source base: `414f91a6` (the lane began at `236bfb81`). The captured
`model-source-sha256.txt` identifies the delivered Bend sources, including
the focused regression driver. The repository-wide manifest covers all
delivered tracked files. Generated C, binaries and diagnostic tool copies are
outside the source package.

Pinned Bend 2.0.39, ordinary checking and JavaScript execution:

```sh
bend Tests.bend > core-js.txt 2>&1
python3 utils/verification/check_core.py core-js.txt
bend PROOF.bend > proof.txt 2>&1
```

All 3,220 core checks passed, including 84 new durable-protocol checks. The
process exited zero and the output checker accepted the reviewed count and
final marker. Five new ordinary laws cover unknown outcomes, blocked new
preparations, unconfirmed retries and failed restoration. The ordinary proof
check passed. No independent Lean kernel verdict or physical GPU run was
performed for this tree.

Focused native CPU regression:

```sh
bend DurableSecurityTests.bend -o security-final.c
gcc -std=c11 -O0 security-final.c -lpthread -lm -o security-final
./security-final +RTS --threads 1 --gpu off > security-native.txt 2>&1
```

GCC 16.2.1 compiled the original pinned compiler's output. All 585 checks
passed: 216 existing host primitives, 285 existing audit checks, and 84 new
durable-publication checks. Emission, compilation and execution each exited
zero. The log contains exactly 585 PASS records, no failure records and one
final success marker. `native-generated-sha256.txt` identifies the generated
C and executable. This focused run is separate from the complete JavaScript
corpus; it is not a new full monolithic native-core run.

Earlier native emission failed at Bend's 247-word continuation limit.
Diagnostics identified wide fixture and protocol records held simultaneously.
Pending state now retains its prior Idle state in a boxed recursive
representation; the bounded receiver log is boxed too. Guard helpers project
one field at a time, and tests use smaller calls. Invalid predecessor and
over-capacity receiver forms are refused and tested. A temporary compiler copy
only added segment names to the diagnostic; none of its output is used for
verification. Final emission and execution above used unmodified Bend 2.0.39.

OpenSpec 1.16.0 strict validation passed all 50 items. Review findings and their
resolutions are retained in the [work record](../../docs/superpowers/records/2026-11-11-security-milestone/task-1-review.md).

These are synthetic monitor, storage, witness and receiver facts. They do not
establish authenticated storage, real crash recovery, external receiver
idempotency, legal admissibility, a cryptographic history chain, or protected
Windows confinement. The ordinary desktop/S3 preview is not upgraded to a
corporate security profile. [Native acceptance remains pending](../../openspec/traceability/durable-publication.md).
