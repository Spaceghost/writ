# HostWire oversized-input guard

A peer provides a 10,000-word or 10,000-byte list to the public decoder. Before
this change the generated Node backend exhausted its call stack while computing
the entire list length, instead of returning `Malformed{TooLong}`. The native
transport must still bound bytes before constructing a Bend value; this direct
API failure does not establish that any particular host accepts a 10,000-byte
frame or qualifies an attack path.

`decode` and `decode_bytes` now use a tail-recursive bounded walk that examines
at most the permitted size plus one element before entering their existing
parsers. The explicit existing check branches preserve the documented error
order, value bounds, authority boundary, and decoded descriptions. No security
law was changed. `HostWireTests.bend` adds two synthetic regressions for 10,000 words and
10,000 bytes plus three combined-error precedence checks; existing tests retain
exact-cap and one-over-limit coverage. An independent review reverted each
old full-length walk separately: the corresponding new Node regression caught
each stack overflow. This is sampled mutation evidence, not a proof.

Before the fix, both isolated Node probes exited 1 with `bend: memory fault
(machine stack overflow?)`. After the fix, each returns `TooLong`. The full
1947-check Bend and Node suites pass with identical output (SHA-256
`310404ca9024b3895fad05d73bfc2f3e159673c3844de2eb0b01266a8236e427`). The
host QuickJS harness passes 1947 checks, 17049 ticks and no exception. Existing
`bend PROOF.bend` checks pass; no Lean kernel verdict or new proof law is
claimed. OpenSpec strict passes 44/44. The full optimized native CPU suite also passes with identical output. The
1947-check Nix build remains unrecorded.

## Genode CI evidence

[Run 42308258031](https://github.com/Spaceghost/writ/actions/runs/42308258031)
executed source commit `b75382c` in a Genode base-hw x86-64 QEMU guest and
passed the 1,947-check core corpus and 69-check mount corpus. The run also
passed the native File_system and libc VFS mount probes. Its retained
[environment](../../../../contrib/native-hosts/genode/evidence/42308258031-environment.log),
[source/build hashes](../../../../contrib/native-hosts/genode/evidence/42308258031-source-and-build.sha256),
[core and mount log](../../../../contrib/native-hosts/genode/evidence/corpus-42308258031.log),
[filesystem log](../../../../contrib/native-hosts/genode/evidence/filesystem-42308258031.log),
and [VFS log](../../../../contrib/native-hosts/genode/evidence/vfs-42308258031.log)
preserve the output with terminal escapes, carriage returns and trailing
whitespace normalized. The [raw artifact hashes](../../../../contrib/native-hosts/genode/evidence/42308258031-artifact-raw-sha256.txt)
identify the original downloaded files. The guest run validates that exact earlier source
commit, not any later combined tree, GPU execution, or protected-host profile.
