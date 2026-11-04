#
# writ_bend.inc - shared Genode build settings for every Bend component
# (build configuration, not Writ implementation). Genode host-layer lane,
# Task 3. Included by scripts/genode/writ_bend_<name>/target.mk, which set
# TARGET, WRIT_BEND_SRC (the emitted C file name), and WRIT_BEND_C_DIR (the
# directory holding it, outside the Genode repository) before the include.
# Live copy: ../writ-genode/writ-repo/src/app/writ_bend.inc (byte-identical).
# Every setting is recorded with the error it answers in
# verification/genode-bend-hello-base-linux.txt (E1-E4, H1, H3), and listed
# in hosts/genode/INVENTORY.md ("Build settings carried by every Bend
# component").
#
SRC_C = $(WRIT_BEND_SRC)
vpath $(WRIT_BEND_SRC) $(WRIT_BEND_C_DIR)

# Genode host-layer lane, Task 2: the shim's memory unit writ_mem.cc
# (hosts/genode/shim/, copied byte-identically to $(REP_DIR)/src/writ_shim/)
# is linked into the component. It supplies Libc::Component::construct, which
# calls main(argc, argv, envp) as posix's construct.cc does, so posix is no
# longer linked (its construct would be a duplicate definition). Its mmap,
# munmap, and mprotect definitions in the program binary are what the
# generated C's calls bind to; see verification/genode-bend-hello-base-linux.txt.
SRC_CC = writ_mem.cc
LIBS   = base libc
vpath writ_mem.cc $(REP_DIR)/src/writ_shim

# The errors below were met building the hello; line numbers refer to its
# hello.c. The same settings apply to every generated unit.
CC_CXX_WARN_STRICT =

# Error 1 (compile): hello.c:124 'expected identifier or ( before return' at
# WL_JMP/WL_DYN, which expand to '__attribute__((musttail)) return ...'.
# The statement attribute musttail first appeared in GCC 15; Genode 26.08's
# prescribed tool chain is GCC 14.2.0. The generated C is written for clang
# (it also uses '#pragma clang' and preserve_none/preserve_most), so this one
# translation unit is compiled by the host clang-23 (23.1.1, /usr/bin/clang-23)
# for a bare x86_64 ELF target, which, like genode-x86-gcc, predefines
# neither __linux__ nor __unix__. Linking still uses the Genode tool chain (LD_CMD is $(CXX)).
CUSTOM_CC = clang-23 --target=x86_64-unknown-elf

# Error 2 (compile): hello.c:1656 'MAP_NORESERVE undeclared'. Genode's libc
# is FreeBSD 12.0's, whose <sys/mman.h> retired the flag (bit 0x0040 is now
# MAP_RESERVED0040, "previously unimplemented MAP_NORESERVE"). On that libc an
# anonymous mapping is not reserved against swap anyway, so the flag value 0
# keeps the FreeBSD meaning; whether Genode's mmap then backs the span with
# RAM is a runtime question for Task 3.
# Host-layer lane, Task 2: still required. Without it hello.c:1656 fails to
# compile again ('use of undeclared identifier MAP_NORESERVE'): the shim
# supplies reserve-now, charge-on-touch semantics for every qualifying
# mapping whatever its flags, but it cannot supply a name the libc headers
# lack. The value 0 means the shim never sees the flag; nothing depends on it.
CC_DEF += -DMAP_NORESERVE=0

# Error 3 (compile, after the clang switch): hello.c:470 and on, 'address
# argument to atomic operation must be a pointer to a trivially-copyable
# type ('_Atomic(u32) *' invalid)'. The build system puts GCC 14.2.0's
# internal include directory (LIBGCC_INC_DIR) on the path, and GCC's
# <stdatomic.h> implements atomic_load_explicit with GCC-only builtins on
# non-atomic temporaries. A clang compile needs clang's own freestanding
# headers (stdatomic.h, stddef.h, stdarg.h, float.h, ...), so the compiler
# header directory follows the compiler. Genode's libc headers still come
# first on the include path. The setting is target-wide (global.mk expands
# ALL_INC_DIR immediately), so it is also on writ_mem.cc's path; the shim's
# dependency file lists no header from it (it includes only Genode and
# libc headers), so g++ compiles the shim with the same headers as before.
LIBGCC_INC_DIR = $(shell clang-23 -print-resource-dir)/include

# Preventive, no triggering error: prg.mk finds libgcc through $(CC), which
# would now ask clang. Keep the Genode tool chain's libgcc so the clang
# switch stays confined to compiling the generated C.
LD_LIBGCC = $(shell $(CROSS_DEV_PREFIX)gcc $(CC_MARCH) -print-libgcc-file-name)

# Error 4 (load, first run): ld.lib.so logged '_reserve_local: lx_mmap
# failed', 'failed to locally attach linker area', 'failed to allocate
# region within linker area', then the component segfaulted. Cause: Genode
# compiles x86_64 code with -mcmodel=large (repos/base/mk/spec/x86_64.mk).
# Under that model clang places code and data in .ltext.*, .ldata, .lbss,
# and .lrodata.*, which Genode's linker script (repos/base/src/ld/genode.ld)
# does not name, so the orphan sections were linked at address 0 instead of
# the program base 0x1000000 and the binary's first LOAD segment covered the
# low address range. GCC under the large model keeps the ordinary section
# names, which is why the Genode tool chain never meets this. The program
# image is a few hundred KiB at 0x1000000, so this translation unit uses
# the default small code model; calls into the shared libc go through the
# PLT (R_X86_64_JUMP_SLOT) and data such as __stderrp through the GOT
# (R_X86_64_GLOB_DAT), both of which Genode's x86_64 ld.lib.so implements.
# CC_MARCH is target-wide, so the shim (g++ 14.2.0) is also compiled with the
# small model; GCC emits ordinary section names under either model.
CC_MARCH = -m64 -march=x86-64-v2
