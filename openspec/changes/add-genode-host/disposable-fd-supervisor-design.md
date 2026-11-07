# Proposed FD handoff for a disposable public Genode fixture

A public nested-Genode fixture may build a `core` symlink under an invocation's
fresh build directory. A later bounded inventory needs to identify the original
build and source directories without opening similarly named replacements after
the fixture. The current e233 driver creates and uses those paths in one script
and does not retain directory descriptors across the run. A proposed narrow
supervisor would split preparation, fixture execution and inventory, retaining
its own handles between phases. No such supervisor or handoff is implemented.

This is a design for a **fresh disposable Linux-hosted VM and public fixtures**,
not a shared-host process containment solution. The [boot-inventory design](disposable-boot-inventory-design.md)
requires fixed mappings, no-follow/mount rules, bounded reads and incomplete on
uncertainty. The [PID-namespace research](../../../contrib/native-hosts/genode/nested-channel/PID-NAMESPACE-DESIGN.md)
separately records unresolved local lifecycle and injection issues. Nothing in
this note clears a Genode/QEMU run, a shared-host identity probe, host
qualification, or a workflow dispatch. VM disposal is fallback containment,
not proof of in-guest process cleanup.

## Fixed responsibilities and held roots

The proposed supervisor is contribution-owned Linux C/C++ OS/packaging code,
not a Writ policy or authorization engine. The existing Bend code remains
responsible for Writ decisions. The supervisor has only two fixed reviewed
public fixture scenarios, fixed preparation/collector/inventory executables and
bounded arguments derived from its trusted workflow. It accepts no arbitrary
command, code, path, process identifier, actor or policy selector. Its exact
source, dependencies, scenario/target mapping and invocation arguments require
independent review and inventory. If an operating-system primitive is missing,
identity is ambiguous, or a fixed child/FD cannot be bound, the result is
incomplete; there is no unrestricted fallback.

1. In the dedicated VM, the supervisor opens a trusted `/tmp` directory and
   creates one fresh private invocation directory as an exclusive child. It
   opens and retains no-follow directory FDs for that root and the separately
   created owned evidence directory, along with their identities. The fixed
   numeric run key names the invocation only; it is not an authority fact.
   Reuse, ambiguous ancestry, wrong owner/mode or unsupported mount checks
   refuses the attempt.
2. Before starting any writable child, the parent loads the scenario's fixed,
   independently reviewed expected argument/config bytes from the pinned
   trusted source into a bounded private memory snapshot. It verifies the
   expected fixed length and SHA-256, records source identity and observations,
   and does not derive expected bytes from a generated fixture output. A held
   FD alone would not freeze a writable reference. The private snapshot must
   not be a writable shared mapping; trusted-kernel and no-parent-memory-
   injection assumptions remain explicit. If stable source identity or the
   expected bytes cannot be established, stop incomplete. The pinned guard
   vector is the Tcl argument; the historical installed-byte expectation adds
   the one `puts` LF documented by the inventory design, without trimming or
   regenerating either expectation from the run.
3. A fixed preparation child downloads and verifies the pinned public inputs,
   extracts the pinned Genode source directory **G**, and invokes the existing
   tool to create fresh build directory **B**. This phase may create files and
   compile prerequisites; it is not a protected workload. The parent retains
   its own root/evidence handles and waits for the exact child result. A failure,
   timeout or missing verification is incomplete, not permission to start the
   fixture. Preparatory child exit does not prove its descendants are gone.
4. Before launching the fixture, the parent opens G and B by their fixed names
   relative to the still-held invocation root. It retains both FDs, verifies
   directory type, owner/mode, identity and ancestry, and uses the reviewed
   `openat2` no-symlink/no-cross-mount rules from the inventory design. It checks
   that the reviewed pinned source, fixture, guard, references and output
   mapping are present; record source/tooling identities and both observations.
   Merely recording device/inode and reopening the names after the fixture does
   **not** satisfy this held-descriptor requirement.
5. Only after those checks does the parent start the fixed scenario's bounded
   capture writer and guarded fixture as **separate, individually bound child
   processes**. A dedicated pipe carries the fixture's stdout/stderr to the
   capture writer. The writer gets only that read end and the minimum fixed
   capture-output handles; the fixture gets only the intended standard streams
   and its pipe write end. The fixture gets no capture-output, root, B, G,
   reference or evidence-directory handles. The legacy e233 collector spawns
   `make` itself and must be independently refactored or shown to preserve this
   separation; the old combined behavior does not establish it. A second
   accidental `make`, different target or runtime overwrite of fixed fixture
   sources must refuse. Keep complete raw gzip capture, integrity checks, caps,
   error records and public credential assumptions.
6. Once the bounded fixture/capture phase has returned, a distinct fixed
   inventory worker receives only the held root, B, G and output FDs it
   actually needs and the parent's already-pinned private expected bytes.
   A forked worker may inherit that private memory through copy-on-write; an
   exec-based worker instead needs a separately reviewed immutable handoff,
   such as a verified sealed object. Reopening the original writable reference
   pathname or assuming an FD freezes its bytes is not sufficient. It opens the
   fixed post-run boot path relative to B
   and applies the 14-name inventory design. The boot directory itself is
   created during the fixture; its post-run handle is an observation, not a
   pre-held claim. The worker's output cannot make the fixture authoritative
   or prove which configuration/binaries the earlier process consumed.

All path identities are observations within the trusted VM and mount namespace.
Even if the supervisor holds B/G and checks their names before and after the
fixture, the fixture itself can access same-UID paths and is not forced to use
those FDs. A same-UID writer can replace a path between observations or modify
a held file in place. No absence of FD leakage, digest or pre/post identity
check establishes confinement, eliminates A→B→A races, proves process identity,
or proves boot consumption. The runner, kernel, reviewed tooling and public
inputs remain trusted.

## Fork, exec and handle delivery

Create held directory/reference FDs close-on-exec and retain them in the parent.
`FD_CLOEXEC` closes an FD at a successful `exec`; it does **not** close it in a
forked child before `exec`. The preparation and fixture child paths must do only
a small reviewed setup sequence after fork, close every non-allowlisted FD
before running child-controlled code, and then execute the fixed command. A
bounded exec-status channel may be kept solely until exec and must itself close
on exec. Handle-number collisions, close/dup/exec errors and unexpected
inheritance are incomplete. Linux [`close_range`](https://man7.org/linux/man-pages/man2/close_range.2.html)
can help close an explicit range, but a correct implementation must preserve
only the intended standard streams and status channel, not assume descriptor
numbers are free. Missing or blocked primitives do not authorize a weaker path.

One narrow inventory handoff is a separately forked worker: duplicate exactly
the retained directory/output FDs into a collision-safe fixed table, close
all other nonstandard FDs in that child, and invoke the fixed worker library or
exec the fixed reviewed worker with deliberate inheritance. If exec is used,
only those intended duplicates may have close-on-exec cleared. The parent keeps
its originals until the worker completes or is classified incomplete. An
alternative private socketpair with `SCM_RIGHTS` would require its own exact
message/FD-count and peer-binding review; it is not assumed by this proposal.
The [`recvmsg`](https://man7.org/linux/man-pages/man2/recvmsg.2.html) contract
supports close-on-exec on received FDs but does not by itself authenticate the
sender, establish the fixed mapping, or close unrelated inherited FDs.

The intended FD/process table is fixed before any child starts:

| Process | Held or received resources | Explicitly excluded |
| --- | --- | --- |
| Supervisor parent | Invocation/root, B/G and evidence FDs; private expected-byte snapshot; exact child pidfds and bounded status/control channels | No Writ authority or generic command endpoint |
| Preparation child | Fixed standard streams and any narrowly reviewed pre-exec status channel | No parent root, B/G, expected-reference or evidence FDs after exec |
| Capture writer | Fixture pipe read end, fixed capture-output handles and a bounded supervisor status channel | No B/G, expected-reference or inventory-output handles |
| Fixture exec | Fixed standard input and fixture pipe write end for stdout/stderr | No pipe read end, capture-output, root, B/G, reference or evidence FDs after exec |
| Inventory worker | Exact root/B/G and inventory-output FDs; the pre-pinned private expected bytes | No fixture pipe endpoints, capture-output handles, arbitrary path or selector |

The actual control and exec-status descriptors must be enumerated separately
and checked against this table before exec; this table is not an assertion that
standard streams or same-UID paths are a sandbox. Each capture writer and
fixture process is a separately identified direct child. Capture timeout,
signal and wait status must be bound to the exact collector being timed, while
fixture exit status is recorded separately. No child PID or pipe EOF is a
substitute for the other's status. If the fixture exits but a descendant keeps
the pipe open, the capture deadline still applies and the result is incomplete;
do not wait indefinitely or infer descendant retirement.
The supervisor must obtain the exact fixture child's actual wait status and
deliver it to the capture writer over the bounded private status channel, or
combine the two statuses itself after capture. The fixture cannot report its
own authoritative exit status. The existing collector's child-status promise
cannot be retained unchanged after making the processes siblings; missing,
duplicate, late or inconsistent status must remain incomplete.
The parent alone retains the capture output directory handle and controls
publication; the writer's fixed preopened temporary output handle does not
authorize arbitrary output paths. Only after a complete bounded capture, close
and integrity audit may the parent publish a result. If the implementation
instead gives a writer a directory handle, that wider authority needs separate
review and must never reach the fixture exec.

A fixture child can still reopen public paths using its own same-UID access;
withholding these FDs is descriptor hygiene, not filesystem confinement. The
inventory worker must check the received FDs' expected type, owner, mount and
identity, retain the held inode while reopening the permitted procfs FD, and
reject missing, extra, swapped or substituted handles. A fixed helper executable,
reference and target must be recorded along with the two distinct fixture and
workflow/tooling source identities. Record observations rather than calling
these checks process attestation.

## Deadlines, output and process lifetime

Keep the existing bounded fixture collector and its complete raw-byte audit.
The inventory worker has a separate monotonic 30-second work deadline and a
bounded status/snapshot window as specified in the inventory design. An
independent parent records a bounded incomplete status when it can, even if the
worker hangs; no incomplete or missing status can promote partial bytes as a
complete inventory. Use exclusive non-uploaded temporary files, verified close,
no-overwrite promotion, an explicit upload allowlist and a completion status
bound to final hashes. A hard job cancellation, blocked filesystem operation or
failed status/upload can prevent even that record; absence is incomplete, not a
success. Preserve the existing job-level nonzero/incomplete conclusion while
cleanup remains unverified.

If the supervisor needs to signal an owned child, it must first hold a
race-resistant handle bound to that exact child. One candidate is atomically
creating the direct child with `clone3(CLONE_PIDFD)` and retaining the resulting
pidfd, using a normal `SIGCHLD` exit signal and no thread, parent-sharing or
namespace-creation flags; kernel or runner refusal means incomplete. [`clone3`](https://man7.org/linux/man-pages/man2/clone3.2.html)
documents the child-bound pidfd, and [`pidfd_send_signal`](https://man7.org/linux/man-pages/man2/pidfd_send_signal.2.html)
addresses the referenced process rather than a recycled numeric PID. The
implementation must verify the exact ownership and wait/reap semantics, avoid
automatic or shared/asynchronous reaping, and signal only its own bound child if
needed. A readable pidfd and successful signal are not themselves a captured
wait/reap status. No
numeric PID fallback, process-group kill, global scan or name-based signal is
permitted. A signal result, direct child exit or reaping does not prove all
fixture descendants retired; a task stuck in uninterruptible I/O may outlive
the deadline. Keep cleanup unverified and rely only on disposable VM disposal
as fallback containment.

The total job budget must leave a conditional upload window after preparation,
fixture capture and inventory; this is a bounded attempt, not a delivery
guarantee. Retain the provider's minimum read token and platform/action
credentials as explicit residual assumptions. Do not deliberately pass
credentials to the fixture or present unfiltered subprocess output as a
credential filter. No change to protected host routes or master CI gates is
proposed.

## Synthetic-only controls before any experiment

Use only owned temporary directories and children, with no Genode, QEMU, shared
VM, process enumeration, network, namespace setup or Linux identity probe.
Record exact commands, tool identities and outcomes; a setup refusal is not a
pass. Independently review source and tests before any future disposable-VM run.

- Run fixed mock preparation, fixture and inventory children, covering normal
  exit, early failure, failed source/target checks and no fixture start after
  failed preparation. Verify the inventory actually receives the originally
  held B/G objects, not a later pathname replacement. Mutate or replace the
  original reference file after pre-pinning: the inventory must use the
  parent's original private byte snapshot, or report incomplete; it must not
  accept a new value merely because a held reference FD still exists.
- Have a test-owned fixture child report its **own** open descriptors and
  object identities; verify it lacks parent root/B/G/reference/evidence
  handles and the writer's capture-output handles after exec. Verify the
  capture writer, fixture and inventory worker have only their own table rows,
  and bind their separate exit/timeout statuses. The worker must receive the
  exact expected handles and no extra ones. Include CLOEXEC failure, descriptor-number collisions,
  remapping errors, missing/swapped/duplicate/extra FD, early parent/child exit
  and cleanup of partial handoffs. Enumeration's own test FD is not a leak.
- Exercise replaced/symlinked root names, G/B renamed after open, parent/child
  ancestry mismatch, unexpected mount and openat2 unavailability. Record the
  same-filesystem bind-mount control as untested in this no-namespace plan; it
  would require a separately reviewed isolated environment. Do not inspect or
  change system mounts.
- Use synthetic regular files and test-owned FIFO/socket objects for delayed or
  blocked I/O; test total/per-file caps, missing status and timeout. Test a
  held stdout pipe, early collector exit, status write/close error, and
  interruption before/after write, promotion and completion binding. Complete
  hashes must never be credited from missing or partial status.
- If pidfd signaling is implemented, test a test-owned worker that exits
  immediately, ignores TERM, is signaled through its retained handle, or cannot
  be signaled/reaped. A separate test-owned sentinel must survive. Verify no
  signal goes to an unbound worker or a process group and never claim that
  a signaled direct child proves descendant retirement.

A future implementation must supply its own reviewed source, explicit trust and
FD inventory, portable/synthetic evidence, OpenSpec validation and separate
exact-source review. A later public-only VM attempt would need separately
reviewed workflow/ref identity and must preserve all failures and cleanup gaps.
