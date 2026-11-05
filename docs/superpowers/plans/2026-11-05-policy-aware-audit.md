# Plan: Policy-aware audit, section 1 (event construction and access, tasks 1.1 to 1.4)

Spec: `openspec/changes/add-policy-aware-audit/` (AU-001 to AU-009; this plan implements tasks 1.1 to 1.4 and covers AU-001, AU-002, AU-003, AU-007 and AU-008 in full, plus the query part of AU-009 and the model part of AU-005). Here is the gap. The library returns pure decisions: `Transfer.admit` returns `Denied{reason}` or `Admitted{ticket}`, and `DataOS.commit_from_capability` returns `Backplane.Committed{session, ledger, intent}` or `Rejected{session, ledger}`. Nothing records either one. There is no event format, no rule for how an event is labelled, no query that respects owners, and no rule against ambient telemetry. Every box in the change's `tasks.md` is unchecked. `openspec/ROADMAP.md` places audit "After durable state", and `add-durable-publication` is still unimplemented. This plan adds the part that does not need durability. It defines a versioned canonical event with a field allowlist, projects each event from the decision the library already made (never a second decision), and labels each event with the authoritative data and control facts behind it. It also adds owner-scoped queries checked against the response sink, and policy-gated exports, metrics and alerts. Section 2 (durable required audit, AU-004; denial-append failure, AU-005; verifiable history, AU-006; queue bounds, AU-009) and section 3 (crash-injection evidence) wait for durable publication. They are a later plan.

Worked example. Owner Bob's source object 11 carries an origin rule whose approved codes leave out the plan's code, so `Transfer.admit` denies with `Origin`. `AuditEvent.audited_admit` returns that same `Denied{Origin{}}` together with a denial event. The event records the invocation, the exact source and destination object versions, the graph, policy and authority epochs, the code and kind, the subject, and the reason `Origin`. It carries no payload bytes, no capability token and no error text. Its policy keeps Bob's label on object 11 as a separate influence. Alice owns the destination object 20 and holds a current read grant for her stream through sink 1, which is cleared for Alice only. Her query returns `Page{[], end}`. That page is identical, word for word, to the page she would get from a log that never held the event, so she cannot tell from it whether a denied attempt took place. A reader whose sink satisfies both Alice's and Bob's policies sees the event and its reason.

## Global Constraints

- Lane `lane/policy-aware-audit`, worktree `../writ-lanes/policy-aware-audit`, created from current master. Environment: `export PATH="$HOME/.local/share/writ-toolchains/bend-2.0.39/bend/bin:$PATH"; export BEND_NO_TELEMETRY=1`. Bend 2.0.39 only. Build outputs go to `../writ-build/policy-aware-audit/`, and mutants go in scratch copies under `../writ-build/policy-aware-audit/mutants/`, never in the worktree.
- Read before the first edit: `AGENTS.md`, `bend guide` (Recursion and Termination, Laws and Proofs), `openspec/README.md`, the whole change (`proposal.md`, `design.md`, `specs/policy-aware-audit/spec.md`, `tasks.md`), `Transfer.bend` (the `Denial` and `Decision` types, `admit`, `scoped`, `output`), `Backplane.bend` (`Binding`, `WriteIntent`, `CommitResult`, `binding_find`, `checks`), `DataOS.bend` (`commit_from_capability`, `subject`), `Dlm.bend` (`Label`, `join`, `flows`, `maximal_restriction`, the `fixture` principals Alice `Named{0}` and Bob `Named{1}`), `Guard.bend`, `Frontend.bend` (`Caller`, `Ref`), `Issuance.bend` lines 1-147 (the model of a module that records authority decisions: header, trusted-input list, gate structure, laws paragraph), `HostWire.bend` (bounded canonical word encoding, `U32.from_nat`/`U32.to_nat`), `LAWS.bend`, `PROOF.bend`, `Tests.bend`, and the fixtures in `TransferTests.bend` (`TF.plan()`, `TF.context()`, `TF.with_*`, `TF.denied_as`), `BackplaneTests.bend` (`BF.context()`, `BF.candidate()`, `BF.binding()`, `BF.retained`), `NegotiationTests.bend` (`NF.running()`, `NF.held_ledger()`) and `FacadeTests.bend` (`context()`, `run(...)`). Audit adds no parallel or GPU entry point, so `bend guide shaders` is not required.
- Touch only these paths. New: `AuditEvent.bend` (Tasks 1 to 3), `AuditQuery.bend` (Task 4), `AuditExport.bend` (Task 5), `AuditTests.bend` (one section per task), `docs/AUDIT.md`, `openspec/traceability/policy-aware-audit.md` and `verification/policy-aware-audit.txt` (Task 6). Extended:
  - `Tests.bend`: one `import ./AuditTests.bend as Audit` line after the Issuance import and one `Audit.main()` line after `Issuance.main()`, both in Task 1. Nothing else.
  - `LAWS.bend` and `PROOF.bend`: additions only, appended after `publication_refused_emits_nothing`, plus one import line each for the Audit modules.
  - `openspec/changes/add-policy-aware-audit/tasks.md`: boxes 1.1 to 1.4, and its first line, which becomes "Section 1 is implemented as a Bend model; sections 2 and 3 are pending."
  - Nothing else. Do not edit `Transfer.bend`, `Backplane.bend`, `DataOS.bend`, `Dlm.bend`, `Core.bend`, `Frontend.bend`, `Negotiation.bend`, `Ledger.bend`, `Guard.bend`, `Issuance.bend`, any `Host*.bend`, any existing test module, `examples/`, `hosts/`, `contrib/`, `writfs/`, `utils/`, `.github/`, `README.md`, `docs/INSTALL.md`, `VERIFICATION.md`, `docs/FEATURES.md`, `openspec/FEATURE-ACCEPTANCE.md`, `openspec/ROADMAP.md`, or the shared captures `verification/tests-js.txt`, `verification/tests-native.txt`, `verification/proofs.txt`, `verification/kernel-verdict.txt`, `verification/source-sha256.txt`. If a task seems to need any of these changed, stop and report BLOCKED.
- **Plan ruling (scope).** This lane implements section 1 only. Tasks 1.1 to 1.4 consume decisions that already exist and append nothing, so they do not depend on `add-durable-publication`. Section 2 requires the durable authorization transaction that change defines, and building it here would be a second, unreviewed publication protocol. Boxes 2.1 to 3.2 stay unchecked. The traceability file marks AU-004 and AU-006 "not implemented" and AU-005 and AU-009 "partial", naming the missing half.
- **Plan ruling (shared files).** `VERIFICATION.md`, the shared `verification/*.txt` captures and `docs/FEATURES.md` belong to whichever tree the controller re-pins after the parallel lanes merge. This lane writes its counts, law list and captured outputs to `verification/policy-aware-audit.txt` and its record directory. The controller folds them into `VERIFICATION.md` and the feature path at landing.
- Security rules (AGENTS.md):
  - No `unsafe` definitions, no `?` holes, no law without a complete proof, and no array or `a[i]` indexing. Use recursive lists and structural recursion, or `Nat` fuel.
  - No caller-controlled authority facts. No Audit record carries a Bool or any other field that asserts authentication, ownership, visibility or clearance. The authenticated query or export principal arrives as a separate `from: Nat` parameter, the same transport-verified subject the host presents as `Frontend.Caller.subject`. The following are monitor-owned state, never caller input: sink labels and clearances, object labels and owners, the DLM snapshot, grants, revocation flags, the live epoch, `now`, and event identifiers. A caller names a sink, a stream owner or a grant only by id, and every id is re-resolved against the current state.
  - Each transition is revalidated at use against the state it answers from. That covers the revision, grant presence, the grant's principal, owner and sink, revocation, the epoch, exclusive expiry (`now < valid_until`), the sink registration, and every influence's flow to the sink label. Nothing is cached from an earlier step.
  - Audit adds no release route and no declassification. It produces no `WriteIntent`, never calls `Backplane.commit` directly, and calls `DataOS.commit_from_capability` exactly once, inside `audited_commit`, which returns that call's result unchanged. No function clears, lowers, meets or drops an influence. `Dlm.meet` is never called. A query or export result is a description of what the monitor may send to one registered sink. It is not an effect.
  - **Event = projection.** An event is computed from the `Transfer.Decision` or `Backplane.CommitResult` that the single library call returned in the same wrapper invocation. No Audit function recomputes an accept/deny outcome, re-runs `admit` to find a reason, or turns a library result into a different one. Acceptance check: `grep -c "T.admit(" AuditEvent.bend` is 1, `grep -c "commit_from_capability(" AuditEvent.bend` is 1, and neither string nor `Backplane.commit` appears in `AuditQuery.bend` or `AuditExport.bend`.
- Laws. This change adds security laws. Do not weaken, reword, reorder or delete any of the 17 existing laws or their proofs. `git diff master -- LAWS.bend PROOF.bend` must show added lines only. Each new law states a property of a public entry point, or of the one named helper that the entry point is shown to use, over all of its inputs. **A trivially true law is a proof hole.** That covers an accessor applied to a constructor, a restatement of a definition, or anything no mutant of the implementation can break. Such a law is not added. For every new law, the task report names one implementation mutant under which `bend PROOF.bend` fails on that law. The rationale goes in two places: in the comment above the law in `LAWS.bend` (what it states, why audit needs it, what it does not claim, in the style of `issuance_stale_revision_rejects`), and in a "Laws" paragraph in the owning module's header. If a law will not check with a complete proof, do not add a hole or a weaker statement. Leave it out, record the attempted statement and the checker output in the task report, and list it as "tested, not proved" in `verification/policy-aware-audit.txt`. The auxiliary law `nat_eq_successor_false` already exists, so reuse it and do not restate it.
- **Mutation standard (this repository's current practice).** Every denial branch, gate, allowlist entry and influence must be pinned by a test that fails when it is removed. After each task, make a scratch copy of the worktree under `../writ-build/policy-aware-audit/mutants/task-N/`. Apply one mutation at a time: replace a gate's condition with `True{}`, delete a `Require` from a gate list, make a field skip its allowlist check, drop one influence from a derived list, swap a `None`/`Withheld` arm for the accepting arm, and copy a diagnostic field into an event. Run `bend AuditTests.bend` and `bend PROOF.bend` on each. Record every mutant in `task-N-report.md` as killed (by which check or law) or equivalent. An equivalent mutant needs a written argument, such as an arm that is unreachable behind an earlier gate. Any other survivor gets a new check before the task commits. The issuance lane's records (`docs/superpowers/records/2026-11-05-authenticated-grant-issuance/activity.log`, "mutation exercise") show the expected level of detail.
- Validation at every commit, all green before committing:
  1. `bend AuditEvent.bend --check-only`, and the same for each Audit module that exists;
  2. `bend AuditTests.bend`, ending in `Audit: N checks passed`;
  3. `bend Tests.bend`, whose last line is `ALL LIBRARY TESTS PASSED`; record the PASS total, counting both the `PASS:` and `PASS ` forms;
  4. `bend PROOF.bend`, which prints `ALL PROOFS CHECK`.
  
  Task 6 adds the native CPU run, one `--verdict` attempt and OpenSpec strict validation. A red suite or proof check at any commit is a stop, not a commit.
- Code conventions:
  - Name every policy bit, tag, bound, identity and comparison with a helper (`event_format_version()`, `kind_admission_denied()`, `field_allowlist()`, `max_sources()`, `max_page()`, `public_denial()`, `object_influence`, `influences_flow`, ...). Decisions contain no bare literals.
  - Comments explain authority, invariants, edge direction and failure behavior.
  - Mark every public entry point "Public entry point" in a comment. Every other def is an exported implementation helper, and the header says that calling one performs none of a transition's checks.
  - `AuditTests.bend` states in its header that every log, grant, sink, label table and principal in it is SYNTHETIC MONITOR STATE, not an authenticated issuer.
  - Fixtures are reused by import (`TF`, `BF`, `NF`, `FacadeTests`) rather than copied. Every stored event in a test log comes from `audited_admit` or `audited_commit`, never from a hand-written `Event` literal, except in the decoder tests of Task 2.
  - Checks are grouped into one def per requirement, built from named fixture functions, so the native backend's arity limit (note above `main` in `HostBindingTests.bend` and `BackplaneTests.bend`) is not hit.
  - `main` calls the sections in task order and ends with `IO.print("Audit: N checks passed")`, with N exact.
- Records: `docs/superpowers/records/2026-11-05-policy-aware-audit/`.
  - Append one line per step to `activity.log` there: tab-separated UTC time, role, text.
  - While a long run is going (the native build, the `--verdict` attempt, a mutation batch), add a heartbeat line at least every 10 minutes. A silent 30 minutes marks the lane idle on the board.
  - Each dispatch gets `task-N-brief.md`. Reports go to `task-N-report.md`, written early and then completed, with: commands and their final lines, PASS totals before and after ("1428 plus N new checks = M" as this tree prints it), new check names, the mutation table, every law and the mutant that breaks it, any plan ruling applied, and status DONE, DONE_WITH_CONCERNS or BLOCKED.
  - Include `git add -A docs/superpowers/records/2026-11-05-policy-aware-audit` in each commit. One commit per task. No push, no manifest regeneration, no `openspec archive`.
- Cross-lane ruling (controller, 2026-11-05): two other lanes, `lane/linux-host` and `lane/executor-rendezvous`, add tests to `Tests.bend` in parallel with this lane. So:
  1. This lane changes no recorded count pin: not `README.md`, `docs/INSTALL.md`, `utils/nix/writ.nix`, `.github/workflows/*.yml` (`WRIT_CORE_EXPECTED`), the count sentences in `VERIFICATION.md`, nor any host corpus default. Its records state the count its own tree prints ("1428 plus N = M"). The controller re-pins every count once, after all three lanes have merged, and then watches the Genode CI run on that push.
  2. Host corpus evidence recorded at 1428 stays historical, and a later lane re-records it.
  3. This lane's `Tests.bend` edit is the smallest registration block: one import and one call group. A merge with either other lane is then at most a two-line conflict.
  4. The change is not archived by this lane, because sections 2 and 3 remain open.

### Shared design for all tasks (plan rulings)

These rulings fill gaps the design leaves open. Each one holds for the whole lane.

- **Module split.** `AuditEvent` holds the event, allowlist, codec, policy derivation and the two wrappers. `AuditQuery` holds the state, sinks, read grants, visibility, views and `respond`. `AuditExport` holds export grants and `transmit`. Reason: AGENTS.md asks for focused modules, and keeping query and export apart means AU-007's "no ambient telemetry" can be reviewed without reading the query code. `AuditQuery` imports `AuditEvent`, and `AuditExport` imports both. None of them imports `hosts/`, `contrib/` or `examples/`.
- **Event record (allowlisted fields only).** `Event{version: Nat, kind: Kind, event_id: Nat, subject: Nat, phase: Phase, invocation: Nat, sources: T.Objects, destination: T.ObjectVersion, stamp: T.Stamp, code: T.CodeId, op: T.OpKind, artifact: Maybe<B.ArtifactId>, outcome: Outcome}`.
  - `Kind` is `AdmissionAdmitted | AdmissionDenied | CommitAccepted | CommitRejected`, and `Phase` is `Admission | Commit`.
  - `Outcome` is `Admitted{}`, `DeniedFor{reason: T.Denial}`, `Committed{}` or `NotCommitted{}`.
  - Ruling: a commit rejection carries no reason. `Backplane.Rejected` exposes none, and finding one would mean re-running the gates, which would be a second decision.
  - The stamp carries all three epochs (graph, policy, authority).
  - `event_id` is a fresh identifier supplied by the monitor (Bend generates none). Query views and exports omit it, because the design forbids exposing a global sequence. It exists for section 2's idempotency.
  - There is deliberately no field that could hold payload bytes, a credential, a capability or caller token, a grant, payment witness or receipt, a request body, or free text. The allowlist is the type plus `field_allowlist()`.
- **Diagnostic input.** `Diagnostic{payload: List<U32>, error_text: List<U32>, credential: List<U32>, token: T.CodeId}` stands for the raw failure material a host holds when it calls audit, as in the spec's "execution error contains source text and a capability token". The wrappers take a `Diagnostic` and a `Frontend.Caller` (with its token) so that the tests and laws can show both are dropped. Ruling: they are parameters, not ignored by omission, because a law about exclusion needs the excluded values in its input.
- **Policy.** `EventPolicy{influences: Influences, secrecy: T.Bits64, untrusted: T.Bits64}`.
  - `Influence{owner: D.Principal, label: D.Label, edge: Edge}` with `Edge = Data | Control`.
  - Influences come from a monitor-owned `Labels` table (`ObjectLabel{object: T.ObjectVersion, owner: D.Principal, label: D.Label}`). For commit events they also come from the authoritative `Backplane.Binding` that `binding_find` resolves for the session's request.
  - `secrecy` and `untrusted` are the `T.Bits64.join` of every authoritative `T.SourcePolicy` secrecy and untrusted set in the context `admit` was given.
  - Ruling: an influence is never merged into another owner's influence. Each owner's restriction stays a separate list element, so "one owner's approval does not erase the other owner's restrictions" holds by construction, and the release check requires every element.
  - Ruling: an object with no label, or with two labels in the table, gets the influence `Influence{D.Top{}, D.maximal_restriction(), Data{}}`. It fails closed exactly like Issuance's ambiguous placements, so the event can reach no sink.
- **Reasons are labelled at least as high as the event.** `Transfer.admit` returns the first failing check in a fixed order. The existence of a given reason therefore depends on every earlier check, including grant presence and every source's policy. Ruling: a denial event's policy is computed from the same inputs as an admission event's for the same plan and context, so the reason is visible exactly when the event is. A denial never lowers the policy, and the Task 3 law states this. Per-reason precision, where for example `Write` would depend on the destination only, is deferred, because an over-approximation is sound and a finer rule needs its own review.
- **Sinks.** `Sink{id: Nat, label: D.Label, clearance: T.Bits64, tolerated: T.Bits64}` lives in monitor state. An event is releasable to a sink when two things hold:
  - `influences_flow(snapshot, epoch, influences, sink.label)`: every influence satisfies `D.flows`;
  - `secrecy ⊆ clearance` and `untrusted ⊆ tolerated` (`T.Bits64.subset`).
- **Streams and ownership.** An event belongs to the stream of every owner that appears among its influences (`event_owners`). A stream has no counter, no length field and no head reference visible to a query. A mixed Alice and Bob event is in both streams, and it is visible in either only through a sink that satisfies both owners' labels.
- **Grants are installed by the monitor in section 1.** `ReadGrant{id, reader: Nat, owner: D.Principal, sink: Nat, epoch: Nat, valid_until: Nat, revoked: Bool}` and `ExportGrant{id, exporter: Nat, owner: D.Principal, sink: Nat, channel: Channel, epoch, valid_until, revoked}`, with `Channel = Events | Metric | Alert`.
  - Ruling: this lane models grant use and monitor revocation, not grant issuance. The monitor installs grants, as it installs `T.Context` grants. `revoke_read` and `revoke_export` are monitor transitions taking `(state, expected_revision, grant_id)`; they set the flag and advance the revision once.
  - Who may approve an event-read or export grant is recorded as a traceability gap; see the questions.
  - There is no operator role. `AuditQuery.empty(...)` and `AuditExport.empty(...)` hold no grants, so nothing is readable or exportable by default.
- **State.** The query side is `AuditQuery.State{revision, epoch: Nat, snapshot: D.Snapshot, sinks: Sinks, grants: ReadGrants, log: Stored}`, where `Stored` is a list of `Recorded{event, policy}` in append order. The export side is `AuditExport.State{revision, query: AuditQuery.State, grants: ExportGrants}`. In section 1 the log is monitor-installed state, and section 2 supplies durable append.
- **Responses.** `Response = Page{views: Views, next: Maybe<Cursor>} | Refused{category: PublicDenial}`. `PublicDenial` has exactly one constructor, `Unavailable{}`, returned by `public_denial()`.
  - Ruling: every refusal looks the same, whatever caused it: unknown version, stale revision, no grant, wrong owner, wrong sink, revoked, expired, epoch change, bad cursor, page limit or work budget. Reason: AU-008 says to withhold protected reasons, and an authorized-but-exhausted caller learns nothing that a stranger does not.
  - A `View` is the event without `event_id`, plus nothing.
  - There is no total, no count and no timestamp field. Ordering is the append order of the caller's visible view only; there is no sort parameter, because sorting by a protected field leaks it through position.
  - `Cursor{reader, owner, epoch, offset}` holds an offset into the caller's visible view, not a log position. `respond` refuses a cursor whose reader, owner or epoch differs from the request's. The offset therefore counts visible events only and reveals nothing beyond them.
- **Work budget (AU-009, query part).** `Query{version, owner: D.Principal, cursor: Maybe<Cursor>, limit: Nat, work: Nat}`. `limit` must be at least 1 and at most `max_page()` (ruling: 16). Evaluation charges one unit of `work` per visible event it skips or returns. If the work runs out before the page is full and before the view ends, the whole response is `Refused{Unavailable{}}`, with no partial page.
  - Ruling: hidden events are not charged. Charging them would make the outcome depend on protected events, which is exactly AU-008's leak.
  - The remaining dependence of compute time on hidden events is a timing channel. The design leaves that to each deployment's confidentiality contract, and `docs/AUDIT.md` says so without claiming constant time.
- **Gates.** `respond` and `transmit` each match first on `revision_current(state, expected_revision)`, so the stale-revision law can rewrite it. Each then computes acceptance as `Guard.all` over a `Guard.Checks` list built by `query_gates(...)` or `export_gates(...)`. The existing law `failed_check_denies` then covers a failed audit gate at any position, without modification.
  - Tests identify the failing gate with the exported helper `first_failed_gate(...) -> Maybe<Gate>`. `Gate` is a closed enum of gate names. It is monitor-internal, never part of a `Response` or `Transmission`, and the header says so.
- **Transmissions.** `Transmission = Sent{effects: Emissions} | Withheld{}`. `Emit{sink: Nat, words: List<U32>}` carries the canonical encoding of views, of a metric word, or of an alert view. There is no fallback constructor (stdout, crash report, local log), and `Withheld` has no effects field.

- Controller rulings on the plan author's questions (2026-11-05): (1) section 1 lands before durable publication because it appends nothing to storage; section 2 waits. (2) Event-read and export grants are installed by the monitor for now and recorded as a gap; who approves them on a real host is put to Spaceghost. (3) Metrics are defined as counts over the events the sink may see, never totals; that reveals nothing about hidden events, whereas withholding a metric when a hidden event exists would reveal that hidden events exist.

### Task 1: Allowlisted event projection and the two wrappers (task 1.1, first half; AU-001, AU-005 model part)

Implements "AU-001 Minimal scoped event records" (scenarios "Error includes protected content" and "Committed operation is recorded") and the model part of "AU-005 Denial recording preserves rejected operation state" (scenario "Denial is recorded successfully": the transfer remains denied and the reservation is not consumed by recording).

Create `AuditEvent.bend`, importing `Base`, `Guard`, `Transfer as T`, `Frontend as F`, `Backplane as B`, `Negotiation as N`, `Dlm as D` and `DataOS as OS`. Add:
- the types `Event`, `Kind`, `Phase`, `Outcome` and `Diagnostic`, with accessors;
- `outcome_of_decision(T.Decision) -> Outcome` and `outcome_of_commit(B.CommitResult) -> Outcome`, the only places an outcome is derived. Each matches on the library value and computes nothing else;
- `admission_event(plan, decision, caller: F.Caller, event_id) -> Event`, taking the scope from `plan`, the subject from `caller`'s subject (its token is never read) and the outcome from `decision`;
- `commit_event(session, ref, result, event_id) -> Event`, taking the scope from `N.Session.plan(session)`, the subject from `OS.subject(ref)`, and the artifact from the committed `WriteIntent` (`None` on rejection);
- the public entry point `audited_admit(plan, context, labels, caller, diagnostic, event_id) -> AuditedAdmission{decision, event}`. It binds `decision = T.admit(plan, context)` once and returns it unchanged next to `admission_event(plan, decision, caller, event_id)`. `labels` is unused until Task 3;
- the public entry point `audited_commit(session, expected_session, expected_ledger, ledger, candidate, ref, expected_frontend, context: OS.Context, labels, diagnostic, event_id) -> AuditedCommit{result, event}`. It calls `OS.commit_from_capability` once with exactly the facade's arguments and returns that result unchanged.

Write the module header: the event is a projection of one library decision, never a second decision; the trusted inputs (`event_id`, `labels`, the contexts, the caller's subject as already authenticated by the frontend); that constructing an Audit record authenticates nothing; that the wrappers add no release route; and the public entry points.

Add laws:
- `audit_admission_event_ignores_diagnostic`: for all `plan`, `context`, `labels`, `subject`, tokens `t1`/`t2`, diagnostics `d1`/`d2` and `event_id`, `AuditedAdmission.event(audited_admit(plan, context, labels, F.Caller{subject, t1}, d1, event_id)) == AuditedAdmission.event(audited_admit(plan, context, labels, F.Caller{subject, t2}, d2, event_id))`. Rationale: no payload, error text, credential or caller token can influence any event field, for every decision, including every denial. Mutant to show: copy `diagnostic.token` into `code`.
- `audit_commit_event_ignores_diagnostic`: the same for `audited_commit`, quantified over the Ref's caller token and the diagnostic.
- `audit_admit_returns_library_decision`: `AuditedAdmission.decision(audited_admit(plan, context, labels, caller, diagnostic, event_id)) == T.admit(plan, context)` for all inputs. Rationale: auditing never changes a decision, so a denied transfer stays denied with its reason, and recording is not a second decision. Mutant to show: return `Denied{Stale{}}` on one branch.
- `audit_commit_returns_library_result`: `AuditedCommit.result(audited_commit(...)) == OS.commit_from_capability(...)` with the same arguments. Rationale: a rejected commit keeps the caller's session and ledger, so no reservation is consumed by recording (AU-005), and the only release route is unchanged. Each law states what it does not claim: durability, append success, or that a host calls the wrapper.

Tests (`event_projection` section) in `AuditTests.bend`, registered in `Tests.bend` now (one import, one call):
- "Error includes protected content":
  - A diagnostic whose payload, error text and credential words, and whose `F.Caller` token words, are the sentinels `0xA0D17001` to `0xA0D17008` (values chosen to appear in no fixture field) gives an event equal (`Event.equal`) to the one built with an empty diagnostic and another token.
  - An `Event.words` helper (a test-side flattening of every field) contains no sentinel.
  - The event carries no grant scope, payment receipt or capability token from `TF.context()`. The receipt number and `FacadeTests.token()` words are absent.
- "Committed operation is recorded":
  - `audited_commit` on `FacadeTests.context()` with subject 7 gives `CommitAccepted`, invocation `T.Plan.invocation(TF.plan())`, the exact `TF.source_manifest()` versions, the destination version, a stamp equal to the plan's stamp in all three epochs, the code and kind, `Some{BF.artifact()}`, and subject 7.
  - Changing any one of a source version, the destination version or each of the three epochs in a second fixture changes the corresponding event field.
- Admission denials, one per reachable `T.Denial` using the `TF.with_*` fixtures (`Stale`, `Source`, `Read`, `Write`, `Schema`, `Operation`, `Origin`, `Payment`, `Destination`, `InvalidPolicy`): the wrapper's decision satisfies `TF.denied_as(..., reason)`, and the event is `AdmissionDenied` with `DeniedFor{reason}`.
- Admitted: the decision is accepted, and the event is `AdmissionAdmitted` with no artifact.
- "Denial is recorded successfully": a commit rejected for a revoked frontend capability or a wrong subject (subject 8, as in `FacadeTests`) gives `CommitRejected` and `NotCommitted{}`. The wrapper's result equals the facade's result, its ledger equals `NF.held_ledger()` (the hold is unconsumed), and its session equals `NF.running()`.

Estimate about 30 checks. Laws: the four above. Do not check any box yet (1.1 is checked after Task 2).

Acceptance:
- Suite green at 1428 plus about 30.
- `ALL PROOFS CHECK` with 21 laws (or the recorded exception).
- The `grep` counts in the event = projection rule hold.
- The mutation table shows every outcome arm and every excluded-field mutant killed.

### Task 2: Versioned canonical encoding with a field allowlist (task 1.1, second half; AU-001)

Implements the format part of "AU-001 Minimal scoped event records": a versioned canonical binary event format with an allowlist of fields.

Add to `AuditEvent.bend`:
- the constants `event_format_version()` = 1, the kind tags 1 to 4, the field tags (`field_event_id()`, `field_subject()`, `field_phase()`, `field_invocation()`, `field_sources()`, `field_destination()`, `field_stamp()`, `field_code()`, `field_op()`, `field_artifact()`, `field_outcome()`), `max_sources()` (ruling: 16) and `word_limit()` (2^32);
- `field_allowlist() -> FieldTags`, the ordered list of the tags above. This is the single allowlist;
- `field_allowed(tag) -> Bool`, a walk over that list.

Encoding layout:
- Header: version, kind tag, body length.
- Fields are emitted in allowlist order. Each is a tag word, a length word, then value words. Object versions are two words, a stamp is three, and a code is eight.
- The outcome is one word, plus one reason word for `DeniedFor`, using a named `reason_tag(T.Denial)` with ten distinct values.
- The artifact field is length 0 for `None`.

Public entry points:
- `encode(event) -> Maybe<List<U32>>` returns `None` if any Nat field is at or above `word_limit()`, or if there are more than `max_sources()` sources. It never truncates.
- `decode(words) -> Decoded{event} | Malformed{reason: FormatError}`, with `FormatError` closed: `UnknownVersion`, `UnknownKind`, `NotAllowed` (a tag outside the allowlist), `OutOfOrder` (a tag repeated, or one earlier than its predecessor in the allowlist), `BadLength`, `TooLong` and `OutOfRange` (for example a reason word out of range, or a phase that contradicts the kind).

The check order is fixed and documented in the header.

Canonicity: the field order and widths are fixed and every field is mandatory, so an accepted word list is the unique encoding of its event.

Tests (`event_format` section):
- Round trips `decode(encode(e)) == Decoded{e}` for each kind, including every denial reason and both artifact cases. The reverse direction holds for accepted word lists.
- Unknown versions 0, 2 and 0xFFFFFFFF; unknown kinds 0 and 5.
- A field tag naming a payload, a token or text (ruling: tags 12, 13 and 14 are reserved and never allowed) is rejected `NotAllowed`, and no event is built from it.
- A field out of order, a duplicate field, a missing field, a length word that is one short and one long, a truncated body, one trailing word, and more than `max_sources()` sources.
- `encode` on an invocation of 2^32 returns `None`.
- Mutating each tag in `field_allowlist()` (removing it, or adding tag 12) fails at least one check.

Estimate about 35 checks. Laws: none. Encoding properties are tested, not proved: the codec works over `U32` words, which are not inductive, and a law about it would be a restatement. Check box 1.1, citing both sections. Write the per-field sensitivity notes into the module header now; Task 6 copies them into `docs/AUDIT.md`.

Acceptance:
- Suite green at about plus 65 in total, proofs unchanged at 21.
- Every case above is a named check.
- The allowlist mutants are killed.

### Task 3: Event policy from authoritative data and control influences (task 1.2; AU-002)

Implements "AU-002 Event policies include observed influences" (scenarios "Denial reveals a protected source fact" and "Multiple owners contribute evidence").

Add to `AuditEvent.bend` the types `Influence`, `Influences`, `Edge`, `EventPolicy`, `ObjectLabel`, `Labels` and `Recorded{event, policy}`, and these named helpers:
- `object_influence(labels, object, edge)`, which returns the maximal-restriction influence on a missing or ambiguous entry;
- `source_influences(labels, objects)`, data edges in manifest order;
- `destination_influence(labels, object)`, a data edge;
- `decision_influences(labels, plan)`: the sources plus the destination as data edges, and the same objects again as control edges. The control copies record that the outcome and reason depend on their policies; see the "Reasons" ruling;
- `binding_influence(binding, owner)`: the `D.join(source_label, destination_label)` of the resolved binding, as a control edge owned by the destination's owner;
- `context_secrecy(context)` and `context_untrusted(context)`, the joins over `T.Context.sources`;
- `admission_policy(plan, context, labels)` and `commit_policy(session, context, labels)`. Neither takes the decision or the result as an argument;
- `influences_flow(snapshot, epoch, influences, sink_label)` (all elements, `&&`) and `releasable(snapshot, epoch, policy, sink)`;
- `event_owners(influences)`.

`audited_admit` and `audited_commit` now also return `recorded: Recorded`, with the policy computed from the authoritative inputs. The Task 1 laws keep their statements, because they speak of the `decision`/`result` and `event` components. Ruling: no helper takes an `Influences` argument from a caller in order to add, remove or replace an element.

Add laws:
- `audit_failed_influence_withholds`: for all `snapshot`, `epoch`, `before`, `after`, influence `i` and `sink_label`, with the hypothesis `{D.flows(snapshot, epoch, Influence.label(i), sink_label) == False{}}`, `influences_flow(snapshot, epoch, Influences.append(before, Influences.cons(i, after)), sink_label) == False{}`. The proof is by induction on `before`, as in `failed_check_denies`. Rationale: one owner's unsatisfied restriction, at any position, withholds the event; approvals from the other owners cannot outweigh it. Mutant to show: `||` in place of `&&`, or a walk that stops at the first satisfied element. It does not prove that `releasable` is the only route to a sink; Tasks 4 and 5 show that by tests.
- `audit_outcome_never_lowers_policy`: `Recorded.policy(AuditedAdmission.recorded(audited_admit(plan, context, labels, caller, diagnostic, event_id))) == admission_policy(plan, context, labels)` for all inputs. Rationale: whatever the decision, the policy is the outcome-independent policy of the plan's facts. A protected denial reason is therefore labelled exactly as the facts it may reveal, never lower. Mutant to show: a denial branch that substitutes `D.public_untrusted()`.

Tests (`event_policy` section). Use `D.fixture(3n)` with Alice `Named{0}` and Bob `Named{1}`; Mallory is the outsider:
- "Denial reveals a protected source fact":
  - Bob's source object 11 and an origin rule that excludes the plan's code give an event that is `DeniedFor{Origin{}}`.
  - Its influences contain Bob's label for object 11, as data and as control.
  - It is not `releasable` to Alice-only sink 1, and it is releasable to sink 3, whose label satisfies both owners.
  - The same holds for a `Payment` denial and a `Schema` denial.
- "Multiple owners contribute evidence":
  - An Alice-and-Bob event's influences contain both owners as separate elements (`event_owners` gives both).
  - A sink satisfying Alice's label but not Bob's is not releasable, and one satisfying both is.
  - A second Alice influence added to the label table does not remove Bob's.
- Unlabelled source and duplicate label entries each give the maximal-restriction influence, and that event is releasable to no fixture sink.
- Secrecy: a sink whose DLM label flows but whose `clearance` lacks the source's secrecy bit is not releasable. The same goes for `tolerated` against untrusted bits.
- The policy is outcome-independent: an admitted event and a denied event for the same plan and label table have equal influences, secrecy and untrusted sets. Tested with a test-side `EventPolicy.equal`.
- A commit event's policy includes the binding influence from `BF.binding()`.
- Mutation pins: dropping the control copies, dropping the binding influence, dropping a source from `source_influences`, and making a missing label public each fail a named check.

Estimate about 28 checks. Check box 1.2.

Acceptance:
- Suite green at about plus 93.
- Proofs green with 23 laws (or the recorded exception).
- Every influence-derivation mutant is killed.

### Task 4: Current-authority, owner-scoped queries with response-sink checks (task 1.3; AU-003, AU-008, AU-009 query part)

Implements:
- "AU-003 Current owner-scoped query authority" (scenarios "Owner queries another owner's stream", "Authorized reader uses an unauthorized sink" and "Query grant is revoked");
- "AU-008 Policy-safe observable metadata" (scenarios "Distinct secret denial reasons" and "Pagination would reveal another owner");
- the query half of "AU-009 Bounded audit work fails closed" (scenario "Query exceeds its work budget").

Create `AuditQuery.bend` with:
- the state, `Sink`, `Sinks`, `ReadGrant`, `ReadGrants`, `Query`, `Cursor`, `View`, `Views`, `Response`, `PublicDenial` and `Gate`;
- the public entry points `empty(epoch, snapshot, sinks)`, `respond(state, expected_revision, from: Nat, query, sink_id: Nat, now) -> Response` and `revoke_read(state, expected_revision, grant_id) -> Change` (a monitor transition);
- the helpers `find_sink`, `find_read_grant(grants, from, owner, sink_id)` (an ambiguous match resolves to `None`), `grant_current(grant, state, now)`, `in_stream(owner, recorded)`, `visible(state, owner, sink, recorded)` (`in_stream` and `releasable`), `view(state, owner, sink, stored) -> Views` (a filter in append order), `page(views, offset, limit, work)`, `cursor_matches` and `query_gates`.

`query_gates` requires:
1. the version is supported;
2. the sink is registered;
3. a grant exists for `from`, the query owner and the sink;
4. that grant is unrevoked;
5. its epoch equals the state epoch;
6. `now < valid_until`;
7. any cursor's reader, owner and epoch match;
8. `1 ≤ limit ≤ max_page()`;
9. the page completes within `work`.

`respond` matches on the revision first, then on `Guard.all(query_gates(...))`, and returns `Page` or `Refused{public_denial()}`. A `Page` is computed only from `view(...)`, never from the raw `log` or from any count.

Add laws:
- `audit_invisible_event_unobservable`: for all `state`, `owner`, `sink`, `before`, `after` and stored event `e`, with the hypothesis `{visible(state, owner, sink, e) == False{}}`, `view(state, owner, sink, Stored.append(before, Stored.cons(e, after))) == view(state, owner, sink, Stored.append(before, after))`. The proof is by induction on `before`; structure `view`'s step as a helper taking the visibility Bool so the step case rewrites. Rationale: an event the caller may not see, including a denied attempt, changes nothing a page is built from. So neither its content nor its existence reaches the response ("absence of a denied event as information"). If the arbitrary-position form will not check, state the head-position form (`Stored.cons(e, rest)`), and record the attempt under the Laws rule. Mutant to show: a filter that keeps invisible events as placeholders.
- `audit_stale_query_refused`: for all `state`, `from`, `query`, `sink_id` and `now`, `respond(state, 1n+revision(state), from, query, sink_id, now) == Refused{Unavailable{}}`, proved with `nat_eq_successor_false` as in `issuance_stale_revision_rejects`. Rationale: a response prepared before a revocation, or before any other state change, cannot be released afterwards ("Query grant is revoked"). It covers the successor revision only and does not claim that the host serializes installs.
- `audit_refusal_is_constant`: for all arguments, with the hypothesis `{Guard.all(query_gates(state, from, query, sink_id, now)) == False{}}` and `revision_current` true, `respond(...) == Refused{Unavailable{}}`. Rationale: every refusal is one public value, so distinct protected causes are indistinguishable. Mutant to show: return `Page{[], None}` for the revoked-grant gate.

Tests (`query` section). The log is built from `audited_admit`/`audited_commit` outputs only:
- "Owner queries another owner's stream":
  - Alice holds a grant for her stream only. Her query of Bob's stream is `Refused{Unavailable{}}`. That response is identical with zero and with five Bob events in the log, so the count is not exposed.
  - An Alice-stream query omits Bob-only events, and mixed events are withheld through sink 1.
  - A principal holding Alice and Bob grants through sink 1 still sees no mixed event, because there is no operator widening.
- "Authorized reader uses an unauthorized sink": Alice's grant names sink 1, and the same query through registered external sink 2 is refused. So is an unregistered sink 9.
- "Query grant is revoked":
  - At revision r the page is released. `revoke_read` moves the state to r+1.
  - `respond(state_r1, r, ...)` is refused (stale), and `respond(state_r1, r+1, ...)` is refused (revoked). `first_failed_gate` names `GrantRevoked`.
  - Expired at `now == valid_until`, a grant for another reader, and an epoch advance are each refused, each with its gate named.
- Totals and empty results:
  - Because `Response` has no total field, the type itself is the check. The test asserts that the page view list length equals the number of visible events.
  - Alice's stream containing only a hidden mixed denial event gives exactly `Page{[], None}`, equal to the response for a log with no events at all.
  - The same equality holds with the hidden event placed first, in the middle and last.
- "Pagination would reveal another owner":
  - With limit 2 over five visible events and three hidden ones interleaved, page 1, the cursor, page 2 and the end are each equal to the run over the log without the hidden events.
  - A cursor from Bob, from another owner or from an older epoch is refused.
  - A view never contains `event_id`: views of two logs whose events differ only in `event_id` are equal.
- Sorting: the page follows the visible view's append order. There is no sort input, and the test fixes the order of three visible events.
- "Distinct secret denial reasons": the responses for an unknown version, no grant, the wrong sink, revoked, expired, a bad cursor, `limit` 0, `limit` 17 and an exhausted budget are all equal to each other and to `Refused{public_denial()}`.
- "Query exceeds its work budget": work 3 over five visible events with limit 5 is refused, with no partial page. Work 5 succeeds. Hidden events do not consume work: the same query with three extra hidden events still succeeds with work 5.
- Accepted baseline: a reader whose sink satisfies both owners sees the mixed denial event with `DeniedFor{Origin{}}`.

Estimate about 40 checks. Check box 1.3.

Acceptance:
- Suite green at about plus 133.
- Proofs green with 26 laws (or the recorded exceptions).
- Every one of the nine gates has a single-failure check that dies when the gate is removed.

### Task 5: Policy-gated exports, metrics and alerts (task 1.4; AU-007)

Implements "AU-007 No ambient telemetry export" (scenarios "Remote telemetry has no grant" and "Export authority is revoked").

Create `AuditExport.bend` with:
- the state, `ExportGrant`, `ExportGrants`, `Channel`, `ExportRequest{version, owner, channel, sink_id, rule: Kind filter}`, `Transmission` and `Emit`;
- the public entry points `empty(query_state)`, `transmit(state, expected_revision, from: Nat, request, now) -> Transmission` and `revoke_export(state, expected_revision, grant_id)`;
- the helpers `find_export_grant(grants, from, request)` (exact exporter, owner, sink and channel; ambiguous resolves to `None`), `export_gates` and `metric_count`.

The gates mirror Task 4: version, sink registered, grant found, unrevoked, epoch, unexpired. Then the content depends on the channel:
- `Events`: the encoded views of `AuditQuery.view(...)` for the export sink. Ruling: the canonical encoding of Task 2 restricted to view fields;
- `Metric`: one word, the number of events in that view that match the rule;
- `Alert`: one emission per visible matching event.

Ruling on metrics: the count is over the export sink's releasable view only. Counting all events would leak hidden ones, and withholding the whole metric whenever any protected event exists would make every dashboard unavailable. `docs/AUDIT.md` states that a metric is a releasable-view count, not a total (see the questions).

Add laws:
- `audit_ungranted_export_emits_nothing`: for all `state`, `expected_revision`, `from`, `request` and `now`, with the hypothesis `{find_export_grant(grants(state), from, request) == None{}}`, `Transmission.effects(transmit(...)) == []`. The proof pins `transmit`'s grant lookup, as `derived_lifetime_extension_rejects` pins `find_grant`. Rationale: without an explicit grant nothing is emitted, on any sink, by any fallback. Mutant to show: a `None` arm that emits to a default sink.
- `audit_revoked_export_emits_nothing`: with the hypotheses `{find_export_grant(...) == Some{g}}` and `{ExportGrant.revoked(g) == True{}}`, the effects are `[]`. Rationale: "Export authority is revoked": subsequent transmissions are denied, not rerouted. Structure `transmit` so that the revocation match follows the lookup.

Tests (`export` section):
- "Remote telemetry has no grant":
  - From `empty(...)`, every channel to every sink is `Withheld{}` with no effects.
  - Grants for another sink, another channel (a `Metric` grant used for `Events`), another exporter or another owner are each withheld.
  - An unregistered sink is withheld.
- "Export authority is revoked": the export is `Sent` at revision r. After `revoke_export`, it is withheld at r+1 and withheld at r (stale). Expiry and an epoch advance are each withheld.
- Content stays policy-gated with a grant:
  - The `Events` emission for Alice's sink 1 omits the mixed Bob event, and its words equal those for a log without it.
  - The metric over a log with three visible matching events and two hidden ones is 3, equal to the metric over the log without the hidden ones.
  - An alert rule matching `AdmissionDenied` emits nothing for a hidden denial, and the result equals that for a log without it. It emits one alert for a visible denial.
  - No emission word equals a Task 1 sentinel.
- No fallback: the `Transmission` type has no third constructor. The test exhaustively matches `Sent` and `Withheld` and asserts that `Withheld` carries nothing.
- Mutation pins: every export gate, the channel comparison, the owner comparison and the view restriction each fail a named check when removed.

Estimate about 26 checks. Check box 1.4.

Acceptance:
- Suite green at about plus 159.
- Proofs green with 28 laws (or the recorded exceptions).
- `AuditExport.bend` imports no IO-performing module, and no def returns an effect outside `Transmission`.

### Task 6: Documentation, traceability and full verification for section 1

1. Write `docs/AUDIT.md`. It leads with this plan's worked example and the current gap: section 1 is modeled in Bend, while durable required audit, denial-append failure, verifiable history, queue bounds and every host wiring are not implemented. It then covers:
   - the event field table with each field's sensitivity, noting that identifiers and digests are not automatically public;
   - the excluded material;
   - the ownership and label rules (influences, the fail-closed label, outcome-independent policy);
   - the supported views and query limits (`max_page()`, work in visible events, cursor binding, no totals and no sort);
   - the export capability contract (three channels, releasable-view metrics, no ambient grant, no fallback);
   - the trusted inputs and who supplies them on a real host;
   - the residual timing, scheduling and traffic-volume channels, stated plainly, without any constant-time claim.
   
   It names the public entry points, and links the spec, the traceability file and `openspec/specs/decentralized-labels/spec.md`.
2. Write `openspec/traceability/policy-aware-audit.md` in the shape of `grant-issuance.md`. It opens by saying the change is proposed, section 1 is modeled, and no host adapter or acceptance scenario is implemented. It has one row for each of AU-001 to AU-009, giving functions, exact named checks (verbatim), laws and the coverage boundary. Mark these explicitly:
   - AU-004 and AU-006 are "not implemented (section 2, depends on add-durable-publication)";
   - AU-005 is "partial: recording preserves the decision (laws); append failure not modeled";
   - AU-009 is "partial: query work bounded; append queue not modeled";
   - "grant issuance for event-read and export grants" is a reviewed-only gap.
3. Run:
   - `bend Tests.bend -o ../writ-build/policy-aware-audit/tests.js && node ../writ-build/policy-aware-audit/tests.js > ../writ-build/policy-aware-audit/tests-js.txt`;
   - `bend Tests.bend -o ../writ-build/policy-aware-audit/tests-native && ../writ-build/policy-aware-audit/tests-native +RTS --threads 4 --gpu off > ../writ-build/policy-aware-audit/tests-native.txt`. This is a CPU run, not a GPU test. The two captures must be byte-identical (`cmp`);
   - `bend PROOF.bend`;
   - one `bend PROOF.bend --verdict` attempt. A missing Lean kernel is recorded verbatim as NOT VERIFIED;
   - `~/.bun/bin/bunx @fission-ai/openspec@1.16.0 validate --all --strict --no-interactive`.
4. Write `verification/policy-aware-audit.txt` with:
   - the commands, Bend version and date;
   - the `Audit:` summary line and the total ("1428 plus N = M", as this tree prints it);
   - the `cmp` result and the proof and verdict lines;
   - each new law with its one-line rationale and limits, or "tested, not proved";
   - what was not exercised: durability, crash injection, history verification, any native host, transport authentication, and GPU.
5. Copy the captures into the record directory. Do not overwrite the shared `verification/*.txt` files.
6. Run `git diff --stat master` and show that only the touch list changed, and that `LAWS.bend`/`PROOF.bend` show additions only.
7. Update the `tasks.md` first line as ruled. Boxes 1.1 to 1.4 are checked, each citing its section and laws, and 2.1 to 3.2 stay unchecked.

Acceptance:
- Both backends pass with the same total.
- `ALL PROOFS CHECK`, and OpenSpec strict passes.
- Every traceability row cites existing check names verbatim.
- The evidence file matches the captured runs.
- No count pin moved.
- The change is not archived.

## Questions only Josh or Spaceghost can answer

1. `openspec/ROADMAP.md` orders audit "After durable state". This plan rules that section 1 may land first, because it appends nothing. Is landing a modeled audit section ahead of `add-durable-publication` acceptable, or should the lane wait?
2. Who is the authority for an event-read or export grant: each stream owner approving through an Issuance-style directory, or the monitor alone? Section 1 rules that the monitor installs them and records the gap. The answer decides the shape of a later grant-issuance step for audit.
3. Metrics count only events releasable to the export sink, so they undercount by design. This plan rules it that way. Is that acceptable to operators, or should a metric that any hidden event would affect be withheld entirely?
