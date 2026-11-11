# Task 1: complete the native corpus

Investigate run 43084126793 against the current source. Preserve its failed
output. Change only the diagnostic wall-clock bound and document why it needs
measurement. Dispatch the existing native Genode workflow on the isolated lane.
Require all 3072 core assertions, all 69 mount assertions, the 24 allocator
checks with sanitizer evidence, raw File_system probes, libc/VFS checks, and
zero live/reserved interpreter allocations at teardown. Record exceptions and
incomplete outcomes without weakening any acceptance or production limit.
