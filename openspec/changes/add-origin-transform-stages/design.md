# Origin transform stages

## Example

An origin holds a customer table with name, email, region, and purchased amount.
It approves a preparation stage that emits only region and amount. The requested
computation groups that prepared input, and a final stage checks the permitted
result schema. The reader's worker never receives a handle to the raw table.

These computations still inherit their sources' restrictions. Making the result
readable by a new audience needs a separate authorized disclosure of the actual
sealed result. Removing column names or passing a detector is not that authority.

This is an acceptance example, not a working transform service.

## Current gap

The library verifies complete supplied graphs, origins, and one exact operation
identity. It does not launch a staged transform, enforce real worker boundaries,
or implement selective disclosure. This proposal defines orchestration in Bend
2 around the pending confined-execution and controlled-disclosure services.

## Stages are explicit

| Stage | Input | Output boundary |
| --- | --- | --- |
| Preparation | Only the approved raw inputs and configuration | A private, sealed artifact for named successor stages |
| Requested computation | Only its declared prepared or otherwise approved inputs | A private result for required post-processing |
| Release processing | The exact admitted result and its permitted validation inputs | A sealed release candidate for the final authorization path |

The graph has finite bounds, unique stage identities, explicit input ordering,
typed edges, required dependencies, and named terminal outputs. Cycles, dangling
edges, unsupported stages, and undeclared dynamic hooks are denied.

Dependencies fix the required phase order. Independent admitted branches may run
in parallel; scheduling them does not change the graph, ordered input bindings,
or effect contract. A stage cannot omit a required predecessor because a similar
cached result exists.

## Pin the recipe

Before approval, fix each stage's code, model, configuration, tools, provider
binding, input schema, output schema, input edges, placement, and quota. Each
execution gets a stage-instance identity bound to its parent invocation and
graph version.

The origin proposes or requires stages. The monitor decides admission from all
current authorities. Registering a stage called `redact` or `post` confers no
special privilege. A required stage change creates a new complete approval scope;
old evidence cannot follow a replacement implementation.

## Constrain each boundary

Establish the stage's native confinement before delivering plaintext. A successor
receives only approved sealed predecessor artifacts, never an implicit raw-source
handle or access to a predecessor's heap, cache, logs, or device buffers.

Every nonterminal output stays private to its authorized edges. Error text,
timing exposed by the declared interface, status, validation reports, and payment
metadata remain outputs governed by their own policy. A failed post-stage cannot
publish diagnostic excerpts as a fallback.

Origin A's stage does not gain access to B's protected contribution merely
because A requires the stage. A combined stage requires approval for every input
and effect. If the owners cannot agree on a workable graph, admission fails.

## Inherit, then disclose explicitly

Conservative dependency capture includes data and control sources, model weights,
configuration, tools, and retained state. Each derived artifact retains complete
original provenance. Ordinary v1 operations keep monotone restrictions.

The separate [controlled-disclosure](../add-controlled-disclosure/proposal.md)
path can authorize a versioned release view with an effective policy over a
specific sealed artifact. Its original policies and provenance remain attached.
The release path needs the appropriate owner authority and current checks; the
worker cannot mint a valid disclosure record by constructing a value.

Later stages and later uses revalidate any release chain and current authority.
A release view cannot be converted to a legacy source by discarding its original
policy. Confidentiality release does not establish integrity endorsement or
remove unrelated owner restrictions.

Start with narrow structured projections and bounded outputs. Free-text PII
scanners and model summaries can provide evidence under an explicit policy, but
a named detector or high sample score is not a universal absence-of-PII proof.

## Quotas and recovery

Admission fixes stage count, work, memory, artifact size, aggregate budget, and
explicit retry limits. Per-stage limits cannot exceed the graph's aggregate
allowance. Resource exhaustion stops the affected execution without admitting an
unchecked result or recursively launching another hook.

Each completed stage binds its immutable artifact and scope to one durable stage
record. Resuming a stage checks current authority and reconciles that record;
retries cannot splice one invocation's intermediate into another's graph or bill
the same event twice.

Recheck authority at stage admission and final publication authorization. A
revocation before durable publication authorization prevents release, even after
all stage functions have returned success. An already committed publication
recovers through its exact recorded intent. Cancellation does not recall earlier
authorized copies, and native teardown must quiesce remaining writers.

## Evidence

Acceptance needs graph-admission and transition tests in Bend, plus native probes
showing that preparation hides raw input from successors and that malicious
post-processing cannot bypass publication. Required disclosure behavior needs
its own checked release-chain evidence. The [tasks](tasks.md) remain unchecked
until that code and evidence exist.
