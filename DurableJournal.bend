import Base
import ./DurablePublication.bend as D
import ./DurableIntent.bend as E
import ./HostPrimitives.bend as P
import ./HostPublication.bend as H
import ./Backplane.bend as B
import ./Negotiation.bend as N
import ./Ledger.bend as L
import ./Transfer.bend as T
import ./Core.bend as C
import ./DataOS.bend as OS

# Reference journal TRANSITIONS ONLY. The journal models a single atomic update
# of the monitor's host, session, ledger and committed-intent records. It does
# not write storage, authenticate a native acknowledgement, publish, or recover
# external data. Every constructor is public; a journal supplied by a caller is
# not authoritative. Only a monitor-owned, current journal and context may be
# evaluated, and the host must serialize ALL authority and time-dependent facts
# with its actual storage transaction. Its journal revision represents that
# complete serialization domain, not a substitute for those native guarantees.
# `authorize` calls the existing publication gate through `D.prepare`, once;
# `inspect` compares with the journal's retained intent and produces no effect.
# Neither function is a release route or proves the host installed the result.
# Coherence checks detect mismatches with the existing host and ledger records,
# but those records do not contain full policy, backend or receipt-to-invocation
# history. They cannot authenticate a recovered journal or detect every altered
# intent. A separately authenticated, current journal and witness are mandatory
# preconditions, not guarantees of these pure comparisons.
# Transition errors and inspection answers can reveal whether an invocation
# exists or matches, whether the journal is full, or why the host gate denied.
# They are private monitor diagnostics, not responses to an untrusted caller;
# a future host must separately authorize and policy-gate observable status.
# The journal is bounded to `max_entries()` records before it performs the
# quadratic uniqueness checks. The host must independently bound host and
# ledger collections, candidate graphs and context, and the sizes and nesting
# of individual intents, policies and requests, before invoking the model.
# Public entry points: `authorize`, `inspect`, and `max_entries`; other defs
# are exported implementation helpers and confer no authority when called.

type Entry is Data:
  Entry{invocation: Nat, receipt: Nat, request: N.Request, intent: B.WriteIntent}

type Entries is Data:
  Empty{}
  More{entry: Entry, rest: Entries}

type State is Data:
  State{revision: Nat, primitive: P.State, session: N.Session, ledger: L.State, entries: Entries}

type Error is Data:
  Stale{}
  Replay{}
  Full{}
  Host{reason: P.Error}
  NotFound{}
  Substitution{}

type Transition is Data:
  Advanced{state: State}
  Denied{state: State, reason: Error}

type Lookup is Data:
  Found{receipt: Nat, request: N.Request, intent: B.WriteIntent}
  Missing{}
  Ambiguous{}

type Inspection is Data:
  Matches{}
  Refused{reason: Error}

def max_entries() -> Nat:
  64n

def within(fuel: Nat, entries: Entries) -> Bool:
  match fuel entries:
    case _ Empty{}:
      True{}
    case 0n More{_, _}:
      False{}
    case 1n+n More{_, rest}:
      within(n, rest)

def has_space(limit: Nat, entries: Entries) -> Bool:
  match limit:
    case 0n:
      False{}
    case 1n+n:
      within(n, entries)

def entry_invocation(entry: Entry) -> Nat:
  match entry:
    case Entry{invocation, _, _, _}:
      invocation

def entry_receipt(entry: Entry) -> Nat:
  match entry:
    case Entry{_, receipt, _, _}:
      receipt

def entries_contain(entries: Entries, +invocation: Nat) -> Bool:
  match entries:
    case Empty{}:
      False{}
    case More{entry, rest}:
      Nat.is_eq(entry_invocation(entry), invocation) || entries_contain(rest, invocation)

def receipts_contain(entries: Entries, +receipt: Nat) -> Bool:
  match entries:
    case Empty{}:
      False{}
    case More{entry, rest}:
      Nat.is_eq(entry_receipt(entry), receipt) || receipts_contain(rest, receipt)

def entries_unique(entries: Entries) -> Bool:
  match entries:
    case Empty{}:
      True{}
    case More{+entry, +rest}:
      Bool.not(entries_contain(rest, entry_invocation(entry)))
        && Bool.not(receipts_contain(rest, entry_receipt(entry))) && entries_unique(rest)

def publication_matches(found: P.PublicationLookup, intent: B.WriteIntent) -> Bool:
  match found intent:
    case P.OnePublication{P.Publication{_, digest, destination}} B.WriteIntent{plan, _, _, _, B.ArtifactId{artifact}}:
      T.CodeId.equal(digest, artifact) && T.ObjectVersion.equal(destination, T.Plan.destination(plan))
    case _ _:
      False{}

def intent_plan(intent: B.WriteIntent) -> T.Plan:
  match intent:
    case B.WriteIntent{plan, _, _, _, _}:
      plan

def entry_valid(entry: Entry, +primitive: P.State, ledger: L.State) -> Bool:
  match entry ledger:
    case Entry{+invocation, receipt, request, +intent} L.State{_, _, _, seen, committed}:
      Nat.is_eq(invocation, T.Plan.invocation(intent_plan(intent))) && T.Plan.equal(N.Request.plan(request), intent_plan(intent))
        && L.contains(seen, receipt) && L.contains(committed, invocation)
        && publication_matches(P.publication_at(P.publications(primitive), invocation), intent)

def entries_valid(entries: Entries, +primitive: P.State, +ledger: L.State) -> Bool:
  match entries:
    case Empty{}:
      True{}
    case More{entry, rest}:
      entry_valid(entry, primitive, ledger) && entries_valid(rest, primitive, ledger)

def publications_covered(publications: P.Publications, +entries: Entries) -> Bool:
  match publications:
    case P.NoPublications{}:
      True{}
    case P.Publications{publication, rest}:
      entries_contain(entries, P.publication_invocation(publication)) && publications_covered(rest, entries)

def coherent_bounded(ok: Bool, +primitive: P.State, +ledger: L.State, +entries: Entries) -> Bool:
  match ok:
    case False{}:
      False{}
    case True{}:
      P.valid(primitive) && L.valid(ledger) && entries_unique(entries) && entries_valid(entries, primitive, ledger)
        && publications_covered(P.publications(primitive), entries)

def coherent(+primitive: P.State, +ledger: L.State, +entries: Entries) -> Bool:
  coherent_bounded(within(max_entries(), entries), primitive, ledger, entries)

def lookup_one(matches: Bool, receipt: Nat, request: N.Request, intent: B.WriteIntent, rest: Lookup) -> Lookup:
  match matches rest:
    case False{} _:
      rest
    case True{} Missing{}:
      Found{receipt, request, intent}
    case True{} _:
      Ambiguous{}

def find(entries: Entries, +invocation: Nat) -> Lookup:
  match entries:
    case Empty{}:
      Missing{}
    case More{Entry{id, receipt, request, intent}, rest}:
      lookup_one(Nat.is_eq(id, invocation), receipt, request, intent, find(rest, invocation))

def inspect_equal(equal: Bool) -> Inspection:
  match equal:
    case True{}:
      Matches{}
    case False{}:
      Refused{Substitution{}}

def inspect_found(found: Lookup, receipt: Nat, request: N.Request, requested: B.WriteIntent) -> Inspection:
  match found:
    case Found{stored_receipt, stored_request, intent}:
      inspect_equal(Nat.is_eq(stored_receipt, receipt) && N.Request.equal(stored_request, request)
        && E.intent_equal(intent, requested))
    case _:
      Refused{NotFound{}}

def inspect_gate(ok: Bool, entries: Entries, invocation: Nat, receipt: Nat, request: N.Request,
    requested: B.WriteIntent) -> Inspection:
  match ok:
    case True{}:
      inspect_found(find(entries, invocation), receipt, request, requested)
    case False{}:
      Refused{Stale{}}

# A match is a model observation, never a Publish or a grant. The requested
# receipt, request and intent are untrusted and must match the retained record.
def inspect(state: State, expected_revision: Nat, invocation: Nat, receipt: Nat, request: N.Request,
    requested: B.WriteIntent) -> Inspection:
  match state:
    case State{revision, +primitive, _, +ledger, +entries}:
      inspect_gate(Nat.is_eq(revision, expected_revision) && coherent(primitive, ledger, entries), entries,
        invocation, receipt, request, requested)

def outcome_prepared(result: D.Preparation, original: State) -> Transition:
  match result original:
    case D.Refused{_, _, _, reason} _:
      Denied{original, Host{reason}}
    case D.Prepared{primitive, B.Committed{session, ledger, +intent}}
        State{revision, _, +old_session, _, entries}:
      Advanced{State{1n+revision, primitive, session, ledger,
        More{Entry{T.Plan.invocation(N.Session.plan(old_session)), N.Session.receipt(old_session),
          N.Session.request(old_session), intent}, entries}}}
    case _ _:
      Denied{original, Stale{}}

def authorize_fresh(fresh: Bool, +state: State, worker: Nat, fact: H.ArtifactFact,
    candidate: C.Candidate, context: OS.Context, frontend_revision: Nat) -> Transition:
  match fresh state:
    case False{} _:
      Denied{state, Replay{}}
    case True{} State{revision, +primitive, +session, +ledger, entries}:
      outcome_prepared(D.prepare(primitive, P.revision(primitive), worker, fact, session,
        N.Session.revision(session), L.revision(ledger), ledger, candidate, context, frontend_revision),
        State{revision, primitive, session, ledger, entries})

def authorize_space(space: Bool, +state: State, worker: Nat, fact: H.ArtifactFact,
    candidate: C.Candidate, context: OS.Context, frontend_revision: Nat) -> Transition:
  match space state:
    case False{} _:
      Denied{state, Full{}}
    case True{} State{revision, primitive, +session, ledger, +entries}:
      authorize_fresh(Bool.not(entries_contain(entries, T.Plan.invocation(N.Session.plan(session)))),
        State{revision, primitive, session, ledger, entries}, worker, fact, candidate, context, frontend_revision)

def authorize_gate(ok: Bool, +state: State, worker: Nat, fact: H.ArtifactFact,
    candidate: C.Candidate, context: OS.Context, frontend_revision: Nat) -> Transition:
  match ok state:
    case False{} _:
      Denied{state, Stale{}}
    case True{} State{revision, primitive, session, ledger, +entries}:
      authorize_space(has_space(max_entries(), entries), State{revision, primitive, session, ledger, entries},
        worker, fact, candidate, context, frontend_revision)

# This is an idealized pure transition over a current monitor-owned state. The
# real transaction, authoritative snapshot, writer exclusion, and storage
# acknowledgement remain host obligations; successful evaluation is not proof
# that any of them happened, and it yields no native delivery effect.
def authorize(+state: State, expected_revision: Nat, worker: Nat, fact: H.ArtifactFact,
    candidate: C.Candidate, context: OS.Context, frontend_revision: Nat) -> Transition:
  match state:
    case State{revision, +primitive, _, +ledger, +entries}:
      authorize_gate(Nat.is_eq(revision, expected_revision) && coherent(primitive, ledger, entries),
        state, worker, fact, candidate, context, frontend_revision)
