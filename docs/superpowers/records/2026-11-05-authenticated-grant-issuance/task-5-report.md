# Task 5 report: integration and the trusted identity inputs document (task 1.5; GI-008)

Status: DONE_WITH_CONCERNS. The concerns: the source-revocation denial reason differs from the brief's wording (explained below), the brief's count estimates are stale, and `--verdict` was not run. Nothing is blocked.

## Files

- `Issuance.bend`: a new final section, "Projection into the use-time checks (GI-008)". Header changes: a trusted-input bullet for the projections, `reads`/`writes`/`registry` added to the public entry points, and a pointer to `docs/GRANT-ISSUANCE.md`. No earlier gate, order, reason or law changed.
- `IssuanceTests.bend`: imports `Frontend.bend as F`. Adds integration fixtures (synthetic) and the `integration` section (13 checks), and `main` prints `Issuance: 196 checks passed`. Adds two public fixtures for FacadeTests: `execute_state` and `execute_write_revoked`.
- `FacadeTests.bend`: imports `Issuance.bend as I` and `IssuanceTests.bend as IF`, adds the issuer-path helpers and 2 checks, and the count string goes from 10 to 12.
- `docs/GRANT-ISSUANCE.md`: new.
- `openspec/changes/add-authenticated-grant-issuance/tasks.md`: box 1.5 checked, with evidence.
- These are unchanged since c5afd1e: `Transfer.bend`, `Frontend.bend`, `DataOS.bend`, `Tests.bend`, `LAWS.bend`, `PROOF.bend`, every count pin, and the do-not-touch files. No use-time module needed a change.

## The projection and what it filters

There are three public entry points. Each walks `grants(state)` and gates every record on `current(state, grant, now)`:

| Entry point | Per current grant | Fields |
|---|---|---|
| `reads(state, now) -> T.Reads` | one `T.ReadGrant` per manifest entry, in manifest order | source = the manifest object version; domain = `source_domain(placements(state), object)`; scope = `grant_scope(grant)` |
| `writes(state, now) -> T.Writes` | one `T.WriteGrant` | destination = the plan's destination; domain = the scope's `write_domain`; scope = `grant_scope(grant)` |
| `registry(state, now) -> F.Registry` | one `F.Capability` | token; subject = the scope's subject; plan; rights; `F.authority(plan stamp)`; expires = the grant's `valid_until` |

`grant_scope` builds `T.GrantScope{invocation, inputs, destination, write_domain, code, kind, stamp, valid_until}` from the plan, the scope's write domain and the grant's own `valid_until`. For a derived grant that is its attenuated lifetime, not the approvals'.

What is filtered:

- The filter is exactly `current`. A grant that is not current contributes nothing to any of the three projections. That covers a revoked source or write approval, a directory, placement or epoch change, expiry, an id that is ambiguous or not registered, and a withdrawn ancestor of a derived grant. So a grant is never projected half usable.
- `current` is evaluated against the whole state for each record. A record that its approvals do not back is therefore not projected.
- Nothing is cached. Each call re-walks the list. The header and the document say the host must rebuild all three projections for every use.
- `placed_read` has an arm for a missing or ambiguous placement that projects no read rather than guessing a domain. It is defensive: `current` already requires every manifest source to be placed once in its approval's domain, through the root of a derived chain. A direct helper check pins it.
- Tokens in the projected registry are distinct because `register` and `derive` deny a held token. `F.registry_valid` would otherwise reject the whole registry.

Helpers (exported implementation helpers, not entry points): `grant_scope`, `placed_read`, `manifest_reads`, `grant_reads`, `reads_of`, `grant_write`, `grant_writes`, `writes_of`, `grant_capability`, `grant_registered`, `registry_of`.

## Checks

Section `integration` in `IssuanceTests.bend`, 13 checks:

1. "GI-008 grant 3 projects exactly one read of 10v4 in read domain 5, one write of 20v8 in write domain 6 and one capability for subject 7, each bound to TF.plan() until 150". Exact list equality for all three projections, every field compared.
2. "GI-008 the two-source grant projects one read per manifest entry, in manifest order, each in its placed read domain".
3. "GI-008 the read-projection helper gives a source placed twice, or not placed, no read rather than a guessed domain (defensive: no current grant has such a source)".
4. "GI-008 the projection of registered grant 3 makes T.admit admit TF.plan()". This uses TF.context() with its reads and writes replaced by the projections.
5. "GI-008 F.mount, F.open and F.checked_plan resolve grant 3's projected capability for subject 7 to TF.plan()".
6. "GI-008 revocation after registration: with the write approval revoked the rebuilt projection is empty and T.admit denies Write".
7. "GI-008 revocation after registration: checked_plan on the descriptor opened while grant 3 was current gives None".
8. "GI-008 with the source approval revoked the rebuilt read projection denies Read even beside a write list that still permits; both projections rebuilt deny at Write, the first check".
9. "GI-008 every projection of grant 3 is empty at its valid_until 150 and not at 149".
10. "GI-008 two current grants both project, newest first".
11. "GI-008 a withdrawn grant is filtered without dropping the current grant behind it". Grant 6 at the head is revoked; grant 3 is still projected and admits.
12. "GI-008 a derived child projects its own attenuated rights and lifetime, and revoking the root's source approval withdraws parent and child together".
13. "GI-008 an authority epoch advance or a directory change withdraws grant 3 from every projection".

`FacadeTests.bend`, 2 checks. Both drive the unchanged `OS.commit_from_capability`. The `OS.Context` is built from `BF.context()`: its transfer context's reads and writes, and its registry, are the projections at time 110 of an issuer state (grant 3 for subject 7, rights 7 until 180). The descriptor is mounted and opened from the projection while the grant is current.

1. "GI-008 a grant registered by the issuer, projected into the transfer grants and registry, commits through the facade". It is accepted, and `BF.retained` holds.
2. "GI-008 after the issuer revokes the write approval the rebuilt projections deny the facade commit and spend no reservation". It is denied, and the ledger revision stays 1.

## Removal map (mutation exercise)

Each mutant was applied to a scratch copy of the tree. `bend IssuanceTests.bend` and `bend FacadeTests.bend` were then run, and a mutant counts as killed when either fails.

| Mutant | Killed by |
|---|---|
| reads gate: False projects anyway | Issuance 6 |
| reads gate: False drops rest | Issuance 11 |
| reads gate: True projects nothing | Issuance 1, Facade 1 |
| reads gate: True drops rest | Issuance 10 |
| reads_of: `current` replaced by True | Issuance 6 |
| reads_of: `now` fixed at 100 | Issuance 9 |
| reads_of: tail not walked | Issuance 10 |
| placed_read: Some dropped | Issuance 1, Facade 1 |
| placed_read: None projects read domain 0 | Issuance 3 (it survived the first pass; check 3 was added for it) |
| manifest_reads: later manifest entries dropped | Issuance 2 |
| grant_scope: lifetime 200 instead of the grant's | Issuance 1 |
| writes gate: False projects anyway / False drops rest / True projects nothing / True drops rest | Issuance 6 / 11 / 1 and Facade 1 / 10 |
| writes_of: `current` replaced by True / `now` fixed / tail not walked | Issuance 6 / 9 / 10 |
| registry gate: False registers anyway / False drops rest / True registers nothing / True drops rest | Issuance 6 / 11 / 1 and Facade 1 / 10 |
| registry_of: `current` replaced by True / `now` fixed / tail not walked | Issuance 6 / 9 / 10 |
| grant_capability: epoch 0 | Issuance 1, Facade 1 |
| grant_capability: lifetime 200 | Issuance 1 |

All 27 mutants are killed: 26 in the first pass, and the last one after check 3 was added. None is equivalent.

## `docs/GRANT-ISSUANCE.md`, in brief

- It opens with the worked example from the plan header: the write-domain-6 principal is denied `NotAuthority` for object 10, with the test name. It follows with the reverse GI-008 case: a write revocation denies at `Write` and through the facade.
- The current gap: the model is implemented. Host transport, durable state and host wiring are not, and there is no facade entry.
- Links: the spec, `openspec/traceability/grant-issuance.md` (Task 6 creates it), and `openspec/specs/authority-boundary/spec.md`.
- A table of every public entry point. It also lists the parameters that are untrusted claims.
- Each trusted input, with what Bend does with it, who supplies it, and what goes wrong if it is wrong:
  - the authenticated `Principal` (`from`). Its dependency is transport identity verification; examples are `HostBinding.Route.subject`, Linux peer credentials and the Windows token SID. It is not a record field.
  - the directory and the placements.
  - the live stamp and `now`.
  - fresh tokens.
  - atomic installation at `expected_revision`, with durability (AB-006 and the pending durable-publication change).
  - rebuilding the projections for every use.
  - approvals carried off-host: Bend verifies no signature, and cryptographic verification is a host input this change does not implement.
  - rollback: never restore an old epoch, never drop `seen`, revocation flags or consumed markers.
- A closing "does not claim" paragraph.

## Verification

- `bend Issuance.bend --check-only`: `ALL PROOFS CHECK`.
- `bend Tests.bend`: 980 `PASS` lines, 0 `FAIL`. That is 782 plus 196 Issuance plus 2 new Facade checks (965 + 15). The summary lines:
  - `Transfer: 53 checks passed`
  - `Frontend: 70 checks passed`
  - `Facade: 12 checks passed`
  - `Issuance: 196 checks passed`
  - last line: `ALL LIBRARY TESTS PASSED`
- `bend PROOF.bend`: last lines `ALL PROOFS CHECK` / `Use --verdict for mathematical validity.` There are 12 laws, unchanged. This task adds no law.
- `--verdict` was not run (the kernel toolchain is unavailable, as in Tasks 1 to 4). No GPU claim is made.

## Concerns

1. **The source-revocation reason.** The brief says a source-approval revocation gives a `Read` denial. Under the ruling, a non-current grant appears in no projection, so either revocation withdraws the whole grant from both lists. `Transfer.admit` checks the write grant in `header`, before `Sources.check`. So with both projections rebuilt, a source revocation also denies at `Write`. Check 8 asserts both facts: the rebuilt read projection alone, beside TF's synthetic write list, denies `Read`, and with both lists rebuilt the denial is `Write`. I chose not to project per side, because that would leave a half-usable grant in one list.
2. **Counts.** The brief estimated about 6 Issuance checks, 2 Facade checks and a suite of about 854; the 854 is stale. The actual counts are 13 Issuance checks, 2 Facade checks and a suite of 980. No count pin was edited, per the cross-lane ruling.
3. **FacadeTests imports IssuanceTests.** It does this for the issuer fixtures (the state, the token and the pair builder). It is a test-to-test import only, with the same shape as the existing `TF`/`BF`/`NF` imports, and the facade itself is untouched.
4. **`--verdict` was not run.** See Verification.

## Fix round 1

Source: task-5-review.md (spec APPROVED; security NEEDS_FIXES for I-1 and M-1 to M-4).

### I-1: I took the structural option, subject-scoped projections

The three projections now take the authenticated principal of the use: `reads(state, from, now)`, `writes(state, from, now)` and `registry(state, from, now)`.

- **The filter.** One named helper, `usable_by(state, grant, from, now)`, is `speaks_for_subject(from, Grant.scope(grant)) && current(state, grant, now)`. It replaces the bare `current` gate in `reads_of`, `writes_of` and `registry_of`.
- **What a list now holds.** A list built for one caller never holds another subject's grant. That holds even on a path that runs `T.admit` without Frontend's caller check (`DataOS.admit`, `Backplane.commit`, Negotiation).
- **The registry is scoped too.** This keeps the three lists consistent, and Frontend's own subject check still applies on top.
- **Why the structural option and not a documented hazard.** The fix is local to `Issuance.bend`, and the use-time modules stay untouched. The changed signatures are used only by the tests, which I updated: the facade tests build their projections for `I.Principal{7n}`, the Ref's caller.
- **Header.** The bullet now says the projections take the use's principal, that this principal is the same transport-verified identity as `F.Caller.subject`, that a projection built for another principal must not be reused, and that expiry and epoch are re-checked at use while revocation, directory and placement changes are not.
- **Document.**
  - A new section, "The subject of a use", covers what Bend does, who supplies the principal, and what goes wrong otherwise. It names `DataOS.admit`, `Backplane.commit` and Negotiation as the paths without a caller check.
  - The principal section says the projections take `from`, and that `from` is `F.Caller.subject` at use.
  - The entry-point table shows the new signatures.

New checks in the `integration` section:

- "GI-008 subject-scoped projections: subject 7's current grant 3 projects nothing for principal 8, principal 6 or principal 0"
- "GI-008 subject-scoped projections: on a path that runs T.admit without Frontend's caller check, principal 8 gets no admission from subject 7's grant"
- "GI-008 subject-scoped projections: with grants for subjects 7 and 8 on one plan, each principal's projections hold exactly its own grant". The fixture `two_subjects` adds grant 6 for subject 8 on the same plan.
- "GI-008 the registry layer alone denies another subject: subject 6 presenting grant 3's token on subject 7's descriptor gets no plan". This is the review's optional check.

### M-1 to M-4 and the nits

- **M-1.** The live stamp and `now` section now says:
  - expiry and epoch are re-checked at use against `T.Context.now`/`live`, so a projection built at an earlier `now` cannot by itself admit an expired grant;
  - a later `now` only drops grants;
  - revocation and directory or placement changes are enforced only by rebuilding, so the time and stamp must come from the monitor for both.

  The per-use section says a cached list's danger is specifically revocation and directory or placement changes.
- **M-2.** New check: "GI-008 partial staleness: a rebuilt registry beside stale transfer lists, or a stale registry beside rebuilt lists, still gives no plan after the write revocation". To confirm it kills the review's mutant on its own, I ran it as the only integration check against the `registry_of` gate with the currency conjunct removed: it fails, and it passes unmutated.
- **M-3.** The derived-child check now also pins `reads` and `writes` exactly. The child's entries carry `TF.scope_for(TF.plan(), write6(), 120n)` and come ahead of grant 3's. Run alone, it kills the `grant_scope` lifetime-200 mutant.
- **M-4.** The per-use section says:
  - the projections replace only the grant fields of `T.Context`;
  - the live stamp, `now`, policies, operation and payments stay host Transfer inputs;
  - the issuer's placements and the context's policy domains must come from the same monitor record; a divergence denies.
- **Nits.**
  - `grant_registered` is renamed `grant_capabilities`.
  - The long line in the document is rewrapped.
  - The derived check's name now says "into the registry and the Transfer scopes".

### Mutation exercise on the new branches

Mutants were applied to a scratch copy, and each run executed `bend IssuanceTests.bend` and `bend FacadeTests.bend`.

| Mutant | Killed by |
|---|---|
| `usable_by`: subject conjunct dropped | subject-scoped "projects nothing for principal 8, 6 or 0" |
| `usable_by`: currency conjunct dropped | "revocation after registration ... T.admit denies Write", and Facade check 2 |
| `reads_of` / `writes_of` / `registry_of` gate is `current` only | subject-scoped "projects nothing ..." (each) |
| `reads_of` / `writes_of` / `registry_of` gate is subject only | "revocation after registration ... denies Write" (each); for the registry, also the M-2 check alone |
| `reads_of` / `writes_of` / `registry_of` tail walked for principal 7 | "with grants for subjects 7 and 8 on one plan ..." (each) |
| `grant_scope` lifetime 200 | grant 3 exact check; the M-3 derived check alone |

All 12 are killed, and none is equivalent. The scripts are `t5mut2.py` (the whole suite) and a check-isolation run, both in the session scratchpad.

### Verification

- `bend Issuance.bend --check-only`: `ALL PROOFS CHECK`.
- `bend Tests.bend`: 985 `PASS` lines, 0 `FAIL`. That is 782 plus 201 Issuance plus 2 new Facade checks. The summary lines:
  - `Transfer: 53 checks passed`
  - `Frontend: 70 checks passed`
  - `Facade: 12 checks passed`
  - `Issuance: 201 checks passed`
  - last line: `ALL LIBRARY TESTS PASSED`
- `bend PROOF.bend`: `ALL PROOFS CHECK` / `Use --verdict for mathematical validity.` There are 12 laws, unchanged.
- `git diff 4ac8041 -- Transfer.bend Frontend.bend DataOS.bend Tests.bend LAWS.bend PROOF.bend` is empty.
- `--verdict` was not run (no kernel toolchain).
