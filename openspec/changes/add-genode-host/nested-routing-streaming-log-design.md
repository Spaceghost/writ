# Bounded complete logging for the public nested Genode fixture: proposal

Both jobs in the [reviewed retry](../../../verification/genode-nested-ci-9e888b7/README.md)
filled their 32 MiB `run.log` prefix during generated-C compilation. Each
prefix contains 9,256 `-Wuninitialized` warnings, 1,227 `-Wunused-variable`
warnings and one other warning; associated macro notes account for much of the
output. The missing remainder cannot establish whether later errors occurred.
Neither fixture nor negative control was observed. The existing `ulimit -f`
also applies to **every file written by the build and descendants**, not just
the log; evidence does not establish whether another file hit the bound.

This is a design only: no logging implementation, build, CI dispatch or
additional run is authorized by this document. Do not suppress warning classes,
change compiler flags or interpret a missing diagnostic as proof of correctness.
Every existing no-qualification, same-UID artifact/credential and cleanup
limitation remains in force.

## Proposed bounded capture

In each disposable public-VM job, replace the build subprocess's blanket
32 MiB file-size limit with one fixed-purpose native I/O harness. It launches
only the reviewed `make -C <fresh-build> run/writ_bend_monitor_nested_accept`
command, with no user-provided command or shell interpolation. A fixed command
wrapper may join stdout and stderr before execution, but must pass the build
path as an argument, not interpolate it as shell code. It streams the combined
**raw bytes** in order through gzip to a new private file. It neither filters
warnings/errors nor buffers the entire stream in memory.

- A candidate hard cap is **512 MiB raw** (`536870912` bytes) and **520 MiB
  compressed** (`545259520` bytes), with small fixed-size buffers and an
  existing per-job wall-clock timeout. Measure the exact implemented limits,
  including gzip overhead; neither limit is a promise that a large run will
  finish. Capture memory, evidence files, parsed lines and artifacts must be
  bounded; total build disk is not quota-proven by this proposal.
- Record the started command and input identities, child exit status or signal,
  raw byte count/SHA-256, compressed byte count/SHA-256, gzip finalization,
  pipe EOF/drain state and timestamped failure reason. Publish a **complete**
  log status only after the process outcome is known, input reaches EOF, the
  compressor finishes successfully, file close succeeds, and independent
  bounded decompression verifies raw size and hash. Metadata must be atomically
  finalized; a missing or partial record is incomplete, never inferred success.
- If a raw/compressed cap, write, compressor, pipe read, EOF/drain, timeout or
  audit fails, mark the run and fixture assertion **incomplete**, irrespective
  of a recorded success-looking line. Preserve bounded partial output with an
  explicit prefix/truncation indicator and hash only the bytes actually
  retained; do not label a prefix hash a whole-stream hash. A partial gzip may
  lack a valid trailer: preserve its bounded bytes as incomplete evidence
  without requiring decompression to succeed. Do not synthesize a successful
  negative control from a nonzero setup/build exit.
- At a hard cap, it is acceptable to stop consuming and close the owned pipe;
  a writer may then receive `EPIPE`/`SIGPIPE`. This is a declared incomplete
  capture, not a process-termination proof. Do not signal by numeric PID,
  PGID or process name. An injected foreign pipe holder and same-UID upload
  races remain part of the existing disposable-VM residual threat model.
- The runner's fresh VM disk is finite and not a proof of a precise filesystem
  quota. Removing blanket `RLIMIT_FSIZE` avoids killing an unrelated-to-logging
  build output at 32 MiB, but can allow other build files to consume disk until
  the VM or separate timeout stops them. Capture `ENOSPC`/write failure and
  report incomplete. Any additional build-output quota must be independently
  scoped and reviewed; do not reuse a limit that silently affects every file.

The exact compressed log and metadata must be retained in the public artifact
allowlist. The existing snapshot helper currently buffers files and caps each at
32 MiB; it would need a reviewed *streaming* FD-to-FD copy and per-name limit
for `run.log.gz` of at most 520 MiB, with the existing directory identity,
regular-file, no-symlink/no-hardlink and pre/post checks. Do not expand every
other artifact's bound. Missing, changing, oversized or unverified snapshots
must fail incomplete, and the existing outer foreground timeout and reserved
upload window remain. The current snapshot deadline is two minutes within a
65-minute job; assess bounded copy, audit and upload time at the proposed
maximum and reserve a realistic window before dispatch. A copy, audit or upload
timeout remains incomplete, and delivery is not guaranteed. An explicitly bounded reader for the uploaded gzip is
required; ordinary unrestricted decompression is not an audit policy. Snapshot
and upload remain observations, not process attestation or protection against a
malicious same-UID process after snapshot.

## Audit and fixture outcome

A separate fixed-purpose auditor must stream-decompress without allocating the
whole output, enforce the 512 MiB decompressed cap, reject malformed or
truncated gzip, and independently recompute the recorded raw length/hash. It
must also validate the compressed length/hash. Never trust an advertised gzip
size to preallocate or treat a partially read stream as complete. Preserve the
original compressed bytes, audit metadata, and any audit failure. Require
exactly one gzip member with no trailing bytes; concatenated members, trailing
garbage, or inability to establish the member boundary are incomplete. The
auditor must account for every compressed byte, not rely on a decoder that
silently accepts extra members. Full logs may contain public fixture output and
compiler messages. The workflow does not deliberately pass or print
credentials, but unfiltered subprocess output and the same-UID residual risk
cannot guarantee that no credential is accidentally disclosed.

Only after complete capture and successful audit may the existing unchanged
fixture's exit and expected evidence be evaluated. The parser must hash and
count the exact decompressed bytes it parses, match the independently audited
raw hash/count, and revalidate compressed hash and file identity. A retained
FD alone does not prevent in-place writes; a mutation or ambiguous identity is
incomplete, and adaptive same-UID racing remains outside attestation. The positive case requires
all existing R assertions; the negative case requires the exact expected client
mismatch and harness failure, not merely an arbitrary nonzero status. A reader
may stream through the audited raw output to locate these lines, but must not
stop early and thereby skip gzip integrity verification, and must prevent races
between the audited file and any later use. Missing evidence or either cap
means **fixture assertions not confirmed**, even if a partial excerpt happens
to contain a success string. Both GitHub jobs still conclude nonzero/incomplete
because in-guest cleanup is not verified; any separately recorded route or
control observation remains limited to this public synthetic fixture.

## Offline checks required before any later dispatch

Implement the collector and auditor only after independent design review, then
review their exact source and native I/O boundaries. Exercise synthetic producers
and temporary files only: complete empty/small/multichunk streams; a compressible
warning-heavy stream; an incompressible stream; exact raw-cap and one-byte-over
boundaries; compressed-cap boundary; producer nonzero/signal; invalid or
truncated gzip; incorrect byte/hash metadata; unwritable destination and disk
failure injection; concatenated gzip members and trailing garbage; mutation
between audit and fixture parsing, including an in-place rewrite on the same
inode; consumer/snapshot symlink, FIFO, hardlink and file-change
refusal; early parent death and a descendant holding a pipe; and timeout or
missing metadata. Compare the complete retained raw bytes and hash when under
the cap. A success-looking marker before an overflow or audit failure must
never turn the result into a confirmed fixture observation. Test ordinary and
malformed UTF-8 as bytes, not just lines. No test may inspect or signal
unrelated processes or start Genode.

The reviewed workflow ref/SHA and trusted no-concurrent-writer precondition,
separate positive and negative VMs, source pins, bounded output, no retry
without review, incomplete cleanup and upload-failure reporting remain in the
[disposable CI plan](nested-routing-disposable-ci.md). Exact workflow/tooling
review and a subsequent dispatch remain future work.
