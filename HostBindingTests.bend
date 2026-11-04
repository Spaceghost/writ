import Base
import ./HostBinding.bend as H
import ./Frontend.bend as F
import ./Transfer.bend as T
import ./TransferTests.bend as TF
import ./Test.bend as Test

# Scenario tests for the host-binding model, GA-001 through GA-011 of the
# genode-capability-adoption change, one named check per scenario outcome.
#
# Every fixture here is SYNTHETIC MONITOR STATE, not authentication. A real
# host constructs routes, quota accounts, alias holders, and the authenticated
# Caller from native state it trusts; these helpers only stand in for those
# facts so each transition's permitted and denied outcomes can be asserted.
# Domain ids and Writ subject ids are separate number spaces; a recorded route
# is the only link between them.
#
# Not tested here, by nature:
# - GA-010 (subject binding by topology) is a host obligation. A Genode server
#   learns which object was invoked, not who invoked it, so the model cannot
#   observe it; it is discharged by reviewed confinement evidence for each
#   qualified profile, never by a model test.
#
# GA-009 canonical vectors: after the check that asserts it, each vector-backed
# scenario prints one line `VECTOR <scenario-id> <transition> <outcome>
# <reason-or-id>`, rendered from the transition's actual result. The id field
# names only model ids (alias, object, or protection-domain numbers of this
# synthetic state), never a native selector. A host port replays the same
# inputs against its own binding and compares normalized outcomes; the inputs
# for each id are listed in openspec/traceability/genode-capability-adoption.md.
# verification/host-binding-vectors.txt holds the captured lines.

# --- Identities ------------------------------------------------------------

# The parent domain that imposes every route below.
def parent_domain() -> Nat:
  1n

# Reader R's protection domain. Its parent routes it as subject() on both
# services, so it is the only domain authorized by route.
def reader() -> Nat:
  7n

# Worker W and helper H: other domains acting for the same subject. They have
# no route of their own, so any authority they hold must come from a recorded
# delegation node. The worker_rerouted fixtures alone give W a route, as
# another subject, to show that such a route withdraws W's delegation.
def worker() -> Nat:
  8n

def helper() -> Nat:
  9n

# Domain S: the parent routes it as other_subject() on service(), so on that
# service it acts for a different subject than the reader's objects belong to.
def stranger() -> Nat:
  10n

# The Writ subject the parent's label prefix names for the reader.
def subject() -> Nat:
  7n

# The subject a client-chosen label suffix ("reader=S") would claim. The model
# does not represent the suffix, so S can only appear as a caller subject.
def other_subject() -> Nat:
  8n

def service() -> Nat:
  1n

def other_service() -> Nat:
  2n

# A service the parent never routed.
def unrouted_service() -> Nat:
  3n

# --- Rights ------------------------------------------------------------------

def read() -> U32:
  1

def read_write() -> U32:
  3

def all_rights() -> U32:
  7

# Outside Frontend's protocol bits; never a valid grant.
def unknown_right() -> U32:
  8

# --- Frontend authority (synthetic, mirrors FrontendTests) -------------------

def token() -> T.CodeId:
  T.CodeId{101, 102, 103, 104, 105, 106, 107, 108}

# The caller the monitor authenticated for an invocation. Frontend re-checks
# its subject and token against the bound handle on every use.
def caller(caller_subject: Nat) -> F.Caller:
  F.Caller{caller_subject, token()}

def reader_caller() -> F.Caller:
  caller(subject())

# The registry grants subject() every protocol right in epoch 3 until 180.
def registry() -> F.Registry:
  F.Registered{F.Capability{token(), subject(), TF.plan(), all_rights(), 3n, 180n}, F.EmptyRegistry{}}

def live() -> F.Live:
  F.Live{3n, 100n}

# --- Routes and quotas (synthetic parent configuration) -----------------------

# The parent routes the reader as subject() for service().
def reader_route() -> H.Route:
  H.Route{parent_domain(), reader(), service(), subject()}

# The same reader and subject, routed for a second service.
def reader_other_route() -> H.Route:
  H.Route{parent_domain(), reader(), other_service(), subject()}

# The parent's recorded route table: the reader on both services, nobody else.
def routes() -> H.Routes:
  H.Routes{reader_route(), H.Routes{reader_other_route(), H.NoRoutes{}}}

# A route table in which the parent routes the reader only for service().
def service_one_routes() -> H.Routes:
  H.Routes{reader_route(), H.NoRoutes{}}

# A route table in which the parent has withdrawn the reader's service()
# route and keeps only its other_service() route.
def service_two_routes() -> H.Routes:
  H.Routes{reader_other_route(), H.NoRoutes{}}

# The recorded table plus S routed as other_subject() on service().
def stranger_routes() -> H.Routes:
  H.Routes{H.Route{parent_domain(), stranger(), service(), other_subject()}, routes()}

# The recorded table plus W routed as other_subject() on service(): the parent
# reconfigured W after R delegated to it. No transition adds routes, so states
# using this table are hand-built from committed ones (see worker_rerouted).
def worker_rerouted_routes() -> H.Routes:
  H.Routes{H.Route{parent_domain(), worker(), service(), other_subject()}, routes()}

# The recorded table plus W routed as other_subject() on other_service() only.
def worker_other_service_routes() -> H.Routes:
  H.Routes{H.Route{parent_domain(), worker(), other_service(), other_subject()}, routes()}

def account(account_domain: Nat, caps: Nat) -> H.Quota:
  H.Quota{account_domain, 4096n, caps}

# Native quota accounts: the reader's capability slots are the scenario's
# variable; the worker and helper each have five.
def quotas(reader_slots: Nat) -> H.Quotas:
  H.Quotas{account(reader(), reader_slots), H.Quotas{account(worker(), 5n),
    H.Quotas{account(helper(), 5n), H.NoQuotas{}}}}

# An empty binding state with the recorded routes and the given reader quota.
def start(reader_slots: Nat) -> H.State:
  H.State{0n, 1n, 1n, H.NoObjects{}, H.NoAliases{}, routes(), quotas(reader_slots),
    H.NoDelegations{}, H.NoBindings{}, F.empty()}

# The parent reconfigured its route table; nothing else changed.
def with_routes(state: H.State, new_routes: H.Routes) -> H.State:
  match state:
    case H.State{r, o, a, objects, aliases, _, kept_quotas, delegations, bindings, frontend}:
      H.State{r, o, a, objects, aliases, new_routes, kept_quotas, delegations, bindings, frontend}

# The native quota accounts changed (exhausted or topped up); nothing else did.
def with_quotas(state: H.State, new_quotas: H.Quotas) -> H.State:
  match state:
    case H.State{r, o, a, objects, aliases, kept_routes, _, delegations, bindings, frontend}:
      H.State{r, o, a, objects, aliases, kept_routes, new_quotas, delegations, bindings, frontend}

# GA-005 premise: a domain holds a reference with no delegation record behind
# it (for example, it was passed outside the monitor). Structurally valid.
def without_delegations(state: H.State) -> H.State:
  match state:
    case H.State{r, o, a, objects, aliases, kept_routes, kept_quotas, _, bindings, frontend}:
      H.State{r, o, a, objects, aliases, kept_routes, kept_quotas, H.NoDelegations{}, bindings, frontend}

# GA-001 premise, using the scenario's literal generations: the reader's
# Session object 1 is at generation 4, alias 2 records generation 3 and is
# stale, and alias 1 records generation 4 and is current. Object 1 is bound to
# the mounted Frontend handle 1 in `frontend`. The state is structurally valid
# but no sequence of transitions reaches it (no transition issues an alias to
# an existing object at a later generation); staleness made by transitions is
# covered by GA-004 and GA-011.
def generations_state(frontend: F.State) -> H.State:
  H.State{1n, 2n, 3n, H.Objects{H.Object{1n, 4n, subject(), H.Session{}, 0n, service()}, H.NoObjects{}},
    H.Aliases{H.Alias{2n, reader(), 1n, 3n}, H.Aliases{H.Alias{1n, reader(), 1n, 4n}, H.NoAliases{}}},
    routes(), quotas(5n), H.NoDelegations{}, H.Bindings{H.Binding{1n, 1n}, H.NoBindings{}}, frontend}

# A state the monitor never committed: its only alias names a missing object.
def dangling_state() -> H.State:
  H.State{0n, 1n, 2n, H.NoObjects{}, H.Aliases{H.Alias{1n, reader(), 1n, 0n}, H.NoAliases{}},
    routes(), quotas(5n), H.NoDelegations{}, H.NoBindings{}, F.empty()}

# --- Structural equality -------------------------------------------------------
# GA-008 requires a denial to return the supplied state unchanged, so every
# field, including the embedded Frontend state, is compared exactly.

def bool_equal(a: Bool, b: Bool) -> Bool:
  match a b:
    case True{} True{}: True{}
    case False{} False{}: True{}
    case _ _: False{}

def kind_equal(a: H.ObjectKind, b: H.ObjectKind) -> Bool:
  match a b:
    case H.Session{} H.Session{}: True{}
    case H.Descriptor{} H.Descriptor{}: True{}
    case H.ResultChannel{} H.ResultChannel{}: True{}
    case _ _: False{}

def handle_kind_equal(a: F.HandleKind, b: F.HandleKind) -> Bool:
  match a b:
    case F.Mounted{} F.Mounted{}: True{}
    case F.Descriptor{} F.Descriptor{}: True{}
    case _ _: False{}

def object_equal(a: H.Object, b: H.Object) -> Bool:
  match a b:
    case H.Object{aid, agen, aown, akind, ader, asrv} H.Object{bid, bgen, bown, bkind, bder, bsrv}:
      Nat.is_eq(aid, bid) && Nat.is_eq(agen, bgen) && Nat.is_eq(aown, bown) && kind_equal(akind, bkind)
        && Nat.is_eq(ader, bder) && Nat.is_eq(asrv, bsrv)

def objects_equal(a: H.Objects, b: H.Objects) -> Bool:
  match a b:
    case H.NoObjects{} H.NoObjects{}:
      True{}
    case H.Objects{ah, at} H.Objects{bh, bt}:
      object_equal(ah, bh) && objects_equal(at, bt)
    case _ _:
      False{}

def alias_equal(a: H.Alias, b: H.Alias) -> Bool:
  match a b:
    case H.Alias{aid, ahold, aobj, agen} H.Alias{bid, bhold, bobj, bgen}:
      Nat.is_eq(aid, bid) && Nat.is_eq(ahold, bhold) && Nat.is_eq(aobj, bobj) && Nat.is_eq(agen, bgen)

def aliases_equal(a: H.Aliases, b: H.Aliases) -> Bool:
  match a b:
    case H.NoAliases{} H.NoAliases{}:
      True{}
    case H.Aliases{ah, at} H.Aliases{bh, bt}:
      alias_equal(ah, bh) && aliases_equal(at, bt)
    case _ _:
      False{}

def route_equal(a: H.Route, b: H.Route) -> Bool:
  match a b:
    case H.Route{ap, ac, asrv, asub} H.Route{bp, bc, bsrv, bsub}:
      Nat.is_eq(ap, bp) && Nat.is_eq(ac, bc) && Nat.is_eq(asrv, bsrv) && Nat.is_eq(asub, bsub)

def routes_equal(a: H.Routes, b: H.Routes) -> Bool:
  match a b:
    case H.NoRoutes{} H.NoRoutes{}:
      True{}
    case H.Routes{ah, at} H.Routes{bh, bt}:
      route_equal(ah, bh) && routes_equal(at, bt)
    case _ _:
      False{}

def quota_equal(a: H.Quota, b: H.Quota) -> Bool:
  match a b:
    case H.Quota{ad, aram, acaps} H.Quota{bd, bram, bcaps}:
      Nat.is_eq(ad, bd) && Nat.is_eq(aram, bram) && Nat.is_eq(acaps, bcaps)

def quotas_equal(a: H.Quotas, b: H.Quotas) -> Bool:
  match a b:
    case H.NoQuotas{} H.NoQuotas{}:
      True{}
    case H.Quotas{ah, at} H.Quotas{bh, bt}:
      quota_equal(ah, bh) && quotas_equal(at, bt)
    case _ _:
      False{}

def delegation_equal(a: H.Delegation, b: H.Delegation) -> Bool:
  match a b:
    case H.Delegation{afrom, ato, arights, aalias} H.Delegation{bfrom, bto, brights, balias}:
      Nat.is_eq(afrom, bfrom) && Nat.is_eq(ato, bto) && U32.is_eq(arights, brights)
        && Nat.is_eq(aalias, balias)

def delegations_equal(a: H.Delegations, b: H.Delegations) -> Bool:
  match a b:
    case H.NoDelegations{} H.NoDelegations{}:
      True{}
    case H.Delegations{ah, at} H.Delegations{bh, bt}:
      delegation_equal(ah, bh) && delegations_equal(at, bt)
    case _ _:
      False{}

def binding_equal(a: H.Binding, b: H.Binding) -> Bool:
  match a b:
    case H.Binding{aobj, ahandle} H.Binding{bobj, bhandle}:
      Nat.is_eq(aobj, bobj) && Nat.is_eq(ahandle, bhandle)

def bindings_equal(a: H.Bindings, b: H.Bindings) -> Bool:
  match a b:
    case H.NoBindings{} H.NoBindings{}:
      True{}
    case H.Bindings{ah, at} H.Bindings{bh, bt}:
      binding_equal(ah, bh) && bindings_equal(at, bt)
    case _ _:
      False{}

def handle_equal(a: F.Handle, b: F.Handle) -> Bool:
  match a b:
    case F.Handle{aid, akind, asub, atok, aplan, arights, aepoch, aexp, aclosed}
        F.Handle{bid, bkind, bsub, btok, bplan, brights, bepoch, bexp, bclosed}:
      Nat.is_eq(aid, bid) && handle_kind_equal(akind, bkind) && Nat.is_eq(asub, bsub)
        && T.CodeId.equal(atok, btok) && T.Plan.equal(aplan, bplan) && U32.is_eq(arights, brights)
        && Nat.is_eq(aepoch, bepoch) && Nat.is_eq(aexp, bexp) && bool_equal(aclosed, bclosed)

def handles_equal(a: F.Handles, b: F.Handles) -> Bool:
  match a b:
    case F.NoHandles{} F.NoHandles{}:
      True{}
    case F.Handles{ah, at} F.Handles{bh, bt}:
      handle_equal(ah, bh) && handles_equal(at, bt)
    case _ _:
      False{}

def frontend_equal(a: F.State, b: F.State) -> Bool:
  match a b:
    case F.State{arev, anext, ahandles} F.State{brev, bnext, bhandles}:
      Nat.is_eq(arev, brev) && Nat.is_eq(anext, bnext) && handles_equal(ahandles, bhandles)

# Exact structural equality of two binding states, every field compared.
def State.equal(a: H.State, b: H.State) -> Bool:
  match a b:
    case H.State{arev, aobjn, aalin, aobjs, aals, arts, aqs, ads, abs, afront}
        H.State{brev, bobjn, balin, bobjs, bals, brts, bqs, bds, bbs, bfront}:
      Nat.is_eq(arev, brev) && Nat.is_eq(aobjn, bobjn) && Nat.is_eq(aalin, balin)
        && objects_equal(aobjs, bobjs) && aliases_equal(aals, bals) && routes_equal(arts, brts)
        && quotas_equal(aqs, bqs) && delegations_equal(ads, bds) && bindings_equal(abs, bbs)
        && frontend_equal(afront, bfront)

# --- Outcome helpers -------------------------------------------------------------

# A denial with exactly `reason` that returned exactly `input` (GA-008). Every
# denial check in this module goes through this helper.
def denied(change: H.Change, input: H.State, reason: H.Error) -> Bool:
  match change:
    case H.Rejected{state, got}:
      H.Error.equal(got, reason) && State.equal(state, input)
    case H.Changed{_, _}:
      False{}

def issued_is(value: Maybe<&2, Nat>, expected: Nat) -> Bool:
  match value:
    case None{}:
      False{}
    case Some{id}:
      Nat.is_eq(id, expected)

# The effective rights the single authority path resolves for a holder.
def rights_are(found: H.Resolved, expected: U32) -> Bool:
  match found:
    case H.Unresolved{_}:
      False{}
    case H.Resolved{_, _, _, rights, _}:
      U32.is_eq(rights, expected)

def handle_rights_are(found: Maybe<&2, F.Handle>, expected: U32) -> Bool:
  match found:
    case None{}:
      False{}
    case Some{handle}:
      U32.is_eq(F.handle_rights(handle), expected)

def handle_closed(found: Maybe<&2, F.Handle>) -> Bool:
  match found:
    case None{}:
      False{}
    case Some{F.Handle{_, _, _, _, _, _, _, _, closed}}:
      closed

def handle_mounted(found: Maybe<&2, F.Handle>) -> Bool:
  match found:
    case None{}:
      False{}
    case Some{handle}:
      F.is_mount(handle)

def object_is(found: Maybe<&2, H.Object>, kind: H.ObjectKind, owner: Nat, wanted_service: Nat) -> Bool:
  match found:
    case None{}:
      False{}
    case Some{H.Object{_, _, got_owner, got_kind, _, got_service}}:
      kind_equal(got_kind, kind) && Nat.is_eq(got_owner, owner) && Nat.is_eq(got_service, wanted_service)

def alias_is(found: Maybe<&2, H.Alias>, expected: H.Alias) -> Bool:
  match found:
    case None{}:
      False{}
    case Some{alias}:
      alias_equal(alias, expected)

def object_count(objects: H.Objects) -> Nat:
  match objects:
    case H.NoObjects{}:
      0n
    case H.Objects{_, rest}:
      1n+object_count(rest)

def delegation_count(delegations: H.Delegations) -> Nat:
  match delegations:
    case H.NoDelegations{}:
      0n
    case H.Delegations{_, rest}:
      1n+delegation_count(rest)

def handle_count(handles: F.Handles) -> Nat:
  match handles:
    case F.NoHandles{}:
      0n
    case F.Handles{_, rest}:
      1n+handle_count(rest)

def frontend_handles(state: H.State) -> Nat:
  handle_count(F.handles(H.frontend(state)))

# Capability slots left in `wanted_domain`'s account; 0n when it has no account.
def caps_of(accounts: H.Quotas, +wanted_domain: Nat) -> Nat:
  match accounts:
    case H.NoQuotas{}:
      0n
    case H.Quotas{H.Quota{owner, _, caps}, rest}:
      H.pick_nat(Nat.is_eq(owner, wanted_domain), caps, caps_of(rest, wanted_domain))

def reader_caps(state: H.State) -> Nat:
  caps_of(H.quotas(state), reader())

def worker_caps(state: H.State) -> Nat:
  caps_of(H.quotas(state), worker())

def frontend_handle(state: H.State, id: Nat) -> Maybe<&2, F.Handle>:
  F.find_handle(F.handles(H.frontend(state)), id)

# --- Canonical vectors (GA-009) ------------------------------------------------
# Rendered from the actual Change, so a vector can only differ from a run if the
# transition's outcome differs. Denials print the closed-type constructor name;
# commits print the model id the change produced (see each transition's
# documentation in HostBinding.bend for which id that is).

def reason_name(reason: H.Error) -> String:
  match reason:
    case H.StaleGeneration{}: "StaleGeneration"
    case H.RouteMismatch{}: "RouteMismatch"
    case H.SubjectMismatch{}: "SubjectMismatch"
    case H.WidenedRights{}: "WidenedRights"
    case H.QuotaExhausted{}: "QuotaExhausted"
    case H.UnknownObject{}: "UnknownObject"
    case H.UnknownAlias{}: "UnknownAlias"
    case H.FrontendRejected{}: "FrontendRejected"
    case H.StaleRevision{}: "StaleRevision"

# mount, open, attenuate, and delegate issue an alias. The object it names is
# printed too, so a host that returns an alias to the parent object (GA-003)
# or mints an object for a delegated copy (GA-006) disagrees with the vector.
def alias_outcome(change: H.Change) -> String:
  match change:
    case H.Rejected{_, reason}:
      "denied " ++ reason_name(reason)
    case H.Changed{state, +id}:
      "accepted alias=" ++ Nat.show(id) ++ ";object=" ++ Nat.show(H.alias_object_of(H.aliases(state), id))

# bind_close reports the destroyed object's id.
def close_outcome(change: H.Change) -> String:
  match change:
    case H.Rejected{_, reason}:
      "denied " ++ reason_name(reason)
    case H.Changed{_, id}:
      "accepted object=" ++ Nat.show(id)

# revoke reports the revoked protection domain's id.
def revoke_outcome(change: H.Change) -> String:
  match change:
    case H.Rejected{_, reason}:
      "denied " ++ reason_name(reason)
    case H.Changed{_, id}:
      "accepted domain=" ++ Nat.show(id)

def vector(scenario: String, transition: String, outcome: String) -> IO(Unit):
  IO.print("VECTOR " ++ scenario ++ " " ++ transition ++ " " ++ outcome)

# --- Scenario states ------------------------------------------------------------
# Each is a named sequence of committed transitions from initial(); later
# fixtures build on earlier ones, so revision numbers below follow this chain.

def initial() -> H.State:
  start(5n)

# Reader mounts service() on its recorded route: alias 1, Session object 1,
# Frontend handle 1. Revision 1.
def mount_change() -> H.Change:
  H.bind_mount(initial(), 0n, reader_route(), reader_caller(), registry(), all_rights(), live())

def mounted() -> H.State:
  H.Change.state(mount_change())

# Reader opens a descriptor from its Session: alias 2, object 2 derived from
# object 1, handle 2 with every right. Revision 2.
def open_change() -> H.Change:
  H.bind_open(mounted(), 1n, 1n, reader(), reader_caller(), registry(), all_rights(), live())

def opened() -> H.State:
  H.Change.state(open_change())

# Reader attenuates its descriptor to read: alias 3, object 3, handle 3 made by
# F.dup and then F.attenuate, so handle 2 keeps every right. Revision 3.
def attenuate_change() -> H.Change:
  H.bind_attenuate(opened(), 2n, 2n, reader(), reader_caller(), registry(), read(), live())

def attenuated() -> H.State:
  H.Change.state(attenuate_change())

# R delegates its attenuated read-only descriptor to worker W with read: alias
# 4 is a copy of object 3 recorded under alias 3. Revision 4.
def attenuated_copy_change() -> H.Change:
  H.delegate(attenuated(), 3n, 3n, reader(), worker(), read())

def attenuated_shared() -> H.State:
  H.Change.state(attenuated_copy_change())

# R delegates its descriptor to worker W with read: alias 3 is a copy of
# object 2 recorded under alias 2. Revision 3.
def copy_change() -> H.Change:
  H.delegate(opened(), 2n, 2n, reader(), worker(), read())

def shared() -> H.State:
  H.Change.state(copy_change())

# W delegates on to helper H with read: alias 4, recorded under alias 3, so
# the tree is R (alias 2) -> W (alias 3) -> H (alias 4). Revision 4.
def chain_change() -> H.Change:
  H.delegate(shared(), 3n, 3n, worker(), helper(), read())

def chain() -> H.State:
  H.Change.state(chain_change())

# W attenuates through its delegated alias: alias 4 on object 3, derived from
# object 2 and recorded under W's node. The authenticated caller is subject(),
# for which W acts. Revision 4.
def worker_derive_change() -> H.Change:
  H.bind_attenuate(shared(), 3n, 3n, worker(), reader_caller(), registry(), read(), live())

def derived() -> H.State:
  H.Change.state(worker_derive_change())

# R delegates its Session to W with read: alias 2. Revision 2.
def session_copy_change() -> H.Change:
  H.delegate(mounted(), 1n, 1n, reader(), worker(), read())

def session_shared() -> H.State:
  H.Change.state(session_copy_change())

# W opens a read descriptor through the delegated Session: alias 3 on object 2,
# derived from the Session and recorded under W's node. Revision 3.
def worker_open_change() -> H.Change:
  H.bind_open(session_shared(), 2n, 2n, worker(), reader_caller(), registry(), read(), live())

def worker_opened() -> H.State:
  H.Change.state(worker_open_change())

# The reader mounted on its second route: a Session on other_service().
def other_mounted() -> H.State:
  H.Change.state(H.bind_mount(initial(), 0n, reader_other_route(), reader_caller(), registry(),
    all_rights(), live()))

# The parent then withdraws the reader's other_service() route.
def rerouted() -> H.State:
  with_routes(other_mounted(), service_one_routes())

# Object 1 at generation 4 with a stale and a current alias (see
# generations_state), bound to the mounted Frontend handle.
def generations() -> H.State:
  generations_state(H.frontend(mounted()))

# After mount the reader's capability slots are exhausted.
def exhausted() -> H.State:
  with_quotas(mounted(), quotas(0n))

def quota_open() -> H.Change:
  H.bind_open(exhausted(), 1n, 1n, reader(), reader_caller(), registry(), all_rights(), live())

# The denied state with one slot topped up; the revision did not advance.
def topped_up() -> H.State:
  with_quotas(H.Change.state(quota_open()), quotas(1n))

def retry() -> H.Change:
  H.bind_open(topped_up(), 1n, 1n, reader(), reader_caller(), registry(), all_rights(), live())

# R closes the descriptor that R and W both hold. Revision 4.
def shared_closed() -> H.State:
  H.Change.state(H.bind_close(shared(), 3n, 2n, reader(), reader_caller()))

# The two-level chain cut by revoking R's domain, or by R closing object 2.
# Revision 5.
def chain_revoked() -> H.State:
  H.Change.state(H.revoke(chain(), 4n, reader()))

def chain_closed() -> H.State:
  H.Change.state(H.bind_close(chain(), 4n, 2n, reader(), reader_caller()))

# W's derived object 3 after its parent object 2 is closed or R is revoked.
# Revision 5.
def derived_closed() -> H.State:
  H.Change.state(H.bind_close(derived(), 4n, 2n, reader(), reader_caller()))

def derived_revoked() -> H.State:
  H.Change.state(H.revoke(derived(), 4n, reader()))

# W holds alias 3 with its delegation record removed (GA-005 premise).
def forged_holder() -> H.State:
  without_delegations(shared())

# R delegated its Session to W (and W opened through it); the parent then
# withdrew R's service() route. Nothing else changed.
def session_unrouted() -> H.State:
  with_routes(session_shared(), service_two_routes())

def worker_opened_unrouted() -> H.State:
  with_routes(worker_opened(), service_two_routes())

# R's descriptor and Session states with S routed as another subject.
def stranger_opened() -> H.State:
  with_routes(opened(), stranger_routes())

def stranger_other_mounted() -> H.State:
  with_routes(other_mounted(), stranger_routes())

# R delegated its Session to W (and W opened through it); the parent then
# routed W as other_subject() on service(). Hand-built from a committed state
# by replacing only the route table; `valid` checks no route field, so it
# holds, and the GA-005 checks assert it.
def worker_rerouted() -> H.State:
  with_routes(session_shared(), worker_rerouted_routes())

def worker_opened_rerouted() -> H.State:
  with_routes(worker_opened(), worker_rerouted_routes())

# As worker_rerouted, but W's new route is on other_service().
def worker_other_routed() -> H.State:
  with_routes(session_shared(), worker_other_service_routes())

# R's Session before any delegation, with W already routed as another subject.
def mounted_worker_rerouted() -> H.State:
  with_routes(mounted(), worker_rerouted_routes())

# R closes its Session in attenuated(): Session 1, descriptor 2 opened from it,
# and descriptor 3 attenuated from descriptor 2. Revision 4.
def session_close() -> H.Change:
  H.bind_close(attenuated(), 3n, 1n, reader(), reader_caller())

def session_closed() -> H.State:
  H.Change.state(session_close())

# The monitor revokes W's domain in shared(), where W holds only a copy of
# R's descriptor object 2. Revision 4.
def delegatee_revoke() -> H.Change:
  H.revoke(shared(), 3n, worker())

def delegatee_revoked() -> H.State:
  H.Change.state(delegatee_revoke())

# --- Named transitions behind vectors --------------------------------------------
# Each is used by exactly the check that asserts it and by its VECTOR line, so
# the printed outcome and the asserted one come from the same inputs.

def stale_open() -> H.Change:
  H.bind_open(generations(), 1n, 2n, reader(), reader_caller(), registry(), read(), live())

def current_open() -> H.Change:
  H.bind_open(generations(), 1n, 1n, reader(), reader_caller(), registry(), read(), live())

def suffix_mount() -> H.Change:
  H.bind_mount(initial(), 0n, reader_route(), caller(other_subject()), registry(), all_rights(), live())

def unrecorded_mount() -> H.Change:
  H.bind_mount(initial(), 0n, H.Route{parent_domain(), reader(), service(), other_subject()}, caller(other_subject()), registry(), all_rights(), live())

def rerouted_open() -> H.Change:
  H.bind_open(rerouted(), 1n, 1n, reader(), reader_caller(), registry(), all_rights(), live())

def guessed_open() -> H.Change:
  H.bind_open(opened(), 2n, 99n, reader(), reader_caller(), registry(), read(), live())

def shared_close() -> H.Change:
  H.bind_close(shared(), 3n, 2n, reader(), reader_caller())

def owner_after_close() -> H.Change:
  H.delegate(shared_closed(), 4n, 2n, reader(), helper(), read())

def holder_after_close() -> H.Change:
  H.delegate(shared_closed(), 4n, 3n, worker(), helper(), read())

def stale_revision_close() -> H.Change:
  H.bind_close(shared(), 2n, 2n, reader(), reader_caller())

def unrecorded_attenuate() -> H.Change:
  H.bind_attenuate(forged_holder(), 3n, 3n, worker(), reader_caller(), registry(), read(), live())

def non_holder_open() -> H.Change:
  H.bind_open(mounted(), 1n, 1n, worker(), reader_caller(), registry(), read(), live())

def widened_delegate() -> H.Change:
  H.delegate(attenuated(), 3n, 3n, reader(), worker(), read_write())

def quota_before_authority() -> H.Change:
  H.bind_open(exhausted(), 1n, 1n, reader(), caller(other_subject()), registry(), all_rights(), live())

def stale_revision_mount() -> H.Change:
  H.bind_mount(mounted(), 0n, reader_route(), reader_caller(), registry(), all_rights(), live())

def rejected_mount() -> H.Change:
  H.bind_mount(initial(), 0n, reader_route(), reader_caller(), registry(), unknown_right(), live())

def invalid_mount() -> H.Change:
  H.bind_mount(dangling_state(), 0n, reader_route(), reader_caller(), registry(), all_rights(), live())

def chain_revoke() -> H.Change:
  H.revoke(chain(), 4n, reader())

def worker_after_revoke() -> H.Change:
  H.delegate(chain_revoked(), 5n, 3n, worker(), helper(), read())

def helper_after_revoke() -> H.Change:
  H.delegate(chain_revoked(), 5n, 4n, helper(), worker(), read())

def wider_child() -> H.Change:
  H.delegate(shared(), 3n, 3n, worker(), helper(), read_write())

def derived_after_close() -> H.Change:
  H.bind_attenuate(derived_closed(), 5n, 4n, worker(), reader_caller(), registry(), read(), live())

# F.open opens only from a mount, so opening from a Descriptor alias passes
# every binding gate and is refused by Frontend.
def descriptor_open() -> H.Change:
  H.bind_open(opened(), 2n, 2n, reader(), reader_caller(), registry(), read(), live())

# W holds a read copy of R's Session alias and tries to destroy the Session.
def delegatee_close() -> H.Change:
  H.bind_close(session_shared(), 2n, 2n, worker(), reader_caller())

# W closes the descriptor it opened itself through the delegated Session.
def minter_close() -> H.Change:
  H.bind_close(worker_opened(), 3n, 3n, worker(), reader_caller())

def session_stale_descriptor() -> H.Change:
  H.delegate(session_closed(), 4n, 3n, reader(), worker(), read())

def withdrawn_open() -> H.Change:
  H.bind_open(session_unrouted(), 2n, 2n, worker(), reader_caller(), registry(), read(), live())

def stranger_delegate() -> H.Change:
  H.delegate(stranger_opened(), 2n, 2n, reader(), stranger(), read())

# W opens through its delegated Session after the parent routed it as
# another subject on the Session's service.
def rerouted_delegatee_open() -> H.Change:
  H.bind_open(worker_rerouted(), 2n, 2n, worker(), reader_caller(), registry(), read(), live())

def delegator_after_delegatee_revoke() -> H.Change:
  H.delegate(delegatee_revoked(), 4n, 2n, reader(), helper(), read())

# The equality and denial helpers must discriminate, or every denial check
# below would pass vacuously.
def helper_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(H.valid(initial()), "binding fixture state is valid")
    Test.check(State.equal(opened(), opened()) && Bool.not(State.equal(mounted(), opened())), "state equality separates a committed change from its input")
    Test.check(Bool.not(State.equal(mounted(), with_quotas(mounted(), quotas(5n)))), "state equality sees a single quota field")
    Test.check(Bool.not(State.equal(generations_state(H.frontend(mounted())), generations_state(H.frontend(opened())))), "state equality sees the embedded Frontend state")
    Test.check(Bool.not(denied(H.bind_close(shared(), 2n, 2n, reader(), reader_caller()), shared(), H.FrontendRejected{})), "denial checks assert the exact reason")

# GA-001 Native objects carry a generation.
def ga001_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(H.valid(generations()), "GA-001 generation fixture is a valid state")
    Test.check(denied(stale_open(), generations(), H.StaleGeneration{}), "GA-001 alias at generation 3 on object at generation 4 denied StaleGeneration")
    vector("GA-001-1", "bind_open", alias_outcome(stale_open()))
    Test.check(denied(H.delegate(generations(), 1n, 2n, reader(), worker(), read()), generations(), H.StaleGeneration{}), "GA-001 stale alias cannot be delegated")
    Test.check(denied(H.bind_close(generations(), 1n, 2n, reader(), reader_caller()), generations(), H.StaleGeneration{}), "GA-001 stale alias cannot close the current object")
    Test.check(H.Change.accepted(current_open()), "GA-001 alias at current generation 4 proceeds")
    vector("GA-001-2", "bind_open", alias_outcome(current_open()))
    Test.check(denied(H.bind_open(generations(), 1n, 1n, reader(), caller(other_subject()), registry(), read(), live()), generations(), H.FrontendRejected{}), "GA-001 current alias reaches the Frontend check")

# GA-002 Mount binds through a parent route. The client-chosen label suffix
# is not represented, so "reader=S" can only arrive as a caller for S.
def ga002_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(H.Change.accepted(mount_change()), "GA-002 mount on a recorded route naming the caller succeeds")
    vector("GA-002-1", "bind_mount", alias_outcome(mount_change()))
    Test.check(issued_is(H.Change.issued(mount_change()), 1n), "GA-002 mount issues the first alias id")
    Test.check(object_is(H.find_object(H.objects(mounted()), 1n), H.Session{}, subject(), service()), "GA-002 mount mints a Session owned by the route subject on the route service")
    Test.check(H.alias_held(H.aliases(mounted()), 1n, reader()), "GA-002 the routed child domain holds the Session alias")
    Test.check(issued_is(H.find_binding(H.bindings(mounted()), 1n), 1n), "GA-002 the Session is bound to the new Frontend handle")
    Test.check(handle_mounted(frontend_handle(mounted(), 1n)) && Nat.is_eq(F.revision(H.frontend(mounted())), 1n), "GA-002 Frontend.mount was applied")
    Test.check(H.valid(mounted()), "GA-002 mount preserves binding validity")
    Test.check(denied(suffix_mount(), initial(), H.RouteMismatch{}), "GA-002 route prefix naming R mounted for caller S denied RouteMismatch")
    vector("GA-002-2", "bind_mount", alias_outcome(suffix_mount()))
    Test.check(denied(unrecorded_mount(), initial(), H.RouteMismatch{}), "GA-002 a presented route the parent never recorded denied RouteMismatch")
    vector("GA-002-3", "bind_mount", alias_outcome(unrecorded_mount()))
    Test.check(denied(H.bind_mount(initial(), 0n, H.Route{parent_domain(), reader(), unrouted_service(), subject()}, reader_caller(), registry(), all_rights(), live()), initial(), H.RouteMismatch{}), "GA-002 route for an unrouted service denied RouteMismatch")
    Test.check(H.Change.accepted(H.bind_open(other_mounted(), 1n, 1n, reader(), reader_caller(), registry(), all_rights(), live())), "GA-002 Session on the second service opens under its own route")
    Test.check(H.valid(rerouted()), "GA-002 route withdrawal fixture is a valid state")
    Test.check(denied(rerouted_open(), rerouted(), H.SubjectMismatch{}), "GA-002 a route on another service does not authorize the holder")
    vector("GA-002-4", "bind_open", alias_outcome(rerouted_open()))

# GA-003 Open and attenuate mint new objects.
def ga003_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(H.Change.accepted(open_change()) && issued_is(H.Change.issued(open_change()), 2n), "GA-003 open from the Session issues a new alias")
    vector("GA-003-1", "bind_open", alias_outcome(open_change()))
    Test.check(Bool.not(Nat.is_eq(H.alias_object_of(H.aliases(opened()), 2n), H.alias_object_of(H.aliases(opened()), 1n))), "GA-003 opened alias names a distinct object")
    Test.check(object_is(H.find_object(H.objects(opened()), 2n), H.Descriptor{}, subject(), service()) && Nat.is_eq(object_count(H.objects(opened())), 2n), "GA-003 open mints a Descriptor object")
    Test.check(issued_is(H.find_binding(H.bindings(opened()), 2n), 2n), "GA-003 the new object is bound to the new handle")
    Test.check(alias_is(H.find_alias(H.aliases(opened()), 1n), H.Alias{1n, reader(), 1n, 0n}), "GA-003 the Session alias is unaffected by open")
    Test.check(H.Change.accepted(H.bind_open(opened(), 2n, 1n, reader(), reader_caller(), registry(), read(), live())), "GA-003 the Session alias still opens after open")
    Test.check(H.valid(opened()), "GA-003 open preserves binding validity")
    Test.check(H.Change.accepted(attenuate_change()) && issued_is(H.Change.issued(attenuate_change()), 3n), "GA-003 attenuate issues a new alias")
    Test.check(Nat.is_eq(H.alias_object_of(H.aliases(attenuated()), 3n), 3n) && issued_is(H.find_binding(H.bindings(attenuated()), 3n), 3n), "GA-003 attenuate mints a distinct object bound to a distinct handle")
    vector("GA-003-2", "bind_attenuate", alias_outcome(attenuate_change()))
    Test.check(handle_rights_are(frontend_handle(attenuated(), 2n), all_rights()), "GA-003 attenuate leaves the parent Frontend handle rights intact")
    Test.check(handle_rights_are(frontend_handle(attenuated(), 3n), read()), "GA-003 the attenuated Frontend handle carries only read")
    Test.check(rights_are(H.resolve(attenuated(), 2n, reader()), all_rights()) && rights_are(H.resolve(attenuated(), 3n, reader()), read()), "GA-003 parent alias keeps its rights and the copy gets the narrower rights")
    Test.check(alias_is(H.find_alias(H.aliases(attenuated()), 2n), H.Alias{2n, reader(), 2n, 0n}), "GA-003 the parent descriptor alias is unaffected by attenuate")
    Test.check(H.valid(attenuated()), "GA-003 attenuate preserves binding validity")
    Test.check(denied(H.bind_attenuate(mounted(), 1n, 1n, reader(), reader_caller(), registry(), read(), live()), mounted(), H.FrontendRejected{}), "GA-003 attenuating a Session alias denied FrontendRejected")
    Test.check(denied(H.bind_attenuate(opened(), 2n, 2n, reader(), reader_caller(), registry(), unknown_right(), live()), opened(), H.WidenedRights{}), "GA-003 attenuate outside the protocol rights denied WidenedRights")
    Test.check(denied(guessed_open(), opened(), H.UnknownAlias{}), "GA-003 open through an unknown alias denied UnknownAlias")
    vector("GA-003-3", "bind_open", alias_outcome(guessed_open()))
    Test.check(denied(descriptor_open(), opened(), H.FrontendRejected{}), "GA-003 open through a Descriptor alias denied FrontendRejected")
    vector("GA-003-4", "bind_open", alias_outcome(descriptor_open()))

# GA-004 Close destroys and invalidates all aliases.
def ga004_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(H.Change.accepted(shared_close()), "GA-004 owner closes a descriptor held by two domains")
    vector("GA-004-1", "bind_close", close_outcome(shared_close()))
    Test.check(denied(owner_after_close(), shared_closed(), H.StaleGeneration{}), "GA-004 after close the owner's alias is stale")
    vector("GA-004-2", "delegate", alias_outcome(owner_after_close()))
    Test.check(denied(holder_after_close(), shared_closed(), H.StaleGeneration{}), "GA-004 after close the second holder's alias is stale")
    vector("GA-004-3", "delegate", alias_outcome(holder_after_close()))
    Test.check(handle_closed(frontend_handle(shared_closed(), 2n)), "GA-004 close applies Frontend.close to the bound handle")
    Test.check(H.Change.accepted(H.bind_open(shared_closed(), 4n, 1n, reader(), reader_caller(), registry(), read(), live())), "GA-004 close leaves the parent Session usable")
    Test.check(H.valid(shared_closed()), "GA-004 close preserves binding validity")
    Test.check(denied(stale_revision_close(), shared(), H.StaleRevision{}), "GA-004 close at a stale revision destroys nothing and leaves state unchanged")
    vector("GA-004-4", "bind_close", close_outcome(stale_revision_close()))
    Test.check(denied(H.bind_close(shared(), 3n, 2n, reader(), caller(other_subject())), shared(), H.FrontendRejected{}), "GA-004 close Frontend rejects destroys nothing")
    Test.check(denied(H.bind_close(shared(), 3n, 2n, helper(), reader_caller()), shared(), H.UnknownAlias{}), "GA-004 a domain without the alias cannot close it and is told UnknownAlias")
    Test.check(denied(H.bind_close(shared_closed(), 4n, 3n, helper(), reader_caller()), shared_closed(), H.UnknownAlias{}), "GA-004 a non-holder of a destroyed alias is told UnknownAlias, not StaleGeneration")
    Test.check(denied(delegatee_close(), session_shared(), H.SubjectMismatch{}), "GA-004 a delegatee holding a read copy of the Session cannot destroy it")
    vector("GA-004-5", "bind_close", close_outcome(delegatee_close()))
    Test.check(denied(H.bind_close(shared(), 3n, 3n, worker(), reader_caller()), shared(), H.SubjectMismatch{}), "GA-004 a delegatee holding a copy of a descriptor cannot destroy it")
    Test.check(H.Change.accepted(minter_close()) && issued_is(H.Change.issued(minter_close()), 2n), "GA-004 a delegatee may close the descriptor it opened itself")
    vector("GA-004-6", "bind_close", close_outcome(minter_close()))
    Test.check(H.Change.accepted(session_close()) && issued_is(H.Change.issued(session_close()), 1n), "GA-004 closing a Session with a two-level derivation below it commits")
    vector("GA-004-7", "bind_close", close_outcome(session_close()))
    Test.check(handle_closed(frontend_handle(session_closed(), 1n)) && handle_closed(frontend_handle(session_closed(), 2n)) && handle_closed(frontend_handle(session_closed(), 3n)), "GA-004 closing a Session closes every derived descriptor's Frontend handle")
    Test.check(denied(H.delegate(session_closed(), 4n, 1n, reader(), worker(), read()), session_closed(), H.StaleGeneration{}), "GA-004 after a Session close the Session alias is stale")
    Test.check(denied(H.delegate(session_closed(), 4n, 2n, reader(), worker(), read()), session_closed(), H.StaleGeneration{}), "GA-004 after a Session close the opened descriptor alias is stale")
    Test.check(denied(session_stale_descriptor(), session_closed(), H.StaleGeneration{}), "GA-004 after a Session close the attenuated descriptor alias is stale")
    vector("GA-004-8", "delegate", alias_outcome(session_stale_descriptor()))
    Test.check(H.valid(session_closed()) && Nat.is_eq(reader_caps(session_closed()), 5n), "GA-004 a Session close stays valid and refunds all three objects")
    Test.check(H.Change.accepted(H.bind_close(shared_closed(), 4n, 1n, reader(), reader_caller())) && handle_closed(frontend_handle(H.Change.state(H.bind_close(shared_closed(), 4n, 1n, reader(), reader_caller())), 1n)), "GA-004 a Session close skips a derived handle that was already closed")

# GA-005 Possession is not the subject in the model.
def ga005_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(H.valid(forged_holder()), "GA-005 holder-without-record fixture is a valid state")
    Test.check(denied(unrecorded_attenuate(), forged_holder(), H.SubjectMismatch{}), "GA-005 alias held by Q with no delegation record denied SubjectMismatch")
    vector("GA-005-1", "bind_attenuate", alias_outcome(unrecorded_attenuate()))
    Test.check(denied(H.delegate(forged_holder(), 3n, 3n, worker(), helper(), read()), forged_holder(), H.SubjectMismatch{}), "GA-005 unrecorded holder cannot delegate onward")
    Test.check(denied(non_holder_open(), mounted(), H.UnknownAlias{}), "GA-005 a domain that does not hold the alias denied UnknownAlias")
    vector("GA-005-2", "bind_open", alias_outcome(non_holder_open()))
    Test.check(H.Change.accepted(worker_derive_change()), "GA-005 recorded delegation to the worker is accepted")
    vector("GA-005-3", "bind_attenuate", alias_outcome(worker_derive_change()))
    Test.check(H.Change.accepted(session_copy_change()) && H.Change.accepted(worker_open_change()), "GA-005 delegatee opens through a delegated Session")
    Test.check(H.Change.accepted(H.bind_attenuate(worker_opened(), 3n, 3n, worker(), reader_caller(), registry(), read(), live())), "GA-005 the delegatee's opened alias is usable")
    Test.check(rights_are(H.resolve(worker_opened(), 3n, worker()), read()), "GA-005 the delegatee's opened alias resolves within the record")
    Test.check(denied(H.bind_open(session_shared(), 2n, 2n, worker(), reader_caller(), registry(), read_write(), live()), session_shared(), H.WidenedRights{}), "GA-005 the delegatee is accepted only within the delegated scope")
    Test.check(H.valid(worker_opened()) && H.valid(derived()), "GA-005 delegatee derivations preserve binding validity")
    Test.check(H.Change.accepted(worker_open_change()), "GA-005 while R's route stands the delegatee opens through the delegated Session")
    vector("GA-005-4", "bind_open", alias_outcome(worker_open_change()))
    Test.check(H.valid(session_unrouted()), "GA-005 route withdrawal after delegation fixture is a valid state")
    Test.check(denied(withdrawn_open(), session_unrouted(), H.SubjectMismatch{}), "GA-005 withdrawing the delegator's route withdraws the delegatee's authority")
    vector("GA-005-5", "bind_open", alias_outcome(withdrawn_open()))
    Test.check(denied(H.bind_attenuate(worker_opened_unrouted(), 3n, 3n, worker(), reader_caller(), registry(), read(), live()), worker_opened_unrouted(), H.SubjectMismatch{}), "GA-005 route withdrawal also withdraws the delegatee's derived alias")
    Test.check(denied(stranger_delegate(), stranger_opened(), H.SubjectMismatch{}), "GA-005 delegation to a domain routed as another subject on the service denied SubjectMismatch")
    vector("GA-005-6", "delegate", alias_outcome(stranger_delegate()))
    Test.check(H.Change.accepted(H.delegate(stranger_opened(), 2n, 2n, reader(), worker(), read())), "GA-005 delegation to the same subject's unrouted worker is still recorded")
    Test.check(H.Change.accepted(H.delegate(stranger_other_mounted(), 1n, 1n, reader(), stranger(), read())), "GA-005 a route on another service does not bar delegation")
    Test.check(H.valid(worker_rerouted()) && H.valid(worker_opened_rerouted()) && H.valid(worker_other_routed()), "GA-005 delegatee rerouted after delegation fixtures are valid states")
    Test.check(denied(rerouted_delegatee_open(), worker_rerouted(), H.SubjectMismatch{}), "GA-005 a delegatee later routed as another subject on the service denied SubjectMismatch at use")
    vector("GA-005-7", "bind_open", alias_outcome(rerouted_delegatee_open()))
    Test.check(denied(H.bind_attenuate(worker_opened_rerouted(), 3n, 3n, worker(), reader_caller(), registry(), read(), live()), worker_opened_rerouted(), H.SubjectMismatch{}), "GA-005 rerouting the delegatee also withdraws its derived alias")
    Test.check(H.Change.accepted(H.bind_open(worker_other_routed(), 2n, 2n, worker(), reader_caller(), registry(), read(), live())), "GA-005 a later route for the delegatee on another service leaves its delegation usable")
    Test.check(denied(H.delegate(mounted_worker_rerouted(), 1n, 1n, reader(), worker(), read()), mounted_worker_rerouted(), H.SubjectMismatch{}), "GA-005 delegation to a worker already routed as another subject is still denied SubjectMismatch")

# GA-006 Delegation cannot widen rights.
def ga006_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(denied(widened_delegate(), attenuated(), H.WidenedRights{}), "GA-006 read-only descriptor delegated with read and write denied WidenedRights")
    vector("GA-006-1", "delegate", alias_outcome(widened_delegate()))
    Test.check(denied(H.delegate(opened(), 2n, 2n, reader(), worker(), unknown_right()), opened(), H.WidenedRights{}), "GA-006 delegation outside the protocol rights denied WidenedRights")
    Test.check(H.Change.accepted(attenuated_copy_change()) && issued_is(H.Change.issued(attenuated_copy_change()), 4n), "GA-006 read delegation of the same read-only descriptor is recorded")
    vector("GA-006-2", "delegate", alias_outcome(attenuated_copy_change()))
    Test.check(rights_are(H.resolve(attenuated_shared(), 4n, worker()), read()) && Nat.is_eq(H.alias_object_of(H.aliases(attenuated_shared()), 4n), 3n), "GA-006 delegatee of the read-only descriptor shares its object and carries read only")
    Test.check(H.Change.accepted(copy_change()) && issued_is(H.Change.issued(copy_change()), 3n), "GA-006 narrower read-only delegation is recorded")
    vector("GA-006-3", "delegate", alias_outcome(copy_change()))
    Test.check(rights_are(H.resolve(shared(), 3n, worker()), read()), "GA-006 delegatee alias carries read only")
    Test.check(rights_are(H.resolve(shared(), 2n, reader()), all_rights()), "GA-006 delegator alias keeps its rights")
    Test.check(denied(H.bind_attenuate(shared(), 3n, 3n, worker(), reader_caller(), registry(), read_write(), live()), shared(), H.WidenedRights{}), "GA-006 delegatee cannot attenuate past its delegated rights")
    Test.check(H.valid(shared()), "GA-006 delegation preserves binding validity")

# GA-007 Quota saturation denies before authority.
def ga007_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(denied(H.bind_mount(start(0n), 0n, reader_route(), reader_caller(), registry(), all_rights(), live()), start(0n), H.QuotaExhausted{}), "GA-007 mount with zero capability quota denied QuotaExhausted")
    Test.check(denied(quota_open(), exhausted(), H.QuotaExhausted{}), "GA-007 open with zero capability quota denied QuotaExhausted")
    vector("GA-007-1", "bind_open", alias_outcome(quota_open()))
    Test.check(Nat.is_eq(frontend_handles(H.Change.state(retry())), 1n+frontend_handles(exhausted())) && Nat.is_eq(F.revision(H.frontend(H.Change.state(retry()))), 1n+F.revision(H.frontend(exhausted()))), "GA-007 only the retried open adds a Frontend handle and advances Frontend")
    Test.check(denied(quota_before_authority(), exhausted(), H.QuotaExhausted{}), "GA-007 quota is checked before Frontend authority")
    vector("GA-007-2", "bind_open", alias_outcome(quota_before_authority()))
    Test.check(H.Change.accepted(retry()) && issued_is(H.Change.issued(retry()), 2n), "GA-007 after top-up the open proceeds at the same revision")
    vector("GA-007-3", "bind_open", alias_outcome(retry()))
    Test.check(Nat.is_eq(frontend_handles(H.Change.state(retry())), 2n) && Nat.is_eq(reader_caps(H.Change.state(retry())), 0n), "GA-007 the retried open is charged and reaches Frontend")
    Test.check(Nat.is_eq(reader_caps(opened()), 3n), "GA-007 mount and open each charge one capability slot")
    Test.check(Nat.is_eq(reader_caps(H.Change.state(H.bind_close(opened(), 2n, 2n, reader(), reader_caller()))), 4n), "GA-007 destroying an object refunds its capability slot")
    Test.check(Nat.is_eq(reader_caps(H.Change.state(H.bind_close(opened(), 2n, 1n, reader(), reader_caller()))), 5n), "GA-007 destroying a Session refunds its derived objects too")
    Test.check(Nat.is_eq(reader_caps(H.Change.state(H.revoke(opened(), 2n, reader()))), 5n), "GA-007 revoking a domain refunds the slots of its live objects")
    Test.check(Nat.is_eq(worker_caps(derived()), 4n) && Nat.is_eq(worker_caps(derived_revoked()), 5n) && Nat.is_eq(reader_caps(derived_revoked()), 5n), "GA-007 revoke refunds each destroyed object to the domain charged for it")

# GA-008 Denials preserve state and name a reason. Every denial check in this
# module compares the returned state structurally with its input; these add
# the revision gate and invalid input states.
def ga008_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(denied(stale_revision_mount(), mounted(), H.StaleRevision{}), "GA-008 mount at a stale revision denied StaleRevision")
    vector("GA-008-1", "bind_mount", alias_outcome(stale_revision_mount()))
    Test.check(denied(rejected_mount(), initial(), H.FrontendRejected{}), "GA-008 mount Frontend rejects returns the input state")
    vector("GA-008-2", "bind_mount", alias_outcome(rejected_mount()))
    Test.check(denied(H.bind_open(opened(), 1n, 1n, reader(), reader_caller(), registry(), read(), live()), opened(), H.StaleRevision{}), "GA-008 open at a stale revision denied StaleRevision")
    Test.check(denied(H.bind_attenuate(opened(), 1n, 2n, reader(), reader_caller(), registry(), read(), live()), opened(), H.StaleRevision{}), "GA-008 attenuate at a stale revision denied StaleRevision")
    Test.check(denied(H.delegate(opened(), 1n, 2n, reader(), worker(), read()), opened(), H.StaleRevision{}), "GA-008 delegate at a stale revision denied StaleRevision")
    Test.check(denied(H.revoke(opened(), 1n, reader()), opened(), H.StaleRevision{}), "GA-008 revoke at a stale revision denied StaleRevision")
    Test.check(Bool.not(H.valid(dangling_state())), "GA-008 dangling alias fixture is invalid")
    Test.check(denied(invalid_mount(), dangling_state(), H.StaleRevision{}), "GA-008 an invalid input state is denied StaleRevision")
    vector("GA-008-3", "bind_mount", alias_outcome(invalid_mount()))
    Test.check(denied(H.revoke(dangling_state(), 0n, reader()), dangling_state(), H.StaleRevision{}), "GA-008 revoke on an invalid input state is denied")

# GA-011 Delegations form a derivation tree.
def ga011_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(H.Change.accepted(chain_change()) && Nat.is_eq(delegation_count(H.delegations(chain())), 2n), "GA-011 a two-level chain R to W to H is recorded")
    Test.check(H.valid(chain()), "GA-011 the chain preserves binding validity")
    Test.check(H.Change.accepted(chain_revoke()), "GA-011 revoking R's domain commits")
    vector("GA-011-1", "revoke", revoke_outcome(chain_revoke()))
    Test.check(denied(worker_after_revoke(), chain_revoked(), H.StaleGeneration{}), "GA-011 revoking R makes W's alias stale")
    vector("GA-011-2", "delegate", alias_outcome(worker_after_revoke()))
    Test.check(denied(helper_after_revoke(), chain_revoked(), H.StaleGeneration{}), "GA-011 revoking R makes H's alias stale")
    vector("GA-011-3", "delegate", alias_outcome(helper_after_revoke()))
    Test.check(Nat.is_eq(delegation_count(H.delegations(chain_revoked())), 0n), "GA-011 revoke removes the whole subtree")
    Test.check(denied(H.delegate(chain_closed(), 5n, 3n, worker(), helper(), read()), chain_closed(), H.StaleGeneration{}), "GA-011 closing R's descriptor makes W's alias stale")
    Test.check(denied(H.delegate(chain_closed(), 5n, 4n, helper(), worker(), read()), chain_closed(), H.StaleGeneration{}), "GA-011 closing R's descriptor makes H's alias stale")
    Test.check(Nat.is_eq(delegation_count(H.delegations(chain_closed())), 0n) && H.valid(chain_closed()) && H.valid(chain_revoked()), "GA-011 close removes the whole subtree and stays valid")
    Test.check(Nat.is_eq(delegation_count(H.remove_subtree(H.delegations(chain()), H.aliases(chain()), H.objects(chain()), 3n)), 0n), "GA-011 removing W's node removes H's node with it")
    Test.check(Nat.is_eq(delegation_count(H.remove_subtree(H.delegations(chain()), H.aliases(chain()), H.objects(chain()), 4n)), 1n), "GA-011 removing H's node keeps W's node")
    Test.check(denied(wider_child(), shared(), H.WidenedRights{}), "GA-011 child delegation wider than its read-only parent denied and no node added")
    vector("GA-011-4", "delegate", alias_outcome(wider_child()))
    Test.check(H.Change.accepted(H.delegate(derived(), 4n, 4n, worker(), helper(), read())), "GA-011 W's derived object is usable before its branch is cut")
    Test.check(denied(derived_after_close(), derived_closed(), H.StaleGeneration{}), "GA-011 derived object is stale after its parent is closed")
    vector("GA-011-5", "bind_attenuate", alias_outcome(derived_after_close()))
    Test.check(denied(H.bind_attenuate(derived_revoked(), 5n, 4n, worker(), reader_caller(), registry(), read(), live()), derived_revoked(), H.StaleGeneration{}), "GA-011 derived object is stale after its parent's holder is revoked")
    Test.check(H.Change.accepted(delegatee_revoke()), "GA-011 revoking the delegatee's domain commits")
    vector("GA-011-6", "revoke", revoke_outcome(delegatee_revoke()))
    Test.check(denied(delegator_after_delegatee_revoke(), delegatee_revoked(), H.StaleGeneration{}), "GA-011 revoking a delegatee destroys the delegator's object too")
    vector("GA-011-7", "delegate", alias_outcome(delegator_after_delegatee_revoke()))
    Test.check(H.Change.accepted(H.bind_open(delegatee_revoked(), 4n, 1n, reader(), reader_caller(), registry(), read(), live())) && Nat.is_eq(reader_caps(delegatee_revoked()), 4n), "GA-011 the delegator's Session survives and its descriptor slot is refunded")

# Public entry point, run by Tests.bend. Checks are grouped per requirement and
# fixtures are named functions rather than shared locals: one flat main with
# every state bound once exceeds the native backend's arity limit.
def main() -> IO(Unit):
  do IO<Unit>:
    helper_checks()
    ga001_checks()
    ga002_checks()
    ga003_checks()
    ga004_checks()
    ga005_checks()
    ga006_checks()
    ga007_checks()
    ga008_checks()
    ga011_checks()
    IO.print("HostBinding: 131 checks passed, 41 vectors emitted; GA-010 is a reviewed host obligation, not a model test")
