# Genode base-hw: automatic master CI

[Run 42374861495](https://github.com/Spaceghost/writ/actions/runs/42374861495)
passed at exact source `4a864b3840cfff3feb74d393778bf0b9665d2fa2`.
The guest reported 2,318 core checks, 69 mount-model checks and 24 allocator
checks, plus public File_system and VFS canaries. Missing real-time-clock and
QEMU feature warnings are retained in the guest logs. Ordinary proof output
requests `--verdict` for a separate mathematical check.

The source/build inventory has 233 tracked paths matching this commit; ten
runner-only generated or native outputs were unavailable for independent
rehashing. The original artifact ZIP hash matches GitHub metadata. Source
inventory mentions of the standalone synthetic pair checker do not show that it ran; the run
executes the regular policy and WritFS fixtures. See the index for the
exact-text repack and normalized presentation copies. This run does not
establish protected-host confinement, durable publication or a GPU test.
