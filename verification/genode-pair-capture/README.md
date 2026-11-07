# Synthetic fixed-name pair capture

The standalone Linux `writ_pair_capture` copies the two fixed public files into
bounded private byte snapshots, rechecks their held inode/path and returns both
only after checked cleanup. It does no format parsing, SHA or worker/authority
validation. No FFI, worker, supervisor, fixture, workflow, host identity probe,
Genode/QEMU run or GPU test is included.

The [137 owned-temp controls](capture.log), reproduced with [UBSan](ubsan.log),
exercise empty, binary and exact-cap bytes; short reads and bounded EINTR;
cap+1, missing/special objects and both fixed-name substitutions; procfs/PID,
cross-mount, unsupported-syscall and inode-mismatch test seams; mutations at
recorded read phases; 52 operation faults, 14 close faults and 14 acquisition
`fstat` failures. Simulated wrong filesystem, PID, owner and type feed the
actual rejection predicates; no real device is opened. The FD count checks
apply to successful test cleanup, including those simulated faults. All
failure outputs are zero; injected close uncertainty is distinct. The owned
child `_exit` controls observe only parent wait/exit status and a borrowed FD;
there is no output or consumer credit path in that test.

Each owned FD's saved device/inode/type is checked before close. A deliberately
closed retained pin produces zero output and cleanup-unverified through an
actual EBADF check; this violates the table precondition and does not model a
transient failure on an open FD. A deliberately reused number pointing to a
different test-owned inode remains open and returns
cleanup-unverified; the test then closes its own sentinel. Another deliberately
reused number pointing to the **same** inode is not detected: capture returns
partial and closes that replacement. These are tests outside the mandatory
exclusive stable FD-table assumption, not a general ownership guarantee. If the
initial acquisition `fstat` fails, the just-opened FD gets one close attempt
under that assumption and status stays cleanup-unverified. Missing fstat
identity cannot prove which descriptor would be closed under a hostile FD table.
The test hook injects this condition after a real successful `fstat`; it does
not reproduce every possible kernel failure or establish process attestation.

The caller, stable exclusive FD table and trusted exclusive output directory,
Linux kernel, procfs and mount namespace remain trusted. File bytes may change
adaptively or via A→B→A outside those assumptions; the two file reads are not
an atomic transaction. No syscall deadline, supervisor, cleanup of descendants,
writer exit, earlier boot consumption, provenance, completeness, authority or
host qualification follows. The fixed byte caps and 32 EINTR retries per file,
including the EOF probe, do not interrupt a blocked syscall. Synthetic snapshots
may contain arbitrary public bytes including zero and 255 and are not logged.

Production analyzer build used GCC 16.2.1 with `-std=c11 -O2 -Wall -Wextra
-Werror -fanalyzer`; [only the fixed capture entry](production-symbols.txt) is
exported. Tests used `-DWRIT_PAIR_CAPTURE_TESTING`, first with `-O2`, then
`-O1 -fsanitize=undefined -fno-sanitize-recover=all`; outputs match byte for
byte. Builds and libraries stayed outside the checkout:

```sh
cc -std=c11 -O2 -Wall -Wextra -Werror -fPIC -shared -DWRIT_PAIR_CAPTURE_TESTING \
  contrib/native-hosts/genode/boot-inventory/capture.c -o /tmp/writ-pair-capture.so
python3 contrib/native-hosts/genode/boot-inventory/test-capture.py /tmp/writ-pair-capture.so
cc -std=c11 -O2 -Wall -Wextra -Werror -fanalyzer -fPIC -shared \
  contrib/native-hosts/genode/boot-inventory/capture.c -o /tmp/writ-capture-production.so
```

Work is based on reviewed design `b58707d4957c257a9528075af3fb4f6adbd4e2a2`;
the source manifest identifies the delivered tree. Pinned Bend 2.0.39
(SHA-256 `2ec160fa4486d33aff51e9eedcc294d6b531dc10c279c00b0c00685dae2045cd`)
ran the unchanged root suite with output identical to the retained
[baseline](../genode-boot-layout/bend.log), and `bend PROOF.bend --verdict`
matched the existing [verdict](../genode-boot-layout/proof-verdict.log) using
BendTT SHA-256 `e365eba1741602bb45261aa0eb6bd2c6f5db885d4b9d4cd603a27bc3c5a9ed18`.
These verify existing Bend source only; neither proves this native capture.
Strict OpenSpec validation and the source manifest were checked separately.

The three tested native input hashes (captured before this evidence commit)
are:

```text
4653449ad964004e5a7ef34af0f942a928ac7fd865da8e01a307e308532a46a9  capture.c
62407762e6dd9f5f18245e3177dd0224c8a4a9b512a36aba89ff1a5577fc016a  capture.h
9cde9e85f93fb21186c013a7fb9f08f357aff3545e457914d6e6f31b388f789e  test-capture.py
```

The common 137-case output SHA-256 is
`16da6cf11ceeac57b6644ef6e273d99a603282eeaf8dcaedd1cb138206965c04`.
