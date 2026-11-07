# Genode base-hw: automatic master CI

[Run 42378254104](https://github.com/Spaceghost/writ/actions/runs/42378254104)
passed at exact source `89d0fcecd473cf6367cbbf883e11e51278c79817`.
The guest reported 2,318 core checks, 69 mount-model checks and 24 allocator
checks, plus public File_system and VFS canaries. Missing real-time-clock and
QEMU feature warnings are retained in the guest logs. Ordinary proof output
requests `--verdict` for a separate mathematical check.

The source/build inventory has 242 tracked paths matching this commit; ten
runner-only generated or native outputs were unavailable for independent
rehashing. The original artifact ZIP hash matches GitHub metadata. Source
inventory mentions of the standalone synthetic capture-to-Bend handoff do not
show that it ran; the run executes the regular policy and WritFS fixtures. See
the index for the exact-text repack and normalized presentation copies. This run
does not establish protected-host confinement, durable publication or a GPU test.
