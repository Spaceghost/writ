# Task 3 report: HostBinding tests

Status: DONE_WITH_CONCERNS (concerns are minor; see the end)

Commit: 8d6fe33 "Add HostBinding scenario tests for GA-001 through GA-011" (branch lane/genode-binding, not pushed).
Files: new `HostBindingTests.bend`; `Tests.bend` (import `./HostBindingTests.bend as HostBinding`, and
`HostBinding.main()` after `Frontend.main()`). HostBinding.bend was not touched. No test revealed a defect.

## Results
| Run | Exit | Final line | `^PASS:` lines | lines containing PASS |
|---|---|---|---|---|
| Baseline (Task 2 fix 2, JS) | 0 | ALL LIBRARY TESTS PASSED | 585 | 639 |
| `bend Tests.bend` (JS) | 0 | ALL LIBRARY TESTS PASSED | 683 | 737 |
| native `tests-native +RTS --threads 4 --gpu off` | 0 | ALL LIBRARY TESTS PASSED | 683 | 737 |

Both counts went up by exactly 98, which is the number of new `Test.check` calls. JS and native output are
byte-identical. Module summary line: `HostBinding: 98 checks passed; GA-010 is a reviewed host obligation, not a
model test`. `bend DataOS.bend --check-only`, `bend HostBindingTests.bend --check-only`, and `bend PROOF.bend`
all print ALL PROOFS CHECK (I did not run --verdict). The native run uses `--gpu off`, so it is CPU only and is
not a GPU test. Outputs are in ../writ-build/genode-binding/task3-{tests-js,tests-native,native-build,proof}.txt.
Grep finds no `@unsafe`, `?TODO`, array indexing, or "RPC object".

## Structure
- Identities, rights, Frontend authority, routes, and quotas are named helpers. Comments call them synthetic
  monitor state, not authentication. Reader domain 7 is routed as subject 7 on services 1 and 2. Worker 8
  and helper 9 have no route, so anything they can do comes from a delegation node.
- Synthetic states: `generations_state` (object at generation 4, stale alias at 3, current alias at 4, the
  literal GA-001 numbers), `dangling_state` (invalid), `with_routes`, `with_quotas`, and
  `without_delegations` (GA-005: a holder with no record; the state is still valid).
- Scenario states are named zero-argument functions (`mounted`, `opened`, `attenuated`, `shared`, `chain`,
  `derived`, `session_shared`, `worker_opened`, `shared_closed`, `chain_revoked`, ...). Their comments give the
  ids and revisions they produce.
- `State.equal` compares every field exactly, including each Object/Alias/Route/Quota/Delegation/Binding field
  and the embedded F.State down to each Handle's token, plan, rights, epoch, expiry, and closed flag.
  `denied(change, input, reason)` = Rejected && the reason is exactly `reason` && `State.equal(state, input)`.
  Every denial check goes through `denied`. Four helper checks show that the equality and the reason test
  actually tell states apart (committed change, a single quota field, the Frontend state alone, wrong reason).
- Checks are grouped as `helper_checks` and `ga001_checks` ... `ga011_checks`, and `main` calls them in order.

## Scenario coverage (check counts)
- GA-001 (6): a generation-3 alias on a generation-4 object is denied StaleGeneration for open, delegate, and
  close. The generation-4 alias proceeds. A current alias with the wrong caller reaches Frontend
  (FrontendRejected).
- GA-002 (12): a mount on a recorded route that names the caller succeeds. It creates a Session owned by the
  subject on that service, gives the child the alias and the binding, and applies F.mount (handle 1 mounted,
  F revision 1). RouteMismatch for: caller S under R's route, a presented but unrecorded route naming S, and an
  unrouted service. A Session on service 2 opens. After the parent withdraws the service-2 route, the same
  holder is denied SubjectMismatch, so a route on another service does not authorize it.
- GA-003 (17): open and attenuate each mint a distinct object, binding, and handle. The Session alias record
  and its ability to open are unaffected. Read back through Frontend after attenuate, parent handle 2 still has
  rights 7 and the new handle 3 has rights 1; resolve agrees. Attenuating a Session alias is denied
  FrontendRejected. Rights outside the protocol bits are denied WidenedRights, and an unknown alias is denied
  UnknownAlias.
- GA-004 (9): after a close, both R's and W's aliases are StaleGeneration and Frontend handle 2 is closed. The
  parent Session still opens. Close at a stale revision is denied StaleRevision with the state unchanged;
  close with the wrong caller is FrontendRejected and close by a non-holder is SubjectMismatch, both with the
  state unchanged.
- GA-005 (10): a holder with no delegation record is denied SubjectMismatch for both attenuate and delegate,
  and so is a domain that does not hold the alias. Recorded delegation is accepted. The delegatee can open
  through a delegated Session, the alias it gets is usable (attenuate accepted) and resolves to read, and
  wider rights are denied WidenedRights.
- GA-006 (7): a read-only descriptor delegated with read+write, or with an unknown bit, is denied
  WidenedRights. A narrower delegation is recorded: the delegatee resolves to read and the delegator keeps 7.
  The delegatee cannot attenuate past read.
- GA-007 (9): zero caps denies both mount and open with QuotaExhausted. A denied open leaves Frontend with 1
  handle at revision 1. Quota is checked before Frontend (a wrong caller still gets QuotaExhausted). After a
  top-up, the retry at the same revision succeeds, is charged, and reaches Frontend. Mount and open each
  charge one slot. Closing a descriptor refunds 1, and closing the Session refunds its derived object too.
- GA-008 (9): StaleRevision for mount, open, attenuate, delegate, and revoke. A mount Frontend rejection
  returns the input. The dangling state is invalid and is denied StaleRevision by mount and revoke. (Every
  other denial in the file also asserts that state is preserved.)
- GA-011 (14): the R -> W -> H chain is recorded and valid. Revoke(R) and close(R's object) each make W's and
  H's aliases stale, remove every node, and leave a valid state. remove_subtree at W's node leaves 0 nodes; at
  H's node it leaves 1. A child wider than its read-only parent is denied WidenedRights with no node added.
  W's derived object can be used before the cut and is StaleGeneration (not SubjectMismatch) after its parent
  is closed and after R is revoked.
- GA-010: reviewed only. The file header says it is a host obligation discharged by confinement evidence.
  GA-009 (vectors) is noted there as a later task; this file emits no vectors.

## Issue hit and fixed (in the tests only)
The first version bound every state as a `+` local in one flat `main`. It passed on JS, but the native build
failed with `Error: an arity over 247`, presumably because the duplicated locals captured by the lifted
continuation are counted as arguments. I rewrote the fixtures as named functions and split the checks into
one function per requirement. The native build then succeeded. A comment on `main` records why.

## Concerns
- I left tasks.md unchanged. Item 1.3's evidence now exists, but the brief only allowed changes to Tests.bend.
  For the same reason `verification/source-sha256.txt`, `verification/tests-*.txt`, and VERIFICATION.md were
  not updated: AGENTS.md asks for the manifest and verification record to match the delivered tree, so a later
  task (2.3) or the coordinator needs to do that.
- GA-001 uses a hand-built state for generations 3 and 4. Transition-built staleness (generation 0 to 1) is
  covered by GA-004 and GA-011.
- The GA-005 "held by Q with no record" premise and the GA-002 route withdrawal are synthetic edits of
  committed states (`without_delegations`, `with_routes`). Each is checked to still satisfy `valid` (the
  GA-005 one explicitly).
- Fixtures are recomputed on every call. That is cheap here (the JS module runs in about 0.4 s) but redundant.
