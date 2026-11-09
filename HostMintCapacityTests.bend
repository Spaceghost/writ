import Base
import ./HostIdentity.bend as I
import ./HostIdentityTests.bend as IT
import ./HostPrimitives.bend as P
import ./HostPrimitivesTests.bend as PT
import ./HostIssueCurrentTests.bend as C
import ./HostIssueResultTests.bend as R
import ./Frontend.bend as F
import ./TransferTests.bend as TF
import ./Test.bend as Test

# All records are synthetic. These table editors do not establish authority.
def identity_with(+state: I.State, revision: Nat, next: Nat, entries: I.Entries) -> I.State:
  match state:
    case I.State{_, host, incarnation, _, sessions, _}:
      I.State{revision, host, incarnation, next, sessions, entries}

def host_with(+host: P.State, host_revision: Nat, identity: I.State) -> P.State:
  match host:
    case P.State{_, _, profiles, bindings, workers, next_worker, seals, publications}:
      P.State{host_revision, identity, profiles, bindings, workers, next_worker, seals, publications}

def direct(+identity: I.State, session: Nat) -> I.Change:
  I.mint(identity, I.revision(identity), session, IT.handle_a(), TF.plan(), IT.root_rights(), IT.root_expires())

def typed_parity(+host: P.State, reason: P.Error) -> Bool:
  R.parity(host, P.revision(host), PT.session_client(), C.frontend(), F.revision(C.frontend()),
    C.registry(), TF.context(), PT.pub_handle(), TF.plan(), 7, PT.pub_root_expires(), reason)

def terminal_identity(+max: Nat) -> Bool:
  +base = IT.bound()
  +slot_full = identity_with(base, I.revision(base), max, I.entries(base))
  +rev_full = identity_with(base, max, I.next_slot(base), I.entries(base))
  I.valid(slot_full) && I.valid(rev_full)
    && Bool.not(Maybe.is_some(&2, I.Error, I.mint_preflight(slot_full, I.revision(slot_full), IT.session_a())))
    && IT.denied(direct(slot_full, IT.session_a()), slot_full, I.CapacityExhausted{})
    && IT.denied(direct(rev_full, IT.session_a()), rev_full, I.CapacityExhausted{})

def zero_identity(+max: Nat) -> Bool:
  +base = IT.bound()
  +zero = identity_with(base, I.revision(base), 0n, I.NoEntries{})
  +zero_full = identity_with(base, max, 0n, I.NoEntries{})
  I.valid(zero) && I.valid(zero_full)
    && Bool.not(Maybe.is_some(&2, I.Error, I.mint_preflight(zero, I.revision(zero), IT.session_a())))
    && IT.denied(direct(zero, IT.session_a()), zero, I.InvalidAllocatorState{})
    && IT.denied(direct(zero_full, IT.session_a()), zero_full, I.InvalidAllocatorState{})

def old_identity_order(+max: Nat) -> Bool:
  +base = IT.bound()
  +full = identity_with(base, max, max, I.entries(base))
  Bool.not(I.successor_fits_limit(0n, None{}))
    && IT.denied(I.mint(full, 0n, IT.session_a(), IT.handle_a(), TF.plan(), IT.root_rights(), IT.root_expires()),
      full, I.StaleRevision{})
    && IT.denied(direct(full, 999n), full, I.UnknownSession{})
    && IT.denied(direct(full, IT.session_heir()), full, I.InheritedEndpoint{})
    && IT.denied(direct(full, IT.session_transferee()), full, I.TransferredEndpoint{})

def accepted_edge(change: I.Change, +before: I.State, +slot: Nat, +max: Nat) -> Bool:
  match change:
    case I.Rejected{_, _}: False{}
    case I.Accepted{+after, got}:
      Nat.is_eq(got, slot) && Nat.is_eq(I.revision(after), max) && Nat.is_eq(I.next_slot(after), max)
        && I.valid(after)
        && Nat.is_eq(I.host(after), I.host(before))

def just_below(+max: Nat, +previous: Nat) -> Bool:
  +base = IT.bound()
  +edge = identity_with(base, previous, previous, I.entries(base))
  I.valid(edge) && accepted_edge(direct(edge, IT.session_a()), edge, previous, max)

def primitive_edge_result(result: P.IssueResult, +max: Nat, +previous: Nat) -> Bool:
  match result:
    case P.IssueDenied{_, _}: False{}
    case P.Issued{+after, slot}:
      Nat.is_eq(slot, previous) && Nat.is_eq(P.revision(after), max)
        && Nat.is_eq(I.revision(P.identity(after)), max)
        && Nat.is_eq(I.next_slot(P.identity(after)), max) && P.valid(after)

def primitive_edges(+max: Nat, +previous: Nat) -> Bool:
  +base = C.state()
  +id = P.identity(base)
  +slot_full = host_with(base, P.revision(base), identity_with(id, I.revision(id), max, I.entries(id)))
  +id_full = host_with(base, P.revision(base), identity_with(id, max, I.next_slot(id), I.entries(id)))
  +host_full = C.max_host_revision(base, max)
  +all_full = host_with(base, max, identity_with(id, max, max, I.entries(id)))
  +zero = host_with(base, P.revision(base), identity_with(id, I.revision(id), 0n, I.NoEntries{}))
  +zero_full = host_with(base, P.revision(base), identity_with(id, max, 0n, I.NoEntries{}))
  +edge = host_with(base, previous, identity_with(id, previous, previous, I.entries(id)))
  P.valid(slot_full) && P.valid(id_full) && P.valid(host_full) && P.valid(zero) && P.valid(zero_full)
    && typed_parity(slot_full, P.Identity{I.CapacityExhausted{}})
    && typed_parity(id_full, P.Identity{I.CapacityExhausted{}})
    && typed_parity(host_full, P.CapacityExhausted{})
    && typed_parity(all_full, P.CapacityExhausted{})
    && typed_parity(zero, P.Identity{I.InvalidAllocatorState{}})
    && typed_parity(zero_full, P.Identity{I.InvalidAllocatorState{}})
    && R.exact(R.current(edge), I.mint(P.identity(edge), I.revision(P.identity(edge)), PT.session_client(),
      PT.pub_handle(), TF.plan(), PT.root_rights(), PT.pub_root_expires()), edge)
    && primitive_edge_result(R.current(edge), max, previous)

def primitive_old_order(+max: Nat) -> Bool:
  +base = C.state()
  +full = C.max_host_revision(C.max_identity_revision(C.max_slot_state(base, max), max), max)
  +zero = host_with(base, max, identity_with(P.identity(base), max, 0n, I.NoEntries{}))
  R.parity(full, 0n, PT.session_client(), C.frontend(), 0n, F.EmptyRegistry{}, TF.context(),
      PT.pub_handle(), TF.plan(), 7, PT.pub_root_expires(), P.StaleRevision{})
    && R.parity(full, P.revision(full), PT.session_client(), C.frontend(), 0n, F.EmptyRegistry{}, TF.context(),
      PT.pub_handle(), PT.other_plan(), 7, PT.pub_root_expires(), P.PlanMismatch{})
    && R.parity(full, P.revision(full), PT.session_unknown(), C.frontend(), 0n, F.EmptyRegistry{}, TF.context(),
      PT.pub_handle(), TF.plan(), 7, PT.pub_root_expires(), P.Identity{I.UnknownSession{}})
    && R.parity(full, P.revision(full), PT.session_client(), C.frontend(), F.revision(C.frontend()), F.EmptyRegistry{}, TF.context(),
      PT.pub_handle(), TF.plan(), 7, PT.pub_root_expires(), P.AuthorityUnavailable{})
    && R.parity(zero, P.revision(zero), PT.session_client(), C.frontend(), F.revision(C.frontend()), F.EmptyRegistry{}, TF.context(),
      PT.pub_handle(), TF.plan(), 7, PT.pub_root_expires(), P.AuthorityUnavailable{})

def parsed_values(found: Maybe<&2, Nat>, near: Maybe<&2, Nat>, +which: Nat) -> Bool:
  match found near:
    case Some{max} Some{previous}:
      match which:
        case 0n: terminal_identity(max)
        case 1n: zero_identity(max)
        case 2n: old_identity_order(max)
        case 3n: just_below(max, previous)
        case 4n: primitive_edges(max, previous)
        case _: primitive_old_order(max)
    case _ _: False{}

def parsed_max(which: Nat) -> Bool:
  parsed_values(Nat.read("281474976710655"), Nat.read("281474976710654"), which)

def main() -> IO(Unit):
  do IO<Unit>:
    Test.check(parsed_max(0n), "PH-mint identity terminal counters deny unchanged")
    Test.check(parsed_max(1n), "PH-mint valid empty allocator at zero denies unchanged")
    Test.check(parsed_max(2n), "PH-mint earlier identity denials precede capacity")
    Test.check(parsed_max(3n), "PH-mint counters just below maximum accept and remain valid")
    Test.check(parsed_max(4n), "PH-mint typed and legacy primitive terminal and zero denials agree")
    Test.check(parsed_max(5n), "PH-mint stale host binding session and authority precede capacity")
    IO.print("HostMintCapacity: 6 checks passed")
