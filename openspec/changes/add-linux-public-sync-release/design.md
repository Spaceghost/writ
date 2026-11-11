## Context

Linux needs a writable desktop-facing mount and packaged delivery matching the
Windows public preview. Both use the unchanged Bend entry/version/CAS and
persistence/readback state machine, not independent native decision engines.

## Native representation

FUSE presents a user-owned root over a private persistent cache outside the
mount. A sparse hello.txt stub carries only native placeholder metadata until
read. Payload retrieval checks the immutable backing record through Bend READ.
Regular temporary files support editor replacement. Writes are flushed to the
private cache before acknowledgement; expected base and recovery copies live
outside the mounted namespace.

All FUSE operations use direct I/O and a shared native mutex. The commit holds
that mutex and the retained file descriptor through snapshot, recovery copy,
store-lock/CAS, durable head publication, Bend persistence acknowledgement,
exact reread and the admitted in-sync effect. Competing FUSE writes/renames must
wait. No shared mmap or writeback cache is enabled. This is the Linux counterpart
to the Windows retained exclusive oplock; native probes must demonstrate it.

Backing frames match the bounded 80-byte WRITP01 framing on supported x86_64
little-endian hosts. Store filesystem calls and SHA-256 observations are native;
the authoritative candidate and transition decisions stay in Bend.

## Lifetime and cleanup

An exclusive per-root provider lock and private per-user control socket own the
mount lifetime. Control accepts only bounded status, stop and lock-probe commands,
with same-user peer credentials; it is not a policy endpoint. Cleanup verifies
the owned FUSE mount identity before unmounting. Hydrated and dirty cache files
are retained and materialized into the unmounted user root. Failed cleanup must
abort uninstall before removing the app. Abrupt termination retains cache and
recovery state; a restarted owned root reconciles it against the retained base.

FUSE requires a running provider while mounted. A stopped provider leaves
ordinary materialized files rather than Windows Cloud Files placeholders. This
platform difference must not hide missing committed or uncommitted bytes.

## Delivery

The installer targets the current user's application directory and desktop
entries, without elevating. Packages include Node, generated policy, the FUSE
shared library, notices and test commands. The system fusermount3 helper and
OpenSSL 3 remain explicit OS prerequisites. Linux builds target glibc 2.35+;
musl, other CPU architectures and interactive desktop application qualification
remain separate gates.

One desktop version tag rebuilds both platforms. Pin downloaded tools and
library sources, record the actual compiler/runner, compare repeated native and
package bytes, and retain successful and failed evidence. Publish a complete
draft only after both native jobs pass, then verify anonymous downloads.
