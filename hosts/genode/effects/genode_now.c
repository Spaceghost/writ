// Genode.now: C twin (bend guide effects, "The C side"). Calls only the
// shim, which reads the component's Timer session; the 64-bit millisecond
// reading is answered as a U32 word, as Base's IO.now truncates io_tick.

uint64_t writ_shim_now_ms(void);

Term genode_now_run(Env e, Term* f, IoWork* w) {
  return (Term)(u32)writ_shim_now_ms();
}

static void __attribute__((constructor)) genode_now_use(void) {
  io_eff(CID(Genode.now), genode_now_run);
}
