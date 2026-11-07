# Genode base-hw: automatic master CI

[Run 42411873103](https://github.com/Spaceghost/writ/actions/runs/42411873103)
passed at exact source `b4e2e97e34cc702557ed9eca56c7b3a0a0e63a09`.
The guest reported 2,634 core checks, 69 mount-model checks and 24 allocator
checks, plus public File_system and VFS canaries. The core suite includes the
bounded synthetic legacy conversion; it does not implement authenticated
frontend migration, owner-cleanup repair or frontend authority. Missing
real-time-clock and QEMU feature warnings are retained. Ordinary proof output
requests `--verdict` for a separate mathematical check.

The source/build inventory has 254 tracked paths matching the exact source;
ten runner-only generated or native outputs were unavailable for independent
rehashing. The original artifact ZIP hash matches GitHub metadata. See the
[index](../README.md) for exact-text repack and normalized presentation
copies. This run does not establish protected-host confinement, durable
publication, authenticated frontend migration or a GPU test.
