# Origin transform stages

## Why

An origin should be able to require a field projection before a reader's code
sees a customer table, then require a result check before publication. Those
stages need exact identities, bounded execution, and the same effect controls as
any other transformation.

Writ currently binds one operation identity and conservatively retains all input
restrictions. It does not execute staged graphs or grant a redactor authority to
relax labels.

## What Changes

Add [origin-transform-stages](specs/origin-transform-stages/spec.md): a bounded
acyclic execution graph with explicit preparation, requested-computation, and
release-processing stages. Each stage consumes only its admitted inputs and
produces private, sealed outputs.

An origin can require a stage without granting that stage authority over another
origin's data. Any confidentiality relaxation uses the separate, versioned
controlled-disclosure path over the actual sealed artifact. Stage success alone
never grants release authority.

## Capabilities

### New Capabilities

- `origin-transform-stages`: Enforce required preparation and post-processing as
  pinned, confined stages with complete provenance, current admission, bounded
  cost, and final artifact validation.

### Modified Capabilities

None in this package. The controlled-disclosure proposal defines its separate
versioned release profile. Existing v1 inheritance
remains the default; this package cannot clear labels or strip a release chain.

## Impact

New Bend stage descriptors, graph admission, stage-instance records, orchestration,
and result binding. Native workers remain subject to the portable host contract.
Hosted transformation languages and arbitrary callback execution remain outside
this package.

All runtime and acceptance work is pending. A proposed field projection is not a
claim that a general PII detector can prove an arbitrary document harmless.

## Dependencies

- [add-confined-transform-execution](../add-confined-transform-execution/proposal.md)
- [add-durable-publication](../add-durable-publication/proposal.md)
- [add-controlled-disclosure](../add-controlled-disclosure/proposal.md)
