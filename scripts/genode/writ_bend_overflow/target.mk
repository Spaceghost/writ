#
# target.mk for writ_bend_overflow - Genode build configuration, not Writ
# implementation. Genode host-layer lane, Task 3. Compiles the unmodified C
# that Bend 2.0.39 emits for scripts/runtime-profile/Overflow.bend
# (bend scripts/runtime-profile/Overflow.bend -o ../writ-genode/bend-c/overflow/overflow.c) against Genode's libc,
# links the shim's memory unit, and builds a Genode component. The generated
# file is read in place from outside this repository and is never edited or
# committed.
#
# Every setting below is the writ_bend_hello pattern, unchanged; each one is
# explained, with the error it answers, in
# scripts/genode/writ_bend_hello/target.mk and recorded in
# verification/genode-bend-hello-base-linux.txt (E1-E4, H1, H3). Only the
# target name and the location of the emitted C differ.
#
TARGET = writ_bend_overflow
SRC_C  = overflow.c

# The shim (hosts/genode/shim/writ_mem.cc, copied byte-identically to
# $(REP_DIR)/src/writ_shim/) supplies Libc::Component::construct and the
# mmap, munmap, and mprotect definitions the generated C binds to; posix is
# not linked.
SRC_CC = writ_mem.cc
LIBS   = base libc
vpath writ_mem.cc $(REP_DIR)/src/writ_shim

# Directory holding the emitted C, outside the Genode repository.
WRIT_BEND_OVERFLOW_C_DIR ?= $(REP_DIR)/../bend-c/overflow
vpath overflow.c $(WRIT_BEND_OVERFLOW_C_DIR)

CC_CXX_WARN_STRICT =

# E1: the generated C needs clang (musttail, preserve_none/preserve_most).
CUSTOM_CC = clang-23 --target=x86_64-unknown-elf

# E2/H3: FreeBSD 12.0's <sys/mman.h> lacks the name; value 0 is that libc's
# meaning, and the shim never depends on the flag.
CC_DEF += -DMAP_NORESERVE=0

# E3: clang's own freestanding headers (stdatomic.h) for the clang compile.
LIBGCC_INC_DIR = $(shell clang-23 -print-resource-dir)/include

# Keep the Genode tool chain's libgcc for the link.
LD_LIBGCC = $(shell $(CROSS_DEV_PREFIX)gcc $(CC_MARCH) -print-libgcc-file-name)

# E4: small code model, so clang emits section names genode.ld places.
CC_MARCH = -m64 -march=x86-64-v2
