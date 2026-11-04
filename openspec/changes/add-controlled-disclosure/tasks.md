# Controlled disclosure tasks

## Model

- [ ] 1.1 Add versioned Bend release-request, view, and receipt types; show that existing v1 requests still reject label removal and unsupported versions fail closed.
- [ ] 1.2 Implement exact scope and affected-owner resolution; test two owners sharing a secrecy bit, hidden control origins, missing owners, and changed recipients.
- [ ] 1.3 Implement original/effective policy validation with preserved integrity and obligations; test attempted endorsement, waived payments, widened operation rights, and erased provenance.
- [ ] 1.4 Bind registered output validators and authenticated execution to sealed bytes; test changed artifacts, untrusted pass flags, changed query fields, and unsupported redaction contracts.

## Integration

- [ ] 2.1 Add the checked release boundary to the authoritative Bend facade and durable publication; test expiry, revocation ordering, duplicate invocation, crash recovery, and one accounting outcome.
- [ ] 2.2 Implement release-chain resolution for copies, cached views, and further computation; test expired chains, missing links, legacy conversion, and protected metadata views.
- [ ] 2.3 Enforce the selected profile's disclosure and resource limits across retries and related requests; test result-size, count, error, and status disclosure boundaries.

## Evidence

- [ ] 3.1 Run model regression/property cases and the approved summary example on supported CPU backends; record source, command, output, and limits without claiming native isolation.
- [ ] 3.2 Run native confinement, sealed-artifact, durable-recovery, and attempted alternate-release probes for each supported host profile; keep untested hosts and cryptographic guarantees explicitly unverified.
