#
# target.mk for writ_bend_overflow - Genode build configuration, not Writ
# implementation. Genode host-layer lane, Task 3. Compiles the unmodified C
# that Bend 2.0.39 emits for scripts/runtime-profile/Overflow.bend
# (bend scripts/runtime-profile/Overflow.bend -o ../writ-genode/bend-c/overflow/overflow.c) against Genode's libc,
# links the shim's memory unit, and builds a Genode component. The generated
# file is read in place from outside this repository and is never edited or
# committed. The shared settings, each with the error it answers, are in
# scripts/genode/writ_bend.inc (live: $(REP_DIR)/src/app/writ_bend.inc); only
# the target name and the location of the emitted C differ per program.
#
TARGET = writ_bend_overflow
WRIT_BEND_SRC = overflow.c

# Directory holding the emitted C, outside the Genode repository.
WRIT_BEND_C_DIR ?= $(REP_DIR)/../bend-c/overflow

include $(REP_DIR)/src/app/writ_bend.inc
