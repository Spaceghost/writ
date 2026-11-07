# Verification record

Core regression rerun on 2026-11-04 using **Bend 2.0.39**, Linux x86_64, and
**clang 19.1.1**. Earlier example/platform evidence is scoped below. The
HostBinding records also include the 2026-11-03 review wave and 2026-11-04
binding-gap fixes with Bend 2.0.39, **clang 23.1.1**, and Node v26.10.0.
The core and examples contain 47 authored `.bend` files (34 originally verified,
plus `HostBinding.bend`, `HostBindingTests.bend`, `Issuance.bend`,
`IssuanceTests.bend`, and the nine portable-host-contract files). Their implementation,
test drivers, and proof declarations are Bend 2. The optional rclone contribution
adds 14 Bend files and a separate minimal Go adapter. WritFS adds seven native
storage Bend files, three mounted-view Bend files and a shared SHA-256 module.
Inventoried C/C++ bindings and small JavaScript runtime harnesses remain under
contrib/native-hosts; their native evidence is separate from core tests.

## Executable checks

The GPU record checker's later [synthetic file-only controls](verification/gpu-record-pid-binding/README.md)
exercise PID/maximum binding, decimal overflow handling and its supported option
profile. They do not run a GPU or change the historical GPU evidence below.

Two isolated public nested Genode CI attempts, at workflow commits `f426fa1`
and `9e888b7`, remained incomplete before boot. The [first](verification/genode-nested-ci-f426fa1/README.md)
failed on a missing library; the [retry](verification/genode-nested-ci-9e888b7/README.md)
hit its output bound. Neither observed the nested fixture or negative control,
and cleanup remained unverified. No protected host is qualified.

The [isolated nested Genode positive run](verification/genode-nested-ci-7b31cfc/README.md)
observed the public synthetic R route and decision on base-linux. Overall it
remains incomplete because cleanup is unverified; the negative job was still
pending when this record was made, and no protected host is qualified.

The [automatic Genode CI at `c14f125`](verification/master-ci-c14f125/README.md)
passed scoped public checks and retained missing-clock warnings. It did not
run the nested channel fixture or qualify a protected host.

The [automatic master platform runs at `b18c0af`](verification/master-ci-b18c0af/README.md)
passed scoped Windows Node, Genode, Linux public-canary and Btrfs/ZFS fixture
checks. **Strict Windows native failed** with incomplete byte-worker network,
clipboard and COM observations. Linux retained a protected-setup refusal
before input; none qualifies a protected host.

The [automatic master platform runs at `45df241`](verification/master-ci-45df241/README.md)
passed scoped Windows Node, Genode, Linux public-canary and Btrfs/ZFS fixture
checks. **Strict Windows native failed** with incomplete byte-worker network,
clipboard and COM observations. The Linux run retained a protected-setup
refusal before input; none qualifies a protected host.

The [automatic CI runs at `f7c47e9`](verification/master-ci-f7c47e9/README.md)
passed Windows Node policy/model and public Btrfs/ZFS fixture checks. These
are scoped observations, not protected-worker or durable-service qualification.

The planner integration reconciled the reviewed planner evidence
branch `ef40aa2` with master `22c8522`. The reconciliation's Bend, workflow
and Nix inputs were unchanged from `ef40aa2`; earlier test and CI results
retain the exact source identities stated in their records and were not rerun
on that evidence merge.

The [isolated proof and test preview](verification/planner-proof-composition-preview/README.md)
rechecks both test sets and the new law on their combined Bend inputs. Its
[exact-source CI record](verification/planner-law-ci-cb54600/README.md) retains
the Linux setup refusal and Genode clock warnings; no protected-host
qualification follows. The
[composition and byte-regression preview](verification/planner-composition-byte-preview/README.md)
combines both test sets. The separately reviewed frontend-composition branch added 35 synthetic checks
to the 2,224-check source, for 2,259 checks at that source. The current
preview also retains the two byte-range checks, for 2,261 checks. These
composition checks exercise a test-selected frontend and plan comparison,
not an authenticated planner request or a production adapter.

The [58c7ffe platform CI record](verification/planner-composition-byte-ci-58c7ffe/README.md)
retains its exact-source outcomes, Linux setup refusal and Genode clock warning;
it does not qualify a protected host or establish later-source CI.

The planner envelope adds 60 synthetic codec checks to the 2,102-check suite,
for 2,162 checks at its recorded source. The later boundary regression adds one
check, and the separate plan-comparison model adds 61 synthetic checks, for
2,224 checks at that source; two later byte-range regressions bring the
byte-regression branch to 2,226 checks. The comparator checks plan fields only and does not resolve a request or establish authority. Its reference-only descriptions do not authenticate
identities or establish planner integration; see the [change traceability](openspec/changes/add-external-planner-adapters/traceability.md).
The separate [comparison record](verification/planner-plan-match-local.md)
scopes its pre-integration tests and existing-law proof verdict.
The [high-word mutation review](verification/planner-comparator-mutants-6985302/README.md)
records the added comparison regression and its scoped local checks.
The later high-word regression passed an [optimized native CPU run](verification/planner-comparator-native-c5a02c7/README.md)
and scoped [platform CI](verification/planner-comparator-ci-c5a02c7/README.md)
at exact source `c5a02c7`. Linux retained a protected-setup refusal before input;
no result qualifies a protected host.
The [byte-range mutation review](verification/byte-range-mutants-f4ef13d/README.md)
records two later public-decoder regressions and their local checks.
The [Nix JavaScript result](verification/byte-range-nix-e632e35/README.md),
[optimized native CPU result](verification/byte-range-native-e632e35/README.md)
and [platform CI](verification/byte-range-ci-e632e35/README.md) cover exact source
`e632e35`, with Linux protected setup refused before input and Genode clock
warnings retained. These checks do not qualify a protected host.
Earlier evidence below remains tied to its own source and is not a claim that
the new checks ran in those historical environments.
The [planner codec record](verification/planner-envelope-local.md) links its
local and exact-source platform checks and retains their qualifications.
The later [N48 mutation review](verification/planner-n48-mutants-dd3dac9/README.md)
records the additional structural check and its Bend/Node results; earlier
platform evidence does not test that later revision.
The [combined preview record](verification/planner-boundary-comparator-preview.md)
scopes the separate 2,223-check Bend/Node, Nix JavaScript, native CPU and
existing-law verdict results and links the [platform CI](verification/planner-boundary-comparator-ci-6985302/README.md).
At exact source `262a8d4`, the reviewed boundary revision also passed an
[optimized native CPU run](verification/planner-boundary-native-262a8d4/README.md)
and scoped [Windows Node, Genode and Linux CI](verification/planner-boundary-ci-262a8d4/README.md).
The Linux run retains an unsupported setup refusal; none qualifies a protected
host or authenticated planner.

The [automatic master runs at `60d6f6b`](verification/master-ci-60d6f6b/README.md)
passed their scoped Windows Node, Genode, Linux public-canary and Btrfs/ZFS
fixture checks. **Strict Windows native failed**: actual-worker network,
clipboard and COM observations remained incomplete. The Linux run retained an
expected setup refusal before input; none of these results qualifies a protected
host or authenticated planner.

A [Lean-built BendTT verdict](verification/lean-verdict-be649f6/README.md)
passed for the 36 named laws in `PROOF.bend` at exact source `be649f6`. Its
negative control and toolchain provenance are recorded; earlier unavailable
Lean attempts remain historical. This does not establish native host
confinement, durable publication or a handoff-specific law.

The synthetic handoff model adds 37 named checks to the 2,065-check
combined baseline (2,102 total). Its monitor facts and current-state binding are
assumptions, and model execution does not establish a Windows handoff or host
confinement. See the [model record](docs/superpowers/records/2026-11-06-windows-init/handoff-model-record.md)
for the scope and remaining native and commit-time gaps. The earlier native and
cross-backend observations below remain historical evidence of their exact source.
The exact hardened `817ab1f` model source also passed the [Windows Node](verification/handoff-ci-817ab1f/windows-42327055068/README.md), [Genode QEMU](verification/handoff-ci-817ab1f/genode-42327054904/README.md) and [Linux public-canary](verification/handoff-ci-817ab1f/linux-42327055037/README.md) workflows. The Genode guest retained a missing-clock warning; the Linux protected setup deliberately refused unsupported Landlock before input and was not qualified. These results do not establish strict Windows worker confinement.

The [automatic master runs at `1ce6757`](verification/master-ci-1ce6757/README.md)
passed their scoped Windows Node, Genode, Linux public-canary and Btrfs/ZFS
fixture checks. **Strict Windows native failed**: the actual worker's network,
clipboard and COM observations remained incomplete. The Linux run retained an
expected setup refusal before input; none of these results qualifies a protected
host.

The historical 1942-check recordings below predate the Linux model and
HostWire bounds changes. Separate trees have recorded 2060 checks with the
Linux model and 1947 checks with the HostWire change. The combined suite at source `73a8055`
passed 2065 checks in Bend, Node and the host QuickJS harness. Bend and Node
output matches byte-for-byte (SHA-256
`6f7c55909c94af843f65152f51f453798d0684e3e19c1db766bfa79ed7b5d449`); the
host QuickJS run reports 19,918 ticks and no exception. The optimized native
CPU output also matches. For source `73a8055`, the Nix JavaScript check matches
the same hash; the Nix native CPU check also passes with the same hash. The
[combined Nix flake check](verification/nix-combined-flake-check.log) passed
all checks with evidence-only files staged. Native Windows Node passed
2,065 checks, the existing Linux public canary passed its native cases, and a
Genode base-hw QEMU guest passed 2,065 core plus 69 mount checks. The
[Linux canary](contrib/native-hosts/linux/verification/run-42308676909/README.md),
[Windows Node](verification/windows-policy-run-42308676869/README.md), and
[combined integration record](docs/superpowers/records/2026-11-05-linux-host/model-only-integration.md)
link exact source and retained evidence. The synthetic Linux cases do not
qualify a protected-worker host.

The historical combined suite exits 0 and prints `ALL LIBRARY TESTS PASSED` on both
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
| Facade | 12 | Capability resolution through final commit, reader identity, revoked/closed/stale descriptors, no spending on denial |
| HostBinding | 144 | Genode binding model GA-001 to GA-011 (GA-010 reviewed-only): generations, parent routes, minted objects, close and revoke staleness, destroy authority (no close through a delegated copy), derived Frontend handles closed with their Session, holder versus subject, non-holders told UnknownAlias, delegation withdrawn with the delegator's route, no delegation to another subject's domain, non-widening delegation trees, quota before authority and refunds on close and revoke, exact state preservation on every denial |
| Issuance | 230 | Authenticated approval submission, exact paired-scope registration (subject-only caller), revision-checked revocation and replay, attenuation-only derivation, exclusive expiry, subject-scoped per-use projections into T.admit and F.checked_plan (model only; not wired to a host) |
| Rendezvous | 229 | Executor rendezvous (`Rendezvous.bend`): offers gated on a current Issuance grant and the exact negotiated plan, origin approvals re-checked against the directory and the issuer's live stamp, eligibility gates and strict ranking, one rendezvous per request, trial binding with the session following the selection, evidence accepted only from the selected provider, dispatch and commit projection gated on host currency and the stored selection, lifecycle scenarios; exact state on every denial (model only; no host) |
| HostWire | 63 | Versioned, bounded, canonical wire schema (four tags, fixed widths, little-endian bytes): word and byte round trips, unknown versions and tags (a tag-5 record shaped like a serialized Context, Ledger, and caller included), malformed lengths, out-of-range fields, fixed check order; decoding yields descriptions, never authority (model only) |
| HostIdentity | 92 | Monitor-owned identity table: authenticated session binding, minting, resolution order (revision, host, incarnation, forged, ambiguity, generation, holder, origin, expiry), the holder is the bound session rather than the subject, an untrusted claimed subject never changes the caller, inherited and transferred endpoints, non-widening delegation that never changes the subject, restart incarnations, retire cascade, exact state on every denial (model only) |
| HostPrimitives | 216 | The five primitive families (`HostPrimitives.bend` and `HostPublication.bend`): session binding with monitor-decided client delegability, issue bound to its Frontend handle's plan, owner, rights, and lease, and delegate wrappers, worker admission under a monitor-bound profile (controls, families, accelerator isolation, route inventory, one worker per identity entry), quotas and gated diagnostics, sealing against live writers and retargeting, publication only through `DataOS.commit_from_capability` with exact plan binding, replay and reconcile bound to the recorded digest and destination, revoke, restart, quiesce, reclaim and complete; full state equality and no effects on every denial (model only; no native binding) |
| HostConformance | 43 | 36 shared conformance vectors plus one comparison line, run on two synthetic adapters: exact plan, owner, rights, and lease binding at issue and plan binding at publication, retained provenance, caller identity and session holding, revocation, replay, restart, digest and destination substitution at recovery, unchanged state on denial; identical decision lines on both adapters (the decision half of PH-012 only; no native adapter replays them) |
| Audit | 285 | Policy-aware audit section 1 (`AuditEvent.bend`, `AuditQuery.bend`, `AuditExport.bend`): allowlisted events projected from library results, `ScopeNotRead{}` for early denials, event policy as the join of every influence failing closed, owner-scoped queries with one fixed public refusal, cursors bound to owner, sink and epoch, bounded work charged to the visible view only, export, metric and alert channels under explicit grant, revocation and re-grant refusal, canonical encoding (model only; no durable log, no host) |
| Property/oracle | 324 | Four oracle fixtures and 320 graph cases checked against both producers |
| **Total per backend** | **1942** | **Both complete runs passed** |

The graph oracle computes four-node closure with Floyd–Warshall and derives
expected results directly from original seeds. It does not call the producer's
propagation/fold/sweep helpers. Its cases include all 256 subsets of eight fixed
directed edges, all 64 subsets of six undirected equality edges in the separate
conflict family, and bits 31, 32, and 63. Each case checks both the reference and
Bend parallel producer. This is finite executable coverage, not an exhaustive
proof for arbitrary graph sizes.

Evidence is in `verification/tests-js.txt` and `verification/tests-native.txt`.
The transfer test driver prints `PASS ` while other drivers print `PASS:`;
counting both forms yields 1942 per file. The two files are byte-identical.

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

### Portable host vectors

`HostConformanceTests.bend` prints 37 `VECTOR <vector-id> <transition>
<outcome> <reason-or-result>` lines: 36 vectors and the PH-012-1 comparison
line `compare accepted vectors=36`. Each is rendered from adapter A's actual
result after a check requires adapter B's line to be equal and both to equal
the expected line in `HostConformanceVectors.bend`. Slots are printed as
logical names, so the adapters' different hosts, incarnations, and slot
numbers do not appear. The lines are in
[portable-host-vectors.txt](verification/portable-host-vectors.txt). On the
portable-host-contract lane's tree after the final fix round and the merge of
master (2026-11-05, Bend 2.0.39, clang
23.1.1, Node v26.10.0; CPU only, `--threads 4 --gpu off`; no GPU was used),
the `VECTOR PH-` lines of the Node run (`tests-js.txt`) and of the native run
(`tests-native.txt`) were both `cmp`-identical to that file, SHA-256
`37816dd7d768c21e730f780cbc98b66cadbba087c972d18e731b670219caf24f`, and the
41 HostBinding lines were unchanged:

```bash
grep '^VECTOR PH-' verification/tests-js.txt | cmp - verification/portable-host-vectors.txt
grep '^VECTOR PH-' verification/tests-native.txt | cmp - verification/portable-host-vectors.txt
grep '^VECTOR GA-' verification/tests-js.txt | cmp - verification/host-binding-vectors.txt
```

The inputs behind each vector id and the requirement mapping are in the
[traceability table](openspec/traceability/portable-host-contract.md). Both
adapters are Bend fixtures of the same interfaces, not native bindings. No
native host replays these vectors yet; that is section 2 of the
[portable host contract tasks](openspec/changes/add-portable-host-contract/tasks.md).

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

The paragraph above is the record of that environment and stays as history.

### 2026-11-05: one GPU host (validate-physical-gpu-execution, proposed)

This host differs from the environment above: it has `/dev/nvidia0`, the CUDA
toolkit and NVRTC. Linux 7.2.9-1-MANJARO x86_64, 32 CPUs, NVIDIA GeForce RTX
4090 `GPU-0188dad3-4d11-4254-3a0d-50e3808bf464`, driver 615.71.09, CUDA UMD
13.4, Bend 2.0.39, clang 23.1.1, NVRTC 13.4.92, cubins `sm=89`
([gpu-toolchain.txt](verification/gpu-toolchain.txt), "Result"). The host is
shared with the display and other GPU clients and was loaded throughout
(1-minute load 10.79 to 99.82 on 32 CPUs). Every configuration, hash and
command is in [gpu-validation-hosts.md](verification/gpu-validation-hosts.md);
the requirement map is
[openspec/traceability/gpu-validation.md](openspec/traceability/gpu-validation.md).

Library correctness: the library corpus printed 782 PASS lines with
`--gpu on` and with `--gpu off`, byte-identical to each other and to
`verification/tests-native.txt` as of 98db68bf (sha256 `fc3a08aa...062916ff`),
on the 782 tree before the merge of master
([gpu-corpus.txt](verification/gpu-corpus.txt), "Result").
On the merged tree the corpus printed 1428 PASS lines with `--gpu on` and with
`--gpu off`, byte-identical to each other and to `verification/tests-native.txt`
as it stands on the merged tree (sha256 `6faee219...9318`)
([gpu-corpus.txt](verification/gpu-corpus.txt), "Result (merged tree)"), and
1428 in the Bend driver ([gpu-final-checks.txt](verification/gpu-final-checks.txt)).

GPU claim, limited to runs with observed launches: compute-sanitizer counted
`bend_dev` launches attributed to the binary, and the hardware-evidence gate
passed, for the graph solver, the label batch and the transfer batch, each in
its own single-bang probe ([gpu-paths.txt](verification/gpu-paths.txt),
"Result"), for 18 of 20 parity cases ([gpu-parity.txt](verification/gpu-parity.txt),
"Result"), for the device runs underneath 11 injected-fault cases
([gpu-injection.txt](verification/gpu-injection.txt), "Result"), and for the
solver bang inside the corpus, 4915 launches on the 782 tree
([gpu-corpus.txt](verification/gpu-corpus.txt), "Result"), and again 4915 launches with gate PASS on the merged 1428 tree
([gpu-corpus.txt](verification/gpu-corpus.txt), "Result (merged tree)").
Separately, CPU-side outcomes: the device results equalled the CPU reference
(typed comparison) and the CPU-side check or replay accepted them, and it
denied every injected fault in every round. The gate refuses
forced CPU fallback, a hidden device and zero launches
([gpu-gate-controls.txt](verification/gpu-gate-controls.txt), "Result").
Everything else is CPU execution: every `--gpu off` run, every CPU reference,
verifier and replay, and the corpus's label and transfer batches.

Limits: the timings were taken on a loaded host and are not representative;
the complete `--gpu on` pipeline took longer than `--gpu off` of the same
binary in every measured cell on this loaded host; this is not a performance
result, and no speedup is claimed ([gpu-pipeline.txt](verification/gpu-pipeline.txt), "Result",
"Limits"). The device call is not split into memory movement, dispatch and
kernel time, because Nsight is not installed. The only trust profile is GT-1
trusted device: the managed heap is shared and writable, and hostile device code
and drivers are excluded from the threat model as a limit, not a boundary
([gpu-trust-profile.md](verification/gpu-trust-profile.md), "Threat-model
exclusion"). The label and transfer checks reuse the producers' evaluators. No
32-bit probe digest is equality evidence. No Lean verdict was obtained for that
historical GPU run.

## Explicit proof scope

`bend PROOF.bend` prints `ALL PROOFS CHECK` for thirty-seven declared laws.
The thirty-six historical laws include:

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
verdict was obtained for these laws on that issuance tree.

The portable-host-contract lane adds five further laws. Each fixes
the denial contract of one host-contract module and holds by computation of an
accessor; its rationale is in that module's header and above the law:

- `identity_denied_preserves_state` (`HostIdentity`): a rejected identity
  change carries the supplied state.
- `primitive_denied_preserves_state` (`HostPrimitives`): a denied primitive
  step carries the supplied state.
- `primitive_denied_emits_nothing` (`HostPrimitives`): a denied primitive step
  carries no effect.
- `publication_refused_preserves_state` (`HostPublication`): a refused
  publication carries the supplied primitive state.
- `publication_refused_emits_nothing` (`HostPublication`): a refused
  publication carries no `Publish` effect.

None of them asserts which transitions deny, that a reason is the right one,
that a refused publication returns the input session and ledger, or that an
accepted step or published intent is correct; the named checks in
`HostIdentityTests.bend` and `HostPrimitivesTests.bend` and the conformance
vectors cover those. That a binding executes only effects the monitor
returned is a host obligation. On that lane's final tree, `bend PROOF.bend`
printed `ALL PROOFS CHECK` for the earlier laws and these five, and
`bend PROOF.bend --verdict` exited 1 with the same `lean: Executable not found`
error shown below, so no Lean-kernel verdict was obtained for that lane run.

The policy-aware-audit lane (section 1 of `add-policy-aware-audit`; model
only, no durable log and no host) adds twelve further laws, checked by the same
`bend PROOF.bend`; each law's rationale and limits are in its `LAWS.bend`
comment and in the module header, and `verification/policy-aware-audit.txt`
records the run:

- `audit_admission_event_ignores_diagnostic` and
  `audit_commit_event_ignores_diagnostic`: the recorded event never depends on
  the caller token or the diagnostic (the token may still change the decision,
  and reaches the event only through it).
- `audit_admit_returns_library_decision` and
  `audit_commit_returns_library_result`: the wrappers return exactly the
  library decision or facade result, so a denied transfer stays denied and a
  rejected commit keeps the caller's session and ledger.
- `audit_failed_influence_withholds`: one influence that does not flow to the
  sink label makes the flow check false at any position (does not claim
  `releasable` is the only route to a sink).
- `audit_outcome_never_lowers_policy`: the recorded admission policy is the
  same function of plan, context, labels and subject for every token,
  diagnostic and event id, hence for every decision.
- `audit_invisible_event_unobservable` and
  `audit_export_outside_stream_unobservable`: inserting an event the caller may
  not see, or outside the owner's stream, anywhere in the log leaves the query
  view and the export view unchanged (that `respond` and `transmit` read the
  log only through those views is structural and tested, not proved; timing is
  not covered).
- `audit_stale_query_refused`: a query at the successor revision is the public
  refusal (successor revision only; host serialization is not claimed).
- `audit_refusal_is_constant`: whenever the revision is current and some query
  gate fails, the response is exactly the one public refusal (the gate list's
  completeness is pinned by tests, not proved).
- `audit_ungranted_export_emits_nothing` and
  `audit_revoked_export_emits_nothing`: with no grant naming exactly this
  exporter, owner, sink and channel, or with the grant found revoked, `transmit`
  emits nothing (the grant registry's correctness and that a host sends nothing
  outside `transmit` are host obligations).

On that lane's final tree `bend PROOF.bend` printed `ALL PROOFS CHECK` for all
twenty-nine laws, and `bend PROOF.bend --verdict` exited 1 with the same
missing-`lean` error, so no Lean-kernel verdict was obtained for that lane run.

The executor-rendezvous lane (`add-executor-rendezvous`; model only, no host)
adds seven further laws, checked by the same `bend PROOF.bend`; each law's
rationale and limits are in its `LAWS.bend` comment and in the module header,
and `verification/executor-rendezvous.txt` records the run:

- `nat_lt_irreflexive` and `nat_eq_reflexive`: auxiliary arithmetic for the
  offer order (say nothing about the rendezvous by themselves).
- `offer_order_irreflexive` (ER-003): the offer comparator is strict on its
  diagonal at all three levels (quote, provider id, serial), so list order
  cannot pick among records under one identity (transitivity, totality on
  distinct identities and that `best` returns the minimum are not proved).
- `rendezvous_ineligible_offer_dropped` (ER-002): an ineligible offer, at any
  position and whatever its quote, leaves the ranked eligible list unchanged
  when removed (that `select` ranks only that list is structural and tested).
- `rendezvous_stale_selection_keeps_state`: a selection at the successor
  revision is not accepted and returns exactly the supplied state (successor
  revision only; host serialization is not claimed).
- `rendezvous_wrong_provider_evidence_rejects` (ER-005): evidence from a
  provider other than the stored selection's, or with no selection, is not
  accepted and returns exactly the supplied state (outer match only).
- `rendezvous_unselected_dispatch_rejects` (ER-001, ER-007): a dispatch whose
  offer, worker session or binding is not the stored selection's target, or
  with no selection, is not accepted and returns exactly the supplied state
  (outer match only; host currency, selection currency, caller token,
  evidence, trial and replay are tested, not proved).

On that lane's final tree `bend PROOF.bend` printed `ALL PROOFS CHECK` for its
twenty-four laws, and on the merged tree for all thirty-six;
`bend PROOF.bend --verdict` exited 1 with the same missing-`lean` error, so
no Lean-kernel verdict was obtained for that earlier run.

The added `planner_empty_sources_rejects` law states only that an empty
proposed source list cannot compare equal to any selected plan. The
[local proof record](verification/planner-empty-source-law/README.md) includes
a negative mutation and its limits. It authenticates no caller or plan and
does not establish any planner admission or commit.

These laws are in `LAWS.bend`, with implementations in `PROOF.bend`. They are
selected guard/state laws, not a proof of noninterference, whole-program
dependency completeness, cryptographic authentication, the compiler, or the OS.
The Bend policy/proof sources introduce no unsafe definitions or proof holes.
Inventoried C/C++ OS/runtime bindings and native probes are separate from these
laws; the ordinary proof check does not prove their correctness.

The earlier independent `--verdict` check **did not run successfully**. The official Lean
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

No Lean-kernel verdict was obtained in those earlier attempts. `kernel-verdict.txt`
keeps the three-law note and later attempts verbatim; the subsequent successful
`be649f6` verdict is recorded [separately](verification/lean-verdict-be649f6/README.md).
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
The historical core record covers 1942 checks, 41 HostBinding vectors and 37
portable-host vector lines on both CPU backends; all thirty-six ordinary laws pass. Linux native CI passes its actual mounts, fixed
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

The evidence-only follow-up Windows CI [run 42311706534](verification/windows-native-rerun-42311706534/README.md)
repeated the strict LPAC failure on source `1fcd29a`; its byte-worker probes
remain incomplete and receive no confinement credit. The separate diagnostic
passed and does not qualify the protected worker.

A separate, report-only Windows initialization diagnostic first failed to
[compile](verification/windows-init-build-42313479154/README.md); after the
header correction, an [isolated no-data run](verification/windows-init-observation-42313767360/README.md)
reproduced the byte worker's initialization error codes while its ordinary
controls and scoped cleanup completed. It used a different process and package,
did not isolate a cause, and supplies no protected-worker confinement credit.

An isolated Windows process-snapshot experiment first had a
[link failure](verification/windows-pss-build-42315743515/README.md). Its
[subsequent observation](verification/windows-pss-observation-42316163834/README.md)
matched two known handles in one suspended, ordinary synthetic child on one
runner. It is not an LPAC or byte-worker result, does not establish complete
environment equivalence, and supplies no host confinement credit.

A separate [LPAC snapshot observation](verification/windows-pss-lpac-observation-42317376618/README.md)
matched the two fixed synthetic handles in one suspended no-data LPAC child
and verified normal owned-filter cleanup. It did not run the real byte worker,
establish complete environment equivalence or qualify Windows confinement.

In a [same-lifetime no-data observation](verification/windows-pss-init-observation-42319102323/README.md),
two LPAC children each had the expected single synthetic report handle before
resume and then reproduced the initialization errors. Ordinary controls
succeeded. The observation does not establish cause, post-resume handle state,
complete environment equivalence or byte-worker confinement.

The automatic Windows native [run 42320010013](verification/windows-native-run-42320010013/README.md)
on source `82c51e8` failed the strict LPAC public-canary step. Its mounted reads,
revocation and native transport passed in their recorded scopes; byte-worker
network, clipboard and COM observations remained incomplete and receive no
confinement credit. The newly added optional standalone diagnostic was not run
by that workflow. The native evidence text and raw artifact hashes preserve the
outcome; generated policy JavaScript is not checked in.

An [exploratory no-data registryRead sequence](verification/windows-registry-ab-observation-42322440747/README.md)
observed Winsock `10107/0/0/10107` in A/B/B/A cases; USER32 and OLE32
initialization errors remained in every LPAC case. The child environments and
other OS state were not independently controlled, so this does not establish
cause, byte-worker confinement or host qualification.

An [exploratory no-data Win32k sequence](verification/windows-win32k-ac-observation-42323201217/README.md)
observed USER32/OLE32 load errors with Win32k calls disabled and zero load
statuses with calls enabled; Winsock returned `10107` in all cases. These
observations do not establish cause, GUI confinement or host qualification.

An [exploratory combined no-data sequence](verification/windows-combined-ad-observation-42323792791/README.md)
observed all three initialization statuses as zero in two LPAC children with
registryRead and Win32k calls enabled. Two settings changed together; this is
not evidence of cause, worker confinement or host qualification.

A [strict-worker research note](docs/superpowers/records/2026-11-06-windows-init/strict-worker-next-research.md)
describes a possible same-lifetime pre-admission feasibility review and its
transition and authority constraints. It establishes no fix or qualification
and authorizes no implementation or native execution.
