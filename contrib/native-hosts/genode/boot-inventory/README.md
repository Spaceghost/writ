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

No supervisor or fixture calls this helper. It does not establish `procfs`
identity, reopen a held file, verify contents, stage/publish output, enforce an
independent time limit or retire any process. The 32-entry and size caps do not
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
