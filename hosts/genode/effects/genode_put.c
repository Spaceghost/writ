// Genode.put: C twin (bend guide effects, "The C side"). Runs on the loop
// and does not block: it reads the Reply's 16 U32 fields in declaration
// order (ctr_take, as io_cbuf reads a String cell), hands the words to the
// shim, and answers Unit. Calls only the shim, which copies the words into
// the channel's result bucket and signals its client. The twin marshals
// words: it makes no decision and does not look at any field.

#define GENODE_PUT_WORDS 16

void writ_shim_put(uint32_t channel, const uint32_t* record);

Term genode_put_run(Env e, Term* f, IoWork* w) {
  Term     fb[GENODE_PUT_WORDS];
  uint32_t words[GENODE_PUT_WORDS];
  spare_free(e, cls_fit(GENODE_PUT_WORDS), ctr_take(e, f[1], GENODE_PUT_WORDS, fb));
  for (u32 i = 0; i < GENODE_PUT_WORDS; i += 1) {
    words[i] = (uint32_t)fb[i];
  }
  writ_shim_put((uint32_t)f[0], words);
  return term_pak(CID(Unit), 0);
}

static void __attribute__((constructor)) genode_put_use(void) {
  io_eff(CID(Genode.put), genode_put_run);
}
