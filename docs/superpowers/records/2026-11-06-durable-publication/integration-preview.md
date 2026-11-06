# Durable publication integration preview

A caller retries an output after losing an acknowledgement. The combined tree
contains synthetic Linux monitor checks, bounded HostWire decoding, and an
experimental durable-publication model. It still has no authenticated durable
transaction, witness, receiver deduplication, or crash-tested recovery. A
model result cannot authorize real publication or qualify the Linux host.

This is an **isolated integration preview**, not a landed change or acceptance
claim. It combines master `9c08eb93b86a6025d3b254551557e394f7685f7c` with
`lane/durable-publication` `dd18cb0657a2c030be7b258082683e19f837c85e`, then
incorporates master `1fcd29a`, which only preserves failed Windows native CI
evidence. The original worktrees and branches were not modified. The Windows
run remains failed/partial as its own record states; no new Windows result is
implied. Independent security review remains outstanding, and the task-order
review gates in the [durable plan](../../plans/2026-11-06-durable-publication.md)
are unchanged. All DP acceptance tasks and audit durability tasks stay open.

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
- The digest of sorted `sha256sum` lines for all Git-tracked `*.bend` files at
  test time is `1e2bf86118771915683a4dc6e750dc8c4f625624c2e5fbf893d4c7edeea577a5`.
  `Tests.bend` itself is
  `d1f530761d86ccb0629ae2c6e0d1f51b58837d758b3fe5860e0dc72b90a5df92`.
  The checked-in source manifest records each delivered file independently.
- `bend PROOF.bend` reports `ALL PROOFS CHECK`; no new durable proof law or
  Lean kernel verdict is claimed. `openspec validate --all --strict
  --no-interactive` passes 44/44, a structural result.
- `nix build --offline --no-link .#checks.x86_64-linux.tests-js` passes with
  the preview's 2,285-check pin. Nix native and the full flake have not been
  rerun. The optimized native CPU build is running.

The CI and local count pins are updated to 2,285 for this proposed tree so a
future run must account for the new tests. The recorded 2,065-check Genode
QEMU and Nix results belong to their earlier source and remain historical; no
2,285-check guest, GPU or protected-host result is claimed. The durable model
remains a private, synthetic description: `Published`, `Recorded`, journal
and byte-codec constructors authenticate nothing, and no persistence, audit
append, rollback witness, authenticated sink, or recovery protocol is added by
this merge. See [durable traceability](../../../../openspec/traceability/durable-publication.md)
and [audit integration design](audit-integration-design.md) for named gaps.
