// Unikraft.put: C twin (bend guide effects, "The C side"). Runs on the
// loop and does not park: it reads the Reply's 16 U32 fields in
// declaration order (ctr_take, as io_cbuf reads a String cell), hands the
// words to the host layer, and answers Unit. Calls only the host layer,
// which writes one result frame to the channel's serial port. The twin
// marshals words: it makes no decision and does not look at any field.

#define UNIKRAFT_PUT_WORDS 16

void writ_uk_put(const uint32_t* record);

Term unikraft_put_run(Env e, Term* f, IoWork* w) {
  Term     fb[UNIKRAFT_PUT_WORDS];
  uint32_t words[UNIKRAFT_PUT_WORDS];
  spare_free(e, cls_fit(UNIKRAFT_PUT_WORDS), ctr_take(e, f[0], UNIKRAFT_PUT_WORDS, fb));
  for (u32 i = 0; i < UNIKRAFT_PUT_WORDS; i += 1) {
    words[i] = (uint32_t)fb[i];
  }
  writ_uk_put(words);
  return term_pak(CID(Unit), 0);
}

static void __attribute__((constructor)) unikraft_put_use(void) {
  io_eff(CID(Unikraft.put), unikraft_put_run);
}
