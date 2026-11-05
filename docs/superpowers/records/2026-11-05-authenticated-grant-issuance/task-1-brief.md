### Task 1: Authenticated issuer and subject records (task 1.1; GI-001, GI-004 records)

Implements "GI-001 Source approval authenticates its issuing domain" and the record half of "GI-004 Issued capability binds the authenticated subject". Create `Issuance.bend` with:
- the types and accessors above, plus `empty(live, directory, placements)` (public entry point);
- the helpers `is_read_authority(directory, principal, domain)`, `is_write_authority(...)`, `source_domain(placements, object)` and `destination_domain(...)`, which return a `Maybe` (missing means deny), `version_supported`, `rights_valid`, `claim_matches(from, issuer)` and `scope_wellformed(scope, live)` (nonempty manifest, stamp equals live, subject > 0);
- `valid(state)`, a structural check only.

Add two public transitions, each taking `(state, expected_revision, from: Principal, approval, now)`:
- `submit_source(...)` requires: revision current, version 1, `claim_matches`, `from` is the read authority for the approval's domain, the placement of the approval's source equals that domain, the source occurs in the scope's manifest, the scope is well formed at the live stamp, the rights are valid, `now < valid_until`, and the serial is unseen. It then stores the approval under a fresh id, records the serial, and advances the revision once.
- `submit_write(...)` has the same checks against the write directory and destination placement, and the destination equals the scope plan's destination object version.

Write the module header: the authority model, which inputs are trusted, that constructing an `Issuance` record authenticates nothing, and the public entry points.

Tests (`submission` section), each with exact reason and an unchanged state:
- A valid source approval from its read authority is accepted, gets id 1, and advances the revision by 1.
- Caller-supplied authority cannot register:
  - The principal that controls only write domain 6 submits a source approval for object 10 under its own identity: `NotAuthority` (the spec's "Forged source issuer").
  - The approval names the true source authority as `issuer`, but `from` is the write principal: `Unauthenticated`.
  - The approval names read domain 9, which `from` does control, but object 10 is placed in read domain 5: `WrongDomain`.
  - The source authority submits a write approval: `NotAuthority`, because control of one namespace does not confer the other.
  - The same numeric domain id (5) in the read and write directories does not cross.
  - An unknown principal: `NotAuthority`.
  - With both approvals submitted, `grants` is still empty and no grant exists for the plan.
- Record version 2: `UnknownVersion`.
- A stale `expected_revision`: `StaleRevision`.
- Rights 8: `InvalidRights`.
- A source that is not in the scope's manifest: `ScopeMismatch`.
- A scope stamp other than live: `StaleEpoch`.
- Subject 0: `SubjectMismatch`.
- A repeated `(issuer, serial)`: `Replay`.
- A write approval for destination version 9 when the plan names version 8: `ScopeMismatch`.

Estimate about 16 checks. Register the suite in `Tests.bend`. Laws: none added. Check box 1.1, citing the test names.

Acceptance: `bend Tests.bend` is green with about 798 checks, and `bend PROOF.bend` is green with six laws, unchanged. No record field asserts authority. The header documents every trusted input this task uses.

