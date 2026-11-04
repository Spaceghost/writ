// Genode.sleep: C twin (bend guide effects, "The C side"). The wait blocks,
// so it leaves the loop by io_work: genode_sleep_call runs on a runtime
// helper thread and touches only w (the guide's rule for a call), then
// genode_sleep_pack answers Unit on the loop. Calls only the shim, which
// sleeps on the component's Timer session until at least w->word
// milliseconds have passed on its clock.

void writ_shim_sleep_ms(uint32_t ms);

static void genode_sleep_call(IoWork* w) {
  writ_shim_sleep_ms(w->word);
}

static Term genode_sleep_pack(Env e, IoWork* w) {
  return term_pak(CID(Unit), 0);
}

Term genode_sleep_run(Env e, Term* f, IoWork* w) {
  w->word = (u32)f[0];
  return io_work(w, genode_sleep_call, genode_sleep_pack);
}

static void __attribute__((constructor)) genode_sleep_use(void) {
  io_eff(CID(Genode.sleep), genode_sleep_run);
}
