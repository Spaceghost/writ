#
# target.mk for writ_bend_hello - Genode build configuration, not Writ
# implementation. Compiles the unmodified C that Bend 2.0.39 emits for
# scripts/genode/Hello.bend (bend scripts/genode/Hello.bend -o
# ../writ-genode/hello/hello.c) against Genode's libc and links it, with the
# shim's memory unit, as a Genode component (Genode component lane, Task 2;
# host-layer lane, Tasks 2 and 3). The generated file is read in place from
# outside this repository and is never edited or committed. The shared
# settings, each with the error it answers, are in scripts/genode/writ_bend.inc
# (live: $(REP_DIR)/src/app/writ_bend.inc).
#
TARGET = writ_bend_hello
WRIT_BEND_SRC = hello.c

# Directory holding the emitted C, outside the Genode repository.
WRIT_BEND_C_DIR ?= $(REP_DIR)/../hello

include $(REP_DIR)/src/app/writ_bend.inc
