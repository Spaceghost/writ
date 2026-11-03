# Authenticated grant issuance

## Why

The library enforces paired read/write permission at use, but does not authenticate grant issuers or prevent an unpaired read from being registered. An authority service must establish those facts before operational admission.

## What Changes

Introduce the behavior in [grant-issuance](specs/grant-issuance/spec.md) as a new capability. This is proposed work; no implementation task is complete merely because this proposal exists.

## Capabilities

### New Capabilities

- `grant-issuance`: Authenticate the parties that issue capabilities and create effective source-read grants only against current, exactly scoped destination-write approval.

### Modified Capabilities

None. Existing model guarantees remain in force.

## Impact

New Bend authority-state and issuer interfaces around Transfer and Frontend; authenticated identity and durable state are trusted host inputs. Existing use-time checks remain mandatory.

## Dependencies

No prior change package is required to specify the issuer. Durable host-state integration is required before deployment.
