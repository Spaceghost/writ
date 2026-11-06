# Windows Node policy run 42312512618

[Workflow run](https://github.com/Spaceghost/writ/actions/runs/42312512618)
executed exact source `61ab2a453915c4162e7ba726b9dfd6f1759f3410`. The
generated Bend library and WritFS model suites passed under native Windows
Server 2025 Node 22.23.4: 2,285 and 78 PASS lines respectively, with Node exit
0. This is not native filesystem, machine-code runtime, or protected-host
qualification.

The captured library JavaScript SHA-256 is
`3434a650b25f3c29f617538d3d4edeba783ca5587e621b974555d70980778297`, matching
the local integration-preview generated artifact. Generated JavaScript is
intentionally kept outside the repository. After normalizing line endings and
removing the CI-appended `Node exit status: 0` line, the library output matches
the local Bend capture byte-for-byte (SHA-256
`bac0e2b581c8f4ad7eae2812e34177cbe97f35ed3f87e2d352da119aaa19f67a`). The
text captures normalize carriage returns, terminal escapes and trailing whitespace; `artifact-raw-sha256.txt`
identifies the original downloaded files, including the generated JavaScript.
