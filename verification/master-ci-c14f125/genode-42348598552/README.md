# Genode base-hw, automatic master CI

[Run 42348598552](https://github.com/Spaceghost/writ/actions/runs/42348598552)
succeeded at exact source `c14f125454e279011589b9527069161241419171`. The
Genode base-hw QEMU guest reported 2,261 core, 69 mount and 24 allocator checks,
plus public File_system and libc VFS canaries. The host allocator sanitizer
probe reported 24 invariants. The guest `clock_gettime(): missing real-time
clock` warnings remain in the logs. The Bend proof check was ordinary, without
an independent Lean verdict. This scoped emulation evidence does not qualify
a protected host or demonstrate nested-init routing.

The source/build list's 197 tracked paths match the exact source; 10 runner-only
generated/binary paths were unavailable for independent rehashing. All 13 raw
artifact-file hashes were checked against the download. The original ZIP hash
matches GitHub's artifact digest. Text copies are normalized for line endings
and trailing whitespace; raw artifact and workflow-log hashes remain separate.
The original ZIP and workflow log remain in temporary external storage, and no
generated code or binary is checked into the source tree.
