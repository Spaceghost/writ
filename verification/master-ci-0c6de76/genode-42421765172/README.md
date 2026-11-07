# Genode base-hw: automatic master CI

[Run 42421765172](https://github.com/Spaceghost/writ/actions/runs/42421765172)
passed at exact source `0c6de7659d8f59f0a32edcd9802017d9277a8a38`.
The guest reported 2,809 core checks, 69 mount-model checks and 24 allocator
checks, plus public File_system and VFS canaries. The core suite includes the
bounded binding-snapshot comparison; it does not authenticate frontend cleanup,
migration or host authority. Missing real-time-clock and QEMU TCG feature
warnings are retained. Ordinary proof output requests `--verdict` for a
separate mathematical check.

The source/build inventory has 260 tracked paths matching the exact source;
ten runner-only generated or native outputs were unavailable for independent
rehashing. The original artifact ZIP hash matches GitHub metadata. See the
[index](../README.md) for exact-text repack and normalized presentation
copies. This run does not establish protected-host confinement, durable
publication, authenticated frontend migration or a GPU test.
