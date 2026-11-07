# Genode base-hw: automatic master CI

[Run 42386142947](https://github.com/Spaceghost/writ/actions/runs/42386142947)
passed at exact source `ffa332ddc289b54d34908ee6799b925550e12750`.
The guest reported 2,448 core checks, 69 mount-model checks and 24 allocator
checks, plus public File_system and VFS canaries. The core suite includes the synthetic issuance-allocation checks; that does not authenticate issuers or establish durable recovery. Missing real-time-clock and QEMU feature warnings are retained.
Ordinary proof output requests `--verdict` for a separate mathematical check.

The source/build inventory has 247 tracked paths matching this commit; ten
runner-only generated or native outputs were unavailable for independent
rehashing. The original artifact ZIP hash matches GitHub metadata. See the
[index](../README.md) for the exact-text repack and normalized presentation
copies. This run does not establish protected-host confinement, durable
publication, staged execution or a GPU test.
