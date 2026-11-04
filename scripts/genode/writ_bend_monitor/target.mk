#
# target.mk for writ_bend_monitor - Genode build configuration, not Writ
# implementation. Genode channel lane, Task 2. Compiles the unmodified C
# that Bend 2.0.39 emits for hosts/genode/monitor/Monitor.bend
# (bend hosts/genode/monitor/Monitor.bend -o ../writ-genode/bend-c/monitor/monitor.c)
# against Genode's libc, links the shim (memory host layer, the LOG and
# Timer functions, and the Writ channel service the Genode.take/put twins
# call), and builds a Genode component. The effect twins under
# hosts/genode/effects/ are spliced into that C by the Bend compiler. The
# shim includes writ_channel_session.h from its own directory
# ($(REP_DIR)/src/writ_shim/). The generated file is read in place from
# outside this repository and is never edited or committed. The shared
# settings are in scripts/genode/writ_bend.inc (live: $(REP_DIR)/src/app/writ_bend.inc).
#
TARGET = writ_bend_monitor
WRIT_BEND_SRC = monitor.c

# Directory holding the emitted C, outside the Genode repository.
WRIT_BEND_C_DIR ?= $(REP_DIR)/../bend-c/monitor

include $(REP_DIR)/src/app/writ_bend.inc
