# Task 1 report: shared core count and PR verification

Status: implementation complete; independent review pending.

Core behavior is unchanged. Added the shared reviewed 3072 count, a Python
output verifier and four test methods covering malformed counts, missing or
repeated final markers, FAIL records, truncated/concatenated output, wrong
counts, CLI exits and CRLF. Nix uses this same verifier. Genode CI reads the
shared count; the native script retains its explicit environment gate.

The new GitHub-hosted PR workflow verifies the pinned Bend archive, runs the
bundled JavaScript suite, ordinary proofs and OpenSpec, and retains logs. It
never routes PRs onto self-hosted machines. Native/GPU/kernel qualification
remains separate. No Bend module, law, test, or OpenSpec task changed.

Local checks: 3072 PASS records and ALL LIBRARY TESTS PASSED from Bend 2.0.39's
bundled JavaScript runner on base be40588; the new output checker accepts it.
Python unittest: four test methods passed, with negative controls in subtests.
Bash syntax and git diff --check passed. Ordinary proof run and final
OpenSpec results are recorded by the controller after completion. Nix and native
Genode execution have not been repeated by this lane.
