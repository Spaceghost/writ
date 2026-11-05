# Task 5 review: integration and the trusted identity inputs document (`c5afd1e..4ac8041`)

Reviewer: task reviewer, security review (read-only except this file). Inputs: task-5-brief.md, task-5-report.md, `.superpowers/sdd/2026-11-05-authenticated-grant-issuance/review-c5afd1e..4ac8041.diff`, the plan's Global Constraints, the earlier reviews, `Transfer.bend` (`scoped`, `header`, `admit`), `Frontend.bend` (`capability_current`, `checked_plan`, `live`), `DataOS.bend` (`admit`, `commit_from_capability`), `docs/GRANT-ISSUANCE.md`, the GI-008 spec delta, and AGENTS.md.

Controller rulings applied (not findings): a non-current grant leaves both projections, so a source revocation denies at Write; FacadeTests importing IssuanceTests is accepted.

## Verdict 1, spec compliance: APPROVED

- **Projections filter exactly on `current` at `now`, recomputed per call.** `reads_of`, `writes_of` and `registry_of` (`Issuance.bend:1951-2021`) each walk `grants(state)` and gate each record on `current(state, head, now)`, the same predicate GI-005 uses. Nothing is stored. The public entry points `reads`/`writes`/`registry` (`Issuance.bend:1962, 1989, 2023`) are pure functions of `(state, now)` and return a fresh list. No state field and no `Change` result carries a projection. Each one is marked "Public entry point" and is listed in the header (`Issuance.bend:94-99`).
- **Admission through the real paths.**
  - Issuance check 4 runs the unchanged `T.admit` on `TF.context()`, with only `reads`/`writes` replaced by the projections (`projected`, IssuanceTests).
  - Check 5 runs `F.mount`/`F.open`/`F.checked_plan` against `I.registry(...)`.
  - Facade check 1 drives `OS.commit_from_capability`, with the transfer lists and the registry both built from `I.reads`/`I.writes`/`I.registry` at 110.
  - None of these uses a hand-built grant list. The one exception is the ruled synthetic write list in check 8's first conjunct.
- **Denial at use.**
  - Check 6: `T.admit` on the rebuilt projections denies `Write`.
  - Check 7: `checked_plan` on a descriptor opened while the grant was current gives `None`.
  - Facade check 2: denied, and the ledger revision stays 1.
  - Facade check 2 is a valid use-time denial because check 1 accepts with identical inputs apart from the issuer state.
- **Mutation results reproduced.** I used my own harness on a fresh `git archive 4ac8041`, because the report names no script: `scratchpad/t5rev/harness/mut.py`, output in `scratchpad/t5rev/mut.out`.
  - `placed_read` None arm projecting `ReadDomain{0n}`: SURVIVED with check 3 removed, and KILLED with check 3 present (by "GI-008 the read-projection helper gives a source placed twice, or not placed, ..."). This matches the report's surviving-then-killed arm.
  - `reads_of`/`writes_of`/`registry_of` with `current` replaced by True: KILLED by check 6.
  - `registry_of` with `now` fixed at 100: KILLED by check 9.
  - `grant_capability` epoch 0: KILLED by check 1 and Facade 1.
  - The writes gate's True arm dropping the write: KILLED by check 1 and Facade 1.
- **The document names every trusted input in the brief.** It covers the authenticated principal (named as transport identity verification, with the Genode route subject, Linux peer credentials and the Windows token SID as sources; not a record field), the directory and placements, the live stamp and `now`, tokens, atomic durable installation (AB-006 and the durable-publication change), per-use rebuild, off-host approvals (no signature verified), and rollback.
  - It opens with the worked example, then the current gap.
  - Its links resolve, apart from the traceability file, which Task 6 creates and the document says so.
  - No sentence reads as a host guarantee. The "current gap" and "does not claim" paragraphs are explicit.
  - Two of its statements are incomplete or imprecise; see I-1 and M-1.
- **Suite and proofs green.** Fresh archive of 4ac8041, Bend 2.0.39:
  - `bend Tests.bend`: rc 0 and 980 `PASS` lines, 0 `FAIL`. The summary lines are `Transfer: 53`, `Frontend: 70`, `Facade: 12` and `Issuance: 196 checks passed`. Last lines:
    ```
    Property: 324 checks passed; 320 graph cases, each checked against CPU and Bend parallel producers
    ALL LIBRARY TESTS PASSED
    ```
  - `bend PROOF.bend`: rc 0, 12 laws in `LAWS.bend`. Last lines:
    ```
    ALL PROOFS CHECK
    Use --verdict for mathematical validity.
    ```
  - `--verdict` was not run (no kernel toolchain). This was a CPU run only, and I make no GPU claim.
- **Use-time modules unchanged.** `git diff c5afd1e HEAD -- Transfer.bend Frontend.bend DataOS.bend Tests.bend LAWS.bend PROOF.bend` is empty.
  - The diff stat touches only FacadeTests, Issuance, IssuanceTests, the new document, tasks.md (box 1.5) and the record directory.
  - No count pin was edited: `utils/nix/writ.nix`, the workflow and the README/VERIFICATION count sentences are untouched.

## Verdict 2, security and code quality: NEEDS_FIXES

One Important documentation finding: a trusted input is missing from the document that exists to name every trusted input. The code is sound.

### Important

**I-1. The document and header do not say that the transfer projections carry no subject, so only the registry binds use to the authenticated caller.**
- **Where:** `docs/GRANT-ISSUANCE.md:185-203` and `Issuance.bend:39-44, 1949-1990`.
- **The unbound lists.**
  - `T.ReadGrant`/`T.WriteGrant`/`T.GrantScope` have no subject field.
  - `Transfer.scoped` (`Transfer.bend:542-548`) matches invocation, manifest, destination, write domain, code, kind, stamp and expiry only.
  - So `I.reads`/`I.writes` are one pool of every subject's current grants.
- **Where the subject is checked.** The only subject check at use is `F.capability_current` (`Frontend.bend:245-251`), which is reached through `F.checked_plan`, which `OS.commit_from_capability` calls.
- **The bypass.** `DataOS.admit` (`DataOS.bend:30`), `Backplane.commit` (`Backplane.bend:201, 243`) and `Negotiation` (`Negotiation.bend:251, 401`) all run `T.admit` on a bare `T.Context`. A host that follows the document's wording ("the grant lists `Transfer.admit` consumes") and puts the projected lists into one of those contexts would admit a plan matching subject 7's grant for any caller.
- **The second missing input.** The use-time `F.Caller.subject` is the same transport-verified identity input as `from`. It is not named; the principal section covers only the issuance transitions.
- **Status.** The behaviour is the pre-existing Transfer contract, not a regression. But this document is where a host learns how to wire the projections, and it omits the condition that keeps them subject-bound.
- **Fix:** add a bullet to "Rebuilding the projections for every use" and a sentence to the header bullet at `Issuance.bend:39-44`. Something like: "`reads` and `writes` carry no subject. The grant's subject is enforced only by `registry` through `F.checked_plan` (`OS.commit_from_capability`). A host must supply the projected transfer lists only on a path that first resolves the caller's capability. It must never use them for `DataOS.admit`, `Backplane.commit` or a `Negotiation` context reached without it. The `F.Caller` subject presented at use is a transport-verified identity, like `from`." Optionally, add one check showing the registry alone denies another subject: `checked_plan` for `F.Caller{6n, token()}` against the projections gives `None`. Check 5 shows only the permitted subject.

### Minor

**M-1. The projection-`now` consequence is misstated, and the real reason per-use rebuild matters is not given (`docs/GRANT-ISSUANCE.md:140-143`).**
- **What the document says:** "A projection built at an earlier `now` than the use-time check can include a grant that has already expired."
- **Why that is incomplete.** Inclusion is true, but use is still denied:
  - `Transfer.scoped` re-checks `now < valid_until` and `stamp == live` against `T.Context.now`/`live` (`Transfer.bend:548`);
  - `F.capability_current` re-checks expiry and the epoch against `F.live(context)` (`Frontend.bend:251`, `100-103`);
  - grant lifetimes are already bounded by the approvals' (`Widened`) and by the parent's (derivation).
- **The answer to the review question.** A caller-chosen projection `now` cannot admit an expired or stale-epoch grant while `T.Context.now`/`live` are trusted. A later `now` only drops grants (fail-closed). What the use-time checks cannot re-derive is revocation, directory and placement changes, and the epoch only to the extent the context's `live` is itself trusted.
- **Fix:** replace the sentence with roughly: "Expiry and epoch are re-checked at use against `T.Context.now` and `live`, so a projection built at an earlier `now` cannot by itself admit an expired grant. Revocation, directory and placement changes are enforced only by rebuilding the projection, so the same time and stamp must come from the monitor for both." Also add one clause to the per-use rebuild section saying a cached list's danger is specifically revocation, directory and placement changes.

**M-2. No check isolates the registry layer's denial after revocation (`IssuanceTests.bend:1126`; FacadeTests check 2).**
- **What check 7 covers.** It passes `projected(write_revoked())`, whose writes are empty, so `T.admit` inside `checked_plan` would deny even with a stale registry.
- **Reproduced.** With `registry_of` judging every grant current, check 7 and Facade check 2 both still pass. The mutant is killed only by check 6's structural `nothing_projected` equality, not by a use-time denial.
- **Why it matters.** A host that caches the transfer lists but rebuilds the registry, or the reverse, is exactly the partial-staleness case.
- **Fix:** add a check that `F.checked_plan(descriptor(), I.registry(write_revoked(), now()), 2n, ..., F.Read{}, projected(registered()))` gives `None`: a stale transfer list with a rebuilt registry is still denied. Optionally add the converse, check 8's style with a stale registry and rebuilt lists.

**M-3. The derived-child check pins only the registry (`IssuanceTests.bend:1137-1140`).**
- Check 12 compares `I.registry(derived(1, 120n), now())` exactly, but not `reads`/`writes`.
- The child's Transfer scope should carry lifetime 120. `grant_scope` uses the record's own `valid_until`, and the `grant_scope` lifetime-200 mutant is killed only via grant 3.
- **Fix:** add `reads_equal`/`writes_equal` for the derived state, with `TF.scope_for(TF.plan(), write6(), 120n)` entries ahead of grant 3's entries.

**M-4. Two policy inputs are not named (`docs/GRANT-ISSUANCE.md:185-196`).**
- The projections replace only the grant fields of `T.Context`. The live stamp, `now`, source/destination policies, operation and payments remain host-supplied Transfer inputs.
- `ReadGrant.matches` requires the projected read domain to equal the source policy's domain.
- The direction of failure is safe: divergent placements deny.
- **Fix:** add one sentence saying the issuer's placements and the context's source/destination policy domains must come from the same monitor record.

### Nits

- `grant_registered` (`Issuance.bend:2003`) reads like a predicate. `grant_capabilities`, parallel to `grant_reads`/`grant_writes`, would be clearer.
- `docs/GRANT-ISSUANCE.md:71` runs past the paragraph's wrap width.

### Security questions from the brief, answered

- **Could a projection include a grant `current` would deny?**
  - Not for the same `(state, now)`: the gate is `current` itself, applied per record with the whole state.
  - With a caller-chosen `now`, it could include an expired grant, but use is still denied by the use-time expiry and epoch checks (M-1).
  - The trust assumption is that `now`, `T.Context.now` and `live` come from the monitor. The document names this (lines 137-139).
- **Could a stale projected list held by a caller still admit a revoked grant?** Yes, if the host lets it. Bend cannot detect it.
  - The header (`Issuance.bend:39-44`) and the document (lines 197-202) say to rebuild per use, never cache, never accept a caller-supplied list, and that a cached list keeps a revoked grant usable.
  - Descriptors opened while a grant was current are re-validated against the rebuilt registry (check 7).
- **Completeness.** Every `current` grant contributes:
  - one read per manifest entry, since `current` guarantees each source is placed once, so the `None` arm is unreachable for current grants;
  - one write;
  - one capability.
  - Check 11 shows a withdrawn head grant does not drop the grant behind it. No drop was found.
- **Partial matches.** The projection cannot be partial for a current grant, because the only partial arm (`placed_read` None) is unreachable then and is pinned by check 3. A partial reads list would deny at `Read` anyway.
  - Cross-grant mixing gives nothing: every grant's read and write entries bind identical plan fields, and they are added and removed together.
- **Derived grants.** A read-only derived child still contributes a `WriteGrant`, because Transfer grants carry no rights. That is not an escalation: the child is current only while its parent is, and the parent contributes the same scope with a longer lifetime. Rights stay a Frontend dimension.
- **Facade checks drive a real path.** Both call the unchanged `OS.commit_from_capability`, with the context and registry built from the projections. The descriptor is mounted from the projected registry.

## What I ran

- `git diff c5afd1e HEAD -- Transfer.bend Frontend.bend DataOS.bend Tests.bend LAWS.bend PROOF.bend`: empty.
- `git diff --stat c5afd1e 4ac8041`: the 7 files listed above.
- On a fresh `git archive 4ac8041` in `scratchpad/t5rev/tree`:
  - `bend Tests.bend`: rc 0, 980 `PASS` lines, 0 FAIL.
  - `bend PROOF.bend`: rc 0, `ALL PROOFS CHECK`.
- `scratchpad/t5rev/harness/mut.py`: 8 mutants. One survived as expected (with check 3 removed), and 7 were killed. Each mutant ran `bend IssuanceTests.bend` and `bend FacadeTests.bend`.
- I checked that the document's link targets exist: the spec, `openspec/specs/authority-boundary/spec.md` (AB-006), `openspec/changes/add-durable-publication/proposal.md` and `docs/PLATFORMS.md`.
