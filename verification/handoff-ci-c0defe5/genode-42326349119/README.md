# Historical Genode QEMU run 42326349119

[Run 42326349119](https://github.com/Spaceghost/writ/actions/runs/42326349119)
passed at exact historical source `c0defe5879660a3ddf294505e1a318fa37709517`.
The Genode 26.08 base-hw QEMU guest reports 2,102 core and 69 mount model
assertions, 24 allocator invariants, and scoped native public File_system and
libc/VFS canaries. It retains the guest warning about the missing real-time
clock. This result does not test the later revised model and establishes no
physical GPU, protected-host or Windows confinement qualification.

The source/build record has 187 relative tracked source hashes matching commit
`c0defe5`; ten generated or otherwise uncomparable paths were not verified
against Git. `ci.json` and `artifact-metadata.json` preserve run identity and
`artifact-raw-sha256.txt` identifies all 13 original artifact files. Text files
retain all observed lines, normalized to UTF-8, LF line endings and without
trailing whitespace; terminal color escapes in guest output are retained.
