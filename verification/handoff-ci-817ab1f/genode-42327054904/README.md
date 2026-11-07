# Genode QEMU run 42327054904

[Run 42327054904](https://github.com/Spaceghost/writ/actions/runs/42327054904)
passed at exact source `817ab1fda43e9968276d9c7d2b4d23e1ce8215c4`.
The Genode 26.08 base-hw QEMU guest reports 2,102 core and 69 mount model
assertions, 24 allocator invariants, and scoped native public File_system and
libc/VFS canaries. It retains the guest warning about the missing real-time
clock. This is not physical GPU, protected-host or Windows confinement
qualification; the earlier `c0defe5` runs apply to a different source.

The source/build record has 187 relative tracked source hashes matching commit
`817ab1f`; ten generated or otherwise uncomparable paths were not verified
against Git. `ci.json` and `artifact-metadata.json` preserve run identity and
`artifact-raw-sha256.txt` identifies all 13 original artifact files. Text files
retain all observed lines, normalized to UTF-8, LF line endings and without
trailing whitespace; terminal color escapes in guest output are retained.
