# Working on WritFS native storage

Keep policy, planning, identity validation, and native command semantics in Bend.
Use the existing capability-to-commit gate; a new native operation is not an
authorization mechanism. Core Writ's trusted-input contract still applies.

This first backend acts on whole sealed Btrfs subvolumes and ZFS snapshots. Its
native effects create private read-only stages. Do not claim a mounted POSIX
filesystem, arbitrary-worker confinement, durable logical publication, or
automatic revocation of already issued native handles.

Native identity is not a pathname, transaction number, or content checksum.
Retain complete filesystem/pool and object identities. Native seal hashes name
canonical manifests, not a traversal/hash of every payload byte. Reject stale
observations, nested Btrfs subvolumes, writable sources, collisions, and
cross-filesystem/pool copies. Never silently fall back to recursive file copies.

Use literal argv and bounded subprocesses for existing upstream tools. There is
no shell interpolation in the runtime. Source/staging roots and executable search
paths belong to the trusted single writer. A timeout may leave an unknown native
effect; preserve that uncertainty and do not delete or retry blindly.

Run pure checks on JavaScript and native CPU. Native backend claims require real
temporary Btrfs/ZFS fixtures, separate from mock/parser tests. CI may provision
only newly created regular-file storage, and cleanup may touch only resources
that the same job successfully created. Missing kernel support fails the native
lane. Keep artifacts/toolchains outside the checkout and preserve all production
host/durability tasks until their separate requirements are implemented.
