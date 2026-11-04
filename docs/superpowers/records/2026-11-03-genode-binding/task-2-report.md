# Task 2 report: HostBinding transitions

Status: DONE_WITH_CONCERNS (see fix passes below)

Commit: 87b9c1e "Add HostBinding transitions over Frontend" (branch lane/genode-binding, not pushed).
File changed: HostBinding.bend only.

## Checks
- `bend HostBinding.bend --check-only`: ALL PROOFS CHECK
- `bend DataOS.bend --check-only`: ALL PROOFS CHECK
- `bend Tests.bend` (JS): exit 0, ALL LIBRARY TESTS PASSED, 639 PASS lines (unchanged; HostBinding tests are Task 3).
  Output: ../writ-build/genode-binding/task2-tests-js.txt
- `bend PROOF.bend`: ALL PROOFS CHECK (no --verdict run).
- grep: no `@unsafe`, `?TODO`, array indexing, or "RPC object" in HostBinding.bend.

## Public entry points and signatures
- `bind_mount(state, expected_revision, route: Route, caller: F.Caller, registry: F.Registry, rights: U32, live: F.Live)`
  Denials: StaleRevision, RouteMismatch, QuotaExhausted (route.child), FrontendRejected (F.mount). Mints Session
  owned by route.subject, alias held by route.child, binding to the new handle; charges one cap. Id = new alias.
- `bind_open(state, expected_revision, alias_id, holder, caller: F.Caller, registry, rights, live)`
  Denials: StaleRevision, UnknownAlias, StaleGeneration, SubjectMismatch, WidenedRights, QuotaExhausted (holder),
  FrontendRejected (F.open). UnknownObject only for an object/binding/handle missing (excluded by valid).
  Mints a new Descriptor object owned by the parent's owner, alias for holder, binding. Id = new alias.
- `bind_attenuate(...)`: same signature, checks, and order over `F.attenuate(state, registry, expected_revision,
  ref, rights, live)`. New object keeps the parent object's kind (F.attenuate keeps the handle kind).
- `delegate(state, expected_revision, alias_id, from_holder, to_holder, rights)`
  Denials: StaleRevision, UnknownAlias, StaleGeneration, SubjectMismatch, WidenedRights. Adds
  `Delegation{alias_id, to_holder, rights, new_alias}` and `Alias{new_alias, to_holder, same object, current gen}`.
  No Frontend call. Id = new alias.
- `bind_close(state, expected_revision, alias_id, holder, caller: F.Caller)`
  Denials: StaleRevision, UnknownAlias, StaleGeneration, SubjectMismatch, FrontendRejected (F.close). Bumps the
  object's generation by one and prunes every delegation on that object. Id = destroyed object id.
- `revoke(state, expected_revision, domain)`: only denial StaleRevision. Bumps every object `domain` holds an
  alias to; prunes delegation subtrees rooted at `domain`'s aliases. Comment documents why holder-keyed
  destruction is the Genode primitive (no per-copy revoke; destroying the object invalidates every copy).
  Frontend handles are not closed. Id = domain.
- Exported helpers: `resolve` (single authority path: alias -> object -> generation -> holder -> binding ->
  handle -> effective rights), `remove_subtree(delegations, aliases, root)`, `prune` with
  `Cut = CutAlias | CutObject | CutHolder`, `under_cut` (fuel = alias id; terminates because parent < child),
  `destroy`, `commit_mint`, `commit_delegate`, `commit_destroy`, accessors, lookups.

## valid() changes (gaps closed)
delegations_valid now also requires `alias_held(aliases, alias, to_holder)` and that the child alias names the
parent alias's object. delegate establishes both by construction.

## valid preserved: sequences tried (scratch file, deleted, not committed)
Fixture: route {parent 1, child 7, service 5, subject 7}; quotas for 7, 8, 9; Frontend registry from
FrontendTests-style fixture. Every resulting state printed valid=T:
- mount (alias 1) -> open (alias 2, Descriptor) -> delegate 2: 7->8 read (alias 3) -> delegate 3: 8->9 read (alias 4)
- then revoke(7): revision +1, 0 delegations; aliases 1, 3, 4 all StaleGeneration (GA-011 two-level chain)
- then bind_close(alias 2 by 7): aliases 3, 4 StaleGeneration; alias 1 (Session) still opens
- then bind_attenuate(alias 3 by delegatee 8, read): accepted, new object; further open from alias 1 accepted
- remove_subtree(root 3) on the two-level chain leaves 0 nodes; remove_subtree(root 4) leaves 1.
Denials observed with revision and Frontend revision unchanged: StaleRevision (mount, revoke); RouteMismatch
(caller subject differs; route not recorded); QuotaExhausted (0 caps); FrontendRejected (mount rights 8, open with
wrong caller, close with wrong caller); UnknownAlias; SubjectMismatch (non-holder on open; non-holder on delegate);
WidenedRights (open rights 8; delegate read+write under read; delegatee attenuating with read+write under read);
StaleGeneration as above. Forged states: delegation with wrong to_holder -> valid F; delegation whose child is on
another object than its parent -> valid F; revoke on such a state -> StaleRevision.
Every denial passes the supplied `state` value through unchanged (never rebuilt); successes increment
revision exactly once in the commit_* helpers.

## Deviations from the brief (each deliberate; please review)
1. `bind_open`/`bind_attenuate` take a `caller: F.Caller` (the brief says "build an F.Ref from the binding's handle
   and the caller" but lists no caller parameter). `bind_close` takes `caller` and drops `registry`/`live`, which
   `F.close(state, expected_revision, ref)` does not accept.
2. WidenedRights in bind_open/bind_attenuate uses the alias's effective rights, not the bound handle's rights. With
   handle rights only, a delegatee given read could open/attenuate with write, widening its delegation (GA-006,
   GA-011). Effective rights = handle rights for a minted alias; delegation rights AND current handle rights for
   a delegated alias. delegate uses the same intersection.
3. bind_mount also requires the route to be recorded in `state.routes` (all four fields), denied RouteMismatch.
   A route supplied only as a parameter would be a caller-controlled authority fact.
4. SubjectMismatch requires `holder` to hold the alias AND (be the object's owner OR a delegation node for this
   alias names it). delegate applies the same rule to from_holder (brief: "must hold the alias"), so an
   unauthorized holder cannot delegate either.
5. Every transition's first gate is `valid(state) && revision == expected`; an invalid state is denied as
   StaleRevision (not a committed state), mirroring Frontend folding valid() into its revision gate. There is no
   dedicated reason in the closed Error type.
6. Header and Object comments now say "native object"/"channel object", per the vocabulary ruling.

## Concerns for Task 3 / coordinator
- The model compares a domain id (`holder`) with a subject id (`owner`). A mount whose route child differs from
  its subject yields an alias the child cannot use (SubjectMismatch). Task 3 fixtures should use child == subject,
  as the spec scenarios do; a richer domain-to-subject map would be a record change.
- A delegatee who opens or attenuates receives a new alias to a new object owned by the subject, with no
  delegation node for it (nodes must stay on the parent's object). That alias is then usable only if the
  delegatee is the owner. Safe (denies) but possibly not the intended UX.
- bind_attenuate narrows the shared Frontend handle in place (Frontend's semantics), so the parent object's
  aliases also see narrower rights after re-resolution. Two objects then bind the same handle; closing either
  closes the handle for both.
- Delegate charges no quota (not listed in the brief).

## Fix pass (coordinator review of 87b9c1e)

Commit: see `git log` (message "Route-map holders, dup before attenuate, keep delegatee derivations in the tree").

Changes:
1. Ruling 1: `route_maps(routes, child, subject)` added; `holder_authorized(routes, delegations, alias, object,
   holder)` = holder holds the alias AND (a recorded Route has child == holder and subject == owner, OR
   delegated_to). Holder and owner are never compared directly.
2. Ruling 2 / decision B: Attenuating arm calls `F.dup` on the parent handle, then `attenuate_dup` calls
   `F.attenuate` on the duplicate id at the post-dup Frontend revision; the new object binds the duplicate
   handle. A rejection at either step passes through as F.Rejected and the transition returns the original
   supplied state with FrontendRejected. F.dup accepts only Descriptors, so a Session alias is FrontendRejected
   (comment on derive_frontend and bind_attenuate). `derived_kind` removed: both derivations mint Descriptor.
3. Ruling 3 / decision A: `Object` gains `derived_from: Nat` (0n root). `valid`: derived_from is 0n or an existing
   object with a smaller id (`derivation_valid`, `derived_of`). Delegation edge clause
   (`delegation_edge_valid`): child alias names the parent alias's object OR the child's object has
   derived_from == parent alias's object. `Resolved` gains `delegated: Bool`. `commit_mint` takes the parent
   object id, `delegated`, the used alias, and recorded rights; when delegated it pushes
   `Delegation{used_alias, holder, rights ∩ effective, new_alias}`. Mount passes 0n/False.
4. Cheap minors taken: caller-authentication assumption stated in bind_open's comment; overlong Alias comment
   rewrapped. Other deferred minors untouched.

Checks:
- `bend HostBinding.bend --check-only`: ALL PROOFS CHECK
- `bend DataOS.bend --check-only`: ALL PROOFS CHECK
- `bend Tests.bend` (JS): exit 0, ALL LIBRARY TESTS PASSED, 639 PASS (output ../writ-build/genode-binding/task2-fix-tests-js.txt)
- `bend PROOF.bend`: ALL PROOFS CHECK (no --verdict)
- no `@unsafe`, `?TODO`, array indexing, or "RPC object".

Scratch sequences (ScratchHB.bend in the worktree root importing HostBinding as H; deleted, not committed).
Fixture: routes {1, 7, 5, 7} and {1, 6, 5, 7} (domain 7 and domain 6 both routed as subject 7); quotas for
domains 6, 7, 8, 9 (caps 5; base(0n) gives domain 7 zero caps); registry with one capability for subject 7,
rights 7, epoch 3, expiry 180; live {3, 100}. For each call I printed reason, issued id, output revision vs input
revision, valid(output), delegation count, Frontend handle count and Frontend revision (output/input).

Valid preserved; every state printed valid=T. Chain:
- s1 = mount (alias 1, Session obj 1) -> s2 = open alias 1 by 7 rights 7 (alias 2, Descriptor obj 2 derived 1)
  -> s3 = delegate 2: 7->8 read (alias 3) -> s4 = delegate 3: 8->9 read (alias 4); dels 1 then 2.
- GA-011 chain goes stale together: revoke(s4, domain 7) -> dels 0; alias 4 by 9 and alias 3 by 8 both
  StaleGeneration. Separately bind_close(s4, alias 2 by 7) -> dels 0, Frontend revision +1; aliases 3 and 4
  StaleGeneration; alias 1 (Session) still opens.
- remove_subtree on s4: root 3 leaves 0 nodes; root 4 leaves 1.
- Ruling 1: mount via route {1, 6, 5, 7} gives domain 6 the alias; domain 6 then opens successfully (holder 6 is
  routed as subject 7). A non-holder (8 on alias 1) is SubjectMismatch.
- Ruling 2: attenuate alias 2 (own descriptor) by 7 to read: accepted, handles 2 -> 3; afterwards
  resolve(alias 2) shows rights 7 (parent untouched) and the new alias 3 shows rights 1. Attenuate on the
  Session alias 1: FrontendRejected, handles and Frontend revision unchanged. Attenuate with rights 8:
  WidenedRights.
- Ruling 3: delegatee 8 attenuates alias 3 to read: accepted, dels 2 -> 3, new alias 5 resolves with rights 1 and
  delegated=T; read+write: WidenedRights. Then revoke(domain 7): dels 0, and alias 5 by 8 is SubjectMismatch (its
  node is pruned and domain 8 has no route as subject 7). bind_close(alias 2 by 7) after the delegatee
  attenuation: dels 0. Delegatee 8 calling bind_open on the descriptor alias 3: FrontendRejected (F.open needs a
  mount).

Denials leave state unchanged: every denial below printed output revision == input revision, the same
delegation count, the same Frontend handle count and Frontend revision. By construction the Rejected branch
returns the supplied `state` value itself:
StaleRevision (mount at revision 1 on s0; revoke at 3 on s4); RouteMismatch (caller subject 8; route
{1, 7, 6, 7} not recorded); QuotaExhausted (base(0n)); FrontendRejected (mount rights 8; open with caller 8;
close with caller 8; attenuate Session alias; delegatee open on a descriptor); UnknownAlias (alias 9);
SubjectMismatch (8 on alias 1; 9 delegating alias 3; 8 using alias 5 after revoke); WidenedRights (open rights 8;
delegate read+write under read; attenuate rights 8; delegatee attenuate read+write); StaleGeneration (after
revoke and after close, as above).

Forged-state checks on valid: correct objects T; derived_from naming a later id F; derived_from naming a missing
object F; correct delegation T; wrong to_holder F; edge alias 1 -> alias 2 (obj 2 derived from obj 1) T. Note:
edge alias 1 -> alias 3 with holder 8 also passes, because alias 3 is on obj 2, which is derived from obj 1.
Decision A admits this by design: valid checks structure, not which edge a transition would have written.

Remaining concerns:
- When a delegator's branch is pruned (revoke or close of the parent object), the delegatee's derived object
  is not destroyed. Its alias loses its delegation node and is then denied SubjectMismatch unless the holder is
  routed as the owner. This fails closed, but the object, its Frontend handle, and its cap charge remain.
  Whether to also bump objects derived from cut objects is a design call.
- Deferred minors from the review are unchanged (revoke vs close pruning scope, no cap charge on delegate,
  selector helpers).

## Fix pass 2 (coordinator re-review of 1fe4df8)

Commit: see `git log` ("Destroy derived objects with their parent and bind routes to a service").

Changes:
1. Derived objects die with their parent. `doomed(fuel, cut, aliases, objects, id)` is true when the object is
   cut or its derived_from chain reaches a cut object. Fuel is the object id: valid makes every derivation edge
   point to a smaller id, so the walk reaches 0n (never an object) before the fuel runs out. `destroy` bumps
   every doomed object. With `whole = True`, `prune` also drops every node whose child alias names a doomed
   object. commit_destroy uses it, so revoke now also removes nodes on destroyed objects that sit outside the
   domain's own subtrees. That narrows the deferred "revoke prunes fewer than close" gap as a side effect.
   `remove_subtree` keeps its exact meaning (`whole = False`) and now takes `objects`.
   Released resources: `refund` returns one cap to the minter of each doomed object that is still live, i.e. has
   a current alias. The minter is the holder of the object's alias that is not a copy (no copy-edge node), which
   is exactly the domain commit_mint charged. A second destruction refunds nothing. bind_close's own handle still
   goes through F.close. The handles of derived and revoked objects are left open: the monitor holds no
   authenticated Caller for them. The commit_destroy comment says this.
2. Routes bind a service. `Object` gains `service: Nat`. bind_mount records route.service, and derived objects
   inherit the parent's service. `route_maps(routes, child, subject, service)` requires all three to match.
   holder_authorized passes the object's service. In `valid`, `derivation_valid` requires the parent to exist with
   a smaller id and the same service (`object_serves`).
3. bind_close and revoke comments now describe transitive destruction and refunds.

Checks: `bend HostBinding.bend --check-only` and `bend DataOS.bend --check-only` print ALL PROOFS CHECK.
`bend Tests.bend` (JS) exits 0 and prints ALL LIBRARY TESTS PASSED with 639 PASS lines (output
../writ-build/genode-binding/task2-fix2-tests-js.txt). `bend PROOF.bend` prints ALL PROOFS CHECK (no --verdict).
No `@unsafe`, `?TODO`, or "RPC object".

Scratch (ScratchHB.bend, deleted, not committed). Routes: r1 = {1, 7, svc 1, subj 7}, r2 = {1, 7, svc 2, subj 7},
r9 = {1, 9, svc 2, subj 7}. Caps: domains 7, 8, 9 each start at 5. Each line printed reason, id, output/input
revision, valid, delegation count, Frontend handle count and revision, caps of domains 7 and 9, and every
object's generation, derived_from, and service.
- Build: mount r1 gives alias 1 on o1(svc 1). Mount r2 gives alias 2 on o2(svc 2). Open alias 1 by 7 gives
  alias 3 on o3(derived 1, svc 1). Delegating alias 3 from 7 to 9 (read) gives alias 4. Domain 9 attenuating
  alias 4 (read) gives alias 5 on o4(derived 3, svc 1) plus node {4, 9, 1, 5}. Caps 7 = 2, 9 = 4. valid = T
  throughout. Before the cut, domain 9 can use alias 5 (delegate succeeds).
- Cut by bind_close(alias 3 by 7): o3 and o4 go to generation 1, dels 2 -> 0, caps 7 2 -> 3 and 9 4 -> 5,
  Frontend revision +1. The derived alias 5 used by 9 is StaleGeneration, not SubjectMismatch. The copy alias 4
  is StaleGeneration. Session aliases 1 (svc 1) and 2 (svc 2) still open.
- Cut by revoke(7): o1 to o4 all go to generation 1. Caps 7 return to 5 (three objects) and caps 9 to 5. Alias 5
  is StaleGeneration. A second revoke(7) bumps generations again with no refund (caps unchanged).
- Cut by bind_close(Session alias 1 by 7): o1, o3, and transitively o4 are destroyed, while o2 (svc 2) stays at
  generation 0 and still opens. Caps 7 +2, caps 9 +1. Alias 5 is StaleGeneration.
- remove_subtree(root 4) on the built state leaves 0 of 2 nodes (both the copy and the derived node).
- Service binding: a forged state equal to the built state at alias 4 but with no delegation nodes (valid = T),
  where domain 9 holds alias 4 on svc-1 object o3. With routes r1, r2, r9, domain 9's svc-2 route does not
  authorize it: SubjectMismatch. Replacing r9 with {1, 9, svc 1, subj 7} authorizes it (accepted).
- Denials leave state unchanged. Each of these printed identical revision, delegation count, handle count,
  Frontend revision, caps, and object generations/derivations/services between input and output: StaleRevision
  (close at a stale revision), FrontendRejected (close with the wrong caller; attenuate on a Session),
  WidenedRights (delegatee attenuate with read+write), QuotaExhausted, RouteMismatch, UnknownAlias.

Remaining notes:
- Closing a Session now destroys every descriptor derived from it in the model, while their Frontend handles
  stay open (Frontend does not cascade a mount close). Invocation still needs a current alias, so this fails
  closed.
- The refund's minter rule relies on commit_mint creating exactly one non-copy alias per object. valid does not
  enforce that for host-supplied states.
- Deferred items untouched: delegate charges no cap, is_delegated comes from node presence, and valid accepts
  derivation edges no transition writes.
