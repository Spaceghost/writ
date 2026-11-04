### Task 2: The Bend hello reaches `main`

Link the Task 1 translation unit into `writ_bend_hello` (target.mk; symbol interposition over libc's `mmap`/`mprotect`/`munmap`, or the libc's documented override mechanism if symbol order does not win; record which and why). Keep `-DMAP_NORESERVE=0` only if still needed and say so. Add the `vfs_pipe` mount and libc `pipe` attribute the event-loop row requires. Run under init at 256M. Expected: `hi` in the log and exit value 0. Record every error on the way with its fix. Evidence: `verification/genode-bend-hello-base-linux.txt` (append a dated section).

Acceptance: the unmodified generated hello C prints `hi` under init on base-linux with exit value 0, or a recorded stopping point with the exact symbol and reason.

