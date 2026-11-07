# Genode base-hw: automatic master CI

[Run 42378765762](https://github.com/Spaceghost/writ/actions/runs/42378765762)
passed at exact source `bfb805282a5beb390c923824bef52626303e6481`.
The guest reported 2,356 core checks, 69 mount-model checks and 24 allocator
checks, plus public File_system and VFS canaries. The core suite includes the
synthetic stage-graph checks; that does not implement stage admission or host
execution. Missing real-time-clock and QEMU feature warnings are retained.
Ordinary proof output requests `--verdict` for a separate mathematical check.

The source/build inventory has 244 tracked paths matching this commit; ten
runner-only generated or native outputs were unavailable for independent
rehashing. The original artifact ZIP hash matches GitHub metadata. See the
[index](../README.md) for the exact-text repack and normalized presentation
copies. This run does not establish protected-host confinement, durable
publication, staged execution or a GPU test.
