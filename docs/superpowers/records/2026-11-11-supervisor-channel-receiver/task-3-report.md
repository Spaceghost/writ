# Task 3 report

Status: DONE. Commit e0d985be "Record supervisor channel receiver selection and evidence".

## Files changed
- openspec/changes/add-linux-host/local-supervisor-profile.md (q24 selection, links to Tasks 1 and 2)
- openspec/changes/add-linux-host/specs/linux-host/spec.md (two LH-011 scenarios)
- openspec/traceability/linux-host.md (scenario to named tests; reviewed-only gaps kept)
- VERIFICATION.md (one paragraph)
- verification/linux-supervisor-channel/ (README.md, bend-focused.txt, bend-suite-tail.txt, proof-tail.txt, native-run.txt, native-repeat.txt, mutant-results.txt, mutants/*.diff and *.out, commands.txt, environment.txt)
- verification/source-sha256.txt (regenerated last from staged content)

## Key outputs
- openspec validate --all --strict --no-interactive: 45 passed, 0 failed.
- Focused Bend: "LocalChannel: 8 checks passed".
- check_core: "Verified 3136 core checks; final success marker present." (first attempt failed only because `time` appended text after the marker; re-run without it.)
- bend PROOF.bend: "ALL PROOFS CHECK"; --verdict not run (no lake/lean).
- Native: 27 PASS, RESULT PASS, exit 0; 20 repeats: 20 x exit 0 "RESULT PASS (0 failures)".
- Mutants (re-run, 9): all exit 1. no-nonpidfs-check and no-rights-rejection need building without -Werror (unused / maybe-uninitialised warnings); the rest build with the strict flags.
- Environment: Linux 7.2.9, gcc 16.2.1, clang 23.1.1, glibc 2.44, CapEff 0.

## Concerns
- Working tree still has unrelated modifications to docs/superpowers/records/.../activity.log and progress.md (not mine, not committed).
- q24 answers file is not present in this checkout; the answer select-scm-pidfd is taken from the instructions and the q24.html option id.
- The README maps native case names to scenario text from the case names and the Task 2 report; I did not re-read each test body.

## Fix round 1
Applied the seven controller rulings: reaped_role_sender is supporting only (FROM_ROLE 1 or SENDER_ERROR); the Bend payload check is described as structural by signature (role 2 maps to 102); missing_sender_without_enable is supporting (receiver-configuration denial); "no from attached" is structural (Denied carries no principal); selection is recorded on the board with q24.html as the in-tree reference; the mapped-by-name caveat is dropped; the Lean --verdict result (exit 0, kernel SHA-256 e365eba1...) is copied to verification/linux-supervisor-channel/verdict.txt with its command. openspec strict: 45/45; links checked; manifest regenerated; git diff --check clean.
