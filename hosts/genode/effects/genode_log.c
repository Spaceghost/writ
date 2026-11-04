// Genode.log: C twin (bend guide effects, "The C side"). Spliced into the
// generated C after the runtime. Calls only the shim; the shim writes the
// bytes to the component's LOG session (hosts/genode/INVENTORY.md).

void writ_shim_log(const char* text, size_t len);

Term genode_log_run(Env e, Term* f, IoWork* w) {
  uint64_t n = 0;
  char* text = io_cstr(e, f[0], &n);
  writ_shim_log(text, (size_t)n);
  free(text);
  return term_pak(CID(Unit), 0);
}

static void __attribute__((constructor)) genode_log_use(void) {
  io_eff(CID(Genode.log), genode_log_run);
}
