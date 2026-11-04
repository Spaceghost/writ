### Task 1: A harness-visible exit code

Today every outcome (success, `IO.die`, fault) ends with QEMU status 0 under `-no-reboot`. Make the three distinguishable.

1. Add the QEMU `isa-debug-exit` device to the harness (`-device isa-debug-exit,iobase=0xf4,iosize=0x04`); QEMU then exits with `(value << 1) | 1` when the guest writes `value` to port 0xf4.
2. Write a termination hook in C under `hosts/unikraft/` and link it into the app via `Makefile.uk`: on Unikraft's termination path (use its `uk_term`/termtab or `ukplat_terminate` hook mechanism in 0.21.0; read `lib/ukboot` and `plat/` to find the supported hook and cite the file) write the process exit status to port 0xf4 so that status 0 becomes QEMU exit 1 and status 1 becomes QEMU exit 3. If the termination hook cannot observe the exit status, write a fixed "terminated" value and record that limit.
3. Crash path: find whether Unikraft 0.21.0's crash handler (`uk_crash`, `CONFIG_LIBUKDEBUG_*`) can call a hook or be configured to halt rather than reset; if a hook exists, write a distinct value (for example 0x7e) on crash; if not, record the limit and rely on Task 2's observation.
4. Rebuild the hello image with the hook, run it under the harness, and record QEMU exit codes for: hello (success), a program that calls `IO.die(Unit, 1, ...)`, and `Overflow.bend` (fault). Evidence: `verification/unikernel-exit-codes.txt`.

Acceptance: three distinct QEMU exit codes for success, die, and fault, or a recorded limit for whichever path cannot be distinguished, with the hook's source inventoried.

