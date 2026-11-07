# Proposed bounded inventory for a disposable Genode fixture

A completed public fixture may leave `genode/core` as a link to `build/bin/core-linux`,
which can itself link to `build/core/linux/core-linux.stripped`. An unrestricted
`find -L | sha256sum` follows those paths by name and can block or read an
unintended object if they change. The proposed inventory instead observes only
fixed descriptor-anchored objects, with explicit bounds. If it cannot establish
the layout, the fixture evidence remains incomplete and its other bounded logs
may still be retained.

The proposed **complete inventory remains unimplemented**. A separate [layout-only
primitive](../../../contrib/native-hosts/genode/boot-inventory/README.md) checks
fixed metadata on synthetic trees. A separate held-file probe hashes a trusted
caller-provided descriptor; the helpers are not connected, do not check exact
config bytes, publish a manifest or establish completion. No guarded Genode run, new host result or
cleanup claim is made. The [guard design](public-fixture-config-guard-design.md)
checks public fixture arguments before installation; this proposal concerns a
separate post-run evidence read. The experimental e233 collector and the
[public route retry](../../../verification/genode-route-retry-42361441863/README.md)
remain historical. Do not run on the shared host or dispatch a workflow merely
because this design exists. The guarded fixture remains pinned separately to
Writ `bb4803b202fd50056279982279fd675501402207`; its later standard Genode
[CI](../../../verification/master-ci-bb4803b/README.md) did not execute these
guarded fixtures. All [Genode host tasks](tasks.md) remain open.

## Source and observation basis

The pinned Genode source is `d18ee9e917200b059549e21f2dd9a55bfe61a0eb`.
Read-only source inspection found:

| Source relative to Genode root | SHA-256 | Relevant behavior |
| --- | --- | --- |
| `tool/run/boot_dir/linux:10–25` | `24dd22b4a63f1dcabf8c4c97dede3db1087f4268d989c42a0421d9b84265f094` | Boot names are absolute symlinks to kernel-specific files under the current build directory's `bin`; core, timer and dynamic linker names are remapped. |
| `tool/run/run:68–108, 115–119, 313–327, 954–967` | `480887b940df809625e9e5d8079676dcc0b736deb0a76ec2bba108db060647b6` | Artifact names come from the build progress log, the boot directory is recreated, the config is installed with `puts`, and name mapping is delegated. |
| `repos/base/mk/prg.mk:196–213, 228–238` | `2983a65fc1ceaab43e1ae76c1389bfb5e7095ad5cfa010a28e85f9261909903c` | Installed program and schema entries can themselves be symlinks. |
| `repos/base/mk/so.mk:165–173` | `ee69dce880d3dad1fa62e7dde473a5a23f28bbe89fc0f11a04003c5015f7ef0c` | Installed shared-library entries can link to stripped outputs. |
| `repos/base/mk/dep_prg.mk:60–70` | `7fffad047665327bebbe3606db4c462b45e33ae6683a3e954a7e11376bc1b8fd` | Program artifacts may include configuration schema names. |

The old retry's [positive](../../../verification/genode-route-retry-42361441863/positive/boot-inputs-sha256.txt)
and [negative](../../../verification/genode-route-retry-42361441863/negative/boot-inputs-sha256.txt)
hash lists each contain the following 14 names. They do **not** retain the
original symlink text, file types, sizes or directory identities. The table's
second-hop paths were observed only in a separate existing local build and are
consistent with the pinned source; they are **not** proof of the fresh CI VM's
layout. A guarded bb4803b run may differ and must become incomplete if the
reviewed fixed table does not fit.

`B` means the invocation's separately held build-directory descriptor; `G`
means its separately held extracted pinned Genode-source descriptor. The first
hop, when a boot entry is a symlink, must be exactly the constructed absolute
`<B>/bin/<bin name>` bytes. A bin symlink's complete text must be exactly the
constructed absolute path under the named root and fixed relative target shown;
no generic path resolution, prefix acceptance, `..`, extra hop or alternate
root is accepted.

| Boot name | Bin name | Expected second target under B or G |
| --- | --- | --- |
| `config` | — | Regular file directly in held boot directory only |
| `core` | `core-linux` | B `core/linux/core-linux.stripped` |
| `hpet_timer` | `hpet_timer` | B `timer/hpet/hpet_timer.stripped` |
| `init` | `init` | B `init/init.stripped` |
| `init.hsd` | `init.hsd` | G `repos/os/src/init/init.hsd` |
| `init.xsd` | `init.xsd` | G `repos/os/src/init/config.xsd` |
| `ld.lib.so` | `ld-linux.lib.so` | B `var/libcache/ld-linux/ld-linux.lib.so.stripped` |
| `libc.lib.so` | `libc.lib.so` | B `var/libcache/libc/libc.lib.so.stripped` |
| `libm.lib.so` | `libm.lib.so` | B `var/libcache/libm/libm.lib.so.stripped` |
| `timer` | `linux_timer` | B `timer/linux/linux_timer.stripped` |
| `vfs.lib.so` | `vfs.lib.so` | B `var/libcache/vfs/vfs.lib.so.stripped` |
| `vfs_pipe.lib.so` | `vfs_pipe.lib.so` | B `var/libcache/vfs_pipe/vfs_pipe.lib.so.stripped` |
| `writ_bend_monitor` | `writ_bend_monitor` | B `app/writ_bend_monitor/writ_bend_monitor.stripped` |
| `writ_channel_client` | `writ_channel_client` | B `app/writ_channel_client/writ_channel_client.stripped` |

## Proposed roots and bounded observation

This is disposable **Linux-hosted public-test evidence tooling**, not Writ
policy or a production host binding. A trusted supervisor would create a fresh
private invocation root under `/tmp` and hold its directory FD and identity
(device, inode, owner, mode) before launching the build. The source root G is
created/extracted under that invocation root; B is created by Genode's
`create_builddir`, which refuses an existing build directory. The supervisor
must capture and hold no-follow directory FDs for G and B after their creation
and before running the fixture, and check that they remain the intended owned
children of the held invocation root. It must not accept a user-selected root,
link target, policy, script or PID. Directory FDs inherited by an intended
helper are explicitly inventoried and closed afterward. A missing identity,
unsupported primitive, replacement, ownership mismatch, unexpected mount or
failure to establish this setup is incomplete.

The existing e233 driver creates these paths by name and does not retain the
root, B and G descriptors for a later inventory worker. Passing and retaining
those descriptors, bounding their lifetime, and binding them to the fixed
driver invocation require a reviewed supervisor change; opening the same path
afterward would not establish that it is the original root. The boot directory
itself cannot be held from before creation without changing Genode's build
sequence. This is a feasibility gap, not an implemented guarantee.

Device-number equality is not proof that mount traversal did not occur: a bind
mount can refer to the same filesystem. For this proposed profile, require
reviewed Linux `openat2` resolution with `RESOLVE_BENEATH`,
`RESOLVE_NO_SYMLINKS`, `RESOLVE_NO_MAGICLINKS` and `RESOLVE_NO_XDEV` for fixed
descents under each held root; `RESOLVE_NO_XDEV` includes bind-mount crossings
([openat2(2)](https://man7.org/linux/man-pages/man2/openat2.2.html)). Inspecting
an expected final symlink uses the documented `O_PATH|O_NOFOLLOW` final-component
exception without resolving it. If the syscall/flags are unavailable or the
layout legitimately crosses a mount, report incomplete; do not silently fall
back to `st_dev` alone. Procfs is a separately verified root and the one
intentional descriptor reopen below is not a descendant of these roots. This
does not protect against a privileged actor replacing the mount namespace or
prove that the earlier Genode process used the held roots.

The boot directory is created **during** the run by Genode. After the fixture
returns, descend from held B through fixed single components
`var/run/writ_bend_monitor_nested_guarded_positive/genode` or the corresponding
fixed `..._negative/genode`; open each as a directory with `O_DIRECTORY`,
`O_NOFOLLOW` and `O_CLOEXEC` relative to the preceding held FD. Inspect owner,
device, type and identity at every hop. This anchors the object observed after
the run; it does not prove it is the directory or file previously consumed by
Genode. The common invocation key/scenario and the exact selected make target
remain fixed by the workflow and recorded; no path text from the run is used to
select an arbitrary destination.

Enumerate by the held boot-directory FD, using a bounded iterator rather than
materializing an unbounded directory listing. Permit at most **32 entries**,
with at most **128 bytes** per ASCII name; require exactly the 14 table names,
with no unknown, duplicate, missing or malformed names. Take a second bounded
observation after reading and compare the set and directory identity; changes,
errors or a count over the cap are incomplete. Python's
[`os.scandir`](https://docs.python.org/3/library/os.html#os.scandir) can accept
a directory FD on supported systems, but concurrent changes to enumeration are
unspecified; neither a successful second scan nor unchanged metadata proves no
transient replacement occurred. Unsupported FD enumeration means incomplete.

For each non-config name, accept only the exact two-link mapping in the table;
direct regular files or other forms are incomplete for this deliberately narrow
profile. Direct `config` must be a regular file. For a symlink, open
its entry as `O_PATH|O_NOFOLLOW|O_CLOEXEC`, verify it is an owned symlink on the
expected device, and read its text from that held symlink FD with bounded
`readlinkat(fd, "")`. Linux documents the empty-path form for such a held
FD ([readlinkat(2)](https://man7.org/linux/man-pages/man2/readlinkat.2.html));
absence or unsupported behavior is incomplete. Compare the complete link text
to the one fixed expected absolute string, then independently open the fixed
next basename from held B's `bin` FD; never follow the link text as a path. The
second link is checked the same way and its mapped final components are opened
one by one relative to held B or G, each directory `O_DIRECTORY|O_NOFOLLOW`.
Reject unexpected types, link text, extra symlinks, cycles, ownership/device
mismatches or changed link identity/text. Record the observed type even when
the check refuses it; do not infer that every future build has this layout.

For a final leaf, first obtain `O_PATH|O_NOFOLLOW`, `fstat` the held object and
require a regular file, expected owner/device, one hard link and an allowed
size. One candidate Linux mechanism then reopens **only that collector-owned,
still-held FD** through a verified trusted procfs `/proc/self/fd/<number>` with
`O_RDONLY|O_NONBLOCK|O_CLOEXEC`, and requires the reopened device, inode and
type to match the still-held FD before reading. This is a deliberate use of a
procfs magic link to the collector's own FD, not permission to follow arbitrary
boot links. The proc directory must be verified as procfs and as the current
process's PID/FD view, and the held FD number must be constructed internally.
Procfs mount identity, self/FD binding and reopening behavior must be
independently tested; reject rather than falling back to a pathname if they
cannot be established. Hold both FDs through the read and check identities and
metadata again. The [Linux open(2) documentation](https://man7.org/linux/man-pages/man2/open.2.html)
explains descriptor-relative lookup and also states `O_NONBLOCK` does not make
regular-file I/O nonblocking. A collector must not promise otherwise.

Use provisional limits of **256 MiB per non-config file**, **16 KiB for
config**, **1 GiB total bytes**, a **64 KiB read chunk**, **4,096 bytes per
link text plus one for truncation detection**, and a **32 KiB manifest**.
Read at most the allowed size plus one; do not map files, allocate by an
untrusted claimed size, or silently truncate. Exact config contents are compared
to the scenario's fixed historical reference, separately from any guard
invocation claim. The prior run did not retain all input sizes, so these limits
are proposed bounds, not a guarantee a future valid fixture fits. Limit,
metadata, short read, content mismatch, unexpected hard-link count or any I/O
failure yields incomplete; no smaller fallback set is reported as complete.

## Publication, time and remaining trust

The worker should write only bounded outputs under a separately held owned
snapshot-directory FD. Create a non-uploaded temporary regular file exclusively
with no-follow; stream and verify its exact bounded content; close it and check
close status before exclusive promotion to a fixed final name. Publish a final
complete result only after **all** names, mappings, reads, hashes and checks
succeed. A failure/timeout produces a separate bounded incomplete status;
`*.tmp` files must not be on the upload allowlist. Never overwrite an existing
final object. If killed after final promotion but before status, consumers must
require the final complete status bound to that file's hash; final-file presence
alone is not completion. This does not assert durable filesystem synchronization.

Use a dedicated child worker and an independent **30-second wall deadline**,
with at most **45 seconds** including bounded status/snapshot handling; the
workflow must reserve upload time beyond that. A worker may still be stuck in
uninterruptible I/O, and signaling only a known owned child does not establish
its descendants have exited. A hard job cancellation may also prevent status
or upload. Treat timeout, termination failure, missing status, failed close,
partial logs or unverified cleanup as incomplete and retain only safe bounded
snapshots. Disposable-VM teardown is fallback containment, not verified in-guest
retirement. No global process discovery or name-based kill is allowed.

An open descriptor pins an object, not immutable contents. Even before/after
`fstat`, complete read, two directory scans, retained link FDs and fixed roots
cannot exclude same-UID adaptive in-place changes or A→B→A substitution. Nor can
a post-run inventory prove which binaries/configuration the earlier Genode
process consumed. Runner, procfs, supervisor, compiler, build tree and public
inputs remain trusted; no host, routing, identity or confinement qualification
follows from hashes. Unexpected symlink chains or unknown artifact sizes must
not lead to an automatic unrestricted `find -L` fallback.

If fixed roots, two-hop targets, procfs reopening, bounded enumeration or safe
publication cannot be established and independently reviewed, use an explicitly
**incomplete** profile: do not dereference boot paths or publish a complete
boot-input manifest, retain independently safe logs/status and known fixture
source/overlay hashes, mark boot inputs unavailable and cleanup unverified, and
make no assertion about a completed guarded fixture. This preserves failure
observations without pretending the old unbounded inventory passed.

## Planned offline controls

Use only test-owned temporary trees and synthetic regular files; no Genode or
QEMU. Include each two-hop table mapping and direct non-config-file refusal; both
scenario paths; exact config, count and byte boundaries; missing/extra names;
wrong absolute root, prefix-collision, `..`, relative target, extra hop, cycle,
changed symlink text/inode, and schema target outside G. Test `O_PATH` held
symlink and descriptor-relative operations on the actual supported Linux APIs,
including absent procfs, wrong procfs, failed reopen, and mismatched reopened
inode. Exercise FIFO, device/special-object substitution before and after the
`O_PATH` observation without opening a device as data, hard links, oversized
and growing files, short reads, in-place changes and directory enumeration
changes. Test no-follow failures and direct config-file acceptance separately.
Include a same-filesystem bind-mount crossing where a safely isolated test
environment permits it; otherwise retain that control as untested, never infer
it from matching device numbers. Inject unavailable `openat2`/resolve flags
and require incomplete without pathname fallback.

Inject failure or interruption before/after write, close, promotion and status;
verify no partial final config or complete manifest can be credited, and no
existing file is overwritten. Test deadline expiration and output-cap refusal
with independently bounded test-owned workers, while recording that a killed
worker's cleanup may still be unverified. Reconstruct and validate the two
known 14-name histories without claiming their missing link metadata. Verify
normal logs/refusals are still retained when inventory is incomplete. These
controls test the inventory design only; they cannot prove Genode execution or
protected-host authority.

The [dedicated-VM FD handoff proposal](disposable-fd-supervisor-design.md) describes the unimplemented parent-side preparation, fixture and inventory split. It does not establish a shared-host lifecycle boundary or cleanup.
