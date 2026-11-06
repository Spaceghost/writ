# Proposed Linux launch response and session binding

A broker asks the monitor to open worker B while a session for worker A already
exists. If B's launch is denied, the retained session table still contains A.
The current WIP helper can report A's session as though it were the result of
B's request. No complete broker calls that helper in this tree; this is a
prospective integration hazard, not a demonstrated native host exploit.

This note proposes a boundary for review. It does not implement a protocol,
authenticate a native process, authorize effects, or complete Linux host task
1.2. [LH-002 and LH-007](../../../../openspec/changes/add-linux-host/specs/linux-host/spec.md)
and the [authority boundary](../../../../openspec/specs/authority-boundary/spec.md)
remain subject to their existing requirements. The [synthetic identity
report](task-2-synthetic-report.md) records the unqualified Linux work and the
prior withheld native-probe attempts.

## Current gap

`contrib/native-hosts/linux/broker.c:189–206` implements
`broker_reply_session`: it scans the table in a reply and returns the largest
numeric session it sees. It does not check that the reply represents an
admitted Launch. Its header promises the allocated ID but does not state that
precondition. A denied or untranslated response can retain an older session
table. The helper stops scanning at the `+` truncation marker and can still
report success. It also writes its output while parsing, so callers cannot
assume their output remains untouched after a later parse failure.

The retained table is diagnostic, not an allocation receipt.
`hosts/linux/monitor/LinuxHost.bend:1105–1125` renders at most eight sessions;
`broker_monitor.mjs:12–15` bounds the line and reply. An `ADMITTED` status is
not uniquely a session-open result: other successful monitor steps use it too,
and an empty effect list does not distinguish them. Comparing only a revision
increment cannot identify the operation or establish a process's identity.
`HostIdentity.bind_session` returns the allocated ID, and
`HostPrimitives.bend:1012–1017` uses it to install a worker binding, but the
public `P.Step` does not carry that ID in its result. It cannot be recovered
from an arbitrary response table as an independently authenticated allocation.

## Candidate contract

The monitor should return an explicit, typed session-open result from the same
accepted shared transition that installs the worker session. Only that result,
not a native calculation over the diagnostic table, may identify the newly
allocated session. Its precise representation is a design choice: it must keep
one authoritative Bend decision path and preserve the existing revision,
identity, role, delegation and replay obligations. A change to a security law
would require its own rationale and review; none is proposed here.

A viable response and its private transport must satisfy all of the following:

- Bind the result to the particular serialized Launch request, monitor process
  and current incarnation. The request correlation token or transport sequence
  is generated and owned by the trusted monitor/broker protocol; a worker's
  claimed identity is not authority. The successful result carries the exact
  ID the monitor allocated and the resulting monitor revision, in a canonical,
  bounded representation. It is distinguishable from every other operation's
  accepted result. Rejected, untranslated, malformed and unrelated results do
  not carry an issued session.
- Derive the result and current revision from the same monitor-owned state
  transition, and retain the resulting state before any effect is executed.
  A caller-supplied revision, a separately executed authorization, an inferred
  maximum, or an `ADMITTED` string is not sufficient. `LINUXB` currently has
  no expected-revision field. A future comparison must not turn an untrusted
  expected value into an authority fact.
- Serialize requests and their state transitions, either with one in-flight
  call per monitor connection or an explicitly reviewed multiplexer. The
  correlation and reply must identify which Launch completed even if other
  operations or workers are concurrent. An out-of-order, duplicate, stale,
  mismatched or unauthenticated response cannot bind a session.
- Define timeouts and broken pipes as unknown outcomes. If the monitor might
  have retained state, do not infer failure, reuse a prior session, replay the
  request as fresh, or execute an effect. The existing WIP transport stops the
  monitor on failure; a real restart needs a fresh authenticated incarnation,
  current replay state and new native lifetime observations. No such restart
  protocol is established here.
- Parse replies canonically within explicit limits; reject malformed numbers,
  overflow, missing or extra fields and truncation without returning a partial
  session binding or modifying the caller's output. A session ID that cannot
  be represented by the selected wire type must be refused, not truncated.
  A diagnostic table may be shortened, reordered or omitted without changing
  the session identified by the typed result. Do not expose the table, identity
  or diagnostic detail outside separately authorized monitor channels.

The present WIP framing caps a broker frame at 512 bytes and a broker reply at
512 bytes (`broker.h:27–30`); the Node harness also caps its line and reply
(`broker_monitor.mjs:12–15`). These limits are facts about the partial code,
not a selected new typed-response format. A future format must account for all
of its fields and transport overhead without silently narrowing an identity or
state value. The request counter currently passed as the monitor's `now` is
not evidence of an appropriate trusted clock and requires separate resolution.

## Proposed synthetic checks

These cases must exercise the actual Bend monitor dispatch and response path,
plus bounded native transport parsing where appropriate. They are a test plan,
not executed native identity evidence:

1. A valid first Launch and several subsequent valid Launches each return the
   exact fresh session from their accepted transition. Check the expected
   before/after state and revision, the correct binding, and the absence of
   unrelated effects. Vary the monitor-owned caller, token and incarnation.
2. A denied or untranslated Launch with an existing session table yields no
   session result and leaves the whole input state and effects unchanged. An
   accepted Barrier, Usage, or other non-Launch operation must never be
   interpreted as an accepted Launch, including when its status and revision
   resemble one.
3. A missing or zero ID, an ID outside the wire range, duplicate or ambiguous
   response, stale incarnation or revision, mismatched request/sequence,
   forged status, unsolicited response, and response replay must not bind a
   worker or mutate the caller's output. Reject extra fields, invalid delimiters,
   noncanonical numeric encodings, partial reads and overlong lines. Test the
   exact bound and one value beyond it.
4. Repeat successful and denied cases with zero, one, seven, eight, nine and
   more existing sessions. Include diagnostic tables containing `+`, reordered
   entries and IDs at and beyond the chosen numeric boundary. An omitted or
   truncated diagnostic entry cannot become evidence for an allocated ID.
5. Interleave two opens and an unrelated transition. Test duplicate requests,
   competing senders, out-of-order delivery, process death, and lost response
   before and after state retention. No reply may be assigned to the wrong
   request, and timeout must not invent failure, success, or permission to
   replay. A supported multiplexed implementation must test its actual ordering
   rules; a single-in-flight design must refuse or serialize overlap.
6. Use synthetic wrong subject/token, foreign launch fact, stale incarnation,
   PID/start-time mismatch and transferred-endpoint observations, with exact
   state preservation and no effect on denial. These checks verify model
   decisions given synthetic facts; they do not authenticate those facts.

## Native qualification remains separate

A real broker must establish who may supply facts and bind each kernel-observed
uid/gid/pid, pidfd and full process start/lifetime to the trusted launch record
and the exact session for every relevant request. It must address namespace
mapping, parent-created endpoints, endpoint transfers, competing senders, PID
reuse, revocation, teardown and restart. The current monitor compares launch
and peer credentials *inside a supplied frame* and checks a Barrier's stored
subject/token; it does not retain or authenticate a native lifetime binding
(`LinuxHost.bend:290–317`). A typed response alone does not close that gap.

Real host qualification also needs full confinement, setup-failure and cleanup
checks, current host time, and native evidence for the applicable contract and
selected platform. The partial launcher's release-before-failed-start behavior
and the partial monitor harness's request-sequence clock remain open concerns.
A future native test must follow the repository's native-boundary rules and
record actual failures; no native identity probe was run for this note.
