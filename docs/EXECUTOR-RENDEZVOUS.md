# Executor rendezvous: selection rule, limits and trusted inputs

## A worked example

Providers A (principal 201) and B (principal 202) offer the same code for
the negotiated plan. B quotes 30 and A quotes 40. Object 10's read authority
has approved provider A only. `select` therefore picks A: B is excluded with
`MissingApproval`, whatever its price (ER-002). The check is "ER-002 cheapest
offer violates an origin: B quotes 30 without object 10's approval, A quotes
40 with it; A is selected and ineligibility(B) is MissingApproval" in
`RendezvousTests.bend`.

A dispatch that names B's offer or B's worker session is denied
`NotSelected` (ER-001): "ER-001 dispatch to an unselected provider: A's
offer with B's worker session 7, B's offer {202, 5} with B's or A's worker
session, or A's unknown offer {201, 9}, denied NotSelected".

Then the issuer revokes object 10's source approval behind A's grant. A
dispatch is now denied `Revoked`. The projected `N.Context` carries no
approval, so `N.start` denies on it ("ER-007 selection racing revocation:
once 101 revokes the source approval behind A's grant 3, dispatch is denied
Revoked, the projection carries no approvals so N.start is rejected on it (it
advances on the earlier one), and the dispatched selection's
provider_registry is empty"). If the revocation comes after dispatch, the
unchanged `Backplane.commit` and `DataOS.commit_from_capability` both
reject, and no reservation is spent ("integration A's grant 3 revoked after
dispatch: the projected approvals are empty, N.owners denies, Backplane and
the facade reject and spend no reservation").

The trial and dispatch checks use a second set of fixtures, in which A
quotes 38 and B quotes 41. Every fixture in `RendezvousTests.bend` is a
SYNTHETIC AUTHORITY RECORD and SYNTHETIC MONITOR STATE, not an
authenticated issuer or a host.

## The current gap

The rendezvous model is implemented in Bend (`Rendezvous.bend`):

- provider-scoped offers backed by registered Issuance grants;
- origin approvals authenticated against the Issuance directory;
- eligibility before ranking, and deterministic selection;
- trial evidence bound to the selection;
- one dispatch per selection to the selected provider's worker session;
- the projections into the existing Negotiation context and Frontend
  registry.

Nothing outside the model is implemented. No host adapter calls these entry
points. No transport delivers authenticated offers, approvals or evidence.
No durable store holds the rendezvous state. No trial compute is metered or
funded: `add-metered-sample-execution` is not implemented. No DataOS facade
entry exposes the rendezvous. By plan ruling, the new path stays disabled
until its acceptance tests and host preconditions hold.

Every trusted input listed below is therefore a precondition that a future
host must meet. None of them is evidence that a host meets it today.

Contracts and evidence:

- Current contract: [executor-rendezvous spec](../openspec/specs/executor-rendezvous/spec.md) (ER-001 to ER-008), with the archived [design](../openspec/changes/archive/2026-11-05-add-executor-rendezvous/design.md) and [tasks](../openspec/changes/archive/2026-11-05-add-executor-rendezvous/tasks.md).
- Traceability: [executor-rendezvous traceability](../openspec/traceability/executor-rendezvous.md), one row per requirement with its named tests and reviewed-only gaps (task 2.1).
- Evidence: [verification/executor-rendezvous.txt](../verification/executor-rendezvous.txt), the recorded commands, counts, laws and mutation totals of this lane's tree.
- Grant authority: [docs/GRANT-ISSUANCE.md](GRANT-ISSUANCE.md). A provider's authority is a registered Issuance grant, and every Issuance trusted input is also a rendezvous input.
- Dependent proposal: [add-locality-aware-execution](../openspec/changes/add-locality-aware-execution/proposal.md) (see "What the locality proposal may extend").

## The selection rule

### One rendezvous per request

`open(index, request, constraint)` fixes the negotiation request and the
execution constraint for the life of the rendezvous. The request carries the plan
(code identity, invocation, ordered manifest, destination and stamp), the
reader, the reader's quote ceiling and the units. The constraint is the
monitor's list of configured worker profile ids that the reader admits.

A change to the operation identity, manifest, destination or billing terms
is a new rendezvous. That rendezvous starts with no offers, approvals,
evidence or dispatches, so nothing follows a changed execution (ER-007).
Nothing in the module constructs or edits a `T.Plan`. Every offer, grant,
approval and evidence must name exactly the request's plan.

`open` also takes the monitor's index of the requests it has already opened
a rendezvous for (`Opened`), and denies `AlreadyOpen`, returning the index
unchanged, for a request the index holds (`N.Request.equal`). On acceptance
it returns the fresh state and the index with the request added, and the
host installs both. This closes a gap the final review found: a Negotiation
sample names no provider, so a second rendezvous for the same request let
provider B attach A's challenge 41 and sample 51 on the shared session as
its own trial, dispatch and commit. "F1 scenario one rendezvous per
request: R.open of the two-source request on the empty index is accepted
with exactly sc_opened()'s state and an index holding that request, and a
second R.open of the same request on that index is denied AlreadyOpen with
the index unchanged, so the second rendezvous of the final review's
scenario (b), in which B counted A's challenge 41 and sample 51 as its own,
cannot be opened". The index is a trusted input: Bend cannot see a state
the host builds without `open` (`fresh` is an exported helper) or an index
it discards, so keeping the index durably is precondition 14.

### Offers and their identity

An offer is immutable:
`Offer{version, id: OfferId{provider, serial}, provider, grant, plan, profile, quote, valid_until}`.

- **Provider-scoped identity (ruling).** The `provider` part of the
  `OfferId` must equal the authenticated `from` at submission. In a global
  namespace, any principal could create a conflicting record under a
  competitor's identity and so deny the whole rendezvous (ER-008) at will.
- **Claims, not authority.** `provider`, `grant` and the identity's provider
  part are claims. The only authority is a registered Issuance grant that
  meets all of the following:
  - it is `I.current` in the supplied issuer state at `now`;
  - its subject is the provider;
  - its plan is `T.Plan.equal` to the request plan;
  - its rights cover `provider_rights()` = 5 (read plus execute). A provider
    never publishes; publication stays the reader's
    `DataOS.commit_from_capability`.
- **Serials are never reused.** Once a `(provider, serial)` pair is
  accepted, it stays in `seen` for ever.
- **Zero quote (ruling).** A zero quote is denied `OverBudget`, the closed
  set's one billing reason.
- **Submission is not eligibility.** `submit_offer` checks the offer's
  record, identity, plan, backing grant, lifetime and uniqueness. The quote
  ceiling, the constraint and the origin approvals are eligibility
  conditions. They are re-checked at every selection and every use, so an
  offer outside them is stored but never selectable.

### Origin approvals

`OriginApproval{version, serial, issuer, origin, provider, profile, plan, valid_until}`
covers one origin, one provider, one profile and one exact plan.

- **Checked against the issuance directory (ruling).** `from` must equal
  the issuer claim. It must be `I.is_read_authority` for the one read
  domain in which the issuer's placements put the origin. An origin that is
  not placed, or is placed twice, cannot be approved.
- **Unneeded origins are refused at submission (ruling).** An approval for
  an origin that `T.required_origins(request plan, transfer)` does not list
  is denied `ScopeMismatch`. A `Missing` lookup is also denied.
- **Bound to the issuer's live stamp (ruling).** An approval submitted while
  the issuer's live stamp differs from the plan's is denied `StaleEpoch`.
  `origin_approved` requires the live stamp at every use, so an epoch
  advance withdraws every approval without editing it.
- **Authority re-read at every use.** A directory or placement change
  withdraws an approval without editing it.
- **Withdrawal.** Only the recorded issuer, still that authority, may
  withdraw an approval. Withdrawal sets a flag that is never cleared, and
  the serial stays seen. A second withdrawal is denied `Revoked` (ruling).
- **An inert approval can count again.** Because authority is re-read, not
  recorded, an approval made inert by a directory change counts again if
  the directory later names its issuer again: it is the issuer's own
  unwithdrawn approval under its own authority, with no new decision. The
  new authority cannot withdraw it; only the recorded issuer can. Likewise
  a fresh approval after a withdrawal makes the same selection
  dispatchable again, which is a new authority decision.

"Every contributing origin" is `T.required_origins(plan, transfer)`, the same
lookup `N.owners` uses, and it includes inherited origins.

### Eligibility gates, in order

An offer is eligible only when it passes every gate of `eligibility_gates`.
The gates are re-read from the state and snapshot supplied at the call. The
denial reason is the first failing gate of the same list, so acceptance and
reason cannot drift apart.

| # | Gate | Reason on failure |
| --- | --- | --- |
| 1 | record version is `record_version()` = 1 | `UnknownVersion` |
| 2 | the identity's provider part equals the provider claim | `Unauthenticated` |
| 3 | the offer plan equals the request plan | `ScopeMismatch` |
| 4 | the backing grant exists, and its subject is the provider | `NoGrant` |
| 5 | the grant's plan equals the request plan | `ScopeMismatch` |
| 6 | the grant is `I.current` | `Expired` if `now` is at or past its end, `StaleEpoch` if its stamp is not live, otherwise `Revoked` |
| 7 | the grant's rights cover `provider_rights()` | `RightsNotHeld` |
| 8 | `now < valid_until` for the offer | `Expired` |
| 9 | the offer does not outlast its grant | `Expired` |
| 10 | the quote is positive and at most the reader's ceiling | `OverBudget` |
| 11 | the profile is in the execution constraint | `Constraint` |
| 12 | every required origin has an unwithdrawn, unexpired approval for this provider, profile and plan, from its current authority, at the live stamp | `MissingApproval` |

`select` ranks only `eligible_offers`, so no price overrides a denial. A
grant revoked between submission and selection drops its offer, wherever the
offer sits in the list. The law `rendezvous_ineligible_offer_dropped` states
that an ineligible offer contributes nothing to `eligible_offers`. `select`
also requires a Negotiation session at `CandidateFixed` that carries exactly
the rendezvous request, and requires that no selection exists yet.

### Ranking profile 1

`before(a, b)` is the strict lexicographic order on (quote, provider id,
serial): the lowest approved total quote first, then the canonical provider
identity, then the canonical offer identity (ER-003). Distinct identities
are always ordered. On an unambiguous offer list, the first-ranked eligible
offer therefore does not depend on list order. The law
`offer_order_irreflexive` states that the order is strict on its diagonal.
Every selection records `ranking_profile()` = 1.

The selection stores:

- the complete offer record;
- the request;
- the issuer's live stamp;
- the time;
- the ranking profile.

It grants nothing by itself. `selection_current` re-derives its currency on
every call. The identical record must still be stored and unambiguous, the
request must be unchanged, the stamp must be the live stamp, and every
eligibility gate must pass again.

### Conflicts and withdrawal

- **Conflicting records.** `select` refuses a list in which one `OfferId`
  carries two contents (ER-008, `ConflictingOffer`). Only the identity's own
  provider can resolve the conflict: `withdraw_offer` removes every record
  under the id and keeps the serial seen, so a replacement needs a fresh
  serial. Withdrawing an id with no record is denied `Revoked` (ruling).
- **No re-ranking.** A cheaper newcomer never displaces a current selection
  (ER-007).
- **Retirement.** Only `abandon` (a monitor action) or the selected offer's
  withdrawal retires a selection. Its id becomes `retired` and is never
  restored, and the next selection gets a new id.
- **After abandonment.** A new selection's provider needs its own origin
  approvals. The old selection's evidence and dispatch record do not count
  for it.

## Trial binding and dispatch

### Trial evidence

`submit_evidence` accepts evidence only when all of the following hold:

- it comes from the authenticated provider that the current selection names.
  The outer match is pinned by the law
  `rendezvous_wrong_provider_evidence_rejects`;
- it is for the selected offer;
- it comes from a Negotiation session at `Challenged` that carries exactly
  the rendezvous request;
- its challenge was issued strictly after the selection (ER-004);
- it names a passed sample that answers that challenge, with the selected
  plan's code (ER-005).

Evidence is accepted once per selection (ruling). Evidence that expires
before use is not replaced under the same selection. The monitor abandons
the selection and selects again, and the new selection id needs fresh
evidence. This fails closed and has a liveness cost.

`negotiation_context` rebuilds Negotiation's challenge, sample and approval
lists for the current selection only:

- **challenges:** those for the selected plan, issued strictly after the
  selection;
- **samples:** those named by evidence stored under the current selection
  id, for the selected offer and provider;
- **approvals:** one per required origin, valid until the earliest of that
  origin's approval, the offer and the grant.

All three lists are empty unless the selection is current. The transfer
context and the budgets pass through unchanged. The unchanged `N.challenge`,
`N.sample`, `N.approve`, `N.reserve` and `N.start` therefore deny once a
selection is abandoned, withdrawn, revoked, at a stale epoch or missing an
approval.

### `session_follows_selection` and the `WrongTrial` gate

The projection does not bind a Negotiation session to a selection. A
session that reached `Sampled` under a retired selection would still pass
`N.approve`, `N.reserve` and `N.start` on a later selection's projection,
because those stages never re-check the challenge or the sample.
`session_follows_selection` (ruling) closes that gap at dispatch, with the
reason `WrongTrial`. It requires that the session's challenge is the one in
evidence stored under the current selection's id that names the selected
offer and its provider claim (the offer and provider comparisons were added
in the final fix round, F4, matching `evidence_for`): "ER-005
session_follows_selection binds the evidence's selection, offer and
provider: on monitor-installed states whose only evidence under selection 3
names challenge 21 for B's offer {202, 5}, or for A's offer under B's
provider claim, A's session challenged with 21 does not follow selection 3;
on A's own stored evidence it does; and once A's same offer is reselected
as selection 4, retired selection 3's evidence does not make it follow".

### Dispatch

`dispatch` checks its target outermost; the law
`rendezvous_unselected_dispatch_rejects` pins this match. The target is
correct only when all of the following hold:

- the offer is the stored selection's offer;
- exactly one host session has that id;
- that session's authenticated caller is the selected provider;
- the session is non-delegable;
- it is bound as a worker under exactly the selected offer's profile.

A failure is `NotSelected`, or `WrongProfile` for the binding. Then come, in
order:

1. the rendezvous revision (`StaleRevision`);
2. **the host revision gate (ruling):** the host state is at
   `expected_host_revision` and `HP.valid` (`HP.current`). A session table
   carried across a restart, a binding to an unconfigured profile, or a host
   at another revision is denied `StaleRevision`;
3. a Running, live Negotiation session at `expected_session` (`WrongStage`)
   carrying exactly the rendezvous request (`ScopeMismatch`);
4. the selection's currency, with every eligibility gate re-run and its own
   reason (`Revoked`, `Expired`, `StaleEpoch`, `MissingApproval`, ...);
5. the worker's caller token is the backing grant's token (`NotSelected`);
6. stored evidence for this selection (`MissingEvidence`);
7. the session's trial is that evidence's (`WrongTrial`);
8. one dispatch per selection (`Replay`).

The record `Dispatch{selection, incarnation, worker_session}` names the host
incarnation, because session ids restart from 1 after a restart. Reporting
`NotSelected` or `WrongProfile` before `StaleRevision` was accepted on
review: the target gates read only the caller's own rendezvous and host
inputs.

`provider_registry` is the Frontend registry from which the monitor opens
the dispatched worker's input. It is Issuance's registry for the selected
provider, filtered to the selected grant's token. It is empty unless the
selection is current and dispatched at that call. Binding the worker's input
to that handle (`HostPrimitives.issue`) is left to the monitor (ruling).

## The final commit still decides

The rendezvous decides who may run the plan. It never widens what the commit
path admits. The `integration` section of `RendezvousTests.bend` drives the
unchanged `Backplane.commit` and `DataOS.commit_from_capability`. Their
Backplane context carries `commit_context`, rebuilt for the commit. It is
`negotiation_context` further gated on four things at that call: the host
state current (`HP.current` at `expected_host_revision`, as at dispatch); a dispatch
of the current selection recorded as `Dispatch{selection, incarnation,
worker_session}` for the worker session the host reports the output from, at
the host's current incarnation; the committing Negotiation session following
that selection's trial (`session_follows_selection`); and the selection
still current. Otherwise its approval, challenge and sample lists are empty,
`N.owners` denies, and the commit keeps the Running session and the ledger.
So no commit rests on a host state that is not current, an undispatched
selection, a selection with no evidence, a session whose trial ran under a retired selection, another
worker session or a session id of another incarnation (the `integration`
and `scenarios` checks "before dispatch", "with a retired trial", "from
another worker", "under a reselected offer"). What still rests on the host
is that the worker it reports is the one that ran and produced the
candidate: Bend checks the reported worker session against the dispatch
record, not the output's origin. The host also passes the same Negotiation
session to `commit_context` and to the commit; Bend cannot tie them, because
the commit takes its session separately, so `session_follows_selection`
protects only the session `commit_context` is given. `negotiation_context` stays the projection
for `N.challenge` to `N.start` and `dispatch`, and the host must never pass
it to a commit. Each denial below is the commit path's own check. Each
denied commit returns the Running session and the ledger with its hold, so
no reservation is spent.

| Check (name prefix `integration`) | What denies |
| --- | --- |
| "a dispatched, sampled execution commits through Backplane.commit on the projected context ..." | nothing: the positive control (Committed, the write intent keeps plan, origins and label) |
| "the same execution commits through DataOS.commit_from_capability with reader 7's execute descriptor" | nothing: the facade's positive control |
| "with the selection current and dispatched, the reader's transfer write grant revoked ..." | `T.admit` (`Write`) |
| "A's grant 3 revoked after dispatch ..." | the projected approvals are empty, so `N.owners` denies |
| "the issuer's live stamp advanced to epoch 5 after dispatch ..." | the projection is empty, so `N.owners` denies |
| "with the selection current and dispatched, an output carrying control label 3 does not fit the destination ..." | Backplane's destination fit on the combined output policy |
| "with the selection current and dispatched, the reader's budget funds quote 41 against the request's 42 ..." | `N.budget_live` |
| "before dispatch, commit_context of A's evidenced selection 3 carries no approvals ..." | `commit_context` is empty without a recorded dispatch, so `N.owners` denies (Backplane and facade) |
| "commit_context reads the whole dispatch list ..." | `commit_context` is empty for a worker session the dispatch record does not name |
| "a sample is not a commit: before A's evidence is stored ..." | without stored evidence the passing sample is not projected, so `N.sample` denies; a Challenged session cannot approve; a Sampled session cannot commit |
| "once object 10 withdraws A's approval, ..." | `N.approve` and `N.start` (owners) on the projection |

The task 1.5 mutation table,
`docs/superpowers/records/2026-11-05-executor-rendezvous/task-6-mutants.md`,
shows which commit-path gate each check depends on.

## Limits

- **Samples can be gamed, and provider identity is not execution
  integrity.** A passing sample shows that one challenge was answered. It
  does not show that the dispatched worker runs the same code on the real
  inputs. The rendezvous binds who is authorized to run. What actually runs
  is the host's confinement and attestation problem.
- **Selection grants no declassification.** The module produces no
  `WriteIntent`, calls neither Backplane nor the facade, and adds no release
  route. Labels, flows and the destination fit are decided only by the
  unchanged commit path ("The final commit still decides").
- **Confinement and independent final validation are still required.** The
  worker must be confined to its admitted inputs and effects, and the output
  must pass `Backplane.commit`'s original-graph verification, which the
  rendezvous neither performs nor weakens.
- **Origins approve providers, not prices.** An origin approval names a
  provider, profile and plan. It says nothing about the quote. Only the
  reader's ceiling bounds price.
- **The reader quote is a ceiling and is not settled here.** Plan ruling: an
  eligible offer's quote is at most the request's quote, and the selection
  records the agreed quote. The Negotiation budget and the ledger hold are
  still matched to the request's quote and units, and `Backplane.commit`
  spends that hold. Nothing in the model moves the selected quote into the
  ledger. Whether the quote should be exact or a ceiling is an open question
  for Spaceghost (q18). The answer shapes how the locality change adds
  movement costs. No billing semantics are settled here.
- **`add-metered-sample-execution` is unmet.** Trial compute is unmetered
  and unfunded, exactly as in Negotiation today ("No sample-compute hold
  exists here"). This is a recorded gap, not a blocker for this change.

## Trusted inputs

Bend authenticates nothing by itself. It compares what it is given. The
untrusted claims are checked against the inputs below. They are the offer,
approval and evidence records, the `OfferId` passed to `dispatch` and
`withdraw_offer`, the approval id passed to `withdraw_approval`, and the
`worker_session` id. For each trusted input, this section says what Bend
does with it and what goes wrong if the host supplies it wrongly.

### The authenticated principal (`from`)

`submit_offer`, `submit_approval`, `withdraw_approval`, `withdraw_offer` and
`submit_evidence` take `from: I.Principal`. It is a separate parameter
attached by the host's transport identity verification, never a record
field. It is the same namespace as `I.Principal` in Issuance and
`F.Caller.subject` in Frontend and HostIdentity.

- **What Bend does with it:**
  - An offer's identity and provider claim must equal it.
  - An approval's issuer claim must equal it, and it must be the directory
    authority for the origin.
  - Evidence must come from the selected provider.
  - Withdrawal must come from the record's own provider or issuer.
- **If it is wrong:** anyone misidentified as a provider can offer, and
  provide evidence, under that provider's grant. Anyone misidentified as an
  origin authority can approve or withdraw providers for that origin. Bend
  cannot detect this, because the parameter defines who is asking. A native
  capability, descriptor or handle is not a portable credential, and bearer
  possession alone does not establish the caller's identity (see
  `docs/PLATFORMS.md`).

### The current issuer state (`Snapshot.issuer`)

The Issuance state: grants, approvals, directory, placements and live stamp.
Grant currency (revocation, expiry, epoch, directory, placements, ancestry)
is re-derived from it with `I.current` at every call. The approval authority
and the selection's stamp are checked against it.

- **Grants installed by the monitor (gap).** Provider grants are whatever
  the issuer state holds. The rendezvous trusts that the monitor installed
  that state through Issuance's entry points, and every Issuance trusted
  input and host precondition applies ([GRANT-ISSUANCE.md](GRANT-ISSUANCE.md)).
- **If it is wrong:** a stale issuer state keeps a revoked grant, a
  withdrawn approval or a retired epoch usable. A forged one confers provider
  authority that no authority approved. Bend cannot detect either.

### The transfer context (`Snapshot.transfer`, and the one inside `n_context`)

`Snapshot.transfer` is the current `T.Context`. It is used for
`T.required_origins`, which lists every contributing origin, inherited ones
included. The transfer context inside `n_context` passes through the
projection unchanged to `N.*` and to Backplane. There `T.admit` judges the
reader's read, write and payment grants.

- **If it is wrong:** a context that omits an origin drops that origin's
  approval requirement, so a provider can be eligible without it. A context
  whose grants are stale admits a commit the current grants deny. The two
  contexts must be the same current monitor record, built from the current
  issuer state for this use. Bend does not compare them.

### Monitor time (`Snapshot.now`, and `now` in `n_context`)

Every expiry is exclusive (`now < valid_until`).

- **What Bend does with it:** the challenge window (issued strictly after
  the selection) is sound only if monitor time is non-decreasing across
  selections, and challenge ids are never reused across selections.
- **If it is wrong:** a slow or caller-chosen clock extends every offer,
  grant and approval. A clock that goes backwards revives expired ones, and
  can let an earlier selection's challenge pass the window. The time must be
  the same value the host passes as `T.Context.now` and `F.Live` for that
  use.

### The negotiation request, the execution constraint and the index (`open`)

The request must be the one Negotiation pinned, and the constraint must be
the monitor's configured worker profiles that the reader admits. The index
must be the monitor's durable index of every request it has opened a
rendezvous for, and the host installs the index `open` returns.

- **If the index is wrong:** an index that lost an entry, or a state built
  without `open`, lets a second rendezvous exist for one request, in which
  another provider can count the first provider's challenge and sample on
  the shared session as its own trial (precondition 14). Bend cannot
  detect it.

- **If either is wrong:** a wrong request makes the rendezvous select for a
  plan the reader never negotiated. The session gates (`ScopeMismatch`)
  then deny the reader's real session, but only if the session itself is
  genuine. A constraint that lists an unadmitted profile makes offers on it
  eligible.

### The Negotiation session and context (`session`, `expected_session`, `n_context`)

`select`, `submit_evidence` and `dispatch` take the monitor's Negotiation
session and its unprojected `N.Context`. In that context, the challenge and
sample records are the monitor's receipts. Evidence only names them.

- **If they are wrong:** a fabricated sample record lets evidence pass. A
  fabricated `Running` session reaches dispatch. The final commit re-checks
  owners, budget, hold and admission, but it reads the same monitor-supplied
  values.

### The configured profiles and the HostPrimitives state (`host`, `expected_host_revision`)

`dispatch` and `commit_context` take the monitor's current HostPrimitives
state, at each dispatch and at each commit, never one from before a
restart. Its HostIdentity
session table sets each session's caller only through `bind_session`, from
authenticated native evidence. Its worker bindings name the configured
profile that `open_session` bound each worker under. Dispatch and
`commit_context` both require `HP.current` at `expected_host_revision`
(final review, F2): "integration commit_context requires the current host
state: after HostPublication.restart moves the host to incarnation 58 at a
new revision, commit_context on the pre-restart host() named at that
revision carries no approvals and Backplane.commit rejects and spends no
reservation (the final review's scenario e5), while host() named at its own
revision commits". Bend checks the state against the revision it is told
is current; that revision is the monitor's.

- **If it is wrong:** a misbound session lets another principal run as the
  selected provider. A binding to the wrong profile runs the provider
  outside the reader's constraint. A table that is valid and current, but
  whose native-session mapping the adapter kept across a restart, is
  HostIdentity's restart obligation. Bend cannot detect it.

### Rebuild per use: `negotiation_context`, `commit_context` and `provider_registry`

The host must rebuild all three projections from the current rendezvous,
issuer and transfer states for every use. That means `negotiation_context`
for every `N.*` call and dispatch, `commit_context` (never
`negotiation_context`) for every `Backplane.commit` or facade commit, and
`provider_registry` for every Frontend mount, open or use.
It must never cache them, reuse them across uses, or accept them from a
caller. It must open the worker's input only from `provider_registry`, never
from the raw issuer registry.

- **If it does not:** a cached projection keeps the authority of a revoked
  grant, a withdrawn approval, an abandoned selection or a past epoch. Bend
  cannot detect this. An identity entry the monitor already issued is not
  retired by the rendezvous. HostPublication's revocation family does that.

### Atomic install at `expected_revision`

Every transition takes `expected_revision`, the revision the caller
validated against. Each one advances the revision exactly once on
acceptance, and returns the supplied state unchanged on denial.

- **What the host must do:** install an accepted state atomically at that
  revision, serialize transitions against the current authoritative
  revision, and preserve `seen`, `retired`, the withdrawal flags, the
  evidence and the dispatch records across crashes.
- **If it does not:** two accepted transitions from one revision (for
  example a selection ranked before a withdrawal) both take effect, and a
  rollback that drops `seen` or a dispatch record re-admits a replay.

## Public entry points

All of them are in `Rendezvous.bend`. Every other definition there is an
exported implementation helper, and calling one does not perform a
transition's checks. This includes `selection_current`,
`selected_provider_is`, `session_follows_selection`, `fresh` and
`dispatch_target_selected`.

| Entry point | What it does |
| --- | --- |
| `open(index, request, constraint)` | The rendezvous for one negotiation request and execution constraint, against the monitor's index of opened requests: denied `AlreadyOpen` for a request the index holds; on acceptance, the state and the extended index (`Opening.accepted`, `Opening.state`, `Opening.index`, `Opening.reason`). |
| `submit_offer(state, expected_revision, from, offer, snapshot)` | Stores one immutable, grant-backed offer under the provider's own identity (ER-001, ER-008). |
| `submit_approval(state, expected_revision, from, approval, snapshot)` | Stores an origin authority's approval of one provider, profile and plan (ER-006). |
| `withdraw_approval(state, expected_revision, from, approval_id, snapshot)` | The issuer withdraws its approval. |
| `select(state, expected_revision, session, expected_session, n_context, snapshot)` | Ranks the eligible offers and records the selection (ER-002, ER-003, ER-008). |
| `abandon(state, expected_revision)` | Monitor action: retires the current selection. |
| `withdraw_offer(state, expected_revision, from, id)` | The provider withdraws every record under its own offer id (ER-008 resolution). |
| `submit_evidence(state, expected_revision, from, evidence, session, n_context, snapshot)` | Binds one trial to the current selection (ER-004, ER-005). |
| `dispatch(state, expected_revision, offer, host, expected_host_revision, worker_session, session, expected_session, n_context, snapshot)` | Records the one dispatch of the current selection to the selected provider's worker session (ER-001, ER-006, ER-007). |
| `negotiation_context(state, n_context, snapshot)` | The projected Negotiation context for `N.challenge` to `N.start` and `dispatch`, rebuilt for every use. |
| `commit_context(state, session, host, expected_host_revision, worker_session, n_context, snapshot)` | The Negotiation context for `Backplane.commit` and the facade commit: empty unless `host` is `HP.current` at `expected_host_revision` and the current selection is dispatched to `worker_session` at the host's incarnation and `session` follows its trial. Rebuilt for every commit. |
| `provider_registry(state, snapshot)` | The dispatched provider's Frontend registry, rebuilt for every use. |
| `ineligibility(offer, state, snapshot)` | Read-only diagnostic: the first failing eligibility gate, or none. |
| `valid(state)` | Structural validity only. It authenticates nothing. |
| `Change.accepted`, `Change.state`, `Change.reason`, `Change.issued`, and the state, snapshot and record accessors | Read a transition's outcome. |

## What the locality proposal may extend

[add-locality-aware-execution](../openspec/changes/add-locality-aware-execution/proposal.md)
depends on this change. It may do the following:

- **Append eligibility gates.** It may add a separately versioned placement
  profile's conditions to the ordered eligibility list. An appended gate
  can only remove candidates, never reorder them.
- **Complete the quote.** It may fold agreed movement costs into the
  approved total quote. How that interacts with the reader's ceiling waits
  on the q18 answer (see "Limits").
- **Rely on the selection's bindings.** Every offer and selection already
  binds the actual provider, the execution profile (the HostPrimitives
  configured profile id), the exact source versions (through the plan) and
  the approved total quote.

It may not replace ranking profile 1 (quote, provider id, serial). A
different preference order needs a new, separately versioned profile number
and a coordinated change to ER-003. This change adds no placement field, no
movement cost and no proximity input.

## Finite allocation counter

The pinned runtime supports Nat through 2^48 − 1. Approval submission and
selection share a monotonic `next_id` that remains above every allocated ID;
max − 1 is the final allocatable ID. An otherwise eligible allocation at max
returns the new model error `IdExhausted` and the original state. Earlier
denials retain their existing order. This is an observable error API addition;
it does not affect existing offers or selections, non-allocating withdrawal,
or their authority checks. Exhaustion of the separate revision counter is not
repaired here.

## Remaining host preconditions

The path stays disabled until every precondition below holds on a host and
that host's native acceptance tests show it. Bend checks none of them; each
is a trusted input or an obligation of the host adapter. Where a requirement
or the design names the obligation, its words are quoted.

1. **Transport identity for providers and approvers.** ER-001 asks for "an
   authenticated provider", and ER-006 for "current approval from every
   contributing origin". Every transition's `from` must come from transport
   identity verification (a Genode route, a Linux peer credential, a
   Windows token). A bearer handle or a native descriptor is not enough.
2. **Signature verification for off-host offers and approvals.** An offer or
   an origin approval carried from another host must be verified before
   `submit_offer` or `submit_approval` sees it. Bend verifies no signature.
3. **Grants installed by the monitor, with the issuance directory.** The
   monitor installs the current Issuance state (`Snapshot.issuer`): the
   grants, the directory of who speaks for each origin and its placements,
   and the live stamp. It must meet every precondition in
   [GRANT-ISSUANCE.md](GRANT-ISSUANCE.md). A stale or forged issuer state
   makes a revoked grant or a replaced authority look current.
4. **The clock and the trial receipts.** A trusted, non-decreasing monitor
   clock (`Snapshot.now`, `now` in the Negotiation context), current and
   consistent transfer contexts, and challenge ids never reused across
   selections, so that challenges are "generated after the candidate and
   provider scope are fixed" (ER-004).
5. **The genuine request at `open`, and monitor-only actions.** The pinned
   negotiation request and the monitor's configured profile constraint, and
   genuine Negotiation sessions and receipts at every call. `select` and
   `abandon` are invoked only by the monitor, never on a provider's or
   reader's request: whoever times `select` can pick before a cheaper
   provider's approvals arrive, and `abandon` forces the trial to be redone.
6. **The host state current at dispatch and at the commit.** The monitor's
   current HostPrimitives state at each dispatch and at each commit, never
   one from before a restart, named at the monitor's current
   `expected_host_revision` (both `dispatch` and `commit_context` require
   `HP.current` there), whose session table binds each
   worker's caller only from authenticated native evidence
   (`bind_session`), and whose native-session mapping does not survive a
   restart (HostIdentity's restart obligation).
7. **Durable, serialized rendezvous state.** Atomic installation of each
   accepted state at `expected_revision`, transitions serialized across
   hosts and processes, and durable storage with no rollback of `seen`,
   `retired`, withdrawal flags, evidence or dispatch records. The design's
   rollback rule applies: rollback "never restores old authority epochs or
   forgets consumed receipts".
8. **Per-use projection rebuilding.** `negotiation_context` for every
   `N.*` call and dispatch, `commit_context` for every `Backplane.commit` or
   facade commit, and `provider_registry` for every Frontend mount, open or
   use, each rebuilt from the current rendezvous, issuer and transfer
   states. None may be cached, reused or accepted from a caller.
9. **The same session at the commit.** `commit_context`, never
   `negotiation_context`, is the only context passed to a commit, and the
   host passes the same Negotiation session to `commit_context` and to the
   commit. Bend cannot tie them, because the commit takes its session
   separately.
10. **An adapter that admits workers only from `provider_registry` after a
    recorded dispatch.** It opens the worker's input only from
    `provider_registry`, never from the raw issuer registry. The worker it
    admitted is the one it runs: it confines that worker, reports that
    worker's session truthfully as `worker_session` at the commit, and
    leaves final validation to the unchanged
    `DataOS.commit_from_capability`.
11. **Enablement and capability negotiation.** The design's rule: "Introduce
    versioned records and explicit capability negotiation. Keep the new
    path disabled until its acceptance tests and host preconditions hold.
    Reject unknown record versions." No host adapter or facade entry exists.
12. **Trial metering.** Trial compute is unmetered and unfunded, as in
    Negotiation. It needs `add-metered-sample-execution`, which is not
    implemented.
13. **Quote settlement.** The reader's quote is a ceiling and the selection
    records the agreed quote. Settling it against the ledger hold, and the
    exact-versus-ceiling semantics, are pending Spaceghost (q18).
14. **One rendezvous per request, durably.** The host holds at most one
    rendezvous per negotiation request and Negotiation session. It opens
    every rendezvous through `open` on its durable index of opened requests,
    installs the index `open` returns, never removes an entry, never builds
    a state without `open` (`fresh`), and never presents one session's
    challenge or sample to two rendezvous. ER-005 ("Selection SHALL reject
    sample evidence from a different provider") relies on it: a sample
    names no provider, so it belongs to a provider only through the one
    rendezvous whose selection preceded its challenge.

Not a host precondition, but open before this change is merged: the count
re-pin by the controller. This lane records its own counts (1657 checks, 24
laws) and changes no pin; the controller re-pins every count and law total
once, after the parallel lanes merge.

## What this document does not claim

This document claims none of the following:

- that any host meets these inputs;
- that the rendezvous is wired into a host adapter or the DataOS facade;
- that trial compute is metered;
- that a billing semantics is settled.

The Bend tests and the ordinary proof check (`bend PROOF.bend`) show what
the model does with the inputs it is given. A Lean kernel verdict
(`--verdict`) is not claimed here. Host qualification needs separate native
evidence for each claimed profile.
