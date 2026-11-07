# Registry ETW feasibility for a separate no-data initializer

A zero-capability LPAC initializer returns `WSAStartup` error 10107. A future
separate, fixed synthetic child might be observed while it initializes: an
owned, short-lived registry trace could count *observed* registry-open statuses
during that child's measured initialization window. This could guide further
investigation, but even an observed denial would not establish why Winsock
failed. The real worker, its failed checks and the existing acceptance gate are
unchanged. The [existing research](strict-worker-next-research.md) describes
the different worker lifetimes and the retained failure.

This is a design-only feasibility note. No trace, provider, native diagnostic or
policy change is implemented or authorized by this note. In particular, this
is **not yet a safe-to-run recipe**: provider attribution and loss controls,
resource ownership, and possible OS trace persistence still need independent
review before any implementation or disposable-VM execution.

## Documented events and unresolved attribution

Microsoft documents the [kernel Registry class](https://learn.microsoft.com/en-us/windows/win32/etw/registry),
GUID `{ae53722e-c863-11d2-8659-00c04fa321a1}`, enabled with
`EVENT_TRACE_FLAG_REGISTRY`. The published version-2 `Registry` class lists
`EVENT_TRACE_TYPE_REGOPEN` (type 11); the
[Registry_TypeGroup1 schema](https://learn.microsoft.com/en-us/windows/win32/etw/registry-typegroup1)
lists an operation NTSTATUS, key handle and key name. The class pages differ in
their description of type 27; this proposal only considers type 11. Verify the
actual event header, class GUID, version, type and runtime schema before using
any observed event. A different, unavailable, malformed or ambiguous schema is
incomplete; do not infer field offsets or cast an unaligned payload to a C
structure. Microsoft's [MOF guidance](https://learn.microsoft.com/en-us/windows/win32/etw/retrieving-event-data-using-mof)
explains that payload alignment and versions need care and recommends TDH.
Schema lookup and all variable-length data must themselves be bounded.

An event header's execution PID is a candidate attribution, not automatically
the subject of every deferred or system-context operation. A held process
handle and its creation time establish the diagnostic lifetime independently of
PID reuse, but do not turn every event bearing that number into a proven causal
operation. Calibrate the exact observed event version and attribution on the
actual runner with separately identified self-created control processes. Reject
missing, ambiguous, out-of-window or inconsistent attribution. A PID filter
for `EnableTraceEx2` is [documented for scoped providers](https://learn.microsoft.com/en-us/windows/win32/api/evntprov/ns-evntprov-event_filter_descriptor),
but its effective application to these classic kernel registry events has not
been established. Neither privacy nor completeness may depend on assuming it
filters before kernel buffering.

[Winsock's documented tracing events](https://learn.microsoft.com/en-us/windows/win32/winsock/winsock-tracing-events)
include socket create/close and catalog *changes*, not a documented event that
explains a failed `WSAStartup`. Microsoft's [Winsock tracing guidance](https://learn.microsoft.com/en-us/windows/win32/winsock/control-of-winsock-tracing)
also says an event's execution PID may represent a kernel or worker context.
Do not replace the registry hypothesis with an undocumented Winsock event or
claim that a socket-create event explains initialization.

## Candidate observation and controls

If a later implementation is reviewed, run only on a fresh disposable Windows VM
with no protected Writ input, personal data or other sensitive workload. Use a
fixed self-created diagnostic image and fixed initializers, with no caller-
selected provider, PID, executable, registry path, data, mount, policy handle
or output target. The admin trace controller is separate from the diagnostic;
it grants the child no privileges, capabilities or relaxed worker controls.
Preserve the strict worker and its actual test order. A separate no-data LPAC
child may reproduce selected configured controls only where verified by native
readback, with an ordinary child as an independent positive initializer control;
the diagnostic is not a replacement worker and never receives a later handoff.

Retain the creation-returned process handle, PID and creation time for every
self-created child until its exit is observed; bind a fixed readiness/start/end
handshake and initializer return code to that lifetime. Start the trace and
consumer before the bounded initializer window; stop, drain and account for it
afterward. For the LPAC and ordinary diagnostic windows, keep only bounded
counts by documented operation and numeric status for events whose attribution
passes the reviewed controls. Do not record or upload raw payload, key names,
registry values, stacks, unrelated events or ETL files. The trace itself may
nevertheless transiently contain OS and other-process data, as explained below.

Calibrate separately with self-created ordinary control children: one performs
an open-only operation on a fixed known existing key and checks its API result;
another attempts a fixed absent synthetic name and checks `ERROR_FILE_NOT_FOUND`
without creating a key. If either premise, exact version/type, status mapping,
PID/window association or expected control event fails, the observation is
incomplete. Observe the controls' held identities separately, and verify that an
event from the other child is not attributed to the target. No registry value is
read, no key or ACL is created or modified, and no event key name is exported.
A passing control shows this observation path worked for that operation on that
runner; it does not establish capture of every registry call or prove a denial
was made by Winsock. Do not assume that all failures appear as `REGOPEN`, that
NTSTATUS maps one-to-one to Win32 errors, or that access during an initializer
was caused by that initializer rather than another thread or OS activity.

## Resource, privacy and failure boundaries

The [StartTrace documentation](https://learn.microsoft.com/en-us/windows/win32/api/evntrace/nf-evntrace-starttracea)
says NT Kernel Logger control requires administrative privilege or LocalSystem,
that sessions consume finite system resources and can remain active until
stopped. For the documented **deprecated** NT Kernel Logger, the candidate
uses `InstanceName = KERNEL_LOGGER_NAME` and
`Properties.Wnode.Guid = SystemTraceControlGuid`; Microsoft warns that these
legacy identifiers may conflict with other components. Microsoft prefers the
newer `EVENT_TRACE_SYSTEM_LOGGER_MODE` for system loggers, but its equivalence
for this exact registry observation, filtering and ownership plan has not been
established and is not assumed here.

Verify actual controller rights and session ownership; never elevate or alter
the child. Use only the session handle returned by successful creation; an
existing name or GUID, unsupported concurrent logger, access failure, unknown
handle ownership or failed readback means incomplete. Never stop or alter an
existing session merely because its name or GUID matches. Stop only the session
created by this invocation, check stop and consumer retirement, and record
uncertainty. A disposable VM's destruction may bound the environment; it is not
proof of successful in-guest cleanup.

Candidate limits for review, not verified implementation properties: at most
64 KiB per ETW buffer and 64 buffers after querying effective properties; at
most 50,000 delivered events, a 30-second observation deadline, 2 MiB of
consumer-owned working memory and 8 KiB of fixed-format output. ETW may adjust
requested buffer sizes/counts, and system CPU count influences minimum buffers;
check preconditions and effective properties and stop incomplete if limits
cannot be established. The [properties documentation](https://learn.microsoft.com/en-us/windows/win32/api/evntrace/ns-evntrace-event_trace_properties)
describes these adjustments. These numbers do not prove an upfront bound on
kernel allocations before readback, nor bound all OS allocations or disk use;
that gap and the VM's resource/timeout plan need resolution before a run.
Callback input, metadata and status counters need checked arithmetic, bounded
parsing and no unbounded queue. A supervisor must bound every wait and stop
only its own children and session, with no global cleanup.

Use real-time mode, request no explicit trace file and do not export trace
payloads. This is **not a guarantee of no disk persistence**: Microsoft notes
that real-time tracing can use a [backing file](https://learn.microsoft.com/en-us/windows/win32/etw/about-event-tracing)
when the consumer is absent or slow. It may transiently receive names from
other processes before any consumer-side filter. Do not use this design on a
shared or sensitive host, upload an ETL/backing file, or claim that a PID
filter prevents such exposure. Establish and review the runner's credential,
background-workload, ETW backing-store and disposal boundaries before any
execution. If the requirement is that no raw events may ever reach disk, this
proposal remains blocked until that stronger property is demonstrated.

Record actual effective configuration and the final `EventsLost`,
`LogBuffersLost` and `RealTimeBuffersLost` statistics. A loss, failed
start/stop/drain, cap, timeout, unsupported event, missing control, child exit
uncertainty or unexpected output makes the observation incomplete. Counters can
report loss; zero reported loss does not show the provider instrumented every
operation. Use only bounded aggregate observations and stage/status codes; no
unfiltered trace, names or underlying OS state may enter repository evidence.

## Interpretation and remaining gates

A status count is a correlation in this different synthetic lifetime. It cannot
establish which key or component caused 10107, prove no unobserved operations,
prove a restriction, or supply evidence for the real worker's failed
network/clipboard/COM checks. Any difference in initialization, tracing,
token, handles, environment, timing or child image must remain explicit. The
[baseline native canary contract](../../../../openspec/specs/native-host-canary-mounts/spec.md)
and [proposed Windows contract](../../../../openspec/changes/add-windows-host/specs/windows-host/spec.md)
still require their own actual-worker evidence; no task or acceptance gate is
closed here.

Before implementation, independently review the exact runtime version/schema,
control feasibility and attribution, no-data and backing-store boundaries,
process and ETW ownership, privilege separation, caps including supervisor
failure, and a synthetic parser/lifecycle test plan. If those cannot be met,
leave the experiment incomplete. The same-worker pre-admission handoff remains
a separate unresolved security design, not a prerequisite silently waived by
this observation.
