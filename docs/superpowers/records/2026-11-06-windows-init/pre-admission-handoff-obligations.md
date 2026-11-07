# Review deliverable: same-worker handoff and transition obligations

A proposed no-data preflight in the same strict worker needs a way to hand public-canary parameters to that process later. The current report pipe and two events cannot carry a broker-to-worker message, and current launch arguments already contain the mount path and public fixture digest/size. The [actual-worker strict run](../../../../verification/windows-native-run-42320010013/README.md) remains failed and incomplete. The smallest concrete next deliverable is a **reviewed transition contract and adversarial test matrix**, before native source or a run. It must resolve the handoff and channel inventory below; this document is a review artifact, not an implemented state machine or authority source.

## Candidate boundaries

| Transition | Required evidence | Failure behavior |
| --- | --- | --- |
| Create → preflight | Creation-returned process/thread and held image, strict zero-capability LPAC, Win32k/job/UI/child/WFP controls, only explicitly inventoried channels; actor remains unadmitted | Missing or unknown control prevents protected input and yields incomplete |
| Preflight → ready | One bounded, phase-specific report from the retained lifetime, fixed initializer results, checked relevant cleanup and a known channel/state inventory; no claim that success proves denial | Malformed, duplicate, stale, wrong-lifetime, timeout or cleanup uncertainty prevents admission |
| Ready → admitted | Reviewed safe handoff and authority revalidation immediately at admission, including monitor/session generation, live process binding, current capability/epoch/budget/scope, inherited restrictions and any surviving input/output routes | Any stale/unknown fact, concurrent invalidation, unapproved peer or failed Bend decision prevents delivery |
| Admitted → revoked/retired | Existing real-worker channel tests, functioning ordinary positive controls, Bend open/read/revocation, exact result and checked owned cleanup | Native initialization failure is not a denial; failed cleanup or incomplete required observation fails the strict gate |

These labels describe evidence boundaries only. Writ's authority and policy remain in Bend, not in a C handshake or a worker assertion. A real design must specify serialization between transition and revocation, exact revalidation/commit points and how it prevents stale or replayed handoffs; merely checking these facts at different times is insufficient.

The follow-up [handoff and resource-control alternatives](handoff-control-alternatives.md)
compares candidate endpoints and their unresolved security and evidence gaps;
it makes no security-design decision and implements no transition.

## Alternatives requiring design assessment

- **New private inbound handoff:** keep public fixture parameters absent at creation, but add an inherited or securely established broker-to-worker endpoint. Specify exactly who owns each end, how its peer and the retained creation lifetime/session are authenticated, bounded message grammar and sequencing, allowed contents, timeout, closure and treatment after protected input. Prevent the endpoint from becoming a new authority or output route. This is a new reachable handle/channel, requiring a security-design choice about its admitted authority and mediation.
- **Reuse existing IPC:** the current child-to-broker pipe and `ready`/`proceed` events lack a data-bearing broker-to-child path. Bidirectional pipe, shared mapping or other change would alter their semantics and likewise requires an explicit channel/authority design; an event or handle value alone authenticates neither a sender nor a grant. A report parser must not leak arbitrary worker-controlled diagnostic fields after protected input.
- **Keep public fixture metadata in launch arguments:** avoids a later parameter channel but does not satisfy the previously proposed boundary that excludes the public canary path and digest during preflight. It may be a distinct public-fixture test with its actual scope disclosed; accepting that boundary change is a separate design decision, and it cannot be described as a no-data-path preflight.

In all alternatives the existing worker must retain its three-phase report capability or replace it with a separately reviewed mechanism. Closing only an added preflight handle does not eliminate these existing routes. Enumerate the worker's retained handles and peer access, public outputs, profile/registry/cache state, file/mapping/device access, logs/errors, status and timing channels; specify how each is prevented or mediated under WH-004/007. A self-report is untrusted. Do not assume all reachable state is absent merely because an initial handle list or one PSS snapshot was small.

## Hard unresolved question

A process that has already initialized may have created additional threads, handles and shared OS state. Existing PSS evidence is an observation at a point in time and does not establish quiescence until admission; suspending one thread is not a supported general synchronization barrier. A design must identify a documented, bounded and identity-bound way to enforce or mediate the relevant reachable routes despite concurrent worker/peer activity, or limit the claim and remain incomplete. It must account for crashes, reuse, changed token or job, broker/monitor restart and concurrent revoke/commit. No same-worker preflight implementation should proceed solely because a readiness event was received.

## Proposed adversarial test matrix

These are proposed test obligations, not executed tests or a claim that the transition is implementable. Each scenario must retain evidence for the exact held lifetime and leave unrelated sessions/resources untouched.

| Scenario | Required result |
| --- | --- |
| Wrong process lifetime, peer, session generation or monitor incarnation supplies a report or handoff | Reject it; no protected delivery or commit |
| A correct-looking preflight report is duplicated, replayed, truncated, extended, malformed or arrives in the wrong phase | Reject or terminate the transition; no protected delivery or commit |
| A worker requests protected input before admission, or a sender introduces an undeclared data/authority field | Deny before delivery and mark the transition incomplete; no commit |
| Protected input is unexpectedly delivered before admission | Preserve the breach/failure, deny subsequent protected use and stale/uncommitted release; do not claim to erase observed data |
| Capability, epoch, scope, budget, inherited restriction or worker token/job/lifetime changes or becomes unknown before the decision/commit | Revalidate and reject the stale operation; no unauthorized delivery or commit |
| Revocation or broker/monitor restart wins before admission or handoff | Reject the stale transition; no protected delivery or commit |
| Revocation or restart occurs after admission | Deny subsequent protected use and stale/uncommitted release; it cannot erase data already delivered |
| An unapproved output handle, peer or shared object is discovered before input | Deny protected dispatch and prevent publication through that route |
| Such a route is discovered after input | Preserve the failure, deny subsequent protected use and stale/uncommitted release; observed data cannot be recalled |
| Worker, peer or broker times out, crashes or cannot verify cleanup before input | Fail incomplete, preserve evidence and prevent protected delivery/commit; retain shared controls while worker exit is unverified |
| Timeout, crash or cleanup uncertainty is discovered after input | Preserve the failure, deny subsequent protected use and stale/uncommitted release, and retain shared controls while worker exit is unverified; already observed input cannot be erased |
| All declared facts remain valid and the authorized ordinary/native positive controls work | Only the existing Bend-authorized transition may proceed; the preflight itself earns no confinement credit |

## Required review and tests

Before implementation, name the trusted peers and channel ownership, exact handoff grammar and generation/lifetime binding, policy decision/commit points, concurrency and teardown guarantees, and which independent Windows readbacks substantiate each fact. Record separately any facts without a supported readback and leave those cases incomplete. A corresponding **Bend-authored** state/authority model and meaningful synthetic tests should reject malformed, replayed, wrong-worker/session, early, duplicate, stale, post-revoke and race-losing transitions; local native code may translate OS facts and enforce only admitted effects. Later native tests must exercise the real strict worker with working positive controls, explicit observed denials and cleanup, without calling a separate diagnostic a worker result. No source/spec behavior change or native run is authorized here.

No user decision is needed merely to research these alternatives. Selecting a new worker-visible channel, accepting a weaker no-data boundary or changing capability, Win32k or acceptance requirements is an actual security-design choice; no such choice follows from the no-data initializer correlations. The [feasibility review](same-worker-pre-admission-feasibility.md) retains the current source constraints and open issues.
