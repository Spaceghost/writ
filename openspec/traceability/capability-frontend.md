# Capability frontend traceability

Baseline: [capability-frontend](../specs/capability-frontend/spec.md).
Implementation: [Frontend.bend](../../Frontend.bend) and the combined entry point
in [DataOS.bend](../../DataOS.bend).
Executable cases: [FrontendTests.bend](../../FrontendTests.bend) and
[FacadeTests.bend](../../FacadeTests.bend).

| Requirement | Implementation | Existing named executable evidence | Coverage boundary |
| --- | --- | --- | --- |
| CF-001 | `registry_valid`, `capability_valid`, `valid`, `handles_valid`, `handle_valid` | `duplicate capability token is ambiguous and invalid`; `malformed registry denies mount`; `malformed registry denies resolution`; `malformed registry rights deny`; `capability epoch must match immutable plan epoch`; `duplicate descriptor IDs invalidate state`; `next descriptor ID must exceed every allocated ID` | Executable malformed registry and state cases. These checks validate structure; they do not authenticate an untrusted state record. |
| CF-002 | `mount`, `capability_current`, `find_capability` | `capability mounts as a protocol handle`; `all 256 token bits participate in lookup`; `token possession does not change bound subject`; `mount cannot amplify registry rights` | Executable subject/token/rights cases. Caller authentication and capability issuance are external. |
| CF-003 | `open`, `open_found`, `resolve_found`, `is_mount`, `is_descriptor` | `mounted capability opens a descriptor record`; `open cannot amplify mounted rights`; `mount handle itself cannot perform an operation`; `descriptor is not a mount alias` | Executable handle-kind and opening-rights behavior. Returned descriptors are records, not OS descriptors. |
| CF-004 | `insert_handle`, `insert_copy` | `mount allocates first monotonic ID`; `open allocates next descriptor ID`; `dup allocates a distinct descriptor ID` | Executable identifier allocation. Revision/counter updates are also directly source-reviewed. Durable serialized allocation is not implemented by this pure state. |
| CF-005 | `dup`, `dup_found`, `copy_handle` | `descriptor duplication succeeds under live authority`; `dup preserves exact token and plan scope`; `duplication preserves attenuation`; `mount is not a duplicable operational descriptor` | Executable duplication and preservation cases. |
| CF-006 | `attenuate`, `attenuate_found`, `restricted`, `replace_handle` | `descriptor rights may be attenuated in current state`; `attenuated read right remains usable`; `attenuation removes write right`; `attenuation removes execute right`; `attenuation cannot restore removed rights`; `zero-right descriptor authorizes no read` | Executable narrowing, no restoration, and zero rights. The independence of a previously created duplicate during attenuation is source-reviewed; lifecycle independence under close is executable under CF-013. |
| CF-007 | `authorized`, `authorized_found`, `scope_current` | `removing registry capability revokes existing descriptor`; `revoked descriptor cannot duplicate itself`; `registry rights reduction invalidates wider existing descriptor`; `shortening registry expiry invalidates older broader handle`; `authority epoch change invalidates open descriptor`; `expiry is exclusive at exact deadline`; `expired descriptor cannot duplicate itself` | Executable revocation, contraction, epoch, and deadline cases. Contraction invalidates the wider stored handle rather than silently mutating it. |
| CF-008 | `scope_current`, `checked_plan`, `resolve_found` | `read request resolves exact immutable plan`; `write request resolves same exact plan`; `registry replacement cannot redirect existing descriptor plan`; `altered descriptor plan disagrees with trusted registry` | Executable exact-plan behavior; the request datatype exposes no replacement-plan field. |
| CF-009 | `request_rights`, `resolve_found` | `execute resolves exact plan with all rights`; `attenuation removes write right`; `attenuation removes execute right`; `zero-right descriptor authorizes no read`; `zero-right descriptor authorizes no write`; `zero-right descriptor authorizes no execution`; `execution requires execute right as well as read and write` | Executable request-right cases. Read=1, write=2, execute requires all bits in 7. |
| CF-010 | `resolve_gate`, `checked_plan`, transfer `admit` | `read request still requires destination write approval`; `write request still requires exact source read approval`; `capability cannot bypass inherited payment requirement` | Executable operation-admission pairing. Mount/open alone do not run transfer admission and are not protected reads. |
| CF-011 | `mount`, `authorized`, `close`, mutation gates | `stale revision cannot resolve operation`; `stale revision cannot duplicate descriptor`; `rejected mutation leaves revision unchanged` | Executable stale revision and retained revision cases. Complete unchanged-state preservation follows directly from returning the supplied state; no external compare-and-swap is provided. |
| CF-012 | `close`, `close_checked`, `close_found`, `ref_matches`, `closed` | `closing descriptor records tombstone`; `another subject cannot close descriptor`; `another token cannot close descriptor`; `close replay denies` | Executable ownership and close-replay cases. Cleanup after revocation or expiry is source-reviewed: close deliberately does not consult registry/time. A [synthetic maximum-revision case](../../docs/superpowers/records/2026-11-07-frontend-revision-exhaustion/README.md) raises a Nat-range error instead of completing owner cleanup; migration and a repair are unimplemented. |
| CF-013 | `close`, `closed`, `ref_matches`, `insert_copy` | `closed descriptor cannot resolve`; `closed descriptor cannot duplicate`; `closed descriptor cannot be reactivated by attenuation`; `closing one descriptor preserves independently duplicated descriptor`; `new open never reuses tombstoned descriptor ID` | Executable tombstone and independent duplicate lifecycle cases under authoritative current state. |
| CF-014 | `DataOS.commit_from_capability`, `commit_resolved`, `commit_allowed` | `facade links capability descriptor through complete commit`; `facade preserves output provenance`; `authenticated subject must be negotiated reader`; `capability revocation is checked at commit`; `revoked capability spends no reservation`; `capability possession cannot override label denial` | Executable integrated decision path. The actual payload write and durable transaction remain host integration work. |

## Scope limits

The protocol never returns protected plaintext. Possession of a constructed
`Caller`, `Handle`, or `Capability` record is not authenticated authority. Tests
provide synthetic monitor-owned state; real requester authentication and all
output confinement must be enforced by the eventual host.

There is no kernel character device, mounted filesystem, descriptor-passing ABI,
or S3 server in this baseline. Those adapters must invoke the same live authority
path rather than interpret a successful mount as unrestricted access.

## Handle allocation exhaustion

The pinned runtime supports Nat through 2^48 − 1. Since a successful allocation
must keep `next` strictly above every allocated ID, max − 1 is the final
allocatable ID; a terminal `next` rejects new mount/open/dup transitions
unchanged. This refusal preserves CF-004 rather than weakening a security law:
the alternative successor is unrepresentable. The
[boundary tests](../../FrontendBoundaryTests.bend) cover all three operations,
exact scope and state preservation, and HostBinding propagation. With revision
headroom, exhaustion of the separate allocation counter does not prevent
resolution, attenuation or owner cleanup, including after capability
revocation. This does not repair the distinct pre-existing terminal *revision*
problem: at maximum frontend revision, close may overflow instead of meeting
CF-012, and that issue remains unresolved. No real identity or native host
qualification follows from these synthetic records.

The [proposed versioned frontend revision and migration](../changes/add-versioned-frontend-revision/proposal.md)
describes a possible repair of the separate terminal-revision cleanup gap. Its
contracts and tests are unimplemented; it does not change the current CF-012
evidence or authenticate a host.
