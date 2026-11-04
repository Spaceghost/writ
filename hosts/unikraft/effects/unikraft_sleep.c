// Unikraft.sleep: C twin (bend guide effects, "The C side"). Parks on the
// runtime's own timer, as Bend 2.0.39's IO.sleep (bend2/effs/sleep.c) does:
// io_wait_on(w, 0, 0, deadline, more) with no descriptor waits on time alone,
// so the event loop stays live and serves other computations, and no helper
// thread is created. The host layer supplies the clock: writ_uk_sleep_left
// reads ukplat_monotonic_clock at the start and on every wake, checks that it
// is ordered, and answers how long is still to wait; while that is not 0 the
// twin parks again, at most 16 times (host.c, WRIT_UK_SLEEP_ROUNDS).
//
// Not io_work: on this single-lane Unikraft configuration an io_work helper
// thread is a second thread of the init process that never ends, so when main
// returns lib/posix-process/shutdown.c reports 0x80 | SIGKILL and the exit
// hook maps it to QEMU 255 (verification/unikernel-effects-qemu.txt, R0-E1).
//
// w->data holds UNIKRAFT_SLEEP_WORDS words, allocated here and freed when
// the sleep ends: [0] start, [1] deadline (both ns on the host clock),
// [2] last reading, [3] parks so far. The park deadline is io_tick() plus
// the time left; io_tick reads the same clock (CLOCK_MONOTONIC, answered
// from ukplat_monotonic_clock by lib/posix-time).

#define UNIKRAFT_SLEEP_WORDS 4

uint64_t writ_uk_clock_ns(void);
uint64_t writ_uk_sleep_left(uint64_t start, uint64_t deadline, uint64_t* last,
  uint32_t round);

static Term unikraft_sleep_more(Env e, IoWork* w) {
  uint64_t* v    = (uint64_t*)w->data;
  uint64_t  left = writ_uk_sleep_left(v[0], v[1], &v[2], (uint32_t)v[3]);
  if (left == 0) {
    free(w->data);
    return term_pak(CID(Unit), 0);
  }
  v[3] += 1;
  return io_wait_on(w, 0, 0, io_tick() + left, unikraft_sleep_more);
}

Term unikraft_sleep_run(Env e, Term* f, IoWork* w) {
  uint64_t* v = io_mem(calloc(UNIKRAFT_SLEEP_WORDS, sizeof(uint64_t)));
  v[0]    = writ_uk_clock_ns();
  v[1]    = v[0] + (uint64_t)(u32)f[0] * 1000000ull;
  v[2]    = v[0];
  v[3]    = 0;
  w->data = (char*)v;
  return unikraft_sleep_more(e, w);
}

static void __attribute__((constructor)) unikraft_sleep_use(void) {
  io_eff(CID(Unikraft.sleep), unikraft_sleep_run);
}
