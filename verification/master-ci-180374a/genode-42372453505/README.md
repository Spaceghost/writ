# Genode base-hw: automatic master CI

[Run 42372453505](https://github.com/Spaceghost/writ/actions/runs/42372453505)
passed at exact source `180374a66d802c6bb2cd388556b01d5a38d9ad55`.
The guest reported 2,318 core checks, 69 mount-model checks and 24 allocator
checks, plus public File_system and VFS canaries. Missing real-time-clock and
QEMU feature warnings are retained in the guest logs. Ordinary proof output
requests `--verdict` for a separate mathematical check.

The source/build inventory has 225 tracked paths matching this commit; ten
runner-only generated or native outputs were unavailable for independent
rehashing. The original artifact ZIP hash matches GitHub metadata. Source
inventory mentions of the standalone evidence writer do not show that it ran; the run
executes the regular policy and WritFS fixtures. See the index for the
exact-text repack and normalized presentation copies. This run does not
establish protected-host confinement, durable publication or a GPU test.
