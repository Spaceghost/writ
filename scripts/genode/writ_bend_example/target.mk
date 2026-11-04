#
# target.mk for writ_bend_example - Genode build configuration, not Writ
# implementation. Genode host-layer lane, Task 3. Compiles the unmodified C
# that Bend 2.0.39 emits for Example.bend
# (bend Example.bend -o ../writ-genode/bend-c/example/example.c) against Genode's libc,
# links the shim's memory unit, and builds a Genode component. The generated
# file is read in place from outside this repository and is never edited or
# committed. The shared settings, each with the error it answers, are in
# scripts/genode/writ_bend.inc (live: $(REP_DIR)/src/app/writ_bend.inc); only
# the target name and the location of the emitted C differ per program.
#
TARGET = writ_bend_example
WRIT_BEND_SRC = example.c

# Directory holding the emitted C, outside the Genode repository.
WRIT_BEND_C_DIR ?= $(REP_DIR)/../bend-c/example

include $(REP_DIR)/src/app/writ_bend.inc
