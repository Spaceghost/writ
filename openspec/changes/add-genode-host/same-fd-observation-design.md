# Same-descriptor public boot observation

A synthetic `core` boot link can pass the fixed layout check and then be
replaced before its bytes are read. The existing layout helper closes the
checked leaf descriptor before returning; a later pathname reopen therefore
cannot bind the digest to the checked inode. The implemented synthetic slice is a single-process, no-path-reopen
composition that privately retains the checked `O_PATH` descriptors and gives
those exact objects to the separate held-read probe. It returns only a partial
observation, not a completed inventory or an authorization, policy,
boot-consumption or cleanup claim.

The [layout](../../../contrib/native-hosts/genode/boot-inventory/layout.c)
and [held-read](../../../contrib/native-hosts/genode/boot-inventory/read-held.c)
helpers are composed by the partial observer and checked on owned temporary
trees; the [synthetic evidence](../../../verification/genode-boot-same-fd/README.md)
does not establish behavior on a disposable VM. Their caller,
Linux kernel, process FD table, procfs, mount namespace and OpenSSL EVP
provider/loader remain trusted. A hash is information: the reviewed caller
must confine this public diagnostic to the fixed synthetic/public fixture;
passing an arbitrary protected file descriptor is outside the intended use.
This design does not add a workflow, launch a fixture, or close any
[Genode host task](tasks.md).

## Private handoff and ownership

A future native wrapper would accept only the existing trusted held
root/build/source descriptors, the existing fixed public scenario and numeric
invocation key. The finite map remains exactly the [reviewed 14 names and
limits](disposable-boot-inventory-design.md); no pathname, expected digest,
callback, arbitrary FD array or policy comes from the workload. Index zero is
`config`; the remaining indices follow the fixed 13-entry layout table. The
fixed ordered mapping belongs to the wrapper and is not supplied by callers.

Refactor layout's existing internal checks so that, only after **all** fixed
entries, both scans, ownership/size/mount checks and link/leaf identity
rechecks pass, the code transfers its 14 existing `O_PATH|O_CLOEXEC` leaf FDs
and the captured leaf metadata to private wrapper-owned storage. Retain the
checked boot/bin directories and both held link FDs for each mapped entry in
that same private context, so the post-read revalidation can compare against
those original objects. The invocation/build/source root FDs remain borrowed from the trusted caller, which must keep them valid for the
entire call; the wrapper must never close them. The FD for
each index must be the very object that passed that index's layout check; do
not close it and resolve the path again. This handoff is an internal native
resource-lifetime boundary, not a public API accepting caller-created arrays.
Keep the existing public layout-only entry point and its behavior; the helper
used to transfer the private set must not become a dynamic export. Use a
fixed-size array and initialized `-1` sentinel slots. No FD may be returned to
the caller, sent to a fixture, or inherited across an exec.

Every acquired FD has exactly one owner. On a layout failure, close all owned
FDs, return incomplete and expose no descriptors or results. Once transferred,
the wrapper alone owns the 14 leaf FDs; the layout stage must not close or
reuse them. Close all other temporary descriptors and check those close results
**before** a successful handoff. The wrapper owns and must later close the
retained boot, bin, link and leaf descriptors; borrowed root descriptors are
not closed. Verify each held FD's type,
close-on-exec flag and captured identity/metadata before its read. Feed the
same FD into `writ_boot_read_held` with the 16 KiB cap for `config` and the
256 MiB cap for each other fixed entry. Preserve the 1 GiB aggregate layout
bound and separately sum the actual read lengths with checked arithmetic and
the same cap; use fixed-size output storage, and recheck retained objects against
the captured metadata after all reads. Before exposing results, a private
`revalidate(context)` operation must re-open only the fixed paths under the
borrowed held roots, compare root/boot/bin and link identities and exact link
text with the still-held context, repeat bounded enumeration, compare the
reopened fixed final objects with these same leaf FDs, and refuse any drift or
error. These reopens observe identity and metadata only; file contents are
still read solely through the original held FDs. This is still not a complete
inventory: exact config-reference comparison, external deadline and safe
publication remain unimplemented. The read helper's deliberate procfs
reopen duplicates the held inode; the composition does not resolve a boot,
bin or target pathname to obtain file contents.

If any check or read fails, attempt to close every still-owned descriptor and
return incomplete. A close failure or a descriptor whose ownership can no
longer be established is **cleanup unverified**, not a successful observation;
do not retry a potentially reused FD number. Keep cleanup-uncertain distinct
from an ordinary denial in internal status, with no path, file contents or
untrusted link text in diagnostics. Since the Linux FD table is process-wide,
the trusted single-process caller must not concurrently close, duplicate over,
or otherwise alter these owned FD numbers. Unexpected test-injected FD
replacement must not cause the wrapper to close a demonstrably different
object; report cleanup unverified. Invalidate each owned slot before calling
`close`, and never retry a close whose FD number may have been released and
reused. Same-inode FD reuse cannot be reliably
distinguished solely by `fstat`. A synthetic same-inode replacement actually
returned partial success and closed the replacement FD; this is a recorded
limitation, not a detected failure or general reuse protection. No actual
worker may call this probe until an exclusive trusted FD-table boundary is
established and independently reviewed.

Only after all reads and all owned closes have succeeded may the wrapper copy
the fixed 14 digests and lengths into a trusted caller's fixed-size memory.
Initialize outputs to zero before the attempt and leave them zero on every
failure, including close uncertainty; there is no partial result or FD output.
The only success-like status must be distinctly named
`WRIT_PUBLIC_PARTIAL_OBSERVATION`, not a generic inventory-success status;
ordinary failure and cleanup uncertainty have distinct incomplete statuses.
These in-process synthetic observations are not a file, upload, admission or
release decision. An [exact same-read config comparison](same-fd-exact-config-design.md) is
proposed separately. No exact config-reference comparison, exclusive staging,
published manifest, supervisor, deadline enforcement, process retirement,
workflow integration or real Genode run is included in this slice. In
particular, matching digest output alone does not establish the expected
configuration.

The existing per-read monotonic checks cannot interrupt a blocked syscall.
Before any actual VM integration, a separate reviewed supervisor must hold
the roots before the fixture, avoid leaking them to the workload, and bound
its own owned worker according to the [FD handoff design](disposable-fd-supervisor-design.md).
Timeouts, failures and unverified cleanup remain incomplete. The descriptor
handoff pins inodes, not immutable bytes or proof that the previous process
used them. Post-read revalidation can detect persistent drift but does not
exclude a transient replacement that is restored before observation. Same-UID
adaptive mutation, A→B→A replacement, procfs/mount
replacement by a privileged actor, ambient provider configuration and
uninterruptible I/O remain explicit limits.

## Required synthetic controls

All controls operate on exclusive test-owned temporary trees and test-owned
FDs; none start Genode, QEMU, a host probe or any unrelated process. Test hooks
must be compiled out of production, with production dynamic exports checked.

* `same_fd_positive` covers both fixed scenarios, checks all 14 ordered
  digests and sizes against independently constructed public data, and
  verifies the wrapper closes its FDs and returns no descriptor.
* `path_changed_after_read` renames a test-owned mapped leaf after all 14
  reads and before post-read revalidation, keeping its original inode linked
  under a test-owned new name, and installs a different leaf at the old path.
  A test-only phase marker must confirm the reads completed first; the fixed-
  path revalidation must reject the replacement and leave all output zero.
* `swapped_private_slots` swaps two distinct retained FD slots while leaving
  their fixed expected metadata in place; the check must fail with all output
  slots zero. This exercises accidental corruption, not an unforgeable
  authorization boundary.
* `closed_or_replaced_private_fd` closes one test-owned FD or reuses its number
  for a different test-owned object before reading. Refuse and report cleanup
  uncertainty where ownership is no longer established, without closing an
  unrelated test sentinel. Confirm any failure leaves no partial result.
* `layout_failure`, `read_failure`, `close_failure` and `late_metadata_drift`
  inject failures at every acquisition, hash and close stage, require all-zero outputs and verify
  owned-descriptor handling. A simulated close failure is not proof that a
  real kernel close failure or uninterruptible I/O was recovered.
* `postread_link_drift` replaces a checked link with a new symlink containing
  identical text after all reads and before revalidation. A test-only phase
  marker must confirm the reads completed first; the held-link identity check
  must reject it and leave all output zero.
* `no_path_reopen` uses a deterministic test hook after the handoff to remove
  a mapped name and verifies that no later content read follows its new path;
  `fixed_order_and_caps` checks all 14 indices and both read limits. Test
  output contains only fixed names/statuses and known public hashes, never
  arbitrary path or file bytes.

Normal and undefined-behavior-sanitized native test runs, source inventory,
strict OpenSpec and the repository's required Bend tests/proof must be
reported with exact inputs. A successful synthetic suite remains model/tooling
evidence only; it neither qualifies a Genode host nor implements an accepted
protected-data path.
