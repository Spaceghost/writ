import Base
import ./Transfer.bend as T
import ./Frontend.bend as F

# Host-binding PROTOCOL MODEL for an object-capability host (Genode first).
# It relates native objects, the aliases protection domains hold to them,
# parent-imposed session routes, native quotas, and explicit delegations to
# Frontend handles. There is no native capability or kernel object here.
# Requests and results are records in channels; the native object is only
# the identity-bearing reference a domain uses to reach its channel.
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

# A native channel object created by the monitor. `owner` is the Writ subject
# the object was minted for, fixed at creation. Destroying the object is
# modelled by advancing `generation`; the id is never reused. `derived_from` is
# 0n for a root object (a mount's Session) and otherwise the id of the object
# whose alias was used to open or attenuate it. It records a derivation edge,
# so a delegatee's derived alias can stay in its delegator's subtree without
# being confused with a copy of the parent reference. `service` is the routed
# service the root Session was mounted for; a derived object inherits it, so
# a route for one service never vouches for objects of another.
type Object is Data:
  Object{id: Nat, generation: Nat, owner: Nat, kind: ObjectKind, derived_from: Nat, service: Nat}

# A capability reference with id `id`, held by protection domain `holder`, to
# the object whose id is `object`. The id names the reference slot the monitor
# allocated and is never reused; delegation nodes name aliases by it. It
# names that object only while `generation` equals the object's current
# generation; a mismatch is stale, not a lesser right.
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
# state and one id. Alias ids, object ids, and protection-domain ids are three
# separate number spaces, and which one `id` belongs to depends on the
# transition: bind_mount, bind_open, bind_attenuate, and delegate return the
# new alias id; bind_close returns the destroyed object id; revoke returns the
# revoked protection-domain id (an input, not an allocation).
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
    case Object{id, _, _, _, _, _}:
      id

def object_derived(object: Object) -> Nat:
  match object:
    case Object{_, _, _, _, derived_from, _}:
      derived_from

def object_service(object: Object) -> Nat:
  match object:
    case Object{_, _, _, _, _, service}:
      service

def alias_id(alias: Alias) -> Nat:
  match alias:
    case Alias{id, _, _, _}:
      id

def alias_object(alias: Alias) -> Nat:
  match alias:
    case Alias{_, _, object, _}:
      object

def pick_nat(ok: Bool, chosen: Nat, rest: Nat) -> Nat:
  match ok:
    case True{}:
      chosen
    case False{}:
      rest

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

# Whether alias `wanted` exists and is held by protection domain `holder`.
def alias_held(aliases: Aliases, +wanted: Nat, +holder: Nat) -> Bool:
  match aliases:
    case NoAliases{}:
      False{}
    case Aliases{Alias{id, owner, _, _}, rest}:
      (Nat.is_eq(id, wanted) && Nat.is_eq(owner, holder)) || alias_held(rest, wanted, holder)

# Whether alias `wanted` exists and refers to object `object`.
def alias_names(aliases: Aliases, +wanted: Nat, +object: Nat) -> Bool:
  match aliases:
    case NoAliases{}:
      False{}
    case Aliases{Alias{id, _, named, _}, rest}:
      (Nat.is_eq(id, wanted) && Nat.is_eq(named, object)) || alias_names(rest, wanted, object)

# Whether protection domain `holder` holds any alias, current or stale, to
# object `object`.
def holds_object(aliases: Aliases, +holder: Nat, +object: Nat) -> Bool:
  match aliases:
    case NoAliases{}:
      False{}
    case Aliases{Alias{_, owner, named, _}, rest}:
      (Nat.is_eq(owner, holder) && Nat.is_eq(named, object)) || holds_object(rest, holder, object)

# The object alias `wanted` refers to, or 0n (never allocated) when no such
# alias exists, so a missing alias can never match a real object.
def alias_object_of(aliases: Aliases, +wanted: Nat) -> Nat:
  match aliases:
    case NoAliases{}:
      0n
    case Aliases{Alias{id, _, object, _}, rest}:
      pick_nat(Nat.is_eq(id, wanted), object, alias_object_of(rest, wanted))

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

# The object `wanted` was derived from, or 0n for a root or a missing object.
def derived_of(objects: Objects, +wanted: Nat) -> Nat:
  match objects:
    case NoObjects{}:
      0n
    case Objects{+object, rest}:
      pick_nat(Nat.is_eq(object_id(object), wanted), object_derived(object), derived_of(rest, wanted))

# Whether object `wanted` exists and serves `service`.
def object_serves(objects: Objects, +wanted: Nat, +service: Nat) -> Bool:
  match objects:
    case NoObjects{}:
      False{}
    case Objects{+object, rest}:
      (Nat.is_eq(object_id(object), wanted) && Nat.is_eq(object_service(object), service))
        || object_serves(rest, wanted, service)

# A derivation edge is absent (0n) or points to an existing object allocated
# earlier that serves the same service, so derivation chains are acyclic,
# never dangle, and never move an object onto another service's route.
def derivation_valid(+derived_from: Nat, +id: Nat, +service: Nat, +all: Objects) -> Bool:
  Nat.is_eq(derived_from, 0n) || (Nat.is_lt(derived_from, id) && object_serves(all, derived_from, service))

# Each object id was allocated and names one object. A duplicate denies the
# whole state: picking the first match would make the owner, kind, or
# generation an invocation sees depend on list order. `all` is the complete
# object list, against which derivation edges are resolved.
def objects_valid(objects: Objects, +all: Objects, +next: Nat) -> Bool:
  match objects:
    case NoObjects{}:
      True{}
    case Objects{+object, +rest}:
      allocated(object_id(object), next) && Bool.not(object_exists(rest, object_id(object)))
        && derivation_valid(object_derived(object), object_id(object), object_service(object), all)
        && objects_valid(rest, all, next)

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
# its effective rights), and the parent was allocated before the child, which
# excludes cycles because alias ids only increase. Recorded rights stay inside
# Frontend's protocol bits. The node's `to_holder` is the child alias's holder,
# so the record names the domain that actually received the reference. The
# child either names the parent's object (a copy: delegation never reaches a
# different object) or names an object derived from the parent's object (a
# delegatee opened or attenuated through its delegated alias). Pruning the
# parent's branch therefore reaches both kinds of child.
def delegation_edge_valid(+aliases: Aliases, +objects: Objects, +from_alias: Nat, +alias: Nat) -> Bool:
  alias_names(aliases, alias, alias_object_of(aliases, from_alias))
    || Nat.is_eq(derived_of(objects, alias_object_of(aliases, alias)), alias_object_of(aliases, from_alias))

def delegations_valid(delegations: Delegations, +aliases: Aliases, +objects: Objects) -> Bool:
  match delegations:
    case NoDelegations{}:
      True{}
    case Delegations{Delegation{+from_alias, +to_holder, rights, +alias}, +rest}:
      alias_exists(aliases, from_alias) && alias_exists(aliases, alias)
        && Nat.is_lt(from_alias, alias) && F.rights_valid(rights)
        && alias_held(aliases, alias, to_holder)
        && delegation_edge_valid(aliases, objects, from_alias, alias)
        && Bool.not(delegated_alias_exists(rest, alias)) && delegations_valid(rest, aliases, objects)

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
# - object and alias ids are unique and were allocated by their counters, and
#   every derivation edge names an earlier existing object on the same service;
# - every alias and every binding names an existing object, and every binding
#   names an existing Frontend handle, with at most one binding per object;
# - every delegation joins existing aliases in a parent-before-child tree,
#   names the child's holder, and stays on the parent's object or on an
#   object derived from it;
# - each domain has at most one quota account.
# Routes carry no ids; a mount transition must check the route's subject
# against the authenticated caller.
def valid(state: State) -> Bool:
  match state:
    case State{_, +next_object, +next_alias, +objects, +aliases, _, quotas,
        delegations, bindings, +frontend}:
      Nat.is_gt(next_object, 0n) && Nat.is_gt(next_alias, 0n) && F.valid(frontend)
        && objects_valid(objects, objects, next_object) && aliases_valid(aliases, objects, next_alias)
        && bindings_valid(bindings, objects, F.handles(frontend))
        && delegations_valid(delegations, aliases, objects) && quotas_valid(quotas)

# ---------------------------------------------------------------------------
# Transitions.
#
# Every public transition first requires a structurally valid state at the
# expected revision; a state failing `valid` is not one this monitor
# committed, so it is denied as StaleRevision rather than read. Denials then
# follow a fixed order per transition and return the supplied `state` value
# itself, never a rebuilt copy. A success advances `revision` exactly once.
# The embedded Frontend state is changed only through F.mount, F.open, F.dup,
# F.attenuate, and F.close, called at its own current revision because the
# binding revision already serializes commits.

def objects(state: State) -> Objects:
  match state:
    case State{_, _, _, objects, _, _, _, _, _, _}:
      objects

def aliases(state: State) -> Aliases:
  match state:
    case State{_, _, _, _, aliases, _, _, _, _, _}:
      aliases

def routes(state: State) -> Routes:
  match state:
    case State{_, _, _, _, _, routes, _, _, _, _}:
      routes

def quotas(state: State) -> Quotas:
  match state:
    case State{_, _, _, _, _, _, quotas, _, _, _}:
      quotas

def delegations(state: State) -> Delegations:
  match state:
    case State{_, _, _, _, _, _, _, delegations, _, _}:
      delegations

def bindings(state: State) -> Bindings:
  match state:
    case State{_, _, _, _, _, _, _, _, bindings, _}:
      bindings

def object_generation(object: Object) -> Nat:
  match object:
    case Object{_, generation, _, _, _, _}:
      generation

def object_owner(object: Object) -> Nat:
  match object:
    case Object{_, _, owner, _, _, _}:
      owner

def object_kind(object: Object) -> ObjectKind:
  match object:
    case Object{_, _, _, kind, _, _}:
      kind

def alias_holder(alias: Alias) -> Nat:
  match alias:
    case Alias{_, holder, _, _}:
      holder

def alias_generation(alias: Alias) -> Nat:
  match alias:
    case Alias{_, _, _, generation}:
      generation

def delegation_alias(delegation: Delegation) -> Nat:
  match delegation:
    case Delegation{_, _, _, alias}:
      alias

def route_child(route: Route) -> Nat:
  match route:
    case Route{_, child, _, _}:
      child

def route_service(route: Route) -> Nat:
  match route:
    case Route{_, _, service, _}:
      service

def route_subject(route: Route) -> Nat:
  match route:
    case Route{_, _, _, subject}:
      subject

# The subject the monitor authenticated for this invocation. Frontend checks
# it again against the stored handle; HostBinding uses it only to compare
# against the parent-imposed route.
def caller_subject(caller: F.Caller) -> Nat:
  match caller:
    case F.Caller{subject, _}:
      subject

def choose_alias(ok: Bool, alias: Alias, rest: Maybe<&2, Alias>) -> Maybe<&2, Alias>:
  match ok:
    case True{}:
      Some{alias}
    case False{}:
      rest

def find_alias(aliases: Aliases, +wanted: Nat) -> Maybe<&2, Alias>:
  match aliases:
    case NoAliases{}:
      None{}
    case Aliases{+alias, rest}:
      choose_alias(Nat.is_eq(alias_id(alias), wanted), alias, find_alias(rest, wanted))

def choose_object(ok: Bool, object: Object, rest: Maybe<&2, Object>) -> Maybe<&2, Object>:
  match ok:
    case True{}:
      Some{object}
    case False{}:
      rest

def find_object(objects: Objects, +wanted: Nat) -> Maybe<&2, Object>:
  match objects:
    case NoObjects{}:
      None{}
    case Objects{+object, rest}:
      choose_object(Nat.is_eq(object_id(object), wanted), object, find_object(rest, wanted))

def choose_handle(ok: Bool, handle: Nat, rest: Maybe<&2, Nat>) -> Maybe<&2, Nat>:
  match ok:
    case True{}:
      Some{handle}
    case False{}:
      rest

# The Frontend handle id bound to object `wanted`. `valid` allows at most one.
def find_binding(bindings: Bindings, +wanted: Nat) -> Maybe<&2, Nat>:
  match bindings:
    case NoBindings{}:
      None{}
    case Bindings{Binding{object, handle}, rest}:
      choose_handle(Nat.is_eq(object, wanted), handle, find_binding(rest, wanted))

# Whether the route was imposed by the parent, compared on every field. A
# route the caller merely presents is not authority: the subject it names must
# come from the recorded parent configuration.
def route_recorded(routes: Routes, +wanted: Route) -> Bool:
  match routes wanted:
    case NoRoutes{} _:
      False{}
    case Routes{Route{parent, child, service, subject}, rest} Route{+wp, +wc, +ws, +wsub}:
      (Nat.is_eq(parent, wp) && Nat.is_eq(child, wc) && Nat.is_eq(service, ws)
        && Nat.is_eq(subject, wsub)) || route_recorded(rest, Route{wp, wc, ws, wsub})

# Native capability quota: the acting domain must be able to receive one more
# reference. A domain with no account has no quota, so it is exhausted.
def has_cap(quotas: Quotas, +domain: Nat) -> Bool:
  match quotas:
    case NoQuotas{}:
      False{}
    case Quotas{Quota{owner, _, caps}, rest}:
      (Nat.is_eq(owner, domain) && Nat.is_gt(caps, 0n)) || has_cap(rest, domain)

def less_one(caps: Nat) -> Nat:
  match caps:
    case 0n:
      0n
    case 1n+rest:
      rest

def charge_one(ok: Bool, quota: Quota) -> Quota:
  match ok quota:
    case True{} Quota{domain, ram, caps}:
      Quota{domain, ram, less_one(caps)}
    case False{} quota:
      quota

# Charge one capability slot to `domain`. Called only after has_cap held, so
# the account exists and the decrement never saturates at zero.
def take_cap(quotas: Quotas, +domain: Nat) -> Quotas:
  match quotas:
    case NoQuotas{}:
      NoQuotas{}
    case Quotas{+quota, rest}:
      Quotas{charge_one(Nat.is_eq(quota_domain(quota), domain), quota), take_cap(rest, domain)}

# Whether a recorded delegation node gave alias `wanted` to `holder`.
def delegated_to(delegations: Delegations, +wanted: Nat, +holder: Nat) -> Bool:
  match delegations:
    case NoDelegations{}:
      False{}
    case Delegations{Delegation{_, to_holder, _, alias}, rest}:
      (Nat.is_eq(alias, wanted) && Nat.is_eq(to_holder, holder)) || delegated_to(rest, wanted, holder)

def choose_rights(ok: Bool, rights: U32, rest: Maybe<&2, U32>) -> Maybe<&2, U32>:
  match ok:
    case True{}:
      Some{rights}
    case False{}:
      rest

# The rights recorded on the delegation node that created alias `wanted`, if
# it was delegated rather than minted.
def delegated_rights(delegations: Delegations, +wanted: Nat) -> Maybe<&2, U32>:
  match delegations:
    case NoDelegations{}:
      None{}
    case Delegations{Delegation{_, _, rights, alias}, rest}:
      choose_rights(Nat.is_eq(alias, wanted), rights, delegated_rights(rest, wanted))

# Effective rights of an alias: a minted alias carries the bound handle's
# rights; a delegated alias carries its node's rights, intersected with the
# handle's current rights so a later Frontend attenuation also narrows it.
# Neither path can exceed what the handle grants now.
def effective_rights(found: Maybe<&2, U32>, +handle_rights: U32) -> U32:
  match found:
    case None{}:
      handle_rights
    case Some{delegated}:
      (delegated .&. handle_rights : U32)

# Whether the parent recorded a route giving protection domain `child` the
# identity `subject` for `service`. This is the only link between a domain id
# and a Writ subject: the two id spaces are never compared directly, and a
# route for one service says nothing about objects of another.
def route_maps(routes: Routes, +child: Nat, +subject: Nat, +service: Nat) -> Bool:
  match routes:
    case NoRoutes{}:
      False{}
    case Routes{Route{_, routed, served, named}, rest}:
      (Nat.is_eq(routed, child) && Nat.is_eq(named, subject) && Nat.is_eq(served, service))
        || route_maps(rest, child, subject, service)

# Whether the parent routes protection domain `child` for `service` as some
# subject other than `subject`. Such a domain acts for a different subject on
# that service, so it is not "the same subject's worker" GA-005 admits as a
# delegatee. A domain with no route on `service` is not routed otherwise.
def routed_otherwise(routes: Routes, +child: Nat, +subject: Nat, +service: Nat) -> Bool:
  match routes:
    case NoRoutes{}:
      False{}
    case Routes{Route{_, routed, served, named}, rest}:
      (Nat.is_eq(routed, child) && Nat.is_eq(served, service) && Bool.not(Nat.is_eq(named, subject)))
        || routed_otherwise(rest, child, subject, service)

# The parent alias of `wanted` in the delegation tree, or 0n for a root. Id 0
# is never allocated, so a root's parent can never match a cut.
def parent_of(delegations: Delegations, +wanted: Nat) -> Nat:
  match delegations:
    case NoDelegations{}:
      0n
    case Delegations{Delegation{from_alias, _, _, alias}, rest}:
      pick_nat(Nat.is_eq(alias, wanted), from_alias, parent_of(rest, wanted))

# The root of the delegation chain through alias `alias`: the first alias,
# walking parent edges upward, that has no parent node. `valid` makes every
# parent id strictly smaller than its child's and positive, so fuel equal to
# the alias id reaches the root before it runs out (as in under_cut).
def chain_root(fuel: Nat, +delegations: Delegations, +alias: Nat) -> Nat:
  match fuel:
    case 0n:
      alias
    case 1n+rest:
      pick_nat(Nat.is_eq(parent_of(delegations, alias), 0n), alias,
        chain_root(rest, delegations, parent_of(delegations, alias)))

# Whether alias `wanted` exists and its holder is routed by its parent as
# `subject` for `service`. Used on a chain root: the delegator's own route is
# what a delegated alias draws its authority from.
def alias_routed(aliases: Aliases, +routes: Routes, +wanted: Nat, +subject: Nat, +service: Nat) -> Bool:
  match aliases:
    case NoAliases{}:
      False{}
    case Aliases{Alias{id, owner, _, _}, rest}:
      (Nat.is_eq(id, wanted) && route_maps(routes, owner, subject, service))
        || alias_routed(rest, routes, wanted, subject, service)

# Model rule GA-005: possession is not the subject. `holder` must hold the
# alias, and must either be routed by its parent as the subject the object was
# minted for on the object's service, or be the domain a recorded delegation
# node gave this exact alias to. A delegated alias stays authorized only while
# the root of its delegation chain is still held by a domain the parent routes
# as that subject on that service: withdrawing the delegator's route withdraws
# every delegation drawn from it. A delegated holder is also denied while the
# parent routes it as some other subject on the object's service. This is the
# use-time counterpart of the check `delegate` makes on its target: a domain
# routed as another subject after it received the delegation acts for that
# other subject on the service, so keeping this subject's authority would merge
# the two; the denial is SubjectMismatch, reported like any other unauthorized
# holder. A route for the holder on a different service changes nothing here.
# On Genode this models a parent reconfiguration that the monitor observes
# through its own recorded routes, not through the invoking domain. The running
# host cannot observe the invoking domain; this rule is enforced there by
# topology (GA-010).
def holder_authorized(+routes: Routes, +delegations: Delegations, +aliases: Aliases, +alias: Alias,
    +object: Object, +holder: Nat) -> Bool:
  Nat.is_eq(alias_holder(alias), holder)
    && (route_maps(routes, holder, object_owner(object), object_service(object))
      || (delegated_to(delegations, alias_id(alias), holder)
        && alias_routed(aliases, routes, chain_root(alias_id(alias), delegations, alias_id(alias)),
          object_owner(object), object_service(object))
        && Bool.not(routed_otherwise(routes, holder, object_owner(object), object_service(object)))))

def is_delegated(found: Maybe<&2, U32>) -> Bool:
  match found:
    case None{}:
      False{}
    case Some{_}:
      True{}

# The outcome of resolving an alias for a holder. `rights` is the alias's
# effective rights; `handle` is the bound Frontend handle as last committed,
# which Frontend re-checks in full on every call. `delegated` says the alias
# was authorized through a delegation node, so anything derived through it
# must stay in that delegation subtree.
type Resolved is Data:
  Unresolved{reason: Error}
  Resolved{alias: Alias, object: Object, handle: F.Handle, rights: U32, delegated: Bool}

def resolve_handle(found: Maybe<&2, F.Handle>, +alias: Alias, +object: Object, +state: State) -> Resolved:
  match found:
    case None{}:
      Unresolved{UnknownObject{}}
    case Some{+handle}:
      Resolved{alias, object, handle,
        effective_rights(delegated_rights(delegations(state), alias_id(alias)), F.handle_rights(handle)),
        is_delegated(delegated_rights(delegations(state), alias_id(alias)))}

# A bound object whose handle is missing from Frontend is unknown, never a
# default grant. `valid` excludes it; the check keeps resolution total.
def resolve_binding(found: Maybe<&2, Nat>, +alias: Alias, +object: Object, +state: State) -> Resolved:
  match found:
    case None{}:
      Unresolved{UnknownObject{}}
    case Some{+handle}:
      resolve_handle(F.find_handle(F.handles(frontend(state)), handle), alias, object, state)

def resolve_subject(ok: Bool, +alias: Alias, +object: Object, +state: State) -> Resolved:
  match ok:
    case False{}:
      Unresolved{SubjectMismatch{}}
    case True{}:
      resolve_binding(find_binding(bindings(state), object_id(object)), alias, object, state)

# A generation mismatch means the object was destroyed after this alias was
# issued. It is stale, not a lesser right. It is reported only to a domain
# that holds the alias (see resolve_alias) and before route and delegation
# records are consulted, so a destroyed reference never reveals them.
def resolve_current(ok: Bool, +alias: Alias, +object: Object, +state: State, +holder: Nat) -> Resolved:
  match ok:
    case False{}:
      Unresolved{StaleGeneration{}}
    case True{}:
      resolve_subject(holder_authorized(routes(state), delegations(state), aliases(state), alias,
        object, holder), alias, object, state)

def resolve_object(found: Maybe<&2, Object>, +alias: Alias, +state: State, +holder: Nat) -> Resolved:
  match found:
    case None{}:
      Unresolved{UnknownObject{}}
    case Some{+object}:
      resolve_current(Nat.is_eq(alias_generation(alias), object_generation(object)),
        alias, object, state, holder)

def resolve_alias(found: Maybe<&2, Alias>, +state: State, +holder: Nat) -> Resolved:
  match found:
    case None{}:
      Unresolved{UnknownAlias{}}
    case Some{+alias}:
      resolve_object(find_object(objects(state), alias_object(alias)), alias, state, holder)

# The alias `wanted` if, and only if, protection domain `holder` holds it.
# A domain that does not hold the alias is answered exactly as if the alias
# did not exist, so it learns neither that the alias exists nor whether its
# object was destroyed.
def find_held_alias(aliases: Aliases, +wanted: Nat, +holder: Nat) -> Maybe<&2, Alias>:
  match aliases:
    case NoAliases{}:
      None{}
    case Aliases{+alias, rest}:
      choose_alias(Nat.is_eq(alias_id(alias), wanted) && Nat.is_eq(alias_holder(alias), holder), alias,
        find_held_alias(rest, wanted, holder))

# Exported helper: the single authority path every alias-taking transition
# uses. Denial order: UnknownAlias (no such alias, or `holder` does not hold
# it), StaleGeneration, SubjectMismatch; an object or binding missing from a
# valid state is UnknownObject. It reads the state and never changes it.
def resolve(+state: State, +alias_id: Nat, +holder: Nat) -> Resolved:
  resolve_alias(find_held_alias(aliases(state), alias_id, holder), state, holder)

def link_node(ok: Bool, node: Delegation, rest: Delegations) -> Delegations:
  match ok:
    case True{}:
      Delegations{node, rest}
    case False{}:
      rest

# Exported implementation helper, not an entry point: it performs no check.
# Only bind_mount, bind_open, and bind_attenuate call it, after every denial
# gate has passed; calling it directly bypasses route, holder, rights, and
# quota checks. Mint a fresh native object owned by `owner` on `service` and
# derived from `parent` (0n for a root), one current alias to it held by
# `holder`, and its binding to Frontend handle `handle`, charging `holder` one
# capability slot. When the alias used was delegated, a node from
# `used_alias` to the new alias with `recorded` rights keeps the result inside
# the delegator's subtree, so revoking that branch prunes it too. Ids come
# from the monotonic counters, so a destroyed object or alias id is never
# handed out again. Returns the new alias id.
def commit_mint(state: State, +next_frontend: F.State, +handle: Nat, +holder: Nat, +owner: Nat,
    kind: ObjectKind, +parent: Nat, +service: Nat, +delegated: Bool, +used_alias: Nat,
    +recorded: U32) -> Change:
  match state:
    case State{revision, +next_object, +next_alias, objects, aliases, routes, quotas,
        delegations, bindings, _}:
      Changed{State{1n+revision, 1n+next_object, 1n+next_alias,
        Objects{Object{next_object, 0n, owner, kind, parent, service}, objects},
        Aliases{Alias{next_alias, holder, next_object, 0n}, aliases}, routes,
        take_cap(quotas, holder),
        link_node(delegated, Delegation{used_alias, holder, recorded, next_alias}, delegations),
        Bindings{Binding{next_object, handle}, bindings}, next_frontend}, next_alias}

def mount_frontend(change: F.Change, +state: State, +holder: Nat, +owner: Nat, +service: Nat) -> Change:
  match change:
    case F.Rejected{_}:
      Rejected{state, FrontendRejected{}}
    case F.Changed{next_frontend, handle}:
      commit_mint(state, next_frontend, handle, holder, owner, Session{}, 0n, service, False{}, 0n, 0)

def mount_quota(ok: Bool, +state: State, +route: Route, +caller: F.Caller, +registry: F.Registry,
    +rights: U32, +live: F.Live) -> Change:
  match ok:
    case False{}:
      Rejected{state, QuotaExhausted{}}
    case True{}:
      mount_frontend(F.mount(frontend(state), registry, F.revision(frontend(state)), caller, rights, live),
        state, route_child(route), route_subject(route), route_service(route))

def mount_route(ok: Bool, +state: State, +route: Route, +caller: F.Caller, +registry: F.Registry,
    +rights: U32, +live: F.Live) -> Change:
  match ok:
    case False{}:
      Rejected{state, RouteMismatch{}}
    case True{}:
      mount_quota(has_cap(quotas(state), route_child(route)), state, route, caller, registry, rights, live)

def mount_checked(ok: Bool, +state: State, +route: Route, +caller: F.Caller, +registry: F.Registry,
    +rights: U32, +live: F.Live) -> Change:
  match ok:
    case False{}:
      Rejected{state, StaleRevision{}}
    case True{}:
      mount_route(route_recorded(routes(state), route)
          && Nat.is_eq(route_subject(route), caller_subject(caller)),
        state, route, caller, registry, rights, live)

# Public entry point: bind a Frontend mount to a new Session object.
# Identity comes only from the parent-imposed route: the route must be one the
# parent recorded and its subject must be the subject the monitor
# authenticated, else RouteMismatch. The child domain must have a capability
# slot (QuotaExhausted, checked before Frontend is consulted). F.mount then
# applies every Writ check (FrontendRejected). On success the child holds the
# only alias to a root Session owned by the route subject on the route's
# service; the change id is that alias. Denial order: StaleRevision,
# RouteMismatch, QuotaExhausted, FrontendRejected.
def bind_mount(+state: State, expected_revision: Nat, +route: Route, +caller: F.Caller,
    +registry: F.Registry, +rights: U32, +live: F.Live) -> Change:
  mount_checked(valid(state) && Nat.is_eq(revision(state), expected_revision),
    state, route, caller, registry, rights, live)

# Which Frontend transition derives the narrower handle. Both mint a new
# native object bound to a new handle: handing out the parent object for a
# narrower handle would let a reference reach authority it was not issued for
# (GA-003).
type Derivation is Data:
  Opening{}
  Attenuating{}

# Second step of attenuation: narrow the duplicate just created, at the
# Frontend revision the duplication produced. A rejection at either step is
# passed through as a rejection; the caller then returns the original state.
def attenuate_dup(change: F.Change, +registry: F.Registry, +caller: F.Caller, +rights: U32,
    +live: F.Live) -> F.Change:
  match change:
    case F.Rejected{rejected}:
      F.Rejected{rejected}
    case F.Changed{+duplicated, +copy}:
      F.attenuate(duplicated, registry, F.revision(duplicated), F.Ref{caller, copy}, rights, live)

# Opening calls F.open on the parent handle. Attenuating first duplicates the
# parent handle with F.dup and then attenuates only the duplicate, so the
# parent handle and every object bound to it keep their rights. F.dup accepts
# only Descriptors, so attenuating a Session alias is FrontendRejected: a
# mount is narrowed by opening a descriptor with fewer rights, never by
# attenuating the mount itself. Either way the result is a new Descriptor.
def derive_frontend(step: Derivation, +current: F.State, +registry: F.Registry, +caller: F.Caller,
    +parent_handle: Nat, +rights: U32, +live: F.Live) -> F.Change:
  match step:
    case Opening{}:
      F.open(current, registry, F.revision(current), F.Ref{caller, parent_handle}, rights, live)
    case Attenuating{}:
      attenuate_dup(F.dup(current, registry, F.revision(current), F.Ref{caller, parent_handle}, live),
        registry, caller, rights, live)

def derive_frontend_done(change: F.Change, +state: State, +holder: Nat, +parent: Object,
    +delegated: Bool, +used_alias: Nat, +recorded: U32) -> Change:
  match change:
    case F.Rejected{_}:
      Rejected{state, FrontendRejected{}}
    case F.Changed{next_frontend, handle}:
      commit_mint(state, next_frontend, handle, holder, object_owner(parent), Descriptor{},
        object_id(parent), object_service(parent), delegated, used_alias, recorded)

def derive_quota(ok: Bool, +step: Derivation, +state: State, +parent: Object, +handle: F.Handle,
    +holder: Nat, +delegated: Bool, +used_alias: Nat, +recorded: U32, +caller: F.Caller,
    +registry: F.Registry, +rights: U32, +live: F.Live) -> Change:
  match ok:
    case False{}:
      Rejected{state, QuotaExhausted{}}
    case True{}:
      derive_frontend_done(
        derive_frontend(step, frontend(state), registry, caller, F.handle_id(handle), rights, live),
        state, holder, parent, delegated, used_alias, recorded)

def derive_rights(ok: Bool, step: Derivation, +state: State, +parent: Object, +handle: F.Handle,
    +holder: Nat, +delegated: Bool, +used_alias: Nat, +recorded: U32, +caller: F.Caller,
    +registry: F.Registry, +rights: U32, +live: F.Live) -> Change:
  match ok:
    case False{}:
      Rejected{state, WidenedRights{}}
    case True{}:
      derive_quota(has_cap(quotas(state), holder), step, state, parent, handle, holder, delegated,
        used_alias, recorded, caller, registry, rights, live)

# The recorded rights of a derived delegation node are the requested rights
# within the used alias's effective rights; the rights gate makes them equal
# to the request, and the intersection keeps the node narrow even so.
def derive_resolved(found: Resolved, step: Derivation, +state: State, +holder: Nat,
    +caller: F.Caller, +registry: F.Registry, +rights: U32, +live: F.Live) -> Change:
  match found:
    case Unresolved{reason}:
      Rejected{state, reason}
    case Resolved{+alias, object, handle, +effective, delegated}:
      derive_rights(F.rights_valid(rights) && T.word_subset(rights, effective), step, state, object,
        handle, holder, delegated, alias_id(alias), (rights .&. effective : U32), caller, registry,
        rights, live)

def derive_checked(ok: Bool, step: Derivation, +state: State, expected_alias: Nat, +holder: Nat,
    +caller: F.Caller, +registry: F.Registry, +rights: U32, +live: F.Live) -> Change:
  match ok:
    case False{}:
      Rejected{state, StaleRevision{}}
    case True{}:
      derive_resolved(resolve(state, expected_alias, holder), step, state, holder, caller,
        registry, rights, live)

# Public entry point: open a Descriptor from the Session bound behind
# `alias_id` and give `holder` a new object, derived from the Session, bound
# to the new handle. The parent object and every alias to it are untouched.
# `rights` must lie within the alias's effective rights (a delegatee cannot
# open past its delegation), and `holder` needs a capability slot before
# F.open is consulted. A delegatee's result is recorded under its delegation
# node. The monitor cannot observe which domain invoked the object (GA-010);
# it authenticates `caller`, the subject on whose behalf the request arrives.
# `holder` is the domain the model records as acting, HostBinding does not
# link the two, and Frontend checks `caller` against the bound handle. The
# change id is the new alias.
# Denial order: StaleRevision, UnknownAlias (no such alias, or `holder` does
# not hold it), StaleGeneration, SubjectMismatch, WidenedRights,
# QuotaExhausted, FrontendRejected (UnknownObject only for an unbound object).
# A Descriptor alias is FrontendRejected: F.open opens only from a mount.
def bind_open(+state: State, expected_revision: Nat, +alias_id: Nat, +holder: Nat,
    +caller: F.Caller, +registry: F.Registry, +rights: U32, +live: F.Live) -> Change:
  derive_checked(valid(state) && Nat.is_eq(revision(state), expected_revision), Opening{}, state,
    alias_id, holder, caller, registry, rights, live)

# Public entry point: give `holder` a narrower Descriptor derived from the
# Descriptor bound behind `alias_id`. The parent handle is duplicated with
# F.dup and only the duplicate is attenuated, so the parent handle's rights
# and every alias to the parent object are unchanged. A Session alias is
# FrontendRejected (see derive_frontend). If either Frontend step rejects, the
# supplied state is returned unchanged. Same checks, caller assumption, and
# denial order as bind_open, including UnknownAlias for a non-holder.
def bind_attenuate(+state: State, expected_revision: Nat, +alias_id: Nat, +holder: Nat,
    +caller: F.Caller, +registry: F.Registry, +rights: U32, +live: F.Live) -> Change:
  derive_checked(valid(state) && Nat.is_eq(revision(state), expected_revision), Attenuating{}, state,
    alias_id, holder, caller, registry, rights, live)

# Exported implementation helper, not an entry point: it performs no check
# and is called only by `delegate` after every denial gate has passed.
# Record that `from_alias` gave `to_holder` a new alias to the same object at
# its current generation. The node is the child's only parent record.
def commit_delegate(state: State, +from_alias: Alias, +to_holder: Nat, +rights: U32) -> Change:
  match state:
    case State{revision, next_object, +next_alias, objects, aliases, routes, quotas,
        delegations, bindings, frontend}:
      Changed{State{1n+revision, next_object, 1n+next_alias, objects,
        Aliases{Alias{next_alias, to_holder, alias_object(from_alias), alias_generation(from_alias)}, aliases},
        routes, quotas, Delegations{Delegation{alias_id(from_alias), to_holder, rights, next_alias}, delegations},
        bindings, frontend}, next_alias}

def delegate_rights(ok: Bool, +state: State, +alias: Alias, +to_holder: Nat, +rights: U32) -> Change:
  match ok:
    case False{}:
      Rejected{state, WidenedRights{}}
    case True{}:
      commit_delegate(state, alias, to_holder, rights)

def delegate_target(ok: Bool, +state: State, +alias: Alias, +to_holder: Nat, +effective: U32,
    +rights: U32) -> Change:
  match ok:
    case False{}:
      Rejected{state, SubjectMismatch{}}
    case True{}:
      delegate_rights(F.rights_valid(rights) && T.word_subset(rights, effective), state, alias,
        to_holder, rights)

# A delegatee the parent routes as a different subject on the object's
# service acts for that other subject there; handing it this subject's object
# would merge two subjects' authority, so it is SubjectMismatch. A delegatee
# with no route on that service (the same subject's worker) is admitted.
# holder_authorized repeats this check on every later use of the delegation.
def delegate_resolved(found: Resolved, +state: State, +to_holder: Nat, +rights: U32) -> Change:
  match found:
    case Unresolved{reason}:
      Rejected{state, reason}
    case Resolved{alias, +object, _, +effective, _}:
      delegate_target(Bool.not(routed_otherwise(routes(state), to_holder, object_owner(object),
          object_service(object))), state, alias, to_holder, effective, rights)

def delegate_checked(ok: Bool, +state: State, +alias_id: Nat, +from_holder: Nat, +to_holder: Nat,
    +rights: U32) -> Change:
  match ok:
    case False{}:
      Rejected{state, StaleRevision{}}
    case True{}:
      delegate_resolved(resolve(state, alias_id, from_holder), state, to_holder, rights)

# Public entry point: record a delegation from the alias `from_holder` holds to
# `to_holder`. This is a host-side record, not a Frontend grant: the delegatee
# still reaches Writ only through the bound handle, re-checked on every use.
# `from_holder` must hold the alias and be authorized for it under GA-005, and
# `to_holder` must not be routed by its parent as a different subject on the
# object's service, and `rights` must lie within the alias's effective rights,
# so a chain can only narrow (GA-006, GA-011). The change id is the
# delegatee's new alias. Denial order: StaleRevision, UnknownAlias (no such
# alias, or `from_holder` does not hold it), StaleGeneration, SubjectMismatch
# (`from_holder` unauthorized, then `to_holder` routed as another subject),
# WidenedRights (UnknownObject only for an unbound object).
def delegate(+state: State, expected_revision: Nat, +alias_id: Nat, +from_holder: Nat,
    +to_holder: Nat, +rights: U32) -> Change:
  delegate_checked(valid(state) && Nat.is_eq(revision(state), expected_revision), state, alias_id,
    from_holder, to_holder, rights)

# What a revocation cuts. CutAlias is one alias and its delegation subtree;
# CutObject is every alias to one object; CutHolder is every alias one domain
# holds. Each alias is matched together with every delegation below it.
type Cut is Data:
  CutAlias{alias: Nat}
  CutObject{object: Nat}
  CutHolder{holder: Nat}

def cut_alias(cut: Cut, +aliases: Aliases, +alias: Nat) -> Bool:
  match cut:
    case CutAlias{root}:
      Nat.is_eq(alias, root)
    case CutObject{object}:
      alias_names(aliases, alias, object)
    case CutHolder{holder}:
      alias_held(aliases, alias, holder)

def cut_object(cut: Cut, +aliases: Aliases, +object: Nat) -> Bool:
  match cut:
    case CutAlias{root}:
      alias_names(aliases, root, object)
    case CutObject{wanted}:
      Nat.is_eq(object, wanted)
    case CutHolder{holder}:
      holds_object(aliases, holder, object)

# Whether `alias` or one of its ancestors is cut. `valid` makes every parent
# id strictly smaller than its child's, so starting with fuel equal to the
# alias id reaches the root (parent 0n) before the fuel runs out.
def under_cut(fuel: Nat, +cut: Cut, +aliases: Aliases, +delegations: Delegations, +alias: Nat) -> Bool:
  match fuel:
    case 0n:
      cut_alias(cut, aliases, alias)
    case 1n+rest:
      cut_alias(cut, aliases, alias)
        || under_cut(rest, cut, aliases, delegations, parent_of(delegations, alias))

def keep_node(ok: Bool, node: Delegation, rest: Delegations) -> Delegations:
  match ok:
    case True{}:
      Delegations{node, rest}
    case False{}:
      rest

# Whether object `id` is cut or derived, directly or transitively, from a cut
# object. A derived object dies with its parent: its authority was reached
# through the parent, so destroying the parent must stale it as well. `valid`
# makes every derivation edge point to a smaller id, so fuel equal to the id
# reaches a root (derived_from 0n, never an object) before running out.
def doomed(fuel: Nat, +cut: Cut, +aliases: Aliases, +objects: Objects, +id: Nat) -> Bool:
  match fuel:
    case 0n:
      cut_object(cut, aliases, id)
    case 1n+rest:
      cut_object(cut, aliases, id) || doomed(rest, cut, aliases, objects, derived_of(objects, id))

def doomed_alias(+cut: Cut, +aliases: Aliases, +objects: Objects, +alias: Nat) -> Bool:
  doomed(alias_object_of(aliases, alias), cut, aliases, objects, alias_object_of(aliases, alias))

# Drop every node of `remaining` whose child alias is cut or lies below a cut
# alias, judged against the complete tree `tree` so descendants are found
# however the list is ordered. With `whole`, also drop every node whose child
# alias names an object that is being destroyed, so no record survives for a
# reference that is now stale. Aliases stay: they are stale, not forgotten.
def prune(remaining: Delegations, +cut: Cut, +aliases: Aliases, +objects: Objects,
    +tree: Delegations, +whole: Bool) -> Delegations:
  match remaining:
    case NoDelegations{}:
      NoDelegations{}
    case Delegations{+node, rest}:
      keep_node(Bool.not(under_cut(delegation_alias(node), cut, aliases, tree, delegation_alias(node))
          || (whole && doomed_alias(cut, aliases, objects, delegation_alias(node)))),
        node, prune(rest, cut, aliases, objects, tree, whole))

# Exported implementation helper, not an entry point and not a revocation:
# remove the delegation node of alias `root` and all its descendants, and
# nothing else. HAZARD: it drops nodes without bumping any generation, so the
# removed aliases stay current; their holders lose only the delegation basis
# for authority, and any copy or derived object stays reachable to a domain
# that is otherwise authorized. No transition calls it; revocation must go
# through commit_destroy, which destroys the objects and so stales every
# removed alias at once.
def remove_subtree(+delegations: Delegations, +aliases: Aliases, +objects: Objects, +root: Nat) -> Delegations:
  prune(delegations, CutAlias{root}, aliases, objects, delegations, False{})

# Exported helper, not a release API: named so LAWS.bend can state the bump.
def bumped(ok: Bool, object: Object) -> Object:
  match ok object:
    case True{} Object{id, generation, owner, kind, derived_from, service}:
      Object{id, 1n+generation, owner, kind, derived_from, service}
    case False{} object:
      object

# Destroy every cut object and every object derived from one by advancing its
# generation by one. Ids, owners, and kinds are kept, so ids are never reused
# and stale aliases still resolve to StaleGeneration rather than UnknownObject.
def destroy(objects: Objects, +cut: Cut, +aliases: Aliases, +all: Objects) -> Objects:
  match objects:
    case NoObjects{}:
      NoObjects{}
    case Objects{+object, rest}:
      Objects{bumped(doomed(object_id(object), cut, aliases, all, object_id(object)), object),
        destroy(rest, cut, aliases, all)}

# Whether object `object` still has a current alias, i.e. is live. Only a
# live object's destruction releases anything; destroying a stale object again
# releases nothing.
def current_alias_exists(aliases: Aliases, +object: Nat, +generation: Nat) -> Bool:
  match aliases:
    case NoAliases{}:
      False{}
    case Aliases{Alias{_, _, named, current}, rest}:
      (Nat.is_eq(named, object) && Nat.is_eq(current, generation))
        || current_alias_exists(rest, object, generation)

# Whether alias `wanted` was made by copying another alias to the same object.
# A copy was never charged a capability slot; a minted or derived alias was.
def copied(delegations: Delegations, +aliases: Aliases, +wanted: Nat, +object: Nat) -> Bool:
  match delegations:
    case NoDelegations{}:
      False{}
    case Delegations{Delegation{from_alias, _, _, alias}, rest}:
      (Nat.is_eq(alias, wanted) && alias_names(aliases, from_alias, object))
        || copied(rest, aliases, wanted, object)

def choose_holder(ok: Bool, holder: Nat, rest: Maybe<&2, Nat>) -> Maybe<&2, Nat>:
  match ok:
    case True{}:
      Some{holder}
    case False{}:
      rest

# The domain charged when `object` was minted: the holder of its alias that
# is not a copy. commit_mint creates exactly one such alias per object.
def minter(aliases: Aliases, +delegations: Delegations, +all: Aliases, +object: Nat) -> Maybe<&2, Nat>:
  match aliases:
    case NoAliases{}:
      None{}
    case Aliases{Alias{id, holder, named, _}, rest}:
      choose_holder(Nat.is_eq(named, object) && Bool.not(copied(delegations, all, id, object)), holder,
        minter(rest, delegations, all, object))

def add_one(ok: Bool, quota: Quota) -> Quota:
  match ok quota:
    case True{} Quota{domain, ram, caps}:
      Quota{domain, ram, 1n+caps}
    case False{} quota:
      quota

def give_cap(quotas: Quotas, +domain: Nat) -> Quotas:
  match quotas:
    case NoQuotas{}:
      NoQuotas{}
    case Quotas{+quota, rest}:
      Quotas{add_one(Nat.is_eq(quota_domain(quota), domain), quota), give_cap(rest, domain)}

def refund_one(ok: Bool, found: Maybe<&2, Nat>, quotas: Quotas) -> Quotas:
  match ok found:
    case True{} Some{holder}:
      give_cap(quotas, holder)
    case _ _:
      quotas

# Return the capability slot charged for each live object being destroyed to
# the domain that was charged when it was minted.
def refund(objects: Objects, +cut: Cut, +aliases: Aliases, +all: Objects, +delegations: Delegations,
    quotas: Quotas) -> Quotas:
  match objects:
    case NoObjects{}:
      quotas
    case Objects{+object, rest}:
      refund(rest, cut, aliases, all, delegations,
        refund_one(doomed(object_id(object), cut, aliases, all, object_id(object))
            && current_alias_exists(aliases, object_id(object), object_generation(object)),
          minter(aliases, delegations, aliases, object_id(object)), quotas))

# Exported implementation helper, not an entry point: it performs no check
# and is called only by bind_close (after F.close accepted the caller) and by
# revoke (after the revision gate). Destroy the cut objects and everything
# derived from them, release their capability charges, drop their delegation
# records, and install `next_frontend`, the Frontend state that accompanies
# the destruction (see close_doomed and revoke for which handles it closes).
# Returns `id`.
def commit_destroy(state: State, +next_frontend: F.State, +cut: Cut, +id: Nat) -> Change:
  match state:
    case State{revision, next_object, next_alias, +objects, +aliases, routes, quotas,
        +delegations, bindings, _}:
      Changed{State{1n+revision, next_object, next_alias, destroy(objects, cut, aliases, objects), aliases,
        routes, refund(objects, cut, aliases, objects, delegations, quotas),
        prune(delegations, cut, aliases, objects, delegations, True{}), bindings, next_frontend}, id}

def handle_open(found: Maybe<&2, F.Handle>) -> Bool:
  match found:
    case None{}:
      False{}
    case Some{F.Handle{_, _, _, _, _, _, _, _, closed}}:
      Bool.not(closed)

# A rejected close of a derived handle keeps the Frontend state it was given.
def close_kept(change: F.Change, +kept: F.State) -> F.State:
  match change:
    case F.Rejected{_}:
      kept
    case F.Changed{next, _}:
      next

def close_bound(ok: Bool, +current: F.State, +caller: F.Caller, +handle: Nat) -> F.State:
  match ok:
    case False{}:
      current
    case True{}:
      close_kept(F.close(current, F.revision(current), F.Ref{caller, handle}), current)

# Close, through F.close with the authenticated caller, the Frontend handle
# bound to every object `cut` dooms that is still open. F.open and F.dup copy
# the parent handle's subject and token into each derived handle, so the
# caller that closed the directly bound handle matches every handle derived
# from it. A handle that is already closed (including the directly bound one,
# closed just before) is skipped, and a rejected F.close leaves that handle
# as it was rather than turning the whole close into a denial: destruction
# has already been authorized, and no binding reaches a handle through a
# destroyed object. Folds left to right over the binding list, each F.close
# at the Frontend revision the previous one produced.
def close_doomed(bindings: Bindings, +cut: Cut, +aliases: Aliases, +objects: Objects, +caller: F.Caller,
    +current: F.State) -> F.State:
  match bindings:
    case NoBindings{}:
      current
    case Bindings{Binding{+object, +handle}, rest}:
      close_doomed(rest, cut, aliases, objects, caller,
        close_bound(doomed(object, cut, aliases, objects, object)
            && handle_open(F.find_handle(F.handles(current), handle)), current, caller, handle))

def close_frontend(change: F.Change, +state: State, +object: Nat, +caller: F.Caller) -> Change:
  match change:
    case F.Rejected{_}:
      Rejected{state, FrontendRejected{}}
    case F.Changed{next_frontend, _}:
      commit_destroy(state,
        close_doomed(bindings(state), CutObject{object}, aliases(state), objects(state), caller,
          next_frontend),
        CutObject{object}, object)

def minted_by(found: Maybe<&2, Nat>, +holder: Nat) -> Bool:
  match found:
    case None{}:
      False{}
    case Some{minted}:
      Nat.is_eq(minted, holder)

# Destroying an object is not an operation a delegated copy confers. `holder`
# may close the object only if its parent routes it as the object's subject on
# the object's service, or it is the domain charged when the object was minted
# (a delegatee may close a Descriptor it opened or attenuated itself). A
# domain whose only basis is a delegation node over a copy of the object can
# use the object within its delegated rights but cannot destroy it.
def close_authorized(+state: State, +object: Object, +holder: Nat) -> Bool:
  route_maps(routes(state), holder, object_owner(object), object_service(object))
    || minted_by(minter(aliases(state), delegations(state), aliases(state), object_id(object)), holder)

def close_gate(ok: Bool, +state: State, +object: Object, +handle: F.Handle, +caller: F.Caller) -> Change:
  match ok:
    case False{}:
      Rejected{state, SubjectMismatch{}}
    case True{}:
      close_frontend(
        F.close(frontend(state), F.revision(frontend(state)), F.Ref{caller, F.handle_id(handle)}),
        state, object_id(object), caller)

def close_resolved(found: Resolved, +state: State, +holder: Nat, +caller: F.Caller) -> Change:
  match found:
    case Unresolved{reason}:
      Rejected{state, reason}
    case Resolved{_, +object, +handle, _, _}:
      close_gate(close_authorized(state, object, holder), state, object, handle, caller)

def close_checked(ok: Bool, +state: State, +alias_id: Nat, +holder: Nat, +caller: F.Caller) -> Change:
  match ok:
    case False{}:
      Rejected{state, StaleRevision{}}
    case True{}:
      close_resolved(resolve(state, alias_id, holder), state, holder, caller)

# Public entry point: close the handle bound behind `alias_id` and destroy its
# native object. `holder` must hold the alias and pass GA-005 resolution, and
# must also be authorized to destroy (see close_authorized): routed as the
# object's subject on its service, or the object's minter; a delegated copy
# alone is SubjectMismatch. F.close must accept the authenticated caller for
# the bound handle (FrontendRejected otherwise, with nothing destroyed). On
# success the object's generation advances, so every alias to it in every
# domain is stale on next use. Every object derived from it, transitively, is
# destroyed with it and its still-open Frontend handle is closed with the
# same caller (see close_doomed); each live object's capability charge is
# returned, and every delegation node on those objects is removed. The change
# id is the destroyed object's id. Denial order: StaleRevision, UnknownAlias
# (no such alias, or `holder` does not hold it), StaleGeneration,
# SubjectMismatch (resolution, then destroy authority), FrontendRejected
# (UnknownObject only for an unbound object).
def bind_close(+state: State, expected_revision: Nat, +alias_id: Nat, +holder: Nat,
    +caller: F.Caller) -> Change:
  close_checked(valid(state) && Nat.is_eq(revision(state), expected_revision), state, alias_id,
    holder, caller)

def revoke_checked(ok: Bool, +state: State, +domain: Nat) -> Change:
  match ok:
    case False{}:
      Rejected{state, StaleRevision{}}
    case True{}:
      commit_destroy(state, frontend(state), CutHolder{domain}, domain)

# Public entry point: the monitor revokes every reference protection domain
# `domain` holds. Genode has no per-copy revoke: a capability is a reference
# to an object, and the only way to take a reference away is to destroy the
# object it names, which invalidates every copy in every domain at once. So
# revocation is keyed by holder and acts by destruction: each object `domain`
# holds an alias to, and every object derived from one, has its generation
# advanced; the delegation subtrees rooted at `domain`'s aliases and every
# node on a destroyed object are removed, and live objects' capability
# charges are returned. Other domains' aliases to those objects go stale too,
# including a delegator's object revoked through its delegatee's copy; that
# is the native semantics, not a side effect to hide. Frontend handles are
# left as they are: revoke has no authenticated Caller, and F.close requires
# one. No binding reaches those handles through a destroyed object, but
# closing or quarantining them at the Frontend layer (or revoking the
# registry grant behind them) is a HOST OBLIGATION, not something this model
# discharges. This is a monitor action with no caller authority to check; its
# only denial is StaleRevision. The change id is `domain`.
def revoke(+state: State, expected_revision: Nat, +domain: Nat) -> Change:
  revoke_checked(valid(state) && Nat.is_eq(revision(state), expected_revision), state, domain)
