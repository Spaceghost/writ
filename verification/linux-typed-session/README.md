# Synthetic Linux typed session-open result

The shared Bend session-open transition now retains the exact session ID
returned by `HostIdentity.bind_session`; the legacy `Step` is its compatibility
projection. The Linux model exposes the same ID in its in-memory `Opened`
outcome. It does not put the ID on `LINUXMON1`: that format remains a
diagnostic, not a correlated allocation receipt. Publicly constructible
results do not authenticate their source or authorize an effect. This record
reports synthetic model evidence, not a native broker, kernel credential,
confinement, replay protection, recovery, GPU execution, or host qualification.
The existing terminal `Nat` allocation/revision risk is unchanged.

On 2026-11-08 UTC, pinned Bend 2.0.39 passed the [16 focused checks](focused.stdout)
and the [full suite](suite.stdout), which has 2,912 named pass lines counted
with `^PASS[: ]` (2,859 counted with `^PASS:` alone); generated JavaScript on
Node v26.10.0 produced byte-identical full-suite stdout. The checks include the exact issued
worker for the first, next, and truncated-table Launch, nondelegable worker
profile binding, client delegation narrowing, exact unchanged denials, literal
legacy admitted/denied/untranslated wire replies, and ordinary non-Launch
routing. `bend PROOF.bend` and the Lean-backed `--verdict` passed the existing
laws; the `/bin/false` kernel negative control exited 1. No law was added or
changed, so this is not a new proof of session-result correctness. OpenSpec
1.16.0 strict validation passed 45/45.

The [tested inputs](tested-inputs.sha256) identify the relevant authored files.
Bend executable SHA-256 is `2ec160fa4486d33aff51e9eedcc294d6b531dc10c279c00b0c00685dae2045cd`;
the BendTT kernel is `e365eba1741602bb45261aa0eb6bd2c6f5db885d4b9d4cd603a27bc3c5a9ed18`.
Focused stdout SHA-256 is `1ff0b26422def31e6039684e17b82e5f802c6389343cb79531f551487a858e35`,
and full stdout SHA-256 is `d3826512aa25b7db9318aa28db424a03baa3c57dc10fee95139ea303988e2799`.
Generated C, JavaScript and native binaries stay outside the source package.

An independent reviewer ran the existing `LinuxHostTests.bend` using pinned
Bend on baseline `54e96b9` and this candidate. The reviewer observed exit 0
and empty stderr for both; the retained 156-line stdout files are identical
(SHA-256 `0be50489901f6b0a79485ad504c9c758efd5ef4253f1680a4403c4f5d9783ced`).
The reviewer did not save separate exit-status files for those two runs.

The complete native suite also passed on CPU with stdout byte-identical to
Bend and Node, and empty generation, compilation and run stderr. The generated
C was built with clang 23.1.1 using `-std=c11 -O0 -static ... -lpthread -lm`;
the executable ran with `+RTS --threads 1 --gpu off`. This hosted `-O0` build
changes the generated runtime's optimization-dependent calling conventions
relative to `-O2`; it does not test GPU execution or native host qualification.
C generation and compilation each had a 16 GiB virtual-memory cap; execution
had a 20 GiB cap. Each used a 600-second wall/CPU cap, 128 MiB file cap, no
core dumps, and a 40 GiB available-memory preflight. The C hash matched before
and after compilation. Generated JavaScript SHA-256 was
`9f2a4a4080694993adb03061c54845de77723f397274cb98d6d2a5a5f92f22e4`,
C was `8f8408937230c132f8f38262335d22b66775bd8ff081b1cd007bddfc471e8588`,
and the native executable was
`e29cbcd226ac2028ee75124058fd49511f925e6e4335c296f209a4a7da840c51`.

The [capture archive](captures.tar.gz), SHA-256
`e5be49e9aa61ac0fcce3101c0a66c1b9cf32b00e8182a0d9b35a555a9b54d6bb`,
contains commands, statuses, stderr, preflights, comparisons, the independent
review outputs and tool hashes. The final focused test, Bend suite, JavaScript
generation/run/comparison, ordinary proof, Lean verdict, OpenSpec validation,
C generation, native compilation/run/comparison all exited 0. The false-kernel
negative control exited 1, as intended. The archive also preserves the earlier
14-check full-suite and Node outputs from before the two review-requested
positive controls were added; the final 16-check outputs are the evidence
reported above.
