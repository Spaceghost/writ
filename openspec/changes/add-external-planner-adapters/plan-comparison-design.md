# Proposed planner-to-plan comparison

A planner describes a transform of sources A and B into destination D. The
monitor has already selected a plan containing A then B for its own reasons.
A comparison may establish that the proposal's *plan fields* describe exactly
that selected plan. It does not establish that the planner is authenticated,
that a request or manifest is current, that evidence is valid, or that the
operation may run. There is currently no planner endpoint, authenticated
planner registry or implemented comparison; this is a design-only proposal.

The existing [planner change](design.md) and [tasks](tasks.md) remain pending.
The comparison is a small, independently testable precursor to task 1.3, not a
registry resolver or completion of that task. It must preserve
[DM-005–006](../../specs/data-model/spec.md),
[AB-001–007](../../specs/authority-boundary/spec.md),
[TA-002–006](../../specs/transfer-admission/spec.md),
[CV-001](../../specs/candidate-verification/spec.md) and
[CB-001–006](../../specs/commit-backplane/spec.md); no security law changes.

## Boundary and result

Propose a pure Bend function `same_plan_description(proposal, selected_plan)`
returning only `Bool`. `proposal` is `PlannerEnvelope.Proposal`, which remains
untrusted and publicly constructible. `selected_plan` is an already selected
`Transfer.Plan` supplied by the monitor; this function neither selects nor
resolves it, and cannot determine whether the supplied value actually came
from that monitor. All public constructors and helper definitions remain
forgeable. `True` means only the listed fields compare exactly, not that either
input is authentic, live, well authorized, or even came from a conforming
codec. `False` means mismatch or unsupported comparison input; it need not
identify a field. The function returns no `Plan`, ticket, context, capability,
caller, policy, evidence, effect, updated state or write intent.

There is no call to `Transfer.admit`, `Frontend.checked_plan`,
`Negotiation.open`, `Backplane.commit` or an equivalent gate. This avoids
creating a second release path. A future enforcing integration must separately
obtain authoritative current state, authenticate the caller and reference,
serialize transitions against revocation, and use existing admission,
verification and commit paths. It must not treat this comparison as approval.
This slice makes no host, durable-recovery, GPU, or endpoint claim.

The name deliberately says *plan description*: it does not mean that the
complete proposal matches a request, manifest, evidence set or context. The
function intentionally does not inspect the proposal's separate request ID,
claimed expiry, manifest reference or evidence references. Even changed or
malformed values in those fields do not change a plan-field comparison; this
is a limitation, not permission to use those fields. It does not parse or
validate the whole `Proposal`. A caller must use appropriate bounded framing
and independent checks before using any proposal, including values produced by
public constructors; this comparison itself is not a validation gate.

## Exact field correspondence

The table covers the *entire* existing `Transfer.Plan` structure, and no more.
Each test uses independently constructed proposal and plan values, not a plan
made by converting the proposal under test.

| Planner description | Already selected `Transfer.Plan` | Required comparison |
| --- | --- | --- |
| `stamp.graph`, `.policy`, `.authority` | `Stamp{graph, policy, authority}` | Each complete N48 numeric value equals the corresponding `Nat`. |
| `invocation` | `invocation` | Complete N48 equals the `Nat`; never substitute the separate planner request ID. |
| `sources` | `Objects` | Equal nonempty ordered lists of object/version pairs, including exact occurrence count and repeated objects. |
| `destination` | `ObjectVersion` | Exact object and version independently. |
| `code` | `CodeId{a,b,c,d,e,f,g,h}` | All eight U32 words compare in the same order. |
| `operation` | `OpKind` | Exactly `1` = Copy, `2` = Transform or `3` = Summarize; all other words fail. |
| `output_type` | `output_type` | Exact equality and one of the eight supported atomic values (1–128 powers of two); other words fail. |

Match the three operation variants explicitly. In particular, the wire value
for Summarize is **3**, whereas `Transfer.OpKind.bit(Summarize)` is the
policy-mask bit **4**; equating the wire word with that bit would compare the
wrong domain. The test suite must distinguish those values.

Both lists must contain 1 through 8 sources, matching the codec profile and
`TA-002`'s nonempty rule. Comparing outside that smaller profile returns false;
it does not prove that a longer Writ plan is invalid in general. No source
may be sorted, deduplicated, omitted or inserted. A plan equality result is not
a completeness claim about the monitor's real data/control dependencies.

`PlannerEnvelope.N48{lo, hi}` is a low U32 word and a high U32 word limited
to 65535. Compare without packing the pair into an unchecked number. Following
`Backplane.word64_matches_nat`, derive the monitor `Nat` low word with modulus
2^32 and its high word with division by 2^32, then compare each word in full;
only convert values known to fit the U32 range. First reject a directly
constructed N48 whose high word exceeds 65535. An implementation must verify
the exact pinned Bend 2.0.39 arithmetic and each backend, including 0,
2^32−1, 2^32 and 2^48−1, without overflow or narrowing. This relies on the
existing typed `Nat` runtime domain capped at 2^48−1 (DM-001's documented
numeric note); arbitrary foreign-language values that violate the type/domain
are outside this pure model and must be rejected by the host boundary.

## Bounded work and evaluation order

This function accepts descriptions, not pre-authenticated compiler objects.
In particular, exported `Proposal` and `Transfer.Plan` constructors can be
called directly, bypassing the existing codec's size and numeric checks.

1. Use bounded cap-plus-one walks to check *each* source list independently;
   no generic full-length traversal, `Objects.equal`, recursive conversion,
   list copy or plan comparison may run before the relevant list's cap is
   established. Reject zero or more than eight entries on either side.
2. Stage the two cap outcomes using matched branches. Reject the first failed
   check before entering the comparison stage; do not pass an expensive
   recursive comparison as an eagerly evaluated argument to a boolean helper.
   In particular this must hold for generated Node as well as Bend and native
   CPU. Preconstructed input allocation, host stack/memory, scheduling and
   transport limits remain separate host obligations.
3. Check every relevant directly constructed N48 high word, operation tag
   and output type in the bounded comparison. Numeric conversions and any
   computed arithmetic are reached only after the bounds they rely upon.
   Compare source lists in lockstep, preserving order and exact length; no
   unchecked array indexes or unbounded work list are introduced.
4. Unknown or malformed non-plan fields are intentionally *not* checked as
   described above. A `True` result cannot be promoted to a valid envelope,
   current request, evidence judgment, policy decision or effect.

A test can observe timely rejection of large finite fixtures; it does not by
itself prove a process-wide memory quota, constant time or termination for
foreign cyclic values. No network stream, queue, deadline or external request
handler is part of this function. Test any applicable resource behavior under
both bundled Bend and generated Node; native CPU regression is separate.

## Proposed adversarial fixtures

These are test requirements, not results. Build valid proposal and plan records
independently, with distinct field values and distinct code words, so one
encoder/decoder or conversion routine cannot make both sides wrong in the same
way. Label all authority/context fixtures synthetic; never present them as
an authenticated monitor.

| Named case | Expected result |
| --- | --- |
| `plan-match-independent` | An independently assembled proposal and plan with the same fields match; the result is only a Boolean and produces no state or effect. |
| `plan-stamp-mutations` | Mutating graph, policy or authority alone, including the high word, returns false. |
| `plan-invocation-mutation` | Different invocation returns false even when request ID equals the plan invocation; changing only request ID does not change the comparison. |
| `plan-source-order-multiplicity` | `[A,B]` versus `[B,A]`, `[A,A]` versus `[A]`, changed object, changed version and extra/missing source all return false. |
| `plan-destination-and-code` | Change destination object, version, or each of the eight code words independently; every case returns false. |
| `plan-kind-and-output` | Each of three valid kind mappings and eight atomic output values matches an independently constructed plan; wrong, unknown, zero or multi-bit values return false. Explicitly verify wire 3 matches Summarize and wire 4 does not, despite Summarize's policy-mask bit being 4. |
| `plan-n48-boundaries` | Check 0, 2^32−1, 2^32 and 2^48−1 against independently constructed Nat values; changing either word returns false, and direct `hi=65536` fails before numeric conversion. Cover every N48 field, not only invocation. |
| `plan-source-cap` | Independently constructed empty, 9-element and far-over-cap proposal and plan lists return false before recursive comparison, on Bend and generated Node; both lengths 1 and 8 can match. |
| `plan-unresolved-fields` | Vary request ID, expiry, manifest and evidence alone, including a directly constructed unsupported evidence tag and overlong evidence list; plan-field match remains the same and is never promoted to validation or authority. |
| `plan-no-forged-authority` | Verify the comparator takes no Context, owner, caller, budget, payment, grant or proof result; direct forged public plan/proposal records can compare equal but cannot create or mutate an authoritative state or effect. This is an interface/side-effect scope check, not a test of actual registry enforcement. |
| `plan-no-admission` | An equal description with an independently missing read grant, changed epoch or missing budget still cannot create an admission or commit because no gate is invoked; existing gate-specific tests remain the authority evidence. |
| `plan-eager-bounds` | Combine far-overlong proposal/plan lists with malformed numeric or operation fields and run under bounded-time Bend and Node checks; the cap stage rejects before recursive comparisons, independent of downstream data. |

Where a test says a comparison cannot grant authority, substantiate it by the
function's result/type and absence of any state/effect entry point, not by
claiming a synthetic caller record was authenticated or an unavailable host
registry rejected an attack.

## Remaining registry and lifecycle gaps

`Negotiation.Request` contains a plan, reader, quote, units and deadline but no
planner request ID. `Backplane.binding_find` keys the *complete* request and
rejects duplicate full keys. Several valid full requests may share one plan, so
a planner request ID cannot be equated with invocation or looked up by plan
alone. `HostIdentity` and `Frontend` resolve monitor-bound session/capability
references, not the planner manifest and evidence namespaces. The first-slice
envelope explicitly leaves those namespaces, issuer authentication and current
lookup unspecified. Inventing a new registry record and labelling it trusted
would not resolve these gaps.

A future reviewed design must specify how request ID maps uniquely to the full
monitor-owned request and authenticated holder, how the sealed manifest and
its full data/control/tool/destination scope are identified, how each evidence
reference maps to an authenticated current record and exact scope, and how
expiry/time, revision, replay, revocation and commit are serialized. A stale
copy of structurally valid state is not authoritative. The actual monitor must
own those facts; public Bend `Data` construction does not establish them. Do
not mark task 1.3 or PL-001/PL-002 integration complete based on a pure field
comparison, and do not infer protected input confinement or host qualification.
