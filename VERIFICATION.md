# Verification record

Core regression rerun on 2026-11-04 using **Bend 2.0.39**, Linux x86_64, and
**clang 19.1.1**. Earlier example/platform evidence is scoped below. The
HostBinding suite and its final-review fix wave were rerun on 2026-11-03 with
Bend 2.0.39, **clang 23.1.1**, and Node v26.10.0, as recorded in the HostBinding
rows below.
The core and examples contain 36 authored `.bend` files (34 originally verified,
plus `HostBinding.bend` and `HostBindingTests.bend`). Their implementation,
test drivers, and proof declarations are Bend 2. The optional rclone contribution
adds 14 Bend files and a separate minimal Go adapter. WritFS adds seven Bend
files and a shared Bend SHA-256 module, with separate native-storage evidence.

## Executable checks

The final combined suite exits 0 and prints `ALL LIBRARY TESTS PASSED` on both
the emitted JavaScript backend under Node and a native Bend executable using
four CPU threads with GPU execution explicitly disabled. The suite was last
rerun on 2026-11-03 after the HostBinding final-review fix wave with Bend
2.0.39, clang 23.1.1 (the C compiler Bend invokes), and Node v26.10.0.

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
| HostBinding | 126 | Genode binding model GA-001 to GA-011 (GA-010 reviewed-only): generations, parent routes, minted objects, close and revoke staleness, destroy authority (no close through a delegated copy), derived Frontend handles closed with their Session, holder versus subject, non-holders told UnknownAlias, delegation withdrawn with the delegator's route, no delegation to another subject's domain, non-widening delegation trees, quota before authority and refunds on close and revoke, exact state preservation on every denial |
| Property/oracle | 324 | Four oracle fixtures and 320 graph cases checked against both producers |
| **Total per backend** | **764** | **Both complete runs passed** |

The graph oracle computes four-node closure with Floyd–Warshall and derives
expected results directly from original seeds. It does not call the producer's
propagation/fold/sweep helpers. Its cases include all 256 subsets of eight fixed
directed edges, all 64 subsets of six undirected equality edges in the separate
conflict family, and bits 31, 32, and 63. Each case checks both the reference and
Bend parallel producer. This is finite executable coverage, not an exhaustive
proof for arbitrary graph sizes.

Evidence is in `verification/tests-js.txt` and `verification/tests-native.txt`.
The transfer test driver prints `PASS ` while other drivers print `PASS:`;
counting both forms yields 764 per file. The two files are byte-identical.

Reproduction:

```bash
mkdir -p ../writ-build
bend Tests.bend -o ../writ-build/tests.js
node ../writ-build/tests.js
bend Tests.bend -o ../writ-build/tests-native
../writ-build/tests-native +RTS --threads 4 --gpu off
```

### HostBinding vectors

`HostBindingTests.bend` prints 40 canonical `VECTOR <scenario-id> <transition>
<outcome> <reason-or-id>` lines, each rendered from the transition's actual
result after the check that asserts it, using model ids only. They were
captured with `bend Tests.bend`, which runs `main` on the JavaScript backend
inside the `bend` executable's embedded runtime: it ran with neither `clang`
nor `node` on `PATH` (a native build in the same environment refuses without
clang). They were regenerated and compared:

```bash
set -o pipefail
bend Tests.bend | grep '^VECTOR ' > verification/host-binding-vectors.txt
bend Tests.bend | grep '^VECTOR ' > ../writ-build/genode-binding/ff-vectors-run2.txt
cmp verification/host-binding-vectors.txt ../writ-build/genode-binding/ff-vectors-run2.txt
```

`cmp` reported no difference (SHA-256
`2cb375ae47af6eb7f07ce92b2dd95041efd625eab4a13ad549993515749a4fb4` for both),
and the `VECTOR` lines of the native run (`tests-native.txt`) are identical too.
The fix wave changed one earlier vector: GA-005-2 is now `denied UnknownAlias`
(was `denied SubjectMismatch`), because an alias the acting domain does not
hold is reported as unknown before any generation or subject check. The inputs behind
each vector id and the requirement mapping are in the
[traceability table](openspec/traceability/genode-capability-adoption.md). No
host port replays these vectors yet.

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
| **Total** | **29** | **Separate from the library suite** |

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

`bend PROOF.bend` prints `ALL PROOFS CHECK` for six declared laws:

1. A false guard at any position in a sequence makes the full guard false.
2. A denied selector returns the original state.
3. A denied ledger result preserves the original ledger state.
4. `binding_denied_preserves_state`: a rejected HostBinding change carries the
   supplied state. It holds by computation of the accessor and documents the
   denial contract; it does not prove a transition chose the right denial.
5. `nat_lt_successor`: every natural number is below its successor (auxiliary).
6. `generation_bump_monotone`: the destroy bump strictly raises an object's
   generation. That no transition lowers a generation is not stated.

These laws are in `LAWS.bend`, with implementations in `PROOF.bend`. They are
selected guard/state laws, not a proof of noninterference, whole-program
dependency completeness, cryptographic authentication, the compiler, or the OS.
No project source declares unsafe code, foreign code, or a proof hole.

The independent `--verdict` check **did not run successfully**. The official Lean
4.34.0 release archive was downloaded and hash-verified, but its executable exits
before kernel compilation with `error: failed to locate application`. Supported
path settings did not resolve that startup problem. No checker, compiler, or law
was changed to bypass it. See `verification/kernel-verdict.txt` and `proofs.txt`.

After the three HostBinding laws were added, and again after the HostBinding
final-review fix wave, `bend PROOF.bend --verdict` was attempted and exited 1
with:

```text
Error: BendTT infrastructure: the kernel did not build (lean: Executable not found in $PATH: "lean"); --verdict needs Lean v4.34.0 (elan toolchain leanprover/lean4:v4.34.0), or $BENDTT set to a built kernel
```

No Lean-kernel verdict exists for any of the six laws. `kernel-verdict.txt`
keeps the earlier three-law note and records the latest attempt verbatim.
Ordinary `bend PROOF.bend` printed `ALL PROOFS CHECK` after the fix wave.

## OpenSpec suite

The repository includes 15 baseline capability specs and 22 pending change
packages. OpenSpec 1.16.0 strict validation passed all 37 items with no errors or
warnings. Baseline specifications contain 153 requirements and 341 scenarios;
pending deltas contain 237 requirements and 441 scenarios. All 197 implementation
tasks in those pending packages remain unchecked. Since then, tasks 1.1 to 1.4 and 2.1 to 2.3 of
`add-genode-capability-adoption` have been checked against the HostBinding
evidence above; its section 3 remains unchecked. After the HostBinding
final-review fix wave edited that change's `tasks.md` (task 2.1 wording) and
its traceability table, `bunx @fission-ai/openspec@1.16.0 validate --all
--strict --no-interactive` passed with 0 failed (the active item count has
grown since the 36-item record). The bounded rclone reference change is
implemented and archived with eight completed tasks. Native snapshot staging is
implemented and archived with ten completed tasks. Neither completes a
production host adapter. See `verification/openspec-validation.txt`.

This is specification validation, not execution of every acceptance scenario.
Traceability tables distinguish named executable tests from source review and
host preconditions. The documentation cleanup does not complete any proposed
adapter task or expand the scope of the selected formal laws.

## Data-view and cooperation specifications

Seven proposed packages add WritFS, addressable views, locality-aware execution,
origin stages, controlled disclosure, scoped private matching, and cooperative
retirement. They contain 96 requirements, 200 scenarios, and 64 unchecked tasks.
The [feature guide](docs/FEATURES.md) and
[acceptance index](openspec/FEATURE-ACCEPTANCE.md) give concrete examples and
cross-feature gates. The source and documentation-style review is recorded in
[feature sources](docs/FEATURE-SOURCES.md).

The specification-only revision `876e6171b24b6ee8970ce58529c5abeb224474ab`
passed strict OpenSpec validation for its 36 active items. The combined tree
passes all 37 items, including native snapshot staging. The feature review
also checked relative Markdown targets, the 22-change dependency graph, scenario
clauses, requirement lengths, and implementation/baseline preservation.
Cross-review covered hidden match verdicts through status and disposition,
visibility-filtered event numbering, original versus effective release policy,
prior disclosure accounting, new-use versus durable-recovery authority, and
publication replay after retirement.

That specification-only revision preserved all 48 Bend files, four Go files,
both Go module files, and 14 baseline specs from revision
`06522bdce860ff720f16a8c331061f46627bb422`. Its historical review remains in
[feature-spec-review.txt](verification/feature-spec-review.txt). The combined
tree additionally contains the shared SHA module and native storage work
described below, with separate execution evidence. All 22 pending task files
remain unchanged. Mounted WritFS, cryptographic matching, and disposal guarantees
remain proposed; native private staging does not complete those features.

## Host platform research

The [platform architecture](docs/PLATFORMS.md) adopts Genode as the native
capability reference and specifies direct Linux, native Windows, and a later
kernel using Drift as distinct host targets. The update adds five proposed
changes with 60 requirements, 120 scenarios, and 46 unchecked tasks.

Genode 26.08 source was downloaded, checked against the recorded archive digest,
and inspected at commit `d18ee9e917200b059549e21f2dd9a55bfe61a0eb`. Drift source
and retained evidence were inspected at `0b7aaca7f4ff5e3da0570379632f952ecfe754f7`.
Linux and Windows mechanism claims are linked to primary documentation. These
are source/document reviews; no Writ Genode image, Linux confinement broker,
native Windows adapter, future kernel, or GPU isolation profile was executed.

All 34 pre-existing core/example Bend files are byte-identical to verified revision
`5982d18dff6ef21953058423ebdfb410d1de6b11`. The 638 library checks and 29 example
assertions per backend are retained evidence for that identical source, not new
host-port results. See [platform-review.txt](verification/platform-review.txt).

## Optional rclone contribution

The [rclone reference remote](contrib/rclone/README.md) keeps its adapter and
service under `contrib/rclone/`, with SHA-256 shared through `lib/Sha256.bend`.
Bend owns its
loopback service, canonical protocol, SHA-256, immutable object model, metadata,
and policy/commit behavior. A separate Go module adapts rclone interfaces and
bounded TCP transport. The root library has no new implementation dependency.

The contribution passes 165 pure checks per Bend backend, 34 real CLI integration
checks per test-driver backend against a native service, and nine Go tests. The
root 638-check suites and ordinary proof checks were rerun successfully. See the
[detailed record](contrib/rclone/VERIFICATION.md) for captured results, exact
limits, toolchain versions, and the distinction between these test lanes.

This is a memory-only, single-principal reference with a fixed standing profile.
It does not qualify the proposed native host ports or implement external grant
issuance, durable publication, arbitrary worker confinement, or a revocation feed.

## Native WritFS storage

The [WritFS backend](writfs/README.md) passes **95 model/parser/runtime checks
on each CPU backend**, plus **11 real Btrfs checks** and **18 real ZFS
filesystem/zvol checks** on disposable native Linux VMs. The native lanes
verify real payloads, read-only behavior, private presentation controls, exact
receipts, collision refusal, and the supported Btrfs snapshot transaction
transition. Both jobs cleaned up their owned fixtures successfully.

The SHA-256 extraction passed 25 digest and 74 rclone model regressions per
backend; the original algorithm and all 34 core/example files are unchanged.
The 638-check root suites and ordinary checks for the same three laws were
rerun successfully. See the [detailed WritFS record](writfs/VERIFICATION.md)
for source comparisons, exact native versions, logs, and fixes established by
real native execution.

An additional Windows Server 2025 lane passed **638 core and 78 WritFS model
checks** using Bend-generated JavaScript under native Windows Node 22.23.4,
without WSL. This is policy/model execution evidence, separate from a Windows
filesystem, native machine-code runtime, or host-confinement result.

The backend is a trusted administrative private-staging operation. It does not
provide a mounted Writ filesystem, authenticated storage service, durable
logical publication, handle revocation, or arbitrary-worker confinement.
Its native manifest seal is not a payload content hash. It adds no Go/C authored
implementation and does not replace the rclone contribution's memory-only store.

## Model boundaries

Passing tests does not authenticate a caller-supplied Context, Session, Capability,
Binding, graph, or ledger. Those must remain monitor-owned state. The code verifies
relationships among the supplied authoritative facts; the core does not discover the
complete source manifest from arbitrary code, compute an artifact digest, or
prove the bytes were produced by the pinned execution.

The optional reference service computes actual SHA-256 digests for its bounded
ingress/copy operation; that specific association does not establish arbitrary
worker execution provenance or complete source extraction.

The character-device interface is a pure protocol model. Durable atomic state
updates, general payload publication, syscall/process/device confinement, actual
payments, and external-language execution remain adapter work. WritFS performs
the narrow private native-copy effects documented separately. A publishing adapter must expose
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
