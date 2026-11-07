# Bounded binding snapshot description comparison

A supplied candidate that drops a historical binding, changes a stale alias's
generation, or alters a route subject must not compare exactly to the supplied
original. This standalone comparator examines the original binding revision,
object and alias allocation watermarks, and all fields of six ordered original
and candidate lists: objects, aliases, routes, quotas, delegations and bindings.
It independently invokes the existing frontend candidate checker. It never
uses a producer's work list, count or digest to select original records.

Each binding list is limited to eight original and eight candidate records;
the frontend checker separately limits handles and each plan's source list to
eight. Traversal continues after a mismatch, so an over-cap tail produces
`Incomplete`, which takes precedence over `Mismatch`. Exceeding this synthetic
profile is not proof that a legacy snapshot is invalid. The existing frontend
checker can report mismatch for an invalid original frontend even when its
description matches; the new comparator does not check `HostBinding.valid`.
Identical malformed binding graphs can return `ExactDescription`. That result
is not authentication, structural admission, a migration, rollback fencing,
resource reservation or host qualification. Caller-forged intermediate helper
results are not gates; only `check` is the intended descriptive entry. Task
2.1 and FR-006 remain open, including external registries and replay state.

The 111 focused checks cover each record field and watermark, valid delegated
and derived history, stale aliases and closed handles, altered transitive
edges, omitted/duplicated/reordered records in all six lists, original and
candidate over-cap tails and forged fuel, malformed-identical binding graphs,
and frontend mismatch/incomplete propagation. Bend and Node outputs match at
SHA-256 `deb811cdce8da8247e91750ee767ac56127cfc88629c8abb99adda4d867fbf95`.
The full 2,809-check Bend and Node outputs match at SHA-256
`ff9b11443479d5338225ac55649f939b89ab637e5a707549afda11b6b11ed96c`.

The 136-source [input inventory](bend-inputs.sha256) includes source
`2378a847c96e34e067e45403d8263c893e2442c8bada464bfeb6473b1be93633`,
focused tests `fdc140eb6d0bdc798bf3b2aaa322ad208b0aa917121c0e4f2aafb096179ae4ea`
and root driver `d25415c9d4610209e23fba9af4c6fcb782afaea78eced63103b0911d8fbab06b`.
The [existing proof verdict](proof.log) used Bend 2.0.39 executable SHA-256
`2ec160fa4486d33aff51e9eedcc294d6b531dc10c279c00b0c00685dae2045cd`
and the previously built Lean-backed kernel selected via `BENDTT`, SHA-256
`e365eba1741602bb45261aa0eb6bd2c6f5db885d4b9d4cd603a27bc3c5a9ed18`;
[stderr](proof.stderr) is empty. Existing laws do not prove this comparator.
Focused C generation succeeded; generated code is outside the source package.
The 49 retained [mutation patches](mutants/) exercise every binding field and
scalar, all six list clamps, hookups and tail traversals, incomplete
precedence, and frontend result propagation. Each fails a named assertion on
both Bend and Node; raw outputs, stderr and exits are retained. This is a
control set, not a completeness proof. The evaluated Nix source filter and
assertion gate are described in [nix-evaluation.txt](nix-evaluation.txt).

The optimized native build and explicit GPU-off CPU run completed successfully.
Its [output](native.log) matches the full Bend and Node logs byte-for-byte,
with 2,809 PASS lines. [Build stdout](native-build.log),
[build stderr](native-build.stderr) and [run stderr](native.stderr) are empty.
The 136 input hashes were checked before and after the build and run. This is
CPU evidence, not GPU verification.

Separate synthetic native checks passed: [24 allocator invariants](allocator.log)
under ASan/UBSan and the owned-temp capture-to-Bend/Node [handoff](handoff.log).
Their stderr logs are [allocator](allocator.stderr) and [handoff](handoff.stderr).
They do not test a native frontend or authenticate a host. Strict OpenSpec
validation is retained in [openspec.log](openspec.log).
