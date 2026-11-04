# Genode capability adoption traceability

Proposed change: [add-genode-capability-adoption](../changes/add-genode-capability-adoption/specs/genode-capability-adoption/spec.md).
Related host requirements: [add-genode-host](../changes/add-genode-host/specs/genode-host/spec.md)
(GN-*) and [add-portable-host-contract](../changes/add-portable-host-contract/specs/portable-host-contract/spec.md)
(PH-*). These are proposed changes; nothing here marks a host adapter or a host
acceptance scenario as implemented.

Implementation: [HostBinding.bend](../../HostBinding.bend), composed with
[Frontend.bend](../../Frontend.bend). Executable cases:
[HostBindingTests.bend](../../HostBindingTests.bend), run by `Tests.bend`.
Laws: `binding_denied_preserves_state`, `nat_lt_successor`, and
`generation_bump_monotone` in [LAWS.bend](../../LAWS.bend), proved in
[PROOF.bend](../../PROOF.bend). Vectors:
[host-binding-vectors.txt](../../verification/host-binding-vectors.txt).

Test names below are the exact `Test.check` names. Vector ids are the second
field of a `VECTOR` line. "Reviewed-only" means the requirement, or the named
part of it, has no executable vector in this model and rests on source review,
a host obligation, or evidence a qualified host profile must supply.

## Vectors

Each vector is rendered by `HostBindingTests.bend` from the transition's actual
`Change`, after the check that asserts it. The line is
`VECTOR <scenario-id> <transition> <outcome> <reason-or-id>`: a denial prints
`denied` and the closed `Error` constructor; a commit prints `accepted` and the
model id it produced (`alias=<a>;object=<o>` for mount, open, attenuate, and
delegate; `object=<o>` for close; `domain=<d>` for revoke). Ids are model ids of
the synthetic fixture, never native selectors. A host port replays the same
inputs (fixture state, transition, arguments) through its own binding and
compares normalized outcomes; a different outcome fails that vector (GA-009).

Fixtures are the named zero-argument functions in `HostBindingTests.bend`.
Domains: reader R = 7, worker W = 8, helper H = 9; subject 7; services 1 and 2.
Rights: read = 1, read+write = 3, all = 7.

| Vector | Fixture and transition inputs | Expected line suffix | Asserting check |
| --- | --- | --- | --- |
| GA-001-1 | `stale_open`: `bind_open(generations, rev 1, alias 2, R, read)` | `bind_open denied StaleGeneration` | `GA-001 alias at generation 3 on object at generation 4 denied StaleGeneration` |
| GA-001-2 | `current_open`: `bind_open(generations, rev 1, alias 1, R, read)` | `bind_open accepted alias=3;object=2` | `GA-001 alias at current generation 4 proceeds` |
| GA-002-1 | `mount_change`: `bind_mount(initial, rev 0, R's route, caller 7, all)` | `bind_mount accepted alias=1;object=1` | `GA-002 mount on a recorded route naming the caller succeeds` |
| GA-002-2 | `suffix_mount`: R's route, caller subject 8 | `bind_mount denied RouteMismatch` | `GA-002 route prefix naming R mounted for caller S denied RouteMismatch` |
| GA-002-3 | `unrecorded_mount`: presented route naming subject 8, caller 8 | `bind_mount denied RouteMismatch` | `GA-002 a presented route the parent never recorded denied RouteMismatch` |
| GA-002-4 | `rerouted_open`: service-2 Session after the parent withdraws that route | `bind_open denied SubjectMismatch` | `GA-002 a route on another service does not authorize the holder` |
| GA-003-1 | `open_change`: `bind_open(mounted, rev 1, alias 1, R, all)` | `bind_open accepted alias=2;object=2` | `GA-003 open from the Session issues a new alias` |
| GA-003-2 | `attenuate_change`: `bind_attenuate(opened, rev 2, alias 2, R, read)` | `bind_attenuate accepted alias=3;object=3` | `GA-003 attenuate mints a distinct object bound to a distinct handle` |
| GA-003-3 | `guessed_open`: `bind_open(opened, rev 2, alias 99, R, read)` | `bind_open denied UnknownAlias` | `GA-003 open through an unknown alias denied UnknownAlias` |
| GA-004-1 | `shared_close`: `bind_close(shared, rev 3, alias 2, R)` | `bind_close accepted object=2` | `GA-004 owner closes a descriptor held by two domains` |
| GA-004-2 | `owner_after_close`: `delegate(shared_closed, rev 4, alias 2, R -> H, read)` | `delegate denied StaleGeneration` | `GA-004 after close the owner's alias is stale` |
| GA-004-3 | `holder_after_close`: `delegate(shared_closed, rev 4, alias 3, W -> H, read)` | `delegate denied StaleGeneration` | `GA-004 after close the second holder's alias is stale` |
| GA-004-4 | `stale_revision_close`: `bind_close(shared, rev 2, alias 2, R)` | `bind_close denied StaleRevision` | `GA-004 close at a stale revision destroys nothing and leaves state unchanged` |
| GA-005-1 | `unrecorded_attenuate`: `bind_attenuate(forged_holder, rev 3, alias 3, W, read)` | `bind_attenuate denied SubjectMismatch` | `GA-005 alias held by Q with no delegation record denied SubjectMismatch` |
| GA-005-2 | `non_holder_open`: `bind_open(mounted, rev 1, alias 1, W, read)` | `bind_open denied SubjectMismatch` | `GA-005 a domain that does not hold the alias denied SubjectMismatch` |
| GA-005-3 | `worker_derive_change`: `bind_attenuate(shared, rev 3, alias 3, W, read)` | `bind_attenuate accepted alias=4;object=3` | `GA-005 recorded delegation to the worker is accepted` |
| GA-006-1 | `widened_delegate`: `delegate(attenuated, rev 3, alias 3, R -> W, read+write)` | `delegate denied WidenedRights` | `GA-006 read-only descriptor delegated with read and write denied WidenedRights` |
| GA-006-2 | `attenuated_copy_change`: `delegate(attenuated, rev 3, alias 3, R -> W, read)` | `delegate accepted alias=4;object=3` | `GA-006 read delegation of the same read-only descriptor is recorded` |
| GA-006-3 | `copy_change`: `delegate(opened, rev 2, alias 2, R -> W, read)` | `delegate accepted alias=3;object=2` | `GA-006 narrower read-only delegation is recorded` |
| GA-007-1 | `quota_open`: `bind_open(exhausted, rev 1, alias 1, R, all)` | `bind_open denied QuotaExhausted` | `GA-007 open with zero capability quota denied QuotaExhausted` |
| GA-007-2 | `quota_before_authority`: as GA-007-1 with caller subject 8 | `bind_open denied QuotaExhausted` | `GA-007 quota is checked before Frontend authority` |
| GA-007-3 | `retry`: as GA-007-1 on `topped_up` | `bind_open accepted alias=2;object=2` | `GA-007 after top-up the open proceeds at the same revision` |
| GA-008-1 | `stale_revision_mount`: `bind_mount(mounted, rev 0, ...)` | `bind_mount denied StaleRevision` | `GA-008 mount at a stale revision denied StaleRevision` |
| GA-008-2 | `rejected_mount`: `bind_mount(initial, rev 0, ..., rights 8)` | `bind_mount denied FrontendRejected` | `GA-008 mount Frontend rejects returns the input state` |
| GA-008-3 | `invalid_mount`: `bind_mount(dangling_state, rev 0, ...)` | `bind_mount denied StaleRevision` | `GA-008 an invalid input state is denied StaleRevision` |
| GA-011-1 | `chain_revoke`: `revoke(chain, rev 4, R)` | `revoke accepted domain=7` | `GA-011 revoking R's domain commits` |
| GA-011-2 | `worker_after_revoke`: `delegate(chain_revoked, rev 5, alias 3, W -> H, read)` | `delegate denied StaleGeneration` | `GA-011 revoking R makes W's alias stale` |
| GA-011-3 | `helper_after_revoke`: `delegate(chain_revoked, rev 5, alias 4, H -> W, read)` | `delegate denied StaleGeneration` | `GA-011 revoking R makes H's alias stale` |
| GA-011-4 | `wider_child`: `delegate(shared, rev 3, alias 3, W -> H, read+write)` | `delegate denied WidenedRights` | `GA-011 child delegation wider than its read-only parent denied and no node added` |
| GA-011-5 | `derived_after_close`: `bind_attenuate(derived_closed, rev 5, alias 4, W, read)` | `bind_attenuate denied StaleGeneration` | `GA-011 derived object is stale after its parent is closed` |

Every denial check above also asserts, through `denied`, that the returned
state equals the input in every field, including the embedded Frontend state.
A vector records only the normalized outcome; state preservation is asserted by
the check, not carried in the line.

## Adoption requirements

| Requirement | Implementation | Named executable evidence | Vectors | Coverage boundary |
| --- | --- | --- | --- | --- |
| GA-001 | `Object.generation`, `Alias.generation`, `resolve_current`, `bumped`, `destroy` | `GA-001 generation fixture is a valid state`; `GA-001 alias at generation 3 on object at generation 4 denied StaleGeneration`; `GA-001 stale alias cannot be delegated`; `GA-001 stale alias cannot close the current object`; `GA-001 alias at current generation 4 proceeds`; `GA-001 current alias reaches the Frontend check` | GA-001-1, GA-001-2 | The generation-3/4 fixture is valid but unreachable by transitions; transition-made staleness is GA-004 and GA-011. `generation_bump_monotone` proves only that a bump raises a generation; that no transition lowers one is source-reviewed, not stated as a law. |
| GA-002 | `bind_mount`, `route_recorded`, `take_cap`, `F.mount` | `GA-002 mount on a recorded route naming the caller succeeds`; `GA-002 mount mints a Session owned by the route subject on the route service`; `GA-002 the routed child domain holds the Session alias`; `GA-002 Frontend.mount was applied`; `GA-002 route prefix naming R mounted for caller S denied RouteMismatch`; `GA-002 a presented route the parent never recorded denied RouteMismatch`; `GA-002 route for an unrouted service denied RouteMismatch`; `GA-002 route withdrawal fixture is a valid state`; `GA-002 a route on another service does not authorize the holder` | GA-002-1, GA-002-2, GA-002-3, GA-002-4 | The label suffix is deliberately unrepresented, so "reader=S" can arrive only as a caller for S. That a host derives `Route` from the parent-imposed prefix and the authenticated `Caller` from trusted native state is reviewed-only. |
| GA-003 | `bind_open`, `bind_attenuate`, `commit_mint`, `F.open`, `F.dup`, `F.attenuate` | `GA-003 open from the Session issues a new alias`; `GA-003 opened alias names a distinct object`; `GA-003 open mints a Descriptor object`; `GA-003 the Session alias is unaffected by open`; `GA-003 attenuate mints a distinct object bound to a distinct handle`; `GA-003 attenuate leaves the parent Frontend handle rights intact`; `GA-003 the parent descriptor alias is unaffected by attenuate`; `GA-003 open through an unknown alias denied UnknownAlias` | GA-003-1, GA-003-2, GA-003-3 | The `object=` field of GA-003-1 and GA-003-2 is what a host that aliases the parent object would get wrong (the "attenuation reuses the parent object" scenario). Running that comparison is a host replay obligation; no host replays the vectors yet. |
| GA-004 | `bind_close`, `close_frontend`, `commit_destroy`, `destroy`, `prune`, `refund`, `F.close` | `GA-004 owner closes a descriptor held by two domains`; `GA-004 after close the owner's alias is stale`; `GA-004 after close the second holder's alias is stale`; `GA-004 close applies Frontend.close to the bound handle`; `GA-004 close leaves the parent Session usable`; `GA-004 close at a stale revision destroys nothing and leaves state unchanged`; `GA-004 close Frontend rejects destroys nothing`; `GA-004 a domain without the alias cannot close it` | GA-004-1, GA-004-2, GA-004-3, GA-004-4 | Derived objects' Frontend handles are left open (the monitor holds no authenticated caller for them); no binding reaches them through a destroyed object. That a native server actually destroys the object is a host obligation (GN-009). |
| GA-005 | `resolve_subject`, `delegated_to`, `delegate` | `GA-005 holder-without-record fixture is a valid state`; `GA-005 alias held by Q with no delegation record denied SubjectMismatch`; `GA-005 unrecorded holder cannot delegate onward`; `GA-005 a domain that does not hold the alias denied SubjectMismatch`; `GA-005 recorded delegation to the worker is accepted`; `GA-005 delegatee opens through a delegated Session`; `GA-005 the delegatee's opened alias resolves within the record`; `GA-005 the delegatee is accepted only within the delegated scope` | GA-005-1, GA-005-2, GA-005-3 | The model sees the holder because the fixture records it. A running Genode server cannot observe the invoker; at runtime GA-005 holds only through GA-010. |
| GA-006 | `delegate`, `delegate_rights`, `delegated_rights`, `T.word_subset` | `GA-006 read-only descriptor delegated with read and write denied WidenedRights`; `GA-006 delegation outside the protocol rights denied WidenedRights`; `GA-006 read delegation of the same read-only descriptor is recorded`; `GA-006 delegatee of the read-only descriptor shares its object and carries read only`; `GA-006 narrower read-only delegation is recorded`; `GA-006 delegatee alias carries read only`; `GA-006 delegator alias keeps its rights`; `GA-006 delegatee cannot attenuate past its delegated rights` | GA-006-1, GA-006-2, GA-006-3 | Rights only; plan and origin preservation is Frontend's exact-scope check (CF-008), not re-tested here. |
| GA-007 | `has_cap`, `mount_quota`, `derive_quota`, `take_cap`, `refund` | `GA-007 mount with zero capability quota denied QuotaExhausted`; `GA-007 open with zero capability quota denied QuotaExhausted`; `GA-007 only the retried open adds a Frontend handle and advances Frontend`; `GA-007 quota is checked before Frontend authority`; `GA-007 after top-up the open proceeds at the same revision`; `GA-007 the retried open is charged and reaches Frontend`; `GA-007 mount and open each charge one capability slot`; `GA-007 destroying an object refunds its capability slot`; `GA-007 destroying a Session refunds its derived objects too` | GA-007-1, GA-007-2, GA-007-3 | Capability slots only; the RAM field is recorded but no transition charges it, so RAM exhaustion is reviewed-only. The module imports no ledger, so "ledger untouched" holds by source review. |
| GA-008 | every transition's `Rejected{state, reason}` path; `valid`; closed `Error` | Every denial check above (via `denied`); `GA-008 mount at a stale revision denied StaleRevision`; `GA-008 mount Frontend rejects returns the input state`; `GA-008 open at a stale revision denied StaleRevision`; `GA-008 attenuate at a stale revision denied StaleRevision`; `GA-008 delegate at a stale revision denied StaleRevision`; `GA-008 revoke at a stale revision denied StaleRevision`; `GA-008 dangling alias fixture is invalid`; `GA-008 an invalid input state is denied StaleRevision`; `GA-008 revoke on an invalid input state is denied`; law `binding_denied_preserves_state` | GA-008-1, GA-008-2, GA-008-3 | The law holds by computation of `Change.state` and documents the contract; it does not prove that a transition chose the denial path or the right reason. The tests are finite cases, not a proof over all states. |
| GA-009 | `reason_name`, `alias_outcome`, `close_outcome`, `revoke_outcome`, `vector` in `HostBindingTests.bend` | The 30 vectors above, regenerated byte-identically on two JavaScript runs and the native run (see VERIFICATION.md) | all | The "vectors regenerate identically" scenario is executable. The "host outcome differs" scenario is reviewed-only: no host replays the vectors yet (task 3.1 of this change and the Genode component change). |
| GA-010 | none in the model, by nature | none | none | **Reviewed-only by nature.** A Genode server learns which object was invoked, not who invoked it, so no model test can observe topology. It is discharged only by reviewed confinement inventory evidence per qualified profile. |
| GA-011 | `Delegation`, `link_node`, `prune`, `remove_subtree`, `revoke`, `bind_close` | `GA-011 a two-level chain R to W to H is recorded`; `GA-011 the chain preserves binding validity`; `GA-011 revoking R's domain commits`; `GA-011 revoking R makes W's alias stale`; `GA-011 revoking R makes H's alias stale`; `GA-011 revoke removes the whole subtree`; `GA-011 closing R's descriptor makes W's alias stale`; `GA-011 closing R's descriptor makes H's alias stale`; `GA-011 close removes the whole subtree and stays valid`; `GA-011 removing W's node removes H's node with it`; `GA-011 removing H's node keeps W's node`; `GA-011 child delegation wider than its read-only parent denied and no node added`; `GA-011 W's derived object is usable before its branch is cut`; `GA-011 derived object is stale after its parent is closed`; `GA-011 derived object is stale after its parent's holder is revoked` | GA-011-1, GA-011-2, GA-011-3, GA-011-4, GA-011-5 | Two-level chain only; deeper trees are source-reviewed through the recursive `prune`. |

## Genode host and portable contract requirements

Only the parts a pure binding model can exercise have vectors. Everything that
needs a running host, native channels, durable state, or confinement evidence
is reviewed-only here and stays unimplemented in its own change.

| Requirement | Model evidence | Vectors | Reviewed-only parts |
| --- | --- | --- | --- |
| GN-003 | An unrecorded alias id grants nothing (`GA-003 open through an unknown alias denied UnknownAlias`); an alias another domain holds cannot be used (`GA-005 a domain that does not hold the alias denied SubjectMismatch`). Vectors carry model ids only. | GA-003-3, GA-005-2 | Obtaining capabilities through native mechanisms; a portable record resembling a native capability with no registered channel binding. |
| GN-004 | Possession without a record is denied; recorded delegation is accepted only within scope (`GA-005 alias held by Q with no delegation record denied SubjectMismatch`, `GA-005 recorded delegation to the worker is accepted`, `GA-005 the delegatee is accepted only within the delegated scope`). | GA-005-1, GA-005-2, GA-005-3, GA-006-1 | Workers lacking general publication authority through their topology (GA-010); authenticated reader checks at the real ingress. |
| GN-005 | Client-chosen suffix cannot change identity; a route withdrawn after session creation stops authorizing (`GA-002 route prefix naming R mounted for caller S denied RouteMismatch`, `GA-002 a route on another service does not authorize the holder`). | GA-002-2, GA-002-3, GA-002-4 | Parsing the native parent label prefix; binding native routing generations; request-body labels at the real ingress. |
| GN-009 | Close and revoke destroy by generation bump and cut delegation subtrees (`GA-004 after close the second holder's alias is stale`, `GA-011 revoking R makes H's alias stale`). | GA-004-1, GA-004-2, GA-004-3, GA-011-1, GA-011-2, GA-011-3 | Linearizing revocation with release; a server ignoring close; quarantine or teardown; the fact that revocation does not recall copied plaintext. |
| GN-010 | Destroyed ids are never reused and stale aliases resolve to StaleGeneration (`GA-004 after close the owner's alias is stale`). | GA-001-1, GA-004-2 | Service and channel incarnations (the model has no incarnation field); selector recycling across restarts; durable invocation and receipt reconciliation. |
| GN-011 | Capability quota denies before Frontend and is refunded on destruction (`GA-007 quota is checked before Frontend authority`, `GA-007 destroying an object refunds its capability slot`). | GA-007-1, GA-007-2, GA-007-3 | RAM quota and dataspaces; diagnostics not exposing payloads; that reclaimed native quota does not settle a Writ reservation (the module imports no ledger; source review only). |
| PH-002 | Subject derives from route and delegation records, not claims (`GA-002 route prefix naming R mounted for caller S denied RouteMismatch`, `GA-005 alias held by Q with no delegation record denied SubjectMismatch`, `GA-001 current alias reaches the Frontend check`). | GA-002-2, GA-005-1, GA-005-2 | A transferred endpoint hiding its holder at runtime (GA-010). |
| PH-003 | A guessed alias number grants nothing (`GA-003 open through an unknown alias denied UnknownAlias`). | GA-003-3 | Cross-host references and fresh scoped grants. |
| PH-004 | Generation is required to resolve (`GA-001 alias at generation 3 on object at generation 4 denied StaleGeneration`); `valid` rejects duplicate ids, and invalid states are denied (`GA-008 an invalid input state is denied StaleRevision`). | GA-001-1, GA-001-2, GA-004-2, GA-008-3 | Host incarnation; conflicting live mappings (no duplicate-id fixture is tested; uniqueness in `valid` is source-reviewed). |
| PH-005 | Delegation and attenuation only narrow rights; the older broad alias stays live (`GA-006 delegator alias keeps its rights`, `GA-003 attenuate leaves the parent Frontend handle rights intact`). | GA-006-1, GA-006-2, GA-006-3, GA-011-4, GA-003-2 | Destination or plan change by a delegated holder (Frontend CF-008 covers plan exactness); lifetime narrowing; new authorization for a changed effective subject. |
| PH-010 | Derived objects go stale with their parent, so a late use with the old generation is refused (`GA-011 derived object is stale after its parent is closed`, `GA-011 derived object is stale after its parent's holder is revoked`). | GA-011-2, GA-011-3, GA-011-5 | Device and worker quiescence; asynchronous completions; the fact that revocation does not erase earlier plaintext copies. |

## Scope limits

Every fixture is synthetic monitor state. Constructing a `Route`, `Quota`,
`Alias`, or `F.Caller` record is not authentication; a real host builds them
from native state it trusts. The model has no native selectors, incarnations,
channels, or RAM accounting, and no host replays these vectors yet. Passing
these checks does not qualify a Genode profile.
