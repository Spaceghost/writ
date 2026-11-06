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
claimed. OpenSpec strict passes 44/44. For this standalone source the full optimized native CPU suite later passed
with matching output. [Genode run 42308258031](https://github.com/Spaceghost/writ/actions/runs/42308258031)
also passed 1,947 core and 69 mount checks for `b75382c`; the
[environment](../../../../contrib/native-hosts/genode/evidence/42308258031-environment.log)
and [corpus](../../../../contrib/native-hosts/genode/evidence/corpus-42308258031.log)
are retained. The standalone Nix build was not recorded.

The subsequent combined Linux and HostWire candidate expects 2,065 checks;
see the root [verification record](../../../../VERIFICATION.md) for its
separate results and remaining evidence gaps.

The [Linux public-canary run 42308257803](../../../../contrib/native-hosts/linux/verification/run-42308257803/README.md)
also passed on `b75382c`. Its retained expected setup-refusal output is not a
protected-worker identity or confinement qualification.
