# Task 1 report: HostBinding records and validity

Status: DONE_WITH_CONCERNS

Commit: 48a7cd3 "Add HostBinding records and structural validity" (branch lane/genode-binding, not pushed).
File: HostBinding.bend (new; no other source file touched).

## Checks
- `bend HostBinding.bend --check-only`: ALL PROOFS CHECK
- `bend DataOS.bend --check-only`: ALL PROOFS CHECK
- `bend Tests.bend` (JS runner): ALL LIBRARY TESTS PASSED, 639 lines containing PASS (HostBinding not yet registered; tests are Task 3). Output in ../writ-build/genode-binding/task1-tests-js.txt.
- `bend PROOF.bend`: ALL PROOFS CHECK (no --verdict run in this task).
- Ad hoc scratch run (deleted, not committed): valid(empty()) = True; one object plus an alias to it = True;
  alias to a missing object = False; Error.equal and Change.accepted behave as expected.
- No `@unsafe`, `?TODO`, or array indexing in the file.

## What was delivered
- Types: ObjectKind (Session, Descriptor, ResultChannel), Object, Alias, Route, Quota, Delegation, Binding,
  State, Error (all nine reasons), Change (Rejected{state, reason}, Changed{state, id}), with field names exactly
  as in the brief. Collections: Objects/NoObjects, Aliases/NoAliases, Routes/NoRoutes, Quotas/NoQuotas,
  Delegations/NoDelegations, Bindings/NoBindings.
- Public entry points: empty() (wraps F.empty(); counters start at 1n), valid(state), Error.equal,
  Change.accepted, Change.state, Change.reason (Maybe<&2, Error>), plus Change.issued (Maybe<&2, Nat>, mirrors
  Frontend.issued). Exported helpers: revision, frontend, object_id, alias_object, quota_domain, *_exists, *_valid.
- Frontend used only through public defs: F.empty, F.valid, F.handles, F.handle_exists, F.rights_valid.

## valid() clauses
Brief-required: every alias's object exists; every binding's object exists and its handle exists in
`frontend`; object ids and alias ids unique and below next_object / next_alias; every Delegation.alias and
Delegation.from_alias exists; quota domains unique.
Added (stricter, each with rationale in a comment):
- ids positive and counters positive (mirrors Frontend: id 0 never allocated);
- F.valid(frontend) holds;
- at most one binding per object (otherwise list order picks authority);
- delegation tree shape: each child alias has at most one parent node, and from_alias < alias (parent allocated
  before child, which excludes cycles since alias ids only increase; Task 2's subtree removal relies on this);
- delegation rights satisfy F.rights_valid.

## Concerns / deviations (for review)
1. `Kind` is a reserved keyword in Bend 2 (checker: "expected : a name (got the keyword 'Kind')"). The type is
   named `ObjectKind`; the Object field is still `kind`. Plan/spec text naming `Kind` should be read as ObjectKind.
2. The brief's `Alias{holder, object, generation}` has no id, yet valid() and Delegation reference alias ids.
   Alias ids are stored in the list cell: `Aliases{id: Nat, head: Alias, tail: Aliases}`, keeping Alias verbatim.
   Task 2 must allocate from next_alias into that cell. If the reviewer prefers an `id` field on Alias, it is a
   small change.
3. Constructor names `Descriptor{}`, `Rejected{}`, `Changed{}`, `State{}` also exist in Frontend.
   H.Descriptor{} and H.Rejected{} resolved correctly from an importing scratch file; Task 1 code constructs none
   of them, so Task 2 should confirm unqualified use inside HostBinding and qualify Frontend's as F.*.
4. Routes are not checked by valid() (the brief lists no route clause); uniqueness of (child, service) routes is
   not enforced. Delegation `to_holder` is not checked against the child alias's holder. Both may be worth adding
   in Task 2 if transitions look routes or delegatees up by key.
5. `T` is imported as the brief requires but not yet used (Task 2 uses T.word_subset).

## Fix pass (coordinator review of 48a7cd3)

Commit: c33e3fd "Give HostBinding aliases an id field and fix review comments"

Changes:
1. Important: Alias is now `Alias{id: Nat, holder: Nat, object: Nat, generation: Nat}`; the collection is the plain
   `Aliases{head: Alias, tail: Aliases}`. Added `alias_id`; `alias_object` uses the four-field pattern;
   `alias_exists` and `aliases_valid` compare `alias_id(alias)` following `objects_valid`. The list-cell comment
   is removed; the Alias comment now says the id names the monitor-allocated reference slot and is never reused.
   (Supersedes concern 2 above.)
2. Delegation comment now says "at most one parent node; an alias with none is a root".
3. Header, Quota, Delegation, and valid() comments no longer cite plan tasks or describe nonexistent transitions;
   they state requirements on transitions ("A transition must deny on exhaustion before Writ authority is
   consulted", "A delegating transition must refuse rights wider than the parent's effective rights", "a mount
   transition must check the route's subject against the authenticated caller").
4. bindings_valid comment adds: "A binding may name a closed handle; invocation still denies through Frontend."

Commands and output:
- `bend HostBinding.bend --check-only`: ALL PROOFS CHECK
- `bend DataOS.bend --check-only`: ALL PROOFS CHECK
- `bend Tests.bend` (JS): exit 0, ALL LIBRARY TESTS PASSED, 639 PASS lines (unchanged; HostBinding has no tests yet).
  Output in ../writ-build/genode-binding/task1-fix-tests-js.txt.
- Scratch run (deleted, not committed): valid(empty()) True; two aliases with ids 1 and 2 True; duplicate alias id
  False; alias id equal to next_alias False; alias to a missing object False.
