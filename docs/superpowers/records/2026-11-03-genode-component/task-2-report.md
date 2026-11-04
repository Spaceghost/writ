# Task 2 report: Bend generated C as a Genode component (base-linux)

Status: DONE_WITH_CONCERNS
Branch: lane/genode-component (not pushed)
Commit: 0e63ea3 Build Bend's generated hello C as a Genode component on base-linux
Wall clock: about 20 minutes (20:28 to 20:48 -06:00).

## Outcome
The unmodified hello.c (3074 lines; sha256 260b70a3...56cf) that Bend 2.0.39
emits for scripts/genode/Hello.bend compiles, links, and loads as the Genode
component writ_bend_hello against Genode 26.08's libc on base-linux. It does
not print "hi". The first blocking error depends on the RAM quota:
- ram 256M (the committed default): `[init] child "writ_bend_hello" requests
  resources: ram_quota=8589950976`, then nothing; the run times out (exit 254).
  The runtime's fixed 8 GiB term-heap mmap goes to Genode libc, which commits
  and bzero()s anonymous memory and ignores the address hint. It blocks on the
  parent's resource request and never returns MAP_FAILED.
- ram 11G (probe, WRIT_BEND_HELLO_RAM=11G): it gets past the heap and then logs
  `Warning: mprotect: mprotect not implemented` / `bend: stack guard failed`,
  and exits with value 1. Genode libc's mprotect is a weak dummy returning -1
  (dummies.cc:126), so pool_stack cannot make its guard page.

Stop point: mprotect. The only flag-level way past it is a -D macro that turns
mprotect into a no-op. That would drop the stack-overflow guard page, which
amounts to editing the evaluator's behavior through the preprocessor, so I
did not do it. The controller needs this: Task 3's fault row cannot run on
stock Genode libc unless a substitute is built or libc's mprotect is fixed.

## Build-configuration changes (each recorded with its error in the evidence file)
- P1: enabled repos/libports in build.conf; added writ_bend_hello to the
  local-expect run rule. P2: `prepare_port libc`. This needed rpcgen, which
  the host lacked and I got from nixpkgs rpcsvc-proto 1.4.4. The port tool
  verified the FreeBSD 12.0 src.txz SHA256.
- E1: `__attribute__((musttail)) return` is rejected by Genode's GCC 14.2.0
  (support starts in GCC 15). Fix: CUSTOM_CC = host clang 23.1.1
  --target=x86_64-unknown-elf, for this TU only. The link still uses
  genode-x86-g++.
- E2: MAP_NORESERVE is undeclared because FreeBSD 12 libc retired it.
  Fix: -DMAP_NORESERVE=0, which matches that libc's ABI meaning.
- E3: GCC's stdatomic.h breaks under clang. Fix: LIBGCC_INC_DIR points at
  clang's resource includes, and LD_LIBGCC is pinned to the Genode
  toolchain's libgcc.
- E4: at load, ld.lib.so fails with "failed to locally attach linker area"
  and the component segfaults. Cause: under Genode's -mcmodel=large, clang
  emits .ltext/.ldata/.lbss sections that genode.ld does not place, so they
  were linked at address 0. Fix: CC_MARCH = -m64 -march=x86-64-v2 (small
  model) for this TU.
- All 47 undefined symbols are exported by the libc/posix/libm/ld ABI lists.
  mprotect is one of them, but it is exported only as a dummy.

## Files
- scripts/genode/Hello.bend (new, four-line program)
- scripts/genode/writ_bend_hello/{target.mk,writ_bend_hello.run}: byte-identical
  to ../writ-genode/writ-repo copies, with header comments
- scripts/genode/writ_hello/build.conf.fragment: updated to match live build.conf
- verification/genode-bend-hello-base-linux.txt: commands, verbatim logs of runs
  1-4, error analyses, compile command, symbol check, limits
- verification/genode-pins.txt: rpcgen, clang, libc port added
Nothing generated is committed (hello.c, binaries, contrib, and build dir all
stay in ../writ-genode/).

## Concerns
1. Blocking: Genode libc mprotect is a dummy, so the guard page fails (see above).
2. Memory: the 8 GiB heap is fixed in the generated C for --gpu off, and
   Genode libc commits and zeroes it. That needs >8 GiB of quota per
   component, and on base-linux it touched about 10 GiB of host tmpfs
   during the probe (released at exit).
3. The object code comes from host clang 23.1.1, which Genode does not
   prescribe, built with a non-default code model. The Genode tool chain
   alone cannot compile Bend's output. This needs a decision: pin clang, or
   wait for a GCC 15+ Genode tool chain.
4. Genode-on-Linux evidence only. tasks.md and docs/GENODE.md are untouched
   because Task 2 maps to no checkbox. source-sha256.txt is still stale (as in
   Task 1).

## Fix report (review of 0e63ea3), commit aac16c4
1. Important: writ_bend_hello.run now checks `exited with exit value 0` with an
   explicit regexp, placed after run_genode_until and before grep_output. The
   header now describes what is checked: wait for an exit with any value,
   require 0, require the single `hi` line, and treat a timeout as failure.
   The live copy in ../writ-genode/writ-repo/run/ is identical. I checked the
   regexp in tclsh (it matches value 0 and rejects value 1), and `info
   complete` accepts the whole script.
2. target.mk now invokes clang-23 for CUSTOM_CC and for -print-resource-dir.
   I rebuilt hello.o; the binary sha256 is unchanged (e5f62ed0...a427).
3. The LD_LIBGCC override is now commented as preventive: no error triggered it.
4. Evidence: runs are numbered 1-5 in the order made, run 1 has its own
   entry, and the run-script revisions are listed. The host-memory figure is
   now an observation, quoting the `free -g` before/after numbers and the
   /tmp/genode-1000 listing; the "released at exit" claim is withdrawn as
   not observed. The -mlarge-data-threshold probe command and its output
   are recorded. The header time range now reads 20:28 to 20:53.
5. Removed the qemu_args line (base-linux starts no QEMU).
Re-run: Run 5 (256M, 20:48:37 to 20:52:52) gave the same resource-request
block, ram_quota=8589950976, timed out, exit 254. The new exit-value check is
not reached on the timeout path, so it was not exercised in a live run. A
comment-only reflow of the run script header came after run 5.
