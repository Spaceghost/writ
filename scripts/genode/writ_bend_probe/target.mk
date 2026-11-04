#
# target.mk for writ_bend_probe - Genode build configuration, not Writ
# implementation. Genode channel lane, Task 1. Compiles the unmodified C
# that Bend 2.0.39 emits for hosts/genode/monitor/Probe.bend
# (bend hosts/genode/monitor/Probe.bend -o ../writ-genode/bend-c/probe/probe.c)
# against Genode's libc, links the shim (memory host layer plus the LOG and
# Timer functions the Genode.* effect twins call), and builds a Genode
# component. The effect twins under hosts/genode/effects/ are spliced into
# that C by the Bend compiler; nothing else is compiled for them. The
# generated file is read in place from outside this repository and is never
# edited or committed. The shared settings, each with the error it answers,
# are in scripts/genode/writ_bend.inc (live: $(REP_DIR)/src/app/writ_bend.inc).
#
TARGET = writ_bend_probe
WRIT_BEND_SRC = probe.c

# Directory holding the emitted C, outside the Genode repository.
WRIT_BEND_C_DIR ?= $(REP_DIR)/../bend-c/probe

include $(REP_DIR)/src/app/writ_bend.inc
