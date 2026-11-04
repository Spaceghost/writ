# WritFS namespace

## Purpose

Expose authorized files, deferred views, and proc-like Writ job state through a
per-session namespace while preserving exact plans, current authority, protected
metadata, and the existing durable publication boundary.

## ADDED Requirements

### Requirement: WF-001 Native sessions establish authority

WritFS SHALL derive the effective subject and resource bindings from trusted host session state and route protected decisions through the Bend monitor; client-supplied identity, registry, ledger, or plugin verdicts SHALL NOT establish authority.

#### Scenario: An authenticated session opens its entry

- **GIVEN** the host binds a live session to reader R and the monitor registers its approved entry
- **WHEN** R opens that entry under current valid authority
- **THEN** the monitor resolves the entry for R through the shared decision path.

#### Scenario: A client plugin substitutes a subject

- **GIVEN** the host binds the session to R
- **WHEN** a plugin claims subject S and supplies an allowing registry
- **THEN** neither value grants S's authority or bypasses the monitor.

### Requirement: WF-002 Mounted names preserve scope

A namespace SHALL expose only entries authorized for its session, preserve each entry's exact plan and allowed rights, and keep bearer tokens out of paths, listings, and diagnostics. Names SHALL NOT confer ambient filesystem or sibling-entry authority.

#### Scenario: A session lists approved aliases

- **GIVEN** the session may discover report A but not report B
- **WHEN** it lists its data directory
- **THEN** only the authorized alias for A is returned without a bearer token.

#### Scenario: A path attempts to leave its grant

- **GIVEN** an entry authorizes destination X only
- **WHEN** a caller uses traversal or a guessed sibling path to reach Y
- **THEN** the namespace grants no access to Y.

### Requirement: WF-003 Paths retain immutable identity

An operational reference SHALL bind the approved object version, plan, host incarnation, and resource generation independently of path resolution. Rebinding or reconfiguration SHALL NOT substitute another resource under an existing approval.

#### Scenario: An alias still resolves to the approved version

- **GIVEN** an entry is bound to report A version 7 and the binding is current
- **WHEN** its admitted operation reads through that entry
- **THEN** the supplied source is exactly A version 7.

#### Scenario: Reconfiguration replaces a path target

- **GIVEN** an approved reference names A version 7
- **WHEN** its native path is reopened against A version 8 or an object in a new host incarnation
- **THEN** the replacement cannot be used under the earlier reference.

### Requirement: WF-004 Introspection is a protected output

Listings, metadata, status, receipts, errors, and events SHALL be filtered by their own current disclosure scopes, including any permitted counts or timing. WritFS SHALL NOT export unrelated jobs, raw worker memory, bearer tokens, or unapproved intermediate results.

#### Scenario: A caller inspects its approved job status

- **GIVEN** R may observe job J's coarse state but not its source names
- **WHEN** R reads J's status
- **THEN** the response contains the permitted state without the source names.

#### Scenario: A failed lookup would reveal another job

- **GIVEN** R has no discovery grant for job K or its existence
- **WHEN** R guesses K's name and requests its receipt
- **THEN** the response does not reveal K's existence, receipt, or intermediate output.

### Requirement: WF-005 Reads retain paired admission

Every protected content or metadata read SHALL identify its authorized delivery sink and pass complete current source-read and destination-write admission, including required origin terms. A mount, read right, or successful native open SHALL NOT replace those checks.

#### Scenario: An admitted report read reaches its sink

- **GIVEN** current paired grants authorize report A version 7 to confined sink D
- **WHEN** the bound reader requests that content with all origin terms satisfied
- **THEN** delivery may proceed only to D under the admitted scope.

#### Scenario: A read lacks destination authority

- **GIVEN** a mounted entry has a read right but no current grant for the requested delivery sink
- **WHEN** its content is requested
- **THEN** no protected bytes are delivered.

### Requirement: WF-006 Controls are bounded explicit requests

Control operations SHALL use complete, bounded, versioned canonical requests with operation-specific grants. Partial writes, unknown verbs, close, or flush SHALL NOT submit an incomplete action or confer cancellation, revocation, or deletion authority.

#### Scenario: A complete authorized control is submitted

- **GIVEN** R has a live grant to cancel its job J
- **WHEN** a complete supported cancel request names exactly J
- **THEN** the request enters the cancellation decision path under R's grant.

#### Scenario: A truncated request is closed

- **GIVEN** only part of a retirement control frame has been written
- **WHEN** the caller closes or flushes the channel
- **THEN** no retirement request or other protected effect is created.

### Requirement: WF-007 Control retries preserve one operation

A new control mutation SHALL check the current revision and bind a request identity to its complete canonical scope. An identical retry SHALL refer to the existing operation; changed reuse SHALL be rejected. Denial SHALL preserve authoritative operation and budget state.

#### Scenario: An accepted submit is retried

- **GIVEN** request Q created job J and its submit acknowledgement was lost
- **WHEN** the same session retries Q with identical contents and may observe its status
- **THEN** it receives J's existing status without a second job or charge.

#### Scenario: A request identity is reused with new contents

- **GIVEN** Q already binds a summary for destination D
- **WHEN** Q is submitted with destination E
- **THEN** the mutation is rejected without changing J or its budget state.

### Requirement: WF-008 Materialization is explicit

The initial WritFS profile SHALL launch or charge for a view only through an explicitly accepted materialization request. Discovery, stat, open, previews, status, and result reads SHALL NOT implicitly execute it; an unmaterialized result read SHALL report pending without exposing intermediates.

#### Scenario: A reader explicitly materializes a view

- **GIVEN** view V has a pinned plan and current execution and budget authority
- **WHEN** its authorized materialization request is accepted
- **THEN** the job may run within that plan and budget.

#### Scenario: An indexer scans an unmaterialized view

- **GIVEN** V has no materialized result or accepted execution request
- **WHEN** an indexer lists, stats, opens, or reads its result entry
- **THEN** no job or charge is created and no intermediate bytes are returned.

### Requirement: WF-009 File writes use durable publication

Data writes SHALL remain private staging until the exact immutable artifact, destination, inherited policy, and current authority pass durable publication. Native write, rename, close, or synchronization success SHALL NOT independently make staged output visible to its recipient.

#### Scenario: A staged result is durably approved

- **GIVEN** artifact A is sealed for the admitted invocation and all current commit checks pass
- **WHEN** its exact publication intent is durably committed
- **THEN** the scoped result may become visible with its required policy.

#### Scenario: A caller renames unapproved staging data

- **GIVEN** a worker has written private staging object S but no publication authorization exists
- **WHEN** it attempts to rename or synchronize S into a recipient-visible path
- **THEN** those operations cannot expose S as committed output.

### Requirement: WF-010 Continued delivery uses live authority

New reads and uses through retained descriptors, cached views, receipts, or events SHALL revalidate current scope, expiry, epoch, and resource generation. Recovery SHALL follow only its exact already-durable publication intent; an old handle cannot relabel a new read as recovery. Revocation stops newly unauthorized use without recalling earlier copies.

#### Scenario: A cached result remains authorized

- **GIVEN** result A is immutable and its reader's exact grants remain current
- **WHEN** the reader requests cached bytes under the same scope
- **THEN** those bytes may be delivered after live authorization succeeds.

#### Scenario: A subscription outlives its grant

- **GIVEN** a subscription was opened before its disclosure grant was revoked
- **WHEN** another protected event becomes available after revocation
- **THEN** that event is not delivered through the old subscription.

### Requirement: WF-011 Inspection records are coherent and bounded

Status reads SHALL return bounded coherent snapshots; event streams SHALL number events after recipient visibility filtering and report authorized overflow or gaps explicitly. Neither interface SHALL reveal suppressed events through numbering, combine incompatible revisions, broaden access on exhaustion, or claim an incomplete stream is complete.

#### Scenario: A job changes while status is read

- **GIVEN** J advances from revision 4 to revision 5 during a multi-part status read
- **WHEN** the admitted snapshot is returned
- **THEN** it describes one declared revision rather than mixing fields from both.

#### Scenario: A watcher misses buffered events

- **GIVEN** a watcher last observed sequence 8 and its bounded buffer loses sequence 9
- **WHEN** delivery resumes with later events
- **THEN** the authorized stream reports the gap instead of presenting an uninterrupted history.

#### Scenario: A hidden event occurs between visible events

- **GIVEN** a recipient may observe events A and C but not event B or its existence
- **WHEN** the stream delivers A and C
- **THEN** its numbering and markers do not reveal B through an unapproved gap or count.

### Requirement: WF-012 Aliases and copies retain policy

Aliases, copies, caches, and materialized views SHALL preserve the required origin records and effective release restrictions of their source artifacts. Changing a name or supported file operation SHALL NOT create fresh provenance, widen destination authority, or remove an origin obligation.

#### Scenario: A permitted copy retains its origins

- **GIVEN** artifact A carries origins O1 and O2 and an admitted copy targets D
- **WHEN** its copy is published through WritFS
- **THEN** the new entry retains both required origin records and effective restrictions.

#### Scenario: An alias is used to claim fresh data

- **GIVEN** an existing artifact includes an origin's export restriction
- **WHEN** a caller gives it a new path and submits it as an unrestricted source
- **THEN** the altered source description is rejected.

### Requirement: WF-013 Native profiles preserve the same boundary

A protected WritFS profile SHALL require qualified host confinement and use the shared authority path for every supported file operation. It SHALL deny unsupported mappings, handle transfers, links, accelerated copies, or other access routes rather than bypassing scope checks.

#### Scenario: A qualified native adapter delivers a result

- **GIVEN** the adapter's native profile confines the reader and supports scoped reads
- **WHEN** the shared Bend path admits an exact result read
- **THEN** the adapter delivers only that result through the confined sink.

#### Scenario: A client requests an unqualified mapping route

- **GIVEN** ordinary reads are supported but memory-mapping revocation has not been qualified
- **WHEN** a caller requests a mapping of protected content
- **THEN** the mapping is denied without falling back to an unchecked native file.
