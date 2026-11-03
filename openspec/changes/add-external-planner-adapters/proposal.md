# External planner adapters

## Why

AI systems and Trealla can help propose transformations, constraints, or candidate
solutions. Their outputs need an explicit untrusted interface so that flexible
planning cannot become a second authority path.

## What Changes

Introduce [planner-adapters](specs/planner-adapters/spec.md) as a new capability:
bounded typed proposal envelopes, exact input manifests, independent evidence
checks, and deterministic admission through current monitor-owned state.
This package specifies pending adapter work; it does not embed an AI service,
Trealla runtime, or a hosted transformation language.

## Capabilities

### New Capabilities

- `planner-adapters`: Accept bounded proposals from external planning engines while retaining all authorization, provenance, and commit decisions in the Bend authority path.

### Modified Capabilities

None. Existing admission, verification, negotiation, and commit contracts remain
in force. Planner output gains no special approval status.

## Impact

New Bend transport envelopes, parsers, adapters, and dispatcher routing are
required. The core representation is versioned typed binary data, not JSON
authority records. External planners may use any implementation language; their
actual protected execution is delegated to the confined-execution adapter when
available. Existing library entry points remain the final decision path.

## Dependencies

- [add-authenticated-grant-issuance](../add-authenticated-grant-issuance/proposal.md)

Reference-only planning can be integrated without running an external language
inside Writ. Any mode exposing protected inputs remains disabled until the
[confined transformation execution](../add-confined-transform-execution/proposal.md)
contract is satisfied by the host.
