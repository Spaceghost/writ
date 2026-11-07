# Genode base-hw: automatic master CI

[Run 42367933299](https://github.com/Spaceghost/writ/actions/runs/42367933299)
passed at exact source `3267dc419e1a7a65888a13d595a44dabfdb03a14`. The guest reported
2,318 core checks, 69 mount-model checks and 24 allocator checks, plus public
File_system and VFS canaries. Missing real-time-clock and QEMU feature warnings
are retained in the logs. Ordinary proof output requests `--verdict` for a
separate mathematical check.

The source/build inventory has 211 tracked paths matching this commit; ten
runner-only generated or native outputs were unavailable for independent
rehashing. The original artifact ZIP hash matches GitHub metadata. The standard
run logs show policy and WritFS fixtures; they do not show the standalone layout checker
executing. Source-inventory names alone do not establish execution. See the
index for the exact-text repack and normalized presentation copies. This run
does not establish protected-host confinement, durable publication or a GPU
test.
