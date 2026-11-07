# Windows Node model run 42327055068

[Run 42327055068](https://github.com/Spaceghost/writ/actions/runs/42327055068)
passed at exact source `817ab1fda43e9968276d9c7d2b4d23e1ce8215c4`.
On Windows Server 2025 with Node 22.23.4, the Bend-generated JavaScript
library suite reports 2,102 PASS lines and the separate WritFS model suite
reports 78; both exit 0. The library output through its completion sentinel,
normalized to LF without the appended Node status, has SHA-256
`44312c9e4c40b3c71422b9f02cf05dd3be5e46879f1ab31df9783f137fadfdf3`
and matches the author's local Bend and Node captures for these source inputs.
Generated library JavaScript SHA-256
`13a883a055543d4b796d6dbd08bb5bd0ae696477da0520e45efb751c3674a02e`
also matches the local generated file. The earlier `c0defe5` results are a
separate historical source and are not evidence for this revision.

This is native Windows Node executing generated policy/model JavaScript, not
native machine-code or protected-host qualification. The synthetic handoff
model does not establish Windows peer identity, OS controls or confinement.
`ci.json` and `artifact-metadata.json` identify jobs and artifacts;
`artifact-raw-sha256.txt` hashes all downloaded files, including generated
JavaScript, which is not checked in. Text captures are normalized to UTF-8,
LF line endings and without trailing whitespace; generated checksums were
verified against the downloaded files.
