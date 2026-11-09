import Base
import ../../../HostIdentity.bend as I
import ../../../HostPrimitives.bend as P
import ../../../Frontend.bend as F
import ../../../Transfer.bend as T
import ../../../Issuance.bend as Iss
import ../../../Rendezvous.bend as R
import ../../../Negotiation.bend as N

# Synthetic retained-owner data and read-only checks. These values do not
# authenticate their contents and none of these definitions commits effects.

# The retained joint owner is synthetic trusted monitor state. External frames
# cannot supply these records, and constructing Data is not authentication.
type Lineage is Data:
  NoLineage{}
  Lineage{incarnation: Nat, selection: Nat, grant: Nat, slot: Nat, rest: Lineage}

# A failed owner retains its historical stops and can never reopen. The
# native host must synchronously contain the whole instance.
type JointPhase is Data:
  JointActive{}
  JointFailed{effects: +List<P.Effect>}

type Joint is Data:
  NoJoint{}
  Joint{issuer: Iss.State, rendezvous: R.State, frontend: F.State, transfer: T.Context,
    negotiation: N.Session, negotiation_context: N.Context, lineage: Lineage, phase: JointPhase, rest: Joint}

def no_dispatches(dispatches: R.Dispatches) -> Bool:
  match dispatches:
    case R.NoDispatches{}: True{}
    case _: False{}

def policies_current(+issuer: Iss.State, +transfer: T.Context, context: N.Context) -> Bool:
  match context:
    case N.Context{reader_transfer, _, _, _, _}:
      T.Stamp.equal(T.Context.live(transfer), Iss.live(issuer))
        && T.Stamp.equal(T.Context.live(reader_transfer), Iss.live(issuer))

# Rebuild each subject's grant projections from one retained issuer and the
# exact sampled time. Policy facts are fixed trusted bootstrap inputs.
def projected_transfer(+issuer: Iss.State, +principal: Iss.Principal, context: T.Context, +now: Nat) -> T.Context:
  match context:
    case T.Context{_, _, sources, destination, operation, _, _, payments}:
      T.Context{Iss.live(issuer), now, sources, destination, operation,
        Iss.reads(issuer, principal, now), Iss.writes(issuer, principal, now), payments}

def selected_principal(selection: R.Selection) -> Iss.Principal:
  match selection:
    case R.NoSelection{}: Iss.Principal{0n}
    case R.Selection{_, offer, _, _, _, _}: R.Offer.provider(offer)

def joint_snapshot(+issuer: Iss.State, +rendezvous: R.State, transfer: T.Context, +now: Nat) -> R.Snapshot:
  R.Snapshot{issuer, projected_transfer(issuer, selected_principal(R.selection(rendezvous)), transfer, now), now}

# Restrict the provider's Transfer grants to the one exact registered grant
# backing the selected offer. Another grant for the same subject or plan must
# not substitute for that selected grant.
def selected_transfer_grant(found: Maybe<&2, Iss.Grant>, +issuer: Iss.State,
    context: T.Context, +now: Nat) -> T.Context:
  match found context:
    case None{} T.Context{_, _, sources, destination, operation, _, _, payments}:
      T.Context{Iss.live(issuer), now, sources, destination, operation, T.ReadEnd{}, T.WriteEnd{}, payments}
    case Some{+grant} T.Context{_, _, sources, destination, operation, _, _, payments}:
      +principal = {Iss.Principal{Iss.Scope.subject(Iss.Grant.scope(grant))} : Iss.Principal}
      +only = {Iss.Grants{grant, Iss.NoGrants{}} : Iss.Grants}
      T.Context{Iss.live(issuer), now, sources, destination, operation,
        Iss.reads_of(only, issuer, principal, now), Iss.writes_of(only, issuer, principal, now), payments}

def selected_grant(selection: R.Selection, +issuer: Iss.State) -> Maybe<&2, Iss.Grant>:
  match selection:
    case R.NoSelection{}: None{}
    case R.Selection{_, offer, _, _, _, _}: Iss.find_grant(Iss.grants(issuer), R.Offer.grant(offer))

def selected_transfer(+issuer: Iss.State, +rendezvous: R.State, context: T.Context, now: Nat) -> T.Context:
  selected_transfer_grant(selected_grant(R.selection(rendezvous), issuer), issuer, context, now)

# An exhausted counter is detected before evaluating a committing transition.
# A failed parse of the backend's maximum also fails closed.
def room_with(value: Nat, found: Maybe<&2, Nat>) -> Bool:
  match found:
    case None{}: False{}
    case Some{maximum}: Nat.is_lt(value, maximum)

def counter_room(value: Nat) -> Bool:
  room_with(value, Nat.read("281474976710655"))

# A unique recorded root must cover the resolved entry in this incarnation
# and belong to the same still-selected Issuance grant.
type LineageCount is Data:
  NoMatch{}
  OneMatch{}
  MultipleMatches{}

def add_lineage_match(matched: Bool, count: LineageCount) -> LineageCount:
  match matched count:
    case False{} count: count
    case True{} NoMatch{}: OneMatch{}
    case True{} _: MultipleMatches{}

# The selected root is always positive. The shared ancestry walk handles
# fixed-point parents without burning remaining fuel; malformed target zero
# is deliberately denied by this narrower owner check.
def reaches_root(fuel: Nat, entries: I.Entries, slot: Nat, +target: Nat) -> Bool:
  f = Bool.pick(Unit -> Bool, Nat.is_gt(target, 0n),
    x => I.under(fuel, entries, slot, target), x => False{})
  f(Unit{})

def lineage_root(found: Maybe<&2, I.Entry>, +identity: I.State, +entry: I.Entry, +slot: Nat) -> Bool:
  match found:
    case None{}: False{}
    case Some{+root}:
      Nat.is_gt(slot, 0n) && I.entry_live(root) && Nat.is_eq(I.entry_parent(root), I.root_parent())
        && I.caller_equal(I.entry_owner(root), I.entry_owner(entry))
        && reaches_root(I.next_slot(identity), I.entries(identity), I.entry_slot(entry), slot)

def lineage_count(entries: Lineage, +identity: I.State, +entry: I.Entry, +selection: Nat,
    +grant: Nat, count: LineageCount) -> LineageCount:
  match entries:
    case NoLineage{}: count
    case Lineage{incarnation, selected, granted, +root, rest}:
      lineage_count(rest, identity, entry, selection, grant,
        add_lineage_match(Nat.is_eq(incarnation, I.incarnation(identity))
          && Nat.is_eq(selected, selection) && Nat.is_eq(granted, grant)
          && lineage_root(I.entry_lookup(I.entries(identity), root), identity, entry, root), count))

def lineage_unique(count: LineageCount) -> Bool:
  match count:
    case OneMatch{}: True{}
    case _: False{}

def entry_grant_current(found: Maybe<&2, Iss.Grant>, +issuer: Iss.State, +identity: I.State,
    +entry: I.Entry, +selection: Nat, +lineage: Lineage, +now: Nat) -> Bool:
  match found:
    case None{}: False{}
    case Some{+grant}:
      Iss.usable_by(issuer, grant, Iss.Principal{I.caller_subject(I.entry_owner(entry))}, now)
        && T.CodeId.equal(Iss.Grant.token(grant), F.caller_token(I.entry_owner(entry)))
        && lineage_unique(lineage_count(lineage, identity, entry, selection, Iss.Grant.id(grant), NoMatch{}))

# The Negotiation reader can differ from the selected provider. Its Transfer
# grants must also be rebuilt for that reader and time, never copied cached.
def joint_negotiation(+issuer: Iss.State, +rendezvous: R.State, +negotiation: N.Session,
    context: N.Context, +snapshot: R.Snapshot, now: Nat) -> N.Context:
  match context:
    case N.Context{transfer, approvals, challenges, samples, budgets}:
      R.negotiation_context(rendezvous,
        N.Context{projected_transfer(issuer, Iss.Principal{N.Request.reader(N.Session.request(negotiation))},
          transfer, now), approvals, challenges, samples, budgets}, snapshot)

# Recheck the retained trial's current Running session and the reader's
# subject-scoped Transfer authority at the same issuer and sampled time.
# This is not a budget, committed ledger, or original-graph verification.
def reader_current(+issuer: Iss.State, +rendezvous: R.State, +negotiation: N.Session,
    context: N.Context, +snapshot: R.Snapshot, now: Nat) -> Bool:
  +current = {joint_negotiation(issuer, rendezvous, negotiation, context, snapshot, now) : N.Context}
  R.session_follows_selection(rendezvous, negotiation)
    && N.ready(negotiation, N.Session.revision(negotiation), N.Running{}, current)
    && T.accepted(T.admit(N.Session.plan(negotiation), N.Context.transfer(current)))
