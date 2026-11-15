# Supervisor provisioning record serial and pinned floor

Example: the operator signed record serial 7 last month and serial 8 today,
after removing a principal from a role. When the operator launches the
supervisor with a provisioning module that pins the operator key and floor 8,
`/etc/writ/supervisor.record` must hold a record signed by that key whose
serial is 8 or higher. A process running as the supervisor's user that puts
serial 7 back, correctly signed as it is, gets `RecordStale`; the profile
stays unprovisioned and the wire stops. The floor is pinned in the module
beside the key, not kept in a file: a state file the supervisor's user could
write would let the same process that restores the old record also lower the
mark.

Current gap: rollback is refused only below the floor. Until the operator
raises the floor, which means launching an updated provisioning module, an
older record at or above it is accepted even after a newer one was signed.
No high-water mark is kept between runs, and nothing protects, rotates or
revokes the pinned key and floor beyond the operator's control of the
supervisor's launch. The key is still the published RFC 8032 TEST 1 key.
LH-011 therefore remains a reviewed-only gap.

## What changed

| Part | Source | Responsibility |
| --- | --- | --- |
| Record | [`SupervisorProvision.bend`](../../hosts/linux/monitor/SupervisorProvision.bend) | Version 4: the version 3 body with a serial word after the version, inside the signed bytes. A zero serial is `RecordZero`; versions 1 to 3 are `RecordVersion` |
| Anchor | same | `Anchor{key, floor}`: the floor is pinned with the key by the module the operator launches, never read from a record, frame or file |
| Order | same | Facts, size, byte range, signature, decode, then `fresh_fault`: a serial below the floor is `RecordStale`, reported before any consistency fault; then consistency and the issuer root |
| Module | [`SupervisorDriverModule.bend`](../../hosts/linux/monitor/SupervisorDriverModule.bend) | The SYNTHETIC test module pins floor 2 (the canary's serial) beside the TEST 1 key, through `SupervisorProvisionTests.anchor` |
| Native test | [`supervisor-owner-test.c`](../../contrib/native-hosts/linux/supervisor-owner-test.c) | Writes version 4 records, and a correctly signed record with serial 1. The driver (`supervisor_owner.c`) is unchanged: it forwards bytes, holds no key and keeps no serial |

`SupervisorWire` is unchanged: its state already holds the whole anchor, so
the floor reaches `install` with the key.

## What ran

| Run | Result |
| --- | --- |
| [`SupervisorProvisionTests.bend`](../../hosts/linux/monitor/SupervisorProvisionTests.bend) | [10 checks](provision-checks.txt): one new, two renamed |
| `Ed25519Tests`, `SupervisorApprovalTests`, `SupervisorOwnerTests`, `SupervisorWireTests`, `SupervisorRoleLaunchTests` | 6, 11, 16, 8 and 12 checks, unchanged |
| Native driver test (gcc, Makefile flags with `-Werror`) | [64 cases](native-run.txt), exit 0; [20 repeats](native-repeat.txt), no directory left behind |
| clang build with `-Werror` | builds and passes |
| [Mutants](mutant-results.txt) ([diffs and outputs](mutants/)) | all 7 fail |
| `bend Tests.bend` | [differs from `f56a3f70`](suite-diff-against-master.txt) by the new and renamed checks only; `check_core.py` verifies 3289, see the [suite tail](suite-tail.txt) |
| Native CPU suite (`clang -std=c11 -O0`, `+RTS --threads 4 --gpu off`) | [byte-identical](native.txt) to the Bend run; no GPU test is claimed |
| Full suite as JavaScript under QuickJS 2026-06-04 with the Genode corpus's 512 KiB stack | [passes](quickjs-run.txt) in 41.2 s, against 42.6 s for `f56a3f70` on the same machine |
| `bend PROOF.bend`, and `--verdict` with the Lean-built BendTT | [`ALL PROOFS CHECK`](verdict.txt); no law mentions record serials |

The [commands](commands.txt), the [environment](environment.txt) and the
[fixture generator](fixtures.py) are recorded. The receiver needs
`SO_PASSRIGHTS` (Linux 6.16 or newer); the test exits 77 when the channel
profile is missing.

Genode lane budget: in the base-hw run for `f56a3f70` the corpus took about
840 s of the lane's 1200 s, and each Ed25519 verification about 40 s under
QEMU's TCG. This change therefore adds one verification (the wire's stale
record) and checks the floor itself on unsigned bodies through
`install_body`, which verifies nothing. No Genode run is claimed here.

## Cases

New native case:

| Case | Observed |
| --- | --- |
| `stale_record_refused` | a protected 0600 file holding the canary at serial 1, correctly signed by the operator key, against the module's floor 2: `PROVISION_REFUSED`, fail-stop |

`rewritten_record_refused` now changes byte 36 (role 2's principal moved one
word with the serial) and `foreign_root_record_refused` word 4.

The Bend checks cover:

- serial 1 under floor 2 refused (`RecordStale`), serial 3 installing, the
  canary refused under floor 3 and installing under floor 1;
- staleness reported before a consistency fault (an empty role map at
  serial 2 is `RecordStale` under floor 3 and `RolesEmpty` under floor 2);
- the U32 limits: serial 2^32 - 1 installs under floor 2^32 - 1, and
  2^32 - 2 is stale there; floor 0 accepts the canary;
- a zero serial refused (`RecordZero`), version 3 and 5 refused
  (`RecordVersion`), including a version 3 body correctly signed by the
  operator key;
- through the wire, the correctly signed serial 1 record replying
  `PROVISION_REFUSED` and stopping.

The fixtures were signed with Python `cryptography` from the RFC 8032 TEST 1
and TEST 2 secret keys. The test suite never signs.

Every process, socket and file in the native test is created by the test. It
requests no privilege, signals only its own children, mounts nothing, probes
nothing host-wide and starts no VM.

## Not established

- **Freshness above the floor:** a superseded record at or above the floor
  is accepted; raising the floor needs an updated module.
- **A high-water mark across runs:** none is kept; a rollback-resistant
  store outside the supervisor user's reach would be needed.
- **A real operator key, key custody and rotation:** as in the
  [record signature record](../linux-supervisor-record-signature/README.md).
- **Program provenance, sessions, relaunch, issuer and clock:** as in the
  [role program record](../linux-supervisor-role-programs/README.md).
- **Qualification:** no host qualification; this test is not part of any CI
  lane.

These remain reviewed-only gaps under LH-011 to LH-017.
