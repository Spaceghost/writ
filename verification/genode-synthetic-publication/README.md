# Synthetic public manifest packaging checks

The fixed native packaging helper encodes 14 bounded public slots, stages a
manifest and separately bound `synthetic-partial` status without overwriting
existing names, and verifies both through held-inode readback. It accepts
caller-supplied synthetic records and cannot authenticate that an observer ran.
Neither a matching pair nor the helper's partial return is a complete
inventory, Writ authorization, proof of an earlier boot, or host qualification.

The [162 owned-temporary cases](publish.log) cover canonical positive and
negative records, exact hashes and size bounds, 16 fixed-name file/symlink/
FIFO/socket sentinels, short-write/EINTR and failure injection, all 16 format
stages, all 60 read-helper close sites, and 16 interruption phases in exact
owned children. A separate test-only Python parser recomputes fixed fields,
length and SHA and combines pair validity with the separately observed exact
child exit: a clean exit-0 positive passes, and missing/nonzero exit does not.
The parser uses ordinary `Path.open` only on fixed regular files in owned
synthetic fixtures; it is **not** a safe consumer for arbitrary or substituted
paths. Rehashed malformed records are rejected, while fabricated digests and
copied replay can still match syntactically. After status promotion an
interrupted writer can leave a matching pair without a successful exit.

The suite also violates directory exclusivity deliberately: a substituted FIFO
is not opened as data, a symlink swapped after the final pre-rename check can
be promoted but remains uncredited, and post-status drift before final checks
is rejected. The `post-check mutation` control documents a real limit: after
the last verification, a same-UID mutation can leave a mismatched pair even
though the helper returns partial. These controls do not prove resistance to
concurrent mutation. The output directory and FD table must be exclusively
trusted throughout; no actual worker may use the helper until that boundary
and an independent supervisor are implemented and reviewed. The individual
limits in the [design](../../openspec/changes/add-genode-host/public-synthetic-manifest-design.md)
remain: no total deadline, no durable `fsync` protocol, no complete status,
no worker binding or verified cleanup.

Two separately compiled [scratch mutants](mutants.log) remove the write-EINTR
retry or stop after a short write; each is rejected by the named stage-1
control. The script compiles these mutants with normal GCC flags even when
the main test library is UBSan-instrumented.

The full synthetic build also reran [36 layout](layout.log), [25 held-read](read-held.log),
[531 observer](observe.log), and [16 reference/mutation](references.log) cases.
Normal and UBSan outputs were byte-identical; the three scratch reference
mutants compile normally even during the UBSan wrapper run. The production
`-fanalyzer -Werror` build exports only the [four public symbols](production-symbols.txt),
with expected-byte readback and test hooks hidden. All synthetic files and
native shared objects were outside the checkout.

The tests used GCC 16.2.1 and trusted OpenSSL EVP/libcrypto 3.6.5
(`/usr/lib/libcrypto.so.3`, SHA-256
`a75a864dcda6ef9e4dc29fad4b7988ca832b904c3915a63c920062c40763dae1`).
The first no-test-macro analyzer build failed with exit 1 because a test-only
phase variable was unused (`-Werror=unused-variable`). The variable was made
test-only, after which the production build and all final tests passed; the
original compiler output was not saved as a separate raw file.

The synthetic build was:

```sh
cc -std=c11 -O2 -Wall -Wextra -Werror -fPIC -shared \
  -DWRIT_BOOT_LAYOUT_TESTING -DWRIT_BOOT_OBSERVE_TESTING -DWRIT_BOOT_READ_TESTING -DWRIT_BOOT_PUBLISH_TESTING \
  contrib/native-hosts/genode/boot-inventory/layout.c \
  contrib/native-hosts/genode/boot-inventory/read-held.c \
  contrib/native-hosts/genode/boot-inventory/observe.c \
  contrib/native-hosts/genode/boot-inventory/publish.c -lcrypto -o /tmp/writ-publish-all-test.so
python3 contrib/native-hosts/genode/boot-inventory/test-layout.py /tmp/writ-publish-all-test.so
python3 contrib/native-hosts/genode/boot-inventory/test-read-held.py /tmp/writ-publish-all-test.so
python3 contrib/native-hosts/genode/boot-inventory/test-observe.py /tmp/writ-publish-all-test.so
python3 contrib/native-hosts/genode/boot-inventory/test-config-references.py /tmp/writ-publish-all-test.so
python3 contrib/native-hosts/genode/boot-inventory/test-publish.py /tmp/writ-publish-all-test.so
python3 contrib/native-hosts/genode/boot-inventory/test-publish-mutants.py
```

The UBSan build used the same sources and macros with `-O1
-fsanitize=undefined -fno-sanitize-recover=all`; the production build omitted
all test macros and used `-O2 -fanalyzer`. The tests ran on a worktree based on
`67e89619a9791ec05b21a8bd3c0cb0ba5b6003a6` with the native source changes
captured by this commit's manifest. Pinned Bend 2.0.39 (SHA-256
`2ec160fa4486d33aff51e9eedcc294d6b531dc10c279c00b0c00685dae2045cd`)
ran `bend Tests.bend` with exit 0 and 2,318 PASS lines; its stdout matched the
retained [layout suite log](../genode-boot-layout/bend.log). The available
`bend PROOF.bend --verdict` exited 0 with output matching the retained
[verdict](../genode-boot-layout/proof-verdict.log), using BendTT SHA-256
`e365eba1741602bb45261aa0eb6bd2c6f5db885d4b9d4cd603a27bc3c5a9ed18`.
These commands check unchanged Bend sources, not this native helper. OpenSpec
1.16.0 strict validation passed 44/44. No Genode/QEMU, host identity probe,
protected data or GPU test was used.

The `observe.h` comment was also corrected to distinguish absent **real-worker**
publication from this synthetic helper. Its old and new preprocessed tokens
were compared using GCC 16.2.1; [both hashes and cmp exit](header-tokens.txt)
match. Reproduce with `git show
67e89619a9791ec05b21a8bd3c0cb0ba5b6003a6:contrib/native-hosts/genode/boot-inventory/observe.h`
and `cc -E -P -x c -Icontrib/native-hosts/genode/boot-inventory` on that old
header and the current one, then compare outputs. The outputs were kept
outside the checkout. This is a token comparison, not semantic attestation.
