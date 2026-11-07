# Genode base-hw: automatic master CI

[Run 42388574216](https://github.com/Spaceghost/writ/actions/runs/42388574216)
passed at exact source `70f05b25eb92581c2f95993151e20ad6b4d71509`.
The guest reported 2,472 core checks, 69 mount-model checks and 24 allocator
checks, plus public File_system and VFS canaries. The core suite includes the synthetic rendezvous-allocation checks; that does not authenticate providers or establish durable recovery. Missing real-time-clock and QEMU feature warnings are retained.
Ordinary proof output requests `--verdict` for a separate mathematical check.

The source/build inventory has 248 tracked paths matching this commit; ten
runner-only generated or native outputs were unavailable for independent
rehashing. The original artifact ZIP hash matches GitHub metadata. See the
[index](../README.md) for the exact-text repack and normalized presentation
copies. This run does not establish protected-host confinement, durable
publication, staged execution or a GPU test.
