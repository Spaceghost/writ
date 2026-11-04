# Cooperative retirement design

## Retiring a report

An origin's agreed terms require report A version 7 to be retired from enrolled
participants. The accepted request names its managed replicas, derived views,
search indexes, caches, and applicable backup policy. Each participant stops new
affected authorization, reconciles in-flight work, and reports its own disposal
result. One offline participant keeps the overall request incomplete.

The receipt can say that the named managed scope was retired using a specified
method. It cannot establish that an unknown recipient never copied the report.
That difference is part of the result schema, not a footnote added after deletion.

## What exists

[Frontend.bend](../../../Frontend.bend) supports closing modeled handles; it does
not erase files or invalidate every independent copy. The
[host contract](../add-portable-host-contract/specs/portable-host-contract/spec.md)
defines native revocation and quiescence obligations, and
[durable publication](../add-durable-publication/specs/durable-publication/spec.md)
defines the authorization race boundary. This package adds the proposed retirement
protocol above them. All implementation tasks remain pending.

## Name the effect

| Effect | Promise |
| --- | --- |
| Unlink | Remove an authorized namespace binding |
| Revoke | Stop newly unauthorized access or publication at the affected authority boundary |
| Retire | Coordinate the described inventory, authority barriers, and participant outcomes |
| Purge | Dispose of named managed material using a specified supported method |

These actions require distinct grants. A read, write, search, or match grant does
not authorize destruction. A retirement grant can identify a protected object
without granting its payload to the requester. Use new versioned control records;
do not reinterpret the current copy/transform/summarize flags as deletion rights.

The request pins the authenticated requester, exact object versions, participants,
required derivative coverage, retention terms, deadline, disposal guarantee, and
receipt recipients. Participants validate current authority and prior obligations;
the caller cannot invent an origin's consent or retroactively widen a grant.
Inventory expansion outside the accepted scope requires authorization.

## Find the managed copies

Inventory is a protected graph over the enrolled storage and execution domains.
It includes aliases, replicas, private staging, worker state, result caches, search
indexes and match features, selected derivatives, and the backup locations covered
by the request. A filename listing is not evidence that this graph is complete.
Unknown inventory coverage is recorded explicitly and prevents a complete claim.

Inventory traversal has work and disclosure bounds. A participant may return a
scoped opaque reference or aggregate outcome instead of another owner's filenames.
Exhaustion leaves the request incomplete; it cannot silently shrink the requested
scope or broaden access in order to finish a scan.

## Stop new use, then dispose

At each authority domain, serialize a durable retirement barrier with new access,
grant issuance, and publication authorization. An affected operation not yet
durably authorized cannot cross that barrier using old authority. An operation
already durably authorized must be reconciled under the existing publication
protocol; retirement must not rewrite its committed destination, payment, or
artifact. If it reaches an enrolled destination, include the delivered artifact
in the already-authorized retirement scope or report the remaining gap.

An offline participant has not acknowledged this barrier. Its status stays
pending or unknown; a coordinator's local revocation does not prove that every
remote lease or independent earlier copy has stopped working.

Quiesce affected workers and asynchronous I/O before reclaiming memory or storage.
Device reset or DMA-stop failure can require retaining an isolated allocation.
Old generations cannot publish or mutate a reused resource. Lack of quiescence
blocks the corresponding disposal claim instead of freeing memory unsafely.

## Describe the guarantee

Every purge outcome names its disposal method and evidence. Removing names,
dropping a cache reference, denying a grant, cryptographic erasure, and physical
storage sanitization are different guarantees. A participant that only supports
logical retirement cannot claim a stronger requested guarantee.

Cryptographic erasure requires the relevant key material and recovery copies to
be covered by the supported method. Removing one key reference is insufficient.
Shared storage also matters: retire the authorized references without destroying
bytes or keys still required by unaffected grants. If shared references prevent
the requested stronger disposal, report that limit rather than hiding it.

Derived data keeps its origin records and effective restrictions until it is
retired or replaced through a separately admitted regeneration. Deleting a source
row does not establish that an aggregate or trained model has lost its influence.
A replacement requires its own source manifest, authority, and publication; the
old artifact remains in the retirement inventory until resolved. No provenance
record is stripped to make remaining data appear unrelated.

## Receipts and recovery

Keep per-participant states for requested work, installed access barriers,
quiescence, disposal, pending/offline work, and authorized retention exceptions.
The overall status is complete only for the requested guarantee and scope when
every required participant has acceptable current evidence. A deadline produces
an overdue result, not a synthetic success.

Authenticate receipts and bind them to the request, participant identity and
incarnation, exact versions, authority epoch, method, coverage, and outcome.
Receipt access has a separate disclosure scope. A signature authenticates a
participant's statement; it is not proof that all possible copies were erased.

Keep the full authenticated receipt in protected coordinator state and provide
each recipient only its authorized projection. A shared-storage limitation may
be reported without disclosing another owner's identity, object names, or
reference counts. The projection must still truthfully distinguish completion
from pending work or an unmet disposal guarantee.

Persist minimal protected tombstones, authority epochs, replay records, and
necessary provenance. Do not create fresh payload copies in retirement logs.
Recovery and restored backups reconcile against current retirement state before
serving affected data. If that state cannot be established, affected delivery is
denied; an old snapshot cannot silently resurrect its grants.

Retain deduplication evidence after disposal. If a receiver accepted a publication,
lost its acknowledgement, and then retired the artifact, a sender retry reconciles
that old outcome without recreating the object. An acknowledged publication's
retry cannot bypass the receiver's retirement tombstone.

Requests are bounded, canonical, and idempotent. Identical retries return the
existing scoped outcome when authorized; changed reuse of an identity is rejected.
A new request checks current revisions, and rejected mutations leave operation
and accounting state unchanged. Cancellation stops work only within its grant and
does not undo installed revocation barriers or resurrect purged data.

## First acceptance run

Use one report with a managed replica, a cached summary, a search entry, and a
backup. Retire it while a job runs, restore the old backup, and retry the request.
Show no new unauthorized publication, no backup resurrection, and one durable
outcome per participant. Then take one participant offline and retain one shared
storage reference: both limitations must remain visible in the scoped receipt.
