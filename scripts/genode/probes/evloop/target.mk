#
# target.mk for writ_probe_evloop - Genode build configuration for runtime-row
# qualification, not Writ implementation (Genode component lane, Task 3).
# Builds the plain-C probe probe_evloop.c against Genode's libc with the same
# pattern as writ_bend_hello (posix supplies the libc entry that calls
# main). The probe stands in for a Bend program until the memory row is
# fixed; see verification/genode-runtime-rows-base-linux.md. It is compiled
# by the Genode tool chain (GCC 14.2.0): the probe uses no clang-only
# construct, and the row under test is libc behaviour, not the compiler.
#
TARGET = writ_probe_evloop
SRC_C  = probe_evloop.c
LIBS   = posix
