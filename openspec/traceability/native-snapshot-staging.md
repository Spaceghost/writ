# Native snapshot staging traceability

This records the private staging implementation and the
[archived native snapshot change](../changes/archive/2026-11-04-add-native-snapshot-staging/proposal.md).
It is not a native host, authenticated issuer, or durable-publication qualification.
The authoritative scope is [WritFS](../../writfs/README.md).

**Evidence state:** local model/typechecking and host-parser/runtime work is
separate from live native acceptance. Native run
[41748733557](https://github.com/Spaceghost/writ/actions/runs/41748733557) at source
revision `ede07df5ccaa08b4695788770d16b7eeb269d3c0` passed all 11 assertions in
[Btrfs job 126308199045](https://github.com/Spaceghost/writ/actions/runs/41748733557/job/126308199045)
and all 18 assertions in
[ZFS filesystem/zvol job 126308199296](https://github.com/Spaceghost/writ/actions/runs/41748733557/job/126308199296).
Both fixture cleanup steps returned zero. The
[Btrfs log](../../writfs/verification/native-btrfs.txt) and
[ZFS log](../../writfs/verification/native-zfs.txt) record those backend results.
Neither lane qualifies a complete enforcing host. The bounded native change
was reviewed and archived with all ten tasks complete.

Abbreviations in the table refer to [model tests](../../writfs/Tests.bend),
[host tests](../../writfs/HostTests.bend), and
[native integration](../../writfs/NativeIntegration.bend). Host evidence is
captured for [JavaScript](../../writfs/verification/host-js.txt) and
[native CPU](../../writfs/verification/host-native.txt).
The model's 78 named checks also pass in the recorded
[JavaScript](../../writfs/verification/native-model-js.txt) and
[native CPU](../../writfs/verification/native-model-native.txt) runs.

| Requirement | Implementation or contract | Named evidence | Coverage and limits |
| --- | --- | --- | --- |
| NS-001 | `Native.command_for`; `Host.execute`; supported CLI in `Main`; Bend source inventory | Model: “Btrfs preview contains only literal readonly snapshot argv”, “filesystem clone cannot auto-mount or inherit sharing”, “volume clone cannot expose a block device” | Source/typecheck and model assertions; no FUSE, general Open, or mount entry point. All three provider invocations passed the recorded native lanes. |
| NS-002 | `Identity`, `identity_valid`, `identity_equal`, `plan_matches`; `Host.declared_container`, `destination_valid` | Model: “native identifiers above uint32 remain valid”, “logical source version must match full plan”, “logical destination version must match full plan”, “pool GUID high bits are not discarded”. Host: “destination filesystem identity stays separate from its private parent locator”, “native identity decimals preserve all 64 bits and reject aliases/overflow” | Full-value parsing/comparison is executable. Authenticated registration and authoritative physical/logical mapping remain monitor preconditions. |
| NS-003 | `Native.source_valid`, `seal`; `Host.observe_btrfs`, `observe_zfs_snapshot` | Model: “writable Btrfs source cannot be sealed”, “nested subvolumes cannot masquerade as a complete source”, “ordinary subdirectory cannot authorize whole-subvolume copy”, “live readonly ZFS dataset is not an immutable snapshot”. Host: “ordinary Btrfs directories are not subvolume roots”. Native: “writable Btrfs subvolume is not an admitted immutable source”, “nested Btrfs subvolumes are rejected instead of silently omitted” | Parser/model checks and the recorded Btrfs/ZFS source-admission fixtures pass. No general recursive dataset-tree admission. |
| NS-004 | `Native.identity_text`, `seal_checked`, `seal`; shared `Sha256.digest_hex` | Model: “source generation high word is bound into artifact seal”, “artifact substitution including final word denied”, “native gate additionally binds exact native source seal”. Shared digest vector/boundary logs listed below | Executable manifest binding and SHA-256 vectors; explicitly no payload traversal/content-hash or independent execution-attestation claim. |
| NS-005 | `Native.authorize` → `DataOS.commit_from_capability`; `intent_matches`, `checked_command` | Model: “Btrfs action traverses complete Writ commit facade”, corresponding ZFS filesystem/volume assertions, “descriptor revocation is checked at final gate”, “another subject cannot reuse descriptor”, stale session/ledger/frontend assertions, “native backend requires Storage intent”, “accepted intent for another invocation cannot authorize command” | Shared facade/model checks. Public `Gate`/`Authorized` construction is not authentication, and `checked_command` is a consistency check. |
| NS-006 | `Host.check_destination`, `check_btrfs_results`, `check_zfs_fields`; `Native.command_for`, `output_controls` | Host: “Btrfs staging requires current ownership private mode same filesystem and absence”, “ZFS staging checks actual pool GUID and authoritative child enumeration”. Native: “a repeated creation cannot overwrite or adopt the existing target”, “ZFS stage remains unmounted”, “native zvol clone remains unexposed with volmode=none” | Host facts and command profiles tested locally. Native readonly/private-control and collision assertions passed both backend lanes. |
| NS-007 | Host selector/native-text parsers, `arguments`, `run`, `command_result`; pinned `Process.run` | Host: “native selectors reject traversal ambiguous components and command-looking names”, “Btrfs missing or duplicated identity fields fail closed”, “ZFS tabular metadata rejects wrong object duplicate properties and truncation”, “native utilities use fixed clean environment and literal argv”, “native subprocess overflow is failure never truncated success” | Actual subprocess output-bound checks passed on both backends, alongside parser checks. Native utility compatibility is scoped to the separately recorded backend runs. |
| NS-008 | `Host.preflight`, `inspect_created`, `finish`; `Native.complete`, `created_matches`; `Receipt` | Model: “stage receipt retains exact plan policy DLM label backend and artifact”, “Btrfs result must identify exact source parent UUID”, “ZFS clone must retain exact origin snapshot”, “post-authorization argv substitution denied”, “snapshot transaction source advance retains exact original authorized intent and seal”, “preflight still rejects any source generation change”. Native: “actual native stage retains complete source origin and restrictions” | Receipts passed both native lanes. For Btrfs, preflight remains exact; completion may change only source generation with `old < new == created.creation == created.generation`. The original seal and created facts remain recorded. |
| NS-009 | `Outcome`; `Host.execute_ready`, `mutation_result`, `reconcile`; `Native.reconcile`; monitor state-retention contract | Model: “same pathname and parent do not reconcile a different native object”, “reconciliation checks creation transaction as well as GUID”, “future source generation cannot reconcile an earlier snapshot receipt”, “terminal session cannot authorize another effect”, “consumed current reservation cannot be replayed from old session”. Native: “exact recorded native identity reconciles without creating another object”, “changed native mount controls invalidate the recorded private stage”, “exposing a zvol invalidates its recorded private-stage controls” | The created observation must match exactly; source reconciliation permits the original sealed observation or the single derived Btrfs transaction observation, without recording which branch completion observed. No durable journal, crash ownership adoption, atomic native/ledger transaction, automatic refund, or persistent replay service. |
| NS-010 | Scope/trust sections of WritFS; `NativeIntegration`; native CI workflow | Native: “Btrfs native snapshot contains the public fixture bytes”, “later live-source edits do not change the native snapshot”, “ZFS native clone contains the public fixture bytes”, “native zvol clone preserves the actual block payload”, and provider-specific kernel readonly assertions | Btrfs passed 11 and ZFS passed 18 native assertions, with both cleanup steps successful. Trusted single-writer/no hostile administrator and operator-supplied public fixtures are reviewed preconditions; the CLI does not classify payloads or authenticate an issuer. No confinement, revocation, durability, independent-kernel, GPU, or performance claim follows from these checks. |

## Shared digest boundary (RC-001 modification)

`contrib/rclone/bend/Digest.bend` delegates its existing public entry points to
`lib/Sha256.bend`. The implementation remains pure Bend. rclone-specific service
behavior and its isolated `contrib/rclone/go/go.mod` remain in the contribution;
the root library does not gain a Go dependency.

The existing payload digest semantics are checked by the recorded
[shared digest JavaScript run](../../writfs/verification/shared-sha-js.txt),
[native digest run](../../writfs/verification/shared-sha-native.txt),
[rclone model JavaScript run](../../writfs/verification/rclone-model-js.txt), and
[native rclone model run](../../writfs/verification/rclone-model-native.txt).
Representative retained assertions include “SHA-256 rejects a payload above
64 KiB” and “maximum body copy preserves artifact identity”. These tests do not
make the native source-manifest digest a payload checksum.

## Final review and deliberate exclusions

- Keep final source/evidence review and archival separate from these passing
  checks. The recorded local runs include 78 model, 17 Host, 25 shared-digest,
  74 rclone-model, and 638 core assertions on each of JavaScript and native CPU,
  plus the ordinary three-law proof check.
- Retain both native lanes with their kernel, utilities, runtime, source
  revision, payload/control assertions, and cleanup evidence. Missing kernel
  support or a failing assertion is a failed lane.
- Preserve the Btrfs pre-mutation full-generation check and permit only the
  verified transaction relation at completion; a later unrelated generation
  remains a reconciliation failure.
- Keep hostile-administrator path/property races and ZFS mutate-then-restore
  outside the trusted-writer claim; identity/current controls are not a content
  history proof.
- Keep issuer, worker confinement, presentation, revocation, durable publication,
  crash recovery, and paid-operation recovery in their existing pending work.

Strict OpenSpec validation checks document structure, not those host guarantees.
