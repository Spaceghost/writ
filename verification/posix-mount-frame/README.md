# POSIX mount-frame description checks

A synthetic 48-byte frame with a complete 256-bit token decodes to an
untrusted description; a truncated frame returns no partial token. The
[partial proposed profile](../../openspec/changes/add-capability-posix-adapter/mount-frame-description.md)
is not a native device, an authenticated session or a complete POSIX ABI.

On 2026-11-07 local time (2026-11-08 UTC), pinned Bend 2.0.39 and generated
Node v26.10.0 each passed 35 focused checks with identical
[stdout](focused.stdout), SHA-256
`ddef7df471db71b7ac3a0f8e953d694faa90f419c2e2f46bdca6b36595f5b32c`.
The full suite passed 2,844 checks on Bend, generated Node and native CPU;
the three complete outputs were byte-identical to [suite.stdout](suite.stdout),
SHA-256 `6a0ebfabcaad30397f7ae098faea7ff7419b4d5d330dbe1240716a1febdd8535`.
The final test and build commands exited 0 with empty stderr. The native build used
static clang 23.1.1 `-std=c11 -O0 -static ... -lpthread -lm`; the run used
`+RTS --threads 1 --gpu off`. At `-O0`, the generated runtime's
optimization-dependent calling-convention attributes differ from `-O2`;
this is CPU-only test evidence, not GPU or native-host qualification.

The checks include literal golden endian encodings, independent mutation of
every token bit, every short prefix, unknown versions and opcodes, invalid
byte values, declared-size errors, cap boundaries, HostWire incompatibility,
and direct exported-helper calls with forged success flags and 10,000-element
inputs. [Generated Node excerpts](generated-js-review.txt) show the entry's cap
branch and the fixed 48-element match's final `Nil` condition for the tested
JS hash. These are execution and source-inspection checks, not a proof that a
native transport limits buffering or that callers are authenticated.

The ordinary `bend PROOF.bend` and the Lean-backed `--verdict` both exited 0
with `ALL PROOFS CHECK`. The selected BendTT kernel SHA-256 was
`e365eba1741602bb45261aa0eb6bd2c6f5db885d4b9d4cd603a27bc3c5a9ed18`
before and after; a `/bin/false` kernel negative control exited 1 with the
[recorded error](verdict-negative.stderr). These are checks of the existing
laws; no new formal law about this codec was added or proved.

The first focused Node attempt exited 1 after 25 PASS lines with
[`bend: memory fault (machine stack overflow?)`](initial-node.stderr). Its
[partial output](initial-node.stdout) and [status](initial-node.exit) are
retained. That version of the 10,000-item test-fixture builder was non-tail
recursive; replacing it with a tail-recursive builder preceded the successful
final Bend and Node runs. The output does not independently establish the
fault's precise cause.

[Capture archive](captures.tar.gz) SHA-256
`f3256985d1804ebcf0939ffcdca911d213432601db0522e4bb4ac2b78a525199`
contains commands, timestamps, resource preflights, stdout, stderr, statuses,
comparisons, kernel hashes and generated-Node inspection excerpts. The
[tested authored inputs](tested-inputs.sha256) identify the new modules,
root test entry, existing wire helper and proof files; they are not a complete
compiler/toolchain inventory. The archive contains no generated JS/C or native
binary. Bend executable SHA-256 was
`2ec160fa4486d33aff51e9eedcc294d6b531dc10c279c00b0c00685dae2045cd`;
generated full-suite C was
`04c082fb4e93b93d06bf714349b8756a85fe64132f8a78c80667070d92cdeaba`,
generated full-suite JavaScript was
`9b0b7a86869665dc692a3b3c1eafc21dfe3b687c2474dbbcd4161219120063a7`,
and the native CPU binary was
`3ff44012803af91ec143ca133daeac5745f81cb59a56695bdfe63600553a7029`.
The emitted C hash matched before and after native compilation.

The full POSIX operation/response ABI, label-carrying frames, native pre-buffer
limits, authenticated identity and registry, device transport, confinement,
revocation and durable publication are unimplemented. PA-006 is only partially
exercised by the model and task 1.1 remains unchecked.
