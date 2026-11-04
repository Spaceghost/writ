# Release an approved result

## Why

A company permits a summary of its customer records to leave its domain after
an approved projection removes specified fields. Today Writ correctly retains
the records' restrictions: changing bytes does not authorize a new audience.
The same problem occurs when a private comparison releases only a match verdict.

## What Changes

Add an explicit, versioned disclosure operation. It binds the exact computation,
sealed output, affected owners, recipient, destination, and current terms. A
released view retains the original provenance together with a separately checked
effective confidentiality policy and an authenticated release record.

The first profile supports bounded, registered output contracts. A sanitizer's
name, a passing trial, a caller-supplied score, or possession of a read grant does
not confer disclosure authority. Integrity endorsement remains outside scope.

## Capabilities

### New Capabilities

- `controlled-disclosure`: An owner-authorized boundary for releasing a precise
  result while preserving its origin history and every unaffected obligation.

### Modified Capabilities

None in the current API profile. Existing `Transfer`, `Core`, and `Backplane`
contracts continue to reject an ordinary operation that drops restrictions.
The proposed release view is a distinct versioned value; a legacy `SourcePolicy`
cannot represent it by clearing bits. Implementation must introduce the new
checked boundary through the authoritative Bend facade before enabling it.

## Impact

New Bend request/result types, owner-authority checks, output-contract validators,
release records, and a versioned integration with the final publication gate.
Stored releases need current authorization checks when used again. Native
confinement, execution authenticity, and durable state remain prerequisites.

This is the explicit rationale for permitting a new confidentiality transition:
the affected principals authorize a precise disclosure. Ordinary derivation stays
monotone; no general-purpose declassification switch is introduced.

## Dependencies

- [Authenticated grant issuance](../add-authenticated-grant-issuance/proposal.md)
- [Confined execution](../add-confined-transform-execution/proposal.md)
- [Durable publication](../add-durable-publication/proposal.md)

Origin stages, views, and private matching can use this capability. They do not
grant it merely by naming an operation that sounds safe.
