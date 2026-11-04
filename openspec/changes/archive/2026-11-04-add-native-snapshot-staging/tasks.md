# Native snapshot staging tasks

This package covers private native staging only. Existing host, authenticated
issuer, confinement, and durable-publication tasks are unchanged. Checked
implementation tasks record code/typecheck or named local evidence; backend
acceptance is recorded separately in the evidence tasks below.

## 1. Bend implementation

- [x] 1.1 Add native providers, complete identities, canonical selectors, and whole-source sealing; acceptance: pinned Bend typechecking plus delivered identity/source-boundary assertions in `writfs/Tests.bend` and executed parser assertions in `HostTests.bend`.
- [x] 1.2 Bind provider-specific native plans to `DataOS.commit_from_capability` and retain its complete state and intent; acceptance: implementation review and delivered stale-state, subject, artifact, backend, and provenance assertions in `writfs/Tests.bend`; final complete run capture is task 3.1.
- [x] 1.3 Add bounded native inspection, private-parent validation, literal argv, and failure classification; acceptance: the 17 recorded Host checks pass on JavaScript and native CPU, including actual subprocess overflow behavior.
- [x] 1.4 Add verified private-result receipts and read-only exact reconciliation with no blind retry, adoption, or deletion; acceptance: pinned typechecking, source review, and delivered result-control/identity assertions; live backend confirmation remains tasks 3.2 and 3.3.

## 2. Shared primitive and native acceptance harness

- [x] 2.1 Share the unchanged pure Bend SHA-256 implementation through `lib/Sha256.bend` while preserving rclone wrappers and its Go isolation; acceptance: recorded digest-vector and rclone-model regressions on JavaScript and native CPU.
- [x] 2.2 Add public Btrfs/ZFS/zvol fixtures and a disposable native workflow; acceptance: source review confirms Bend-owned assertions, fresh regular-file-backed storage, explicit native support requirements, and cleanup scoped to job-created resources; passing kernel execution is recorded below.

## 3. Evidence and completion gates

- [x] 3.1 Capture the complete current model, host, shared-hash, rclone regression, and applicable core/proof results against the delivered source; acceptance: 78 native-model, 17 Host, 25 shared-digest, 74 rclone-model, and 638 core assertions pass on both JavaScript and native CPU, and the ordinary three-law proof check passes. Independent-kernel/GPU claims remain separate.
- [x] 3.2 Pass the actual Btrfs lane and record tool/kernel/source evidence for payload preservation, readonly behavior, nested-source denial, collisions, receipts, and the exact supported source-generation transition; acceptance: run `41748733557`, job `126308199045`, at `ede07df5ccaa08b4695788770d16b7eeb269d3c0` passed all 11 native assertions and cleanup, captured in `writfs/verification/native-btrfs.txt`.
- [x] 3.3 Pass the actual ZFS filesystem and zvol lane and record tool/kernel/source evidence for payload preservation, readonly behavior, private controls, collisions, receipts, and rejection after test-only exposure; acceptance: run `41748733557`, job `126308199296`, at `ede07df5ccaa08b4695788770d16b7eeb269d3c0` passed all 18 native assertions and cleanup, captured in `writfs/verification/native-zfs.txt`.
- [x] 3.4 Finalize scope/evidence/traceability, validate with OpenSpec 1.16.0 using `OPENSPEC_TELEMETRY=0`, and archive only after required native evidence is reviewed; keep unrelated pending packages and tasks unchanged.

Acceptance references: [requirement traceability](../../../traceability/native-snapshot-staging.md),
[scope](../../../../writfs/README.md), and the
[verification record](../../../../writfs/VERIFICATION.md).
