# Genode composition and byte-test CI 42342414353

GitHub Actions reported success for source commit `58c7ffe048aa37aa38b8b8b6d21c6e5f2cb9db2e`. The retained environment identifies Genode 26.08, toolchain 25.05 and QEMU. The guest reported 24 native allocator checks, 2,261 native core checks, 69 native mount checks and the corpus acceptance sentinel. The file-system and libc VFS public-canary logs have their separate acceptance sentinels.

The guest reported `clock_gettime(): missing real-time clock`; the warnings remain in the logs. This is scoped emulated Genode and public-canary evidence, not full host qualification. The source-and-build hash list contains 192 tracked paths independently matched to the exact commit, plus 10 runner-only generated/binary paths whose contents were unavailable for independent rehashing.

`artifact-raw-sha256.txt` records SHA-256 hashes of all original downloaded files. Retained text is normalized to UTF-8/LF with trailing whitespace removed; its bytes may differ from raw downloads. No generated code or binaries are retained in this copy-ready set.
