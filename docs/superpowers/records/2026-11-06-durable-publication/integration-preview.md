# Durable publication integration preview

A caller retries an output after losing an acknowledgement. The combined tree
contains synthetic Linux monitor checks, bounded HostWire decoding, and an
experimental durable-publication model. It still has no authenticated durable
transaction, witness, receiver deduplication, or crash-tested recovery. A
model result cannot authorize real publication or qualify the Linux host.

This is an **isolated integration preview**, not a landed change or acceptance
claim. It combines master `9c08eb93b86a6025d3b254551557e394f7685f7c` with
`lane/durable-publication` `dd18cb0657a2c030be7b258082683e19f837c85e`, then
incorporates master `1fcd29a` and `1646a8d`, which preserve two failed Windows
native CI runs, and durable `a78d71b`, which adds comparison-bound comments
and a standalone failing resource probe. The original worktrees and branches were not
modified. The Windows run remains failed/partial as its own record states; no new Windows result is
implied. Independent security review remains outstanding, and the task-order
review gates in the [durable plan](../../plans/2026-11-06-durable-publication.md)
are unchanged. All DP acceptance tasks and audit durability tasks stay open.

The preview subsequently incorporates master `b34ae99`, which corrects
documentation, preserves Windows diagnostic records, and adds an optional
standalone no-data Windows initialization diagnostic. The CI and Nix runs
below remain attributed to their exact tested source
`61ab2a453915c4162e7ba726b9dfd6f1759f3410`; they did not test the later
standalone diagnostic. Its separate Windows result and the subsequent failed
strict gate are recorded on master. This merge is not a new execution or host
qualification.

The `Tests.bend` merge retains both Linux/HostWire and durable suites. The only
textual merge conflict was `verification/source-sha256.txt`; it was regenerated
for the complete tree. The current HostWire implementation is unchanged from
master: SHA-256
`05b9ec272a14895397fc413b0bde3f0ffa112f2f205752fe2d952586a775da98`.
Named checks in the combined suite include `PH-011 very oversized word input
denied TooLong before parsing` and `PH-011 very oversized byte input denied
TooLong before parsing`. A combined synthetic pass does not establish a native
Linux identity boundary or a durable service.

## Results and exact inputs

- With pinned Bend 2.0.39, `bend Tests.bend` and generated Node output match
  byte-for-byte, ending in `ALL LIBRARY TESTS PASSED` with 2,285 PASS lines.
  Output SHA-256:
  `bac0e2b581c8f4ad7eae2812e34177cbe97f35ed3f87e2d352da119aaa19f67a`.
- Generated JavaScript SHA-256:
  `3434a650b25f3c29f617538d3d4edeba783ca5587e621b974555d70980778297`.
  The host QuickJS harness passes 2,285 checks with program exit 0, no exception,
  20,715 ticks, and 20,949,920 peak live bytes under a 128 MiB limit. Host
  QuickJS is not a Genode guest or physical GPU run.
- The digest of sorted `sha256sum` lines for all Git-tracked `*.bend` files
  in the initial combined test tree (through durable dd18cb0) is
  `1e2bf86118771915683a4dc6e750dc8c4f625624c2e5fbf893d4c7edeea577a5`.
  After a78d71b's two comment-only edits and new standalone probe, this digest
  is `80f4f1725b21b39b8f073c0e99322af67f90138d7bbd83df7d449a046e84a10f`.
  Implementation tokens of `DurableIntent.bend` and `DurableJournal.bend` were
  compared to dd18cb0 and match; their 25 and 35 focused checks pass. Generated
  full-suite JavaScript and output are unchanged. The probe is deliberately
  outside the suite and preserves a Node stack-overflow failure on unbounded
  synthetic input, not an expected security law; see [the review](model-review.md).
  `Tests.bend` itself is
  `d1f530761d86ccb0629ae2c6e0d1f51b58837d758b3fe5860e0dc72b90a5df92`.
  The checked-in source manifest records each delivered file independently.
- `bend PROOF.bend` reports `ALL PROOFS CHECK`; no new durable proof law or
  Lean kernel verdict is claimed. `openspec validate --all --strict
  --no-interactive` passes 44/44, a structural result.
- `nix build --offline --no-link .#checks.x86_64-linux.tests-js` passes with
  the preview's 2,285-check pin. At source 61ab2a4 the full `nix flake check
  --no-update-lock-file --option max-jobs 1` also passes all four checks,
  including optimized native CPU; its [captured logs and hashes](../../../../verification/durable-integration-61ab2a4/nix/README.md)
  retain exact source and tool scope. The optimized Bend-generated native CPU run of the initial combined
  source (before a78d71b's comment-only edits and separate probe) passes and
  its output is byte-identical to the Bend capture. The subsequent affected
  implementation tokens and generated JavaScript are unchanged, as recorded
  above; that earlier optimized native binary was not rebuilt after those
  edits. The later full Nix check above built and ran the native suite at
  source 61ab2a4.

At exact source `61ab2a453915c4162e7ba726b9dfd6f1759f3410`, the
[Windows Node policy run](../../../../verification/windows-policy-run-42312512618/README.md)
passes 2,285 core and 78 WritFS model checks, while the separate [Linux public
canary run](../../../../contrib/native-hosts/linux/verification/run-42312512646/README.md)
passes its scoped native cases and preserves the intentionally refused setup.
Their core test outputs match the Bend capture above. Neither result qualifies
the proposed protected-worker host or any durable-publication protocol.
At the same source, the [Genode base-hw QEMU run](../../../../contrib/native-hosts/genode/evidence/run-42312512632/README.md)
passes 2,285 core and 69 mount model assertions, plus its scoped native public
filesystem and libc/VFS canary cases. Its source record matches the 204 tracked
source files that could be compared to commit 61ab2a4; generated/native build
artifacts are separately identified by CI hashes. This is not physical GPU,
durable storage or a protected-worker qualification.

The CI and local count pins are updated to 2,285 for this proposed tree so a
future run must account for the new tests. The recorded 2,065-check Genode
QEMU and Nix results belong to their earlier source and remain historical. The
2,285-check guest result above is scoped to exact source 61ab2a4; no physical
GPU or protected-host result is claimed. The durable model
remains a private, synthetic description: `Published`, `Recorded`, journal
and byte-codec constructors authenticate nothing, and no persistence, audit
append, rollback witness, authenticated sink, or recovery protocol is added by
this merge. See [durable traceability](../../../../openspec/traceability/durable-publication.md)
and [audit integration design](audit-integration-design.md) for named gaps.
