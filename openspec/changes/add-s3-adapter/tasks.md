# S3 adapter tasks

All implementation and integration work below is pending.

## 1. Request and read boundary

- [ ] 1.1 Define the versioned operation allowlist and request bounds in Bend; test unsupported methods and malformed variants deny, and document the supported subset and POSIX deployment prerequisite.
- [ ] 1.2 Implement authenticated canonical-request-to-plan binding; test subject, path-encoding, source-version, and destination substitutions, and document the host authenticator contract.
- [ ] 1.3 Implement GET and bounded streaming/range release against paired source/sink authority; test an unauthorized recipient and revocation between release units, and document the exact revocation boundary.
- [ ] 1.4 Implement protected HEAD/LIST/conditional-result mappings and the registered-query gate; test hidden names, counts, page tokens, and unregistered queries, and document metadata-view policies and unsupported query behavior.

## 2. Staging and publication

- [ ] 2.1 Implement PUT ingress provenance and COPY plan mapping; test forged labels, a changed source version, and copy restrictions, and document how clients inspect retained output policy.
- [ ] 2.2 Implement principal-bound multipart staging and cleanup; test cross-principal upload IDs, incomplete-object invisibility, and authenticated abort, and document staging limits and lifecycle.
- [ ] 2.3 Implement frozen-manifest completion through durable publication; test changed parts, revoked grants, duplicate completion, and crashes around publication, and document retry and recovery outcomes.
- [ ] 2.4 Reject direct backing-store and presigned bypass routes; test that accepted API responses expose no such access path, and document the endpoint's supported credential and transport model.

## 3. Integration evidence

- [ ] 3.1 Run every delta scenario against the supported host and object-client subset, record conformance and failure-injection results, and document remaining unsupported operations without implying universal compatibility.
- [ ] 3.2 Run applicable Bend tests and ordinary proof checks, validate OpenSpec strictly, and update implementation traceability and dependency documentation with the actual evidence.
