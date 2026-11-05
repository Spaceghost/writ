### Task 2: Monitor-owned identity, delegation, incarnation, and generation binding (tasks.md 1.2)

Requirements: PH-002 "Subject identity survives the native boundary" ("A client changes its claimed subject", "A delegated endpoint hides its new holder"); PH-003 "Native handles remain host-local authority" ("A guessed numeric handle", "A reference crosses hosts"); PH-004 "References bind incarnation and generation" ("Handle reuse after restart", "Conflicting live mappings"); PH-005 "Delegation cannot widen Writ scope" ("A transferred endpoint requests another bucket", in its delegation part, and "A narrower proxy leaves an old handle alive").

Create `HostIdentity.bend`, importing `Base`, `HostWire`, `Frontend`, and `Transfer`. The header states that every field is monitor state built from authenticated native evidence; `valid` checks structure and does not authenticate.

- `Origin`: `Authenticated{}` | `Inherited{parent_session: Nat}` | `Transferred{from_session: Nat}`. This is how the binding observed the endpoint reaching its holder, a native fact the adapter reports.
- `Session{id, incarnation, caller: F.Caller, origin, delegable: Bool}`. `caller` is set only by `bind_session` from the adapter's authenticated evidence.
- `Entry{slot, generation, holder (session id), owner (Writ subject), handle (Frontend handle id), plan: T.Plan, rights: U32, expires: Nat, parent (0 for a root, else the parent slot), live: Bool}`.
- `State{revision, host, incarnation, next_slot, sessions, entries}`.
- `Error` is a closed set: `ForeignHost`, `StaleIncarnation`, `Forged` (slot 0 or not below `next_slot`), `Retired`, `Ambiguous`, `StaleGeneration`, `NotHolder`, `InheritedEndpoint`, `TransferredEndpoint`, `SubjectChanged`, `NotDelegable`, `WidenedRights`, `WidenedLifetime`, `Expired`, `UnknownSession`, `StaleRevision`. It uses the same `Change` pattern as `HostBinding` (`Accepted{state, issued}` | `Rejected{state, reason}`, with accessors).
- Public transitions: `bind_session`, `mint` (a root entry for a Frontend handle the monitor has already opened; the owner is the session's caller subject), `resolve` (read-only; returns the entry and the session's caller), `delegate`, `retire` (bumps the generation, clears `live`, and cascades to the whole subtree by `parent`, on fuel = `next_slot`), and `restart` (a new incarnation that is strictly greater, with empty sessions and entries and `next_slot` reset to 1).
- Resolution order, fixed and documented, with the first failure reported: host, incarnation, forged, ambiguity (count live entries with the slot: 0 gives `Retired`, more than 1 gives `Ambiguous`, never first-match), generation, holder, session origin, expiry. Plan ruling: an `Inherited` or `Transferred` session can use an entry only through a delegation edge naming that session as holder. Without one, it is denied `InheritedEndpoint` or `TransferredEndpoint` even when it presents a correct reference.
- Delegation, plan rulings. (a) The child copies the parent's plan exactly; `delegate` has no plan parameter, so a changed plan cannot be expressed as an attenuation. (b) The target session's subject must equal the entry owner, or the request is denied `SubjectChanged`. A changed subject needs a fresh `mint` after complete admission and is never a delegation. (c) The parent's session must be `delegable`. Plan ruling: worker sessions in the first topology are created non-delegable, so a worker cannot re-delegate its inputs. (d) Rights must be a subset of the parent's rights, and the child's expiry is at most the parent's (`now + lifetime`, capped).
- `valid`: at most one live entry per slot; every slot is below `next_slot`; every holder is a known session; every session's incarnation equals the state's; every parent link names a lower slot.
- Law, which needs a rationale. `identity_denied_preserves_state`: for every `HostIdentity.State` and `Error`, `Change.state(Rejected{state, reason}) == state`, proved by `{==}`. It fixes the contract every denial path relies on. It does not assert that a transition chose the denial or that the reason is correct; the tests cover that.

`HostIdentityTests.bend` (registered as `HostIdentity`) must cover these cases.
- Accepted: bind, mint, resolve, delegate (narrower rights and shorter lifetime, same plan), retire, restart.
- Forged: slot 0, and slot equal to `next_slot`.
- Ambiguous: a hand-built state with two live entries for one slot. `resolve` denies `Ambiguous`, and `valid` is false.
- Stale generation: after `retire`, the old reference is denied. The new reference resolves; the old one stays denied.
- Stale incarnation: after `restart`, slot 1 is minted again and the prior-incarnation reference with the same slot and generation is denied `StaleIncarnation`.
- Cross-host: a reference with another `host` is denied `ForeignHost`.
- Guessed handle: session B presents A's slot and generation and is denied `NotHolder`.
- Transferred endpoint: a `Transferred` session with no delegation edge is denied; with an edge to it, it resolves.
- Inherited endpoint: an `Inherited` session is denied; with an edge to it, it resolves.
- Claimed subject: a decoded `Use` whose `claimed_subject` is B, presented on A's session, resolves to caller A. A test shows that no transition reads `claimed_subject`.
- Delegation denials: to another subject's session (`SubjectChanged`); wider rights; longer lifetime; from a non-delegable session; from a stale or retired parent.
- Narrower proxy: after delegating a narrower child, the parent still resolves with its full rights and `live` is true, so the old authority is not reported as revoked.
- Retire cascade: retiring the parent makes the child and grandchild stale. Retiring the child leaves the parent live.
- Expiry: a use after `expires` is denied `Expired`.
- Stale revision: each transition with the wrong `expected_revision` is denied.
- Unchanged state: every denial is checked for full state equality with its input, using equality helpers in the test module.

Estimate: about 45 checks; about 350 lines of module and 350 of tests. Add the law to `LAWS.bend` and its `{==}` proof to `PROOF.bend`, importing `HostIdentity`. Add the PH-002 to PH-005 rows. PH-002's "derive the effective subject from trusted session state" is marked model-tested here, and "the adapter establishes the native identity/delegation semantics" is marked as a host obligation for section 2. Check box 1.2.

Acceptance: every case is a named check; all prior checks are unchanged; `bend PROOF.bend` passes with one more law; the suite is green on both backends.

