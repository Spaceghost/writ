# Final whole-branch review: lane/authenticated-grant-issuance

Assessment: **Needs fixes before merge**. There is one Important finding, I-1: `register` is open to any caller, so whoever calls first can use up an approval pair and choose its terms. The fix can be a code change or a documented host precondition. The rest of the branch is sound: the laws, the proofs, the use-time recheck, the projections, the records and the evidence.

Reviewed tree: `5fe21c8` (worktree HEAD; merge base `d56325b`; master has since moved by one questions-only commit, `a434cd0`). The diff came from `.superpowers/sdd/2026-11-05-authenticated-grant-issuance/final-diff.diff`. I read Issuance.bend in full, and the LAWS.bend and PROOF.bend diffs in full.

## Findings, by severity

### I-1 (Important, blocking): anyone can call `register`, so a third party can use up an approval pair and pick the grant's terms

`Issuance.bend:66-69` (header) and `Issuance.bend:1281` (`register`). `register` takes no `from`, by the Task 2 plan ruling ("the request carries no requester identity"). The cited approvals fix the scope and the subject. The caller, though, still chooses `rights` (any valid subset, including 0), `valid_until` (anything after `now`), and the moment of registration. Approvals are single use (`Unconsumed` gates), so the first registration consumes the pair for good.

Approval ids are sequential and come back in every `Change.issued`, so any party that can reach the entry point can do this. That includes a principal who is neither an authority nor the subject. It can register the pair with rights 0 until `now+1`. That burns both approvals, and the subject's own registration is then denied `Replay`. My scenario (g) shows it on the real entry points: `register(both(), 2, request_with(scope(), [1], 2, rights 0, until 101), 100, token)` is accepted. The subject's `good_request()` at revision 3 is then denied Replay.

No authority is widened: the subject is still the approved one, and the bounds hold. So this is denial of service plus terms the subject never agreed to, not escalation. Still, it is an authority-service availability hole. No document mentions it: GRANT-ISSUANCE.md:89-91 presents "register takes no from" as purely a strength, and the traceability rows show no gap. The approving authorities can recover only by reissuing approvals with new serials.

Fix (choose one; option A changes a plan ruling, so it needs the controller's ruling):
- A (preferred, code): give `register` a `from: Principal` parameter and add a gate after `UnknownVersion`, `speaks_for_subject(from, Request.scope(request))` with reason `SubjectMismatch` (or `Unauthenticated`). Add one permitted and one denied named check, one of them a scenario. Restate the three `register` laws with the extra quantifier. This is a signature change, not a weakening. The proofs go through unchanged, because the outer revision match still comes first. The header, GRANT-ISSUANCE.md "The authenticated principal" and the GI-004 row then need updating.
- B (minimum, documents only): add a precondition 8 to `docs/GRANT-ISSUANCE.md` "Remaining host preconditions": the host must accept `register` only from the scope's subject (or from an approving authority acting for it), because any caller could otherwise consume single-use approvals with terms it chose. Fix the sentence at GRANT-ISSUANCE.md:89-91 and the header at Issuance.bend:66-69 to match. Add a reviewed-only gap to the GI-002 and GI-004 rows of `openspec/traceability/grant-issuance.md`.

### M-1 (Minor): rights do not limit the Transfer projections

`Issuance.bend:1986-1997` (`grant_write`/`grant_writes`), with `manifest_reads`. `reads`/`writes` give every current grant one `ReadGrant` per manifest entry and one `WriteGrant`, whatever the grant's `rights`. Transfer grants carry no rights. On a bare `T.admit` path (`DataOS.admit`, `Backplane.commit`, Negotiation), a rights-0 grant admits its whole plan: scenario (h) passes. The Task 5 review accepted this for derived children: they live no longer than the parent, so there is no escalation. A root grant registered with rights 0 or 1 still projects a write that its write authority approved only for those rights. No authority goes beyond what the approvals' scope covers, but the document does not say that rights are a Frontend-only dimension. Fix: one sentence in GRANT-ISSUANCE.md "The subject of a use" or "Rebuilding the projections": "`rights` constrain only Frontend handles; a bare `T.admit` path admits a current grant's plan whatever its rights, including 0." Optionally, `rights_valid` at registration could deny rights 0.

### M-2 (Minor): the clock is never required to be monotone

`unexpired` (`Issuance.bend:582`) checks only an upper bound, and nothing records when an approval or grant came into existence. If `now` goes backwards, three things happen. A grant registered at 100 is current at 50. A grant that expired at 150 is current again at 149. Approvals valid until 100 still register at a regressed time of 50. Scenario (e) passes all three. GRANT-ISSUANCE.md:141-147 and precondition 4 (line 320) say "trusted clock", and that a slow clock "extends every lifetime". Neither says that the time must never go backwards between transitions and uses. Fix: in precondition 4, write "a trusted, monotone clock: `now` never decreases across transitions and uses of one issuer state". Add the same to the GI-007 reviewed-only gap.

### M-3 (Minor, open item): there is no grant-level revocation

Only approvals can be revoked (`revoke`, `Issuance.bend:1410`). So a derived grant cannot be withdrawn on its own. Neither the subject nor an authority can withdraw one child, or the middle of a chain, without revoking the root's approval, which kills the whole chain. Scenario (b), "middle grant revoked", therefore cannot be expressed through the public entry points. The spec does not ask for it: GI-005 and GI-008 talk about approvals. Fix: list it as open under GRANT-ISSUANCE.md "What this document does not claim", or in a follow-up change. A merge does not need it.

### M-4 (Minor): one stale comment

`Issuance.bend:1279`: "projection (task 1.5) admits only current grants". The projections exist now and are scoped to the subject. Fix: "the projections `reads`, `writes` and `registry` admit only the authenticated principal's current grants".

### M-5 (Minor, already raised): OpenSpec item count 37 to 44

The Task 7 review's single finding: `verification/grant-issuance.txt` does not explain the move from 37 to 44. That fix belongs to Task 7's own round. It is repeated here only so it is not lost at merge.

### Nits (no fix required)

- When the parent fails `current` because the epoch advanced, `derive` reports `Revoked` rather than `StaleEpoch` (scenario (a)). The header (`Issuance.bend:76-79`) and the `derive_gates` comment document this, so no fix is needed.
- `seen` is keyed by `(issuer, serial)` and shared by source and write approvals. A principal that is both a read and a write authority cannot reuse one serial across the two kinds. This fails closed.
- The plan's "about 16 checks" (plan lines 80 and 168) and "about 798 checks" (line 82) are pre-implementation estimates in the plan. No delivered document repeats them. "Task 6 of this change creates" and "864" appear nowhere in the delivered tree. "1008" appears only in historical statements that are explained (tasks.md 2.1, and grant-issuance.txt:33-34, "Task 6 recorded 1008 ... task 2.2 added the two GI-003 checks").

## My own scenarios (a) to (h)

I ran these as `ReviewScenarios.bend` on a scratch copy of the tree. It is kept at `/tmp/claude-1000/-mnt-MediaVolume-Media-src-github-com-spaceghost-writ/55038343-2e0b-4235-a6a8-7c68c6dd1f50/scratchpad/finalmut/ReviewScenarios.bend` and uses the IssuanceTests synthetic fixtures. All 19 checks printed PASS, each meaning the behaviour stated:

- (a) Epoch N, then N+1. Grant 3 is current at epoch 3 and not current once the monitor installs epoch 4 (`with_live`). Nothing is projected, and `T.admit` denies. `derive` from grant 3 at N+1 is denied `Revoked`. Registering the epoch-N pair at N+1 is denied `StaleEpoch`. **Holds.**
- (b) Three-deep chain 3 -> 4 -> 5. All three are current. Revoking the root's source approval after the leaf was derived withdraws all three, and nothing is projected. A middle record narrowed in place (synthetic state) makes the leaf not current, because attenuation is checked against the exact parent record. The leaf expires at its own 110 while the middle stays current. "Middle revoked" as such cannot be expressed: grants have no revocation (M-3). **Holds; gap noted.**
- (c) One approval pair, two registrations at revision 2. Both are accepted when each is evaluated against the same pre-state: Bend cannot serialize, which is AB-006, a host precondition, as documented. Once the first is installed, the second at revision 2 is denied `StaleRevision`, and rebased to revision 3 it is denied `Replay`. **Holds, given serialized installs.**
- (d) The write authority for domain 5 submits a source approval for read domain 5. It is denied `NotAuthority`, and the state equals the input (via `IF.denied`). **Holds.**
- (e) `now` going backwards. Bend has no lower bound: a grant registered at 100 is current at 50; a grant that expired at 150 is current again at 149; approvals that expire at 100 register at 50. **Behaves as modeled; needs the monotone-clock precondition (M-2).**
- (f) Projections for the subject of a revoked chain (subject 7; a derived grant's parent has the same subject by construction). After the root revocation, nothing is projected for 7 or for 8, and `T.admit` on the rebuilt lists denies. Separately, the existing check "a withdrawn grant is filtered without dropping the current grant behind it" covers a sibling grant that is still current. **Holds.**
- (g) Third-party registration (beyond the brief). It is accepted with rights 0 and lifetime `now+1`, and the subject's own request is then denied `Replay`. **This is I-1.**
- (h) A rights-0 grant on a bare `T.admit` path (beyond the brief). `T.admit` admits the plan. **This is M-1.**

## What I verified and how

- **Laws.** `git diff master..HEAD -- LAWS.bend PROOF.bend` contains only additions (0 removed lines). The six existing laws are untouched. I read all six new statements and proof terms:
  - Two are arithmetic helpers, and their headers say so.
  - The three stale-revision laws are not trivially true. Each holds only because the transition matches on `revision_current` first and its Rejected branch carries the input state. The Task 3 review replaced the tautological `issuance_denied_preserves_state`, and Task 4 recorded that removing the gate makes the proof fail.
  - `derived_lifetime_extension_rejects` has a satisfiable hypothesis (`found`) and depends on the outer `lifetime_within` match.
  - Every law has a rationale in both the module header (`Issuance.bend:104-137`) and LAWS.bend, and VERIFICATION.md lists them.
  - `bend PROOF.bend`: `ALL PROOFS CHECK`, run by me. There is no `--verdict` and no Lean, and nothing on the branch claims otherwise; kernel-verdict.txt records NOT VERIFIED.
- **Holes, unsafe definitions, indexes.** There are none. The `_` placeholders in PROOF.bend are rewrite-motive positions of `%Equal.sym`, and the checker accepts them. The data are lists and are walked structurally. No arrays are indexed: `sources_cover_manifest` walks the manifest and the ids together.
- **Every request field traced to its check.**
  - `SourceApproval` and `WriteApproval`: `version` (version_supported), `serial` (seen), `issuer` (claim_matches against `from`, then the directory), `source`/`destination` (placements, manifest or plan destination), `domain` (directory and placement), `scope` (well-formed at live; destination and domain against the scope), `rights` (rights_valid), `valid_until` (unexpired).
  - `Request`: every field is checked against the stored approvals. Its `scope` must pass SameScope and well-formedness, `sources`/`write` must pass Present, kind, Unconsumed, Unrevoked, ids_distinct and coverage, and `rights`/`valid_until` must pass the RightsCover, LifetimeCovers and unexpired gates.
  - `Derivation`: rights and valid_until are bounded by the parent's exact record.
  - `parent_id`/`approval_id`: resolved without ambiguity, and id 0 is denied.
  - The `grant` passed to `current`: it must equal the registered record (`registered_as`), and its id must be positive.
  - Trusted inputs (`from`, `now`, `token`, `expected_revision`, and the state's live/directory/placements) are all named in GRANT-ISSUANCE.md.
  - No caller-controlled authority fact is believed. The one gap is I-1, whose concern is consumption and terms, not authority.
- **Release routes.** The only exits are `reads`, `writes` and `registry`. Each filters by `usable_by` = subject && `current`, and nothing reads `grants` without going through `current`. No WriteIntent, Backplane call or declassification exists. `git diff master..HEAD --stat -- DataOS.bend Transfer.bend Frontend.bend` is empty, so the DataOS facade is untouched.
- **What `current` rechecks at every use.**
  - The grant itself: its exact record; a scope stamp equal to the live stamp (so an epoch advance withdraws it); its exclusive expiry.
  - A root grant's approvals: consumed by this grant, unrevoked, their issuers still authorities, their objects still placed, covering the manifest, destination and domain, the same exact scope, rights cover, unexpired.
  - A derived grant: an exact-scope, rights and lifetime check against its parent's exact record, plus the parent's own `current`, through a walk bounded by the grant list.
  - Inherited restrictions are rechecked the same way, through the attenuation checks and the chain walk.
- **Suites.**
  - `bend Tests.bend`: 1010 PASS (the grep counts 1011 lines, one of which is "ALL LIBRARY TESTS PASSED"), 0 FAIL, last line `ALL LIBRARY TESTS PASSED`. The output is byte-identical to `verification/tests-js.txt`, and tests-js.txt and tests-native.txt share SHA-256 `61743d04...`, which matches the evidence file.
  - OpenSpec 1.16.0 strict: `Totals: 44 passed, 0 failed (44 items)`.
- **Removal-map spot-check: six mutants on the current tree, all killed by the check the maps name.**
  - Task 3 map, "root 4 write Unrevoked" mutant: killed by "GI-005 the registered grant is not current after its write approval is revoked". Facade check 2 also catches it.
  - Task 3 map, "own 2 scope_wellformed" mutant: killed by "GI-005 after the monitor advances the authority epoch the old grant is not current".
  - Task 3 map, "current_within ancestor not walked" mutant: killed by "GI-005 revoking the parent's source approval makes the derived grant not current".
  - Task 5 map, `usable_by` with the subject conjunct dropped: killed by "GI-008 subject-scoped projections: subject 7's current grant 3 projects nothing for principal 8, principal 6 or principal 0".
  - Task 5 map, `usable_by` with the currency conjunct dropped: killed by "GI-008 revocation after registration: with the write approval revoked ... T.admit denies Write", and also by Facade check 2.
  - Task 5 map, `grant_scope` with lifetime 200: killed by the exact check "GI-008 grant 3 projects exactly one read ... until 150".
  - Harness: `/tmp/claude-1000/-mnt-MediaVolume-Media-src-github-com-spaceghost-writ/55038343-2e0b-4235-a6a8-7c68c6dd1f50/scratchpad/finalmut/run.py`.
- **Cross-document consistency.** The header, GRANT-ISSUANCE.md, the traceability rows, grant-issuance.txt and the tasks.md box notes agree on each of these rules:
  - approvals are single use (consumed, with `seen` kept through revocation);
  - subject and scope stay fixed under derivation (a `Derivation` has no scope field; the child copies the parent's);
  - projections are scoped to the subject;
  - a source revocation denies at `Write` under the admission order (traceability "Model details"; tasks.md 1.5);
  - a missing or ambiguous parent, or parent id 0, maps to MissingApproval, and a parent that is not current to Revoked (header lines 76-79, `derive` doc);
  - id 0 is never issued (`empty` sets next_id 1; `id_named` in `own_checks` and `parent_present`).

  The only disagreement is I-1's framing at GRANT-ISSUANCE.md:89-91.
- **Evidence claims.** No sentence claims a Lean verdict or GPU evidence. Every mention says CPU / `--gpu off` / not a GPU test / NOT VERIFIED. The traceability and evidence files cite only PASS labels that exist; I spot-checked the labels in the GI-003, GI-005 and GI-008 rows against the test output.

## Before merge

Must fix:
1. I-1, option A or option B (B at minimum).

Optional (recommended in the same round, all documentation or comment changes):
- M-1: a sentence saying rights constrain only Frontend.
- M-2: "monotone" in precondition 4 and in the GI-007 gap.
- M-4: the comment at Issuance.bend:1279.
- M-3: listed as open.
- M-5: Task 7's own fix.

The controller does at merge, as planned:
- update the tasks.md opening sentence ("All implementation and integration work below is pending.");
- re-pin the counts from the task-7-report.md table (1010 on this tree, or whatever the merged tree prints);
- regenerate `verification/source-sha256.txt` on master (it does not match this branch's edited files: FacadeTests, LAWS, PROOF, Tests, VERIFICATION.md and others);
- archive the change only if every box stays honest after the I-1 ruling.

## Open for the change after this branch

- Host transport identity, signature verification for approvals that travel off-host, durable and serialized installs (AB-006), and rollback resistance.
- Per-use projection rebuilding by a real host, a facade issuance entry, and capability negotiation.
- The host-corpus rebaseline from 782 (Unikraft `check-corpus.sh`, Genode `writ_bend_tests.run`).
- A Lean `--verdict` run for the twelve laws.
- Grant-level revocation (M-3).
- A rights proof: rights attenuation is tested, not proved.
