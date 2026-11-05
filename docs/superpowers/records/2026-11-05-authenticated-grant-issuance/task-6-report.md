# Task 6 report: end-to-end evidence and traceability (task 2.1)

Status: DONE_WITH_CONCERNS. The concerns are minor: one marked monitor install in the epoch scenario, one gate that no public lifecycle can reach, the brief's stale count estimates, a stale "Task 6 creates it" phrase in docs/GRANT-ISSUANCE.md (not on this task's touch list), and `--verdict` not run. Nothing is blocked.

## Files

- `IssuanceTests.bend`: scenario fixtures (synthetic, commented) and a new `scenarios` section with 23 checks. `main` calls it after `integration` and prints `Issuance: 224 checks passed`. The header names the section.
- `verification/grant-issuance.txt` (new): the commands, Bend version, date, the Issuance and Facade lines, the total in both PASS forms, the proof last lines, every scenario check name, the two Facade check names, and what was not exercised.
- `openspec/traceability/grant-issuance.md` (new): one row per GI-001 to GI-008, in the `transfer-admission.md` table shape.
- `openspec/traceability/transfer-admission.md`: the closing "deferred" sentence replaced (text only).
- `openspec/changes/add-authenticated-grant-issuance/tasks.md`: box 2.1 checked, with its evidence.
- Unchanged: `Issuance.bend`, `FacadeTests.bend`, `Tests.bend`, `LAWS.bend`, `PROOF.bend`, the use-time modules, and every count pin. `git diff b0ffdbd --stat` over those files is empty.

## Scenarios and their check names

Each scenario starts from `I.empty(...)` (`initial()`, or `pair_initial()`, which places 30v6 in read domain 9). It reaches every later state only through `submit_source`, `submit_write`, `register`, `revoke` and `derive`, each called with the principal a host would attach. Use is judged by the unchanged `T.admit` and `F.mount`/`F.open`/`F.checked_plan`, on projections rebuilt for that use. Fixtures reused from earlier sections (`registered()`, `both()`, `derived(...)`, `deadline_pair()`) are built the same way. There is one exception, marked in the source: `epoch_advanced()` is the monitor installing registered()'s records under epoch 4 (`with_live`). No public transition changes the live stamp, so this is the only way to model the install, and `valid` accepts the state. Every scenario asserts both a permitted and a denied outcome.

Current authority (two sources, two read authorities, TF.pair_plan() under TF.pair_context()'s policies):
1. "scenario current authority: from an empty state the read-domain-5 and read-domain-9 authorities each approve their source of TF.pair_plan(), the write-domain-6 authority approves its destination, and the cited approvals register grant 4 at revision 4"
2. "scenario current authority: subject 7's rebuilt projections of grant 4 hold one read per source in its own read domain and make T.admit admit TF.pair_plan() under TF.pair_context()'s policies"
3. "scenario current authority: F.mount, F.open and F.checked_plan resolve grant 4's projected capability for subject 7 to TF.pair_plan()"
4. "scenario current authority: principal 8's rebuilt projections of the same state admit nothing at Write and give it nothing to mount"

Revocation:
5. "scenario revocation mid-flow: after the read-domain-9 authority revokes approval 2 at revision 4, registering the pair at revision 4 is denied Revoked, and a registration validated at revision 3 is denied StaleRevision"
6. "scenario revocation mid-flow: use is denied too, with nothing projected for subject 7, T.admit denying TF.pair_plan() at Write and nothing to mount"
7. "scenario revocation after derivation: subject 7 derives child 4 (rights 1 until 120) from grant 3, and a descriptor opened from the child's capability resolves TF.plan()"
8. "scenario revocation after derivation: once the write authority revokes the root's approval 2 the child dies with its parent: neither is current, nothing is projected, the child's descriptor resolves no plan and T.admit denies Write"

Replay:
9. "scenario replay: a second registration of grant 3's request with a fresh token denied Replay"
10. "scenario replay: grant 3's consumed source approval 1 cited by another request beside a fresh write approval denied Replay"
11. "scenario replay: after its issuer revokes approval 1, resubmitting serial 1 is denied Replay while a fresh serial 2 is accepted as id 5"
12. "scenario replay: grant 3's consumed write approval 2 cited beside the fresh source approval 5 denied Replay"
13. "scenario replay: the fresh pair registers grant 6, the only grant projected for subject 7, which T.admit admits while revoked grant 3 is not current"

Denial cases:
14. "scenario forged issuer: the write-domain-6 principal's own source approval for object 10 is denied NotAuthority, its genuine write approval is accepted, a request citing that write approval as the source is denied MissingApproval, and T.admit denies Write"
15. "scenario forged issuer: once the read-domain-5 authority itself approves object 10, the same plan registers as grant 3 and T.admit admits it"
16. "scenario redirect: a read of 10 into 20v8 paired with a write approval for 20v9 is denied ScopeMismatch under either scope, nothing is projected, and T.admit denies the redirected plan at Write"
17. "scenario expanded manifest: a write approval whose scope adds source 11 is denied ScopeMismatch beside the one-source read and MissingApproval under its own scope, and T.admit denies Write"
18. "scenario subject substitution: subject 7's approvals with a request for subject 8 are denied SubjectMismatch; after grant 3 registers for subject 7, principal 8 deriving from it is denied SubjectMismatch and gets no projection or mount, while subject 7 is admitted"
19. "scenario subject substitution: when the source authority approved subject 8 but the write authority approved subject 7, a request for subject 8 is denied SubjectMismatch and nothing is projected for principal 8"
20. "scenario epoch advance: grant 3 admitted at epoch 3 is not current once the monitor installs epoch 4, nothing is projected, T.admit denies the old plan Stale and a fresh approval of the old scope is denied StaleEpoch"
21. "scenario epoch advance: approvals of the plan at the new stamp register grant 6, the only capability projected, at authority epoch 4"
22. "scenario deadline: approvals valid while now < 100 and submitted at 99 deny registration at 100 Expired with no grant registered, and a request whose own lifetime ends at 100 is denied Expired at 100 beside approvals valid until 200"
23. "scenario deadline: the same pair registered at 99 until 100 is admitted at 99, and at 100 nothing is projected and T.admit denies Write"

Every denial goes through `denied` (the exact `Error` plus full state equality with the supplied state).

## Mutation exercise

This task adds no denial branch: `Issuance.bend` is unchanged. To show that the scenario checks are not vacuous, I ran them alone against 19 gate mutants of `Issuance.bend`. Each run used a scratch copy of the tree with `main` reduced to `scenarios()`. Harness: `/tmp/claude-1000/-mnt-MediaVolume-Media-src-github-com-spaceghost-writ/55038343-2e0b-4235-a6a8-7c68c6dd1f50/scratchpad/t6mut/run.py` (and `run2.py` in the same directory), with output in `out2.txt` and `out3.txt` there.

| Mutant | Killed by (scenario check) |
| --- | --- |
| `source_gates` NotAuthority gate True | 14 (forged issuer) |
| `source_gates` serial Replay gate True | 11 |
| `register_gates` write Unconsumed True | 12 (survived the first pass; check 12 was added for it) |
| `register_gates` sources Unconsumed True | 10 |
| `register_gates` sources Unrevoked True | 5 |
| `register_gates` sources Present True | 14 |
| `register_gates` write SameScope True | 17 |
| `register_gates` write SameSubject True | 19 (survived the first pass; check 19 was added) |
| `register_gates` request unexpired True | 22 (survived the first pass; the request-lifetime conjunct was added) |
| `unexpired` inclusive (`is_le`) | 22 |
| `scope_at_live` always True | 20 |
| `parent_subject_is` always True (derive subject) | 18 |
| `root_checks` write Unrevoked True | 8 |
| `current_within` drops the parent's currency | 8 |
| `usable_by` subject conjunct dropped | 4 |
| `usable_by` currency conjunct dropped | 8 |
| `mark_revoked` marks nothing | 5 |
| `own_checks` scope_wellformed True | 20 |
| `register_gates` write DestinationIsPlans True | **equivalent within public lifecycles** |

The equivalent one: `submit_write` already requires the approved destination to be the scope plan's destination. So through the public entry points the gate is always shadowed by `SameScope` with the same reason. The registration section kills it against a monitor-installed state ("GI-003 stored write approval for destination 20v9 under a plan naming 20v8 is revalidated and denied ScopeMismatch"), and the traceability file says so. In total, 18 of 19 mutants are killed by the scenarios alone.

## Traceability rows (openspec/traceability/grant-issuance.md)

The file opens by saying the change is proposed, that no host adapter, facade entry or acceptance scenario is implemented, and that every identity input is a synthetic fixture. Each row lists its functions, existing PASS names quoted verbatim (all 73 checked against the run), and its boundary:

| Row | Reviewed-only gap (in the requirement's words) |
| --- | --- |
| GI-001 | "an authenticated authority": host transport identity verification is not implemented; `from` is a fixture |
| GI-002 | none; executable |
| GI-003 | source-version-only and output-type-only mismatches have no dedicated named test (covered by `T.Plan.equal` in `scope_equal`, by review) |
| GI-004 | "the authenticated subject" at use: the host must present the transport-verified identity as both the projection principal and `F.Caller.subject`; not implemented |
| GI-005 | "atomically register": host serialization of installs at `expected_revision` (AB-006), with no durable store or concurrent install; laws cover the successor revision only |
| GI-006 | rights attenuation is tested, not proved; scope and subject are unwidenable by construction (reviewed) |
| GI-007 | `now` is the monitor's trusted time; no host clock |
| GI-008 | "whenever it is used": per-use projection rebuilding by the host; revocation and directory or placement changes are enforced only by rebuilding; no facade issuance entry |

A model-details paragraph records the rulings: single-use approvals; derived grants never change subject or scope; stored identities are the authenticated principal; projections are subject scoped; and a source revocation denies at Write under the admission order. It also records the unreachable gate and the list of what was not exercised.

## The replaced sentence (openspec/traceability/transfer-admission.md)

Before:
> The current scope implements read/write pairing at use; authenticated grant
> issuance is deferred.

After:
> The current scope implements read/write pairing at use. Authenticated grant
> issuance is modeled in Bend and is not wired to a host; see
> [grant-issuance.md](grant-issuance.md).

## Verification (Bend 2.0.39)

- `bend Issuance.bend --check-only`: `ALL PROOFS CHECK`.
- `bend Tests.bend`: rc 0, 0 FAIL. There are 1008 PASS lines (955 `PASS: ` and 53 `PASS `): 782 plus 224 Issuance plus 2 Facade. That is 985 plus 23. The summary lines are `Facade: 12 checks passed` and `Issuance: 224 checks passed`. Last lines:
  ```
  Property: 324 checks passed; 320 graph cases, each checked against CPU and Bend parallel producers
  ALL LIBRARY TESTS PASSED
  ```
- `bend PROOF.bend`: rc 0, with 12 laws, unchanged. Last lines:
  ```
  ALL PROOFS CHECK
  Use --verdict for mathematical validity.
  ```
- `bunx @fission-ai/openspec@1.16.0 validate --all --strict --no-interactive`: `Totals: 44 passed, 0 failed (44 items)`. This was a sanity run only. Task 7 records it.
- `--verdict` was not run (no Lean kernel toolchain). This was a CPU run only, with no GPU claim.

## Concerns

1. **The marked monitor install.** The epoch-advance scenario uses `with_live` to install the advanced epoch. No public transition changes the live stamp, so the scenario cannot avoid it. It is marked MONITOR INSTALL in the source, in the evidence file and in the traceability file, and it is not a `valid`-rejected forgery.
2. **One gate unreachable by public lifecycles.** `DestinationIsPlans` (see the mutation table) is defensive within the public path, and is exercised only against a monitor-installed state.
3. **Counts.** The brief's figures are stale: it estimated about 10 checks and a suite of about 864. The actual figures are 23 checks and 1008. Per the cross-lane ruling, no count pin was edited.
4. **docs/GRANT-ISSUANCE.md** still says the traceability file is something "Task 6 of this change creates". The document is not on this task's touch list, so I left it. Task 7, which edits that document, can drop the phrase.
5. **`--verdict` was not run.**
