import Base
import ./Transfer.bend as T
import ./Frontend.bend as F

# Host-binding PROTOCOL MODEL for an object-capability host (Genode first).
# It relates native RPC objects, the aliases protection domains hold to them,
# parent-imposed session routes, native quotas, and explicit delegations to
# Frontend handles. There is no native capability, RPC, or kernel object here.
#
# Capabilities are references; records are authority. A native object carries
# no plan, rights, epoch, or expiry: the monitor re-resolves the bound Frontend
# handle on every use. Possession of an alias proves a domain can invoke an
# object, never that it is the subject the object was minted for.
#
# Public Data records are a model, not unforgeable capabilities. The host must
# construct State from authenticated native state; `valid` checks structure
# only and does not authenticate the supplied state. Every transition must
# return the supplied state unchanged with a closed-set reason on any denial.

# The native object classes the monitor mints. A Session backs a Frontend
# mount; a Descriptor backs an opened or attenuated handle; a ResultChannel
# carries release results back to a reader. Named ObjectKind because `Kind`
# is a reserved keyword in Bend 2 (the kind of a type).
type ObjectKind is Data:
  Session{}
  Descriptor{}
  ResultChannel{}

# A native RPC object created by the monitor. `owner` is the Writ subject the
# object was minted for, fixed at creation. Destroying the object is modelled
# by advancing `generation`; the id is never reused.
type Object is Data:
  Object{id: Nat, generation: Nat, owner: Nat, kind: ObjectKind}

# A capability reference with id `id`, held by protection domain `holder`, to
# the object whose id is `object`. The id names the reference slot the monitor
# allocated and is never reused; delegation nodes name aliases by it. It names that object only while `generation` equals
# the object's current generation; a mismatch is stale, not a lesser right.
type Alias is Data:
  Alias{id: Nat, holder: Nat, object: Nat, generation: Nat}

# A parent-imposed session route from `parent` to `child` for `service`.
# `subject` is the identity the parent prepends to the session label and is
# the only identity source. The client-chosen label suffix is resource intent
# and is deliberately not represented, so it cannot contribute to identity.
type Route is Data:
  Route{parent: Nat, child: Nat, service: Nat, subject: Nat}

# Native resource accounts of protection domain `domain`, separate from the
# Writ ledger. A transition must deny on exhaustion before Writ authority is
# consulted.
type Quota is Data:
  Quota{domain: Nat, ram: Nat, caps: Nat}

# One node of the delegation derivation tree: alias `from_alias` was used to
# give `to_holder` the new alias `alias` with `rights`. Edges point from the
# parent alias to the child alias. A delegating transition must refuse rights
# wider than the parent's effective rights, and revoking an alias must revoke
# its whole subtree.
type Delegation is Data:
  Delegation{from_alias: Nat, to_holder: Nat, rights: U32, alias: Nat}

# The link from native object `object` to the Frontend handle with id
# `handle`. Every Writ check on an invocation goes through this handle.
type Binding is Data:
  Binding{object: Nat, handle: Nat}

type Objects is Data:
  NoObjects{}
  Objects{head: Object, tail: Objects}

type Aliases is Data:
  NoAliases{}
  Aliases{head: Alias, tail: Aliases}

type Routes is Data:
  NoRoutes{}
  Routes{head: Route, tail: Routes}

type Quotas is Data:
  NoQuotas{}
  Quotas{head: Quota, tail: Quotas}

type Delegations is Data:
  NoDelegations{}
  Delegations{head: Delegation, tail: Delegations}

type Bindings is Data:
  NoBindings{}
  Bindings{head: Binding, tail: Bindings}

# The whole host-binding state. `frontend` is the embedded Frontend state and
# is changed only through Frontend's public transitions. `next_object` and
# `next_alias` exceed every id ever allocated, so destroyed ids never return.
type State is Data:
  State{revision: Nat, next_object: Nat, next_alias: Nat, objects: Objects,
    aliases: Aliases, routes: Routes, quotas: Quotas, delegations: Delegations,
    bindings: Bindings, frontend: F.State}

# Closed set of denial reasons. Every rejected transition names exactly one.
type Error is Data:
  StaleGeneration{}
  RouteMismatch{}
  SubjectMismatch{}
  WidenedRights{}
  QuotaExhausted{}
  UnknownObject{}
  UnknownAlias{}
  FrontendRejected{}
  StaleRevision{}

# A rejection carries the supplied state unchanged; a change carries the next
# state and the id of the alias or object it produced.
type Change is Data:
  Rejected{state: State, reason: Error}
  Changed{state: State, id: Nat}

# Public entry point: the empty binding state over an empty Frontend state.
# Id 0 is never allocated, matching Frontend's handle numbering.
def empty() -> State:
  State{0n, 1n, 1n, NoObjects{}, NoAliases{}, NoRoutes{}, NoQuotas{},
    NoDelegations{}, NoBindings{}, F.empty()}

def Error.equal(a: Error, b: Error) -> Bool:
  match a b:
    case StaleGeneration{} StaleGeneration{}: True{}
    case RouteMismatch{} RouteMismatch{}: True{}
    case SubjectMismatch{} SubjectMismatch{}: True{}
    case WidenedRights{} WidenedRights{}: True{}
    case QuotaExhausted{} QuotaExhausted{}: True{}
    case UnknownObject{} UnknownObject{}: True{}
    case UnknownAlias{} UnknownAlias{}: True{}
    case FrontendRejected{} FrontendRejected{}: True{}
    case StaleRevision{} StaleRevision{}: True{}
    case _ _: False{}

# Public accessor: whether the transition committed.
def Change.accepted(change: Change) -> Bool:
  match change:
    case Rejected{_, _}:
      False{}
    case Changed{_, _}:
      True{}

# Public accessor: the resulting state; on rejection, the supplied state.
def Change.state(change: Change) -> State:
  match change:
    case Rejected{state, _}:
      state
    case Changed{state, _}:
      state

# Public accessor: the denial reason; None for a committed change.
def Change.reason(change: Change) -> Maybe<&2, Error>:
  match change:
    case Rejected{_, reason}:
      Some{reason}
    case Changed{_, _}:
      None{}

# Public accessor: the id a committed change produced; None on rejection.
def Change.issued(change: Change) -> Maybe<&2, Nat>:
  match change:
    case Rejected{_, _}:
      None{}
    case Changed{_, id}:
      Some{id}

def revision(state: State) -> Nat:
  match state:
    case State{revision, _, _, _, _, _, _, _, _, _}:
      revision

def frontend(state: State) -> F.State:
  match state:
    case State{_, _, _, _, _, _, _, _, _, frontend}:
      frontend

def object_id(object: Object) -> Nat:
  match object:
    case Object{id, _, _, _}:
      id

def alias_id(alias: Alias) -> Nat:
  match alias:
    case Alias{id, _, _, _}:
      id

def alias_object(alias: Alias) -> Nat:
  match alias:
    case Alias{_, _, object, _}:
      object

def quota_domain(quota: Quota) -> Nat:
  match quota:
    case Quota{domain, _, _}:
      domain

def object_exists(objects: Objects, +wanted: Nat) -> Bool:
  match objects:
    case NoObjects{}:
      False{}
    case Objects{object, rest}:
      Nat.is_eq(object_id(object), wanted) || object_exists(rest, wanted)

def alias_exists(aliases: Aliases, +wanted: Nat) -> Bool:
  match aliases:
    case NoAliases{}:
      False{}
    case Aliases{alias, rest}:
      Nat.is_eq(alias_id(alias), wanted) || alias_exists(rest, wanted)

def quota_exists(quotas: Quotas, +wanted: Nat) -> Bool:
  match quotas:
    case NoQuotas{}:
      False{}
    case Quotas{quota, rest}:
      Nat.is_eq(quota_domain(quota), wanted) || quota_exists(rest, wanted)

def bound_object_exists(bindings: Bindings, +wanted: Nat) -> Bool:
  match bindings:
    case NoBindings{}:
      False{}
    case Bindings{Binding{object, _}, rest}:
      Nat.is_eq(object, wanted) || bound_object_exists(rest, wanted)

def delegated_alias_exists(delegations: Delegations, +wanted: Nat) -> Bool:
  match delegations:
    case NoDelegations{}:
      False{}
    case Delegations{Delegation{_, _, _, alias}, rest}:
      Nat.is_eq(alias, wanted) || delegated_alias_exists(rest, wanted)

# An allocated id is positive and below its counter. Id 0 is never allocated,
# so a zero reference can never name a live record.
def allocated(+id: Nat, next: Nat) -> Bool:
  Nat.is_gt(id, 0n) && Nat.is_lt(id, next)

# Each object id was allocated and names one object. A duplicate denies the
# whole state: picking the first match would make the owner, kind, or
# generation an invocation sees depend on list order.
def objects_valid(objects: Objects, +next: Nat) -> Bool:
  match objects:
    case NoObjects{}:
      True{}
    case Objects{+object, +rest}:
      allocated(object_id(object), next) && Bool.not(object_exists(rest, object_id(object)))
        && objects_valid(rest, next)

# Each alias id was allocated and names one reference slot, and every alias
# refers to an object that exists. A dangling alias is denied structurally
# rather than left for a transition to misread as merely stale.
def aliases_valid(aliases: Aliases, +objects: Objects, +next: Nat) -> Bool:
  match aliases:
    case NoAliases{}:
      True{}
    case Aliases{+alias, +rest}:
      allocated(alias_id(alias), next) && Bool.not(alias_exists(rest, alias_id(alias)))
        && object_exists(objects, alias_object(alias)) && aliases_valid(rest, objects, next)

# Every binding links an existing native object to a handle that exists in the
# embedded Frontend state, so every invocation reaches a real Writ check. An
# object has at most one binding: two would let list order pick its authority.
# A binding may name a closed handle; invocation still denies through Frontend.
def bindings_valid(bindings: Bindings, +objects: Objects, +handles: F.Handles) -> Bool:
  match bindings:
    case NoBindings{}:
      True{}
    case Bindings{Binding{+object, handle}, +rest}:
      object_exists(objects, object) && F.handle_exists(handles, handle)
        && Bool.not(bound_object_exists(rest, object)) && bindings_valid(rest, objects, handles)

# Every delegation node joins two existing aliases, so revoking a subtree never
# follows a dangling edge. Tree shape: each child alias has at most one parent
# node; an alias with none is a root (two parents would let list order pick
# its effective rights), and the
# parent was allocated before the child, which excludes cycles because alias
# ids only increase. Recorded rights stay inside Frontend's protocol bits.
def delegations_valid(delegations: Delegations, +aliases: Aliases) -> Bool:
  match delegations:
    case NoDelegations{}:
      True{}
    case Delegations{Delegation{+from_alias, _, rights, +alias}, +rest}:
      alias_exists(aliases, from_alias) && alias_exists(aliases, alias)
        && Nat.is_lt(from_alias, alias) && F.rights_valid(rights)
        && Bool.not(delegated_alias_exists(rest, alias)) && delegations_valid(rest, aliases)

# Each domain has one quota account; two would let list order decide whether
# a domain is exhausted.
def quotas_valid(quotas: Quotas) -> Bool:
  match quotas:
    case NoQuotas{}:
      True{}
    case Quotas{+quota, +rest}:
      Bool.not(quota_exists(rest, quota_domain(quota))) && quotas_valid(rest)

# Public entry point: the structural invariant every transition requires of
# its input and preserves on success. It is total and checks shape only; it
# does not authenticate the state, the routes, or who holds which alias.
# Clauses:
# - both counters are positive, so id 0 stays unallocated;
# - the embedded Frontend state satisfies Frontend's own invariant;
# - object and alias ids are unique and were allocated by their counters;
# - every alias and every binding names an existing object, and every binding
#   names an existing Frontend handle, with at most one binding per object;
# - every delegation joins existing aliases in a parent-before-child tree;
# - each domain has at most one quota account.
# Routes carry no ids; a mount transition must check the route's subject
# against the authenticated caller.
def valid(state: State) -> Bool:
  match state:
    case State{_, +next_object, +next_alias, +objects, +aliases, _, quotas,
        delegations, bindings, +frontend}:
      Nat.is_gt(next_object, 0n) && Nat.is_gt(next_alias, 0n) && F.valid(frontend)
        && objects_valid(objects, next_object) && aliases_valid(aliases, objects, next_alias)
        && bindings_valid(bindings, objects, F.handles(frontend))
        && delegations_valid(delegations, aliases) && quotas_valid(quotas)
