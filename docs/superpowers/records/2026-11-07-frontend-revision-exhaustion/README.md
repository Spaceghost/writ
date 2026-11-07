# Frontend revision exhaustion: owner cleanup and migration design

An authenticated owner holds one open frontend handle at revision
`281474976710655` (`2^48−1`), the pinned runtime's largest supported `Nat`.
The supplied frontend state is structurally valid. Calling `Frontend.close`
with that exact current revision should close the handle for cleanup under
[CF-012](../../../../openspec/specs/capability-frontend/spec.md), yet the
increment needed for the resulting state raises a Nat-range error on both Bend
and generated Node. The same close at one less than the maximum succeeds and
leaves a closed tombstone at the maximum. This is a model availability and
cleanup failure, not an observed authorization bypass or native-host result.

This record compares possible future designs. **No frontend revision fix,
generation rollover, migration, host quarantine, or additional acceptance test
is implemented here.** Existing laws remain unchanged. The separate handle-ID
allocation boundary also appears in the evidence; resolving that boundary does
not resolve revision exhaustion or prove cleanup.

## Observed scope and evidence

The [synthetic close fixtures](close-current.bend.txt) use the matching current
revision and [a stale revision](close-stale.bend.txt) with the same valid handle.
The [recorded results](results.json) show exit 1 and a Nat-range error for the
current close at the maximum; both backends return `CHANGED` at maximum minus one
and `REJECTED` for stale revision at both values. [Separate controls](Controls.bend.txt)
confirm the terminal state validates and the penultimate close records a closed
tombstone; their [Bend](controls-bend.stdout) and [Node](controls-node.stdout)
outputs and [exit statuses](controls-exit.json) match. The same record includes
the unrelated maximum-next-ID mount experiment. These are externally supplied
synthetic records, not authenticated host state or physical descriptor tests.

The experiments were run before this document on the 59 copied tracked Bend
files in [this inventory](copied-bend-inputs.sha256), all independently compared
to source `85a1577`, and the retained fixtures above. The [scratch artifact
hashes](scratch-artifact-sha256.txt) include generated Node files, which remain
outside the source package. The pinned Bend 2.0.39 binary SHA-256 was
`2ec160fa4486d33aff51e9eedcc294d6b531dc10c279c00b0c00685dae2045cd`.
These finite examples do not prove all states or backends, host confinement,
durable serialization, or a native cleanup guarantee.

## Contracts and the existing contradiction

The [data model](../../../../openspec/specs/data-model/spec.md) documents the
compiled Nat cap and does not promise a checked-overflow result for every
operation. [Frontend.bend](../../../../Frontend.bend) states that every successful
mutation advances revision once; [CF-011](../../../../openspec/specs/capability-frontend/spec.md)
requires the current expected revision and unchanged state on rejection.
[CF-012](../../../../openspec/specs/capability-frontend/spec.md) separately promises
that the authenticated subject with the exact token and current revision can
close an open handle, even if its capability was revoked or expired. [CF-013](../../../../openspec/specs/capability-frontend/spec.md)
keeps closed IDs permanently reserved and unusable. State constructors do not
authenticate the supplied records: an enforcing monitor still owns the current
state, caller and serialized transition.

For a valid state with an open handle and revision at the maximum, those current
requirements have no representable v1 successor: close must change the handle
and advance the revision, but the next Nat is outside the runtime range. Merely
returning `Rejected{old}` avoids an exception and preserves denial state but
does not satisfy the owner-cleanup promise for that state. Marking the handle
closed with an unchanged, wrapped, reset or saturated revision would break the
stated successor invariant and invite stale-current ambiguity. Treating the
terminal state as invalid, deleting tombstones, or reusing identifiers would
discard existing obligations rather than resolve them. Neither holding an OS
descriptor nor a native handle authenticates a caller or makes a native
cleanup effect equivalent to the Bend transition.

## Candidate approaches

### 1. Reserve room before the terminal state

An invariant for a new, authenticated lifecycle could reserve one remaining
revision transition per open handle. Let `R` be current revision, `O` the exact
number of open handles, and `M` the representable maximum. The invariant is
`O <= M - R`, with checked subtraction and bounded counting. A close consumes
one revision and one open handle, preserving the inequality; an allocation
consumes a revision and adds one open handle, so it needs two units of headroom.
An attenuation consumes a revision without reducing `O`, so it needs one unit
beyond the already reserved cleanup room. All other successful mutations must
be inventoried and charged for their exact effect. This is a candidate invariant,
not a tested implementation or an authorization to refuse an operation today.

Count all open handles, including revoked or expired ones, not just handles
currently authorized for use. A potentially huge list must be admitted and
counted with an independently reviewed work/resource bound; do not overflow a
count, truncate, or interpret an incomplete count as zero. A caller-supplied
count is not authority. Read-only resolution must not be silently disabled just
because allocation is exhausted. Rejecting a proposed allocation, attenuation,
or other update under the new budget needs a reviewed contract and rationale;
the invariant cannot be used as a retrospective excuse to relabel an existing
valid state invalid.

This approach can maintain sufficient room from a properly initialized state,
but it **cannot repair an already accepted state** where `O > M - R`, including
the reproduced terminal state. Treating every such state as unauthenticated
would not be justified by its structural shape. A migration or a separately
specified recovery path is still required before promising owner cleanup there.

### 2. Versioned wider revision plus authenticated migration

A new frontend interface could represent a revision as an explicitly tagged,
multiword value rather than silently changing the meaning of an existing Nat.
For example, a lexicographically ordered pair of U32 words can encode every
currently supported Nat revision. It needs exact-word comparison, checked carry,
and a no-wrap terminal rule. Such a finite value only postpones exhaustion;
it still needs a cleanup-headroom and retirement plan. An unbounded mathematical
counter is not an implementation or a resource bound.

Migration must be an authenticated, serialized, atomic monitor transition of
the exact authoritative frontend and any coupled binding state. It must preserve
every open handle, closed tombstone, identifier, owner, token, immutable scope,
restriction and allocation watermark; neither constructing a new record nor
choosing a purported incarnation in an untrusted request proves any of those
facts. A versioned expected-revision interface must fence all legacy requests,
including delayed requests and restored snapshots. Accepted state and replay
history must be persisted with the required anti-rollback guarantees before
effects are exposed. Existing aliases, external references and current callers
need an explicit mapping/retirement protocol that neither reuses identity nor
silently widens authority. The mechanism for authenticating, allocating and
durably advancing an incarnation is not specified here; a random value,
timestamp, native token, or bearer possession is not a substitute for those
requirements.

If the extended space also nears exhaustion, an implementation must retain
enough headroom to close all open handles and retire the instance under an
explicitly reviewed lifecycle. It must not assume an inexhaustible sequence or
reset an epoch without demonstrating that stale references cannot become current.
Migration also changes API compatibility and authenticated current-revision
handling; those choices and any normative specification changes require explicit
rationale, tests and independent review before implementation.

### 3. Host-only shutdown is not a model repair

An integration may need to quiesce or quarantine a real object while an
exhausted instance is recovered, but no current native action by itself proves
the required frontend tombstone was committed. Such a shutdown cannot stand in
for CF-012 or be used as an alternate authorization or release path. Native
confinement and recovery evidence are separate from pure Bend cases.

## Composition with HostBinding

[GA-004](../../../../openspec/specs/genode-capability-adoption/spec.md) requires
object destruction to invalidate aliases and apply frontend close to the bound
handle; [GA-008](../../../../openspec/specs/genode-capability-adoption/spec.md)
requires denied transitions to retain the original binding state. In
[HostBinding.bend](../../../../HostBinding.bend), `close_frontend` first closes the
selected handle; `close_doomed` then walks bound handles for objects destroyed
by the same cut and uses the caller to close each still-open one. Its current
`close_kept` retains the previous frontend state if an individual close is
rejected, while the outer destruction can continue. Existing
[traceability](../../../../openspec/traceability/genode-capability-adoption.md)
describes rejected derived closes as not arising for valid state. A newly added
revision-exhaustion refusal would invalidate that reasoning if the first close
consumed the last revision and a later required close could not advance.

Any proposal must count and identify the complete original cut and every
distinct still-open bound frontend handle, including descendants, before
committing the destruction. The model must either establish and retain enough
headroom for every required close, with all relevant caller checks satisfied, or
return the **original full binding and frontend state** without external
destruction/refund. Do not expose a partial prefix as complete, skip a denied
close while claiming it happened, or use a producer's pruned work list as proof
that every original binding was considered. This is a design obligation, not a
claim that a concrete exploit or native destruction occurred. The binding
state's own revision, object generations, quota refunds, alias staleness and
replay state have separate numeric and authority obligations; securing only the
frontend counter does not establish them.

## Required work before selecting or claiming a solution

1. Decide and specify the lifecycle and compatibility contract for existing
   authoritative terminal and near-terminal snapshots, including how owner
   cleanup remains available and how delayed legacy requests are fenced. Keep
   the current CF-012 promise unless a separately justified law change is
   explicitly reviewed; a crash avoidance test alone is not such a rationale.
2. Specify exact `O` counting, quotas and resource limits, each mutation's
   headroom cost, and atomic behavior of failed multi-handle close. Prove or
   independently check the invariant from initialization and across every
   transition, including delegated and already-closed handles.
3. Add Bend tests for an accepted penultimate operation, last available
   cleanup, multiple open handles, revoked/expired owners, stale/wrong caller,
   legacy terminal migration, migration replay/rollback, no ID reuse, and an
   interrupted or denied binding close returning the original whole state.
   Add independent boundary/mutation controls, inspect eager Node evaluation,
   and run the appropriate full suite, native tests and existing Lean verdict.
   A Lean pass for unrelated existing laws is not proof of the new lifecycle.
4. Qualify actual host migration, serialization, confinement and recovery
   separately. No runnable monitor integration, durable witness or qualified
   host follows from this design or these synthetic observations.
