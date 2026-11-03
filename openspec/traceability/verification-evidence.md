# Verification evidence traceability

| Requirement | Source or record | Evidence | Coverage |
| --- | --- | --- | --- |
| VE-001 | [AGENTS.md](../../AGENTS.md), root and `examples/` `.bend` files; [optional adapter](../../contrib/rclone/README.md) | 34 unchanged core/example Bend files; 14 contribution Bend files and a separate minimal Go adapter; generated artifacts excluded | Repository inspection and separate contribution checks |
| VE-002 | [verification/environment.txt](../../verification/environment.txt) | Bend 2.0.39, clang 19.1.1, four native CPU threads | Recorded toolchain |
| VE-003 | [VERIFICATION.md](../../VERIFICATION.md), [tests-js.txt](../../verification/tests-js.txt), [tests-native.txt](../../verification/tests-native.txt) | Both suite logs have 638 passing checks and completion sentinel; four self-checking teaching examples add 29 assertions per backend | Executed on JS/native CPU; examples counted separately |
| VE-004 | [PropertyTests.bend](../../PropertyTests.bend) | 324 checks: four oracle fixtures, 256 directed cases, 64 separate equality cases | Finite executable oracle coverage |
| VE-005 | [gpu-codegen.txt](../../verification/gpu-codegen.txt), [gpu-example-native.txt](../../verification/gpu-example-native.txt) | Three device entry points; CPU fallback run | Physical GPU unverified |
| VE-006 | [LAWS.bend](../../LAWS.bend), [PROOF.bend](../../PROOF.bend), [kernel-verdict.txt](../../verification/kernel-verdict.txt) | Three ordinary checks; independent toolchain startup failure recorded | Selected laws only |
| VE-007 | [source-sha256.txt](../../verification/source-sha256.txt), [cleanup-review.txt](../../verification/cleanup-review.txt) | Current source/document hashes; comment-only runtime comparison against the preceding revision; complete tests rerun | Source/package binding |
| VE-008 | [openspec/README.md](../README.md), each pending change's tasks | Baseline versus pending capability separation | Specification/process review |

OpenSpec validation checks document structure and selected consistency rules. It
does not execute Bend scenarios or prove security. Its own version and result are
recorded separately from the 638-check Bend suite.

The [example walkthrough](../../docs/GETTING-STARTED.md) connects the public APIs
to concrete allowed and denied cases. [examples-js.txt](../../verification/examples-js.txt)
and [examples-native.txt](../../verification/examples-native.txt) capture those
four self-checking programs. Their synthetic authority records are not an issuer,
and their successful pure transitions do not execute a host adapter.
