# Proposed V2 frontend revision and authoritative migration

For a synthetic legacy state at revision `2^48−1` with one open handle, the
correct owner currently triggers an overflow when closing it. The proposed
migration maps that exact state into a tagged two-word revision with room to
close the handle. A stale V1 close must then fail even if its old numeric
revision equals the new pair. The [reproduction and constraints](../../../docs/superpowers/records/2026-11-07-frontend-revision-exhaustion/README.md)
remain valid; no part of this proposal is implemented or accepted by a host.

## Representation and checked progression

Use `RevisionV2{high: U32, low: U32}` in an explicitly V2-tagged frontend
state and expected-revision request. Compare both words and the version tag
exactly. Interpret the pair lexicographically as an unsigned 64-bit number;
the model need not and must not pack it into the bounded Nat type. The current
V1 revision `r` maps injectively to `high = floor(r / 2^32)` and
`low = r mod 2^32`. Validate and perform the mapping without overflow or
unchecked narrowing. For `r = 2^48−1`, the result is
`high = 65535`, `low = 4294967295`.

Migration is a distinct, monitor-authorized V1-to-V2 version-control
transition, not an ordinary successful V2 frontend mutation. It installs the
exact mapped revision without a further increment, while atomically changing
the active version/instance fence. Subsequent successful V2 mutations advance
once. This distinction does not let an old V1 request act on the new state.

The V2 successor increments `low` only when it is below U32 max. At low max,
it increments `high` only when high is below U32 max and sets low to zero.
At both maxima there is no successor. Arithmetic that would overflow must
appear only in a proven-safe match branch on every backend; do not rely on
short-circuit evaluation or a provisional invalid successor. A successful
frontend mutation advances the pair exactly once. Denial returns the complete
original state, including the pair. Resolution checks the exact current pair
but does not consume one. The request does not authenticate itself by carrying
a version or guessing a revision.

V2 is a new interface, not implicit coercion of old calls. Existing Nat-based
call sites, including the `DataOS` facade, must migrate to a tagged V2
expected revision. Once an instance migrates, V1 requests and queued V1
operations fail rather than being translated to a new expected value. A
version tag does not authorize an operation; all original caller, token,
registry, epoch, expiry, scope, budget and final-commit checks remain in force.

A standalone [descriptive revision primitive](../../../FrontendRevisionV2.bend)
and [synthetic controls](../../../verification/frontend-revision-v2/README.md)
now exercise tagged V2 comparison and guarded two-word successor arithmetic.
They are not wired into `Frontend`, `HostBinding` or `DataOS`, do not map V1
state, and do not establish an authenticated current revision. FR-001 and all
frontend migration/cleanup acceptance scenarios remain open.

A separate [bounded synthetic conversion and verifier](../../../FrontendLegacyConversion.bend)
copies a supplied V1 description and independently compares its original and
candidate within a fixed eight-handle/eight-source test profile. Its
[controls and limits](../../../verification/frontend-legacy-conversion/README.md)
are not an authenticated snapshot, V2 admission, migration, binding-state
verification, or a deployment resource guarantee. Larger inputs remain
incomplete in that profile; all migration tasks and acceptance remain open.

## Reserve the remaining cleanup and retirement transitions

Let `M = 2^64−1`, `R` be the current pair and `O` the exact count of all open
handles in the original frontend, including expired or revoked handles.
Every admitted **active** V2 state maintains `O + 1 <= M − R`: one successor
per open handle plus one reserved for retiring the empty instance. This is a
representation/resource-admission invariant, not a reason to modify the
existing owner-cleanup law.

* Let `D = M − R`. A successful mount/open/dup advances `R` once and
  increases `O` by one. Its postcondition is `D − 1 >= (O + 1) + 1`,
  so its precondition is **`D >= O + 3`**: two units beyond the old
  `O + 1` reserve. At `D = O + 2`, allocation is denied unchanged. A
  successful attenuation advances `R` once with the same `O`, so it needs
  `D >= O + 2`.
* A successful close advances `R` once and decreases `O` by one. In an active
  state satisfying the invariant, an exact authenticated owner and current
  revision can always close an open handle even after expiry/revocation.
* A monitor may retire only an instance with no open handles, using the
  reserved final successor. The retired state retains all tombstones and
  allocation history; it is not a fresh instance and cannot be reopened by a
  stale request. Creating a new instance is a separately authenticated,
  non-reusing lifecycle, not a counter reset.

A [standalone synthetic reserve arithmetic reference](../../../FrontendCleanupReserve.bend)
counts up to eight supplied handles and describes capacity at these thresholds.
Its [checks and limits](../../../verification/frontend-cleanup-reserve/README.md)
do not authenticate the list, establish handle validity, admit a real V2 state,
perform a close or retirement, or reserve host resources. Over-cap lists are
incomplete; existing V1 and V2 cleanup acceptance remain open.

Apply the same prospective inequality to every other successful mutation;
inventory all current and future mutations. An unrepresentable or
reserve-consuming non-cleanup mutation refuses unchanged, after the existing
authority and failure-order rules appropriate to that entry point. It must not
silently disable otherwise authorized read-only resolution. Do not first
construct an overflow candidate and then select denial.

Count from the original complete handle list, preserving uniqueness and
closed flags; a request-supplied count is not evidence. The monitor's resource
profile must bound retained handles, bindings, encoded bytes, traversal and
work before evaluating an untrusted request. Count and each reserve/cost
(`O + 1`, `O + 2`, `O + 3`) must be checked; use two-word arithmetic if a cost
would exceed the Nat ceiling. Compare to the two-word remaining capacity without wrapping, narrowing,
unbounded unary construction or an unchecked index. If counting or resource
admission is incomplete, return no accepted result. A failure to establish
the reserve does not prove an old authoritative snapshot was invalid or
discharge its cleanup obligation.

An admitted V2 integration must also reserve enough bounded traversal and
other resources to carry out each promised owner cleanup, including after
revocation or expiry. Resource exhaustion is a host qualification and
liveness failure, not proof that the cleanup happened or a silent exception to
CF-012. No implementation may advertise the profile as qualified until this
resource reservation and its recovery behavior are established.

For a structurally valid V1 state, allocated IDs are distinct positive Nats
below `next <= 2^48−1`; therefore at most `2^48−2` handles exist. Its V1
revision is at most `2^48−1`. After the exact mapping, even the largest such
revision has `2^64−2^48` successors, more than `O + 1`. This arithmetic is a
design argument, not a proof or a guarantee that a deployment can traverse
an arbitrarily large snapshot. Migration may be claimed available only for
the deployment's complete admitted snapshot and budget; if an existing state
cannot be counted or migrated within those limits, it remains an explicit
unresolved recovery/cleanup case. Do not silently truncate or relabel it
invalid.

## Authenticated, atomic V1-to-V2 transition

The enforcing monitor, not an ordinary caller, owns the current complete V1
frontend and any coupled binding state, the migration control operation, its
resource profile and its authority checks. The migration input is the exact
authoritative current snapshot under a serialized transition, not a caller's
selected state or a Boolean `authenticated` field. A pure Bend migration may
compute and validate a candidate, but its public constructors or returned
candidate do not authenticate the source or commit an external effect.

The migration must preserve each original handle and its order, identifier,
kind, subject, full token, complete plan, rights, authority epoch, expiry and
closed flag; preserve the allocation watermark, including all tombstones; and
map only the revision and version representation. For coupled `HostBinding`,
preserve its revision, object/alias allocation watermarks, routes, quotas,
objects and generations, aliases, delegations and bindings, including stale
or closed history. Preserve all separately authoritative registries and their
live scopes; no migration is a new grant, release, declassification, charge
waiver or revocation reversal.

An independent checker must compare the candidate against the *entire
original* admitted snapshot, not a producer's work list or a caller-supplied
count or digest. It must reject missing, repeated, reordered or altered entries,
changed high token/plan words, changed tombstones, omitted original binding
edges or unsupported variants. A digest can help identify bytes but does not
authenticate this state or replace complete comparison. Every scan must be
bounded and fail closed on incomplete work.

The monitor must fence old sessions and queued requests, serialize the
snapshot and migration against all writes, and atomically install the validated
V2 state with the V2 request fence and replay history. Operations queued under
V1 are denied or freshly reauthenticated/reissued; the monitor must never
substitute the V2 expected revision on their behalf. Failure, interruption or
concurrent change leaves the authoritative old state intact and emits no
success; any ambiguous outcome is incomplete until recovered against the
authoritative transaction record.

The frontend and every coupled binding facade must route requests by the
authenticated active instance/version. In particular, merely changing
`Frontend.State` is insufficient: current `HostBinding` entry points compare
their own Nat revision and then read `F.revision` internally. A V1 binding
request must not enter the V2 path just because that independent binding
revision is numerically unchanged. Version the binding entry points as well,
and preserve their separate current-revision and authority gates. The new
instance/epoch identity must be monitor-owned, non-reused for its scope, and
durably bound to the exact state and authenticated sessions. A caller-supplied
identifier, timestamp, random guess, old native selector or bearer handle is
not proof of identity. Authentication, allocation, fencing and durable
non-reuse of that identity are **unimplemented integration prerequisites**.

Every persisted handle reference, binding and authenticated session must be
bound to this authoritative instance identity. A new instance cannot reinterpret
an old reference or alias merely because its numeric handle ID, token, subject
and revision happen to match. An integration unable to establish these bindings
cannot qualify the new instance. Globally non-reused identifiers across
retirement may add protection, but do not replace authenticated instance
binding. Neither fresh-looking bytes nor a caller assertion is evidence of
non-reuse. This fence must not discard a migrated open handle: a newly
authenticated V2 request can reference the exact preserved handle through the
validated mapping and still passes the original caller, token and applicable
current checks. In particular, a new V2 owner close remains allowed after
revocation or expiry, as CF-012 requires; operational use still requires the
live registry and expiry checks.

An old snapshot restored after the transition can defeat a pure revision
comparison. A qualified integration must retain an independently trusted,
rollback-resistant record tying the active instance/version to its current
state and replay history across crashes; it must reject a restored V1 snapshot
and a reused retired V2 identity. Neither a migration marker inside a restored
snapshot nor a caller-presented receipt is sufficient. No existing host or
durable witness is claimed to provide this yet.

## Binding close and failure atomicity

For `bind_close`, identify every distinct still-open frontend handle of the
selected object and the entire original transitive cut from original bindings,
objects and aliases. Do not count the same handle twice because several
aliases name it; do not omit descendants or replace original-graph checks with
the producer's cut/work list. Validate caller ownership/token and every
required close, the exact cut, frontend revision headroom, binding revision,
object generations and quota refunds before committing. If any required
check, arithmetic or resource bound fails, return the complete original
binding **and** frontend state and perform no destruction or refund.

The current `close_doomed` retains a prior frontend on a rejected derived
close while the outer operation can still destroy objects. That behavior is
not sufficient once new refusal conditions can arise. The proposed
implementation must change that composition and test failure at each position;
merely widening the frontend revision does not fix binding generation,
binding revision or quota overflow. Those other counters need their own
checked obligations before a binding operation can be accepted.

`HostBinding.revoke` has no authenticated `Frontend.Caller` and currently
leaves frontend handles unchanged. V2 migration does not create authority to
close them. The existing host obligation to close/quarantine handles and
invalidate authority remains; no native cleanup, host qualification, or
alternative release path is established by this design.

## Implementation and evidence gates

The [tasks](tasks.md) and [traceability](traceability.md) name all intended
model and integration checks. They remain unchecked. Bend owns the state,
policy and independent validation; native components may only translate
admitted facts and perform admitted effects. Strict OpenSpec validation checks
document structure, not migration, owner cleanup, kernel proof or host
qualification. Any new formal laws need non-vacuous cases and a separate Lean
kernel verdict; existing laws alone do not prove this proposed transition.
