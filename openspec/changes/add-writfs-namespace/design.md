# WritFS design

## A report and its summary

A session can read an approved report, submit its approved summary operation, and
inspect the resulting job. A directory scan only shows authorized names; it does
not run the summary or spend its budget. The summary becomes readable after the
same sealed-artifact and current-authority checks used by other Writ frontends.

These paths illustrate the interface, not a finalized wire schema:

| Path | Meaning |
| --- | --- |
| `/writ/data/report/content` | An alias for one approved object version |
| `/writ/views/summary` | The registered view and its materialization state |
| `/writ/jobs/42/state` | A scoped snapshot of this session's job |
| `/writ/jobs/42/result` | The authorized, committed result, when available |
| `/writ/self/scope` | A filtered description of the session's effective rights |

Job receipts, bounded event streams, limits, and the control channel are exposed
through the same session. Their names and contents are policy outputs too.
Illustrative job number `42` is a session-local name, not a portable credential.

## What exists

[Frontend.bend](../../../Frontend.bend) supplies the pure mount/descriptor model;
the [capability baseline](../../specs/capability-frontend/spec.md) describes its
live checks and exact-plan binding. There is no native WritFS mount or proc server.
The [host contract](../add-portable-host-contract/design.md) and
[platform architecture](../../../docs/PLATFORMS.md) define the enforcement work
needed before delivering protected plaintext.

## Names and authority

Each namespace is bound to an authenticated session. Its data entries and jobs
refer to separately admitted immutable plans; the namespace does not turn one
plan's capability into a general bucket or host-filesystem capability. A broader
view must be composed from explicitly authorized entries.

Pass tokens through the authenticated protocol, never in pathnames, arguments,
directory entries, or diagnostics. Bind references to the host incarnation and
resource generation. Traversal, aliases, and native reconfiguration cannot replace
the object version, operation, subject, or destination in an approved plan.

Protected metadata has its own source, schema, and delivery scope. A metadata
grant need not permit content access, and a content grant need not reveal every
origin's name. Listings, statistics, status, receipt reads, and subscriptions use
the same current authorization path as other disclosures. No session can supply
its own authoritative subject, ledger, grant registry, or result binding.

## Reading and submitting

The first profile requires explicit materialization. Listing, stat, open, preview,
and status reads do not execute a view. Reading an unmaterialized result reports
pending; reading a materialized result still checks current release authority.
A future version may negotiate lazy execution on read with explicit budget and
effect authority, but it is not a fallback in this profile.

Control messages use a versioned, bounded canonical encoding. An accepted request
binds the session, complete operation, request identity, and expected revision.
Partial writes stage bytes only. A complete submit message establishes the
transaction; close and flush do not invent a submit or final publication.

An identical retry returns the existing operation's status or receipt if the
caller may currently observe it. Reusing the request identity with different
contents is rejected. A new mutation checks the current revision, and denial
leaves authoritative operation and budget state unchanged. No generic control
write grants permission to cancel another job or retire another object.

## Results and introspection

Writes create private staging objects. Native rename, synchronization, or a
successful filesystem write cannot publish them without the durable Writ commit.
Copies and derived views retain required origin records and effective output
restrictions. A different alias or destination name cannot erase that policy.

Status files give a coherent, bounded snapshot per admitted read. Event streams
carry scoped sequence numbers and report overflow explicitly rather than
silently omitting state. Stream delivery, cached results, and retained descriptors
remain subject to current authority. Revocation can stop further reads; it cannot
recall bytes already released to an authorized reader.

Allocate sequence numbers after recipient visibility filtering. Hidden events do
not leave observable holes in another recipient's stream. Pending, overflow, and
gap markers obey the same disclosure scope as ordinary status; a marker cannot
become a second way to count protected work. Already authorized durable delivery
recovery follows its original intent; a new read or subscription needs live
authorization rather than borrowing that recovery permission.

The proc-like interface describes Writ jobs and session limits. Raw process memory,
environment variables, global job counts, unrelated provider identities, and
unapproved intermediate results are not exported. Data-dependent errors, counts,
timing, and progress are covered by the declared disclosure profile; the presence
of a synthetic filesystem does not establish a universal covert-channel claim.

## Native adapters

Keep namespace and operation rules in Bend. A Genode VFS plugin, Linux frontend,
or Windows frontend translates file operations into the trusted service protocol;
client-side code cannot be the sole authority check. Protected input delivery
still requires whole-worker confinement, including logs, inherited handles,
network routes, devices, and caches.

Each supported profile defines its actual file semantics. Initially deny mappings,
handle transfers, accelerated copies, links, or other routes without demonstrated
scope preservation. A namespace unlink does not mean revocation or cooperative
purge. Those effects require distinct authorized operations; unsupported control
verbs fail without effects. This is not a promise of full POSIX behavior.

Genode's private VFS plugin model is a useful presentation mechanism. Its 26.08
path handles may reopen their underlying objects during reconfiguration, so Writ
must retain object/version identity independently of the native path. Plan 9's
synthetic namespaces are an interface precedent; remote operations still require
transport, authentication, and distributed failure handling. Sources:
[Genode VFS](https://genode.org/documentation/release-notes/26.08) and
[Plan 9 namespaces](https://9p.io/sys/doc/names.html).

## First acceptance run

Show one report, an explicitly submitted summary, a scoped status read, and an
authorized committed result. Then demonstrate that directory scanning does not
launch work, alias rebinding cannot change the input, a duplicated request cannot
publish twice, and revocation prevents new unauthorized result reads. Recovery of
an already-durable delivery retains its exact scope. Record the native profile
tested; pure Bend vectors and a successful mount do not prove confinement.
