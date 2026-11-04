// Genode.take: C twin (bend guide effects, "The C side"). The wait blocks,
// so it leaves the loop by io_work: genode_take_call runs on a runtime
// helper thread and touches only w (the guide's rule for a call); it blocks
// in the shim until a client's request has been queued, and the runtime's
// own completion pipe then wakes the loop, where genode_take_pack builds
// the Request on the Bend heap. Calls only the shim. The twin marshals
// words: it makes no decision and does not look at any field.
//
// w->data holds GENODE_TAKE_WORDS words: [0] channel id, [1] route
// subject, [2..17] the 16 record words in order (Channel.md).

#define GENODE_TAKE_WORDS 18

void writ_shim_take(uint32_t* record, uint32_t* channel, uint32_t* subject);

static void genode_take_call(IoWork* w) {
  uint32_t* v = (uint32_t*)w->data;
  writ_shim_take(v + 2, v + 0, v + 1);
}

// A Request{..} constructor of GENODE_TAKE_WORDS U32 fields, laid out as
// the compiler lays out a constructor node (fields at its location, in
// declaration order) and sealed field by field as io_node seals its two.
static Term genode_take_pack(Env e, IoWork* w) {
  uint32_t* v = (uint32_t*)w->data;
  u64 l = heap_alloc(e, cls_fit(GENODE_TAKE_WORDS));
  for (u32 i = 0; i < GENODE_TAKE_WORDS; i += 1) {
    e.mem[l + i] = io_seal(e, (Term)v[i], CID(Request));
  }
  free(w->data);
  return term_ctr(CID(Request), l);
}

Term genode_take_run(Env e, Term* f, IoWork* w) {
  w->data = io_mem(calloc(GENODE_TAKE_WORDS, sizeof(uint32_t)));
  return io_work(w, genode_take_call, genode_take_pack);
}

static void __attribute__((constructor)) genode_take_use(void) {
  io_eff(CID(Genode.take), genode_take_run);
}
