// Unikraft.log: C twin (bend guide effects, "The C side"). Spliced into the
// generated C after the runtime. Calls only the host layer; writ_uk_log
// writes the bytes to Unikraft's STDOUT console devices
// (hosts/unikraft/host.c, hosts/unikraft/INVENTORY.md). Runs on the loop:
// a console write does not park.

void writ_uk_log(const char* text, size_t len);

Term unikraft_log_run(Env e, Term* f, IoWork* w) {
  uint64_t n = 0;
  char* text = io_cstr(e, f[0], &n);
  writ_uk_log(text, (size_t)n);
  free(text);
  return term_pak(CID(Unit), 0);
}

static void __attribute__((constructor)) unikraft_log_use(void) {
  io_eff(CID(Unikraft.log), unikraft_log_run);
}
