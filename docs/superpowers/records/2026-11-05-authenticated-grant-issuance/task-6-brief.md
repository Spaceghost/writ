### Task 6: End-to-end evidence and traceability (task 2.1)

Add a `scenarios` section that walks one lifecycle per case, each from an `empty(...)` state through the public entry points only:
- Current authority: two sources and two authorities, submission, registration, projection, `T.admit` and `checked_plan` accepted.
- Revocation:
  - A source revocation mid-flow; registration after it is denied, and so is use.
  - A revocation after a derivation; the child dies.
- Replay: a serial resubmitted after revocation, a second registration, and a consumed approval cited by another request.
- Denial cases: a forged issuer, a redirect, an expanded manifest, subject substitution, an epoch advance, and the deadline.

Estimate about 10 checks. Write `verification/grant-issuance.txt`: the commands, Bend version, date, the Issuance and Facade output lines, the total, and what was not exercised (transport authentication, signatures, durable storage, concurrent hosts, any native host; a CPU run is not a GPU test). Write `openspec/traceability/grant-issuance.md` in the `transfer-admission.md` table shape. It has one row per GI-001 to GI-008 with functions, the exact named tests and the coverage boundary, and it marks reviewed-only gaps explicitly (for example, host serialization of installs, and per-use projection rebuilding). It opens by saying the change is proposed and that no host adapter or acceptance scenario is implemented. Replace the "authenticated grant issuance is deferred" sentence in `transfer-admission.md` with a link to that file, stating that issuance is modeled in Bend and is not wired to a host. Check box 2.1.

Acceptance: green suite at about 864 checks and green proofs. Every traceability row cites existing test names verbatim, and the evidence file matches the run.

