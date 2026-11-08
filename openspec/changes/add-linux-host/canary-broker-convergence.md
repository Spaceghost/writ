# Converging the Linux public canary and worker broker

An admitted reader opens the single public `data` file through Writ's existing
FUSE canary. A protected worker, by contrast, would need an authenticated
launch and a confined execution profile before receiving any input. Josh
selected the direction in which the canary reader becomes a worker profile of
the broker, with the result re-qualified. The current canary and the unfinished
broker do not yet form that combined path. This is a proposed integration plan,
not an implemented adapter, an executed native test, or a protected-host claim.

Josh's selection is recorded in the local q18 board thread and is **his**
direction, not an answer attributed to Spaceghost. The [earlier recovered
answers and remaining questions](../../../docs/superpowers/records/spaceghost-questions.md)
remain distinct. In particular, no choice of audit approver, settlement rule,
or authority veto is inferred here.

## Existing paths and evidence

| Path | Current scope | What it does not establish |
| --- | --- | --- |
| [Linux public-canary mount](../../../contrib/native-hosts/linux/README.md) | A native FUSE service freezes one designated public file, joins callbacks to its retained reader lifetime, and calls the shared Bend canary through [WRITFS1](../../../contrib/native-hosts/PROTOCOL.md). Its [existing VM evidence](../../../contrib/native-hosts/linux/verification/README.md) records mounted I/O, outsider denial, revocation and failures for that exact profile. | A general broker, external grant issuer, complete protected worker, durable publication, or qualification of a combined implementation. |
| [Linux monitor model](../../../hosts/linux/INVENTORY.md) | `LinuxHost.bend` translates bounded synthetic launch/session, profile, route and report facts into the shared Bend host model; [named tests](../../../openspec/traceability/linux-host.md) cover its model portion. | Authentic kernel evidence, native worker confinement or Linux host qualification. |
| [Separate broker WIP at `63eece8`](https://github.com/Spaceghost/writ/tree/63eece827bd3ca92edfcc78cc0d2506917991948) | Off-master source and records for an unfinished launcher, broker and private monitor harness. The unused helper that inferred a session from a diagnostic table was removed in that revision. | The new in-memory typed result or a consumer of it, a request-correlated transport receipt, a complete launcher/broker, or a tested production authority path. Its earlier results and source remain historical. |

The WIP's [session-response design](https://github.com/Spaceghost/writ/blob/63eece827bd3ca92edfcc78cc0d2506917991948/docs/superpowers/records/2026-11-05-linux-host/session-response-design.md)
is still proposed: a diagnostic session table is not a session-allocation
receipt. The shared Bend transition now exposes its exact issued session in a
typed in-memory result, with Linux Launch projecting it into a distinct model
outcome. `LINUXMON1` remains unchanged and does not carry that result; request
correlation, frame bounds, authenticated native identity and a broker consumer
remain open. The returned value and its public constructors are not credentials. The WIP source also has a separate launch-order issue: after an unsuccessful
start-time observation, `launch_worker` writes the child's release byte before
returning failure for the zero value. Whether the child proceeds and how it is
retired have **not** been tested. The post-clone failure leaves a recorded
pidfd, but the header does not define failure-path ownership and reaping is a
separate operation; namespace-map writes also discard failures. No complete
broker call site or exploit is claimed. A [synthetic identity record](../../../docs/superpowers/records/2026-11-05-linux-host/task-2-synthetic-report.md)
retains the original observations and the two earlier classifier-withheld native
identity-probe attempts; this plan does not retry them. q19's synthetic-case
choice supplies model evidence, not authenticated Linux identity.

The public canary has its own protected-data limits and [NM001–NM008](../../specs/native-host-canary-mounts/spec.md)
contracts. The proposed combined host must also meet [LH-001–LH-010](specs/linux-host/spec.md)
and the [portable-host contract](../add-portable-host-contract/specs/portable-host-contract/spec.md).
Neither a successful `LinuxHostTests.bend` run nor a historical FUSE pass
transfers those claims to a new composition. Keep the existing source revisions,
logs, failed/incomplete observations and profile names; do not rewrite old
results as a pass for the new binary.

The [live-owner ordering review](live-owner-ordering.md) traces the existing
state and authority gap and records the proposed sequencing as unimplemented.

## Proposed combined boundary

The target is one supervisor/broker owning the selected worker's lifetime,
resource bindings, private monitor transport and the FUSE presentation. A
public-canary reader is an explicitly named, bounded worker profile of that
boundary; it does not stand in for the later protected-transform profile. The
worker never supplies the subject, current `Context`, registry, ledger, profile,
launch result or native-observation claims that the monitor treats as facts.
Authenticated subject and the trusted launch/endpoint binding must be derived
by the enforcing monitor and its qualified host boundary. A UID, PID, start time,
pidfd, FUSE context or socket possession is a local observation, not a portable
credential or proof of the original human.

The FUSE callbacks translate only the admitted fixed profile's operations and
native observations into bounded requests to the **same authoritative Bend
state and decision path**. Bend remains responsible for grants, current
identity/session scope, labels, budgets, replay and final effects. Native code
can manage Linux resources and transport admitted effects, but must not create
an alternate policy or publication decision. An unsupported, ambiguous, stale
or transferred endpoint is denied or causes an incomplete instance; no numeric
descriptor reuse or caller-selected slot can create authority.

In the existing canary, `ADMIT` calls the full `DataOS.commit_from_capability`
gate for its fixed public Copy and the monitor retains the resulting state.
Integrating a worker-session transition must not repeat that committed Copy,
replay its charge, discard the retained session/ledger/write intent, or replace
the exact plan with a native pathname or a diagnostic reply. Define the order,
shared state ownership, failure atomicity and correlation of the existing
`LinuxHost` and mounted-view decisions before connecting them. If that contract
cannot be met, do not deliver bytes. A successful public fixture is not proof
of protected admission or settlement.

## Required lifecycle and failure behavior

1. **Create and bind.** Establish a monitor-owned incarnation, exact selected
   profile and launch record, current authority and a live owned process. A
   typed, request-correlated session-open result comes only from the accepted
   Bend transition, within fixed frame and numeric bounds. Diagnostic tables,
   `SO_PEERCRED` taken when a parent created a socketpair, and endpoint
   possession cannot substitute for the accepted result or live identity.
2. **Confine before data.** Establish and verify each required namespace,
   privilege, `no_new_privs`, seccomp, Landlock, resource, channel and descriptor
   restriction before releasing a worker or exposing input. Child creation,
   partial setup, unsupported controls, unavailable clock and cleanup failures
   must have explicit fail-closed outcomes. A start-time observation of zero
   cannot be treated as verified merely because two unverified facts compare
   equal. Do not retain the WIP release-before-failure ordering as a guarantee.
3. **Bind the view.** Register exactly the sealed object/version and its reader
   domain under the current session and profile. Retain sealed bytes and their
   identity as a local resource; a later caller-controlled pathname or recycled
   descriptor cannot select a substitute. For the current public fixture, the
   bytes are frozen once; this does not claim an atomic version of a concurrently
   changing original file. Protected inputs need their own authenticated exact
   scope and immutable delivery evidence.
4. **Serve under current authority.** Translate supported FUSE lookup, metadata,
   open and read operations into the common Bend path with a current native
   binding. Preserve the canary's admitted-only metadata, fixed public root,
   bounded non-reused handles, read bounds, zero-lived attribute/dentry caches
   and direct-I/O behavior. The host must separately mediate any page caches,
   descriptor copies or already observed bytes it claims to control. Unsupported
   write, mapping, direct-copy, ioctl, async and inherited/transfer paths deny
   unless separately specified and evidenced; ownership of a descriptor alone
   never transfers the original subject.
5. **Revoke and retire.** Recheck current capability, epochs, inherited terms,
   exact plan and budget before any future release. Revoke blocks new observation
   and uncommitted publication; it does not recall bytes already observed. Close
   remains owner-bound cleanup and cannot be a fresh grant. The broker must
   quiesce the affected worker, handles and output paths, account for duplicates,
   and retain a clear incomplete result if any required cleanup or identity
   evidence is missing. A crash, poisoned monitor channel, timeout or ambiguous
   sequence stops service; no fallback to a separate legacy monitor or replay
   of `ADMIT` is permitted.
6. **Publish and recover only under the applicable contracts.** A protected
   transform's output remains private until its exact sealed artifact, current
   authority and durable commit/recovery path meet the existing requirements.
   The current public canary is not evidence of that path. Preserve original
   provenance and independently authorized disclosure; do not add a native
   release decision, strip labels or infer a price/charge decision from q18.

## Staged work and evidence gates

The steps below are proposed work, not completed acceptance. Keep every
[Linux host task](tasks.md) unchecked until its stated evidence exists.

1. **Contract and ownership review.** Pin the profile/version, exact source
   and immutable fixture; enumerate all process, file, pipe, mount and monitor
   state owners, effects and failure paths. Map each FUSE operation and every
   allowed transport message to its exact existing Bend entry and the source,
   expiry and lifetime of each authority fact. Resolve the single-state and
   one-admission ordering before code. The named contracts are NM001–NM008,
   LH-001–LH-010 and PH-001–PH-014; cite exact tests or explicit reviewed-only
   gaps in [Linux traceability](../../traceability/linux-host.md).
2. **Bend model and replay.** Add the narrow shared profile composition in
   Bend, with synthetic launch/session records clearly marked. Cover allowed
   and denied admission, stale session/incarnation, unchanged denial state,
   exact resource scope, duplicate admission and preserved ledger/intent, and
   no unauthenticated fallback. Inspect generated backend behavior and run the
   named Bend tests and existing proof verdict. A model success is not a native
   endpoint or process identity.
3. **Private adapter integration.** Only after independent contract review,
   adapt native resource ownership and fixed transport to the common monitored
   transition, including a typed correlated session-open reply and truthful trusted
   clock. Retire or repair WIP paths rather than promoting them as qualified.
   Verify compile-time/native transport properties separately from runtime
   authority. The approved C/JS boundary does not authorize policy in native
   code or a root Go module. Do not execute the prior withheld identity probe.
4. **Fresh public-canary requalification.** On an independently suitable native
   Linux test host/profile, exercise both allowed and denied operations against
   the **combined** executable. Retain exact build inputs, expected profile,
   real requester and lifetime evidence, pre-admission controls, warm-cache
   outsider checks, read/open after revocation, duplicate and transferred
   descriptors, transport failure, process death, teardown and refusal at every
   required setup step. Positive controls must show the attempts reached the
   intended boundary; an environment failure is incomplete. The original
   profile's historical pass remains historical.
5. **Protected-host qualification separately.** Require the complete input and
   output inventory, typed identities and delegated recipient checks, no bypass
   via inherited resources, per-use revalidation, sealed outputs, replay-safe
   durable commit and recovery, resource and audit evidence under the chosen
   policy. Use actual malicious-worker and crash/restart evidence for each
   claimed profile. Keep host qualification and GPU execution unclaimed until
   independently demonstrated; CPU fallback is not a GPU test.

Open design work includes request-correlated session transport and clock,
monitor state ownership across the two existing protocols, exact permitted
FUSE operation/descriptor semantics, the control-to-kernel map (including
Landlock and `no_new_privs`), bounded state and event retention, and native
recovery. The previous q18 questions on audit authorization and settlement are
still for Spaceghost. Nothing here fixes or implies an answer to them.
