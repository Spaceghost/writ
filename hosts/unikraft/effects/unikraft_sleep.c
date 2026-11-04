// Unikraft.sleep: C twin (bend guide effects, "The C side"). Calls only the
// host layer, which blocks the calling thread on Unikraft's scheduler until
// the platform monotonic clock has advanced by at least the requested
// milliseconds, then answers Unit.
//
// The wait runs on the event loop's own thread, not by io_work: on this
// single-lane Unikraft configuration an io_work helper thread is a second
// thread of the init process that never ends, so when main returns the init
// process is still running and lib/posix-process/shutdown.c (no
// LIBPOSIX_PROCESS_SIGNAL) reports status 0x80 | SIGKILL, which the exit
// hook maps to QEMU 255 instead of 1 (verification/unikernel-effects-qemu.txt,
// run E2). The cost: the loop serves no other computation during the sleep.

void writ_uk_sleep_ms(uint32_t ms);

Term unikraft_sleep_run(Env e, Term* f, IoWork* w) {
  writ_uk_sleep_ms((uint32_t)f[0]);
  return term_pak(CID(Unit), 0);
}

static void __attribute__((constructor)) unikraft_sleep_use(void) {
  io_eff(CID(Unikraft.sleep), unikraft_sleep_run);
}
