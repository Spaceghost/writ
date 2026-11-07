# Experimental public-fixture layout check

A public fixture's `core` entry is expected to point to the fixed `core-linux`
build link, which in turn points to a fixed stripped output. `layout.c` checks
this proposed two-link shape and 12 other mappings on owned synthetic trees.
**It is not the planned inventory collector.** It reads no file contents,
compares no config bytes, produces no hashes or manifest and cannot report a
completed boot-input observation. A zero return means only that its checks
passed at the times observed. For example, the synthetic controls explicitly
show that an incorrect regular-file config still passes this layout check.

The entry point takes trusted, already held invocation, build and Genode-source
FDs, numeric fixed invocation identifiers and a public fixture scenario. It
checks those descriptors against the constructed `/tmp` fixture location and
fixed children, traverses fixed paths with `openat2` no-follow and no-cross-mount
flags, inspects held links without following their text, bounds file sizes and
two independent directory scans, and refuses unsupported operations and drift.
The table, Linux kernel and its filesystem semantics, callers and retained FDs
are trusted. Callers must ensure the intended FDs were held before the fixture:
this helper does not establish their historical provenance. The test-only hook
and error injection are omitted from a normal build.

No supervisor or fixture calls this helper. It does not itself establish `procfs`
identity, reopen a held file, verify contents, stage/publish output, enforce an
independent time limit or retire any process. A separate [held-file read](read-held.h)
can hash a caller-supplied held regular inode; the two helpers are not connected
and do not together implement a collector. The layout check closes the leaf
FDs it observed, so reopening a pathname afterward would not bind the digest
to the checked object. A future reviewed composition must retain or transfer
the very same checked leaf FD, rather than re-resolving its path. The 32-entry and size caps do not
bound a blocking filesystem call. There is no automatic fallback if `openat2`
is unsupported. Metadata checks and two scans cannot rule out same-UID
A→B→A races or in-place adaptive changes, nor establish what an earlier process
actually consumed. The reviewed [inventory design](../../../../openspec/changes/add-genode-host/disposable-boot-inventory-design.md)
continues to require these missing facilities and independent review before a
complete inventory or workflow integration. No Genode, QEMU, device or host
qualification is involved in the [synthetic evidence](../../../../verification/genode-boot-layout/README.md).

To repeat the owned-temporary-tree controls, use an isolated external output:

```sh
cc -std=c11 -O2 -Wall -Wextra -Werror -fPIC -shared -DWRIT_BOOT_LAYOUT_TESTING \
  contrib/native-hosts/genode/boot-inventory/layout.c -o /tmp/writ-layout-check.so
python3 contrib/native-hosts/genode/boot-inventory/test-layout.py /tmp/writ-layout-check.so
```


The `read-held.c` probe requires an already held `O_PATH` regular file and one
of the two fixed per-file size caps. It duplicates the descriptor, verifies a
procfs root and its numeric/current-process PID and FD view, and deliberately
follows only the internally numbered held FD magic link. It compares inode and
metadata before and after a bounded byte read and repeats the procfs identity
checks. It produces a SHA-256 digest only on success and clears its outputs on
failure. It does not check the file against a fixture reference or the fixed
layout, establish how the caller obtained the FD, hash an inventory or publish
an output. It accepts any owned regular `O_PATH` FD the caller supplies; a digest itself
is information, so callers must restrict it to the fixed public test inputs.
The caller and FD table must be trusted and stable; concurrent FD
table manipulation, in-place adaptive changes, mount-namespace manipulation,
A→B→A changes and a blocked regular-file I/O call remain outside its claims.
The internal 30-second monotonic check cannot interrupt a blocked syscall; a
separate reviewed supervisor is still required.

The native-only SHA-256 probe dynamically uses OpenSSL `libcrypto` EVP and its
provider/configuration environment. The observed synthetic run used OpenSSL
3.6.5 (`libcrypto.so.3`, SHA-256
`a75a864dcda6ef9e4dc29fad4b7988ca832b904c3915a63c920062c40763dae1`);
that host library, dynamic loader and provider setup are trusted, not a pinned
portable dependency. No Writ core dependency or policy functionality is added.
The [synthetic read controls](../../../../verification/genode-boot-read-held/README.md)
do not establish behavior on another runner or establish host qualification.
