# Native snapshot staging design

## Scope and effect boundary

Use the existing filesystem implementations as native copy engines. Btrfs
creates a read-only snapshot of a read-only leaf subvolume on the same
filesystem. ZFS clones an existing snapshot of a leaf filesystem dataset or
block volume within the same pool. The resulting stage remains read-only and
private. There is no general mount, plaintext Open, file-copy fallback, writable
workspace, arbitrary transform, or durable publication operation in this slice.

All authored planning, validation, authority decisions, sequencing, and tests
stay in Bend. `Host` invokes installed upstream utilities using `Process.run`;
it does not add a C/Go binding or a second policy implementation. Native
metadata inspection has subprocess overhead; this change makes no benchmark
claim and does not proxy ordinary file/block I/O through Bend.

## Authority ownership and identity

The trusted single writer owns source registration, private staging roots,
executable search directories, native administration, authenticated subject
context, dependency graph, capability registry, session, and ledger. It maps
logical `Transfer.ObjectVersion` values to native resources. Callers cannot
choose that mapping by supplying a pathname or a well-formed UUID.

Btrfs identity retains filesystem UUID, subvolume UUID, root ID, generation, and
creation generation. ZFS retains pool GUID, object GUID, creation TXG, and the
provider type. Native uint64 values use canonical decimal strings; logical IDs
remain a separate namespace. `Destination.container` is the expected FSID/pool
GUID. Its registered `locator` names the destination, and the host derives the
private parent from that locator.

The source must be a complete native unit. Host inspection checks a Btrfs root
inode and native metadata; an ordinary subdirectory cannot impersonate its
containing subvolume. Nested Btrfs subvolumes are rejected because a snapshot
would omit them. The ZFS source is a snapshot rather than a live dataset, with
the parent dataset's type and leaf status observed separately.

## Source seal and common authorization

`Native.seal` hashes a versioned canonical descriptor containing the provider,
full source identity, locator, origin, and admitted source flags. The hash is a
source-seal manifest identity, not a payload checksum or filesystem attestation.
`lib/Sha256.bend` supplies the same pure digest primitive used by the rclone
compatibility wrapper. The rclone service continues hashing actual payload
bytes; native manifest hashes are not interchangeable with those content hashes.

`Native.preview` validates the source, provider, logical input/output versions,
provider-specific operation identity, destination scope, and exact manifest
digest. It returns descriptive argv only. `Native.authorize` then calls
`DataOS.commit_from_capability` with current monitor-owned state and requires the
accepted intent to match the complete plan, Storage backend, and source seal.
The returned authorization retains the facade's session, ledger, and entire
write intent, including policy, DLM label, and provenance.

Public `Gate`, `Authorized`, and `Receipt` constructors are descriptions.
`checked_command` checks structural consistency; it neither authenticates
caller-built records nor replaces the capability-to-commit facade. The physical
destination mapping is an authoritative monitor input, not a credential encoded
in the source seal. The example CLI is explicitly limited to public fixtures.
That content classification is an operator precondition; the CLI neither
classifies payloads nor authenticates an issuer.

## Native sequencing and private stages

`Host.execute` re-observes the expected source and validates the destination
before a mutation. The Btrfs parent is canonical, owned by the effective UID,
mode `0700`, and on the registered source filesystem. The ZFS parent is an
existing unmounted filesystem with `canmount=off`, `mountpoint=none`, and sharing
disabled. Existing targets, including dangling Btrfs symlinks, are refused.

The only generated mutations are:

| Provider | Operation and output controls |
| --- | --- |
| Btrfs | `subvolume snapshot -r` under the private parent |
| ZFS filesystem | `clone` with `readonly=on`, `canmount=off`, `mountpoint=none`, `sharenfs=off`, and `sharesmb=off` |
| ZFS volume | `clone` with `readonly=on`, `volmode=none`, and `snapdev=hidden` |

The host re-observes the source, created object, and private parent after the
command. It checks actual created identity, source parent/origin, native kind,
readonly/leaf/root status, and presentation controls. A pathname appearing after
the command is insufficient to report success. A successful receipt retains the
exact accepted intent and native identities needed for later comparison.

Btrfs native snapshot creation can update source-root transaction bookkeeping
while leaving its read-only contents unchanged. Pre-mutation source equality
remains exact. At completion, the only permitted changed source field is its
generation, with the strict relation `old < new == created.creation ==
created.generation`. All other source fields remain equal. The receipt keeps the
original source seal and the created object's full native facts, from which the
allowed changed source generation can be derived. Reconciliation permits the
original sealed observation or this single derived transaction observation;
the receipt does not record which branch completion observed. A later unrelated
generation is rejected. Dropping generation fields or accepting arbitrary
changes is not a compatibility fix. Diagnostic native evidence established this
transition, and the corrected Btrfs acceptance lane passed with this rule.

## Bounded tool boundary

Commands use literal argv through `/usr/bin/env -i` with `LC_ALL=C` and
`PATH=/usr/sbin:/usr/bin:/sbin:/bin`. Native locators use the documented ASCII
subset, a 512-character bound, and unambiguous components. No shell interprets a
locator, and no caller-supplied executable or general command is exposed by the
administrative entry points.

Each subprocess has a 15-second limit and a 65,536-byte combined stdout/stderr
limit. The pinned runtime returns failure on overflow rather than a successful
prefix. Structured native text is parsed under the fixed locale; selected
identity fields must be complete and unambiguous. Host errors contain fixed
codes rather than raw subprocess output.

## Failure, concurrency, and recovery

Before a native mutation, a failed check returns `Refused`. After a mutation has
been attempted, a failed command, timeout, incomplete observation, or invalid
postcondition returns `Unknown`. A private object may already exist. The adapter
does not delete it, retry the command, adopt an object by pathname, or claim a
rolled-back transaction.

`Host.reconcile` requires an already recorded receipt and rereads source/result
native facts and private controls. The created observation must remain exact;
the source must satisfy the original-or-derived rule above. Reconciliation
performs no creation or publication. An unrecorded result after a crash cannot
be authenticated merely by discovering a matching name. It checks present
identity and controls; it is not a durable replay journal.

The monitor retains the session and ledger returned by authorization even if the
native operation subsequently fails. Model state and native storage are not one
atomic transaction. Reconstructing an old gate, automatically refunding a
reservation, or replaying an uncertain operation would exceed this contract.
Durable coordination and paid-operation recovery remain separate work.

## Trust limits

Canonical path checks do not pin directory descriptors against a hostile
administrator. Native roots, pools, mappings, and readonly flags belong to the
trusted administrative writer. In particular, ZFS clone GUID and `createtxg`
identify creation rather than current contents: privileged mutate-then-restore
of readonly or presentation properties is outside the guarantee.

No mount, native device, or passing copy test establishes authenticated callers,
complete worker egress mediation, revocation of already issued handles, or
durable publication. Those requirements remain in their existing host packages.

## Acceptance and migration

Model tests exercise exact scope, full identities, common-facade denials,
command substitution, receipt preservation, and reconciliation. Host tests cover
native text, private parent checks, and the real subprocess output bound.

The separate native workflow uses fresh regular-file-backed storage on a
disposable Linux runner. Bend assertions check actual fixture payloads, kernel
readonly behavior, collisions, retained restrictions, and control changes.
Only the test harness may temporarily expose its public ZFS fixtures to inspect
payloads; that exposure must invalidate the previous private-stage observation.
Missing native kernel support fails the lane. Cleanup is limited to resources
successfully created by that job.

Native run `41748733557` at source revision
`ede07df5ccaa08b4695788770d16b7eeb269d3c0` passed all 11 Btrfs assertions in job
`126308199045` and all 18 ZFS filesystem/zvol assertions in job `126308199296`;
both fixture cleanup steps returned zero. Final source/evidence review retained
the stated private-stage scope. The verification record identifies the runtime,
kernel, utilities, and captured backend results.
No production storage is migrated, formatted, imported, deleted, or exposed by
the adapter's CLI.
