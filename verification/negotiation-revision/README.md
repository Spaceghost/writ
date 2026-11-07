# Negotiation session revision boundary

A stale pin or commit against a session at the supported Nat maximum previously
crashed while constructing a provisional successor before selecting denial.
The [original-source reproductions](original-repro-status.log) use source
`b0ed98b569804ee71c3cc7a6badf357790cafadb`, with
[pin](session-pin-original-repro.bend.txt) and
[Backplane commit](session-commit-original-repro.bend.txt) probes. At
`281474976710655` both pinned Bend and generated Node exited 1 with the
retained `original-*-terminal.log` errors; at `281474976710654` the same stale
requests returned `REJECTED` with exit 0. The patched source retains the
existing stage, authority and commit gates; terminal sessions now deny, with
provisional revision arithmetic bounded even under eager evaluation.

The [30 focused checks](focused.log) passed pinned Bend and generated Node with
byte-identical output, SHA-256
`ad72cc1f13c4a0d85657277d2c59ce1efebe5ceff27a7369f2c2464c9751e8b2`.
They check matching and stale terminal revisions at each of the six advancing
transitions and sample admission, exact preservation of every session field,
complete session and ledger preservation for reserve and Backplane/DataOS
commit denials, direct terminal helper preservation, and real max−1 success
through all six transitions and both commit paths. Two additional max−1 stale
checks retain both state objects as appropriate. These are synthetic model
fixtures; public constructors or successful transitions do not authenticate a
session or perform host publication.

The [mutation summary](mutants.log), [exact patches](mutants.patch.txt), and
individual raw Bend/Node logs cover removal of the readiness gate, restoration
of unsafe increment, removal of each terminal-preservation selection, and
bypass of the Backplane readiness gate. Each fails its named check on both
backends; the unsafe increment crashes with the Nat-range error. Scratch
mutant JS and orchestration remain outside the source tree. A separate
[generated Node inspection](node-inspection.txt) records the actual saturated
arithmetic and eager candidate construction for the exact generated artifact;
it is not process attestation.

The full root suite passed **2,386 checks** on [Bend](bend.log) and generated
[Node](node.log), byte-identical SHA-256
`0b775ba0c4ba48c4df765b0dfe842ef99d79b813ffacb0b3dbe9314da087deed`.
Existing [Lean-kernel verdict](proof-verdict.log) is `ALL PROOFS CHECK`;
no law or proof changed and the verdict does not prove these new tests.
Pinned Bend 2.0.39 SHA-256
`2ec160fa4486d33aff51e9eedcc294d6b531dc10c279c00b0c00685dae2045cd` and
BendTT SHA-256
`e365eba1741602bb45261aa0eb6bd2c6f5db885d4b9d4cd603a27bc3c5a9ed18` were used.
The [121-file Bend inventory](bend-inputs.sha256) identifies the source inputs;
the native CPU build is running and its result is not yet recorded.

Offline Nix evaluation produced [this derivation](nix-eval.txt), whose
[description](nix-derivation.json) sets the 2,386-PASS gate. All 85 Bend
files in the evaluated filtered source match the [recorded hashes](nix-filtered-inputs.sha256)
and the tested working tree. A direct pinned Bend run from that immutable store
source in a read-only, network-unshared bubblewrap environment produced
[identical output](nix-direct.log). This did **not** run the Nix derivation,
its gate, a full flake check, or a Nix native build. `HOME` was not changed.

This isolated branch leaves `Ledger.bend`, `LedgerTests.bend`, all laws and
proofs unchanged. It does not fix independent ledger-overflow behavior, prove
atomicity or claim a host/GPU test. The later reviewed ledger change must be
reconciled and the combined source tested independently; previous results
remain attributed to their actual inputs. Strict OpenSpec validation is
structural only, not native host qualification.
