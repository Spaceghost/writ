# Frontend V2 integration dependency map

An owner of a legacy handle at revision `2^48−1` still needs to close it.
Replacing that Nat with two words in `Frontend.State` alone cannot safely make
the close available: the monitor must first install the exact migrated state
and fence old requests, while every coupled binding and channel must know which
version of the instance it addresses. This map describes implementation work;
it does not implement or authenticate the transition. The existing terminal
failure remains open, including for snapshots too large for the synthetic
eight-handle conversion profile.

## One authorization path

Refactor the existing `Frontend` implementation rather than adding a second
release-capable frontend. Its state, expected revision, lifecycle and result
types must distinguish active V2, legacy and retired instances. Exactly which
legacy representation remains callable before migration is an implementation
choice, but it must keep the old state authoritative until a serialized
installation succeeds; after installation, a V1 request must not be translated
into a fresh V2 request. A type tag or a public constructor is not a monitor
fence or proof that a state is current. Any data-only conversion helper is
unable to authorize a release or install its own candidate.

`mount`, `open` and `dup` each allocate one open handle and advance once;
`attenuate` advances once without changing the open count; `close` advances
once and tombstones one open handle. `checked_plan` is read-only and must not
be denied just because allocation reserve is exhausted. Add retirement as a
distinct monitor-owned lifecycle transition only after its authority and
instance fence exist. Every successful mutation uses the original complete
handle list and checked arithmetic; denied mutations return the original
state. Preserve the owner/token close rule even after expiry or revocation and
preserve all operational registry, token, exact plan, epoch, expiry and rights
checks. Existing `valid`, `find_handle`, registry checks and plan equality
traverse nested records; a real admitted profile needs bounds and resources
for those checks as well as the reserve count. An incomplete scan is not
proof that an old snapshot is invalid, or that its owner has been cleaned up.

The active invariant is `D >= O+1`, where `O` counts every original open
handle and `D` is the checked two-word distance to the maximum. Allocation
needs `D >= O+3`, attenuation `D >= O+2`, and close must retain the resulting
active invariant. No request-supplied count, Boolean, work list or provisional
overflow result supplies these facts. Node's eager evaluation also requires
unsafe arithmetic and unbounded traversals to be staged in actual matched
success branches. Bounded tests alone do not reserve host cleanup resources.

## Coupled call sites and atomicity

| Source | Required change or constraint |
| --- | --- |
| `Frontend.bend` | Refactor state/revision and all five mutation entries together; keep one `authorized`/`checked_plan` policy path and unchanged denial state. Guard checked successor before constructing a changed state. |
| `DataOS.bend` | Carry a tagged expected frontend revision into `checked_plan`; preserve exact plan and authenticated reader comparisons followed by the same Backplane commit gate. |
| `AuditEvent.bend` | Pass the tagged expectation unchanged through `audited_commit`; retain the same single DataOS result and audit policy. |
| `HostPublication.bend` | Change `Attempt.expected_frontend` and `publish` together; the resolved identity caller and entry handle still go through DataOS and the existing artifact/plan checks. |
| `HostPrimitives.bend` and `HostIdentity` | `issue` reads the monitor's frontend handle without an expected frontend revision. Instance-bind and revalidate the resulting identity entries and sessions; do not mistake its existing defense-in-depth lookup for authenticated current-state serialization. |
| `HostBinding.bend` | Version and fence **all** public binding operations, including delegation and revoke, against the monitor-owned active frontend instance/version while preserving the independent binding revision and authority checks. The existing operations internally use `F.revision(frontend)`; that substitution must not turn a queued V1 binding request into a V2 request. |
| Examples and adapters | Migrate `examples/Commit.bend`, `writfs/MountAuthority.bend`, `contrib/rclone/bend/Authority.bend`, synthetic HostConformance and associated tests to the same typed facade. A constructed fixture is not an authenticated migration. |
| Genode and Unikraft monitors/channels | Their V1 request carries `expected_session`, not an expected frontend revision. Their replies narrow descriptor and frontend revision to one U32. Specify a versioned exact codec and fencing, or explicitly refuse an incompatible profile before committing; never report truncated words as an exact V2 identity. Preserve route-subject provenance. |

`HostBinding.bind_attenuate` is a two-step composition: it duplicates a
descriptor (`R+1`, `O+1`), then attenuates that duplicate (`R+1`, unchanged
`O`). Its full success needs initial `D >= O+4`. At `D = O+3` the provisional
duplicate may pass while attenuation must fail; the whole binding and frontend
input, quotas and effects must remain unchanged. Other composite paths need
their own exact prospective accounting, not a single-operation assumption.
The [composite reserve design](design.md#composite-binding-and-frontend-reserve)
specifies the complete threshold and rollback cases.

`bind_close` currently closes a directly bound handle, then `close_doomed`
retains the prior frontend whenever a derived close rejects, and finally
destroys the cut and refunds quota. V2 must independently verify the full
original transitive binding cut, deduplicate aliased handles, preflight every
required close and all binding revision, generation and refund arithmetic,
and commit both states only if all succeed. A candidate work list is not the
original cut. `revoke` has no frontend caller and does not gain authority to
close a handle from this refactor.

## Migration and qualification sequence

1. Define bounded codecs and monitor-owned admission covering complete
   frontend, binding, registry and nested plan records. The profile must
   provide the work and recovery resources needed for every promised cleanup.
   Oversize or incomplete legacy states remain explicit recovery obligations;
   the eight-handle/eight-source synthetic checker is not a general migration.
2. Independently compare the entire admitted original frontend and coupled
   binding state against the candidate, preserving all fields, order,
   tombstones, allocation watermarks and the exact mapped V1 revision. The
   check must not trust the producer's work list, supplied count or digest.
3. Serialize against writes and authenticate the control operation using
   monitor-owned identity. Atomically install the verified state, active
   instance/version fence and replay history, with an independently protected
   rollback-resistant recovery record. Preserve the original state on failure;
   an ambiguous outcome requires authoritative recovery. Existing public Bend
   values and caller-provided flags cannot provide these guarantees.
4. Bind sessions, persisted references and binding requests to that
   non-reused instance. Fence queued V1 requests and safely version channels
   before routing any V2 request. A freshly authenticated V2 owner must still
   be able to close the exact preserved handle after expiry or revocation.
5. Refactor the existing policy and facade call chain together, add original
   cut and resource checks, and exercise boundary, stale-tag, exact-field,
   authority, incomplete-scan, old-terminal cleanup, multi-step rollback and
   failure-position controls. Retain full Bend/Node/native CPU, existing Lean,
   relevant native and OpenSpec evidence with their actual limits. No current
   host supplies the authenticated installation or rollback witness described
   above, so a pure model or a passing channel fixture cannot qualify it.

The proposed [tasks](tasks.md) and [traceability](traceability.md) remain open;
this sequencing note changes no law and claims no completed migration, native
host qualification, or owner cleanup at the legacy terminal revision.
