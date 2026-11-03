# Native Windows host design

## Context

The pinned Bend distribution and current Writ evidence do not provide a native
Windows enforcing host. The portable model is useful here, but runtime execution,
Win32 bindings, and actual worker isolation are separate milestones. See
[host-platform research](../../../docs/HOST-PLATFORMS.md) for primary API sources.

## Goals and boundaries

Build a native Windows target for the Genode-informed portable contract, initially
on an explicitly pinned Windows/x64 profile. Keep every authored authority,
verification, and state-transition rule in Bend. The target may use a validated
generated backend and existing OS/runtime bindings, but it does not introduce a
second policy implementation in another language. WSL tests qualify only their
Linux target. A native ABI bridge and its trust boundary must be reviewed before
any Windows enforcement claim.

## Decisions

### One broker owns authority and publication

Keep authoritative records, protected storage, keys, accounting, and final
destination handles in a broker security context inaccessible to worker tokens.
Authenticate the initiating subject and bind each launch to its operation,
runtime image, configuration, process lifetime, monitor incarnation, and session
generation. A Windows account name, package moniker, SID string, or PID supplied
by a client is an assertion, not trusted launch evidence.

The broker calls the common Bend facade and performs only accepted effects. All
worker result channels terminate in private staging; no worker receives a raw
handle to an external publication target.

### Start workers under an explicit restricted profile

The initial design uses LPAC, a minimal declared capability set, explicit DACLs,
and no network or direct device grant. Verify the actual created process's token,
required LPAC behavior, inherited handle list, and lifecycle controls before
protected input delivery. Prefer job assignment at creation; if setup requires a
suspended process, it must remain suspended until the entire profile is ready.
Every setup failure retires the process without plaintext.

Do not treat low integrity, a restricted token, or Job Object membership as an
equivalent substitute. Ordinary AppContainer and LPAC have different ambient
resource behavior. If a runtime needs an ordinary AppContainer, it requires a
separate named profile and new acceptance tests; failure of LPAC setup cannot
select that profile automatically.

The runtime must work within the selected profile. Do not grant broad filesystem,
registry, COM, network, or GPU access merely to make startup pass. Optional
mitigations, denied native APIs, and OS build requirements belong to the pinned
profile rather than an unsupported claim that every Windows release behaves alike.

### Bind IPC to authentic processes and sessions

A named pipe is an initial transport candidate, not the authority model. Construct
its security descriptor explicitly, restrict clients to the intended local
security contexts, defend the server endpoint against substitution, and bind the
peer context to the monitor's launched-process record. Shared package identity
alone does not distinguish worker invocations.

If the adapter uses named-pipe impersonation for client inspection, check success,
required impersonation level, and thread-token identity. Reject any failure before
performing the operation; do not proceed as the privileged broker. Restore the
broker identity reliably before handling unrelated work. The trusted request
snapshot is bounded and immutable before policy evaluation.

An inherited or duplicated client handle remains a bearer reference to an OS
object. It does not authenticate whichever process now uses it as the original
Writ subject. Initially deny cross-worker transfer and unbrokered descendants.
A future explicit delegation operation must establish the recipient binding,
preserve the exact plan and origin obligations, and only narrow rights or expiry.
A different subject or plan requires new authorization; dropping a source is not
an attenuation of an existing exact-plan grant.

### Treat handles, storage, and descendants as authority

Create a specific inherited-handle allowlist. Do not leak process or token handles,
public consoles, devices, final-destination files, unrelated pipes, or shared
mappings. Protect broker and worker process objects against unauthorized handle
duplication or inspection according to the declared threat model. Numeric handles
are local values; broker mappings also carry process lifetime and generation.

Use Job Objects for memory/work/process limits and lifetime control. Disable
breakaway, restrict child-process creation, and deny indirect process-creation
services that would evade supervision. Worker tokens and object permissions still
supply the access boundary. Keep lifecycle-control handles out of worker reach,
and test both broker termination and process-tree cleanup.

AppContainer storage, registry state, scratch files, crash output, and caches can
carry information between invocations. Give that state an explicit provenance and
lifetime; do not treat private storage as harmless because it is application-local.
The first profile should avoid cross-invocation worker/profile reuse until cleanup
and dependency capture are demonstrated.

### Revoke logically, publish durably

An open `HANDLE` does not override the broker's current registry. Closing one
handle does not invalidate every duplicate, terminate its process, or necessarily
remove mapped views. Revalidate scope and authority at every protected use and
final commit, invalidate old monitor/session generations, and retire revoked
workers while retaining the durable replay/accounting facts.

Once a worker observes plaintext, closing its references cannot make it forget.
Revocation stops new admission and uncommitted publication; complete confinement
continues until worker retirement. Accepted output must be bound to exact sealed
bytes and published with its terms and the committed state under the shared
durable-publication protocol. A filesystem rename, pipe completion, or Job Object
exit is not evidence that the full commit persisted atomically.

### Qualify the native target

Run common Bend vectors and then native negative tests: inherited handles,
duplicate/import attempts, impersonation failure, spoofed endpoints, public
console/clipboard output, named objects, registry/cache leakage, network, COM
helpers, child breakaway, delayed results, restart reuse, and crash recovery.
Qualify only the profile and Windows build tested. A GPU path requires additional
driver, shared-memory, lifetime, and device-execution evidence; it remains disabled
for protected workers until qualified.

## Risks and trade-offs

Windows and its selected drivers remain trusted dependencies. Legacy runtimes may
expect ambient privileges incompatible with the first narrow profile. That is a
porting constraint, not permission to weaken the common information-flow policy.
Host administrators, kernel compromise, and unmeasured hardware timing channels
are outside the initial enforcement claim.

## Migration and rollback

Register the native adapter only after its runtime and isolation gates pass. Keep
model tests and WSL development clearly labeled. On regression, stop new protected
dispatch, retire affected workers, and reconcile accepted durable records without
reusing old generations or sending uncommitted results through an unrestricted
fallback.
