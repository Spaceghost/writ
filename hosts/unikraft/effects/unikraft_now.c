// Unikraft.now: C twin (bend guide effects, "The C side"). Calls only the
// host layer, which reads ukplat_monotonic_clock; the 64-bit millisecond
// reading is answered as a U32 word, as Base's IO.now truncates io_tick.

uint64_t writ_uk_now_ms(void);

Term unikraft_now_run(Env e, Term* f, IoWork* w) {
  return (Term)(u32)writ_uk_now_ms();
}

static void __attribute__((constructor)) unikraft_now_use(void) {
  io_eff(CID(Unikraft.now), unikraft_now_run);
}
