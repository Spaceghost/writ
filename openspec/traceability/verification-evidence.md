# Verification evidence traceability

| Requirement | Source or record | Evidence | Coverage |
| --- | --- | --- | --- |
| VE-001 | [AGENTS.md](../../AGENTS.md), 28 root `.bend` files | Source inventory and artifact exclusions | Repository inspection |
| VE-002 | [verification/environment.txt](../../verification/environment.txt) | Bend 2.0.39, clang 19.1.1, four native CPU threads | Recorded toolchain |
| VE-003 | [VERIFICATION.md](../../VERIFICATION.md), [tests-js.txt](../../verification/tests-js.txt), [tests-native.txt](../../verification/tests-native.txt) | Both suite logs have 638 passing checks and completion sentinel | Executed on JS/native CPU |
| VE-004 | [PropertyTests.bend](../../PropertyTests.bend) | 324 checks: four oracle fixtures, 256 directed cases, 64 separate equality cases | Finite executable oracle coverage |
| VE-005 | [gpu-codegen.txt](../../verification/gpu-codegen.txt), [gpu-example-native.txt](../../verification/gpu-example-native.txt) | Three device entry points; CPU fallback run | Physical GPU unverified |
| VE-006 | [LAWS.bend](../../LAWS.bend), [PROOF.bend](../../PROOF.bend), [kernel-verdict.txt](../../verification/kernel-verdict.txt) | Three ordinary checks; independent toolchain startup failure recorded | Selected laws only |
| VE-007 | [source-sha256.txt](../../verification/source-sha256.txt) | Hashes of authored source and documentation | Source/package binding |
| VE-008 | [openspec/README.md](../README.md), each pending change's tasks | Baseline versus pending capability separation | Specification/process review |

OpenSpec validation checks document structure and selected consistency rules. It
does not execute Bend scenarios or prove security. Its own version and result are
recorded separately from the 638-check Bend suite.
