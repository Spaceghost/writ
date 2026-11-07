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
can hash a caller-supplied held regular inode. The separate
[`writ_boot_public_observe`](observe.h) retains the exact 14 checked leaf FDs
through the reads and revalidates the fixed paths and held objects afterward.
It returns only the distinctly named partial-observation status and in-memory
hashes after successful checks and closes; failures return zero outputs, and
cleanup uncertainty has its own status. Borrowed root FDs must be CLOEXEC and
their metadata stable for this observer; the older layout-only API retains its
earlier borrowed-FD behavior. The observer also compares the config bytes to its fixed scenario reference
during the same read that feeds SHA-256. It does not publish a manifest or
implement an externally supervised total deadline, and is not a complete
inventory. The embedded public references are trusted compiled constants;
the [reference controls](../../../../verification/genode-exact-config/README.md)
check them against independently retained archive bytes. The 32-entry and size caps do not
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


The same-FD observer and its private descriptor-transfer/cleanup plumbing are
experimental Linux public-fixture I/O only. Their test hooks are absent from
production. A trusted caller must supply the fixed held roots and ensure an exclusive,
stable process FD table throughout observation and cleanup. A tested
same-inode FD-number replacement is not detected and its replacement FD is
closed; no actual worker may call this probe until the FD-table boundary is
established and independently reviewed. The checks do not provide general FD
reuse protection; inode/metadata rechecks cannot rule out same-UID adaptive
changes or prove earlier boot consumption. The 14 returned hashes are
information and must be restricted to the fixed public test; they convey no
policy decision. The [same-FD controls](../../../../verification/genode-boot-same-fd/README.md)
cover both synthetic scenarios and failure/ownership boundaries. No fixture,
workflow, supervisor or host calls this observer.


`config-reference.h` contains the two fixed public installed-config vectors:
the reviewed scenario argument bytes plus exactly one installer LF. These are
compiled into this native diagnostic, not generated Bend backend source. The
selected bytes are compared with each bounded config read buffer before the
same buffer is hashed; the standalone held-read API retains its general
trusted-FD hashing behavior. The fixed source, binary, OpenSSL/provider and
caller are trusted. No synthetic check establishes that these constants or
the executable were pinned before a hypothetical fixture child started.


The separate [`writ_public_synthetic_publish`](publish.h) encodes only the
fixed public 14-slot format and writes a `synthetic-partial` status bound to
the manifest bytes. It is tested only with owned synthetic output directories
and is not connected to the observer or any worker/workflow. A matching pair
can remain after a failed writer exit and caller-provided records can be
fabricated; the pair is not completed inventory, provenance or authority.
The caller must establish an exclusive stable FD table and an exclusive trusted
output directory. Synthetic tests demonstrate that deliberately modifying the
directory after the last check can leave an invalid pair even after a partial
return. No actual worker may use this helper until that boundary is reviewed
and implemented. The [publication evidence](../../../../verification/genode-synthetic-publication/README.md)
records interruption, readback and no-overwrite controls and their limits.
