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
- Traceability: [openspec/traceability/grant-issuance.md](../openspec/traceability/grant-issuance.md). Task 6 of this change creates it.
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
| `register(state, expected_revision, request, now, token)` | Issues one grant backed by one exact, current approval pair (GI-002 to GI-004). |
| `revoke(state, expected_revision, from, approval_id)` | Withdraws a stored approval on behalf of its issuer (GI-005). |
| `derive(state, expected_revision, from, parent_id, child, now, token)` | Issues an attenuated grant to the parent's own subject (GI-006, GI-007). |
| `current(state, grant, now)` | Whether a grant is usable now, re-derived from the state (GI-005). |
| `valid(state)` | Structural validity only. It authenticates nothing. |
| `reads(state, now)`, `writes(state, now)`, `registry(state, now)` | Projections of the current grants into `T.Reads`, `T.Writes` and `F.Registry` (GI-008). |
| `Change.accepted`, `Change.state`, `Change.reason`, `Change.issued`, and the state accessors | Read a transition's outcome. |

## Trusted identity inputs

Bend authenticates nothing by itself. It compares what it is given. Each input
below is taken as given. The other parameters are untrusted claims that Bend
checks against these inputs: the approval records, the `Request` (scope, cited
approval ids, rights, lifetime), the `Derivation`, the `parent_id` and
`approval_id`, and the `grant` passed to `current`. For each one, this section says what Bend does with
it, who must supply it on a real host, and what happens if the host supplies
it wrongly.

### The authenticated principal (`from`)

`submit_source`, `submit_write`, `revoke` and `derive` each take
`from: Principal`, a separate parameter that the host attaches to the
transition. It is not a record field. No approval, request or derivation can
assert its own authentication.

- What Bend does with it: an approval is accepted only when its claimed
  `issuer` equals `from` (otherwise `Unauthenticated`) and the directory names
  `from` as the authority for the approval's domain (otherwise
  `NotAuthority`). A revocation must come from the approval's recorded issuer,
  who must still be that authority. A derivation must come from the parent
  grant's subject (otherwise `SubjectMismatch`). `register` takes no `from`:
  its only authority is the cited approvals, which were each bound to an
  authenticated submitter.
- Who supplies it: the host's transport identity verification. Example
  sources are the Genode route subject (`HostBinding.Route.subject`, the
  identity the parent prepends to the session label), Linux peer credentials
  on the broker socket, and the Windows token SID of the calling process. A
  native capability, descriptor or handle is not a portable credential, and
  bearer possession alone does not establish the original caller's identity
  (see `docs/PLATFORMS.md`).
- If it is wrong: anyone the host misidentifies as a directory authority can
  submit and revoke approvals in that authority's domains, and anyone
  misidentified as a grant's subject can derive from it. Bend cannot detect
  this, because the parameter is the definition of who is asking.

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
  trusted clock. The `now` passed to the projections must be the same time
  the host passes in `T.Context.now` and `F.Live` for that use.
- If they are wrong: a stale live stamp keeps grants from a retired epoch
  usable, and a clock that runs slow or is caller-chosen extends every
  lifetime. A projection built at an earlier `now` than the use-time check
  can include a grant that has already expired.

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

`reads(state, now)`, `writes(state, now)` and `registry(state, now)` return
the grant lists `Transfer.admit` consumes (`T.Context.reads`/`writes`) and
the registry `Frontend` and the DataOS facade consume (`F.Registry`).

- What Bend does with them: each projection walks the grant list and keeps
  only grants that are `current` at `now`, so a revoked, expired or otherwise
  withdrawn grant contributes nothing to any of the three. Each read grant
  is placed in the source's read domain, and every entry is bound to the
  grant's own scope and lifetime. `T.admit` and `F.checked_plan` then run
  unchanged on the result. Issuance adds no shortcut around them.
- Who supplies them: the host must rebuild all three from the current,
  installed issuer state for every use. It must not cache one, reuse an
  earlier one, or let the caller supply one.
- If it is wrong: a cached projection keeps a revoked grant usable. The
  use-time checks see only the lists they are given, so they cannot tell a
  stale projection from a current one. Merging in grants from another
  source puts authority beside the issuer's that the issuer never checked.

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

## What this document does not claim

It does not claim that any host meets these inputs, that issuance is wired
into the DataOS facade, or that approvals are cryptographically verified. The
Bend tests and proofs show what the model does with the inputs it is given.
Host qualification needs separate native evidence for each claimed profile.
