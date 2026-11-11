# Task 2 report

[Native run 43110533402](https://github.com/Spaceghost/writ/actions/runs/43110533402)
at `7fc0967` supplies actual Windows/MSVC execution. Its network-controls job
passes 739 synthetic assertions and all four exact-canary loopback deliveries.
The WinFsp job builds, passes ordinary mount/revocation and all 22 native
private-pipe assertions, then fails the unchanged strict LPAC gate because its
byte-worker network, clipboard and COM initialization remains incomplete.
The overall workflow is explicitly recorded as **failure**.

The actual worker shows shared Winsock startup 10107, four startup-stage
unattempted endpoints and failed bits in both network phases. Its separate
diagnostic reaches socket creation and records 10013; that different profile
receives no byte-worker qualification. All three downloaded evidence ZIPs,
including the initial test compile failure, match GitHub's published digests.
The [verification record](../../../../verification/windows-network-evidence-20261111/README.md)
retains normalized logs, raw member hashes and 204 tested source hashes.

Local `bend Tests.bend` passed all 3072 reviewed assertions, verified by
`utils/verification/check_core.py`. Ordinary `bend PROOF.bend` printed
`ALL PROOFS CHECK`; no Lean kernel verdict or physical GPU check was run.
The native tests for this change are the Windows probe/transport/fixture runs;
no new native machine-code Bend core result is claimed. Authored Bend is
unchanged. Native classification is distinct from complete host qualification.

Genode's previously failed master run was retried: attempt 2 passed at the
same source `0bc0c25`. Attempt 1 had failed only evidence upload after passing
native execution. No source change was necessary for that service failure.

OpenSpec 1.16.0 strict validation passed **45/45**; the exact output is in
[openspec-validation.txt](openspec-validation.txt). All 21 retained captures
match their manifest hashes, all 204 tested source hashes verify, and all 51
local link targets in the changed native/evidence documents exist. The native
code, test sources and workflow still match the tested `7fc0967` revision;
only documentation/evidence has been added afterward.
