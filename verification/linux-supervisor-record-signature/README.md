# Supervisor provisioning record signed by a pinned operator key

> Superseded in part: version 4 adds a serial checked against a floor pinned
> beside the key, so an older signed record below the floor is now refused.
> See the [record serial record](../linux-supervisor-record-serial/README.md).

Example: the operator signs the provisioning record on a machine that holds
the operator's Ed25519 secret key, and installs the signed file as
`/etc/writ/supervisor.record`. The supervisor's provisioning module pins the
matching public key. `writ_supervisor_provision` forwards the file's `fstat`
facts and bytes as LINUXSUP1 `PROVISION`, as before. Bend now checks, in
order: the file facts, at most 4096 bytes, every value a byte, and then that
the last 64 bytes are an Ed25519 signature (RFC 8032) by the pinned key over
`WRIT-LINUXSUP1-RECORD` followed by every byte before them. Only after that
does it parse the record (version 3) and check its consistency and issuer
root. A process running as the supervisor's user that rewrites the file, for
example to name itself in a role or to pin another program, produces a record
that is refused (`SignatureInvalid`), and the profile stays unprovisioned. It
can still substitute an older record the same key signed.

Current gap: the key in every test, and in the only provisioning module, is
the RFC 8032 TEST 1 key, whose secret key is published; it stands in for an
operator and authenticates nobody. A signature has no freshness, so an older
record signed by the same key is accepted again: rollback is not detected.
Nothing protects, rotates or revokes the pinned key beyond the operator's
control of the supervisor's launch. Worker sessions are still not bound, the
issuer is still the synthetic canary and clock samples are scripted. LH-011
therefore remains a reviewed-only gap.

## What changed

| Part | Source | Responsibility |
| --- | --- | --- |
| SHA-512 | [`lib/Sha512.bend`](../../lib/Sha512.bend) | FIPS 180-4 SHA-512 over a byte list, with 64-bit words as pairs of U32 halves. A value above 255 or a message of 2^29 bytes or more is refused, never masked |
| Ed25519 | [`lib/Ed25519.bend`](../../lib/Ed25519.bend) | RFC 8032 verification only: exact key and signature lengths, S below the group order L, a key that decodes (y below p, x exists, no negative zero), k = SHA-512(R, A, message) unreduced, and [S]B - [k]A, computed in one double-and-add pass, encoding to exactly R. Field elements are sixteen 16-bit limbs so that every product fits a U32. No secret is handled |
| Record | [`SupervisorProvision.bend`](../../hosts/linux/monitor/SupervisorProvision.bend) | Version 3: the version 2 body followed by the signature. `install(anchor, facts, bytes)` checks the facts, the size and byte range, then the signature, and parses nothing before it verifies. `Anchor` is the pinned key; `no_anchor()` verifies nothing. Version 2 (unsigned) is refused |
| Wire | [`SupervisorWire.bend`](../../hosts/linux/monitor/SupervisorWire.bend) | The interpreter state holds the anchor given to `unprovisioned(state, authority, anchor)` by the provisioning module. No frame carries or changes it |
| Module | [`SupervisorDriverModule.bend`](../../hosts/linux/monitor/SupervisorDriverModule.bend) | The SYNTHETIC test module pins the RFC 8032 TEST 1 public key |
| Native test | [`supervisor-owner-test.c`](../../contrib/native-hosts/linux/supervisor-owner-test.c), [`Makefile`](../../contrib/native-hosts/linux/Makefile) | Signs its records at run time with the TEST 1 secret key through libcrypto, which only the test links. The driver (`supervisor_owner.c`) is unchanged: it forwards bytes, holds no key and verifies nothing |

## What ran

| Run | Result |
| --- | --- |
| [`lib/Ed25519Tests.bend`](../../lib/Ed25519Tests.bend) | [6 checks](ed25519-checks.txt) |
| [`SupervisorProvisionTests.bend`](../../hosts/linux/monitor/SupervisorProvisionTests.bend) | [9 checks](provision-checks.txt), one new |
| `SupervisorApprovalTests`, `SupervisorOwnerTests`, `SupervisorWireTests`, `SupervisorRoleLaunchTests` | 11, 16, 8 and 12 checks, unchanged |
| Native driver test (gcc, Makefile flags with `-Werror`) | [63 cases](native-run.txt), exit 0; [20 repeats](native-repeat.txt), no directory left behind |
| clang build with `-Werror` | builds and passes |
| [Mutants](mutant-results.txt) ([diffs and outputs](mutants/)) | 23 of 25 fail; the survivors are below |
| `bend Tests.bend` | [differs from `ea156773`](suite-diff-against-master.txt) by the new and renamed checks only; `check_core.py` verifies 3288, see the [suite tail](suite-tail.txt) |
| Native CPU suite (`clang -std=c11 -O0`, `+RTS --threads 4 --gpu off`) | [byte-identical](native.txt) to the Bend run; no GPU test is claimed |
| Full suite as JavaScript under QuickJS 2026-06-04 with the Genode corpus's 512 KiB stack | [passes](quickjs-run.txt) in 38.9 s, against 20.9 s at `ea156773`: each full verification costs about 1.8 s there. The Genode lane runs this corpus under QEMU with a 1200 s deadline; no Genode run is claimed here |
| `bend PROOF.bend`, and `--verdict` with the Lean-built BendTT | [`ALL PROOFS CHECK`](verdict.txt); no law mentions signatures |

The [commands](commands.txt) and the [environment](environment.txt) are
recorded. The receiver needs `SO_PASSRIGHTS` (Linux 6.16 or newer); the test
exits 77 when the channel profile is missing.

## Cases

New native cases (the record is otherwise the canary, with both program pins
replaced by the digest of the test's role program):

| Case | Observed |
| --- | --- |
| `unsigned_record_refused` | a protected 0600 file holding the body without a signature: `PROVISION_REFUSED`, fail-stop |
| `rewritten_record_refused` | a signed record whose role 2 principal was changed from 102 to 101 after signing: `PROVISION_REFUSED`, fail-stop |
| `other_key_record_refused` | the same body signed by the RFC 8032 TEST 2 key: `PROVISION_REFUSED`, fail-stop |

Every other native case that provisions now uses the signed record, and
`foreign_root_record_refused` signs its mismatched record, so its refusal is
the issuer-root check rather than the signature.

The Bend checks cover:

- SHA-512 against hashlib digests of "abc", "", the 112-byte FIPS 180-4
  message and 111- and 128-byte messages (the padding boundaries), and
  refusal of a value above 255;
- field normalization at the carry edge, where two carry passes would leave
  limb 0 at 2^16 + 28;
- the base point's encoding, decode-then-encode of the TEST 1 and TEST 3 keys,
  and refusal of keys with y = p + 1, y = 1 with the sign bit set, and y = 2
  (no x on the curve);
- RFC 8032 TESTs 1 to 3 verifying, and refusal of an altered message, an
  altered R, another key, S + L and S = L in place of S, the identity and
  order-2 keys with R = encode(identity) and S = 0 (which RFC 8032's
  equation accepts for every message), malformed keys, a 63-byte signature
  and a value above 255;
- the signed canary installing over the canary issuer root; refusal
  (`SignatureInvalid`) of the TEST 2 key's signature, a TEST 1 signature
  without the signing context, a signed record with its first byte changed,
  the body alone, an empty and a 63-byte file, and any record under
  `no_anchor()`; `RecordVersion` for a correctly signed version 2 body (the
  signature is necessary, not sufficient); `RecordRange` for a value above 255 and `RecordTooLong`
  before the signature is examined; and, through the wire, an unsigned
  record replying `PROVISION_REFUSED` and stopping.

The fixtures were signed with Python `cryptography` from the RFC secret keys;
the three RFC vectors were checked against it as well. The test suite never
signs: Bend has no signing code.

Small-order keys are a choice beyond RFC 8032: the RFC's equation accepts
them, but under one a fixed R and S verify for every message, so `verify`
refuses any key whose eighth multiple is the identity.

An independent review of the change found no defect in the field
arithmetic bounds, the reductions, SHA-512, the verification equation or the
provisioning order, and cross-checked the constants and further SHA-512,
signature and field values against Python. It found that a pinned
small-order key would authenticate nothing (now refused, above), that two
documents overstated the result (a process of the supervisor's user can
still substitute an older signed record; now said), and asked for the tests
added above. The `two-carry-passes` mutant first survived; the carry-edge
check now kills it.

Mutant notes:

- `length-unchecked` survives. Without the exact 32- and 64-byte checks,
  every wrong-length key or signature tested is still refused, by decoding,
  the small-order check or the equation; the check stays as the stated
  precondition.
- `s-equal-order-allowed` survives. Accepting S = L could matter only when
  [L]B = R + [k]A can be met, which needs a small-order key, and those are
  refused.

Not exercised: a non-canonical encoding of a valid R (comparing encodings
refuses it by construction, but no vector was built), a record at exactly
4096 bytes, and a real operator key.

Every process, socket and file in the native test is created by the test. It
requests no privilege, signals only its own children, mounts nothing, probes
nothing host-wide and starts no VM.

## Not established

- **A real operator key:** only the published RFC 8032 TEST 1 key is used.
- **Freshness:** an older record signed by the same key is accepted again.
- **Key custody:** the pinned key is as trustworthy as the provisioning module
  the operator launches; nothing here protects, rotates or revokes it.
- **Program provenance, sessions, relaunch, issuer and clock:** as in the
  [role program record](../linux-supervisor-role-programs/README.md).
- **Qualification:** no host qualification; this test is not part of any CI
  lane.

These remain reviewed-only gaps under LH-011 to LH-017.
