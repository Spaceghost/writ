# Native filesystem run 42328550443

[Run 42328550443](https://github.com/Spaceghost/writ/actions/runs/42328550443)
passed both Btrfs and ZFS jobs at exact source
`1ce67579924e81ebc5d8e51f78c546d5927e4959`. On the recorded Ubuntu 24.04
runner, isolated native fixtures report 11 Btrfs and 18 ZFS PASS lines,
respectively, and checked fixture cleanup exits 0. The logs retain the native
snapshot/clone behavior and their public fixture scope. These filesystem checks
do not qualify a protected worker or the synthetic handoff as a Windows host.

`ci.json` and `artifact-metadata.json` identify both jobs and artifacts;
`artifact-raw-sha256.txt` records all ten original artifact-file hashes.
Text is normalized to UTF-8, LF line endings and without trailing whitespace.
