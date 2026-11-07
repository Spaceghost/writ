# Standalone synthetic manifest-pair syntax checks

The contribution's pure Bend checker accepts or rejects the fixed public
manifest/status **syntax and original-byte hash binding**. A match does not
authenticate a worker, caller, source, output-directory lifetime, exit status,
cleanup or completion, and creates no Writ authority or release effect.
Fabricated and replayed matching pairs deliberately remain syntax matches. No
native file capture, FFI, real worker, Genode/QEMU run, host identity probe or
GPU test is included.

The [71 standalone checks](tests.log) passed with pinned Bend 2.0.39 and the
generated Node program; stdout was byte-identical (SHA-256
`644db9ef08a101671e06d90079558b70ce86998468044fcd5683474374ba5e7d`).
They cover both public scenarios, all eight status-hash words, 20-digit u64
boundaries, pinned config fields, the exact 1 GiB aggregate and a plus-one
rejection, malformed/rehashed names and numbers, full manifest/status
truncation prefixes (1,344 and 187 prefixes), early and late 128/255/256/U32
max values on both inputs (one-byte early inputs and bytes appended to valid inputs), a same-length status NUL, cap+1 and 10,000-element inputs, and a 1,462-byte
valid maximum-width fixture with a 225-byte status. The [fixture audit](fixtures.log)
independently checks 40 fixed manifest/status hashes with Python hashlib,
including nine intentional mismatches, seven status-only cases and the 1,462-byte
fixture. The [five feasibility checks](feasibility.log) separately exercise
1,462-byte and 1,466-byte byte-to-hex/SHA inputs on Bend and Node before the
checker implementation; the 1,466-byte ceiling example is a conversion input,
not a claim that it is a canonical manifest.

The [mutation summary](mutants.log) covers six independent source mutants and
three post-cap sentinel/bypass variants on both Bend and Node. Exact source
substitutions are in [the patch record](mutants.patch.txt) and executable
[test harness](../../contrib/native-hosts/genode/boot-inventory/pair-checker/test-mutants.py).
The sentinel proves branch reachability in its modified scratch source; it does
not itself observe the original SHA call. Separate [inspection of the exact
external Node artifact](node-staging.txt) found the downstream operations in
their corresponding success branches. Only summary outcomes are retained;
raw mutant subprocess logs and scratch sources were not retained. An initial
mutation-harness run exited 1 because an earlier aggregate-overflow assertion
failed before the requested plus-one assertion; the tests were reordered to
exercise the latter directly. Its raw output was not retained.

A fresh standalone [native CPU run](native.log) also passed the same 71 checks
with `+RTS --threads 1 --gpu off -RTS` and output identical to Bend/Node. The
[117-file Bend source inventory](bend-inputs.sha256) covers all tracked Bend
files plus these five new contribution files, checked before build and after
build/run. It is a source observation, not independent process attestation;
the compiler's optimization flags were not observed. The binary remains in
`/tmp`. An earlier [62-check native run](early-native.log) started while the
test file was still being edited and had no pre-build source inventory; it
is historical only and does not validate the final source or final suite.
The earlier [68-check run](native-68-historical.log) and [70-check run](native-70-historical.log) used their separately recorded [68-source inventory](bend-inputs-68.sha256) and [70-source inventory](bend-inputs-70.sha256), respectively, checked before and after those runs. Their uncommitted source bytes are identified by hashes, not retained as complete source snapshots, and neither run validates the final 71-case revision. An initial attempt to execute an emitted `.mjs` directly produced no main
output and its comparison failed; the corrected standalone `.js` run passed.
The original empty output was not separately retained.

The source worktree was based on design commit
`adee0635d5bf88747df38b8d28251f86af37c762`; final input hashes are recorded
above before subsequent evidence-only reconciliation. Bend 2.0.39 SHA-256 was
`2ec160fa4486d33aff51e9eedcc294d6b531dc10c279c00b0c00685dae2045cd`;
Node was v26.10.0. The unchanged root `bend Tests.bend` passed 2,318 checks,
and `bend PROOF.bend --verdict` returned `ALL PROOFS CHECK` using BendTT SHA-256
`e365eba1741602bb45261aa0eb6bd2c6f5db885d4b9d4cd603a27bc3c5a9ed18`.
These do not prove the new checker or host controls. Strict OpenSpec 1.16.0
passed 44/44. The root test suite, Nix filtered source set, policy and security
laws remain unchanged.

To repeat the standalone tests with the pinned executable, keeping generated
code outside the checkout:

```sh
bend contrib/native-hosts/genode/boot-inventory/pair-checker/Feasibility.bend
bend contrib/native-hosts/genode/boot-inventory/pair-checker/PairTests.bend
bend contrib/native-hosts/genode/boot-inventory/pair-checker/PairTests.bend -o /tmp/writ-pair-tests.js
node /tmp/writ-pair-tests.js
python3 contrib/native-hosts/genode/boot-inventory/pair-checker/check-fixtures.py
python3 contrib/native-hosts/genode/boot-inventory/pair-checker/test-mutants.py /absolute/path/to/pinned/bend
```

The optional native fixed-FD capture, exact byte handoff to Bend, exclusive
FD-table/output-directory boundary, overall deadline, supervisor, worker exit,
publication and cleanup are still unimplemented. Input is synthetic public
data and all parsing results remain non-authoritative.
