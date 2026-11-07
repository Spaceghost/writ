# Synthetic exact public-config checks

The partial public observer compares each config read buffer with the fixed
scenario reference before hashing that same buffer from the same held inode.
On owned temporary trees, the [531 observer cases](observe.log) cover both
archived public vectors, scenario and byte/LF/NUL mismatches, short chunks,
EINTR, EOF/growth and fault injection, plus the existing ownership/revalidation
controls. The previous arbitrary 16 KiB config-positive fixture is now correctly
an exact-reference mismatch; the standalone reader's general 16 KiB boundary
remains covered by its [25 cases](read-held.log). The [36 layout cases](layout.log)
retain earlier layout-only behavior.

For successful config reads, separate test-only EVP contexts fingerprint the
bytes at the comparison and hash-call boundaries; tests compare each fingerprint
and count to the independently pinned archived-vector SHA-256, including
multi-chunk reads. No arbitrary input bytes or fingerprints are printed. The
[16 reference/mutation controls](references.log) check each compiled array
against its tracked argument plus one LF and the historical ZIP member, verify
the fixed hashes and reject unknown scenario. Three separately compiled
scratch mutants change one embedded reference byte, bypass the comparison, or
shift/shorten the hash input; each exits 1 at its named observer assertion.
Only the named outcomes are retained in the log; generated mutant binaries and
full subprocess output are not retained. The changed-source control modifies a
separate test-owned copy; it does not establish that any supervisor pinned a
reference before starting a child.

The two public arrays in `config-reference.h` were formed once by reading each
tracked `writ_guard_{positive,negative}.args` file, appending one LF, checking
byte-for-byte against that scenario's archived `installed-config.txt`, and
emitting fixed hexadecimal byte initializers in groups of 16. The [design](../../openspec/changes/add-genode-host/same-fd-exact-config-design.md)
records their lengths, full hashes and reference provenance. The independent
compiled-array/ZIP controls do not regenerate expected runtime bytes. These are
native fixed public data constants, not generated Bend backend code. The
source, binary, caller, exclusive stable FD table, kernel, procfs and OpenSSL
loader/provider environment remain trusted.

The normal and UBSan control outputs match byte-for-byte. The separately built
scratch mutants inside the reference test use the normal GCC flags even when
the base library is UBSan-instrumented. A production `-fanalyzer -Werror`
build exported only [the three existing public symbols](production-symbols.txt);
reference access, stream instrumentation and fault hooks are test-only. The
runs used GCC 16.2.1 and OpenSSL 3.6.5 `libcrypto.so.3` (SHA-256
`a75a864dcda6ef9e4dc29fad4b7988ca832b904c3915a63c920062c40763dae1`).
Generated libraries were kept in `/tmp`.

These controls do not establish a pre-fixture pin or protect against adaptive
same-UID changes, A→B→A replacement, blocked I/O or concurrent FD-table
manipulation. In particular the previously observed same-inode FD-reuse
limitation remains. The supervisor, independent total deadline, publication
and actual-worker FD-table boundary are unimplemented. Exact comparison does
not prove what a previous process consumed, authorize any protected data, or
qualify a host. No Genode, QEMU, host identity probe or GPU test was run.

The control build and runs were:

```sh
cc -std=c11 -O2 -Wall -Wextra -Werror -fPIC -shared \
  -DWRIT_BOOT_LAYOUT_TESTING -DWRIT_BOOT_OBSERVE_TESTING -DWRIT_BOOT_READ_TESTING \
  contrib/native-hosts/genode/boot-inventory/layout.c \
  contrib/native-hosts/genode/boot-inventory/read-held.c \
  contrib/native-hosts/genode/boot-inventory/observe.c -lcrypto -o /tmp/writ-config-exact-test.so
python3 contrib/native-hosts/genode/boot-inventory/test-layout.py /tmp/writ-config-exact-test.so
python3 contrib/native-hosts/genode/boot-inventory/test-read-held.py /tmp/writ-config-exact-test.so
python3 contrib/native-hosts/genode/boot-inventory/test-observe.py /tmp/writ-config-exact-test.so
python3 contrib/native-hosts/genode/boot-inventory/test-config-references.py /tmp/writ-config-exact-test.so
```

The UBSan build used the same sources/macros with `-O1 -fsanitize=undefined
-fno-sanitize-recover=all`; the production build omitted test macros and used
`-O2 -fanalyzer`. The worktree was based on reviewed design commit
`c97996fee0a40b3b16773782b9a9d6e5b5f61752`; native inputs were the source files
captured by this commit's manifest, before the documentation/manifest edits.

Pinned Bend 2.0.39 (SHA-256
`2ec160fa4486d33aff51e9eedcc294d6b531dc10c279c00b0c00685dae2045cd`)
ran `bend Tests.bend` with exit 0 and 2,318 PASS lines, byte-identical to the
retained [layout suite log](../genode-boot-layout/bend.log). The available
`bend PROOF.bend --verdict` exited 0 with output matching the retained
[verdict](../genode-boot-layout/proof-verdict.log), using BendTT SHA-256
`e365eba1741602bb45261aa0eb6bd2c6f5db885d4b9d4cd603a27bc3c5a9ed18`.
These commands check unchanged Bend sources, not this C probe. OpenSpec 1.16.0
strict validation passed 44/44.
