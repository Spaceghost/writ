### Task 2: Exact paired-scope registration (task 1.2; GI-002, GI-003, GI-004)

Implements "GI-002 Destination approval precedes effective read issuance", "GI-003 Both approvals bind one complete scope" and "GI-004 Issued capability binds the authenticated subject". Add the public entry point `register(state, expected_revision, request: Request, now, token)`. `Request{version, scope, sources: Ids, write: Nat, rights, valid_until}` names the stored source approval ids in manifest order and one write approval id. Ruling: the request carries no requester identity. Authority comes only from the cited approvals, and the subject is fixed by them.

The `register_checks` list requires:
- revision current and version 1;
- the source ids have the same length and order as the scope plan's manifest, each approval is present, unconsumed and unrevoked, and its source equals the manifest entry at that position (`sources_cover_manifest`, which walks the manifest and the id list together, so it has no index);
- every cited approval's scope satisfies `scope_equal` against the request scope;
- the write approval is present, unconsumed and unrevoked, and its destination and domain match the scope;
- each approval's issuer is still the directory authority and its placement still holds, which is revalidation, not trust in the stored record;
- the scope stamp equals live;
- the requested rights are valid and within every approval's rights (`rights_within`);
- `now < valid_until`, the requested `valid_until` is ≤ every approval's (`lifetime_within`), and every approval satisfies `now < its valid_until`;
- the token is fresh.

On acceptance, store `Grant{id, token, scope, rights, valid_until, sources, write, parent: 0n}`, mark the cited approvals consumed, and advance the revision once.

Tests (`registration` section):
- A one-source paired registration is accepted.
- A two-source plan (objects 10 and 11 in read domains 5 and 7, with distinct authorities) is accepted only with both source approvals in manifest order.
- No write approval is cited, or the cited id does not exist: `MissingApproval` (the spec's "Missing destination approval").
- The write approval was issued under the wrong write domain (it was submitted for domain 6, but the request scope says 9): `ScopeMismatch`.
- Redirected destination: the source approval names A to X, and the write approval names Y: `ScopeMismatch` (the spec's "Redirecting an existing read").
- Expanded manifest: the write approval adds source B, so the manifests differ: `ScopeMismatch`.
- A source approval is missing for one manifest entry, or the ids are reordered: `MissingApproval` or `ScopeMismatch`.
- The approvals differ only in invocation, in the eighth code word, or in kind: `ScopeMismatch`.
- Recipient substitution: the approvals are for subject R and the request asks for S: `SubjectMismatch`. The request for R is accepted.
- The requested rights 7 exceed the source approval's 3: `Widened`.
- A duplicate token: `DuplicateToken`.
- Request version 2: `UnknownVersion`.
- The source authority is removed from the directory between submission and registration (a new state from the monitor): `NotAuthority`.

Estimate about 18 checks. Laws: none added. Check box 1.2.

Acceptance: green suite at about 816 checks and green proofs. Every spec denial listed for 1.2 has a named test with its exact reason.

