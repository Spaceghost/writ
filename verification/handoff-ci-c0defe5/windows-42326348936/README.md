# Historical Windows Node model run 42326348936

[Run 42326348936](https://github.com/Spaceghost/writ/actions/runs/42326348936)
passed at exact historical source `c0defe5879660a3ddf294505e1a318fa37709517`.
It does not test the later revised model.
On Windows Server 2025 with Node 22.23.4, the Bend-generated JavaScript
library suite reports 2,102 PASS lines and the separate WritFS model suite
reports 78; both exit 0. The library output through its completion sentinel,
normalized to LF without the appended Node status, has SHA-256
`0fb92a34387ff14ea30bb97bb09fc8a79585b058a6057c6acdd54692f6dcf45c`
and matches the author's local Bend and Node captures for those source inputs.
The generated library JavaScript SHA-256 is
`e335c368395d0c7445e99b2280a52a7da04fa00ac71ba9e750540c6b11281255`.

This is native Windows Node executing generated policy/model JavaScript, not
native machine-code or protected-host qualification. The synthetic handoff
model does not establish Windows peer identity, OS controls or confinement.
`ci.json` and `artifact-metadata.json` identify jobs and artifacts;
`artifact-raw-sha256.txt` hashes all downloaded files, including generated
JavaScript, which is not checked in. Text captures are normalized to UTF-8,
LF line endings and without trailing whitespace; generated checksums were
verified against the downloaded files.
