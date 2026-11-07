# Genode planner preview CI 42335756177

GitHub Actions reported success for source commit `6985302b7bbbd6ffaf2afcd7790c42f3a564f4c0`. The retained environment identifies Genode 26.08, toolchain 25.05 and QEMU. The guest reported 24 native allocator checks, 2,223 native core checks, 69 native mount checks and the corpus acceptance sentinel. The file-system and libc VFS public-canary logs have their separate acceptance sentinels.

The guest reported `clock_gettime(): missing real-time clock`; the warnings remain in the logs. This is scoped emulated Genode and public-canary evidence, not full host qualification. The source-and-build hash list contains 191 tracked paths independently matched to the exact commit, plus 10 runner-only generated/binary paths whose contents were unavailable for independent rehashing.

`artifact-raw-sha256.txt` records SHA-256 hashes of all original downloaded files. Retained text is normalized to UTF-8/LF with trailing whitespace removed; its bytes may differ from raw downloads. No generated code or binaries are retained in this copy-ready set.
