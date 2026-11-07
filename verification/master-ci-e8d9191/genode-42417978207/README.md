# Genode base-hw: automatic master CI

[Run 42417978207](https://github.com/Spaceghost/writ/actions/runs/42417978207)
passed at exact source `e8d91912a9da49315f1c4ca49657889827f03216`.
The guest reported 2,698 core checks, 69 mount-model checks and 24 allocator
checks, plus public File_system and VFS canaries. The core suite includes
wide-word reserve arithmetic; it does not count original handles or implement
authenticated frontend cleanup, migration or authority. Missing real-time-clock
and QEMU TCG feature warnings are retained. Ordinary proof output requests
`--verdict` for a separate mathematical check.

The source/build inventory has 258 tracked paths matching the exact source;
ten runner-only generated or native outputs were unavailable for independent
rehashing. The original artifact ZIP hash matches GitHub metadata. See the
[index](../README.md) for exact-text repack and normalized presentation
copies. This run does not establish protected-host confinement, durable
publication, authenticated frontend migration or a GPU test.
