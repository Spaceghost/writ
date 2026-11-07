# Genode base-hw: automatic master CI

[Run 42376339875](https://github.com/Spaceghost/writ/actions/runs/42376339875)
passed at exact source `189f42be263689ec9b0846cc58f6895e87ca6371`.
The guest reported 2,318 core checks, 69 mount-model checks and 24 allocator
checks, plus public File_system and VFS canaries. Missing real-time-clock and
QEMU feature warnings are retained in the guest logs. Ordinary proof output
requests `--verdict` for a separate mathematical check.

The source/build inventory has 236 tracked paths matching this commit; ten
runner-only generated or native outputs were unavailable for independent
rehashing. The original artifact ZIP hash matches GitHub metadata. The
inventory includes `capture.c`, `capture.h` and `test-capture.py`, but the
standard workflow does not run the standalone capture controls. See the index
for the exact-text repack and normalized presentation copies. This run does
not establish protected-host confinement, durable publication, standalone
capture execution or a GPU test.
