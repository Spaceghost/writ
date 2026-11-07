# Genode base-hw: automatic master CI

[Run 42414768625](https://github.com/Spaceghost/writ/actions/runs/42414768625)
passed at exact source `fafbbe2bed9fecd30d92f98cd0be1e8dcef90dd0`.
The guest reported 2,673 core checks, 69 mount-model checks and 24 allocator
checks, plus public File_system and VFS canaries. The core suite includes the
bounded synthetic cleanup-reserve reference; it does not implement
authenticated frontend cleanup, migration or authority. Missing real-time-clock
and QEMU feature warnings are retained. Ordinary proof output requests
`--verdict` for a separate mathematical check.

The source/build inventory has 256 tracked paths matching the exact source;
ten runner-only generated or native outputs were unavailable for independent
rehashing. The original artifact ZIP hash matches GitHub metadata. See the
[index](../README.md) for exact-text repack and normalized presentation
copies. This run does not establish protected-host confinement, durable
publication, authenticated frontend migration or a GPU test.
