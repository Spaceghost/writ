# Synthetic native-capture to Bend pair-checker test

A test-owned temporary directory holds a fixed public manifest/status pair. The
ctypes harness calls the standalone `writ_pair_capture`; only its
`CAPTURED_PARTIAL` result is copied to two bounded lowercase-hex environment
values. A fixed Bend-authored test entry decodes them, calls the existing pure
`PairSyntax.check`, and re-encodes the decoded lists. The harness compares each
returned hex byte and the test-expected result in memory. This exercises the
actual synthetic bridge, not a worker, production FFI, supervisor, completed
inventory, boot observation, host qualification, or Writ authority.

The test's explicit C ABI probe compares size, field offsets and widths with
ctypes before capture. Fixed public tests cover canonical and modified pairs,
empty snapshots, all 256 byte values including NUL/LF/0x80/0xff, the 4,096/512
capture caps and the checker's smaller syntax caps. The Bend decoder separately
compares a literal `00..ff` hex sequence with an independently counted numeric
sequence, preventing a matching encoder/decoder mistake from hiding a changed
byte value. Fixed malformed, odd, uppercase, non-hex, missing and over-cap
hex values require their exact bounded refusal on the Bend and Node backends.
The harness checks native failure and cleanup-uncertain status separately and
the actual capture-result gate must not invoke either checker on failure.

The ordinary and UBSan instrumented native test libraries both passed the
[same fixed test output](synthetic.log), SHA-256
`92860dbf092a82b6b974839f367361231e8d9e1204bea4573d1a3375da6af85f`,
with [ordinary exit](synthetic.exit) and [UBSan exit](synthetic-ubsan.exit) 0
and empty respective stderr. The test compiled the fixed Bend entry to an
external JS file, SHA-256
`ac02541efb160aeb6f6a0890744f6005c56ad9882a9888a9e798953002bace1e`,
and ran both the Bend entry and generated Node entry. Generated JS and native
libraries remain outside the checkout. `python3 -O` [exited 1](python-optimize.exit)
with the [fixed refusal](python-optimize.stderr) before loading the library,
so disabled Python assertions cannot silently pass the test.

Three isolated scratch mutations exercise test sensitivity, not exhaustive
coverage. A [capture gate mutation](mutant-gate.patch) that admits the
cleanup-uncertain `-1` result [exited 1](mutant-gate.exit) on the named
[no-launch assertion](mutant-gate.log). A [decoder mutation](mutant-decoder.patch)
that changes a hexadecimal digit value [exited 2](mutant-decoder-bend.exit)
on [Bend](mutant-decoder-bend.stderr) and [Node](mutant-decoder-node.stderr)
([Node exit](mutant-decoder-node.exit)) at the fixed known-byte control. A
[checker mutation](mutant-checker.patch) forcing `PairMalformed` [exited 1](mutant-checker.exit)
on the [canonical positive assertion](mutant-checker.log). These are synthetic
test changes in separate scratch copies; the delivered capture and checker
implementation are unchanged.

The [fixed input inventory](test-inputs.sha256) covers all tracked Bend files,
this test entry, the native capture inputs, ABI shim, test scripts and public
fixture bytes. It records content observations before commit, not process
attestation. Existing root [Bend tests](root-bend.log) exited 0 with 2,318
passes and SHA-256
`e87d601d12b49d85bc45d20f2b59ca1d7ece694cc1828b7f21d4713be3f9ad50`;
[proof verdict](proof-verdict.log) exited 0 for the existing 37 laws only.
No proof of this bridge, optimized native CPU suite, GPU test or host run is
claimed.

## Reproduction and trust limits

This test is explicitly local and synthetic. Its library, Bend and Node paths
are **caller-supplied trusted test inputs**; the harness does not authenticate
them or act as a general safe command launcher. The observed run used GCC
16.2.1, Python 3.14.7 (`/usr/bin/python3`, SHA-256
`d78f9cf7178ecff09963551399855543c297f37ac207e626228bfe43cb26a70c`),
Node v26.10.0 (`/usr/bin/node`, SHA-256
`06b9073a69a1b7a4bf0e6d64c48b08294ef23a450e0e8e94b96fc8a4820d7e6d`), and
Bend 2.0.39 (`/home/jadams/.local/share/writ-toolchains/bend-2.0.39/bend/bin/bend`,
SHA-256 `2ec160fa4486d33aff51e9eedcc294d6b531dc10c279c00b0c00685dae2045cd`).
The Lean-backed kernel SHA-256 was
`e365eba1741602bb45261aa0eb6bd2c6f5db885d4b9d4cd603a27bc3c5a9ed18`.
Tool and library hashes are observations, not process attestation.

```sh
cc -std=c11 -O2 -Wall -Wextra -Werror -fPIC -shared -DWRIT_PAIR_CAPTURE_TESTING \
  contrib/native-hosts/genode/boot-inventory/capture.c \
  contrib/native-hosts/genode/boot-inventory/pair-checker/handoff-abi.c \
  -o /tmp/writ-pair-handoff-review.so
python3 contrib/native-hosts/genode/boot-inventory/pair-checker/test-handoff.py \
  /tmp/writ-pair-handoff-review.so \
  /home/jadams/.local/share/writ-toolchains/bend-2.0.39/bend/bin/bend /usr/bin/node
```

The separate sanitizer build used `-O1 -fsanitize=undefined
-fno-sanitize-recover=all` with the same inputs and warning flags. The observed
ordinary and UBSan library hashes were respectively
`cb60acf8bfadb28c61f54156b9413a317f76b6504da5d338378fc5c5116573ab` and
`702faa1add8e879673bd684fde80ce923f8d5b88d73ff7f2d5ede36139688c5e`.

Only fixed public test bytes are allowed: the environment, child process
memory and pipes can be observed by same-user processes. The re-encoded bytes
are compared in bounded in-memory pipes and are **not** written to test logs.
Do not use this harness with secrets, arbitrary user-supplied data or a real
worker. The capture's trusted owned directory, exclusive stable FD table,
same-UID race, procfs/mount trust and sequential-read limits remain unchanged.

The fixed test commands use no shell, enforce stdout/stderr accumulation caps,
and send no signals. The pipe and direct-child wait have **no enforced deadline**;
a stuck tool or inherited pipe can block indefinitely, including cleanup after
an output-limit failure. The output cap controls retained memory, not child
lifetime, system resources or descendant cleanup. The tests dynamically cover
stdout/stderr cap boundaries and selector-setup cleanup; they do not test every
possible read/close failure. Future production plumbing needs its own reviewed
transport, identity/lifetime binding, deadlines and cleanup evidence; this
experiment establishes none of those. All proposed host tasks remain open.
