# Genode base-hw: automatic master CI

[Run 42409457706](https://github.com/Spaceghost/writ/actions/runs/42409457706)
passed at exact source `d71d09cd4079e94147121be24934f6699bbff790`.
The guest reported 2,508 core checks, 69 mount-model checks and 24 allocator
checks, plus public File_system and VFS canaries. The core suite includes the
standalone descriptive frontend revision primitive; it does not implement
authenticated migration, owner-cleanup repair or frontend authority. Missing
real-time-clock and QEMU feature warnings are retained. Ordinary proof output
requests `--verdict` for a separate mathematical check.

The source/build inventory has 252 tracked paths matching the exact source;
ten runner-only generated or native outputs were unavailable for independent
rehashing. The original artifact ZIP hash matches GitHub metadata. See the
[index](../README.md) for the exact-text repack and normalized presentation
copies. This run does not establish protected-host confinement, durable
publication, authenticated frontend migration or a GPU test.
