# Task 1 report: Unikraft pin and hello build

Status: DONE_WITH_CONCERNS
Commit: 2d52fb9 (branch lane/unikernel-library, not pushed)

## Delivered
- scripts/unikernel/Hello.bend (four-line IO.print("hi"); runtime-profile's Hello.bend absent on this branch)
- verification/unikernel-pins.txt: kraft 0.12.16 (b5dd63d) install commands + tarball/binary sha256;
  Unikraft core RELEASE-0.21.0 (7351f8b) + lib-musl 0.21.0 (5fed64e); secondary pin RELEASE-0.16.3
  (e453b74) + lib-musl 0.16.3 (fd1abc9) for linuxu; musl 1.2.3 tarball sha256; host gcc/ld/make/qemu.
- verification/unikernel-matrix-unikraft.md: per-target build command, link result, first error,
  run command and full output, verbatim Kraftfile/Makefile.uk, resolved Kconfig facts.

## Outcomes
- linuxu/x86_64 on 0.21.0: not available. linuxu was removed from Unikraft core after 0.16
  (absent 0.17.0 to 0.21.0). kraft stops: "Select exactly one target platform in the configuration!".
- linuxu/x86_64 on 0.16.3: unadjusted first error `stdatomic.h: No such file or directory`.
  With A1+A2 it links (64-bit static ELF). Needs a TTY on stdin (else CRIT "Failed to initialize
  terminal console", exit 1). Under a pty: banner, then "bend: reservation failed", then no exit
  (killed at 60 s). posix-mmap was silently dropped: it depends on LIBUKVMEM, unavailable on linuxu.
- qemu/x86_64 on 0.21.0: unadjusted first error `stdatomic.h: No such file or directory`;
  with A1 the next is in core `ukboot/boot.c:489 too many arguments to '*ctorfn'` (GCC 16 C23).
  With A1+A2 and the plan's four libraries: links, boots under TCG, prints
  "bend: the event loop failed to open", does not halt. Supplementary A3 (+posix-pipe,
  +posix-poll): boots, prints "hi", QEMU exits 0.

Adjustments (all in ../writ-unikernel/, none touch Bend output):
A1 include dir with only a symlink to GCC's stdatomic.h (Unikraft uses -nostdinc, musl lacks it);
A2 UK_CFLAGS=-std=gnu11; A3 add CONFIG_LIBPOSIX_PIPE/POLL.
CUDA/Metal includes were not pulled in.

## Concerns
- The linuxu evidence comes from an older core (0.16.3) than the primary pin; for 0.21.0 the
  linuxu row is "platform absent". Task 2 should decide whether a 0.21 `native` platform or the
  0.16.3 linuxu build serves as the process-execution debugging target.
- Two build adjustments were needed for any link (A1, A2); A2 means Unikraft 0.21.0 does not
  build with GCC 16 defaults. clang was not tried.
- Whether `-append` reached argv (LIBUKLIBPARAM unset) is unverified; main's exit status is not
  observable on QEMU here.
- The kraft .sig signature was not verified, only the release checksum file.
- verification/source-sha256.txt was not updated; it already omits recent docs on this branch
  (e.g. docs/UNIKERNELS.md), so it is not being maintained per commit in this lane.
- Bend Tests/PROOF not run: no library source changed.
- Time used: well within the two-hour box.

## Nothing generated in tree
git status clean after commit; builds, logs, sources, kraft state under ../writ-unikernel/
(logs at ../writ-unikernel/logs/).
