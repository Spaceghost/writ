# Verification record

Core regression rerun on 2026-11-04 using **Bend 2.0.39**, Linux x86_64, and
**clang 19.1.1**. Earlier example/platform evidence is scoped below. The
HostBinding records also include the 2026-11-03 review wave and 2026-11-04
binding-gap fixes with Bend 2.0.39, **clang 23.1.1**, and Node v26.10.0.
The core and examples contain 36 authored `.bend` files (34 originally verified,
plus `HostBinding.bend` and `HostBindingTests.bend`). Their implementation,
test drivers, and proof declarations are Bend 2. The optional rclone contribution
adds 14 Bend files and a separate minimal Go adapter. WritFS adds seven native
storage Bend files, three mounted-view Bend files and a shared SHA-256 module.
Inventoried C/C++ bindings and small JavaScript runtime harnesses remain under
contrib/native-hosts; their native evidence is separate from core tests.

## Executable checks

The final combined suite exits 0 and prints `ALL LIBRARY TESTS PASSED` on both
the emitted JavaScript backend under Node and a native Bend executable using
four CPU threads with GPU execution explicitly disabled. After integrating
master 58cdbfa4's final binding fixes, the native-host work reran all 782 checks
and 41 vectors with Bend 2.0.39, clang 19.1.1 and Node 24.22.1. Both outputs are
byte-identical and match the upstream 782-check records. The later master
dc6ff2b2 adds only a Genode-channel plan; tested implementation inputs are unchanged.

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
| HostBinding | 144 | Genode binding model GA-001 to GA-011 (GA-010 reviewed-only): generations, parent routes, minted objects, close and revoke staleness, destroy authority (no close through a delegated copy), derived Frontend handles closed with their Session, holder versus subject, non-holders told UnknownAlias, delegation withdrawn with the delegator's route, no delegation to another subject's domain, non-widening delegation trees, quota before authority and refunds on close and revoke, exact state preservation on every denial |
| Property/oracle | 324 | Four oracle fixtures and 320 graph cases checked against both producers |
| **Total per backend** | **782** | **Both complete runs passed** |

The graph oracle computes four-node closure with Floyd–Warshall and derives
expected results directly from original seeds. It does not call the producer's
propagation/fold/sweep helpers. Its cases include all 256 subsets of eight fixed
directed edges, all 64 subsets of six undirected equality edges in the separate
conflict family, and bits 31, 32, and 63. Each case checks both the reference and
Bend parallel producer. This is finite executable coverage, not an exhaustive
proof for arbitrary graph sizes.

Evidence is in `verification/tests-js.txt` and `verification/tests-native.txt`.
The transfer test driver prints `PASS ` while other drivers print `PASS:`;
counting both forms yields 782 per file. The two files are byte-identical.

Reproduction:

```bash
mkdir -p ../writ-build
bend Tests.bend -o ../writ-build/tests.js
node ../writ-build/tests.js
bend Tests.bend -o ../writ-build/tests-native
../writ-build/tests-native +RTS --threads 4 --gpu off
```

### HostBinding vectors

`HostBindingTests.bend` prints 41 canonical `VECTOR <scenario-id> <transition>
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
That earlier SHA (`2cb375…`) was recorded with 40 vectors, before the parked-gaps lane added GA-005-7 (the 41st vector).
On 2026-11-04 the suite was rerun with Bend 2.0.39, clang 23.1.1, and Node v26.10.0 (CPU only, `--threads 4 --gpu off`; no GPU was used): 41 vectors, two JavaScript runs `cmp`-identical, native `VECTOR` lines identical, SHA-256 of `verification/host-binding-vectors.txt` now
`1842e96673fe3b24eaff99ca820065d9dab05817c153132f6dd2b5d0ff9430ff`; the final-review fix wave (782 checks) recaptured the 41 lines with the same SHA-256. `bend PROOF.bend` printed `ALL PROOFS CHECK`; `bend PROOF.bend --verdict` could not run here and printed: `Error: BendTT infrastructure: the kernel did not build (lean: Executable not found in $PATH: "lean"); --verdict needs Lean v4.34.0 (elan toolchain leanprover/lean4:v4.34.0), or $BENDTT set to a built kernel`.
The fix wave changed one earlier vector: GA-005-2 is now `denied UnknownAlias`
(was `denied SubjectMismatch`), because an alias the acting domain does not
hold is reported as unknown before any generation or subject check. The inputs behind
each vector id and the requirement mapping are in the
[traceability table](openspec/traceability/genode-capability-adoption.md).
Native canary runtimes execute the model corpus, but no host binding yet
replays those vectors against native capability transitions.

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

The proposed authenticated-grant-issuance change (`Issuance.bend`, not wired to
any host) adds six laws, checked by the same `bend PROOF.bend`:

- `nat_eq_successor_false`: no natural number equals its successor under
  `Nat.is_eq` (auxiliary; says nothing about issuance by itself).
- `issuance_stale_revision_rejects`: a registration whose expected revision is
  one past the state's never commits (GI-005). Successor revision only; it
  does not claim the host installs atomically or serializes installs (AB-006).
- `issuance_stale_registration_keeps_state`: that registration returns exactly
  the supplied state. Successor revision only; state preservation on every
  other denial is tested, not proved.
- `issuance_stale_revocation_keeps_state`: the same for revocation. Successor
  revision only; host serialization is not claimed.
- `nat_le_add_successor_false`: a natural number plus a positive amount is
  never at most the original under `Nat.is_le` (auxiliary).
- `derived_lifetime_extension_rejects`: a derivation asking for a lifetime past
  its parent's never commits and returns the supplied state (GI-006, lifetime
  half). Rights attenuation is tested, not proved (U32 masks); scope and
  subject cannot be expressed by a derivation; the per-use re-check of the
  chain in `current` is tested.

On the issuance tree `bend PROOF.bend` printed `ALL PROOFS CHECK`, and the one
`bend PROOF.bend --verdict` attempt exited 1 with the same missing-`lean`
error quoted below (see `verification/kernel-verdict.txt`). No Lean-kernel
verdict exists for these laws either.

These laws are in `LAWS.bend`, with implementations in `PROOF.bend`. They are
selected guard/state laws, not a proof of noninterference, whole-program
dependency completeness, cryptographic authentication, the compiler, or the OS.
The Bend policy/proof sources introduce no unsafe definitions or proof holes.
Inventoried C/C++ OS/runtime bindings and native probes are separate from these
laws; the ordinary proof check does not prove their correctness.

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

OpenSpec 1.16.0 strict validation passes all **44 active items**: 16 baseline
capabilities and 28 pending change packages. The baseline has 161 requirements
and 362 scenarios; pending deltas have 294 requirements and 555 scenarios.
The 28 pending task files retain 238 unchecked and 15 previously completed
tasks, unchanged from integrated master dc6ff2b2. (Those counts predate the
Genode lanes; on the Genode channel lane's tree, counted with `grep` of
`- [ ]` and `- [x]` lines, they are 233 unchecked and 20 checked, and
OpenSpec 1.16.0 strict validation passes 44 of 44 items; see "Genode Bend
component, base-linux" below.)

Only the bounded native-canary change was completed and archived in this
contribution: eight requirements, 21 scenarios and six tasks. Windows mounted
presentation is implemented, while its complete confinement gate remains failed.
That failure and the separate diagnostic results are recorded explicitly; the
broader Windows host proposal remains open. The other host, runtime, namespace,
issuer and durable-publication changes retain their own qualification gates.

The earlier rclone reference and native snapshot staging archives retain their
eight and ten completed tasks respectively. Historical 37-item OpenSpec output
remains in verification/openspec-validation.txt; the current result is in
[the native contribution's validation record](contrib/native-hosts/verification/openspec.txt).

Structural validation does not execute every acceptance scenario or establish
confinement. Traceability identifies named tests, reviewed mechanics and remaining
host preconditions. No security law or broader host task was weakened to close
the bounded canary contract.

## Data-view and cooperation specifications

Seven proposed packages add WritFS, addressable views, locality-aware execution,
origin stages, controlled disclosure, scoped private matching, and cooperative
retirement. They contain 96 requirements, 200 scenarios, and 64 unchecked tasks.
The [feature guide](docs/FEATURES.md) and
[acceptance index](openspec/FEATURE-ACCEPTANCE.md) give concrete examples and
cross-feature gates. The source and documentation-style review is recorded in
[feature sources](docs/FEATURE-SOURCES.md).

The specification-only revision `876e6171b24b6ee8970ce58529c5abeb224474ab`
passed strict OpenSpec validation for its 36 active items. The subsequent
snapshot-staging revision passed the 37 items then present. The historical
feature review also checked relative links, its 22-change dependency graph, scenario
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
described below, with separate execution evidence. That revision preserved its
22 pending task files. Later upstream model/runtime work records its own partial
completion; the seven feature packages retain their unchecked tasks. General
WritFS namespaces, cryptographic matching and disposal remain proposed; native
staging and canary mounts do not complete those features.

## Host platform research

The [platform architecture](docs/PLATFORMS.md) adopts Genode as the native
capability reference and specifies direct Linux, native Windows, and a later
kernel using Drift as distinct host targets. The update adds five proposed
changes with 60 requirements, 120 scenarios, and 46 unchecked tasks.

Genode 26.08 source was downloaded, checked against the recorded archive digest,
and inspected at commit `d18ee9e917200b059549e21f2dd9a55bfe61a0eb`. Drift source
and retained evidence were inspected at `0b7aaca7f4ff5e3da0570379632f952ecfe754f7`.
Linux and Windows mechanism claims are linked to primary documentation. Those
original records were source/document reviews. Later native canary execution is
recorded separately below. No future kernel or GPU isolation profile is qualified.

At that platform-research revision, all 34 core/example Bend files were identical
to `5982d18dff6ef21953058423ebdfb410d1de6b11`. Its 638 library checks and
29 example assertions per backend are historical evidence, not host-port results.
The later HostBinding additions and 782-check regressions are recorded above. See [platform-review.txt](verification/platform-review.txt).

## Genode Bend component, base-linux (channel lane)

The proposed change `add-genode-bend-component` was exercised on Genode
26.08 `base-linux` (Genode-on-Linux: core, init, and components are Linux
processes), single lane, `--gpu off`, over the synthetic authority state of
`examples/Scenario.bend`. `base-hw` was not attempted, and no host profile is
qualified. The library corpus is unchanged: `writ_bend_tests` prints the 782
PASS lines and `ALL LIBRARY TESTS PASSED`, and its 834 component lines are
byte-identical to the Linux single-lane record (sha256
`fc3a08aa33059b67fc9602d20496f6d40ad7950e5dd32bada6fc37c6062916ff`). The
Linux check `hosts/genode/monitor/MonitorCheck.bend` (17 PASS lines over the
monitor's pure decision, the channel table, close events, and reasons 1 to
8) is host scaffolding and is not among the 782 checks.

Genode runs (`make run/<name>`), with their evidence:

| Run scripts | Evidence |
| --- | --- |
| `writ_bend_hello`, `writ_bend_rts` | [genode-bend-hello-base-linux.txt](verification/genode-bend-hello-base-linux.txt) |
| `writ_probe_threads`, `writ_probe_clock`, `writ_probe_evloop`, `writ_probe_process`, `writ_probe_fault`, `writ_probe_reservation_live`, `writ_probe_reservation_guard` | [genode-runtime-rows-base-linux.md](verification/genode-runtime-rows-base-linux.md), [genode-reservation-probe-base-linux.txt](verification/genode-reservation-probe-base-linux.txt) |
| `writ_bend_tests`, `writ_bend_example`, `writ_bend_flow`, `writ_bend_transfer`, `writ_bend_gpuexample`, `writ_bend_overflow` | [genode-corpus-base-linux.txt](verification/genode-corpus-base-linux.txt) |
| `writ_bend_probe` | [genode-effects-base-linux.txt](verification/genode-effects-base-linux.txt) |
| `writ_bend_monitor_accept`, `_substitute`, `_routed_s`, `_claim_ignored`, `_bad_length`, `_liveness`, `_queue`, `_dead_client` | [genode-channel-base-linux.txt](verification/genode-channel-base-linux.txt) |

The requirement-by-requirement map, with reviewed-only gaps quoted, is the
[traceability table](openspec/traceability/genode-bend-component.md). Open
in that change: 1.3 (the parent records no fault), 2.2 (the shim inventory
has no GB-006 reviewer), and section 3 (`base-hw`, the binary check task,
OpenSpec). `scripts/runtime-profile/check-binary.sh` on the monitor ELF
reports only Genode effect rows (`Genode.log`, `Genode.put`,
`Genode.take`) beyond the monitor profile and fails its symbol half, as on
every Genode binary (Linux allow list).

## Optional rclone contribution

The [rclone reference remote](contrib/rclone/README.md) keeps its adapter and
service under `contrib/rclone/`, with SHA-256 shared through `lib/Sha256.bend`.
Bend owns its
loopback service, canonical protocol, SHA-256, immutable object model, metadata,
and policy/commit behavior. A separate Go module adapts rclone interfaces and
bounded TCP transport. The root library has no new implementation dependency.

The contribution passes 165 pure checks per Bend backend, 34 real CLI integration
checks per test-driver backend against a native service, and nine Go tests. The
then-current root 638-check suites and ordinary proof checks were rerun successfully. See the
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
backend. That storage revision preserved the algorithm and all 34 then-existing
core/example files. Its 638-check root suites and the three laws then present
were rerun successfully. See the [detailed WritFS record](writfs/VERIFICATION.md)
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

## Native filesystem canaries

The optional [native contribution](contrib/native-hosts/README.md) implements
one immutable read-only public object through WinFsp, Linux FUSE and native
Genode File_system/VFS. Shared Bend modules retain the complete facade commit,
hash the frozen payload, bind native reader lifetimes and mediate metadata,
bounded handles and supervisor revocation.

The [execution record](contrib/native-hosts/VERIFICATION.md) captures 69 mount
vectors plus a count-consistency check: 70 PASS lines on each local backend.
The integrated core passes 782 checks and 41 vectors on both CPU backends;
all six ordinary laws pass. Linux native CI passes its actual mounts, fixed
worker probes, revocation, interpreter/broker failure and owned cleanup.
Genode clean CI passes the 782-core and 69-mount corpus, 24 allocator checks
on host and guest, 56 filesystem checks and eight libc/VFS checks.

Windows mounted reads, caller denial and revocation pass, including its LPAC
reader. The strict confinement gate remains failed because direct network,
clipboard and COM probes cannot initialize in the byte-worker profile. Separate
no-data diagnostic passes do not replace those missing observations; the
[Windows record](contrib/native-hosts/windows/VERIFICATION.md) retains exit 1.

Windows and Genode execute generated JavaScript in native Node/QuickJS. This
does not qualify general machine-code Bend ports. Public input status is an
operator precondition. Events identify process/session facts, not human intent,
and are bounded diagnostics rather than durable audit. Broader host, issuer,
whole-dataset presentation, writable publication and recovery remain pending.

All 67 Bend files from integrated master dc6ff2b2 remain byte-identical. This
contribution adds three Bend modules and changes no existing security law.
Independent Lean kernel verification and physical GPU execution remain outside
these results. Earlier 638/764 native records retain their exact-source counts.

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
