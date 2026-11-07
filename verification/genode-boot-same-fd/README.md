# Synthetic same-descriptor public boot observations

The partial observer retains the exact 14 `O_PATH` leaves checked by the fixed
public-fixture layout, hashes those held inodes, revalidates fixed root, path,
link and inode identities, then closes its own descriptors before copying
results. Its only success-like status is `WRIT_PUBLIC_PARTIAL_OBSERVATION`.
It never produces a manifest or a complete-inventory decision.

On owned synthetic trees, the [511 cases](observe.log) exercise both fixed
scenarios and independent ordered expected digests; 14 hash-stage, 44 retained
acquisition, 44 retained close, 140 reader-close and 250 layout-close fault
injections; and explicit index/cap boundaries, post-read rename/replacement, identical-text
new symlink, in-place drift, missing path and descriptor reuse. Test-only phase markers
verify the relevant mutations happen after all 14 reads. Fault hooks simulate
failures after closing test-owned FDs; they do not prove recovery from an
actual failed or stuck kernel operation. Failure results require all-zero
caller outputs; the reuse control checks that an unrelated test-owned sentinel
is not closed. The slot-swap control changes test-only read selection indices,
leaving the private ownership array intact. The different-inode replacement
control is deliberately narrower than general reuse protection: a separate
known-limitation control reuses the internal FD number for a separately opened
FD to the **same inode**. The observer returns partial success and closes that
replacement FD; metadata cannot prove ownership. A trusted exclusive stable
FD table is a prerequisite, and no actual worker or workflow may use this probe
until that boundary is established and independently reviewed.

The [36 layout cases](layout.log) retain the old layout-only entry's behavior
for inheritable borrowed FDs and unrelated invocation-root metadata changes.
The new observer requires CLOEXEC and stable metadata on borrowed roots. The
[25 held-read cases](read-held.log) exercise the prior standalone API. Normal
and undefined-behavior-sanitized runs produced identical outputs. A production
GCC `-fanalyzer -Werror` build exported only [the three public symbols](production-symbols.txt);
the private context, read status and test hooks are not dynamic exports.

These runs used GCC 16.2.1 and trusted OpenSSL EVP/libcrypto 3.6.5
(`/usr/lib/libcrypto.so.3`, SHA-256
`a75a864dcda6ef9e4dc29fad4b7988ca832b904c3915a63c920062c40763dae1`),
with generated shared objects kept in `/tmp`. Caller, exclusive stable FD table, kernel,
procfs, mount namespace, crypto loader and provider configuration remain
trusted. A digest is information, so this is restricted to public fixture
inputs; no protected input was used. Exact config-reference comparison, an
independent overall deadline, publication, supervisor, process cleanup and
fixture integration remain unimplemented. Adaptive same-UID mutation,
A→B→A changes and blocked I/O are not ruled out. No Genode, QEMU, GPU, host
identity probe or host qualification is claimed.

The test build and controls can be repeated with:

```sh
cc -std=c11 -O2 -Wall -Wextra -Werror -fPIC -shared \
  -DWRIT_BOOT_LAYOUT_TESTING -DWRIT_BOOT_OBSERVE_TESTING -DWRIT_BOOT_READ_TESTING \
  contrib/native-hosts/genode/boot-inventory/layout.c \
  contrib/native-hosts/genode/boot-inventory/read-held.c \
  contrib/native-hosts/genode/boot-inventory/observe.c -lcrypto -o /tmp/writ-observe-test.so
python3 contrib/native-hosts/genode/boot-inventory/test-layout.py /tmp/writ-observe-test.so
python3 contrib/native-hosts/genode/boot-inventory/test-read-held.py /tmp/writ-observe-test.so
python3 contrib/native-hosts/genode/boot-inventory/test-observe.py /tmp/writ-observe-test.so
```

The UBSan build used the same sources and macros with `-O1
-fsanitize=undefined -fno-sanitize-recover=all`; the production build omitted
all three test macros and used `-O2 -fanalyzer`. The final checks ran in the worktree based on reconciled commit
`5df7082f82f3d273935e2ca7b6d7bd006767dceb`, after the slot-bound guard and
known-limitation control changes. The original implementation was based on
design commit `647608f6a903017589bddb9be92d78023da4b72c`. The pinned Bend executable (SHA-256
`2ec160fa4486d33aff51e9eedcc294d6b531dc10c279c00b0c00685dae2045cd`)
ran `bend Tests.bend` with 2,318 PASS lines and exit 0; stdout matched the
retained [layout suite log](../genode-boot-layout/bend.log) byte for byte.
`bend PROOF.bend --verdict` exited 0 with output matching the retained
[verdict](../genode-boot-layout/proof-verdict.log) and used BendTT SHA-256
`e365eba1741602bb45261aa0eb6bd2c6f5db885d4b9d4cd603a27bc3c5a9ed18`.
These commands verify unchanged Bend sources, not the C observer. OpenSpec
1.16.0 strict validation passed 44/44.
