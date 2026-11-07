# Authenticated grant issuance: trusted identity inputs

## A worked example

A caller who controls only write domain 6 submits a source-read approval for
object 10, which lives in read domain 5, under its own identity. The authority
directory names that caller as the authority for write domain 6 only, so
`submit_source` denies the submission with `NotAuthority` and returns the
state unchanged. Without that approval no read grant for object 10 can be
registered, and with no registered grant the projections the host hands to
`Transfer.admit` contain no read of object 10. The check is
"GI-001 forged source issuer: the write-domain-6 principal submitting a source
approval for object 10 under its own identity denied NotAuthority" in
`IssuanceTests.bend`.

The reverse case also holds. Once a grant is registered, revoking its
destination-write approval removes the grant from every projection the host
rebuilds afterwards. `Transfer.admit` then denies at `Write`, and
`Frontend.checked_plan` returns no plan for a descriptor that was opened while
the grant was still current ("GI-008 revocation after registration: ..." in
`IssuanceTests.bend`). Through the unchanged DataOS facade, the commit is
denied and spends no reservation ("GI-008 after the issuer revokes the write
approval the rebuilt projections deny the facade commit and spend no
reservation" in `FacadeTests.bend`).

## The current gap

The issuance model is implemented in Bend (`Issuance.bend`): authenticated
approval submission, exact paired-scope registration, revision-checked
revocation, attenuation-only derivation, the per-use `current` check, and the
projections into the existing use-time checks. Nothing outside the model is
implemented. No host transport delivers authenticated submissions, no durable
store holds the issuer state, and no host wires the projections into a real
`Transfer.Context` or `Frontend.Registry`. The DataOS facade has no issuance
entry point; by plan ruling the new path stays disabled until its acceptance
tests and host preconditions hold. Every input listed below is therefore a
precondition that a future host must meet. None of them is evidence that a
host meets it today.

Contracts and evidence:

- Proposed contract: [grant-issuance spec](../openspec/changes/add-authenticated-grant-issuance/specs/grant-issuance/spec.md) (GI-001 to GI-008).
- Traceability: [openspec/traceability/grant-issuance.md](../openspec/traceability/grant-issuance.md).
- Host obligations this document depends on: [authority-boundary spec](../openspec/specs/authority-boundary/spec.md), in particular AB-006.

## Public entry points

All of them are in `Issuance.bend`. Every other definition there is an
exported implementation helper, and calling one does not perform a
transition's checks.

| Entry point | What it does |
| --- | --- |
| `empty(live, directory, placements)` | The issuer state the monitor installs. |
| `submit_source(state, expected_revision, from, approval, now)` | Accepts a source-read approval from its read-domain authority (GI-001). |
| `submit_write(state, expected_revision, from, approval, now)` | Accepts a destination-write approval from its write-domain authority (GI-001). |
| `register(state, expected_revision, from, request, now, token)` | Issues one grant backed by one exact, current approval pair, on behalf of the request scope's subject only (GI-002 to GI-004). |
| `revoke(state, expected_revision, from, approval_id)` | Withdraws a stored approval on behalf of its issuer (GI-005). |
| `derive(state, expected_revision, from, parent_id, child, now, token)` | Issues an attenuated grant to the parent's own subject (GI-006, GI-007). |
| `current(state, grant, now)` | Whether a grant is usable now, re-derived from the state (GI-005). |
| `valid(state)` | Structural validity only. It authenticates nothing. |
| `reads(state, from, now)`, `writes(state, from, now)`, `registry(state, from, now)` | Projections of the authenticated principal's current grants into `T.Reads`, `T.Writes` and `F.Registry` (GI-008). |
| `Change.accepted`, `Change.state`, `Change.reason`, `Change.issued`, and the state accessors | Read a transition's outcome. |

## Trusted identity inputs

Bend authenticates nothing by itself. It compares what it is given. Each input
below is taken as given. The other parameters are untrusted claims that Bend
checks against these inputs: the approval records, the `Request` (scope, cited
approval ids, rights, lifetime), the `Derivation`, the `parent_id` and
`approval_id`, and the `grant` passed to `current`. For each trusted input,
this section says what Bend does with it, who must supply it on a real host,
and what happens if the host supplies it wrongly.

### The authenticated principal (`from`)

`submit_source`, `submit_write`, `register`, `revoke` and `derive` each take
`from: Principal`, a separate parameter that the host attaches to the
transition. The projections `reads`, `writes` and `registry` take the same
parameter for the principal of a use, and that principal is the identity the
host presents to Frontend as `F.Caller.subject`. It is not a record field.
No approval, request or derivation can assert its own authentication.

- What Bend does with it: an approval is accepted only when its claimed
  `issuer` equals `from` (otherwise `Unauthenticated`) and the directory names
  `from` as the authority for the approval's domain (otherwise
  `NotAuthority`). A revocation must come from the approval's recorded issuer,
  who must still be that authority. A derivation must come from the parent
  grant's subject (otherwise `SubjectMismatch`). A registration must come
  from the subject the request scope names (otherwise `SubjectMismatch`,
  checked before any approval is read). That check grants no authority, since
  the only authority is the cited approvals, each bound to an authenticated
  submitter. It exists because approvals are single use. Without it, any
  caller that learned the approval ids (they are sequential and returned in
  every `Change.issued`) could register the pair first with terms the subject
  never chose, for example rights 0 until `now + 1`. That would consume both
  approvals, and the subject's own registration would then be denied
  `Replay` ("GI-004 principal 8, neither an authority nor subject 7,
  registering subject 7's pair with rights 0 until 101 denied
  SubjectMismatch, both approvals unconsumed" in `IssuanceTests.bend`).
- Who supplies it: the host's transport identity verification. Example
  sources are the Genode route subject (`HostBinding.Route.subject`, the
  identity the parent prepends to the session label), Linux peer credentials
  on the broker socket, and the Windows token SID of the calling process. A
  native capability, descriptor or handle is not a portable credential, and
  bearer possession alone does not establish the original caller's identity
  (see `docs/PLATFORMS.md`).
- If it is wrong: anyone the host misidentifies as a directory authority can
  submit and revoke approvals in that authority's domains, and anyone
  misidentified as a grant's subject can register its approved pairs, derive
  from its grants and use them: the
  projections built for that principal include the grant, and Frontend's
  caller check compares against the same identity. Bend cannot detect this,
  because the parameter is the definition of who is asking.

### The authority directory and the placements

`State.directory` (`ReadAuthority`, `WriteAuthority`) and `State.placements`
(`SourceAt`, `DestinationAt`) live inside the issuer state that the monitor
installs.

- What Bend does with them: read and write domains are separate namespaces.
  A source approval needs the read-domain authority, and the monitor's
  placement must put the source object in that same domain (otherwise
  `WrongDomain`). Write approvals are checked the same way against the write
  directory and the destination placements. An object placed twice in one
  namespace resolves to no domain and is denied. `current` re-checks the
  directory and the placements at every use, so a removal withdraws existing
  grants.
- Who supplies them: the monitor, from the authoritative record of which
  principal administers which domain and where each object version is
  stored. A change is the monitor installing a new state, never a caller
  request.
- If they are wrong: a principal wrongly named as an authority can approve
  reads or writes in that domain, and a wrong placement lets an authority
  approve an object it does not control. Bend checks consistency (one
  placement per object, the claimed domain against the placement). It cannot
  check that the directory matches reality.

### The live stamp and `now`

`State.live` is the current epoch snapshot (graph, policy and authority
epochs). `now` is passed to every submission, registration, derivation,
`current` call and projection.

- What Bend does with them: a scope must be stamped with the live stamp
  (otherwise `StaleEpoch`), and `current` re-checks it, so an epoch advance
  withdraws every grant issued under the old one. Every expiry is exclusive
  (`now < valid_until`), matching Transfer and Frontend. The projections take
  `now` and include only grants current at that time.
- Who supplies them: the monitor, from its authoritative epoch state and a
  trusted, monotone clock: `now` never decreases across the transitions and
  uses of one issuer state. The `now` passed to the projections must be the same time
  the host passes in `T.Context.now` and `F.Live` for that use, and the live
  stamp must be the one in `T.Context.live`.
- If they are wrong: a stale live stamp keeps grants from a retired epoch
  usable, and a clock that runs slow or is caller-chosen extends every
  lifetime. A clock that goes backwards revives expired grants and
  approvals. Bend checks only the upper bound `now < valid_until` and records
  no lower bound. A grant that expired at 150 is current again at 149, and
  approvals valid until 100 still register at a regressed time of 50.
  Expiry and epoch are re-checked at use against `T.Context.now`
  and `live` (`Transfer.scoped`, `Frontend.capability_current`), so a
  projection built at an earlier `now` cannot by itself admit an expired
  grant while those use-time values are trusted; a later `now` only drops
  grants. Revocation and directory or placement changes are enforced only by
  rebuilding the projection, so the time and stamp for both must come from
  the monitor.

### Fresh tokens

`register` and `derive` take a `token: T.CodeId`, the capability token the
new grant will carry.

- What Bend does with it: Bend generates no randomness. It denies a token
  that a registered grant already holds (`DuplicateToken`), and that keeps the
  projected registry free of duplicates. Frontend would reject the whole
  registry otherwise.
- Who supplies it: the monitor, from a cryptographically secure source,
  never from the caller.
- If it is wrong: a predictable token can be guessed by another caller.
  Frontend still checks that the caller's authenticated subject owns the
  capability, so the guess alone does not grant use, but it removes a layer
  of defence. A token reused across issuer states, or across registries the
  host merges, is not caught by this issuer's freshness check.

### Finite allocation counter

The pinned runtime supports Nat through 2^48 − 1. Source/write submission,
registration and derivation allocate from one positive, monotonic `next_id`,
which must remain above every allocated ID. Max − 1 is the final allocatable
ID. An otherwise eligible allocation at max returns the new closed-set
`IdExhausted` reason and the original state; earlier failed gates retain their
existing precedence. This is an observable model API addition. The bound is not
an authority check: existing current grants and their projections remain usable
and authorized revocation remains available when revision headroom exists.
Exhaustion of the separate revision counter is not repaired by this change.

### Atomic installation at `expected_revision`, with durability

Every transition takes `expected_revision` and returns the next state. A
denial returns the supplied state unchanged.

- What Bend does with it: a transition commits only when `expected_revision`
  equals the state's revision (otherwise `StaleRevision`). The laws
  `issuance_stale_revision_rejects`, `issuance_stale_registration_keeps_state`
  and `issuance_stale_revocation_keeps_state` prove this for the successor
  revision.
- Who supplies it: the host must install an accepted state atomically at that
  revision, serialize transitions against the current authoritative revision,
  and keep the result across crashes. That is AB-006 in the authority-boundary
  spec. The pending
  [durable-publication change](../openspec/changes/add-durable-publication/proposal.md)
  is where recoverable persistence is proposed. Neither is implemented for
  issuance.
- If it is wrong: two transitions validated at the same revision can both be
  installed. A registration could then commit against a state from which an
  approval had just been revoked (the GI-005 race), or a lost write could
  forget a revocation. Revision equality is a check. It does not serialize a
  concurrent host by itself.

### Rebuilding the projections for every use

`reads(state, from, now)`, `writes(state, from, now)` and
`registry(state, from, now)` return the grant lists `Transfer.admit` consumes
(`T.Context.reads`/`writes`) and the registry `Frontend` and the DataOS
facade consume (`F.Registry`), for one use by the authenticated principal
`from`.

- What Bend does with them: each projection walks the grant list and keeps
  only grants whose scope's subject is `from` and that are `current` at
  `now`. A revoked, expired or otherwise withdrawn grant contributes nothing
  to any of the three, and neither does another subject's grant. Each read grant
  is placed in the source's read domain, and every entry is bound to the
  grant's own scope and lifetime. `T.admit` and `F.checked_plan` then run
  unchanged on the result. Issuance adds no shortcut around them.
- Rights reach Frontend only. `rights` limit what a Frontend handle opened
  from the projected registry may do, but Transfer's grants carry no rights,
  so the projected read and write grants do not reach `Transfer.admit` with
  them. On a bare `T.admit` path (`DataOS.admit`, `Backplane.commit`, the
  Negotiation transitions), a current grant admits its whole plan whatever
  its rights, including a rights-0 grant. The hazard is that a grant
  registered or derived with narrower rights than its approvals still
  projects the full approved read and write to any path that does not go
  through `F.checked_plan`. It never projects more than the approvals'
  scope covers. A host must route rights-limited use through Frontend
  (`DataOS.commit_from_capability`) and must not treat a bare admission as
  evidence that a grant's rights permitted it.
- Who supplies them: the host must rebuild all three from the current,
  installed issuer state, for the principal of this use, for every use. It
  must not cache one, reuse an earlier one, reuse one built for another
  principal, or let the caller supply one. The projections replace only the
  grant fields of `T.Context`. The live stamp, `now`, the source and
  destination policies, the operation and the payment witnesses stay
  host-supplied Transfer inputs. The issuer's placements and the context's
  source and destination policy domains must come from the same monitor
  record: `ReadGrant.matches` requires the projected read domain to equal the
  source policy's domain, so a divergence denies (fail-closed) but signals a
  host fault.
- If it is wrong: a cached projection keeps a revoked grant usable, and
  likewise a grant withdrawn by a directory or placement change, because
  those are the facts the use-time checks cannot re-derive. They see only
  the lists they are given, so they cannot tell a stale projection from a
  current one. Merging in grants from another source puts authority beside
  the issuer's that the issuer never checked.

### The subject of a use

Transfer's grants carry no subject: `T.ReadGrant`, `T.WriteGrant` and
`T.GrantScope` bind a plan's invocation, manifest, destination, write domain,
code, kind, stamp and lifetime, but not who may use them. Only Frontend's
`capability_current`, reached through `F.checked_plan` and so through
`DataOS.commit_from_capability`, compares a use with an authenticated
caller. Other library paths run `T.admit` on a bare `T.Context` with no
caller check: `DataOS.admit`, `Backplane.commit` and the Negotiation
transitions.

- What Bend does about it: the projections are subject-scoped. They take the
  authenticated principal of the use and return only that subject's grants,
  so a list built for one caller never holds another subject's grant. A
  different principal gets empty lists ("GI-008 subject-scoped projections:
  ..." checks in `IssuanceTests.bend`), and on a bare `T.admit` path
  principal 8 gets no admission from subject 7's grant.
- Who supplies it: the host's transport identity verification, the same
  input as `from` above. The principal passed to the projections must be the
  caller of this use, and the same identity the host presents as
  `F.Caller.subject`.
- If it is wrong: lists built for the wrong principal, or reused for a
  different caller, hand that subject's grants to someone else. On a path
  that also goes through `F.checked_plan`, the registry's subject check
  still refuses a caller whose authenticated subject does not own the token.
  On a bare `T.admit` path nothing else checks the caller.

### Approvals carried off-host

An approval record (`SourceApproval`, `WriteApproval`) names an issuer, a
serial, a scope, rights and a lifetime.

- What Bend does with it: Bend treats the `issuer` field as a claim and
  compares it with `from` and the directory. `(issuer, serial)` pairs are
  kept in `seen` forever, so a replayed approval is denied (`Replay`). Bend
  verifies no signature.
- Who supplies it: when an approval travels between hosts or out of band,
  verifying its cryptographic signature, and binding the signer to the
  `from` the host attaches, is a host input. This change does not implement
  it.
- If it is wrong: a forged or altered approval presented by a host that
  attaches the forged issuer as `from` is accepted as genuine.

### Rollback

The issuer state carries the live stamp, the revocation flags, the consumed
markers on approvals, and `seen`.

- What Bend does with it: revocation flags and `seen` serials are never
  cleared, and consumed approvals stay consumed through revocation. Bend
  cannot see a state the host has replaced with an older copy.
- Who supplies it: the host must never restore an old epoch, and never drop
  `seen`, the revocation flags or the consumed markers, for example when
  recovering from a backup or a crash.
- If it is wrong: restoring an older state revives revoked grants, makes
  consumed approvals usable for a second registration, and readmits replayed
  serials. Pure revision checks are not rollback-resistant persistence
  (AB-006).

## Remaining host preconditions

A real host must meet every precondition below before the issuer's decisions
mean what the requirements say. None is met today: no host runs issuance, and
each is a host obligation, not something the Bend model can supply. Where a
requirement applies, its words are quoted. The sections above say what Bend
does with each input and what goes wrong if it is supplied wrongly.

1. **Transport identity verification.** The `from: Principal` attached to
   `submit_source`, `submit_write`, `revoke` and `derive`, and the principal
   passed to `reads`, `writes` and `registry`, must be the transport-verified
   identity of the caller (a Genode route subject, Linux peer credentials, a
   Windows token SID), never a value the caller chose. GI-001 requires
   "an authenticated authority for that source's read domain"; GI-004
   requires binding a capability to "the authenticated subject". The
   principal of each use must also be the identity presented as
   `F.Caller.subject`. Bearer possession of a native capability, descriptor
   or handle does not establish it.
2. **Signature verification for approvals carried off-host.** An approval
   that travels between hosts or out of band must have its cryptographic
   signature verified, and the signer bound to the `from` the host attaches,
   before submission. Bend verifies no signature; GI-001's "authenticated
   authority" is otherwise only as strong as the host that attaches `from`.
3. **Durable and serialized state.** Each accepted state must be installed
   atomically at `expected_revision`, transitions serialized against the
   current authoritative revision, and the result preserved across crashes.
   GI-005: "atomically register a grant only while the snapshot and approvals
   used for its validation remain current". AB-006: "serialize accepted model
   transitions against current authoritative revisions and preserve their
   replay state across crashes". Recovery must never restore an old epoch or
   drop `seen`, the revocation flags or the consumed markers (rollback,
   above). The proposed durable-publication change is where recoverable
   persistence would come from; none exists for issuance.
4. **Monitor-supplied directory, placements, live stamp, clock and tokens.**
   The authority directory and placements must come from the monitor's
   authoritative record; the live stamp and `now` from its epoch state and a
   trusted, monotone clock (`now` never decreases across the transitions and
   uses of one issuer state, because a backwards `now` revives expired grants
   and approvals), the same values the host passes as `T.Context.live`,
   `T.Context.now` and `F.Live` for that use; and every `token` from a
   cryptographically secure source, never from the caller. GI-003's "epoch
   snapshot" and GI-007's "at or after their expiry boundary" are only as
   good as these inputs.
5. **Per-use projection rebuilding.** For every use the host must rebuild
   `T.Context.reads`/`writes` and the `F.Registry` from the current installed
   issuer state for that use's authenticated principal, and must not cache,
   reuse, merge or accept caller-supplied projections. GI-008: "A registered
   capability SHALL remain subject to current paired-grant and policy checks
   whenever it is used." The issuer's placements and the context's source
   and destination policy domains must come from the same monitor record.
6. **Enablement and capability negotiation in a host adapter.** No DataOS
   facade entry or host adapter exposes issuance. The design requires
   "explicit capability negotiation" and says to "Keep the new path disabled
   until its acceptance tests and host preconditions hold"; rollback "never
   restores old authority epochs or forgets consumed receipts". A host
   adapter must negotiate the issuance capability and record versions
   explicitly, reject unknown versions, and stay disabled until native
   acceptance tests show preconditions 1 to 5 on that host. Until then
   `DataOS.commit_from_capability` stays the only host-facing commit.
7. **Host-corpus rebaseline.** The host corpus gates are bound to recorded
   evidence for the tree before issuance and still expect 782 checks:
   `hosts/unikraft/scripts/check-corpus.sh` (`WRIT_CORPUS_PASS` default 782,
   with its Linux reference capture
   `verification/unikernel-corpus-linux-reference.txt`) and
   `scripts/genode/writ_bend_tests/writ_bend_tests.run`
   (`expected_pass 782`). The library suite on this tree has 1014 checks on
   the JavaScript and native CPU backends. Those images must be rebuilt and
   their gates and captures re-recorded against the new tree by a later
   lane before any host run counts as evidence for it. The current-tree
   count gates (`utils/nix/writ.nix`, `WRIT_CORE_EXPECTED` in the Genode
   workflow, the `build-and-run.sh` message) and the README and
   VERIFICATION counts are re-pinned once by the controller after the
   parallel lanes merge.

## What this document does not claim

It does not claim that any host meets these inputs, that issuance is wired
into the DataOS facade, or that approvals are cryptographically verified.

Open in the model: there is no grant-level revocation. Only approvals can be
revoked (`revoke`). A derived grant, or the middle of a chain, can be
withdrawn only by revoking the root's approval, and that withdraws the whole
chain. Neither the subject nor an authority can withdraw one child alone. The
Bend tests and proofs show what the model does with the inputs it is given.
Host qualification needs separate native evidence for each claimed profile.
