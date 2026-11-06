# Windows native evidence-only rerun 42311706534

[Workflow run](https://github.com/Spaceghost/writ/actions/runs/42311706534)
tested source `1fcd29a4cddea3c67a0c71d26f8130e3e6babf59` and **failed** the
strict LPAC public-canary gate. It was automatically triggered by retaining
[the previous failed run](../../contrib/native-hosts/windows/verification/run-42311207831/README.md);
its native implementation inputs were unchanged. Mounted reads and revocation
passed, while the actual byte worker again reported WSAStartup 10107 and
clipboard/COM initialization failures. Those observations remain incomplete
and receive no confinement credit. The separate no-data diagnostic passed but
is not a substitute for the byte worker. No root cause or protected-host
qualification is established.

Selected text captures normalize carriage returns and trailing whitespace.
`artifact-raw-sha256.txt` identifies every originally downloaded artifact file;
the complete original CI artifact was retained by GitHub at the run link.
