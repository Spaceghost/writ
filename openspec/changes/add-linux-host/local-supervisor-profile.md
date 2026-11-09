# Proposed local Linux supervisor profile

A local supervisor starts one reader for the existing public canary. The reader
is allowed to use the view only while its separately provisioned source-read
and destination-write approvals, exact descriptor and worker session remain
current. If either approval is revoked after the one Copy commits, later
observations must stop without replaying the Copy or discarding its committed
session, ledger, intent or provenance.

Josh selected a local operator/supervisor as the first design direction. This
file specifies a proposed development profile under
[LH-011–LH-017](specs/linux-host/spec.md), alongside the existing
[local owner ordering](live-owner-ordering.md). It does not install a trust
root, authenticate a principal, start a broker, implement a live authority
feed or qualify a Linux host. The current canary is still the fixed, separately
qualified public fixture, and the combined bridge remains unimplemented.

## Trust and ownership

The operator controls the supervisor's launch, configuration and protected
administrative channel. The exact mechanism that authenticates the operator,
protects configuration and recovers it after restart is an implementation and
acceptance requirement; a pathname, root UID or process owning a socket is not
by itself proof of that mechanism. The supervisor admits no protected work if it
cannot establish the selected trust boundary and exclusive ownership.

The operator or another explicitly authenticated local authority provisions
source-read and destination-write authority as separate roles in the issuer's
directory, together with the exact object-version placements. A person may
hold both roles only when both were deliberately provisioned; being the local
operator, owning the destination or launching a worker does not silently create
source consent. Issuance's existing authenticated submit/register/revoke
transitions decide the approved scope in Bend. No new audit approver, price,
settlement rule or authority veto is inferred from this profile.

The supervisor must authenticate the local service principal for a worker and
bind that principal to its precise launched process lifetime, session,
incarnation and profile. UID, PID, start time, pidfd and kernel peer facts are
local observations that may help bind a lifetime; none alone proves the original
human or a portable credential. `Reference.caller(1)` and its deterministic
internal token are synthetic canary data, not a provisioned local identity.
The actual authentication mechanism, session transport, protected channels and
lifetime correlation are not implemented by the current model.

## Proposed first bootstrap and updates

1. An operator explicitly launches a trusted supervisor with protected local
   configuration naming its local service principal, source and destination
   placements, separate source-read and destination-write roles, and its
   protected administration endpoint. The supervisor establishes exclusive
   instance ownership and verifies its configuration and administrative channel
   before admitting protected work. The authentication, authorization and
   configuration protection, channel provenance and non-transfer mechanisms
   still need a concrete implementation and acceptance evidence; launching with a UID or knowing an endpoint is not
   sufficient by itself.
2. Through authenticated administrative channels, the separately provisioned
   source and destination roles submit and revoke their respective approvals
   through the existing Issuance transitions. The supervisor attaches each
   `from` from the authenticated channel's provisioned role, never from an
   administrator-supplied principal field, and serializes transitions with its
   retained issuer state. A single operator may hold both roles only if
   independently provisioned for both, and two approvals must be accepted;
   launching the worker does not itself create either approval.

3. The supervisor launches and owns its reader, binds the precise observed
   process lifetime and session to the configured local service principal, and
   supplies the resulting correlation to the sole owner. Ordinary worker
   requests cannot assert or replace the principal, issuer, registry, clock or
   retained state. Native peer/lifetime checks and a request-correlated session
   receipt still have to be implemented and tested for that binding.
4. Once that binding is established, and before any protected worker input,
   registration derives `from` from the authenticated subject/service-session
   binding and uses a supervisor-owned fresh capability token from a
   cryptographically secure source, never from the requester, with exact scope
   checks. The token does not replace authenticated subject binding. An
   administrator acting for the subject requires an explicit authenticated
   delegation contract; either approval role alone does not supply one.
5. On a missing or unauthenticated channel, invalid configuration, ambiguous
   instance ownership, or uncertain restart, the supervisor leaves the profile
   incomplete and refuses protected effects. Restart must reconcile any prior
   commit and replay state as well as authority and clock continuity; fresh
   authorization alone is insufficient. Safe revocation and cleanup remain
   available according to their authenticated control paths.

This is an implementable sequence of responsibilities, not an assertion that
any current endpoint, trusted configuration store or authenticated channel
already exists. The channel mechanism, exclusivity and recovery design are
separate implementation and host-qualification work.

## Candidate administrative transport: source constraints

Consider a separate local `AF_UNIX` `SOCK_SEQPACKET` channel for each explicitly
provisioned authority role, with `SO_PASSPIDFD` enabled on the receiver before
it accepts messages. This is a candidate to evaluate, not a selected or
implemented authentication method. The operator's protected bootstrap must
first bind each role to a trusted program and exact process lifetime; a public
path, inherited socket, UID, PID or received pidfd alone cannot create that
binding. Source- and destination-role submissions and revocations must attach
`Issuance.from` from the supervisor's retained mapping, never from a message.
Registration instead derives the subject from its authenticated worker session.
All of these actions still need the sole serialized state owner and the existing
Bend issuance transitions.

In upstream Linux v6.5, `SO_PASSPIDFD` and `SCM_PIDFD` were introduced by
[commit 5e2ff670](https://github.com/torvalds/linux/commit/5e2ff6704a275be009be8979af17c52361b79b89).
In that version the [UNIX send path](https://github.com/torvalds/linux/blob/v6.5/net/unix/af_unix.c)
captures a process reference when it queues a message, and the
[receive path](https://github.com/torvalds/linux/blob/v6.5/include/net/scm.h)
constructs the returned pidfd from that stored reference. A transferred socket
used by a different ordinary process is therefore distinguishable from the
original process at the message boundary, assuming the receiver checks the
pidfd against an independently retained, matching lifetime. A connection-time
`SO_PEERCRED` snapshot or an endpoint's possession alone does not establish
which process sent a later message. Queued data may outlive its sender: the
owner must specify how exit, revocation and effect admission are ordered; a
pidfd by itself does not serialize those events.

**This is not an unforgeable sender identity.** In the v6.5
[SCM credential handling](https://github.com/torvalds/linux/blob/v6.5/net/core/scm.c),
a sender with `CAP_SYS_ADMIN` in the user namespace owning its active PID
namespace can supply a different visible PID; the kernel replaces the same
stored PID reference from which it then creates `SCM_PIDFD`. UID/GID values
may also be supplied from the sender's real, effective or saved IDs, or more
broadly with the applicable `CAP_SETUID`/`CAP_SETGID` in its user namespace.
A candidate deployment must establish that unauthorized senders cannot obtain
those relevant capabilities, control the role process, or proxy its actions;
namespace creation, visibility, mappings, ptrace and other process-control
channels must be included in that argument. The kernel does not establish a
human's identity, the integrity of the configured role program, or what that
program approved. A process can execute a different image without changing its
process lifetime; close-on-exec handling and executable/control confinement
therefore require separate design and evidence.

The received descriptor number is not the retained descriptor number or a
portable identity. Linux 6.5 support for `SCM_PIDFD` alone does not justify
comparing `fstat` inode values: older anonymous-inode pidfds shared an inode.
Upstream [v6.9 pidfs](https://github.com/torvalds/linux/blob/v6.9/fs/pidfs.c)
changes the representation, and the [v6.18 pidfs implementation](https://github.com/torvalds/linux/blob/v6.18/fs/pidfs.c)
explains 64-bit inode comparison and its 32-bit generation issue; v6.9 uses a
different 32-bit allocation strategy.
A possible restricted 64-bit profile would retain both pidfds, verify their
actual pidfs provenance, compare the appropriate device/inode identity, and
fail closed if the required semantics cannot be established. The exact kernel,
architecture, backport behavior, lifetime and namespace semantics need review
and native acceptance; version numbers alone do not qualify a host. The
[pidfd API](https://man7.org/linux/man-pages/man2/pidfd_open.2.html) describes
exit polling and the precautions required when opening a child pidfd after
creation. A `clone`-created pidfd or a carefully protected child-reaping
protocol can prevent the initial numeric-PID reuse window, subject to its own
validation. Polling is not an atomic authorization-and-handoff operation.

A prospective receiver must use one bounded record per request, reject missing,
duplicate, malformed or negative pidfd control data, payload or ancillary
truncation (`MSG_TRUNC`/`MSG_CTRUNC`), unexpected control messages and all
identity, system-call or resource errors. It must close every installed
received descriptor on every path, including unexpected `SCM_RIGHTS`, and set
close-on-exec where applicable. `SCM_PIDFD` creation can itself fail; a control
message's presence is not sufficient. Authorization must not advance on an
incomplete receive, and cleanup and revocation remain available. Protected
configuration, trustworthy startup, namespace/capability isolation, message
provenance under descriptor transfer, exec and process control, FD lifetime,
clock, serialization and restart all remain unimplemented and require
adversarial testing for the exact combined profile. No such test or native
identity probe was run for this design note.

## One state owner and one effect path

The combined profile needs one serialized owner of the issuer, current
Frontend and descriptor, Linux session/incarnation, canary phase, exact
immutable artifact, clock state and the retained committed Copy result. At
each admitted use it must rebuild `Issuance.reads`, `Issuance.writes` and
`Issuance.registry` from the same current issuer, subject, time and epoch;
`Frontend.checked_plan` must re-resolve the descriptor and paired plan. The
applicable original graph, integrity, provenance, operation, destination,
budget and confinement obligations remain independent requirements. A
successful Frontend check is not the complete host or publication gate.

The single existing `DataOS.commit_from_capability` path commits the exact
Copy. It is not repeated for every observation. The owner retains the exact
returned committed session, ledger, intent and original policy, including
through later denial, setup failure and recovery. A raw descriptor, a cached
registry, a diagnostic table row or a locally constructed record is not a new
commit or a release permit. An effect can be handed off only after the owner
retains its accepted state and orders that handoff against revocation. If the
old standalone `Mount.dispatch` remains reachable around the joint checks, the
combined profile is not admitted.

The current [`MountAuthority.descriptor`](../../../writfs/MountAuthority.bend)
uses the full DataOS commit but discards its Frontend input and does not own a
live registry or worker session. [`LinuxHost`](../../../hosts/linux/monitor/LinuxHost.bend)
retains synthetic launch credentials and an exact in-memory session result; its
diagnostic response is not a request-correlated native receipt.
[`HostPrimitives.issue`](../../../HostPrimitives.bend) is not a substitute for
current Frontend/registry checks. Neither worker input nor a caller-controlled
boolean can supply the missing current authority. The operator selection does
not change these facts.

## Clock, denial and recovery

The owner samples a trusted monotone clock before handling untrusted requests,
including malformed requests and requests later denied by policy. It retains
the high-water mark separately from Issuance, Frontend, session and ledger
state. Thus observing time 150 can advance only the clock owner while an
expired policy request leaves those policy states unchanged. A subsequent
sample of 149, an unavailable clock, overflow or ambiguous continuity poisons
new grants, metadata or byte observations, input delivery, publication and
effect handoff. Revocation, retirement, quiescence and STOP remain available
for safe cleanup. Poisoning cannot recall an effect already handed to the host.

The existing Linux `CLOCK_MONOTONIC` use is for private-pipe deadlines; it is
not an Issuance time source. A monotone clock may restart at a lower origin on
reboot. The profile needs an independently justified continuity and
rollback-resistant recovery scheme for the watermark, issuer transitions,
committed ledger and invocation replay state. If those cannot be established,
the instance remains incomplete and cannot revive old grants or replay the
Copy. A new authorization does not eliminate the need to reconcile a possibly
committed earlier operation. This proposal does not assert durable storage,
crash atomicity or cleanup of an uncertain host.

## Evidence and staged implementation

[`LocalSupervisorTests.bend`](../../../LocalSupervisorTests.bend) constructs
synthetic separate source and destination authorities for the exact canary Copy
plan. It passes the exact issuer-projected Frontend change and context to the
existing canary authority helper, observes its DataOS commit, then revokes each
approval in turn. Fresh projections deny the same descriptor; both cached
commit-time projections still resolve. A retry with the returned committed
session and ledger is rejected with those two states unchanged, and the original
intent's provenance is inspected. The fixture is Free with zero charge; this
trace does not demonstrate nonzero-charge replay. These checks do not invoke
`Mount.dispatch`,
observe bytes, authenticate an operator or establish a serialized host owner.

Before enabling the combined profile, implement and independently review: the
protected administrator/worker channels; the current issuer and clock owner;
exact binding of issued session, descriptor owner, reader domain and native
lifetime; one common gated observation/effect consumer; revocation and
stop/quiescence ordering; and rollback-resistant recovery. Tests must include
source and destination revocation, stale projections, expired and regressing
clock samples, denied and malformed requests that advance the clock watermark,
transferred endpoints, prior committed Copy preservation, interrupted effect
handoff and uncertain restart. Native identity, confinement, mount and recovery
evidence must then be run for the exact combined profile under LH-010 and
[NM001–NM008](../../specs/native-host-canary-mounts/spec.md). Existing model or
historical public-canary tests do not substitute for those host results.
