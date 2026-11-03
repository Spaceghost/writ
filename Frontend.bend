import Base
import ./Transfer.bend as T

# Capability-mounted character-device PROTOCOL MODEL. There is no OS mount,
# file descriptor, syscall, plaintext read, or device IO in this pure library.
# The monitor supplies current state, an authenticated caller subject, a live
# registry, and trusted time/epoch. Token words are compared in full; this code
# does not generate random tokens, authenticate callers, or verify signatures.
# State updates require a current revision and an atomic host-side commit.

type Capability is Data:
  Capability{token: T.CodeId, subject: Nat, plan: T.Plan, rights: U32,
    authority_epoch: Nat, expires: Nat}

type Registry is Data:
  EmptyRegistry{}
  Registered{capability: Capability, rest: Registry}

type Caller is Data:
  Caller{subject: Nat, token: T.CodeId}

type Ref is Data:
  Ref{caller: Caller, id: Nat}

type Live is Data:
  Live{authority_epoch: Nat, now: Nat}

type HandleKind is Data:
  Mounted{}
  Descriptor{}

type Handle is Data:
  Handle{id: Nat, kind: HandleKind, subject: Nat, token: T.CodeId,
    plan: T.Plan, rights: U32, authority_epoch: Nat, expires: Nat, closed: Bool}

type Handles is Data:
  NoHandles{}
  Handles{head: Handle, tail: Handles}

type State is Data:
  State{revision: Nat, next: Nat, handles: Handles}

type Change is Data:
  Rejected{state: State}
  Changed{state: State, id: Nat}

# Protocol rights: 1 = read request, 2 = write request, 4 = execute request.
# Execute requires all three bits. Every operational request still requires
# T.admit to approve the entire paired read/write plan against live context.
type Request is Data:
  Read{}
  Write{}
  Execute{}

def empty() -> State:
  State{0n, 1n, NoHandles{}}

def accepted(change: Change) -> Bool:
  match change:
    case Rejected{_}:
      False{}
    case Changed{_, _}:
      True{}

def state(change: Change) -> State:
  match change:
    case Rejected{state}:
      state
    case Changed{state, _}:
      state

def issued(change: Change) -> Maybe<&2, Nat>:
  match change:
    case Rejected{_}:
      None{}
    case Changed{_, id}:
      Some{id}

def revision(state: State) -> Nat:
  match state:
    case State{revision, _, _}:
      revision

def handles(state: State) -> Handles:
  match state:
    case State{_, _, handles}:
      handles

def authority(stamp: T.Stamp) -> Nat:
  match stamp:
    case T.Stamp{_, _, authority}:
      authority

def live(context: T.Context) -> Live:
  match context:
    case T.Context{stamp, now, _, _, _, _, _, _}:
      Live{authority(stamp), now}

def rights_valid(rights: U32) -> Bool:
  T.word_subset(rights, 7)

def request_rights(request: Request) -> U32:
  match request:
    case Read{}:
      1
    case Write{}:
      2
    case Execute{}:
      7

def token(capability: Capability) -> T.CodeId:
  match capability:
    case Capability{token, _, _, _, _, _}:
      token

def caller_token(caller: Caller) -> T.CodeId:
  match caller:
    case Caller{_, token}:
      token

def ref_token(ref: Ref) -> T.CodeId:
  match ref:
    case Ref{caller, _}:
      caller_token(caller)

def ref_id(ref: Ref) -> Nat:
  match ref:
    case Ref{_, id}:
      id

def handle_id(handle: Handle) -> Nat:
  match handle:
    case Handle{id, _, _, _, _, _, _, _, _}:
      id

def handle_rights(handle: Handle) -> U32:
  match handle:
    case Handle{_, _, _, _, _, rights, _, _, _}:
      rights

def handle_plan(handle: Handle) -> T.Plan:
  match handle:
    case Handle{_, _, _, _, plan, _, _, _, _}:
      plan

def is_mount(handle: Handle) -> Bool:
  match handle:
    case Handle{_, Mounted{}, _, _, _, _, _, _, _}:
      True{}
    case _:
      False{}

def is_descriptor(handle: Handle) -> Bool:
  match handle:
    case Handle{_, Descriptor{}, _, _, _, _, _, _, _}:
      True{}
    case _:
      False{}

def registry_contains(registry: Registry, +wanted: T.CodeId) -> Bool:
  match registry:
    case EmptyRegistry{}:
      False{}
    case Registered{capability, rest}:
      T.CodeId.equal(token(capability), wanted) || registry_contains(rest, wanted)

def capability_valid(capability: Capability) -> Bool:
  match capability:
    case Capability{_, _, plan, rights, epoch, _}:
      rights_valid(rights) && Nat.is_eq(authority(T.Plan.stamp(plan)), epoch)

def registry_valid(registry: Registry) -> Bool:
  match registry:
    case EmptyRegistry{}:
      True{}
    case Registered{+capability, +rest}:
      capability_valid(capability) && Bool.not(registry_contains(rest, token(capability)))
        && registry_valid(rest)

def handle_exists(handles: Handles, +wanted: Nat) -> Bool:
  match handles:
    case NoHandles{}:
      False{}
    case Handles{handle, rest}:
      Nat.is_eq(handle_id(handle), wanted) || handle_exists(rest, wanted)

def handle_valid(handle: Handle, next: Nat) -> Bool:
  match handle:
    case Handle{+id, _, _, _, plan, rights, epoch, _, _}:
      Nat.is_gt(id, 0n) && Nat.is_lt(id, next) && rights_valid(rights)
        && Nat.is_eq(authority(T.Plan.stamp(plan)), epoch)

def handles_valid(handles: Handles, +next: Nat) -> Bool:
  match handles:
    case NoHandles{}:
      True{}
    case Handles{+handle, +rest}:
      handle_valid(handle, next) && Bool.not(handle_exists(rest, handle_id(handle)))
        && handles_valid(rest, next)

def valid(state: State) -> Bool:
  match state:
    case State{_, +next, handles}:
      Nat.is_gt(next, 0n) && handles_valid(handles, next)

def choose_capability(ok: Bool, capability: Capability, rest: Maybe<&2, Capability>) -> Maybe<&2, Capability>:
  match ok:
    case True{}:
      Some{capability}
    case False{}:
      rest

def find_capability(registry: Registry, +wanted: T.CodeId) -> Maybe<&2, Capability>:
  match registry:
    case EmptyRegistry{}:
      None{}
    case Registered{+capability, rest}:
      choose_capability(T.CodeId.equal(token(capability), wanted), capability,
        find_capability(rest, wanted))

def choose_handle(ok: Bool, handle: Handle, rest: Maybe<&2, Handle>) -> Maybe<&2, Handle>:
  match ok:
    case True{}:
      Some{handle}
    case False{}:
      rest

def find_handle(handles: Handles, +wanted: Nat) -> Maybe<&2, Handle>:
  match handles:
    case NoHandles{}:
      None{}
    case Handles{+handle, rest}:
      choose_handle(Nat.is_eq(handle_id(handle), wanted), handle, find_handle(rest, wanted))

def capability_current(capability: Capability, caller: Caller, live: Live, +rights: U32) -> Bool:
  match capability caller live:
    case Capability{token, subject, _, allowed, epoch, expires}
        Caller{claimed_subject, claimed_token} Live{current, now}:
      T.CodeId.equal(token, claimed_token) && Nat.is_eq(subject, claimed_subject)
        && rights_valid(rights) && T.word_subset(rights, allowed)
        && Nat.is_eq(epoch, current) && Nat.is_lt(now, expires)

def make_handle(capability: Capability, id: Nat, kind: HandleKind, rights: U32) -> Handle:
  match capability:
    case Capability{token, subject, plan, _, epoch, expires}:
      Handle{id, kind, subject, token, plan, rights, epoch, expires, False{}}

def insert_handle(state: State, capability: Capability, kind: HandleKind, rights: U32) -> Change:
  match state:
    case State{revision, +next, handles}:
      Changed{State{1n+revision, 1n+next,
        Handles{make_handle(capability, next, kind, rights), handles}}, next}

def mount_gate(ok: Bool, state: State, capability: Capability, rights: U32) -> Change:
  match ok:
    case False{}:
      Rejected{state}
    case True{}:
      insert_handle(state, capability, Mounted{}, rights)

def mount_found(found: Maybe<&2, Capability>, state: State, caller: Caller, live: Live, +rights: U32) -> Change:
  match found:
    case None{}:
      Rejected{state}
    case Some{+capability}:
      mount_gate(capability_current(capability, caller, live, rights), state, capability, rights)

def mount_checked(ok: Bool, state: State, registry: Registry, +caller: Caller, live: Live, rights: U32) -> Change:
  match ok:
    case False{}:
      Rejected{state}
    case True{}:
      mount_found(find_capability(registry, caller_token(caller)), state, caller, live, rights)

def mount(+state: State, +registry: Registry, expected_revision: Nat, caller: Caller, rights: U32, live: Live) -> Change:
  mount_checked(valid(state) && registry_valid(registry) && Nat.is_eq(revision(state), expected_revision),
    state, registry, caller, live, rights)

def ref_matches(handle: Handle, ref: Ref) -> Bool:
  match handle ref:
    case Handle{id, _, subject, token, _, _, _, _, closed}
        Ref{Caller{claimed_subject, claimed_token}, claimed_id}:
      Bool.not(closed) && Nat.is_eq(id, claimed_id) && Nat.is_eq(subject, claimed_subject)
        && T.CodeId.equal(token, claimed_token)

def scope_current(handle: Handle, capability: Capability, live: Live) -> Bool:
  match handle capability live:
    case Handle{_, _, hs, ht, hp, hr, he, +hu, _}
        Capability{ct, cs, cp, cr, ce, +cu} Live{+epoch, +now}:
      Nat.is_eq(hs, cs) && T.CodeId.equal(ht, ct) && T.Plan.equal(hp, cp)
        && T.word_subset(hr, cr) && Nat.is_eq(he, epoch) && Nat.is_eq(ce, epoch)
        && Nat.is_le(hu, cu) && Nat.is_lt(now, hu) && Nat.is_lt(now, cu)

def handle_gate(ok: Bool, handle: Handle) -> Maybe<&2, Handle>:
  match ok:
    case True{}:
      Some{handle}
    case False{}:
      None{}

def authorized_found(handle: Maybe<&2, Handle>, capability: Maybe<&2, Capability>, ref: Ref, live: Live) -> Maybe<&2, Handle>:
  match handle capability:
    case Some{+handle} Some{capability}:
      handle_gate(ref_matches(handle, ref) && scope_current(handle, capability, live), handle)
    case _ _:
      None{}

def authorized_checked(ok: Bool, state: State, registry: Registry, +ref: Ref, live: Live) -> Maybe<&2, Handle>:
  match ok:
    case False{}:
      None{}
    case True{}:
      authorized_found(find_handle(handles(state), ref_id(ref)),
        find_capability(registry, ref_token(ref)), ref, live)

def authorized(+state: State, +registry: Registry, expected_revision: Nat, ref: Ref, live: Live) -> Maybe<&2, Handle>:
  authorized_checked(valid(state) && registry_valid(registry) && Nat.is_eq(revision(state), expected_revision),
    state, registry, ref, live)

def copy_handle(handle: Handle, id: Nat, kind: HandleKind, rights: U32) -> Handle:
  match handle:
    case Handle{_, _, subject, token, plan, _, epoch, expires, _}:
      Handle{id, kind, subject, token, plan, rights, epoch, expires, False{}}

def insert_copy(state: State, handle: Handle, rights: U32) -> Change:
  match state:
    case State{revision, +next, handles}:
      Changed{State{1n+revision, 1n+next,
        Handles{copy_handle(handle, next, Descriptor{}, rights), handles}}, next}

def open_gate(ok: Bool, state: State, handle: Handle, rights: U32) -> Change:
  match ok:
    case True{}:
      insert_copy(state, handle, rights)
    case False{}:
      Rejected{state}

def open_found(found: Maybe<&2, Handle>, state: State, +rights: U32) -> Change:
  match found:
    case None{}:
      Rejected{state}
    case Some{+handle}:
      open_gate(is_mount(handle) && rights_valid(rights) && T.word_subset(rights, handle_rights(handle)),
        state, handle, rights)

def open(+state: State, registry: Registry, expected_revision: Nat, ref: Ref, rights: U32, live: Live) -> Change:
  open_found(authorized(state, registry, expected_revision, ref, live), state, rights)

def dup_found(found: Maybe<&2, Handle>, state: State) -> Change:
  match found:
    case None{}:
      Rejected{state}
    case Some{+handle}:
      open_gate(is_descriptor(handle), state, handle, handle_rights(handle))

def dup(+state: State, registry: Registry, expected_revision: Nat, ref: Ref, live: Live) -> Change:
  dup_found(authorized(state, registry, expected_revision, ref, live), state)

def restricted(handle: Handle, rights: U32) -> Handle:
  match handle:
    case Handle{id, kind, subject, token, plan, _, epoch, expires, closed}:
      Handle{id, kind, subject, token, plan, rights, epoch, expires, closed}

def replace_one(ok: Bool, old: Handle, replacement: Handle) -> Handle:
  match ok:
    case True{}:
      replacement
    case False{}:
      old

def replace(handles: Handles, +replacement: Handle, +wanted: Nat) -> Handles:
  match handles:
    case NoHandles{}:
      NoHandles{}
    case Handles{+head, tail}:
      Handles{replace_one(Nat.is_eq(handle_id(head), wanted), head, replacement),
        replace(tail, replacement, wanted)}

def replace_handle(state: State, +handle: Handle) -> Change:
  match state:
    case State{revision, next, handles}:
      Changed{State{1n+revision, next, replace(handles, handle, handle_id(handle))}, handle_id(handle)}

def attenuate_gate(ok: Bool, state: State, handle: Handle, rights: U32) -> Change:
  match ok:
    case True{}:
      replace_handle(state, restricted(handle, rights))
    case False{}:
      Rejected{state}

def attenuate_found(found: Maybe<&2, Handle>, state: State, +rights: U32) -> Change:
  match found:
    case None{}:
      Rejected{state}
    case Some{+handle}:
      attenuate_gate(rights_valid(rights) && T.word_subset(rights, handle_rights(handle)), state, handle, rights)

# Attenuation replaces this handle in the current state. Previously duplicated
# handles keep their own rights; revoke the registry grant to revoke them all.
def attenuate(+state: State, registry: Registry, expected_revision: Nat, ref: Ref, rights: U32, live: Live) -> Change:
  attenuate_found(authorized(state, registry, expected_revision, ref, live), state, rights)

def closed(handle: Handle) -> Handle:
  match handle:
    case Handle{id, kind, subject, token, plan, rights, epoch, expires, _}:
      Handle{id, kind, subject, token, plan, rights, epoch, expires, True{}}

def close_gate(ok: Bool, state: State, handle: Handle) -> Change:
  match ok:
    case True{}:
      replace_handle(state, closed(handle))
    case False{}:
      Rejected{state}

def close_found(found: Maybe<&2, Handle>, state: State, ref: Ref) -> Change:
  match found:
    case None{}:
      Rejected{state}
    case Some{+handle}:
      close_gate(ref_matches(handle, ref), state, handle)

def close_checked(ok: Bool, +state: State, +ref: Ref) -> Change:
  match ok:
    case False{}:
      Rejected{state}
    case True{}:
      close_found(find_handle(handles(state), ref_id(ref)), state, ref)

# Closing is cleanup: an authenticated owner can close an expired/revoked
# handle. The tombstone remains, and monotonically allocated IDs never reuse it.
def close(+state: State, expected_revision: Nat, ref: Ref) -> Change:
  close_checked(valid(state) && Nat.is_eq(revision(state), expected_revision), state, ref)

def plan_gate(ok: Bool, plan: T.Plan) -> Maybe<&2, T.Plan>:
  match ok:
    case True{}:
      Some{plan}
    case False{}:
      None{}

def resolve_gate(ok: Bool, +plan: T.Plan, context: T.Context) -> Maybe<&2, T.Plan>:
  match ok:
    case False{}:
      None{}
    case True{}:
      plan_gate(T.accepted(T.admit(plan, context)), plan)

def resolve_found(found: Maybe<&2, Handle>, request: Request, context: T.Context) -> Maybe<&2, T.Plan>:
  match found:
    case None{}:
      None{}
    case Some{+handle}:
      resolve_gate(is_descriptor(handle) && T.word_subset(request_rights(request), handle_rights(handle)),
        handle_plan(handle), context)

# The client supplies no replacement plan. Every request yields the same
# immutable registered plan, after live paired read/write admission. This is
# a proposal for Backplane; it is not a committed write or a plaintext result.
def checked_plan(+state: State, registry: Registry, expected_revision: Nat, ref: Ref,
    request: Request, +context: T.Context) -> Maybe<&2, T.Plan>:
  resolve_found(authorized(state, registry, expected_revision, ref, live(context)), request, context)
