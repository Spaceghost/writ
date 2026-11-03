# Verification record

Verified on 2026-11-03 using **Bend 2.0.39**, Linux x86_64, and **clang 19.1.1**.
The final source package contains 28 authored `.bend` files. The implementation,
examples, test drivers, and proof declarations are all Bend 2.

## Executable checks

The final combined suite exits 0 and prints `ALL LIBRARY TESTS PASSED` on both
the emitted JavaScript backend under Node and a native Bend executable using
four CPU threads with GPU execution explicitly disabled.

| Suite | Checks | Main coverage |
| --- | ---: | --- |
| Core | 52 | Original graph verification, type intersection, exact 64-bit labels/effects, cycles, stamps, checked indexes, fuel exhaustion, forged candidates, actual sink effects |
| Transfer | 53 | Exact read/write pairing, source manifests, domains, object versions, code identity, schemas, inherited origins, payment scope, expiry |
| DLM | 47 | Owner-sensitive semantics, confidentiality/integrity duals, delegation closure, invalid authority, unknown principals, joins/meets, epochs |
| Ledger | 16 | Reservation, balance, exact receipt scope, stale revisions, replay, refund, expiry, malformed accounts |
| Negotiation | 26 | Stage ordering, candidate pinning, fresh challenges, sample permission, every-origin approval, reader expense, current budgets |
| Backplane | 40 | Combined checks, late revocation, metadata tampering, actual effects, combined labels, exact output types, artifact identity, duplicate-binding denial |
| Frontend | 70 | Mount/open/dup/attenuate/close protocol, subject/token/plan binding, all token words, current grants, descriptor revocation, malformed registries |
| Facade | 10 | Capability resolution through final commit, reader identity, revoked/closed/stale descriptors, no spending on denial |
| Property/oracle | 324 | Four oracle fixtures and 320 graph cases checked against both producers |
| **Total per backend** | **638** | **Both complete runs passed** |

The graph oracle computes four-node closure with Floyd–Warshall and derives
expected results directly from original seeds. It does not call the producer's
propagation/fold/sweep helpers. Its cases include all 256 subsets of eight fixed
directed edges, all 64 subsets of six undirected equality edges in the separate
conflict family, and bits 31, 32, and 63. Each case checks both the reference and
Bend parallel producer. This is finite executable coverage, not an exhaustive
proof for arbitrary graph sizes.

Evidence is in `verification/tests-js.txt` and `verification/tests-native.txt`.
The transfer test driver prints `PASS ` while other drivers print `PASS:`;
counting both forms yields 638 per file.

Reproduction:

```bash
bend Tests.bend -o tests.js
node tests.js
bend Tests.bend -o tests-native
./tests-native +RTS --threads 4 --gpu off
```

A native compiler arity limit encountered in a large test driver was resolved by
moving large cached fixtures into small helper functions. The final source and
both complete runs include that fix; the library's policy behavior was unchanged.

## GPU-directed source

`GpuLibrary.bend` exposes native device requests for the constraint solver, finite
DLM batches, and transfer batches. `GpuExample.bend` was typechecked, emitted as
native C by Bend, built as a native executable, and run using the CPU fallback.
The generated source contains **`#define BANGS 3`**, confirming all three device
entry points survive Bend lowering.

The example reports:

```text
Independent constraint verification: True
Label batch matches host replay: True
Batch with missing read grant denied: True
```

See `verification/gpu-codegen.txt`, `gpu-example-js.txt`, and
`gpu-example-native.txt` for the captured outputs. The generated C itself is an
intermediate compiler artifact and is not authored library source.

**No physical GPU execution, CUDA/Metal device compilation, performance claim,
or device isolation claim was validated.** This environment had no `/dev/nvidia0`,
no `/dev/dri`, and no CUDA toolkit. Native tests used `--gpu off`. Bend's `!`
can fall back to CPU execution; success does not establish the physical backend.

## Explicit proof scope

`bend PROOF.bend` prints `ALL PROOFS CHECK` for three declared laws:

1. A false guard at any position in a sequence makes the full guard false.
2. A denied selector returns the original state.
3. A denied ledger result preserves the original ledger state.

These laws are in `LAWS.bend`, with implementations in `PROOF.bend`. They are
selected guard/state laws, not a proof of noninterference, whole-program
dependency completeness, cryptographic authentication, the compiler, or the OS.
No project source declares unsafe code, foreign code, or a proof hole.

The independent `--verdict` check **did not run successfully**. The official Lean
4.34.0 release archive was downloaded and hash-verified, but its executable exits
before kernel compilation with `error: failed to locate application`. Supported
path settings did not resolve that startup problem. No checker, compiler, or law
was changed to bypass it. See `verification/kernel-verdict.txt` and `proofs.txt`.

## OpenSpec suite

The repository includes 13 baseline capability specs and 10 pending change
packages. OpenSpec 1.16.0 strict validation passed all 23 items with no errors or
warnings. Baseline specifications contain 135 requirements and 297 scenarios;
pending deltas contain 81 requirements and 121 scenarios. All 87 implementation
tasks remain unchecked. See `verification/openspec-validation.txt`.

This is specification validation, not execution of every acceptance scenario.
Traceability tables distinguish named executable tests from source review and
host preconditions. All 28 Bend files remain byte-identical to the earlier native
test record; the JavaScript suite and ordinary proof checks also passed again
from the Writ repository layout.

## Model boundaries

Passing tests does not authenticate a caller-supplied Context, Session, Capability,
Binding, graph, or ledger. Those must remain monitor-owned state. The code verifies
relationships among the supplied authoritative facts; it does not discover the
complete source manifest from arbitrary code, compute an artifact digest, or
prove the bytes were produced by the pinned execution.

The character-device interface is a pure protocol model. Durable atomic state
updates, real payload writes, syscall/process/device confinement, actual payments,
and external-language execution remain adapter work. The write adapter must expose
only the sealed artifact identified in the accepted intent.

## Toolchain and package facts

`verification/environment.txt` records the compiler, native compiler, execution
mode, source count, and observed device availability. The verified official
Bend Linux x64 2.0.39 archive had SHA-256:

```text
6cf462fd8f70b094a4950ebb709a9c4ffd8f1d1189d9cedf1fd63cd5d041c7ab
```

`verification/source-sha256.txt` binds the final authored source and documentation
to this test record. Native binaries, upstream toolchains, generated C/JavaScript,
and unrelated prototypes are excluded from the repository.
