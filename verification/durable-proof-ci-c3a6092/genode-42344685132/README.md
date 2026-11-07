# Genode CI 42344685132

GitHub Actions reported success for exact source `c3a6092f5553f3e83fa1dd1107acefda62616349`. The retained environment identifies Genode 26.08, toolchain 25.05 and QEMU. The guest reported 24 native allocator checks, 2,481 native core checks, 69 native mount checks and the corpus acceptance sentinel. The File_system and libc VFS public-canary logs have their separate acceptance sentinels.

The guest reported `clock_gettime(): missing real-time clock`; the warnings remain in the logs. This is scoped emulated Genode and public-canary evidence, not protected-host qualification. The source-and-build hash list contains 228 tracked paths independently matched to the exact commit, plus 10 runner-only generated/binary paths unavailable for independent rehashing.

`archive-sha256.txt` records the original downloaded ZIP hash, matched against GitHub's artifact metadata. `artifact-raw-sha256.txt` records hashes of every original artifact file, and `workflow-log-raw-sha256.txt` records the raw workflow log hash. Retained text is normalized to UTF-8/LF with trailing whitespace removed; its bytes may differ from the original. Raw ZIPs and workflow logs are held separately outside this copy-ready directory. No durable publication acceptance or independent human security review is implied.
