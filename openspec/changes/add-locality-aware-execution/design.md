# Locality-aware execution

## Example

The origin of a customer table permits its raw bytes only inside domain A. A
reader on Windows asks for an approved report. The scheduler finds a qualified
executor in A and sends the approved operation there. The raw table stays in A;
only a separately permitted result crosses to the reader's destination.

If no eligible executor exists in A, the request is denied or remains pending
within its approved deadline. Downloading the table to the reader is not a
fallback.

## Current gap

The pending executor rendezvous binds provider identity, exact execution scope,
owner approval, and price. It does not yet implement placement or real remote
execution. This design adds policy and planning in Bend 2; it relies on the
portable host contract for actual confinement and authenticated native bindings.

## Placement contract

| Field | Meaning |
| --- | --- |
| Required domains | Where each input, intermediate, and result may be processed or retained |
| Movement limits | Permitted recipients, paths, copies, staging stores, and transfer bounds |
| Host profile | Required isolation, runtime, device, and retention properties |
| Provider binding | Authenticated provider, host incarnation, execution domain, and resource generations |
| Ranking and quote | Versioned ordering rule, fixed estimates, approved compute and movement costs, and total ceiling |

Hard requirements come from every applicable origin and other protected input.
Nearness is a placement preference or an explicitly chosen domain requirement;
it never overrides those requirements. Reject unsupported policy fields rather
than treating them as hints.

An address locates a resource. It does not authenticate a provider, qualify a
host, prove where bytes reside, or transfer a native capability. The registry
resolves versioned object identities independently of their current approved
locators. A relocated replica needs a current authenticated binding and suitable
authority before use.

## Eligibility, then cost

First filter offers against all origin rules, source and query/code visibility,
movement limits, required host features, and budget. Estimates are scoped planning
facts from authenticated sources; a provider's unverified self-description cannot
satisfy a required isolation or residency check.

The first profile retains ER-003: lowest approved total quote, then canonical
provider identity, then canonical offer identity. The quote states compute,
input/result movement, and other agreed charges. Unapproved costs cannot hide
behind an inexpensive compute-only offer. Fixed offers and estimates produce the
same selection; arithmetic outside supported bounds is rejected.

This profile can require execution at an origin and account for transfer cost.
It does not promise to choose a physically nearer provider at any price. A later
"prefer nearby" ordering needs a named version, precise metric and tie-breaks,
fresh consent, and a coordinated amendment to the pending rendezvous ordering.
Until then, an unknown ranking profile is denied.

## Protect both sides

Requester-supplied queries, code, model weights, parameters, and tools can also be
confidential. The selected host must be approved to observe each item it needs.
Keeping the table at its origin does not authorize that origin's operator to read
a private requester model.

The scheduler has no implicit permission to reveal protected sizes, source names,
candidate availability, or placement errors while shopping for offers. Discovery
uses permitted metadata or scoped estimates. If it needs additional disclosure,
that requires its own authorization.

## Pin the execution

The selected record fixes provider, host incarnation, execution domain, code and
configuration, source versions, movement plan, host profile, quote, and authority
epoch before dispatch. Replacing a provider, source, domain, or billing term
requires new approval. Trials and approvals from one binding do not qualify
another.

Every planned transfer is an effect with an authorized recipient and destination.
That includes caches, temporary staging, model delivery, logs, and intermediate
results. A shared address syntax does not create shared memory or grant remote
handles the rights of local ones.

Actual execution must produce authenticated evidence tied to this binding. Such
evidence has the trust scope of the qualified host; it is not a cryptographic
proof of physical geography. A self-reported location string is insufficient.

## Multiple origins

Take the intersection of applicable requirements. If A requires raw input to stay
in A and B requires raw input to stay in B, a raw-data join has no eligible common
executor.

The [bounded conjunction reference model](first-slice-conjunction.md) implements
a small synthetic check for supplied domain descriptions. It does not
implement placement or establish that the supplied descriptions are complete.

A new plan may instead propose approved local subcomputations and combine only
their permitted outputs. Each local computation and every movement edge needs
complete approval; a partial result does not automatically lose its inherited
restrictions. If the required answer cannot be obtained that way, deny the plan.
Secure multiparty computation is a separate future execution profile, not an
assumed property of address-based placement.

## Failure and evidence

Timeout, unavailable hosts, invalid evidence, or missing isolation controls do not
authorize remote fallback, raw export, or another billed attempt. Reconcile the
same execution binding. If replacement is needed, negotiate a new binding under
current authority and the remaining approved budget.

CPU execution is permitted only when the admitted profile allows it. A required
GPU backend cannot silently fall back to CPU, and a GPU claim needs actual device
and isolation evidence.

The [tasks](tasks.md) require deterministic Bend planning tests and native probes
for real movements, denied fallbacks, stale bindings, and protected metadata.
Document validation is not evidence that a host obeys a placement contract.
