# Verification evidence traceability

| Requirement | Source or record | Evidence | Coverage |
| --- | --- | --- | --- |
| VE-001 | [AGENTS.md](../../AGENTS.md), root and `examples/` `.bend` files; [optional adapter](../../contrib/rclone/README.md) | The earlier inspection recorded 34 core/example Bend files and 14 contribution Bend files with a separate minimal Go adapter; later source additions are inventoried in [VERIFICATION.md](../../VERIFICATION.md) | Repository inspection and separate contribution checks; earlier file counts are historical |
| VE-002 | [verification/environment.txt](../../verification/environment.txt) | The recorded 1942-check rerun used Bend 2.0.39, clang 23.1.1 and four native CPU threads; the original record used clang 19.1.1 | Toolchains are scoped to their respective runs |
| VE-003 | [VERIFICATION.md](../../VERIFICATION.md), [tests-js.txt](../../verification/tests-js.txt), [tests-native.txt](../../verification/tests-native.txt) | The two linked historical suite logs each have 1942 passing checks and the completion sentinel; four teaching examples add 29 assertions per backend. The 638-check scenario describes an earlier baseline. The separate [combined record](../../docs/superpowers/records/2026-11-05-linux-host/model-only-integration.md) reports 2065 checks on source `73a8055` | Linked logs: JavaScript and native CPU; examples counted separately. The combined run is not the content of those logs |
| VE-004 | [PropertyTests.bend](../../PropertyTests.bend) | 324 checks: four oracle fixtures, 256 directed cases, 64 separate equality cases | Finite executable oracle coverage |
| VE-005 | [gpu-codegen.txt](../../verification/gpu-codegen.txt), [gpu-example-native.txt](../../verification/gpu-example-native.txt), [gpu-validation-hosts.md](../../verification/gpu-validation-hosts.md) | Three device entry points and an earlier CPU fallback run; later observed device launches for the recorded probes on one RTX 4090 host | CPU fallback is not GPU evidence. Device evidence is limited to the recorded configurations and trusted-device profile; loaded-host timings are not representative and no device isolation is established |
| VE-006 | [LAWS.bend](../../LAWS.bend), [PROOF.bend](../../PROOF.bend), [proofs.txt](../../verification/proofs.txt), [kernel-verdict.txt](../../verification/kernel-verdict.txt) | Ordinary Bend checking reports `ALL PROOFS CHECK`; the original independent attempt covered three laws and failed to start, and later attempts are recorded separately | Selected laws only; no independent Lean kernel verdict |
| VE-007 | [source-sha256.txt](../../verification/source-sha256.txt), [cleanup-review.txt](../../verification/cleanup-review.txt) | Current source/document hashes; the historical cleanup review compares non-comment, nonblank lines against its named base for 13 runtime modules | Source/package binding; the cleanup comparison applies to that recorded change, not all later revisions |
| VE-008 | [openspec/README.md](../README.md), each pending change's tasks | Baseline versus pending capability separation | Specification/process review |

OpenSpec validation checks document structure and selected consistency rules. It
does not execute Bend scenarios or prove security. Its own version and result are
recorded separately from the Bend suites and their historical check counts.

The [example walkthrough](../../docs/GETTING-STARTED.md) connects the public APIs
to concrete allowed and denied cases. [examples-js.txt](../../verification/examples-js.txt)
and [examples-native.txt](../../verification/examples-native.txt) capture those
four self-checking programs. Their synthetic authority records are not an issuer,
and their successful pure transitions do not execute a host adapter.
