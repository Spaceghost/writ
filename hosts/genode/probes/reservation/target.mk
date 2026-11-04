#
# target.mk for writ_probe_reservation - Genode build configuration for
# host-layer qualification, not Writ implementation (Genode host-layer
# lane, Task 1). Links the plain-C probe with the shim's memory unit
# writ_mem.cc, which supplies Libc::Component::construct (so posix is not
# linked) and the mmap/munmap/mprotect definitions that shadow libc's.
#
# writ_mem.cc is a byte-identical copy of hosts/genode/shim/writ_mem.cc
# placed at src/writ_shim/ of the Genode writ-repo; the sha256 of the live
# copy is recorded in verification/genode-reservation-probe-base-linux.txt.
# Both files are compiled by the Genode tool chain (GCC 14.2.0).
#
TARGET = writ_probe_reservation
SRC_C  = probe_reservation.c
SRC_CC = writ_mem.cc
LIBS   = base libc

vpath writ_mem.cc $(REP_DIR)/src/writ_shim

# Genode base-hw lane, Task 1: the shim's fault front end follows KERNEL
# (hosts/genode/shim/writ_shim.mk, live beside writ_mem.cc).
include $(REP_DIR)/src/writ_shim/writ_shim.mk
