// Unikraft.take: C twin (bend guide effects, "The C side"). Parks on the
// runtime's own timer between polls of the channel, as unikraft_sleep.c
// does: io_wait_on(w, 0, 0, deadline, more) with no descriptor waits on
// time alone, so the loop stays live and no helper thread is created
// (io_work's helper thread outlives main on this configuration,
// verification/unikernel-effects-qemu.txt R0-E1). COM2 offers no descriptor
// to park on: lib/posix-tty's serial file reads every STDIN console, not
// COM2, and drivers/ukconsole/ns16550 runs COM2 with interrupts off
// (hosts/unikraft/effects/Channel.md, "Transport"). On each wake
// writ_uk_take_poll reads what has arrived; when a whole request is in,
// unikraft_take_more builds the Request on the Bend heap. Calls only the
// host layer. The twin marshals words: it makes no decision and does not
// look at any field.
//
// Cost: the port holds one received byte at a time (its FIFOs stay off), so
// a wake collects about one byte. The twin parks 10 ms while nothing is
// arriving and 1 ms while a frame is partly in (host.c answers BUSY, for at
// most 100 empty polls in a row, then IDLE again): one
// request round trip measured 0.14 to 0.56 s under QEMU TCG, against 0.86 s
// with a fixed 10 ms park (verification/unikernel-channel-qemu.txt,
// "Fix round 1").
//
// w->data holds UNIKRAFT_TAKE_WORDS words: [0] route subject, [1..16] the
// 16 record words in order (Channel.md). Allocated here, freed when the
// Request is built.

#define UNIKRAFT_TAKE_WORDS   17
#define UNIKRAFT_TAKE_IDLE_MS 10
#define UNIKRAFT_TAKE_BUSY_MS 1

// Answers 0 (nothing received), 1 (a record in record/subject), or 2 (bytes
// arriving or a frame just refused or dropped).
uint32_t writ_uk_take_poll(uint32_t* record, uint32_t* subject);

// A Request{..} constructor of UNIKRAFT_TAKE_WORDS U32 fields, laid out as
// the compiler lays out a constructor node (fields at its location, in
// declaration order) and sealed field by field as io_node seals its two.
static Term unikraft_take_pack(Env e, uint32_t* v) {
  u64 l = heap_alloc(e, cls_fit(UNIKRAFT_TAKE_WORDS));
  for (u32 i = 0; i < UNIKRAFT_TAKE_WORDS; i += 1) {
    e.mem[l + i] = io_seal(e, (Term)v[i], CID(Request));
  }
  return term_ctr(CID(Request), l);
}

static Term unikraft_take_more(Env e, IoWork* w) {
  uint32_t* v  = (uint32_t*)w->data;
  uint32_t  rc = writ_uk_take_poll(v + 1, v + 0);
  if (rc == 1) {
    Term r = unikraft_take_pack(e, v);
    free(w->data);
    return r;
  }
  return io_wait_on(w, 0, 0, io_until(rc == 2 ? UNIKRAFT_TAKE_BUSY_MS : UNIKRAFT_TAKE_IDLE_MS),
    unikraft_take_more);
}

Term unikraft_take_run(Env e, Term* f, IoWork* w) {
  w->data = io_mem(calloc(UNIKRAFT_TAKE_WORDS, sizeof(uint32_t)));
  return unikraft_take_more(e, w);
}

static void __attribute__((constructor)) unikraft_take_use(void) {
  io_eff(CID(Unikraft.take), unikraft_take_run);
}
