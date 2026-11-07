# Windows native run 42320010013

[Workflow run 42320010013](https://github.com/Spaceghost/writ/actions/runs/42320010013)
was automatically triggered on master at exact source
`82c51e85f309d38188a5b8dc4008f2e70db7f610`. Its overall result was **failure**:
the strict LPAC public-canary step exited 1. The shared Bend policy compilation,
native Windows build, mount-canary and native transport steps passed. The LPAC
run also reports its mounted reads and revocation passed, but the actual byte
worker's network, clipboard and COM observations were incomplete and receive
no restriction credit. Its phase-one Winsock errors were `10107` and the DLL
initialization stages failed; the network API probes after WFP removal again
reported `10107`. The complete original result lines are retained in `lpac.txt`.

The existing separate no-data diagnostic passed in both phases; it has a
different profile and is not evidence of byte-worker confinement. This workflow
did not build or run the newly added optional standalone initialization
diagnostic. No cause, protected-data host qualification or general Windows
confinement is established by this run.

`ci.json` records both jobs and their step results; `artifact-metadata.json`
identifies both uploaded artifacts. The twelve native evidence files retain
all artifact text, normalized to UTF-8, LF line endings and without trailing
whitespace; the original WinFsp installer log was UTF-16. The policy directory
retains the generated-policy source commit and checksum file; generated
JavaScript is not checked in. `artifact-raw-sha256.txt` records hashes of all
16 files in both original downloaded artifacts, including the generated
JavaScript. The downloaded policy files passed their original `SHA256SUMS` check.
Runner, binary and generated policy identities are recorded in the environment
and native-source files, with their precise source and scope.
