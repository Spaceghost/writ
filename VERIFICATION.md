# Verification record

Verified on 2026-11-03 using **Bend 2.0.39**, Linux x86_64, and **clang 19.1.1**.
The final source package contains 34 authored `.bend` files. The implementation,
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
mkdir -p ../writ-build
bend Tests.bend -o ../writ-build/tests.js
node ../writ-build/tests.js
bend Tests.bend -o ../writ-build/tests-native
../writ-build/tests-native +RTS --threads 4 --gpu off
```

A native compiler arity limit encountered in a large test driver was resolved by
moving large cached fixtures into small helper functions. The final source and
both complete runs include that fix; the library's policy behavior was unchanged.

## Runnable examples and cleanup review

The four examples are ordinary library clients with named synthetic monitor
records. They do not import the test suite. Each assertion fails the process
when its expected outcome changes; the examples are not just printed booleans.

| Example | Assertions per backend | Main demonstration |
| --- | ---: | --- |
| `examples/Flow.bend` | 4 | Internal flow permitted, public flow denied, derived-label forgery rejected |
| `examples/Transfer.bend` | 4 | Exact paired grants and complete retained origin policy |
| `examples/Commit.bend` | 16 | Guarded negotiation, mount/open, final commit, and exact state preservation after revocation |
| `examples/Parallel.bend` | 5 | Three device-requesting paths with explicit allow/deny outcomes and host checks |
| **Total** | **29** | **Separate from the 638-check library suite** |

All four were run through Bend's JavaScript runner and compiled as native
executables, then run with four CPU threads and `--gpu off`. Their outputs match
across those backends. The root `Example.bend` and `GpuExample.bend` wrappers were
also run; their duplicate assertions are not counted again. See
[examples-js.txt](verification/examples-js.txt),
[examples-native.txt](verification/examples-native.txt), and the
[example guide](examples/README.md).

The cleanup added comments to 13 runtime modules. Comparing each against revision
`03efcc6361528c17773bc04c1c62c553da728209` after removing only full-line comments and
blank lines gives identical implementation lines. Existing test drivers and proof
declarations are byte-identical to that revision. Both complete test suites and
ordinary proof checks were rerun against the current tree. The comparison record
is in [cleanup-review.txt](verification/cleanup-review.txt).

## GPU-directed source

`GpuLibrary.bend` exposes native device requests for the constraint solver, finite
DLM batches, and transfer batches. `GpuExample.bend` was typechecked, emitted as
native C by Bend, built as a native executable, and run using the CPU fallback.
The generated source contains **`#define BANGS 3`**, confirming all three device
entry points survive Bend lowering.

The example reports:

```text
PASS solver path passes original-graph verifier: True
PASS label path allows internal and denies public: True
PASS label path matches complete host replay: True
PASS transfer path admits paired grants and denies missing read: True
PASS host transfer replay preserves both outcomes and provenance: True
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
host preconditions. The documentation cleanup does not complete any proposed
adapter task or expand the scope of the selected formal laws.

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
