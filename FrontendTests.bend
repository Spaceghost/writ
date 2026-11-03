import Base
import ./Frontend.bend as F
import ./Transfer.bend as T
import ./TransferTests.bend as TF
import ./Test.bend as Test

# Only tests import the synthetic Transfer fixtures. Frontend has no fixture,
# foreign IO, external executor, or dependency on a test module.
def token() -> T.CodeId:
  T.CodeId{101, 102, 103, 104, 105, 106, 107, 108}

def other_token() -> T.CodeId:
  T.CodeId{101, 102, 103, 104, 105, 106, 107, 109}

def caller(subject: Nat) -> F.Caller:
  F.Caller{subject, token()}

def ref(id: Nat) -> F.Ref:
  F.Ref{caller(7n), id}

def capability(rights: U32) -> F.Capability:
  F.Capability{token(), 7n, TF.plan(), rights, 3n, 180n}

def registry(rights: U32) -> F.Registry:
  F.Registered{capability(rights), F.EmptyRegistry{}}

def live() -> F.Live:
  F.Live{3n, 100n}

def plan_is(value: Maybe<&2, T.Plan>, expected: T.Plan) -> Bool:
  match value:
    case None{}:
      False{}
    case Some{plan}:
      T.Plan.equal(plan, expected)

def no_plan(value: Maybe<&2, T.Plan>) -> Bool:
  match value:
    case None{}:
      True{}
    case Some{_}:
      False{}

def issued_is(value: Maybe<&2, Nat>, expected: Nat) -> Bool:
  match value:
    case None{}:
      False{}
    case Some{id}:
      Nat.is_eq(id, expected)

def resolve(state: F.State, registry: F.Registry, revision: Nat, ref: F.Ref, request: F.Request) -> Maybe<&2, T.Plan>:
  F.checked_plan(state, registry, revision, ref, request, TF.context())

def redirected_plan() -> T.Plan:
  TF.plan_destination(TF.plan(), T.ObjectVersion{21n, 8n})

def redirected_registry() -> F.Registry:
  F.Registered{F.Capability{token(), 7n, redirected_plan(), 7, 3n, 180n}, F.EmptyRegistry{}}

def raw_handle(id: Nat, plan: T.Plan) -> F.Handle:
  F.Handle{id, F.Descriptor{}, 7n, token(), plan, 7, 3n, 180n, False{}}

def main() -> IO(Unit):
  +reg = registry(7)
  +mount = F.mount(F.empty(), reg, 0n, caller(7n), 7, live())
  +mounted = F.state(mount)
  +open = F.open(mounted, reg, 1n, ref(1n), 7, live())
  +opened = F.state(open)
  +dup = F.dup(opened, reg, 2n, ref(2n), live())
  +duplicated = F.state(dup)
  +attenuate = F.attenuate(opened, reg, 2n, ref(2n), 1, live())
  +attenuated = F.state(attenuate)
  +close = F.close(duplicated, 3n, ref(2n))
  +closed = F.state(close)
  +readonly_mount = F.state(F.mount(F.empty(), reg, 0n, caller(7n), 1, live()))
  +zero = F.state(F.attenuate(opened, reg, 2n, ref(2n), 0, live()))
  +duplicate_registry = {F.Registered{capability(7), F.Registered{capability(7), F.EmptyRegistry{}}} : F.Registry}
  +bad_state = {F.State{2n, 3n, F.Handles{raw_handle(2n, TF.plan()), F.Handles{raw_handle(2n, TF.plan()), F.NoHandles{}}}} : F.State}
  +small_next = {F.State{2n, 2n, F.Handles{raw_handle(2n, TF.plan()), F.NoHandles{}}} : F.State}
  +forged_redirect = {F.State{2n, 3n, F.Handles{raw_handle(2n, redirected_plan()), F.NoHandles{}}} : F.State}
  do IO<Unit>:
    Test.check(T.accepted(T.admit(TF.plan(), TF.context())), "frontend fixture has a valid paired read/write contract")
    Test.check(F.valid(F.empty()), "empty frontend state is valid")
    Test.check(F.registry_valid(reg), "unique capability registry validates")
    Test.check(F.accepted(mount), "capability mounts as a protocol handle")
    Test.check(issued_is(F.issued(mount), 1n), "mount allocates first monotonic ID")
    Test.check(F.accepted(open), "mounted capability opens a descriptor record")
    Test.check(issued_is(F.issued(open), 2n), "open allocates next descriptor ID")
    Test.check(F.valid(opened), "open preserves frontend structural validity")
    Test.check(plan_is(resolve(opened, reg, 2n, ref(2n), F.Read{}), TF.plan()), "read request resolves exact immutable plan")
    Test.check(plan_is(resolve(opened, reg, 2n, ref(2n), F.Write{}), TF.plan()), "write request resolves same exact plan")
    Test.check(plan_is(resolve(opened, reg, 2n, ref(2n), F.Execute{}), TF.plan()), "execute resolves exact plan with all rights")
    Test.check(no_plan(resolve(mounted, reg, 1n, ref(1n), F.Read{})), "mount handle itself cannot perform an operation")
    Test.check(no_plan(resolve(opened, reg, 2n, F.Ref{caller(8n), 2n}, F.Read{})), "descriptor cannot cross authenticated subjects")
    Test.check(no_plan(resolve(opened, reg, 2n, F.Ref{F.Caller{7n, other_token()}, 2n}, F.Read{})), "descriptor cannot switch capability token")
    Test.check(Bool.not(F.accepted(F.mount(F.empty(), reg, 0n, F.Caller{7n, other_token()}, 7, live()))), "all 256 token bits participate in lookup")
    Test.check(Bool.not(F.accepted(F.mount(F.empty(), reg, 0n, caller(8n), 7, live()))), "token possession does not change bound subject")
    Test.check(Bool.not(F.accepted(F.mount(F.empty(), reg, 0n, caller(7n), 8, live()))), "unknown rights bit denies mount")
    Test.check(Bool.not(F.accepted(F.mount(F.empty(), registry(1), 0n, caller(7n), 3, live()))), "mount cannot amplify registry rights")
    Test.check(Bool.not(F.accepted(F.open(readonly_mount, reg, 1n, ref(1n), 3, live()))), "open cannot amplify mounted rights")
    Test.check(Bool.not(F.accepted(F.open(opened, reg, 2n, ref(2n), 7, live()))), "descriptor is not a mount alias")
    Test.check(Bool.not(F.accepted(F.dup(mounted, reg, 1n, ref(1n), live()))), "mount is not a duplicable operational descriptor")
    Test.check(F.accepted(dup), "descriptor duplication succeeds under live authority")
    Test.check(issued_is(F.issued(dup), 3n), "dup allocates a distinct descriptor ID")
    Test.check(plan_is(resolve(duplicated, reg, 3n, ref(3n), F.Execute{}), TF.plan()), "dup preserves exact token and plan scope")
    Test.check(F.accepted(attenuate), "descriptor rights may be attenuated in current state")
    Test.check(plan_is(resolve(attenuated, reg, 3n, ref(2n), F.Read{}), TF.plan()), "attenuated read right remains usable")
    Test.check(no_plan(resolve(attenuated, reg, 3n, ref(2n), F.Write{})), "attenuation removes write right")
    Test.check(no_plan(resolve(attenuated, reg, 3n, ref(2n), F.Execute{})), "attenuation removes execute right")
    Test.check(Bool.not(F.accepted(F.attenuate(attenuated, reg, 3n, ref(2n), 7, live()))), "attenuation cannot restore removed rights")
    Test.check(no_plan(resolve(F.state(F.dup(attenuated, reg, 3n, ref(2n), live())), reg, 4n, ref(3n), F.Write{})), "duplication preserves attenuation")
    Test.check(no_plan(resolve(zero, reg, 3n, ref(2n), F.Read{})), "zero-right descriptor authorizes no read")
    Test.check(no_plan(resolve(zero, reg, 3n, ref(2n), F.Write{})), "zero-right descriptor authorizes no write")
    Test.check(no_plan(resolve(zero, reg, 3n, ref(2n), F.Execute{})), "zero-right descriptor authorizes no execution")
    Test.check(no_plan(resolve(opened, F.EmptyRegistry{}, 2n, ref(2n), F.Read{})), "removing registry capability revokes existing descriptor")
    Test.check(Bool.not(F.accepted(F.dup(opened, F.EmptyRegistry{}, 2n, ref(2n), live()))), "revoked descriptor cannot duplicate itself")
    Test.check(no_plan(resolve(opened, registry(3), 2n, ref(2n), F.Read{})), "registry rights reduction invalidates wider existing descriptor")
    Test.check(no_plan(resolve(opened, redirected_registry(), 2n, ref(2n), F.Read{})), "registry replacement cannot redirect existing descriptor plan")
    Test.check(no_plan(resolve(forged_redirect, reg, 2n, ref(2n), F.Read{})), "altered descriptor plan disagrees with trusted registry")
    Test.check(no_plan(F.checked_plan(opened, reg, 2n, ref(2n), F.Read{}, TF.with_writes(TF.context(), T.WriteEnd{}))), "read request still requires destination write approval")
    Test.check(no_plan(F.checked_plan(opened, reg, 2n, ref(2n), F.Write{}, TF.with_reads(TF.context(), T.ReadEnd{}))), "write request still requires exact source read approval")
    Test.check(no_plan(F.checked_plan(opened, reg, 2n, ref(2n), F.Execute{}, TF.with_payments(TF.context(), T.PayEnd{}))), "capability cannot bypass inherited payment requirement")
    Test.check(no_plan(resolve(opened, reg, 1n, ref(2n), F.Read{})), "stale revision cannot resolve operation")
    Test.check(Bool.not(F.accepted(F.dup(opened, reg, 1n, ref(2n), live()))), "stale revision cannot duplicate descriptor")
    Test.check(Nat.is_eq(F.revision(F.state(F.open(mounted, reg, 0n, ref(1n), 7, live()))), 1n), "rejected mutation leaves revision unchanged")
    Test.check(no_plan(F.checked_plan(opened, reg, 2n, ref(2n), F.Read{}, TF.with_live(TF.context(), T.Stamp{1n, 2n, 4n}))), "authority epoch change invalidates open descriptor")
    Test.check(Bool.not(F.accepted(F.mount(F.empty(), reg, 0n, caller(7n), 7, F.Live{4n, 100n}))), "stale capability cannot mount in new epoch")
    Test.check(Bool.not(F.accepted(F.open(mounted, reg, 1n, ref(1n), 7, F.Live{4n, 100n}))), "stale mounted capability cannot open")
    Test.check(no_plan(F.checked_plan(opened, reg, 2n, ref(2n), F.Read{}, TF.with_now(TF.context(), 180n))), "expiry is exclusive at exact deadline")
    Test.check(Bool.not(F.accepted(F.dup(opened, reg, 2n, ref(2n), F.Live{3n, 180n}))), "expired descriptor cannot duplicate itself")
    Test.check(Bool.not(F.accepted(F.mount(F.empty(), reg, 0n, caller(7n), 7, F.Live{3n, 180n}))), "expired capability cannot mount")
    Test.check(no_plan(resolve(opened, F.Registered{F.Capability{token(), 7n, TF.plan(), 7, 3n, 179n}, F.EmptyRegistry{}}, 2n, ref(2n), F.Read{})), "shortening registry expiry invalidates older broader handle")
    Test.check(Bool.not(F.registry_valid(duplicate_registry)), "duplicate capability token is ambiguous and invalid")
    Test.check(Bool.not(F.accepted(F.mount(F.empty(), duplicate_registry, 0n, caller(7n), 7, live()))), "malformed registry denies mount")
    Test.check(no_plan(resolve(opened, duplicate_registry, 2n, ref(2n), F.Read{})), "malformed registry denies resolution")
    Test.check(Bool.not(F.registry_valid(F.Registered{capability(8), F.EmptyRegistry{}})), "malformed registry rights deny")
    Test.check(Bool.not(F.registry_valid(F.Registered{F.Capability{token(), 7n, TF.plan(), 7, 4n, 180n}, F.EmptyRegistry{}})), "capability epoch must match immutable plan epoch")
    Test.check(Bool.not(F.valid(bad_state)), "duplicate descriptor IDs invalidate state")
    Test.check(no_plan(resolve(bad_state, reg, 2n, ref(2n), F.Read{})), "ambiguous descriptor state denies resolution")
    Test.check(Bool.not(F.valid(small_next)), "next descriptor ID must exceed every allocated ID")
    Test.check(no_plan(resolve(opened, reg, 2n, ref(0n), F.Read{})), "unallocated zero descriptor denies")
    Test.check(no_plan(resolve(opened, reg, 2n, ref(99n), F.Read{})), "unknown descriptor denies")
    Test.check(F.accepted(close), "closing descriptor records tombstone")
    Test.check(no_plan(resolve(closed, reg, 4n, ref(2n), F.Read{})), "closed descriptor cannot resolve")
    Test.check(Bool.not(F.accepted(F.dup(closed, reg, 4n, ref(2n), live()))), "closed descriptor cannot duplicate")
    Test.check(Bool.not(F.accepted(F.attenuate(closed, reg, 4n, ref(2n), 0, live()))), "closed descriptor cannot be reactivated by attenuation")
    Test.check(Bool.not(F.accepted(F.close(closed, 4n, ref(2n)))), "close replay denies")
    Test.check(Bool.not(F.accepted(F.close(opened, 2n, F.Ref{caller(8n), 2n}))), "another subject cannot close descriptor")
    Test.check(Bool.not(F.accepted(F.close(opened, 2n, F.Ref{F.Caller{7n, other_token()}, 2n}))), "another token cannot close descriptor")
    Test.check(plan_is(resolve(closed, reg, 4n, ref(3n), F.Execute{}), TF.plan()), "closing one descriptor preserves independently duplicated descriptor")
    Test.check(issued_is(F.issued(F.open(closed, reg, 4n, ref(1n), 7, live())), 4n), "new open never reuses tombstoned descriptor ID")
    IO.print("Frontend: 70 checks passed")
