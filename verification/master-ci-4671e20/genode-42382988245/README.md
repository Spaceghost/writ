# Genode base-hw: automatic master CI

[Run 42382988245](https://github.com/Spaceghost/writ/actions/runs/42382988245)
passed at exact source `4671e205f0dc4f9e8ce8f1d85f6767497092e30f`.
The guest reported 2,413 core checks, 69 mount-model checks and 24 allocator
checks, plus public File_system and VFS canaries. The core suite includes the synthetic frontend-allocation checks; that does not authenticate callers or establish durable recovery. Missing real-time-clock and QEMU feature warnings are retained.
Ordinary proof output requests `--verdict` for a separate mathematical check.

The source/build inventory has 246 tracked paths matching this commit; ten
runner-only generated or native outputs were unavailable for independent
rehashing. The original artifact ZIP hash matches GitHub metadata. See the
[index](../README.md) for the exact-text repack and normalized presentation
copies. This run does not establish protected-host confinement, durable
publication, staged execution or a GPU test.
