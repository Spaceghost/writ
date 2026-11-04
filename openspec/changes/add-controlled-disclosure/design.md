# A release has its own authority

## Example

The origin approves `customer-count-v3` over records at version 42. The registered
projection excludes names and contact fields; the output is one bounded count
for an approved cohort. That count can still disclose information, so the owner
explicitly authorizes this query and recipient. The final gate checks the actual
sealed result and all current terms before publishing it.

Changing the query to a single named customer, changing the projector, or sending
the result to another recipient requires a new authorized scope. Calling an
arbitrary function `remove_pii` does not qualify it for release.

## What exists

The current library conservatively accumulates source and control restrictions.
Its DLM flow check grants no declassification or endorsement. The ordinary
source, candidate, transfer ticket, and write-intent formats cannot express an
authorized release. This change adds a separately negotiated profile; none of
its scenarios have implementation evidence yet.

## Keep the two policies

| Record | Meaning |
| --- | --- |
| Protected artifact | Actual bytes sealed under every original data/control restriction |
| Release request | Exact plan, execution, artifact, output contract, recipient, destination, and terms |
| Original policy | Complete provenance and restrictions before disclosure; never rewritten as public |
| Effective policy | Only the confidentiality changes justified by current affected-owner authority |
| Release record | Durable binding between those facts and the exact authorized outcome |

The names above describe required facts, not committed constructor names or a
wire encoding. All policy and verification behavior is authored in Bend 2.

The view's content may be readable by a broader audience than its provenance
metadata. Keep the full origin records protected at the enforcing service and
bind them to the released artifact; provide only an authorized metadata view to
its recipient. An opaque reference is descriptive, not a bearer credential.

## The boundary

First prepare the result in a domain that accepts the complete original policy.
Verify the unchanged authoritative graph and the authenticity of the producing
execution. The release gate then checks a separate authenticated transition over
that sealed artifact. It must not feed cleared labels back into the producer or
pretend the original graph had fewer dependencies.

Every policy owner whose confidentiality is relaxed must authorize the release.
The monitor resolves owners from complete policy and provenance facts, including
control inputs, code/model/configuration dependencies, and inherited releases.
Ambiguous ownership is a denial. If two owners impose the same secrecy bit,
approval from only one cannot remove the other's restriction. A numeric mask is
not evidence of the authority to remove it.

The first profile changes confidentiality only. Integrity, operation-kind limits,
approved code, source charges, compute charges, resource limits, and actual sink
effects retain their ordinary checks. There is no implied integrity endorsement,
payment waiver, or permission to reuse the result for another purpose.

Untrusted query parameters are part of the pinned plan. A user cannot choose a
different field or influence the decision to release through a worker-reported
`passed` flag. Output validation checks the declared contract and the actual
artifact; execution binding establishes which pinned operation produced it.
Neither check establishes that arbitrary free text is anonymous. General AI
redaction, differential privacy accounting, and proofs of semantic anonymization
need their own reviewed profiles.

## Current state and recovery

The release uses the existing durable-publication architecture. Its serialized
authorization point records the exact artifact, original/effective policies,
release evidence, current revisions, reservation consumption, and destination
together. Before that point, revocation or expiry denies release. After it,
recovery delivers only the exact already-authorized intent without charging or
disclosing again. A completed disclosure cannot be recalled.

Copies, cached views, and further computation are new uses. A release-aware
consumer validates the complete chain and current scope before use; it does not
treat an old receipt as perpetual authority. An unsupported consumer refuses the
view. Exporting to an already authorized external recipient has the ordinary
limit that Writ cannot govern copies outside its enforced domain.

Budgets distinguish compute cost from permitted disclosure. A retry of the same
invocation reconciles its recorded outcome; a new query consumes the applicable
cumulative allowance. Result size, count, order, errors, progress, and timing
exposed by the chosen profile are declared outputs. A profile cannot promise
the absence of all hardware or network side channels without corresponding
evidence.

A rejected final release does not undo information already disclosed by an
authorized protocol step or status observation. Those steps reserve and record
their own cumulative allowance before exposing information; their consumed
allowance survives failure of a later step. Compute settlement is separate.

## Compatibility and migration

Keep v1 requests and all existing regression cases unchanged. Add versioned
release-view and release-intent handling to the same trusted Bend authority
boundary. The host accepts a release intent only when it resolves to that
boundary's durable current record, never because a client serialized one.

Enable the new profile only after model, host, and persistence acceptance tests
pass. Rollback disables new release operations but retains receipts, epochs,
disclosure accounting, and exact already-authorized recovery. It cannot downgrade
a release view into a v1 source with missing origin bits.

## Sources and evidence

Jif distinguishes confidentiality declassification from integrity endorsement,
requires the authority of the affected principal, and checks untrusted influence
over downgrading in its robustness model. Those distinctions inform this design;
Writ does not claim Jif's compiler proof or a complete implementation of it.

- [Jif language features: downgrading and authority](https://research.cs.cornell.edu/jif/doc/jif-3.3.0/language.html#downgrading)
- [Current provenance contract](../../specs/provenance-preservation/spec.md)
- [Current commit contract](../../specs/commit-backplane/spec.md)
- [Feature acceptance index](../../FEATURE-ACCEPTANCE.md)
