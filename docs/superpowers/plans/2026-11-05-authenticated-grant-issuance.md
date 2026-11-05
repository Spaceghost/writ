# Plan: Authenticated grant issuance in Bend (tasks 1.1 to 2.2)

Spec: `openspec/changes/add-authenticated-grant-issuance/` (GI-001 to GI-008; tasks 1.1 to 1.5 and 2.1 to 2.2). Here is the gap. `Transfer.admit` requires a matching source-read grant and a matching destination-write grant at use (TA-001 to TA-007, `Transfer.bend` `scoped`, `Reads.permit`, `Writes.permit`). `Frontend` checks a registered `Capability` against the authenticated caller on every request. Both modules take their grants and capabilities as monitor-supplied data (`T.Context.reads`/`writes`, `F.Registry`). Nothing in Bend says who may put a grant there. Nothing checks that a source-read approval came from that source's read-domain authority, and nothing stops a read from being registered without its exact, current destination-write approval. `openspec/traceability/transfer-admission.md` ends with "authenticated grant issuance is deferred". None of the six laws in `LAWS.bend`/`PROOF.bend` is about grants. This plan adds a Bend issuer, `Issuance.bend`. It authenticates approvals against a monitor-owned authority directory, registers an effective grant only against one current revision of its own state, and derives grants that can only attenuate. It then projects its registered grants into the existing `T.Reads`, `T.Writes` and `F.Registry` shapes, so the use-time checks stay mandatory and unchanged (GI-008). Here is a worked example. A caller who controls only write domain 6 submits a source-read approval for object 10 (read domain 5) under its own identity. The directory names it as the authority for write domain 6 only, so submission is denied with `NotAuthority` and the state is returned unchanged. No read grant for object 10 can then be registered.

## Global Constraints

- Lane `lane/authenticated-grant-issuance`, worktree `../writ-lanes/authenticated-grant-issuance`, created from current master. Environment: `export PATH="$HOME/.local/share/writ-toolchains/bend-2.0.39/bend/bin:$PATH"; export BEND_NO_TELEMETRY=1`. Bend 2.0.39 only. Before the first edit, read `AGENTS.md`, `bend guide` (the "Laws and Proofs" section in particular), `openspec/README.md`, the change (proposal, design, spec, tasks), `Transfer.bend`, `Frontend.bend`, `DataOS.bend`, `Guard.bend`, `LAWS.bend`, `PROOF.bend`, `HostBinding.bend` lines 1-180 (the `Error`/`Change`/`Rejected{state, reason}` pattern to copy), `TransferTests.bend` (fixtures `TF.plan()`, `TF.context()`, `TF.with_reads`/`with_writes`), `FrontendTests.bend`, `FacadeTests.bend`, `BackplaneTests.bend` (`BF.with_transfer`), and `Tests.bend`. Issuance adds no parallel or GPU entry point, so `bend guide shaders` is not required.
- Touch only these files. Create `Issuance.bend`, `IssuanceTests.bend`, `docs/GRANT-ISSUANCE.md`, `openspec/traceability/grant-issuance.md` and `verification/grant-issuance.txt`. Edit:
  - `Tests.bend`: one import and one `Issuance.main()` line, placed after `Facade.main()`.
  - `FacadeTests.bend`: the Task 5 checks and its count string.
  - `LAWS.bend` and `PROOF.bend`: additions only.
  - `openspec/changes/add-authenticated-grant-issuance/tasks.md`: boxes only.
  - `openspec/traceability/transfer-admission.md`: the closing "deferred" sentence only.
  - `VERIFICATION.md`, `README.md`: the count sentence at line 114 only.
  - `verification/tests-js.txt`, `verification/tests-native.txt`, `verification/proofs.txt`, `verification/kernel-verdict.txt` (append only) and `verification/openspec-validation.txt`.
  - The two current-tree count gates: `utils/nix/writ.nix` (`assertTests` comment and constant) and `WRIT_CORE_EXPECTED` in `.github/workflows/writfs-genode-native.yml`. The workflow runs on every `*.bend` push to master, so it would go red without this edit.
  - The "currently 782" text in `contrib/native-hosts/genode/build-and-run.sh`.

  Do not edit `Transfer.bend`, `Frontend.bend`, `DataOS.bend`, `Backplane.bend`, `Negotiation.bend`, `Ledger.bend`, `Guard.bend`, `HostBinding.bend` or any `writfs/`, `contrib/rclone/` or `hosts/` source. Because none of their imports change, the writfs and rclone suites are unaffected, and Task 7 shows this with `git diff --stat master`. If an implementation seems to need one of those files changed, stop and report BLOCKED.
- **Plan ruling (host corpora):** the Unikraft `check-corpus.sh` default and its Linux reference capture, and the Genode `writ_bend_tests.run` default, stay at 782. They are bound to recorded evidence for the pre-issuance tree, and rebuilding those images is out of scope. Task 7 records in its report that these gates need rebaselining for the new tree.
- Security rules (AGENTS.md):
  - No `unsafe` definitions, no `?TODO`/`?name` holes, no law without a proof def (that is an open claim), and no array indexing (use recursive lists, like `Transfer.bend`).
  - No record in `Issuance.bend` carries a Bool, or any other field, that asserts authentication, ownership or authority. The authenticated principal arrives as a separate parameter of type `Principal` that the host attaches to the transition. An approval's own `issuer` field is a claim, and it is compared against that parameter and the directory.
  - Every accepting transition revalidates the stamp, authority epoch, directory membership, placements, revocation, expiry and exact scope against the state it commits. The projection functions revalidate again at every use. A registered grant record is never trusted because it exists.
  - `Issuance` produces no `WriteIntent`, does not call `Backplane`, and adds no release route. `DataOS.commit_from_capability` stays the only host-facing commit.
  - **Plan ruling (disabled path):** no `DataOS` facade entry is added in this change. The design says to keep the new path disabled until its acceptance tests and host preconditions hold. `Issuance` is a library module that a future host wires in, and its public entry points are documented in its header.
- Laws: this change touches security laws. Do not weaken, reword, reorder or delete any existing law in `LAWS.bend` or its proof in `PROOF.bend` to make a changed implementation pass. `git diff master -- LAWS.bend PROOF.bend` must show added lines only. Every new law gets a rationale in two places: a comment directly above it in `LAWS.bend` (the existing convention: what it states, why it matters to issuance, and what it does not claim), and a "Laws" paragraph in the `Issuance.bend` module header naming the law and that rationale. If a new law does not check under ordinary `bend PROOF.bend` with a complete proof, do not add a hole or a weaker statement. Leave it out of `LAWS.bend`, record the attempted statement and the checker output in the task report, and state it as "tested, not proved" in `VERIFICATION.md`.
- Validation at every commit, all green before committing: `bend Issuance.bend --check-only`, then `bend Tests.bend` (last line `ALL LIBRARY TESTS PASSED`; record the new total PASS count, with both the `PASS:` and `PASS ` forms counted), then `bend PROOF.bend` (`ALL PROOFS CHECK`). Task 7 adds the native run and OpenSpec strict validation. A red suite or proof check at any commit is a stop, not a commit.
- Code conventions: named helpers for every policy bit, identity and comparison (for example `rights_within`, `lifetime_within`, `scope_equal`, `is_read_authority`). Comments explain authority, invariants, edge direction and failure behavior. Every public entry point is marked "Public entry point" in a comment, and exported implementation helpers are not. Test fixtures in `IssuanceTests.bend` are commented as synthetic authority records, not an authenticated issuer. Each task adds one `def <section>() -> IO(Unit)` to `IssuanceTests.bend` (`submission`, `registration`, `revision`, `attenuation`, `integration`, `scenarios`). `main` calls them in order and ends with `IO.print("Issuance: N checks passed")`, with N kept exact. Every denial test checks both the exact `Error` (via `Error.equal`) and that `Change.state` equals the supplied state's revision and content (via a test-side state equality helper).
- Records: `docs/superpowers/records/2026-11-05-authenticated-grant-issuance/`. Append one line per step to `activity.log` there: tab-separated UTC time, role, text. While a long run is going (the native build, or the `--verdict` attempt), add a heartbeat line at least every 10 minutes. A silent 30 minutes marks the lane idle on the board. Reports go to `task-N-report.md` in the same directory, with commands, final lines, PASS totals and any BLOCKED or DONE_WITH_CONCERNS status. Include `git add -A docs/superpowers/records/2026-11-05-authenticated-grant-issuance` in each commit. One commit per task, no `verification/source-sha256.txt` manifest regeneration (that happens on master), no push, no `openspec archive`.

### Shared design for all tasks (plan rulings)

These rulings fill gaps the design leaves open. Each is fixed for the whole lane.

- **State is one snapshot.** `Issuance.State{revision, next_id, live: T.Stamp, directory: Authorities, placements: Placements, approvals: Approvals, grants: Grants, seen: Serials}`. Ruling: the epoch snapshot, the authority directory and the object placements live inside the issuer's own state. That makes "validates and registers against one authoritative snapshot" literal. A directory or epoch change is the monitor installing a new state. Ids are positive, monotone and never reused, as in `Frontend`.
- **Identities.** The identity type is `Principal{id: Nat}`. Directory entries are `ReadAuthority{principal, domain: T.ReadDomain}` and `WriteAuthority{principal, domain: T.WriteDomain}`. These are separate namespaces, so read domain 5 and write domain 5 confer nothing on each other. Placements are `SourceAt{object: T.ObjectVersion, domain: T.ReadDomain}` and `DestinationAt{object: T.ObjectVersion, domain: T.WriteDomain}`. Ruling: placements are needed. Without them, a caller could name a read domain it does control for a source that lives in another domain, and issuance must deny that before use.
- **Scope.** `Scope{plan: T.Plan, write_domain: T.WriteDomain, subject: Nat}`. The plan already binds the stamp (epoch snapshot), invocation, ordered source manifest with versions, destination object version, code, kind and output type, so `scope_equal` is `T.Plan.equal` plus write-domain equality plus subject equality. That is exactly what GI-003 lists.
- **Approvals.** `SourceApproval{version, serial, issuer: Principal, source: T.ObjectVersion, domain: T.ReadDomain, scope, rights: U32, valid_until}` and `WriteApproval{version, serial, issuer, destination, domain: T.WriteDomain, scope, rights, valid_until}`. The record version supported is `1n` only, and an unknown version is denied. Ruling: approvals are single-use. A registration consumes the approvals it cites, and a consumed approval cannot back a second registration (`Replay`). The design forbids forgetting consumed receipts, and single use keeps one approval pair to one effective grant. Ruling: `(issuer, serial)` pairs are kept in `seen` forever, through revocation, so a replayed approval is denied.
- **Rights.** Rights use Frontend's bits (1 read, 2 write, 4 execute; values within 7). The rights of an issued capability must be within the intersection of every cited approval's rights.
- **Lifetime.** Ruling: the requested `valid_until` must be ≤ each cited approval's `valid_until`. Anything larger is denied (`Widened`), never silently clamped. Every expiry check is exclusive (`now < valid_until`), matching TA-007 and Frontend.
- **Tokens.** Ruling: the capability token is a monitor-supplied fresh `T.CodeId` passed to `register` and `derive`. Bend does not generate randomness. A token already present in the state is denied (`DuplicateToken`), matching `F.registry_valid`'s duplicate rule.
- **Errors.** The closed set is `Issuance.Error`: `StaleRevision`, `UnknownVersion`, `Unauthenticated` (the claimed issuer is not the authenticated principal), `NotAuthority`, `WrongDomain`, `MissingApproval`, `ScopeMismatch`, `SubjectMismatch`, `Expired`, `Revoked`, `Replay`, `Widened`, `InvalidRights`, `DuplicateToken`, `StaleEpoch`. `Issuance.Change` is `Rejected{state, reason}` or `Changed{state, id}`, with accessors as in HostBinding. Every denial returns the supplied state unchanged.
- **Gates.** Ruling: each transition computes its acceptance as `Guard.all(<transition>_checks(...))` over a `Guard.Checks` list, plus a separate first-failure reason selector. The existing law `failed_check_denies` then covers a failed issuance check at any position, without modifying that law.

- Cross-lane ruling (controller, 2026-11-05): two lanes add tests to `Tests.bend` at the same time (`lane/authenticated-grant-issuance` and `lane/portable-host-contract`), and a third (`lane/physical-gpu`) reads the corpus count. So: (1) this lane does not change any recorded count pin: not `README.md`, `INSTALL.md`, `utils/nix/writ.nix`, `.github/workflows/*.yml` (`WRIT_CORE_EXPECTED`), nor the count sentences in `VERIFICATION.md`; its records state the count its own tree produces ("782 plus N new checks = M") and the controller re-pins every count once after both lanes have merged, then watches the Genode CI run on that push; (2) the earlier host corpus runs (Genode, Unikraft, native hosts) stay historical at 782 and are re-recorded by a later lane, not this one; (3) keep this lane's `Tests.bend` edit to the smallest registration block (one import and one call group) so the merge with the other lane is a two-line conflict at most; (4) the change is not archived by this lane.

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

### Task 3: Revision-checked registration and revocation (task 1.3; GI-005)

Implements "GI-005 Issuance races are revision checked". Add the public entry point `revoke(state, expected_revision, from: Principal, approval_id)`. Only the approval's authenticated issuer, who must still be the directory authority, may revoke. Revocation marks the approval revoked, keeps its serial in `seen`, and advances the revision. Ruling: revoking an approval makes every grant that cites it, and every grant derived from such a grant (Task 4), unusable through the projection. Grant records are not edited, so the history stays.

Add the public entry point `current(state, grant, now) -> Bool`. It re-derives usability from the state on every call. The grant must be in `grants`, and every approval it cites must be present, consumed by this grant, unrevoked and still authenticated by the directory. The scope stamp must equal live, `now` must be below both the grant's and every approval's `valid_until`, and every ancestor must be current. `valid(state)` additionally requires that every grant's cited approvals exist and are consumed by exactly that grant. A grant record copied into a fresh state therefore fails `valid`, and is never `current`.

Add laws:
- `issuance_denied_preserves_state`: `Issuance.Change.state(Issuance.Rejected{state, reason}) == state`. Rationale: fixes the denial contract that every issuance transition relies on, so a denied or raced registration exposes no new state. It holds by computation and does not prove that a transition chose the denial.
- The auxiliary `nat_eq_successor_false`: `Nat.is_eq(n, 1n+n) == False{}`, by induction like `nat_lt_successor`.
- `issuance_stale_revision_rejects`: for all `state`, `request`, `now` and `token`, `Issuance.Change.accepted(Issuance.register(state, 1n+Issuance.revision(state), request, now, token)) == False{}`. Rationale: a registration validated at revision r cannot commit after any transition has moved the state, which is the GI-005 race. The proof needs `register` to test the revision first, in a gate that matches on that Bool, so that the lemma rewrites it. Structure `register` that way. It does not claim that the host serializes installs; that is AB-006.

Tests (`revision` section):
- Revocation during issuance: approvals valid at revision 7, then `revoke` moves the state to 8.
  - `register(state8, 7, ...)` is denied with `StaleRevision`, `Change.state` is state8, no grant for the plan is `current`, and no stale grant is exposed.
  - `register(state8, 8, ...)` is denied with `Revoked`.
- A registered grant becomes not `current` after either approval is revoked.
- `revoke` by a non-issuer: `Unauthenticated`. `revoke` by a former authority now gone from the directory: `NotAuthority`. A stale `expected_revision`: `StaleRevision`.
- Replay:
  - A second `register` citing consumed approvals: `Replay`.
  - Re-submitting a revoked approval's serial: `Replay`.
- A grant copied into a fresh `empty(...)` state, or into a state whose approvals lack it: `valid` is false and the grant is not `current`.
- The monitor advances the authority epoch (a new live stamp): the old grant is not `current`, and a registration with the old scope gives `StaleEpoch`.
- The revision is unchanged on every denial.

Estimate about 14 checks. Check box 1.3.

Acceptance: green suite at about 830 checks. `bend PROOF.bend` is green with nine laws (six unchanged plus three), or the unproved law is recorded under the Laws rule. `git diff master -- LAWS.bend PROOF.bend` shows additions only.

### Task 4: Expiry and attenuation (task 1.4; GI-006, GI-007)

Implements "GI-006 Derived grants only attenuate" and "GI-007 Issued approvals have exclusive expiry". Add the public entry point `derive(state, expected_revision, from: Principal, parent_id, child: Derivation, now, token)`, where `Derivation{version, rights, valid_until}`. Ruling: `Derivation` has no scope, plan or subject field. The child copies its parent's scope and subject by construction, so a widening of scope cannot be represented. Ruling: only the parent's subject may derive (`from` must equal the scope subject, otherwise `SubjectMismatch`). Derivation to another subject is delegation, and GI-004 forbids that without the authorities' approval.

The checks require: the revision is current, the parent is `current` at `now`, `rights_within(child.rights, parent.rights)`, `lifetime_within(child.valid_until, parent.valid_until)` (that is, `Nat.is_le`), `now < child.valid_until`, the token is fresh, and version 1. The child stores `parent: parent_id` and cites no approvals of its own, and `current` walks the parent chain.

Add law `derived_lifetime_extension_rejects`: `Issuance.lifetime_within(1n+u, u) == False{}` for all `u`, with the auxiliary `nat_le_successor_false` if needed. Rationale: this is GI-006's lifetime half on the named helper that `derive` uses. It does not prove that `derive` calls the helper, which the tests show. It also does not cover rights, because U32 masks are not inductive. State both limits in the comment.

Tests (`attenuation` section):
- Extending an expiry: the parent expires at 100 and the child asks for 101: `Widened`. Asking for 100 is accepted, and so is 50.
- Widened rights: the parent has 1 and the child asks for 3: `Widened`. A child with equal rights is accepted.
- A non-subject derives: `SubjectMismatch`.
- The derived child's projected plan equals the parent's (`T.Plan.equal`).
- A grandchild cannot exceed its grandparent, through its parent.
- Revoking the parent's source approval makes both parent and child not `current`.
- Deriving at `now` equal to the parent's expiry: `Expired`.
- Issuance at the deadline (GI-007): an approval valid while `now < 100` is accepted on submission at 99 and denied at 100 with `Expired`. A registration attempted at 100 after a submission at 99 is denied. A grant with `valid_until` 100 is `current` at 99 and not at 100.
- A requested grant lifetime beyond the shorter approval: `Widened`.
- Derive version 2: `UnknownVersion`.

Estimate about 16 checks. Check box 1.4.

Acceptance: green suite at about 846 checks, and green proofs with ten laws (or the recorded exception).

### Task 5: Integration and the trusted identity inputs document (task 1.5; GI-008)

Implements "GI-008 Issuance does not replace use-time authorization". Add three public projection entry points:
- `reads(state, now) -> T.Reads`: one `T.ReadGrant{source, domain, GrantScope}` per manifest entry of each `current` grant;
- `writes(state, now) -> T.Writes`;
- `registry(state, now) -> F.Registry`: `F.Capability{token, subject, plan, rights, authority(stamp), valid_until}`.

Each projection includes only grants that are `current` at `now`. The `GrantScope` fields come from the scope and `valid_until`. The header says that the host must rebuild `T.Context.reads`/`writes` and the `F.Registry` from the current issuer state for every use, which is a trusted input. Bend still runs `T.admit` and `F.checked_plan` unchanged on those projections.

Tests (`integration` section, using the TF/BF fixtures):
- The projection of a registered grant makes `T.admit` admit `TF.plan()`, and `F.mount`/`open`/`checked_plan` resolve it for the subject.
- Revocation after registration: the write approval is revoked, the projection is rebuilt, and `T.admit` is denied (`Write`) and `checked_plan` gives `None`.
- A source-approval revocation gives a `Read` denial.
- A projection at the grant's expiry is empty.

In `FacadeTests.bend`, two checks drive `OS.commit_from_capability` with an `OS.Context` built from the projections. One is accepted. The other, after a write-approval revocation, is denied and spends no reservation. Estimate about 6 Issuance and 2 Facade checks.

Write `docs/GRANT-ISSUANCE.md`. It leads with the worked example from this plan's header and the current gap: the model is implemented, while host transport, durable state and wiring are not. It then covers each trusted identity input: what Bend does with it, and what happens if the host supplies it wrongly.
- The authenticated `Principal` attached to each submission, revocation and derivation. Name the dependency "transport identity verification" and give example sources: the Genode route subject (`HostBinding.Route.subject`), Linux peer credentials, Windows token SID. It is not a record field.
- The authority directory and the placements.
- The live stamp and `now`.
- Fresh tokens.
- Atomic installation of an accepted state at `expected_revision`, with durability, under AB-006 and the pending durable-publication change.
- Rebuilding the projections per use.
- Approvals carried off-host. Bend verifies no signature, and cryptographic verification is a host input that this change does not implement.
- Rollback: never restore an old epoch, and never drop `seen` or consumed approvals.

Name the public entry points. Link the spec, the traceability file (created in Task 6) and `openspec/specs/authority-boundary/spec.md`.

Run `bend Tests.bend` and quote the Transfer, Frontend, Facade and Issuance summary lines in the report. Check box 1.5.

Acceptance: green suite at about 854 checks and green proofs. The document names every trusted input that the code's parameters take. `Transfer.bend`, `Frontend.bend` and `DataOS.bend` are untouched.

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

### Task 7: Full verification, records and host preconditions (task 2.2)

Run:
- `bend Tests.bend -o ../writ-build/tests.js && node ../writ-build/tests.js > verification/tests-js.txt`;
- `bend Tests.bend -o ../writ-build/tests-native && ../writ-build/tests-native +RTS --threads 4 --gpu off > verification/tests-native.txt`. This is a CPU run with `--gpu off`, and the record says so. The two files must be byte-identical, with the same PASS count;
- `bend PROOF.bend > verification/proofs.txt`;
- one attempt at `bend PROOF.bend --verdict`, appended verbatim to `verification/kernel-verdict.txt` (a missing Lean kernel is recorded as NOT VERIFIED, as before);
- `~/.bun/bin/bunx @fission-ai/openspec@1.16.0 validate --all --strict --no-interactive > verification/openspec-validation.txt`.

Update `VERIFICATION.md`:
- an Issuance row in the suite table, the new Facade count, and the new total;
- the "counting both forms yields N" sentence;
- the proof-scope list (the new laws, each with its one-line rationale and limits, or "tested, not proved").

Update the count in `README.md` at line 114, and the current-tree count gates (`utils/nix/writ.nix`, `WRIT_CORE_EXPECTED` in the Genode workflow, and the `build-and-run.sh` message) to the new total.

Add a "Remaining host preconditions" section to `docs/GRANT-ISSUANCE.md`: transport identity verification, signature verification for off-host approvals, durable and serialized state, per-use projection rebuilding, enablement and capability negotiation in a host adapter, and the host-corpus rebaseline (Unikraft and Genode gates still at 782). Run `git diff --stat master` to confirm that the don't-touch list holds. Check box 2.2.

Acceptance: both backends pass with the same new total; `ALL PROOFS CHECK`; OpenSpec strict passes; every record agrees with the runs. All seven boxes are checked, each citing its evidence, and the change is not archived (the controller decides on landing).
