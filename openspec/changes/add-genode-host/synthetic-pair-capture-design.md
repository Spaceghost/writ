# Fixed-name synthetic pair byte capture

A synthetic output directory can contain `public-manifest.txt` and
`public-status.txt` whose bytes a future caller wishes to examine. The existing
[held-file reader](../../../contrib/native-hosts/genode/boot-inventory/read-held.c)
returns a digest, not a byte snapshot, and the separate
[Bend checker](synthetic-pair-checker-design.md) performs no filesystem I/O.
A fixed-name, bounded snapshot primitive is a useful independent native I/O
slice; neither file nor a successful capture establishes a worker result,
authenticity, completeness, host qualification, or Writ authority. The [standalone synthetic capture](../../../contrib/native-hosts/genode/boot-inventory/capture.h) now implements this bounded I/O slice; its [owned-temp evidence](../../../verification/genode-pair-capture/README.md) does not implement a production FFI, worker, launcher or workflow.

The native exception permits Linux OS ABI and descriptor lifetime operations,
not a second protocol or policy engine. The only native outcome is a partial
I/O observation; format, SHA-256, scenario, worker and release decisions are
outside it. This design follows [AB-001, AB-004 and AB-007](../../specs/authority-boundary/spec.md)
and [VE-007/008](../../specs/verification-evidence/spec.md). The existing
[synthetic publisher's format and limitations](public-synthetic-manifest-design.md)
and [same-FD FD-table limitation](same-fd-observation-design.md) remain in
force; host tasks stay open.

## Boundary and fixed result

A future Linux-only entry takes a **borrowed**, already-held output-directory FD
and one caller-owned fixed result object. It takes no pathname, filename,
callback, scenario, digest, worker identity, status claim or policy input.
The result contains two unsigned byte arrays of 4,096 and 512 bytes and their
bounded lengths. No NUL terminator is implied or required. At entry initialize
the *entire* valid result object, including both arrays and lengths, to zero.
Zero-initialize private snapshots and copy both into the result only after all checks
and owned-descriptor closes succeed. Zero unused array tails. A null result is
an invalid call; a caller must provide a valid writable object for the whole
call and not concurrently access it. Output must not alias implementation
storage. Both files may be empty: arbitrary binary bytes, including NUL and
non-ASCII, are preserved unchanged and are not parsed. Bytes are synthetic
public data; no raw file bytes are written to diagnostics.

Return a distinct `CAPTURED_PARTIAL` only for an all-or-nothing byte observation;
return `INCOMPLETE` for refusals/errors and `CLEANUP_UNVERIFIED` for any
uncertain owned-FD close (even after an otherwise successful read). Both
failure results leave the whole result zero. No file descriptors, partial
lengths, hashes or file contents accompany failure. This result cannot be
confused with a syntactic match, complete inventory or a successfully exited
worker. A trusted caller owns the returned memory; no API supplies an
implicit parser or invokes Bend. Production transport or FFI requires a separate byte-preservation, lifetime,
bounds and failure review before passing captured bytes to the Bend checker.

## Trusted inputs and observation sequence

The caller supplies an exclusive, stable FD table throughout the call, and a
trusted, exclusively held output directory whose entries and backing files
are not concurrently modified by another thread or same-UID process. The
caller keeps the borrowed directory open and unchanged; this routine neither
closes it nor transfers it to a workload. Its trust and lifetime are not
established by `fstat`, file permissions or this API. In particular, as the
existing [same-inode reuse control](../../../verification/genode-boot-same-fd/README.md)
shows, metadata identity cannot prove ownership after hostile FD-table reuse.
Do not attach this routine to a real worker unless a separately reviewed
supervisor establishes the boundary.

1. Check the borrowed FD is a directory with `FD_CLOEXEC`, effective
   owner and mode `0700`, as required by the existing publisher, and save
   its device/inode/type/owner/mode and relevant metadata. Refuse bad, missing
   or unsupported inputs. Use only literal fixed names, never caller-derived
   path components. Use `openat2` relative to that held FD with
   `RESOLVE_BENEATH | RESOLVE_NO_XDEV | RESOLVE_NO_SYMLINKS |
   RESOLVE_NO_MAGICLINKS` and `O_PATH | O_NOFOLLOW | O_CLOEXEC` to pin each
   final name. Linux may return an `O_PATH` FD for the final symlink itself;
   the following type check rejects it, and it is never followed. Refuse unsupported syscall or flags without fallback. The held
   trusted directory is the root: no ancestor pathname traversal is needed.
2. Before any data open, `fstat` both held objects and require regular file,
   effective owner, one link, mode `0600` and nonnegative size
   at most 4,096 and 512 respectively. Save device, inode, type, mode, owner,
   link count, size and nanosecond mtime/ctime. Reject missing, symlink, FIFO,
   socket, device, directory, cross-mount, oversized or ambiguous entries; do
   not open any special object for data. Retain both original `O_PATH` FDs
   through all reads and revalidation; no pathname reopen supplies the bytes.
3. Reopen each held inode for reading via the existing reader's independently
   verified Linux procfs/current-process FD-view pattern: validate held procfs
   and current PID view, use no-follow/no-cross-mount checks on ordinary
   components, and allow only the internally constructed held-FD magic-link
   reopen. Check reopened regular object and saved metadata equal the still
   held inode before use and recheck procfs/view afterward. No arbitrary
   procfs path, descriptor number or fallback is caller-selected. Do not call
   `writ_boot_read_held` and pretend its digest is a snapshot: that API does not
   return the bytes. An implementation may factor or independently reproduce
   reviewed syscall plumbing, but must preserve standalone reader behavior.
4. Read each exact original size into a private fixed buffer using checked
   offset/remaining arithmetic and bounded requests; handle short reads and
   EINTR with at most 32 retries per file across data and EOF reads; persistent
   interruption refuses. This retry bound is not an external deadline. Require an additional one-byte
   EOF probe and reject early EOF, growth, oversize, read failure or arithmetic
   failure. Recheck the original and data FD's full saved metadata. There is
   no string conversion, normalization, SHA, expected-byte comparison or schema
   validation in this operation. The bytes returned must be exactly the read
   bytes, including embedded zeroes.
5. After *both* reads, revalidate the held directory, both retained inode
   metadata, procfs view and the two fixed directory entries. Reopen each
   name only as a no-follow `O_PATH` check and require it denotes the same
   saved held object with matching full metadata; never read through this
   recheck. Refuse persistent same-text symlink or same-name inode replacement,
   missing entries and observed directory/metadata drift. Do not assume an
   inode/device comparison excludes mount changes: `NO_XDEV` is required.
   For each internally owned descriptor, check saved device/inode/type before
   close and refuse a demonstrably different object; this cannot establish
   ownership of a same-inode replacement. Invalidate its slot before the
   single close attempt and never retry an uncertain close. If its initial
   acquisition `fstat` fails, the trusted stable-table precondition identifies
   the just-opened descriptor for one close attempt; still report cleanup
   unverified because its identity could not be recorded. Only after all closes succeed may
   private byte arrays and lengths be copied to the caller. On any failure,
   close all acquired owned descriptors, report close uncertainty separately,
   leave outputs zero and do not unlink or modify either file.

The output directory and FD-table exclusivity assumptions are essential:
`O_PATH`, pre/post metadata and path checks do not rule out adaptive same-UID
in-place edits, A→B→A replacements, or same-inode FD-table reuse. Nor do they
bind the snapshot to a prior writer, worker exit, earlier boot consumption,
subsequent path contents or durable storage. The two reads are sequential,
not an atomic filesystem transaction. A malicious or defective filesystem can
stall an open, `fstat`, read or close; nonblocking flags and byte caps do not
bound syscall wall time. A separately reviewed owned-worker supervisor and
external deadline are still absent; timeout cannot guarantee termination of an
uninterruptible I/O task. No raw contents or retained snapshots are to be
published by this slice.

## Owned-temporary controls

The recorded controls cover the ABI and failure cases below. Tests operate only on test-owned temporary
files and processes, with no host fixture or protected input. Exercise the
actual native entry, not a substitute parser:

* `capture_exact_bytes`: empty files, mixed binary including NUL/255, both
  exact caps and distinct patterns; lengths and every byte independently
  compared, zero tails and borrowed directory FD still usable. Capture two
  intentionally malformed, replayed or fabricated pairs as bytes without
  asserting any format or completion result.
* `caps_and_progress`: cap+1 on either file, late growth/early EOF, short reads,
  EINTR, read/stat failure and unsupported `openat2`/flags; all failures zero
  both arrays and lengths. Check exact-cap EOF without a terminator overwrite.
* `special_and_scope`: missing/wrong borrowed FD, missing entries, symlinks,
  FIFO and test-owned socket, directories, wrong mode/owner/link count,
  cross-mount simulation, and wrong procfs/PID view or reopen identity. A
  test-only classification hook can model a device without opening one.
  Verify no special object is opened as data and no unsupported fallback.
* `persistent_replacement_after_read`: after both byte reads and before the
  final recheck, rename a still-linked held leaf and install another at its
  old name, replace with a symlink, and replace either fixed entry; also swap either name after the first read and
  before the second. Assert the
  hook reached that precise phase, refusal, zero output and no leaked owned FDs.
  Also mutate either file in place during and after its read; observed metadata
  drift must refuse. Describe adaptive same-size/A→B→A limits rather than
  claiming these tests exclude them.
* `resource_failure`: inject failures at each acquisition, read, procfs/path
  recheck and close for both inputs, including a late failure after the first
  private buffer is populated and after the second read. Check zero outputs,
  close uncertainty distinct from ordinary incomplete, borrowed FD untouched,
  and no owned FD leak when close succeeds. Cover FD reuse only within the
  exclusive-table assumption; retain the known same-inode limitation rather
  than claiming generic FD ownership detection.
* `interruption_and_boundary`: a deterministic test-only hook calls `_exit`
  in the exact owned capture child at each named phase; its parent waits on
  its own child and uses no signal. The child snapshot memory is private;
  no output channel or consumer is implemented, so this checks exit reporting
  only and does not exercise a completion-credit decision. Any separate signaling test must use an
  independently established race-resistant handle for the exact owned child,
  such as a verified pidfd with no concurrent reaping; refuse if unavailable,
  with no numeric-PID or process-group fallback. A test-owned unrelated
  sentinel must remain untouched. These are test-harness facts, not an
  implemented supervisor, deadline, process-authentication mechanism or
  guarantee of filesystem cleanup.

Native synthetic checks, sanitizers/analyzer, applicable root Bend/proof,
OpenSpec and manifest evidence must identify the exact source. The pure Bend
checker remains separate. A [test-only synthetic handoff](../../../verification/genode-pair-handoff/README.md)
exercises `CAPTURED_PARTIAL` bytes through a fixed Bend decoder and checker;
production FFI, worker identity and supervised transport remain unimplemented.
No Genode/QEMU, identity probe, workflow, GPU or protected-host execution is
implied.
