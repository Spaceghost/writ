# Locality-aware execution tasks

All implementation and integration work below is pending.

## 1. Placement and selection

- [ ] 1.1 Implement versioned placement and movement records in Bend; test unsupported fields, malformed estimates, and requirements falsely presented as preferences.
- [ ] 1.2 Implement every-origin eligibility and requester code/query protection; test incompatible residency, unapproved model observers, and unauthenticated host claims.
- [ ] 1.3 Extend offers with approved end-to-end costs while preserving ER-003 ordering; test movement charges, exact ties, conflicting offers, and bounded-arithmetic rejection.
- [ ] 1.4 Bind provider, host incarnation, domain, generations, source versions, and movement plan; test relocation, stale bindings, and provider substitution.

## 2. Execution evidence

- [ ] 2.1 Integrate current dispatch and per-edge transfer checks; test revoked owners, forbidden caches/staging, incompatible local subplans, and protected planning metadata.
- [ ] 2.2 Exercise timeout, retry, and unavailable-provider recovery; verify no unapproved raw-data fallback, duplicate billing, or CPU substitution for required GPU execution.
- [ ] 2.3 Run native placement probes on each claimed host profile; record observed movements, actual backend, evidence trust boundary, and every unverified device or location claim.
- [ ] 2.4 Add a runnable Bend placement example with accepted and unsatisfiable plans, record suite/proof results, update traceability, and validate OpenSpec strictly.
