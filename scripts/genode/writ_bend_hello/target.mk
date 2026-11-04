#
# target.mk for writ_bend_hello - Genode build configuration, not Writ
# implementation. Compiles the unmodified C that Bend 2.0.39 emits for
# scripts/genode/Hello.bend (bend scripts/genode/Hello.bend -o
# ../writ-genode/hello/hello.c) against Genode's libc and links it as a
# Genode component (Genode component lane, Task 2). The generated file is
# read in place from outside this repository and is never edited or
# committed; every flag below is recorded with the error it answers in
# verification/genode-bend-hello-base-linux.txt.
#
TARGET = writ_bend_hello
SRC_C  = hello.c

# posix supplies the libc component entry that calls main(argc, argv) and
# pulls in libc itself.
LIBS   = posix

# Directory holding the emitted C, outside the Genode repository.
WRIT_BEND_HELLO_C_DIR ?= $(REP_DIR)/../hello
vpath hello.c $(WRIT_BEND_HELLO_C_DIR)

CC_CXX_WARN_STRICT =

# Error 1 (compile): hello.c:124 'expected identifier or ( before return' at
# WL_JMP/WL_DYN, which expand to '__attribute__((musttail)) return ...'.
# The statement attribute musttail first appeared in GCC 15; Genode 26.08's
# prescribed tool chain is GCC 14.2.0. The generated C is written for clang
# (it also uses '#pragma clang' and preserve_none/preserve_most), so this one
# translation unit is compiled by the host clang for a bare x86_64 ELF
# target, which, like genode-x86-gcc, predefines neither __linux__ nor
# __unix__. Linking still uses the Genode tool chain (LD_CMD is $(CXX)).
CUSTOM_CC = clang --target=x86_64-unknown-elf

# Error 2 (compile): hello.c:1656 'MAP_NORESERVE undeclared'. Genode's libc
# is FreeBSD 12.0's, whose <sys/mman.h> retired the flag (bit 0x0040 is now
# MAP_RESERVED0040, "previously unimplemented MAP_NORESERVE"). On that libc an
# anonymous mapping is not reserved against swap anyway, so the flag value 0
# keeps the FreeBSD meaning; whether Genode's mmap then backs the span with
# RAM is a runtime question for Task 3.
CC_DEF += -DMAP_NORESERVE=0

# Error 3 (compile, after the clang switch): hello.c:470 and on, 'address
# argument to atomic operation must be a pointer to a trivially-copyable
# type ('_Atomic(u32) *' invalid)'. The build system puts GCC 14.2.0's
# internal include directory (LIBGCC_INC_DIR) on the path, and GCC's
# <stdatomic.h> implements atomic_load_explicit with GCC-only builtins on
# non-atomic temporaries. A clang compile needs clang's own freestanding
# headers (stdatomic.h, stddef.h, stdarg.h, float.h, ...), so the compiler
# header directory follows the compiler. Genode's libc headers still come
# first on the include path.
LIBGCC_INC_DIR = $(shell clang -print-resource-dir)/include

# Programs link libgcc found through $(CC); keep that the Genode tool
# chain's libgcc so the clang switch stays confined to compiling hello.c.
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
CC_MARCH = -m64 -march=x86-64-v2
