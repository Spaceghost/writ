# Proposed live owner for the Linux canary and worker session

A supervisor admits the existing public `abc` canary, then tries to bind a
Linux worker to the same view. If the capability is revoked between those
steps, the worker must not receive input. Today the canary and Linux monitor
have separate state owners, and a typed Linux session ID is not linked to the
canary's actor or its live capability. There is no combined gate. This design
is a proposed ordering for the [convergence plan](canary-broker-convergence.md),
not an implementation, an additional release API, a native identity result, or
a completed host acceptance scenario.

The scope is the existing immutable **public-canary** Copy and the proposed
Linux worker binding. A protected transformation or its output publication
still needs all applicable policy, current authority, accounting and native
qualification. No test, profile, audit approver, price, settlement decision or
new authority is implied by this document.

## Source facts and the missing bridge

| Existing component | What it currently owns or does | Missing for composition |
| --- | --- | --- |
| [Mount.dispatch](../../../writfs/Mount.bend) | Owns canary phase, fixed input and digest, one actor, bounded handles, protocol sequence and `MountAuthority.Grant`. ADMIT invokes the fixed Copy commit; read/open consult phase, actor and grant. | It knows no Linux worker session, current Linux process, or common owner with the Linux monitor. The native [policy runner](../../../contrib/native-hosts/runtime/node-policy.mjs) calls it directly today. |
| [MountAuthority.descriptor](../../../writfs/MountAuthority.bend) | Passes a Frontend state and reference into the same `DataOS.commit_from_capability` invocation, then retains only the accepted session, ledger and write intent in `Grant`. | The Frontend values are validated **inputs**, not returned current authority. They are discarded by this caller; it does not retain a live Frontend state or registry. |
| [LinuxHost.dispatch](../../../hosts/linux/monitor/LinuxHost.bend) | On synthetic Launch, `P.open_session_result` produces the same-transition ID and state in `Opened`; a Barrier can call `P.admit_worker`. `LINUXMON1` remains diagnostic. | No current native broker, request-correlated session receipt, single canary owner, or link from that ID to actor 1 is implemented. |
| [HostPrimitives.issue/admit_worker](../../../HostPrimitives.bend) | `issue` binds a root to the supplied monitor Frontend handle's plan, owner, rights and lease. `admit_worker` resolves an input reference on the worker session and checks profile, controls and inventory before `DeliverInputs`. | `issue` does **not** check the supplied handle's closure, current registry, epoch or a later Frontend state. `admit_worker` does not itself revalidate the canary's phase and live capability. Neither is a complete joint release gate. |

The fixed canary uses `Reference.caller(1)` and its deterministic
`internal_token(1)` to open an in-process descriptor; its source explicitly
says this token does not replace a host bearer token
([reference authority](../../../contrib/rclone/bend/Authority.bend)). Its subject
and token are synthetic internal values, not a real Linux caller or token, and
are not evidence that the Linux process is the descriptor owner. The Linux
session caller must come from an independently authenticated enforcing boundary; that
boundary and the exact relationship between the reader domain and worker
caller remain unimplemented. A monitor may not assert their equality merely
because both are represented by `Frontend.Caller`.

In particular, keeping the earlier Frontend/ref as a snapshot and later
passing it to `P.issue` is insufficient: [Mount.revoke](../../../writfs/Mount.bend)
sets the canary phase and retains the commit record; it does not close a
retained Frontend handle. The snapshot could therefore still appear to satisfy
`P.issue` after revocation. `P.issue` is defense in depth on the supplied
monitor-owned Frontend state, not live authorization; `HostIdentity.mint`
and `P.admit_worker` do not repair a stale canary phase or registry or bind
the supplied Frontend to a later publication state. A subsequent
`P.admit_worker` can return `DeliverInputs` without learning that the canary
or registry was revoked. That source-level possibility is not a claim of an executed exploit or current
native integrated path. Public Bend records and constructors are descriptive;
constructing or copying one is not authentication or permission to release.

## One serialized owner and its inputs

A future combined monitor needs **one serialized owner** for the following
records for the entire request and effect lifecycle. Merely putting copies in a
single record, or comparing revisions after another actor can mutate state,
does not establish this ownership:

- The canary's phase, private immutable input identity and exact public object,
  existing actor/handle table, and the committed session, ledger, intent and
  original policy retained by `Mount.State`.
- The live Linux `P.State` including its host incarnation, session, profile,
  identity entries, workers and revocation/quiescence state; an issued session
  is the exact accepted transition result, never guessed from a diagnostic table.
- The **current** monitor-owned Frontend state, descriptor, capability registry,
  epochs, paired transfer context, operation/sink obligations and trusted time
  necessary to revalidate the exact plan. This live state is not presently
  retained by the canary. A historical commit input is not a substitute.
- The independently authenticated caller/lifetime and an exact mapping among
  the descriptor owner, reader domain, Linux session and native actor. The
  source and expiry of each fact, session transport correlation, worker profile,
  registry update/revocation feed, trusted clock and bounded retention are
  unresolved. Neither worker bytes, UID/PID alone, a public token, a native
  handle, a client-supplied actor nor a serializable `State` may set them.

This owner must be able to serialize admission, use, revocation, restart and
attributed effects against each other. An implementation may distribute native
resource ownership only if it preserves this single authoritative ordering and
can retire an uncertain instance. It must not make native policy decisions or
let a FUSE callback or worker replace authority. Because the current native
runner calls `Mount.dispatch` directly and phase 2 permits canary reads, a
future combined service must exclusively mediate that consumer through the
joint owner and keep service closed until all combined gates succeed; retaining
a second, directly reachable legacy path would bypass the proposed checks. No
authenticated native identity, confinement, clock or crash recovery is
implemented by this design.
See [authority-boundary](../../specs/authority-boundary/spec.md),
[capability-frontend](../../specs/capability-frontend/spec.md),
[NM001–NM006](../../specs/native-host-canary-mounts/spec.md),
[LH-001–LH-008](specs/linux-host/spec.md) and
[PH-001–PH-010](../add-portable-host-contract/specs/portable-host-contract/spec.md).

## Proposed ordered lifecycle

The steps specify obligations for a future implementation. They are not calls
that can safely be wired together as-is; in particular, the required current
state, authenticated binding and composite effect gate do not yet exist.

1. **Freeze and prepare.** The trusted owner freezes the exact designated
   public fixture and initializes the canary once (NM002). It identifies the
   profile, host incarnation and exact resource mapping. A worker is created
   and controlled without receiving input; its process/lifetime and required
   confinement observations must be available from a qualified host boundary
   before an enforcing profile can use them (LH-002, LH-003, PH-006).
2. **Bind session.** Under that same owner, translate only trusted launch
   evidence and use the existing single `P.open_session_result` transition.
   If accepted, retain its resulting state and issued ID together; if denied,
   install no session result and emit no effect. A typed in-memory value is
   neither a request-correlated native receipt nor evidence of identity. The
   native correlation and replay rules are still open. A newly opened session
   alone does not admit a worker or authorize a mount.
3. **Commit once.** When the fixed Copy's prerequisites are satisfied, the
   existing ADMIT executes `DataOS.commit_from_capability` for the exact
   immutable artifact, plan and reader domain. Retain its returned committed
   session, ledger, intent and original policy. The precise owner-controlled
   relationship of this commit's descriptor to the Linux session is unresolved;
   successful ADMIT cannot establish it by itself. A second ADMIT is denied
   without executing the Copy or charging it again (NM003). If the Copy already
   committed, a later Linux/session/native setup failure must retain that exact
   commit evidence, deny service/effects, and must not roll back or replay it.
4. **Validate and bind an entry.** Before any future issuance, check the
   owner's **current** canary phase, native-bound session/incarnation and live
   Frontend state, registry, authority epoch, rights, exclusive expiry, exact
   plan, original restrictions and paired transfer context. Derive the
   descriptor owner/worker relationship from independently authenticated facts,
   and use the existing `P.issue`/delegation rules only if their exact caller
   and attenuation requirements are met. Neither a historical Frontend
   snapshot nor a raw issued session ID supplies this check. The exact bridge
   and the verified live revalidation entry are not implemented.
5. **Admit and serve under the same current boundary.** Before a Barrier can
   yield a usable `DeliverInputs`, and before each relevant mounted observation
   or protected release, the owner must revalidate current phase, caller and
   session lifetime, live descriptor and registry, epochs, inherited terms,
   exact plan/resource/sink, budgets and required controls. Retain all accepted
   state before an admitted effect. Serialize the check, retained state and
   effect handoff against revocation, or perform a fresh check at a properly
   ordered effect boundary; the native effect/cancellation mechanism is open.
   The existing canary's single public Copy is not re-committed for each read;
   the protected use and publication contracts may require additional checks.
   `DeliverInputs` cannot be equated with a canary read or treated as a second
   route to bytes without an explicitly specified and tested mapping. All
   current ordinary label, integrity, operation and sink obligations remain.
6. **Revoke, quiesce and retire.** An owner-serialized revoke first prevents
   any subsequent admission/observation/effect handoff, then retires the
   relevant identity reference and quiesces/reclaims the affected native
   worker and handles under the existing host contract. Preserve the earlier
   Copy's committed record. A failed cleanup or ambiguous in-flight effect
   leaves the instance incomplete and denies further service; already observed
   bytes cannot be recalled. The mapping from canary revoke to portable-host
   retire/quiesce and recovery is not yet implemented. A restart invalidates
   old session/incarnation attribution and cannot replay ADMIT.

A failure before the Copy commit must not expose input or leave a partial
entry as usable authority. An earlier, separately accepted session is already
part of the owner's state: retain and quarantine or retire it rather than
pretending the session transition never happened. If an implementation
proposes a single tentative transaction with atomic rollback of both models,
it must demonstrate that neither side had committed or emitted an irreversible
native effect. Once the Copy has committed, retain it even when later setup fails; do not
simulate rollback by discarding it. The exact native serialization, transport
failure and crash boundaries remain design work, not proven atomicity.

### Existing wire and denial behavior

`Mount.dispatch` advances its WRITFS1 sequence before normal parsing or
rejection. Therefore a denied duplicate ADMIT is **not** a byte-for-byte
unchanged `Mount.State`: its existing sequence/reply behavior remains, while
the grant, committed session, ledger, intent and original policy must be
unchanged and no second commit or worker/native effect may occur. STOP,
exhaustion and revocation have their own existing phase behavior. Any proposed
stronger composite atomicity must explicitly account for these observable
protocol transitions rather than silently changing them. Existing `LINUXMON1`
and WRITFS1 bytes have not been changed by this document.

## Evidence required before implementation or qualification

The following are reviewed-only gaps, not passing tests:

- A same-owner admission sequence with exactly one Copy, unchanged retained
  commit across duplicate ADMIT and every post-commit failure, and no worker
  effect or serving after a failed bridge; include existing WRITFS1 sequences.
- A legitimate current identity/plan/rights/expiry positive control, then
  independently stale/closed descriptor, revoked registry or phase, changed
  epoch, wrong caller/token, worker-supplied records, wrong incarnation,
  inherited/transferred endpoint and wrong exact resource denials. Explicitly
  test that a historical Frontend snapshot cannot authorize after revocation.
- Interleavings between validation, revocation, restart, effect handoff and
  cleanup, including late completion and an uncertain transport. Test the native
  serialization and failure boundaries separately; a model trace cannot prove
  a real process identity, kernel control or crash-recovery guarantee.
- Before any combined native-host claim, fresh evidence for the exact public
  profile, identity/lifetime, confinement, FUSE operations, descriptor and cache
  behavior, quiescence and recovery under the existing NM/LH/PH contracts.
  The historical public-canary result remains a result for its old profile.

No task checkbox becomes complete from this design or from structural OpenSpec
validation. The previously withheld native identity probes remain unexecuted.
