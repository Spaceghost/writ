# Synthetic held-regular-file SHA-256 checks

The [25 synthetic results](synthetic.log) exercise the separate Linux
held-descriptor probe on owned public temporary files. Cases include empty and
multi-chunk files, both fixed cap values, wrong type/filesystem, mismatched
reopened inode, explicit syscall and timeout fault injection, EINTR retry, and
unlink/replacement or in-place mutation during the observation. Failed cases
require zero digest and size; positive cases independently compare Python's
SHA-256. The wrong-filesystem case opens the test-owned directory as a procfs
substitute only in the test build. No device, Genode, QEMU, protected data or
host probe was run.

The Linux `openat2`, procfs and current-PID checks were exercised on this host;
injected failures are synthetic and do not prove the behavior of another
kernel, an interrupted kernel-I/O task, or an active attacker. An `O_PATH` FD
pins an inode but not immutable contents. Metadata checks cannot rule out
adaptive in-place changes or prove what a previous fixture consumed. These
checks do not implement the fixed-layout composition, exact config comparison,
manifest publication, independent deadline, process cleanup or any host
qualification. The trusted caller must own and retain the intended descriptor;
this helper does not authenticate its provenance. A digest is information:
the caller must restrict use to the fixed public test inputs. The layout helper
closes the leaf FDs it observes, so a later path reopen would not bind this
digest to the earlier check; a future composition must retain the same checked
leaf FD.

The following test and production builds used GCC 16.2.1 and OpenSSL 3.6.5's
`/usr/lib/libcrypto.so.3` (SHA-256
`a75a864dcda6ef9e4dc29fad4b7988ca832b904c3915a63c920062c40763dae1`).
No generated library was added to the repository. The UBSan run produced the
same output as the ordinary run, and `-fanalyzer -Werror` accepted the
production build, which exported only [the probe symbol](production-symbols.txt).
OpenSSL EVP, its providers/configuration and the dynamic loader are trusted
native-only dependencies; they are not pinned for a future CI runner and are
not a Writ core dependency.

```sh
cc -std=c11 -O2 -Wall -Wextra -Werror -fPIC -shared -DWRIT_BOOT_READ_TESTING \
  contrib/native-hosts/genode/boot-inventory/read-held.c -lcrypto -o /tmp/writ-read-held-test.so
python3 contrib/native-hosts/genode/boot-inventory/test-read-held.py /tmp/writ-read-held-test.so
cc -std=c11 -O1 -Wall -Wextra -Werror -fPIC -shared -DWRIT_BOOT_READ_TESTING \
  -fsanitize=undefined -fno-sanitize-recover=all \
  contrib/native-hosts/genode/boot-inventory/read-held.c -lcrypto -o /tmp/writ-read-held-ubsan.so
python3 contrib/native-hosts/genode/boot-inventory/test-read-held.py /tmp/writ-read-held-ubsan.so
cc -std=c11 -O2 -Wall -Wextra -Werror -fanalyzer -fPIC -shared \
  contrib/native-hosts/genode/boot-inventory/read-held.c -lcrypto -o /tmp/writ-read-held-production.so
```

On the worktree based on `3267dc419e1a7a65888a13d595a44dabfdb03a14`, after
the native source changes, the pinned Bend executable (SHA-256
`2ec160fa4486d33aff51e9eedcc294d6b531dc10c279c00b0c00685dae2045cd`)
ran `bend Tests.bend` with exit 0 and 2,318 PASS lines. Its stdout was
byte-identical to the retained [layout suite log](../genode-boot-layout/bend.log).
`bend PROOF.bend --verdict` exited 0 with stdout byte-identical to the retained
[verdict](../genode-boot-layout/proof-verdict.log), using BendTT SHA-256
`e365eba1741602bb45261aa0eb6bd2c6f5db885d4b9d4cd603a27bc3c5a9ed18`.
Both commands had empty stderr. They check unchanged Bend sources, not the C
probe. OpenSpec 1.16.0 strict passed 44/44. No GPU test was run.
